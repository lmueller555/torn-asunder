extends "res://game/battlefield/command_harness.gd"

const Rival := preload("res://game/battlefield/marches_rival_reserve.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const CART_SPEED := 7.5
const SHALLOWS_SPEED := 3.9
const CART_NAMES := ["Seed grain", "Bread grain"]
const CART_COLORS := [Color("#ffc67f"), Color("#9fe1c7")]
const FORMATION_NAMES := ["Infantry Reserve", "Escort Archers"]
const STATUS := ["Staged", "En route", "Secured", "Turned back", "Lost"]
const ROUTES := [
	["SeedGrainCart", "ReserveFork", "BridgeApproachWest", "BridgeWestBank", "BridgeDeck", "BridgeEastBank", "MillApproach", "SeedGrainMillYard"],
	["BreadGrainCart", "ReserveFork", "ShelteredTurn", "FordApproachWest", "FordWestBank", "FordShallows", "FordEastBank", "StoreApproach", "BreadGrainStoreYard"],
]
const COMMIT_MARKERS := ["BridgeWestBank", "FordWestBank"]

signal first_crossing_committed(cart: Grain.Cart)
signal mission_cleared(result: StringName)

var objective := Grain.new()
var selected_cart := Grain.Cart.SEED
var committed_cart := -1
var _paths: Array[PackedVector3Array] = []
var _carts: Array[Node3D] = []
var _commit_beacons: Array[Node3D] = []
var _next_waypoint: Array[int] = [1, 1]
var _return_waypoint: Array[int] = [-1, -1]
var _crossed_this_tick: Array[bool] = [false, false]
var _dispatch_requested: Array[bool] = [false, false]
var _withdraw_requested: Array[bool] = [false, false]
var _cart_lost: Array[bool] = [false, false]
var _hero_fell := false
var _blocked_cart := -1
var _rival_routes: Array[PackedVector3Array] = []

@onready var rival: Rival = $RivalReserve
@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _status: Label = $ObjectiveHUD/Panel/Margin/Readout/Status
@onready var _cue: Label = $ObjectiveHUD/Panel/Margin/Readout/Cue
@onready var _select_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Select
@onready var _dispatch_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Dispatch
@onready var _withdraw_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Withdraw
@onready var _restart_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Actions/Restart


func _ready() -> void:
	super._ready()
	_rival_routes = [
		PackedVector3Array([$RivalApproach/NorthTurn.global_position, $RivalApproach/MillTrack.global_position, _route_position("MillApproach")]),
		PackedVector3Array([$RivalApproach/SouthTrack.global_position, _route_position("StoreApproach")]),
	]
	_sign(self, _route_position("ReserveFork"), "RESERVE FORK", Color("#f4dbaf"), 3.1)
	for cart in range(ROUTES.size()):
		var path := PackedVector3Array()
		for marker in ROUTES[cart]:
			path.append(_route_position(marker))
		_paths.append(path)
		_carts.append(_wagon(cart))
		_sign(self, path[-1], "MILL YARD" if cart == Grain.Cart.SEED else "STORE YARD", CART_COLORS[cart], 3.0)
		var crossing := _route_position(COMMIT_MARKERS[cart])
		var beacon := Node3D.new()
		add_child(beacon)
		beacon.global_position = crossing
		_mesh(beacon, _ring(2.7, 2.87), _material(CART_COLORS[cart], true), Vector3.UP * 0.055)
		var sign := _sign(beacon, crossing, "BRIDGE RESERVE CUE" if cart == Grain.Cart.SEED else "FORD RESERVE CUE", CART_COLORS[cart], 3.4)
		sign.no_depth_test = true
		_commit_beacons.append(beacon)
	_select_button.pressed.connect(_select_other_cart)
	_dispatch_button.pressed.connect(_request_dispatch)
	_withdraw_button.pressed.connect(_request_withdrawal)
	_restart_button.pressed.connect(restart_mission)
	_reset_escort()
	_refresh_objective()


func _physics_process(delta: float) -> void:
	for cart in range(_carts.size()):
		if _return_waypoint[cart] >= 0:
			_advance_retreat(cart, delta)
	if objective.outcome == Grain.Outcome.ACTIVE:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	_blocked_cart = -1
	_step_rival(delta)
	var frame := Grain.Observation.new()
	frame.hero_fell = _hero_fell
	for cart in range(_carts.size()):
		var report: Grain.CartReport = frame.seed if cart == Grain.Cart.SEED else frame.bread
		if not frame.hero_fell and objective.cart_state(cart) == Grain.CartState.EN_ROUTE:
			_advance_cart(cart, delta)
		report.dispatch_ordered = _dispatch_requested[cart]
		report.turn_back_ordered = _withdraw_requested[cart]
		report.definitively_lost = _cart_lost[cart]
		report.at_receiving_yard = _next_waypoint[cart] == _paths[cart].size()
		_dispatch_requested[cart] = false
		_withdraw_requested[cart] = false
	objective.advance(frame)
	for cart in range(_carts.size()):
		if objective.cart_state(cart) == Grain.CartState.TURNED_BACK and _carts[cart].visible and _carts[cart].global_position != _paths[cart][0] and _return_waypoint[cart] < 0:
			_return_waypoint[cart] = _next_waypoint[cart] - 1
	_check_crossing_cue()
	_refresh_objective()
	if objective.outcome == Grain.Outcome.SUCCEEDED:
		mission_cleared.emit(objective.clear_result)


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	# Grain uses R1/G and T for cart orders. Give the hero marker separate
	# append/clear shortcuts; D-pad Up already clears via the harness.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_BACKSPACE:
				restart_mission()
				return
			KEY_C:
				_select_other_cart()
				return
			KEY_G:
				_request_dispatch()
				return
			KEY_T:
				_request_withdrawal()
				return
			KEY_V:
				if objective.outcome == Grain.Outcome.ACTIVE:
					add_march_waypoint()
				return
			KEY_B:
				if objective.outcome == Grain.Outcome.ACTIVE:
					clear_march_route()
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
				_request_dispatch()
				return
			JOY_BUTTON_Y:
				_request_withdrawal()
				return
			JOY_BUTTON_DPAD_DOWN:
				if objective.outcome == Grain.Outcome.ACTIVE:
					add_march_waypoint()
				return
	if objective.outcome == Grain.Outcome.ACTIVE:
		super._unhandled_input(event)


func _march_route_controls() -> String:
	return "D-pad Down / V: set waypoint (replaces route)   ·   Square / J: add to route\nCircle / D-pad Up / B: clear route   ·   D-pad Left/Right / Z X: change platoon"


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _name_formations() -> void:
	for index in range(FORMATION_NAMES.size()):
		battle.formations[index].title = FORMATION_NAMES[index]


func _select_other_cart() -> void:
	if objective.outcome != Grain.Outcome.ACTIVE:
		return
	selected_cart = Grain.Cart.BREAD if selected_cart == Grain.Cart.SEED else Grain.Cart.SEED
	_refresh_objective()


func _request_dispatch() -> void:
	if objective.outcome == Grain.Outcome.ACTIVE and objective.cart_state(selected_cart) == Grain.CartState.STAGED:
		_dispatch_requested[selected_cart] = true


func _request_withdrawal() -> void:
	var state := objective.cart_state(selected_cart)
	if objective.outcome == Grain.Outcome.ACTIVE and state in [Grain.CartState.STAGED, Grain.CartState.EN_ROUTE]:
		_withdraw_requested[selected_cart] = true


## Optional hooks for future actual combat; this logistics playtest does not invent losses.
func report_cart_lost(cart: Grain.Cart) -> void:
	_cart_lost[cart] = true


func report_hero_fell() -> void:
	_hero_fell = true


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_formations()
	_sync_view()
	_reset_escort()
	_refresh_objective()


func _reset_escort() -> void:
	selected_cart = Grain.Cart.SEED
	committed_cart = -1
	_blocked_cart = -1
	rival.reset($RivalApproach/ReserveMuster.global_position)
	_hero_fell = false
	for cart in range(_carts.size()):
		_next_waypoint[cart] = 1
		_return_waypoint[cart] = -1
		_crossed_this_tick[cart] = false
		_cart_lost[cart] = false
		_dispatch_requested[cart] = false
		_withdraw_requested[cart] = false
		_carts[cart].global_position = _paths[cart][0]
		_face(_carts[cart], _paths[cart][1])


func _advance_cart(cart: Grain.Cart, delta: float) -> void:
	var wagon := _carts[cart]
	var points := _paths[cart]
	var time_left := delta
	while time_left > 0.0 and _next_waypoint[cart] < points.size():
		var waypoint := _next_waypoint[cart]
		var target := points[waypoint]
		var speed := SHALLOWS_SPEED if cart == Grain.Cart.BREAD and ROUTES[cart][waypoint] in ["FordShallows", "FordEastBank"] else CART_SPEED
		var distance := wagon.global_position.distance_to(target)
		var trial := wagon.global_position.move_toward(target, speed * time_left)
		if cart == committed_cart and rival.blocks_cart_step(wagon.global_position, trial):
			_blocked_cart = cart
			break
		_face(wagon, target)
		wagon.global_position = trial
		if wagon.global_position != target:
			break
		time_left -= distance / speed
		_next_waypoint[cart] += 1
		if ROUTES[cart][waypoint] == COMMIT_MARKERS[cart]:
			_crossed_this_tick[cart] = true


func _advance_retreat(cart: Grain.Cart, delta: float) -> void:
	# Returning resolves the objective immediately; the cosmetic retreat can continue
	# after the debrief appears, rather than forcing the player to wait.
	var wagon := _carts[cart]
	var destination := _paths[cart][_return_waypoint[cart]]
	_face(wagon, destination)
	wagon.global_position = wagon.global_position.move_toward(destination, CART_SPEED * delta)
	if wagon.global_position == destination:
		_return_waypoint[cart] -= 1
		if _return_waypoint[cart] < 0:
			wagon.hide()


func _check_crossing_cue() -> void:
	# Resolve ties in cart order. A returned or destroyed cart cannot activate a cue.
	for cart in range(_carts.size()):
		if committed_cart == -1 and objective.outcome != Grain.Outcome.FAILED and _crossed_this_tick[cart] and objective.cart_state(cart) in [Grain.CartState.EN_ROUTE, Grain.CartState.SECURED]:
			committed_cart = cart
			rival.mobilize(_rival_routes[cart])
			first_crossing_committed.emit(cart)
		_crossed_this_tick[cart] = false


func _refresh_objective() -> void:
	var active := objective.outcome == Grain.Outcome.ACTIVE
	var selected_state := objective.cart_state(selected_cart)
	_select_button.text = "Select: %s" % CART_NAMES[selected_cart]
	_select_button.disabled = not active
	_dispatch_button.disabled = not active or selected_state != Grain.CartState.STAGED
	_withdraw_button.disabled = not active or selected_state not in [Grain.CartState.STAGED, Grain.CartState.EN_ROUTE]
	_status.text = "%s: %s   ·   %s: %s" % [
		CART_NAMES[0], _cart_label(Grain.Cart.SEED),
		CART_NAMES[1], _cart_label(Grain.Cart.BREAD),
	]
	for cart in range(_carts.size()):
		_commit_beacons[cart].visible = active and committed_cart == cart
		var state := objective.cart_state(cart)
		_carts[cart].visible = state != Grain.CartState.LOST and (state != Grain.CartState.TURNED_BACK or _return_waypoint[cart] >= 0)
	match objective.outcome:
		Grain.Outcome.ACTIVE:
			_goal.text = "Escort at least one load to its receiving yard"
			_cue.text = _rival_cue()
		Grain.Outcome.SUCCEEDED:
			match objective.clear_result:
				Grain.SEED_ONLY:
					_goal.text = "Seed grain delivered to the mill"
				Grain.BREAD_ONLY:
					_goal.text = "Bread grain delivered to the town store"
				_:
					_goal.text = "Both grain loads delivered"
			_cue.text = "The convoy is resolved. Restart to try another escort plan."
		Grain.Outcome.FAILED:
			_goal.text = "The field hero fell" if objective.failure == Grain.Failure.HERO_FELL else "No grain was delivered"
			_cue.text = "Restart to try the crossing again."


func _step_rival(delta: float) -> void:
	var positions := PackedVector3Array()
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD:
			positions.append(to_global(_ground(formation.position)))
	rival.step(delta, _can_rival_move, positions)


func _can_rival_move(from: Vector3, to: Vector3) -> bool:
	var start := to_local(from)
	var destination := to_local(to)
	return _terrain.can_move(Vector2(start.x, start.z), Vector2(destination.x, destination.z), true)


func _cart_label(cart: Grain.Cart) -> String:
	if cart == _blocked_cart and objective.cart_state(cart) == Grain.CartState.EN_ROUTE:
		return "Blocked by rival reserve"
	return STATUS[objective.cart_state(cart)]


func _rival_cue() -> String:
	if committed_cart == -1:
		return "Dispatch either cart first. The rival reserve is still at its muster."
	var lane := "north bridge" if committed_cart == Grain.Cart.SEED else "south ford"
	match rival.status:
		Rival.Status.MARCHING:
			return "Rival reserve moving toward the %s." % lane
		Rival.Status.BLOCKING:
			return "Rival reserve blocking the %s. Hold a nearby ally or use the other route." % lane
		Rival.Status.SCREENED:
			return "Ally holding the %s approach. The cart can pass." % lane
	return ""


func _route_position(id: String) -> Vector3:
	for prefix in ["Spawns/", "Routes/", "Objectives/"]:
		var marker := battlefield_marker(NodePath("Markers/" + prefix + id))
		if marker:
			return marker.global_position
	push_error("Missing Marches Crossing marker: " + id)
	return Vector3.ZERO


func _face(wagon: Node3D, target: Vector3) -> void:
	var offset := target - wagon.global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.00001:
		wagon.rotation.y = atan2(-offset.x, -offset.z)


func _wagon(cart: Grain.Cart) -> Node3D:
	var wagon := Node3D.new()
	add_child(wagon)
	var oak := _material(Color("#987048"))
	var trim := _material(Color("#6c4b34"))
	var sacks := _material(CART_COLORS[cart])
	_mesh(wagon, _box(Vector3(1.65, 0.31, 2.55)), oak, Vector3.UP * 0.68)
	for x in [-0.9, 0.9]:
		_mesh(wagon, _box(Vector3(0.19, 0.45, 2.55)), trim, Vector3(x, 0.97, 0.0))
		for z in [-0.73, 0.73]:
			var wheel := CylinderMesh.new()
			wheel.height = 0.24
			wheel.top_radius = 0.46
			wheel.bottom_radius = 0.46
			wheel.radial_segments = 12
			_mesh(wagon, wheel, trim, Vector3(x * 1.22, 0.46, z)).rotation.z = PI / 2.0
	for spot in [Vector3(-0.39, 1.06, 0.37), Vector3(0.39, 1.06, 0.37), Vector3(0, 1.06, -0.55)]:
		_mesh(wagon, _box(Vector3(0.64, 0.48, 0.75)), sacks, spot)
	_sign(wagon, wagon.global_position, CART_NAMES[cart], CART_COLORS[cart], 1.95)
	return wagon


func _sign(parent: Node3D, at: Vector3, title: String, color: Color, height: float) -> Label3D:
	var sign := Label3D.new()
	sign.text = title
	sign.modulate = color
	sign.pixel_size = 0.033
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(sign)
	sign.global_position = at + Vector3.UP * height
	return sign
