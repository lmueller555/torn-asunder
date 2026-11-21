extends "res://game/battlefield/command_harness.gd"

const CharacterArt := preload("res://game/battlefield/raska_campaign_character_art.gd")
## Campaign-scale graybox for Raska's Spanwater release. Motion and control are
## observable world conditions; neither the water ribbon nor troops model fluid or damage.

signal mission_finished(won: bool)

const Release := preload("res://game/battlefield/raska_spanwater_release.gd")
const DEFENDERS := ^"Markers/Routes/MarchCounterattackApproach"
const WITHDRAWAL_EXIT := ^"Markers/Routes/OrcWithdrawalExit"
const SWEEP_START := ^"Markers/Routes/ReleaseSweepStart"
const SWEEP_END := ^"Markers/Routes/ReleaseSweepEnd"
const LOW_CROSSING := ^"Markers/PhaseZones/LowCrossingClosure"
const REGULARS := "Basin Regulars"
const LOWER_TOWNS := "Lower-town Companies"
const HOLD_RADIUS := 3.6
const SCREEN_RADIUS := 8.0
const CONTEST_RADIUS := 5.0
const STANDOFF_METRES := 3.25
const WHEEL_INTERACT := 2.2
const EXIT_RADIUS := 2.8
const MARCH_SPEED := 4.0
const WITHDRAW_SPEED := 4.0
const FLOW_SPEED := 13.0
const ROUTE_SAMPLE := 1.1

@export var flow_width := 12.0

var objective := Release.new()
var _wheel: Vector2
var _exit: Vector2
var _march_staging: Vector2
var _march_distance := 0.0
var _march_line_length := 0.0
var _withdrawal_exit: Vector2
var _support_trail := PackedVector2Array()
var _withdrawal_route := PackedVector2Array()
var _withdrawal_step := 0
var _withdrawal_count := 0
var _crossing_closed := false
var _crossing_rect: Rect2
var _crossing_ceiling := 0.0
var _flow_start: Vector3
var _flow_end: Vector3
var _flow_length := 0.0
var _interact := false

var _flow: MeshInstance3D
var _march_proxy: Node3D
var _wheel_zone: MeshInstance3D
var _wheel_ready_material: StandardMaterial3D
var _wheel_contested_material: StandardMaterial3D
var _wheel_beacon: Node3D
var _exit_beacon: Node3D
var _crossing_beacon: Node3D
var _departure_label: Label3D

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _hint: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _situation: Label = $ObjectiveHUD/Panel/Margin/Readout/Situation
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_wheel = _marker_ground(Release.SPILLWAY_WHEEL)
	_exit = _marker_ground(Release.HIGH_BANK_EXIT)
	_march_staging = _marker_ground(DEFENDERS)
	_march_line_length = _wheel.distance_to(_march_staging)
	_withdrawal_exit = _marker_ground(WITHDRAWAL_EXIT)
	var crossing := battlefield_marker(LOW_CROSSING)
	var extents: Vector3 = crossing.get_meta("box_size") * 0.5
	var at := _marker_position(crossing)
	_crossing_rect = Rect2(at - Vector2(extents.x, extents.z), Vector2(extents.x, extents.z) * 2.0)
	_crossing_ceiling = to_local(crossing.global_position).y + extents.y
	_flow_start = _marker_floor(SWEEP_START)
	_flow_end = _marker_floor(SWEEP_END)
	_flow_length = maxf(1.0, _flow_start.distance_to(_flow_end))
	_build_objective_proxies(at)
	objective.lower_towns_withdrawal_ordered.connect(_begin_withdrawal)
	objective.high_bank_unlocked.connect(_close_crossing)
	_restart.pressed.connect(restart_mission)
	_reset_attempt()
	CharacterArt.attach(self)


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _physics_process(delta: float) -> void:
	if not _finished():
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	_record_support_trail()
	var hold := _orc_near_wheel(HOLD_RADIUS)
	var screen := _orc_near_wheel(SCREEN_RADIUS)
	_advance_march(delta, hold, screen)
	_advance_withdrawal(delta)
	var observation := Release.Observation.new()
	observation.wheel_control = _wheel_control(hold)
	observation.raska_opens_spillway = _interact and not command_view and _hero_within(_wheel, WHEEL_INTERACT)
	var remaining := _flow_length * (1.0 - objective.release_progress)
	observation.river_credit = minf(remaining, FLOW_SPEED * delta) / _flow_length
	observation.shutdown_confirmed = objective.withdrawal_ordered and not screen and is_zero_approx(_march_distance)
	observation.raska_at_high_bank = _hero_within(_exit, EXIT_RADIUS)
	_interact = false
	objective.advance(observation)
	_refresh_objective(observation.wheel_control)
	if _finished():
		mission_finished.emit(objective.phase == Release.Phase.SUCCEEDED)


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view:
			_interact = true
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact = true
			return
	if not _finished():
		super._unhandled_input(event)


func _movement_check() -> Callable:
	return _can_move_on_spanwater


func _can_move_on_spanwater(from: Vector2, to: Vector2, is_formation: bool) -> bool:
	if _crossing_closed:
		var depth := _crossing_depth(to)
		if depth > 0.0 and depth >= _crossing_depth(from):
			# Traffic already caught in the zone can leave, but cannot enter or go deeper.
			return false
	return _terrain.can_move(from, to, is_formation)


func _crossing_depth(point: Vector2) -> float:
	if not _crossing_rect.has_point(point) or _terrain.ground_height(point) >= _crossing_ceiling:
		return 0.0
	var edge := point - _crossing_rect.position
	var far := _crossing_rect.end - point
	return maxf(0.0, minf(minf(edge.x, edge.y), minf(far.x, far.y)))


func _hero_within(point: Vector2, radius: float) -> bool:
	return _ground(battle.hero_position).distance_to(_ground(point)) <= radius


func _orc_near_wheel(radius: float) -> bool:
	for group in battle.formations:
		if group.order != Battle.Order.DEFEATED and _ground(group.position).distance_to(_ground(_wheel)) <= radius:
			return true
	return false


func _wheel_control(hold: bool) -> Release.WheelControl:
	if _march_distance < CONTEST_RADIUS:
		return Release.WheelControl.CONTESTED
	return Release.WheelControl.SECURED if hold else Release.WheelControl.UNSECURED


func _advance_march(delta: float, hold: bool, screen: bool) -> void:
	if objective.phase >= Release.Phase.EXTRACT:
		return
	var destination := 0.0
	if hold:
		destination = _march_line_length
	elif screen:
		# A screen can stop the detachment short of the wheel indefinitely,
		# but only closing the formation onto the wheel pushes them back.
		destination = STANDOFF_METRES
	var next_distance := move_toward(_march_distance, destination, MARCH_SPEED * delta)
	var from := _wheel.move_toward(_march_staging, _march_distance)
	var next := _wheel.move_toward(_march_staging, next_distance)
	if _terrain.can_move(from, next, false):
		_march_distance = next_distance
		_march_proxy.position = _ground(next)


func _record_support_trail() -> void:
	if battle.formations.size() < 2:
		return
	var position := battle.formations[1].position
	if _support_trail.is_empty() or position.distance_to(_support_trail[-1]) >= ROUTE_SAMPLE:
		_support_trail.append(position)


func _begin_withdrawal() -> void:
	_withdrawal_count += 1
	var support: Battle.Formation = battle.formations.pop_back()
	selected_index = 0
	_departure_label.visible = true
	_departure_label.text = "LOWER TOWNS WITHDRAWING"
	# Retrace the route already walked instead of cutting across walls or the ford.
	_withdrawal_route = _support_trail.duplicate()
	_withdrawal_route.reverse()
	_withdrawal_route.append(_withdrawal_exit)
	_withdrawal_step = 0
	_formation_models[1].position = _ground(support.position)


func _advance_withdrawal(delta: float) -> void:
	if _withdrawal_step >= _withdrawal_route.size():
		return
	var model := _formation_models[1]
	var from := Vector2(model.position.x, model.position.z)
	var waypoint := _withdrawal_route[_withdrawal_step]
	var next := from.move_toward(waypoint, WITHDRAW_SPEED * delta)
	var offset := next - from
	if not offset.is_zero_approx():
		model.rotation.y = atan2(-offset.x, -offset.y)
	model.position = _ground(next)
	if next == waypoint:
		_withdrawal_step += 1
		if _withdrawal_step == _withdrawal_route.size():
			model.hide()


func _close_crossing() -> void:
	_crossing_closed = true


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	_name_formations()
	_reset_attempt()
	_sync_view()


func _reset_attempt() -> void:
	_crossing_closed = false
	_withdrawal_count = 0
	_withdrawal_route.clear()
	_support_trail.clear()
	_formation_models[1].show()
	_departure_label.hide()
	_record_support_trail()
	_interact = false
	_march_distance = 0.0
	_march_proxy.position = _ground(_wheel)
	_refresh_objective(Release.WheelControl.CONTESTED)


func _name_formations() -> void:
	battle.formations[0].title = REGULARS
	battle.formations[1].title = LOWER_TOWNS


func _finished() -> bool:
	return objective.phase in [Release.Phase.SUCCEEDED, Release.Phase.FAILED]


func _refresh_objective(control: Release.WheelControl) -> void:
	var fraction := objective.release_progress
	var travel := _flow_length * fraction
	_flow.visible = travel > 0.0
	if travel > 0.0:
		_flow.position = _flow_start.lerp(_flow_end, fraction * 0.5)
		_flow.scale = Vector3(travel, 1.0, flow_width)
	_crossing_beacon.visible = _crossing_closed
	_exit_beacon.visible = objective.phase == Release.Phase.EXTRACT or objective.phase == Release.Phase.SUCCEEDED
	_wheel_beacon.visible = objective.phase < Release.Phase.EXTRACT
	_wheel_zone.visible = _wheel_beacon.visible
	_wheel_zone.material_override = _wheel_ready_material if control == Release.WheelControl.SECURED else _wheel_contested_material
	_situation.text = "Sea gate stays shut."
	if objective.withdrawal_ordered:
		_situation.text += " Lower-town companies recalled. Low crossing: %s." % ("closed" if _crossing_closed else "open")
	match objective.phase:
		Release.Phase.SECURE_SPILLWAY:
			_goal.text = "Secure the spillway wheel"
			_hint.text = "Follow the raised causeway. Move a formation into the inner wheel ring to push the March guard back."
		Release.Phase.READY_AT_WHEEL:
			_goal.text = "Raska must open the spillway"
			_hint.text = "At the wheel, leave command view and press Cross / Space. The sea gate is not a target."
		Release.Phase.RELEASING:
			_goal.text = "Release to the old riverbed   ·   %d%%" % floori(fraction * 100.0)
			_hint.text = "Keep the regulars at the wheel. The flow reaching the low crossing will close it."
		Release.Phase.PAUSED:
			_goal.text = "Release paused   ·   %d%%" % floori(fraction * 100.0)
			_hint.text = "Regain the wheel. The March guard is %d m from closing it; a nearby screen can stop its advance." % ceili(_march_distance)
		Release.Phase.EXTRACT:
			_goal.text = "River stage reached. Lead Raska to the high bank."
			_hint.text = "Use the raised bank route to the green exit. The low crossing is closed."
		Release.Phase.SUCCEEDED:
			_goal.text = "The Basin river runs again"
			_hint.text = "Raska reached the high bank. The sea gate stayed shut and the lower towns recalled their companies."
		Release.Phase.FAILED:
			_goal.text = "The March guard shut the spillway"
			_hint.text = "It reached the empty wheel. Restart and leave the regulars close enough to screen it."


func _build_objective_proxies(crossing: Vector2) -> void:
	_wheel_beacon = _beacon(_wheel, "SPILLWAY WHEEL", Color("#ffd085"))
	_exit_beacon = _beacon(_exit, "HIGH BANK EXIT", Color("#90e5ba"))
	_crossing_beacon = _beacon(crossing, "LOW CROSSING CLOSED", Color("#9bd6ff"))
	_wheel_ready_material = _material(Color("#90e5ba"), true)
	_wheel_contested_material = _material(Color("#ffc292"), true)
	_wheel_zone = _mesh(self, _ring(HOLD_RADIUS - 0.13, HOLD_RADIUS), _wheel_contested_material, _ground(_wheel, 0.025))
	_march_proxy = Node3D.new()
	add_child(_march_proxy)
	var red := _material(Color("#dd6a52"))
	for i in range(3):
		var x := (i - 1) * 0.80
		_mesh(_march_proxy, _box(Vector3(0.58, 1.52, 0.51)), red, Vector3(x, 0.78, 0))
	_sign(_march_proxy, "MARCH GUARD", Color("#ff9e8a"))
	_departure_label = _sign(_formation_models[1], "", Color("#d2e9b7"), 3.1)
	_flow = _mesh(self, _box(Vector3(1.0, 0.05, 1.0)), _material(Color("#4fa9bb"), true))
	_flow.rotation.y = -atan2(_flow_end.z - _flow_start.z, _flow_end.x - _flow_start.x)


func _marker_ground(path: NodePath) -> Vector2:
	return _marker_position(battlefield_marker(path))


func _marker_floor(path: NodePath) -> Vector3:
	return to_local(battlefield_marker(path).global_position) + Vector3.UP * 0.05


func _beacon(point: Vector2, title: String, color: Color) -> Node3D:
	var beacon := Node3D.new()
	add_child(beacon)
	beacon.position = _ground(point)
	var material := _material(color, true)
	_mesh(beacon, _ring(1.08, 1.18), material, Vector3.UP * 0.05)
	_sign(beacon, title, color, 2.3)
	return beacon


func _sign(parent: Node3D, title: String, color: Color, height := 2.0) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.modulate = color
	label.position.y = height
	label.pixel_size = 0.027
	label.outline_size = 9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
