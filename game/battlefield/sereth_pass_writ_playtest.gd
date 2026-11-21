extends "res://game/battlefield/command_harness.gd"

const EnemyAggro := preload("res://game/combat/enemy_aggro.gd")
const Writ := preload("res://game/battlefield/sereth_pass_writ.gd")
const CONTACT := 1.8
const RALLY_RADIUS := 2.9
const DETECT_RANGE := EnemyAggro.RADIUS_METRES
const PATROL_RANGE := 33.0
const WARNING_SECONDS := 1.15
const PATROL_SPEED := 4.1
const MOUNTED_SPEED := 8.0
const KEEPER_SPEED := 2.5
const SCREEN_RADIUS := 5.0
const NEUTRAL := Color("#ffe1a1")
const SAFE := Color("#a9e4cc")
const WARN := Color("#ff9d7a")

const POST_PATH := ["Routes/LookoutBendRoad", "Routes/PostEastTurn", "Routes/PostRoadApproach",
	"Routes/PostDoorway", "Objectives/WritHandover"]
const MOUNTED_PATH := ["Spawns/MarchMountedReserve", "Routes/ReserveWideTurn", "Routes/ReserveScreenTurn",
	"Routes/ReserveReveal", "Routes/ReserveChargeEntry", "Routes/PostEastTurn", "Routes/LookoutBendRoad",
	"Routes/RoadEastStraight", "Routes/ScoutRoadBypassEast", "Routes/ScoutRoadBypassWest",
	"Routes/RoadCenter", "Routes/OpenRoadBrace", "Routes/MountedRunout"]
const ROAD_COMMIT_INDEX := 5

signal mission_finished(won: bool)

var objective := Writ.new()
var _keeper: Node3D
var _lookout: Node3D
var _patrol: Node3D
var _reserve: Node3D
var _reserve_flag: Node3D
var _lookout_flag: Node3D
var _rally_flag: Node3D
var _writ: Node3D
var _debug_labels: Array[Label3D] = []
var _yard: AABB
var _handover: Vector3
var _rally: Vector3
var _keeper_home: Vector3
var _keeper_reply_spot: Vector3
var _patrol_west: Vector3
var _patrol_east: Vector3
var _post_route := PackedVector3Array()
var _mounted_route := PackedVector3Array()
var _patrol_intent := false
var _patrol_joined := false
var _patrol_eastbound := false
var _patrol_distance := 0.0
var _post_road_distance := 0.0
var _post_route_length := 0.0
var _next_mount := 1
var _lookout_contact := 0.0
var _courier_seen := 0.0
var _scout_spotted := false
var _offer_pressed := false
var _sereth_fell := false

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _keeper_text: Label = $ObjectiveHUD/Panel/Margin/Readout/Keeper
@onready var _pressure: Label = $ObjectiveHUD/Panel/Margin/Readout/Pressure
@onready var _hint: Label = $ObjectiveHUD/Panel/Margin/Readout/Hint
@onready var _restart_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_handover = _point("Objectives/WritHandover")
	_rally = _point("Objectives/WithdrawalRally")
	_keeper_home = _point("Spawns/Keeper")
	_keeper_reply_spot = _keeper_home.move_toward(_handover, 2.35)
	_patrol_west = _point("Routes/RoadEastStraight")
	_patrol_east = _point("Routes/LookoutBendRoad")
	for id: String in POST_PATH:
		_post_route.append(_point(id))
	for id: String in MOUNTED_PATH:
		_mounted_route.append(_point(id))
	_post_road_distance = _post_route[0].distance_to(_post_route[1])
	for i in range(1, _post_route.size()):
		_post_route_length += _post_route[i - 1].distance_to(_post_route[i])
	var zone := battlefield_marker(^"Markers/Zones/KeeperOccupation")
	var size: Vector3 = zone.get_meta(&"box_size")
	_yard = AABB(to_local(zone.global_position) - size * 0.5, size)
	_keeper = _debug_party("Neutral Keeper", NEUTRAL, 1)
	_lookout = _debug_party("March lookout", WARN, 1)
	_lookout.global_position = _point("Spawns/MarchLookout")
	_patrol = _debug_party("March road patrol", Color("#d57a69"), 4)
	_reserve = _debug_party("Mounted reserve", Color("#af654b"), 4, true)
	_reserve_flag = _debug_marker(_mounted_route[0], "RESERVE SIGNAL", WARN)
	_lookout_flag = _debug_marker(_lookout.global_position, "LOOKOUT", WARN)
	_rally_flag = _debug_marker(_rally, "WITHDRAWAL RALLY", SAFE)
	_debug_marker(_handover, "KEEPER HANDOVER", NEUTRAL)
	_debug_marker(_point("Routes/WestTrackTurn"), "SHEEP TRACK", SAFE)
	_debug_marker(_point("Routes/OpenRoadBrace"), "OPEN ROAD · SCREEN HERE", NEUTRAL)
	_debug_marker(_point("Routes/HighBankScout"), "SCOUT BANK", SAFE)
	_debug_marker(_point("Routes/PostRoadApproach"), "HOLD SCREEN", SAFE)
	_writ = Node3D.new()
	$DebugPlaytestVisuals.add_child(_writ)
	_mesh(_writ, _box(Vector3(0.28, 0.20, 0.055)), _material(NEUTRAL))
	_restart_button.pressed.connect(restart_mission)
	_reset_attempt()


func _physics_process(delta: float) -> void:
	if objective.phase not in [Writ.Phase.SUCCEEDED, Writ.Phase.FAILED]:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var hero := hero_world_position()
	var hero_visible := _seen_from_lookout(hero, DETECT_RANGE)
	var seen := hero_visible
	for formation in battle.formations:
		if formation.can_receive_orders():
			seen = seen or _seen_from_lookout(to_global(_ground(formation.position)), DETECT_RANGE)
	_lookout_contact = _lookout_contact + delta if seen else 0.0
	# The foot patrol seeks the yard when the courier actually comes into view
	# near the post. The reserve can be drawn earlier by a visible formation.
	var near_courier := hero_visible and hero.distance_to(_lookout.global_position) <= PATROL_RANGE
	_courier_seen = _courier_seen + delta if near_courier else 0.0
	_patrol_intent = _patrol_intent or _courier_seen >= WARNING_SECONDS
	_scout_spotted = _scout_spotted or _scout_has_sight(hero)
	_step_patrol(delta)
	_step_mounted(delta)

	var at_handover := hero.distance_to(_handover) <= CONTACT
	var patrol_in_yard := _yard.has_point(to_local(_patrol.global_position) + Vector3.UP * 0.8)
	var pending := objective.pending_offer_id
	var reply := 0
	if objective.phase == Writ.Phase.CARRYING_WRIT:
		_move_actor(_keeper, _keeper_home, KEEPER_SPEED * delta, false)
	elif objective.phase == Writ.Phase.AWAITING_KEEPER and pending > 0 and at_handover and not patrol_in_yard:
		# The neutral actor actually steps up to take this offer. Losing contact
		# cancels it in the model; its ID is not copied to the next interaction.
		if _move_actor(_keeper, _keeper_reply_spot, KEEPER_SPEED * delta, false):
			reply = pending
	var frame := Writ.Observation.new()
	frame.offer_writ = _offer_pressed and not command_view
	frame.sereth_at_handover = at_handover
	frame.keeper_at_post = _keeper.visible and _yard.has_point(to_local(_keeper.global_position) + Vector3.UP * 0.8)
	frame.keeper_accepts_offer_id = reply
	frame.sereth_at_withdrawal_rally = hero.distance_to(_rally) <= RALLY_RADIUS
	frame.sereth_fell = _sereth_fell
	frame.post_contested = patrol_in_yard
	frame.hostile_controls_post = patrol_in_yard and not _held_near(_point("Routes/PostRoadApproach"), SCREEN_RADIUS) \
		and not _allied_in_yard()
	frame.elapsed_seconds = delta
	frame.lookout_signaled = _lookout_contact >= WARNING_SECONDS
	frame.mounted_reserve_at_road = _next_mount > ROAD_COMMIT_INDEX
	_offer_pressed = false

	objective.advance(frame)
	_refresh(hero, patrol_in_yard, seen)
	if objective.phase == Writ.Phase.SUCCEEDED:
		mission_finished.emit(true)
	elif objective.phase == Writ.Phase.FAILED:
		mission_finished.emit(false)


func _seen_from_lookout(feet: Vector3, radius: float) -> bool:
	var offset := feet - _lookout.global_position
	return Vector2(offset.x, offset.z).length_squared() <= radius * radius and _clear_sight(_lookout.global_position, feet)


func _scout_has_sight(hero: Vector3) -> bool:
	var bank := _point("Routes/HighBankScout")
	if hero.distance_to(bank) <= 12.0 and _clear_sight(hero, _lookout.global_position):
		return true
	for formation in battle.formations:
		var feet := to_global(_ground(formation.position))
		if formation.can_receive_orders() and feet.distance_to(bank) <= 12.0 and _clear_sight(feet, _lookout.global_position):
			return true
	return false


func _clear_sight(from: Vector3, to: Vector3) -> bool:
	return _terrain.clear_ranged_lane(to_local(from) + Vector3.UP * 1.6, to_local(to) + Vector3.UP * 1.6)


func _step_patrol(delta: float) -> void:
	var budget := PATROL_SPEED * delta
	if not _patrol_intent:
		var point := _patrol_east if _patrol_eastbound else _patrol_west
		if _move_actor(_patrol, point, budget, true):
			_patrol_eastbound = not _patrol_eastbound
		return
	if not _patrol_joined:
		_patrol_joined = _move_actor(_patrol, _post_route[0], budget, true)
		return
	# A held platoon at the actual choke forces the foot patrol to back out
	# along its route, not teleport away or vanish when the Hold key is hit.
	var screened := _held_near(_point("Routes/PostRoadApproach"), SCREEN_RADIUS) or _allied_in_yard()
	var destination := _post_road_distance if screened else _post_route_length
	var next := move_toward(_patrol_distance, destination, budget)
	if _move_actor(_patrol, _route_sample(_post_route, next), budget, true):
		_patrol_distance = next


func _step_mounted(delta: float) -> void:
	if objective.reserve == Writ.Reserve.UNALERTED or _next_mount >= _mounted_route.size():
		return
	if _next_mount > ROAD_COMMIT_INDEX and _held_near(_reserve.global_position, SCREEN_RADIUS + 1.1):
		return
	if _move_actor(_reserve, _mounted_route[_next_mount], MOUNTED_SPEED * delta, true):
		_next_mount += 1


func _move_actor(actor: Node3D, destination: Vector3, budget: float, formation: bool) -> bool:
	var start := actor.global_position
	var next := start.move_toward(destination, budget)
	if not _terrain.can_move(_flat(start), _flat(next), formation):
		return false
	var heading := next - start
	if heading.length_squared() >= 0.000001:
		actor.rotation.y = atan2(-heading.x, -heading.z)
	actor.global_position = next
	return next.is_equal_approx(destination)


func _route_sample(points: PackedVector3Array, at: float) -> Vector3:
	var remaining := at
	for i in range(1, points.size()):
		var length := points[i - 1].distance_to(points[i])
		if remaining <= length:
			return points[i - 1].lerp(points[i], remaining / length)
		remaining -= length
	return points[-1]


func _held_near(world: Vector3, radius: float) -> bool:
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD and to_global(_ground(formation.position)).distance_to(world) <= radius:
			return true
	return false


func _allied_in_yard() -> bool:
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD and _yard.has_point(_ground(formation.position, 0.8)):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and not event.echo and event.pressed:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view:
			_offer_pressed = true
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_offer_pressed = true
			return
	if objective.phase not in [Writ.Phase.SUCCEEDED, Writ.Phase.FAILED]:
		super._unhandled_input(event)


func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_offer_pressed = false


## Reserved for a confirmed casualty from a future battle/combat adapter.
func report_sereth_fell() -> void:
	_sereth_fell = true


func _build_placeholders() -> void:
	_name_platoons()
	super._build_placeholders()


func _name_platoons() -> void:
	battle.formations[0].title = "Household Foot"
	battle.formations[1].title = "Court Foot"


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_platoons()
	_sync_view()
	_reset_attempt()


func _reset_attempt() -> void:
	_keeper.global_position = _keeper_home
	_patrol.global_position = _patrol_east
	_reserve.global_position = _mounted_route[0]
	for party in [_keeper, _patrol, _reserve]:
		party.rotation.y = 0.0
	_patrol_intent = false
	_patrol_joined = false
	_patrol_eastbound = false
	_patrol_distance = 0.0
	_next_mount = 1
	_lookout_contact = 0.0
	_courier_seen = 0.0
	_scout_spotted = false
	_offer_pressed = false
	_sereth_fell = false
	_refresh(hero_world_position(), false, false)


func _refresh(hero: Vector3, occupied: bool, seen: bool) -> void:
	var sign_scale := 0.047 if command_view and _sector.overview else 0.030 if command_view else 0.008
	for label in _debug_labels:
		label.pixel_size = sign_scale
	_reserve.visible = objective.reserve != Writ.Reserve.UNALERTED
	_reserve_flag.visible = _reserve.visible
	_reserve_flag.global_position = _reserve.global_position
	_lookout_flag.visible = _scout_spotted
	_rally_flag.visible = objective.audience_granted
	_keeper.visible = objective.failure != Writ.Failure.KEEPER_DRIVEN_AWAY
	_writ.visible = objective.failure != Writ.Failure.SERETH_FELL
	_writ.global_position = (_keeper if objective.audience_granted else _hero).to_global(Vector3(0.39, 1.09, -0.15))
	_keeper_text.text = "Keeper: neutral · the writ requests a hearing only."
	_hint.text = "Use the covered sheep track or screen the road. Cross / Space at the handover."
	match objective.reserve:
		Writ.Reserve.UNALERTED:
			_pressure.text = "Lookout has sight · %d%% to signal." % roundi(100.0 * minf(_lookout_contact / WARNING_SECONDS, 1.0)) \
				if seen else "Mounted reserve unalerted. High bank can spot the lookout."
		Writ.Reserve.ALERTED:
			_pressure.text = "LOOKOUT SIGNAL · Mounted reserve is moving toward the road."
		Writ.Reserve.COMMITTED:
			_pressure.text = "Mounted reserve on the road. Brace, keep cover or reroute."
	if occupied:
		_pressure.text = "POST OCCUPIED · %.1f s to break the hold." % \
			maxf(Writ.POST_OCCUPATION_LIMIT_SECONDS - objective.post_occupation_seconds, 0.0) \
			if objective.post_occupation_warned else "POST CONTESTED · Screen the approach to push the patrol back."
	elif _patrol_intent and not objective.audience_granted:
		_hint.text = "The foot patrol approaches. Hold a platoon at the marked post approach."
	match objective.phase:
		Writ.Phase.CARRYING_WRIT:
			_goal.text = "Carry the writ to the neutral Keeper"
			if hero.distance_to(_handover) <= CONTACT and not occupied:
				_hint.text = "Cross / Space in hero view to offer the writ."
		Writ.Phase.AWAITING_KEEPER:
			_goal.text = "Wait for the Keeper to take the writ"
			_keeper_text.text = "Keeper: stepping up to receive the writ."
			_hint.text = "Stay near the handover. Leaving or contesting the post interrupts it."
		Writ.Phase.WITHDRAWING:
			_goal.text = "Audience granted · withdraw to the west rally"
			_keeper_text.text = "Keeper: I will hear the court at the valley assembly. No entry to the vault."
			_hint.text = "Reach the rally along either route. The mounted reserve need not be defeated."
		Writ.Phase.SUCCEEDED:
			_goal.text = "Sereth withdrew with a hearing granted"
			_keeper_text.text = "The court may be heard; this grants no custody or consent from the dead."
			_pressure.text = ""
			_hint.text = "Trial complete. Backspace / Options to retry."
		Writ.Phase.FAILED:
			_goal.text = "The Keeper was driven away" if objective.failure == Writ.Failure.KEEPER_DRIVEN_AWAY else "Sereth fell"
			_keeper_text.text = "No hearing can be secured in this attempt." if not objective.audience_granted \
				else "The earlier reply did not secure Sereth’s withdrawal."
			_pressure.text = ""
			_hint.text = "Backspace / Options to retry."


func _point(id: String) -> Vector3:
	return battlefield_marker(NodePath("Markers/" + id)).global_position


func _flat(world: Vector3) -> Vector2:
	var local := to_local(world)
	return Vector2(local.x, local.z)


## Scenario position cues only: generic harness boxes/rings, not runtime art.
func _debug_party(title: String, tint: Color, count: int, mounted := false) -> Node3D:
	var group := Node3D.new()
	group.name = title.replace(" ", "")
	$DebugPlaytestVisuals.add_child(group)
	var debug_material := _material(tint)
	var size := Vector3(0.68, 1.8, 1.35) if mounted else Vector3(0.55, 1.55, 0.50)
	var spread := 1.75 if mounted else 1.05
	for i in range(count):
		var point := Vector3((i % 2 - 0.5) * spread, 0, (floori(i / 2.0) - 0.5) * spread) if count > 1 else Vector3.ZERO
		_mesh(group, _box(size), debug_material, point + Vector3.UP * (size.y * 0.5))
	return group


func _debug_marker(point: Vector3, title: String, tint: Color) -> Node3D:
	var node := Node3D.new()
	$DebugPlaytestVisuals.add_child(node)
	node.global_position = point
	_mesh(node, _ring(1.42, 1.56), _material(tint, true), Vector3.UP * 0.05)
	var label := Label3D.new()
	label.text = title
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.outline_size = 5
	_debug_labels.append(label)
	node.add_child(label)
	label.position.y = 2.5
	return node


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions([_patrol, _reserve])
