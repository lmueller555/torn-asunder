extends "res://game/battlefield/command_harness.gd"
## Logistics prototype with optional directional charge pressure on formation cohesion only.

signal mission_finished(won: bool)

const WellRoad := preload("res://game/battlefield/raska_well_road.gd")
const Rival := preload("res://game/battlefield/marches_rival_reserve.gd")
const MountedPass := preload("res://game/combat/mounted_brace_encounter.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Roster := preload("res://game/combat/faction_roster.gd")

enum PassStage { AVAILABLE, ARMED, RUNNING, WITHDRAWING, RESTAGING, WITHDRAWN, SPENT }
const BRACE_INDEX := 0
const BRACE_GATE_RADIUS := 2.5
const CART_SPEED := 7.5
const HOUSEHOLD_SPEED := 3.0
const BOARDING_REACH := 2.8
const EXIT_RADIUS := 2.0
const CART_NAMES := ["Upper-well cart", "Lower-well cart"]
const CART_COLORS := [Color("#ffca7d"), Color("#99dec3")]
const GROUP_NAMES := ["Brace Infantry", "Basin Archers"]
const SALT := ["SaltRoadWest", "SaltChargeGate", "SaltRoadEast"]
const WASH := [
	"WashEntryTurn", "WashWestBend", "WashReedBend", "WashBlindBend", "WashLongBend",
	"WashEastBend", "WashRampTurn", "WashRampFoot", "WashRampTop",
]
const RESERVE_ROUTE := ["MountedReserveTurn", "MountedScreenCorner", "MountedWarning", "MountedChargeStart"]
const HOUSEHOLD_OFFSETS: Array[Vector3] = [Vector3(0, 0, -0.70), Vector3(0, 0, 0), Vector3(0, 0, 0.70)]


class Convoy:
	var wagon: Node3D
	var banner: Label3D
	var path := PackedVector3Array()
	var next := 0
	var fork := 0
	var merge := 0
	var order := WellRoad.Route.NONE
	var waiting_on := ""
	var lost := false


var objective := WellRoad.new()
var selected_cart := WellRoad.Cart.UPPER
var _carts: Array[Convoy] = []
var _households: Array[Node3D] = []
var _riders: Array[Node3D] = []
var _boarded := 0
var _boarding := false
var _load_requested := false
var _hero_fell := false
var _notice := ""
var _upper_spawn: Vector3
var _lower_spawn: Vector3
var _door: Vector3
var _boarding_position: Vector3
var _household_spawn: Vector3
var _exit: Vector3
var _salt_trigger: Vector3
var _reserve_spawn: Vector3
var _reserve_path := PackedVector3Array()
var _pass_stage := PassStage.AVAILABLE
var _pass: MountedPass
var _brace_line: Platoon
var _mounted_line: Platoon
var _explicit_brace := false

@onready var _rival: Rival = $MountedReserve
@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _status: Label = $ObjectiveHUD/Panel/Margin/Readout/Status
@onready var _cue: Label = $ObjectiveHUD/Panel/Margin/Readout/Cue
@onready var _instructions: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _select: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Select
@onready var _salt: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Salt
@onready var _wash: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Wash
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Restart


func _ready() -> void:
	super._ready()
	_upper_spawn = _mark("Spawns/UpperWellCart")
	_lower_spawn = _mark("Spawns/LowerWellCart")
	_door = _mark("Objectives/LowerStorehouse")
	_boarding_position = _mark("Objectives/LowerBoarding")
	_household_spawn = _mark("Spawns/LowerHouseholds")
	_exit = _mark("Objectives/BasinExit")
	_salt_trigger = _route("SaltRoadWest")
	_reserve_spawn = _mark("Spawns/MountedReserve")
	for route_name in RESERVE_ROUTE:
		_reserve_path.append(_route(route_name))
	_carts.append(_make_cart(WellRoad.Cart.UPPER))
	_carts.append(_make_cart(WellRoad.Cart.LOWER))
	_make_households()
	_beacon(_door, "LOWER STOREHOUSE", Color("#99dec3"))
	_beacon(_salt_trigger, "SALT ROAD · OPEN LANE", Color("#ffd293"))
	_beacon(_route("WashEntryTurn"), "COVERED WASH", Color("#9fc9eb"))
	_beacon(_exit, "BASIN EXIT", Color("#a4e4c6"))
	_select.pressed.connect(_select_other_cart)
	_salt.pressed.connect(_queue_route.bind(WellRoad.Route.SALT_ROAD))
	_wash.pressed.connect(_queue_route.bind(WellRoad.Route.WASH))
	_restart.pressed.connect(restart_mission)
	_reset_convoy()
	_refresh()


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _physics_process(delta: float) -> void:
	if objective.outcome == WellRoad.Outcome.ACTIVE:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var was_active := objective.outcome == WellRoad.Outcome.ACTIVE
	_step_boarding(delta)
	_step_reserve(delta)
	var frame := WellRoad.Observation.new()
	frame.lower_households_aboard = _boarded == _households.size()
	frame.raska_incapacitated = _hero_fell
	var previous_routes: Array[WellRoad.Route] = []
	for cart in range(_carts.size()):
		var data := _carts[cart]
		var report := frame.upper if cart == WellRoad.Cart.UPPER else frame.lower
		var route := objective.route_for(cart)
		previous_routes.append(route)
		if objective.cart_state(cart) == WellRoad.CartState.EN_ROUTE and not _hero_fell and not data.lost:
			_step_cart(cart, route, delta)
		report.definitively_lost = data.lost
		report.at_basin_exit = not data.path.is_empty() and data.next >= data.path.size() \
			and data.wagon.global_position.distance_to(_exit) <= EXIT_RADIUS
		report.requested_route = data.order
		report.route_admitted = _route_admitted(cart)
		if data.order != WellRoad.Route.NONE:
			if objective.cart_state(cart) == WellRoad.CartState.LOADING:
				_notice = "Lower cart cannot leave before all households are aboard. Order it again once ready."
			elif not report.route_admitted:
				_notice = "That cart has already passed the route merge or reached safety."
			else:
				_notice = ""
		data.order = WellRoad.Route.NONE
	objective.advance(frame)
	for cart in range(_carts.size()):
		var new_route := objective.route_for(cart)
		if new_route != previous_routes[cart]:
			_apply_route(cart, new_route)
	_refresh()
	if was_active and objective.outcome != WellRoad.Outcome.ACTIVE:
		mission_finished.emit(objective.outcome == WellRoad.Outcome.SUCCEEDED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_BACKSPACE:
				restart_mission()
				return
			KEY_C:
				_select_other_cart()
				return
			KEY_G:
				_queue_route(WellRoad.Route.SALT_ROAD)
				return
			KEY_T:
				_queue_route(WellRoad.Route.WASH)
				return
			KEY_SPACE:
				if not command_view:
					_load_requested = true
					return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		match event.button_index:
			JOY_BUTTON_START:
				restart_mission()
				return
			JOY_BUTTON_LEFT_SHOULDER:
				_select_other_cart()
				return
			JOY_BUTTON_RIGHT_SHOULDER:
				_queue_route(WellRoad.Route.SALT_ROAD)
				return
			JOY_BUTTON_Y:
				_queue_route(WellRoad.Route.WASH)
				return
			JOY_BUTTON_A:
				if not command_view:
					_load_requested = true
					return
	if objective.outcome == WellRoad.Outcome.ACTIVE:
		super._unhandled_input(event)


func _move_selected() -> void:
	if command_view and selected_index == BRACE_INDEX:
		_explicit_brace = false
	super._move_selected()


func _hold_selected() -> void:
	if command_view and selected_index == BRACE_INDEX and objective.outcome == WellRoad.Outcome.ACTIVE:
		var group := battle.formations[BRACE_INDEX]
		var aim := cursor - group.position
		if group.can_receive_orders() and group.position.distance_to(_xz(_route("SaltChargeGate"))) <= BRACE_GATE_RADIUS \
				and aim.length_squared() > 0.25:
			if _pass_stage == PassStage.AVAILABLE and _rival.status != Rival.Status.WAITING:
				_notice = "The riders have mobilized. Use an ordinary screen or reroute to the wash."
			elif _pass_stage in [PassStage.AVAILABLE, PassStage.ARMED, PassStage.RUNNING]:
				group.heading = aim.normalized()
				_explicit_brace = true
				if _pass_stage == PassStage.AVAILABLE:
					_pass_stage = PassStage.ARMED
	super._hold_selected()


func _select_other_cart() -> void:
	if objective.outcome == WellRoad.Outcome.ACTIVE:
		selected_cart = WellRoad.Cart.LOWER if selected_cart == WellRoad.Cart.UPPER else WellRoad.Cart.UPPER
		_notice = ""
		_refresh()


func _queue_route(route: WellRoad.Route) -> void:
	if objective.outcome == WellRoad.Outcome.ACTIVE:
		_carts[selected_cart].order = route


func _route_admitted(cart: WellRoad.Cart) -> bool:
	var state := objective.cart_state(cart)
	return state in [WellRoad.CartState.LOADING, WellRoad.CartState.READY] \
		or (state == WellRoad.CartState.EN_ROUTE and _carts[cart].next <= _carts[cart].merge)


func _apply_route(cart: WellRoad.Cart, route: WellRoad.Route) -> void:
	var data := _carts[cart]
	var path := PackedVector3Array()
	var next := 1
	if data.path.is_empty():
		path.append(data.wagon.global_position)
		if cart == WellRoad.Cart.UPPER:
			path.append(_route("UpperWellStaging"))
		else:
			path.append(_route("LowerWellStaging"))
			path.append(_route("WashEntryTurn"))
	elif data.next <= data.fork:
		# Before reaching the fork, keep the approach or the already-chosen retreat.
		for i in range(data.fork + 1):
			path.append(data.path[i])
		next = data.next
	else:
		# Rerouting is a physical turn back along the traveled road, not a teleport.
		path.append(data.wagon.global_position)
		for i in range(data.next - 1, data.fork - 1, -1):
			if path[-1] != data.path[i]:
				path.append(data.path[i])
	data.fork = path.size() - 1
	if route == WellRoad.Route.SALT_ROAD:
		if cart == WellRoad.Cart.LOWER:
			path.append(_route("WestApproachFork"))
		for marker in SALT:
			path.append(_route(marker))
	else:
		if cart == WellRoad.Cart.UPPER:
			path.append(_route("WestApproachFork"))
		for marker in WASH:
			var point := _route(marker)
			if point != path[-1]:
				path.append(point)
	path.append(_route("HighBankRally"))
	data.merge = path.size() - 1
	# Both use the same exit zone, but park on separate sides of it.
	path.append(_exit + Vector3(0.0, 0.0, -1.05 if cart == WellRoad.Cart.UPPER else 1.05))
	data.path = path
	data.next = next
	data.waiting_on = ""


func _step_cart(cart: WellRoad.Cart, route: WellRoad.Route, delta: float) -> void:
	var data := _carts[cart]
	data.waiting_on = ""
	var remaining := delta * CART_SPEED
	while remaining > 0.0 and data.next < data.path.size():
		var here := data.wagon.global_position
		var target := data.path[data.next]
		var trial := here.move_toward(target, remaining)
		# A wagon retreating toward the fork is moving away from the charge lane.
		var on_salt := route == WellRoad.Route.SALT_ROAD and data.next > data.fork and data.next <= data.merge
		# A deliberate pass stages salt wagons outside the complete swept lane.
		# This checkpoint is 32 m west of its run-out; the covered wash never
		# waits here, and a cart can turn back while the riders move.
		if on_salt and here.is_equal_approx(_salt_trigger) and _pass_owns_lane():
			data.waiting_on = "Mounted pass"
			return
		if on_salt and _pass_stage != PassStage.WITHDRAWN and _rival.blocks_cart_step(here, trial):
			data.waiting_on = "Mounted reserve"
			return
		if not _can_move(here, trial):
			data.waiting_on = "Terrain"
			return
		_face(data.wagon, target)
		data.wagon.global_position = trial
		remaining -= here.distance_to(trial)
		if trial != target:
			break
		data.next += 1
		if on_salt and target == _salt_trigger:
			_rival.mobilize(_reserve_path)


func _step_boarding(delta: float) -> void:
	if _load_requested and objective.cart_state(WellRoad.Cart.LOWER) == WellRoad.CartState.LOADING \
			and not command_view and not _hero_fell:
		if hero_world_position().distance_to(_door) <= BOARDING_REACH:
			_boarding = true
			_notice = ""
		else:
			_notice = "Bring Raska to the marked lower storehouse to board the households."
	_load_requested = false
	if not _boarding or _boarded == _households.size() or _hero_fell:
		return
	var wagon := _carts[WellRoad.Cart.LOWER].wagon
	if wagon.global_position != _boarding_position:
		_face(wagon, _boarding_position)
		var trial := wagon.global_position.move_toward(_boarding_position, CART_SPEED * delta)
		if _can_move(wagon.global_position, trial):
			wagon.global_position = trial
		return
	for index in range(_households.size()):
		var household := _households[index]
		if not household.visible:
			continue
		var seat := _boarding_position + HOUSEHOLD_OFFSETS[index] * 0.50
		var step := household.global_position.move_toward(seat, HOUSEHOLD_SPEED * delta)
		if _can_move(household.global_position, step, false):
			household.global_position = step
		if household.global_position.distance_to(seat) <= 0.12:
			household.hide()
			_riders[index].show()
			_boarded += 1


func _step_reserve(delta: float) -> void:
	var brace := battle.formations[BRACE_INDEX]
	_pass.observe_defender(brace.position, brace.heading, _explicit_brace and brace.order == Battle.Order.HOLD, delta)
	match _pass_stage:
		PassStage.RUNNING:
			_pass.advance(delta)
			_rival.global_position = to_global(_ground(_pass.rider_position))
			var direction := _pass.travel_direction
			_rival.rotation.y = atan2(-direction.x, -direction.y)
			_rival._banner.text = "Mounted reserve · Regrouping" if _pass.phase == MountedPass.Phase.REGROUPING else "Mounted reserve · Charging"
			if _pass.phase == MountedPass.Phase.READY:
				_finish_pass()
			return
		PassStage.WITHDRAWING, PassStage.RESTAGING:
			_rival.step(delta, _can_move, PackedVector3Array())
			if _rival.status == Rival.Status.BLOCKING:
				_pass_stage = PassStage.WITHDRAWN if _pass_stage == PassStage.WITHDRAWING else PassStage.SPENT
			else:
				_rival._banner.text = "Mounted reserve · Withdrawing" if _pass_stage == PassStage.WITHDRAWING else "Mounted reserve · Returning"
			if _pass_stage == PassStage.WITHDRAWN:
				_rival._banner.text = "Mounted reserve · Withdrew"
			return
		PassStage.WITHDRAWN:
			return
	var held := PackedVector3Array()
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD:
			held.append(to_global(_ground(formation.position)))
	var reserve_before := _rival.global_position
	_rival.step(delta, _can_move, held)
	if _pass_stage != PassStage.ARMED:
		return
	for cart in range(_carts.size()):
		if objective.cart_state(cart) != WellRoad.CartState.EN_ROUTE \
				or objective.route_for(cart) != WellRoad.Route.SALT_ROAD \
				or not _carts[cart].wagon.global_position.is_equal_approx(_salt_trigger):
			continue
		if _rival.status == Rival.Status.MARCHING:
			if delta > 0.0 and _rival.global_position == reserve_before:
				_release_unavailable_pass()
			return
		if _rival.status in [Rival.Status.BLOCKING, Rival.Status.SCREENED] \
				and _rival.global_position.is_equal_approx(_route("MountedChargeStart")) \
				and _pass.sync_ready_riders(_xz(_rival.global_position)) \
				and _pass.order_pass(_xz(_route("MountedRunout"))):
			_pass_stage = PassStage.RUNNING
		else:
			_release_unavailable_pass()
		return


func _release_unavailable_pass() -> void:
	# Leave the surviving actors where they are and restore the normal convoy
	# rules. A rejected pass must not keep an otherwise movable cart staged.
	_pass_stage = PassStage.SPENT
	_notice = "Mounted pass unavailable. Screen the reserve or reroute to the wash."


func _finish_pass() -> void:
	var repelled := _pass.result == MountedPass.Result.REPELLED
	_pass_stage = PassStage.WITHDRAWING if repelled else PassStage.RESTAGING
	# Reuse the mounted formation's ordinary physical movement starting exactly
	# where the real pass finished. Repelled riders leave the deck alive.
	var charge_start := _route("MountedChargeStart")
	var route := PackedVector3Array([charge_start])
	if repelled:
		route.append(_route("MountedWarning"))
	_rival.reset(_rival.global_position)
	_rival.mobilize(route)


func _pass_owns_lane() -> bool:
	return _pass_stage in [PassStage.ARMED, PassStage.RUNNING, PassStage.WITHDRAWING, PassStage.RESTAGING]


func _xz(point: Vector3) -> Vector2:
	var local := to_local(point)
	return Vector2(local.x, local.z)


func _can_move(from: Vector3, to: Vector3, wide := true) -> bool:
	var a := to_local(from)
	var b := to_local(to)
	return _terrain.can_move(Vector2(a.x, a.z), Vector2(b.x, b.z), wide)


## Definitive loss hooks. The optional mounted pass affects only formation cohesion.
func report_cart_lost(cart: WellRoad.Cart) -> void:
	_carts[cart].lost = true


func report_raska_incapacitated() -> void:
	_hero_fell = true


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_formations()
	_reset_convoy()
	_sync_view()
	_refresh()


func _reset_convoy() -> void:
	selected_cart = WellRoad.Cart.UPPER
	_boarded = 0
	_boarding = false
	_load_requested = false
	_hero_fell = false
	_notice = ""
	_rival.reset(_reserve_spawn)
	_pass_stage = PassStage.AVAILABLE
	_explicit_brace = false
	_brace_line = Platoon.new([Unit.new()], {})
	_mounted_line = Platoon.new([Unit.new()], {})
	_pass = MountedPass.new(_mounted_line, _brace_line, _xz(_reserve_spawn), Roster.ANTI_RIDING,
		_terrain.can_move.bind(true), _terrain.clear_melee_contact)
	for i in range(_carts.size()):
		var data := _carts[i]
		data.path.clear()
		data.next = 0
		data.fork = 0
		data.merge = 0
		data.order = WellRoad.Route.NONE
		data.waiting_on = ""
		data.lost = false
		data.wagon.global_position = _upper_spawn if i == WellRoad.Cart.UPPER else _lower_spawn
		data.wagon.show()
	for i in range(_households.size()):
		_households[i].global_position = _household_spawn + HOUSEHOLD_OFFSETS[i]
		_households[i].show()
		_riders[i].hide()


func _refresh() -> void:
	var active := objective.outcome == WellRoad.Outcome.ACTIVE
	_select.text = "Select: %s  [C / L1]" % CART_NAMES[selected_cart]
	_select.disabled = not active
	_salt.disabled = not active or not _route_admitted(selected_cart)
	_wash.disabled = _salt.disabled
	var labels: Array[String] = []
	for cart in range(_carts.size()):
		var state := _cart_status(cart)
		labels.append("%s: %s" % [CART_NAMES[cart], state])
		_carts[cart].banner.text = ("%s: " % CART_NAMES[cart]) + state
		_carts[cart].banner.modulate = CART_COLORS[cart] if cart == selected_cart else Color.WHITE
		_carts[cart].wagon.visible = objective.cart_state(cart) != WellRoad.CartState.LOST
	_status.text = "  ·  ".join(labels)
	_instructions.text = "At the lower storehouse, return to Raska and press Cross / Space to board households."
	if objective.cart_state(WellRoad.Cart.LOWER) != WellRoad.CartState.LOADING:
		_instructions.text = "Both carts must arrive. Hold near the reserve to screen it, or aim and Hold Brace Infantry at Salt Charge Gate before riders mobilize."
	match objective.outcome:
		WellRoad.Outcome.ACTIVE:
			_goal.text = "Escort both well carts to the Basin exit"
			_cue.text = _reserve_cue()
			if not _notice.is_empty():
				_instructions.text = _notice + " " + _instructions.text
		WellRoad.Outcome.SUCCEEDED:
			_goal.text = "Both well carts made it out"
			_cue.text = "The households and both shipments reached the Basin exit."
			_instructions.text = ""
		WellRoad.Outcome.FAILED:
			_goal.text = "Raska was incapacitated" if objective.failure == WellRoad.Failure.RASKA_INCAPACITATED else "A required well cart was lost"
			_cue.text = "Restart to try a new escort plan."
			_instructions.text = ""


func _cart_status(cart: WellRoad.Cart) -> String:
	match objective.cart_state(cart):
		WellRoad.CartState.LOADING:
			return "Boarding %d/%d" % [_boarded, _households.size()] if _boarding else "Awaiting households"
		WellRoad.CartState.READY: return "Ready"
		WellRoad.CartState.SAFE: return "Safe"
		WellRoad.CartState.LOST: return "Lost"
	var data := _carts[cart]
	if not data.waiting_on.is_empty():
		return "Waiting: " + data.waiting_on
	return "Salt road" if objective.route_for(cart) == WellRoad.Route.SALT_ROAD else "Wash"


func _reserve_cue() -> String:
	var cohesion := "Brace cohesion %.0f · Mounted cohesion %.0f." % [_brace_line.cohesion, _mounted_line.cohesion]
	match _pass_stage:
		PassStage.ARMED:
			var facing := battle.formations[BRACE_INDEX].heading
			var toward_riders := (_xz(_route("MountedChargeStart")) - _xz(_route("SaltChargeGate"))).normalized()
			var ready := "Brace ready." if _pass.brace_ready else "Brace setting."
			if facing.dot(toward_riders) < MountedPass.FRONT_DOT:
				ready = "Brace faces away. Aim east and Hold."
			var warning := "Riders approaching. " if _rival.status == Rival.Status.MARCHING else ""
			return "%s%s Salt carts wait at the west marker. Wash open. %s" % [warning, ready, cohesion]
		PassStage.RUNNING:
			match _pass.result:
				MountedPass.Result.REPELLED: return "Brace held. Riders regrouping to withdraw. " + cohesion
				MountedPass.Result.LANDED: return "The charge broke through. Reroute to the wash or screen when riders return. " + cohesion
				MountedPass.Result.NONE: pass
				_: return "The pass made no contact. Riders regrouping; wash open. " + cohesion
			return "Riders charging from the east. Salt carts wait west of the lane. Wash open. " + cohesion
		PassStage.WITHDRAWING: return "Brace held. Riders withdrawing clear of the salt road. " + cohesion
		PassStage.RESTAGING: return "Riders returning to the salt road. Wash open. " + cohesion
		PassStage.WITHDRAWN: return "Riders withdrew. Salt road open. " + cohesion
	match _rival.status:
		Rival.Status.MARCHING: return "Mounted reserve approaching the salt road. Wash stays open."
		Rival.Status.BLOCKING: return "Mounted reserve blocking the salt road. Screen it or turn a cart back through the fork to the wash."
		Rival.Status.SCREENED: return "Mounted reserve screened by allied Hold. Salt road open."
	return "Salt road is shorter; the wash is covered. To brace, aim and Hold Brace Infantry at Salt Charge Gate before the riders move."


func _name_formations() -> void:
	for i in range(GROUP_NAMES.size()):
		battle.formations[i].title = GROUP_NAMES[i]


func _route(name: String) -> Vector3:
	return _mark("Routes/" + name)


func _mark(path: String) -> Vector3:
	return battlefield_marker(NodePath("Markers/" + path)).global_position


func _make_cart(cart: WellRoad.Cart) -> Convoy:
	var data := Convoy.new()
	var wagon := Node3D.new()
	add_child(wagon)
	data.wagon = wagon
	var timber := _material(Color("#86634b"))
	var iron := _material(Color("#56463b"))
	_mesh(wagon, _box(Vector3(2.1, 0.65, 1.62)), timber, Vector3.UP * 0.83)
	_mesh(wagon, _box(Vector3(1.70, 0.54, 1.16)), _material(CART_COLORS[cart]), Vector3.UP * 1.35)
	for x in [-0.93, 0.93]:
		for z in [-0.56, 0.56]:
			_mesh(wagon, _box(Vector3(0.16, 0.65, 0.65)), iron, Vector3(x, 0.35, z))
	data.banner = _sign(wagon, CART_NAMES[cart], CART_COLORS[cart], 2.8)
	return data


func _make_households() -> void:
	for offset in HOUSEHOLD_OFFSETS:
		var household := Node3D.new()
		add_child(household)
		_mesh(household, _box(Vector3(0.50, 1.20, 0.40)), _material(Color("#e1c6a5")), Vector3.UP * 0.65)
		_households.append(household)
		var rider := _mesh(_carts[WellRoad.Cart.LOWER].wagon, _box(Vector3(0.34, 0.41, 0.30)),
			_material(Color("#e1c6a5")), offset + Vector3.UP * 1.75)
		_riders.append(rider)


func _beacon(at: Vector3, text: String, color: Color) -> void:
	var marker := Node3D.new()
	add_child(marker)
	marker.global_position = at
	_mesh(marker, _ring(1.3, 1.46), _material(color, true), Vector3.UP * 0.03)
	_sign(marker, text, color, 2.5)


func _sign(parent: Node3D, text: String, color: Color, height: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.position.y = height
	label.pixel_size = 0.028
	label.outline_size = 9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label


func _face(actor: Node3D, target: Vector3) -> void:
	var offset := target - actor.global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.00001:
		actor.rotation.y = atan2(-offset.x, -offset.z)
