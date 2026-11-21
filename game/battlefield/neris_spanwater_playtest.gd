extends "res://game/battlefield/command_harness.gd"
## The local lane shares Spanwater's geometry, not other campaigns' win states.
## Terrain-probed actors and two visible water fronts drive the objective.
## The March patrol interdicts the work site; it does not deal combat damage.

signal mission_finished(won: bool)

const Feeder := preload("res://game/battlefield/neris_spanwater_feeder.gd")
const WARNING_AT := 22.0
const RELEASE_AT := 32.0
const CREST_DELAY := 24.0
const RIVER_SPEED := 13.0
const INLET_SPEED := 8.0
const DOWNSTREAM_SPEED := 6.5
const GAUGE_SECONDS := 7.0
const PATROL_AT := 8.0
const PATROL_SPEED := 5.7
const CREW_SPEED := 4.5
const BOARD_SECONDS := 13.0
const RACK_REACH := 2.8
const HIDE_RACK_CAPTIONS_WITHIN := 7.5
const SHOW_RACK_CAPTIONS_BEYOND := 13.0
const JAM_PATROL_NEAR_SIZE := 0.011
const CONTEST_RADIUS := 5.0
const SCREEN_RADIUS := 4.5
const WATER := Color("#509fc9")
const FRIENDLY := Color("#a6dfbb")
const ALERT := Color("#f1b277")
# Follow the existing low feeder bed, under the causeway, through the rack.
const FEEDER_SOURCE := Vector3(-108.0, 0.22, -19.5)
const FEEDER_BEND := Vector3(-108.0, 0.22, -73.0)

var objective := Feeder.new()
var _elapsed := 0.0
var _interact := false
var _neris_fell := false
var _rack_point: Vector2
var _screen_point: Vector2
var _gauge: Marker3D
var _crew: Node3D
var _crew_route := PackedVector2Array()
var _crew_next := 0
var _patrol: Node3D
var _patrol_start: Vector2
var _screened := false
var _contested := false
var _ford_rect: Rect2
var _ford_ceiling := 0.0
var _ford_closed := false

var _river_start: Vector3
var _river_end: Vector3
var _river_length := 0.0
var _river_metres := 0.0
var _rack_water: Vector3
var _gauge_water: Vector3
var _inlet_length := 0.0
var _inlet_metres := 0.0
var _channel_metres := 0.0
var _crest_metres := 0.0
var _river_visual: MeshInstance3D
var _inlet_visual: MeshInstance3D
var _bend_visual: MeshInstance3D
var _channel_visual: MeshInstance3D
var _crest_visual: MeshInstance3D
var _gauge_float: MeshInstance3D
var _silt: Node3D
var _boards: Array[MeshInstance3D] = []
var _rack_sign: Label3D
var _crew_sign: Label3D
var _patrol_sign: Label3D
var _patrol_sign_size: float
var _rack_caption_opacity := -1.0
var _rack_caption_outline: Color
var _screen_sign: Label3D
var _gauge_sign: Label3D

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _status: Label = $ObjectiveHUD/Panel/Margin/Readout/Status
@onready var _cue: Label = $ObjectiveHUD/Panel/Margin/Readout/Cue
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_rack_point = _point("Objectives/FeederInletRack")
	_gauge = _mark("Objectives/TownGauge")
	_patrol_start = _point("Routes/FeederMaintenanceBend")
	_screen_point = _rack_point.move_toward(_patrol_start, 10.0)
	_crew_route = PackedVector2Array([_point("Routes/FeederPathWest"), _rack_point])
	var ford := _mark("PhaseZones/LowCrossingClosure")
	var half: Vector3 = ford.get_meta("box_size") * 0.5
	var footprint := Vector2(half.x, half.z)
	_ford_rect = Rect2(_marker_position(ford) - footprint, footprint * 2.0)
	_ford_ceiling = to_local(ford.global_position).y + half.y
	_river_start = to_local(_mark("Routes/ReleaseSweepStart").global_position) + Vector3.UP * 0.22
	_river_end = to_local(_mark("Routes/ReleaseSweepEnd").global_position) + Vector3.UP * 0.22
	_river_length = _river_start.distance_to(_river_end)
	_rack_water = Vector3(_rack_point.x, FEEDER_BEND.y, FEEDER_BEND.z)
	_gauge_water = Vector3(_marker_position(_gauge).x, FEEDER_BEND.y, FEEDER_BEND.z)
	_inlet_length = FEEDER_SOURCE.distance_to(FEEDER_BEND) + FEEDER_BEND.distance_to(_rack_water)
	_build_worksite()
	_restart.pressed.connect(restart_mission)
	_reset_attempt()


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _physics_process(delta: float) -> void:
	if not _finished():
		super._physics_process(delta)


func _update_mode() -> void:
	super._update_mode()
	_refresh_rack_captions()


func _after_battle_step(delta: float) -> void:
	var previous := _elapsed
	_elapsed += delta
	var observation := Feeder.Observation.new()
	observation.neris_fell = _neris_fell
	observation.rack_interaction_confirmed = _interact and not command_view and _near_rack()
	_interact = false
	if not _neris_fell:
		_step_people(delta)
		observation.maintenance_contested = _contested
		if _screened and not _contested and _crew_next == _crew_route.size():
			observation.board_credit = delta / BOARD_SECONDS
		_step_water(previous, observation)
	objective.advance(observation)
	_refresh()
	if _finished():
		mission_finished.emit(objective.phase == Feeder.Phase.SUCCEEDED)


func _step_people(delta: float) -> void:
	_screened = false
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD and formation.position.distance_to(_screen_point) <= SCREEN_RADIUS:
			_screened = true
			break
	_patrol.visible = _elapsed >= PATROL_AT
	if _patrol.visible:
		_step_actor(_patrol, _patrol_start if _screened else _rack_point, PATROL_SPEED * delta)
	_contested = _patrol.visible and _xz(_patrol.position).distance_to(_rack_point) <= CONTEST_RADIUS
	if not _contested and _crew_next < _crew_route.size():
		if _step_actor(_crew, _crew_route[_crew_next], CREW_SPEED * delta):
			_crew_next += 1


func _step_actor(actor: Node3D, destination: Vector2, distance: float) -> bool:
	var from := _xz(actor.position)
	while from != destination and distance > 0.0:
		var step := minf(0.20, distance)
		var next := from.move_toward(destination, step)
		if not _can_move_in_lane(from, next, false):
			return false
		actor.position = _ground(next)
		var heading := next - from
		actor.rotation.y = atan2(-heading.x, -heading.y)
		from = next
		distance -= step
	return from == destination


func _step_water(previous: float, frame: Feeder.Observation) -> void:
	if _elapsed < RELEASE_AT:
		return
	frame.spillway_release_started = previous < RELEASE_AT
	var released_delta := _elapsed - maxf(previous, RELEASE_AT)
	_river_metres = minf(_river_length, _river_metres + released_delta * RIVER_SPEED)
	_ford_closed = _river_metres >= _river_length
	frame.river_at_stage = _ford_closed
	var inlet_was_at_rack := _inlet_metres >= _inlet_length
	_inlet_metres = minf(_inlet_length, _inlet_metres + released_delta * INLET_SPEED)
	frame.debris_pulse_reached_rack = _inlet_metres >= _inlet_length and not inlet_was_at_rack
	var old_crest := _crest_metres
	var crest_delta := maxf(0.0, _elapsed - maxf(previous, RELEASE_AT + CREST_DELAY))
	_crest_metres = minf(_inlet_length, _crest_metres + crest_delta * INLET_SPEED)
	frame.crest_reached_feeder = _crest_metres >= _inlet_length and old_crest < _inlet_length
	if inlet_was_at_rack and objective.rack == Feeder.Rack.CLEAR and objective.board_progress >= 1.0:
		var channel_length := _rack_water.distance_to(_gauge_water)
		var to_gauge := (channel_length - _channel_metres) / DOWNSTREAM_SPEED
		_channel_metres = minf(channel_length, _channel_metres + released_delta * DOWNSTREAM_SPEED)
		frame.water_at_gauge = _channel_metres >= channel_length
		frame.gauge_credit = maxf(0.0, released_delta - to_gauge) / GAUGE_SECONDS
	else:
		_channel_metres = 0.0


func _movement_check() -> Callable:
	return _can_move_in_lane


func _can_move_in_lane(from: Vector2, to: Vector2, is_formation: bool) -> bool:
	if _ford_closed:
		var depth := _ford_depth(to)
		if depth > 0.0 and depth >= _ford_depth(from):
			# Units already in the footprint can retreat but not enter or go deeper.
			return false
	return _terrain.can_move(from, to, is_formation)


func _ford_depth(point: Vector2) -> float:
	if not _ford_rect.has_point(point) or _terrain.ground_height(point) >= _ford_ceiling:
		return 0.0
	var a := point - _ford_rect.position
	var b := _ford_rect.end - point
	return maxf(0.0, minf(minf(a.x, a.y), minf(b.x, b.y)))


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view and not _finished():
			_interact = true
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view and not _finished():
			_interact = true
			return
	if not _finished():
		super._unhandled_input(event)


## Future combat can report a genuine hero defeat. The graybox patrol cannot.
func report_neris_fell() -> void:
	_neris_fell = true


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_formations()
	_reset_attempt()
	_sync_view()


func _reset_attempt() -> void:
	_elapsed = 0.0
	_neris_fell = false
	_interact = false
	_ford_closed = false
	_river_metres = 0.0
	_inlet_metres = 0.0
	_channel_metres = 0.0
	_crest_metres = 0.0
	_crew_next = 0
	_crew.position = to_local(_mark("Spawns/DryadCrew").global_position) + Vector3(2.0, 0.0, -2.0)
	_crew.rotation.y = -PI / 2.0
	_patrol.position = to_local(_mark("Routes/FeederMaintenanceBend").global_position)
	_patrol.rotation.y = PI / 2.0
	_patrol.hide()
	_screened = false
	_contested = false
	_refresh()


func _build_worksite() -> void:
	_crew = _people("TownBoardCrew", FRIENDLY)
	_crew_sign = _sign(_crew, "TOWN BOARD CREW", FRIENDLY, 2.1)
	_rack_caption_outline = _crew_sign.outline_modulate
	_patrol = _people("MarchPatrol", ALERT)
	_patrol_sign = _sign(_patrol, "MARCH PATROL", ALERT, 2.1)
	_patrol_sign_size = _patrol_sign.pixel_size
	var rack_pose := to_local(_mark("Objectives/FeederInletRack").global_position)
	_rack_sign = _beacon(rack_pose, FRIENDLY)
	_screen_sign = _beacon(Vector3(_screen_point.x, rack_pose.y, _screen_point.y), ALERT)
	_screen_sign.text = "HOLD · WORK SCREEN"
	_gauge_sign = _beacon(to_local(_gauge.global_position), WATER.lightened(0.28))
	for item in range(4):
		_boards.append(_mesh(self, _box(Vector3(1.8, 0.22, 0.38)), _material(Color("#b38255")), Vector3.ZERO))
	_silt = Node3D.new()
	_silt.name = "RackBlockage"
	add_child(_silt)
	_silt.position = _rack_water
	for index in range(4):
		var log_piece := _mesh(_silt, _box(Vector3(0.50, 0.57, 2.8)), _material(Color("#80563b")),
			Vector3(-0.52, 0.4 + index * 0.07, -4.2 + 2.8 * index))
		log_piece.rotation.y = (index - 1.5) * 0.21
	_river_visual = _water_piece("RiverFront")
	_inlet_visual = _water_piece("UpstreamFeederWater")
	_bend_visual = _water_piece("FeederBendWater")
	_channel_visual = _water_piece("DownstreamFeederWater")
	_crest_visual = _mesh(self, _box(Vector3(4.2, 0.28, 4.2)), _material(Color("#d2eaff"), true), Vector3.ZERO)
	_crest_visual.name = "CrestFront"
	_gauge_float = _mesh(self, _box(Vector3(1.45, 0.24, 0.28)), _material(WATER.lightened(0.3), true), Vector3.ZERO)
	_gauge_float.name = "TownGaugeFloat"


func _refresh() -> void:
	var inlet_first := FEEDER_SOURCE.distance_to(FEEDER_BEND)
	_paint_water(_river_visual, _river_start, _river_end, _river_metres, 12.0)
	_paint_water(_inlet_visual, FEEDER_SOURCE, FEEDER_BEND, minf(inlet_first, _inlet_metres), 9.0)
	_paint_water(_bend_visual, FEEDER_BEND, _rack_water, maxf(0.0, _inlet_metres - inlet_first), 9.0)
	_paint_water(_channel_visual, _rack_water, _gauge_water, _channel_metres, 9.0)
	_crest_visual.visible = _crest_metres > 0.0 and _crest_metres < _inlet_length
	_crest_visual.position = (FEEDER_SOURCE.move_toward(FEEDER_BEND, _crest_metres) if _crest_metres < inlet_first
		else FEEDER_BEND.move_toward(_rack_water, _crest_metres - inlet_first)) + Vector3.UP * 0.22
	_gauge_float.position = to_local(_gauge.global_position) + Vector3(0, 1.05 + objective.gauge_progress * 1.55, 3.25)
	for i in range(_boards.size()):
		var fixed := clampf(objective.board_progress * _boards.size() - i, 0.0, 1.0)
		var carried := _crew.position + Vector3(0.56 + i * 0.30, 0.75 + i * 0.09, -0.35)
		var slot := _rack_water + Vector3(2.1 + i * 2.0, 0.68, -3.75)
		_boards[i].position = carried.lerp(slot, fixed)
		_boards[i].rotation.y = lerpf(0.0, 0.25, fixed)
	_silt.visible = objective.rack != Feeder.Rack.CLEAR
	_silt.scale.y = 1.6 if objective.rack == Feeder.Rack.DEBRIS_JAM else 1.0
	_rack_sign.text = "INLET RACK" if not _silt.visible else ("DEBRIS AT THE RACK" if objective.rack == Feeder.Rack.DEBRIS_JAM else "CLEAR THE INLET RACK")
	(_screen_sign.get_parent() as Node3D).visible = not _finished() and objective.board_progress < 1.0
	_gauge_sign.text = "TOWN GAUGE · %d%%" % floori(objective.gauge_progress * 100.0)
	_refresh_rack_captions()
	_refresh_readout()


## Near the active rack, clear only the two friendly work cues. During a
## contested jam, keep the orange threat name readable without covering the
## nearby worksite or adjacent formation name. No tactical glyph is changed.
func _refresh_rack_captions() -> void:
	if not _rack_sign or not _crew_sign or not _patrol_sign:
		return
	var opacity := 1.0
	if not command_view:
		var rack := (_rack_sign.get_parent() as Node3D).global_position
		var distance := hero_world_position().distance_to(rack)
		opacity = smoothstep(HIDE_RACK_CAPTIONS_WITHIN, SHOW_RACK_CAPTIONS_BEYOND, distance)
	var patrol_size := _patrol_sign_size
	if objective.phase == Feeder.Phase.CLEAR_DEBRIS and _contested:
		patrol_size = lerpf(JAM_PATROL_NEAR_SIZE, _patrol_sign_size, opacity)
	if not is_equal_approx(_patrol_sign.pixel_size, patrol_size):
		_patrol_sign.pixel_size = patrol_size
	if opacity == _rack_caption_opacity:
		return
	_rack_caption_opacity = opacity
	for label: Label3D in [_rack_sign, _crew_sign]:
		label.visible = opacity > 0.0
		label.modulate = Color(FRIENDLY, FRIENDLY.a * opacity)
		label.outline_modulate = Color(_rack_caption_outline, _rack_caption_outline.a * opacity)


func _refresh_readout() -> void:
	var phase := objective.phase
	match phase:
		Feeder.Phase.CLEAR_INLET, Feeder.Phase.CLEAR_DEBRIS:
			_goal.text = "Clear fresh debris at the rack" if phase == Feeder.Phase.CLEAR_DEBRIS else "Clear the feeder inlet rack"
			_status.text = "Clear the inlet rack."
			if _contested:
				_status.text = "The patrol is at the rack. Put a platoon on the marked screen before trying again."
			elif command_view:
				_status.text = "Neris must clear the rack."
		Feeder.Phase.FIT_BOARDS:
			_goal.text = "Protect the town board crew  ·  %d%%" % floori(objective.board_progress * 100.0)
			if _contested:
				_status.text = "The March patrol reached the worksite. Hold a platoon at the marked screen."
			elif _screened and _crew_next < _crew_route.size():
				_status.text = "Screen holding. The town crew is bringing boards to the rack."
			elif _screened:
				_status.text = "Screen holding. The town crew is fitting the guide boards."
			else:
				_status.text = "The crew is waiting for a platoon to hold the marked screen."
		Feeder.Phase.RAISE_GAUGE:
			_goal.text = "Bring water to the town gauge  ·  %d%%" % floori(objective.gauge_progress * 100.0)
			_status.text = "Follow the feeder downstream. The town gauge rises only once water reaches it."
		Feeder.Phase.SUCCEEDED:
			_goal.text = "Water reached the town mark"
			_status.text = "The volunteers hand the working gauge back to the town."
		Feeder.Phase.FAILED:
			_goal.text = "The feeder mission failed"
			_status.text = "Neris fell." if objective.failure == Feeder.Failure.NERIS_FELL else "The crest buried the unready feeder."
	_cue.text = ""
	if not _finished():
		if _crest_metres >= _inlet_length:
			_cue.text = "The crest passed. The low ford is closed; use the raised path."
		elif _crest_metres > 0.0:
			_cue.text = "Crest approaching the rack  ·  %ds. The boards and rack must be ready first." % ceili((_inlet_length - _crest_metres) / INLET_SPEED)
		elif objective.released:
			_cue.text = "Spillway open. The sea gate remains shut." + (" The low ford is closed." if _ford_closed else "")
		elif _elapsed >= WARNING_AT:
			_cue.text = "Spillway release warning  ·  %ds. Clear the low ford." % ceili(RELEASE_AT - _elapsed)


func _people(node_name: String, color: Color) -> Node3D:
	var actor := Node3D.new()
	actor.name = node_name
	add_child(actor)
	var clothes := _material(color)
	for index in range(3):
		var offset := (index - 1.0) * 0.88
		_mesh(actor, _box(Vector3(0.54, 1.14, 0.50)), clothes, Vector3(offset, 0.60, 0.0))
		_mesh(actor, _box(Vector3(0.36, 0.35, 0.36)), clothes, Vector3(offset, 1.32, 0.0))
	return actor


func _beacon(point: Vector3, color: Color) -> Label3D:
	var node := Node3D.new()
	add_child(node)
	node.position = point
	_mesh(node, _ring(1.45, 1.63), _material(color, true), Vector3.UP * 0.06)
	return _sign(node, "", color, 2.9)


func _sign(parent: Node3D, title: String, color: Color, height: float) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.modulate = color
	label.outline_size = 10
	label.pixel_size = 0.027
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position.y = height
	return label


func _water_piece(title: String) -> MeshInstance3D:
	var visual := _mesh(self, _box(Vector3(1.0, 0.035, 1.0)), _material(WATER, true), Vector3.ZERO)
	visual.name = title
	return visual


func _paint_water(visual: MeshInstance3D, start: Vector3, end: Vector3, length: float, width: float) -> void:
	visual.visible = length > 0.0
	if visual.visible:
		var heading := (end - start).normalized()
		visual.position = start + heading * length * 0.5
		visual.rotation.y = atan2(-heading.z, heading.x)
		visual.scale = Vector3(length, 1.0, width)


func _name_formations() -> void:
	battle.formations[0].title = "Dryad Guard"
	battle.formations[1].title = "Feeder Reserve"


func _mark(path: String) -> Marker3D:
	return battlefield_marker(NodePath("Markers/" + path))


func _point(path: String) -> Vector2:
	return _marker_position(_mark(path))


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _near_rack() -> bool:
	return hero_world_position().distance_to(to_global(_ground(_rack_point))) <= RACK_REACH


func _finished() -> bool:
	return objective.phase in [Feeder.Phase.SUCCEEDED, Feeder.Phase.FAILED]


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions([_patrol])
