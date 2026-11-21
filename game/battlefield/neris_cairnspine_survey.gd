extends "res://game/battlefield/command_harness.gd"
## A quiet, Year Two reconnaissance. Ordinary freight signs are evidence of a
## route, not of what may be buried at the far end.

signal mission_finished(won: bool)

const TRACK_CLUE := ^"Markers/Routes/SheepPinch"
const POST_CLUE := ^"Markers/Objectives/WritHandover"
const EXIT := ^"Markers/Routes/EastMarchEdge"
const WATCH_ROUTE: Array[NodePath] = [
	^"Markers/Routes/RoadEastStraight", ^"Markers/Routes/LookoutBendRoad",
	^"Markers/Routes/PostRoadFork", ^"Markers/Routes/PostEastTurn",
]
const REACH := 2.45
const WATCH_SPEED := 4.0
const WATCH_SIGHT_RANGE := 15.0
const INTERCEPT_SECONDS := 3.0
const SAFE := Color("#afe0c1")
const ALERT := Color("#ffad81")

enum Stage { TRACK, POST, EXIT, CLEARED, TURNED_BACK }

var stage := Stage.TRACK
var _interact := false
var _watched_seconds := 0.0
var _watch: Node3D
var _watch_points := PackedVector2Array()
var _watch_target := 1
var _watch_direction := 1
var _beacons: Array[Node3D] = []

@onready var _goal: Label = $SurveyHUD/Panel/Margin/Readout/Goal
@onready var _evidence: Label = $SurveyHUD/Panel/Margin/Readout/Evidence
@onready var _cue: Label = $SurveyHUD/Panel/Margin/Readout/Cue


func _ready() -> void:
	super._ready()
	for path in WATCH_ROUTE:
		_watch_points.append(_marker_position(battlefield_marker(path)))
	_beacons.append(_beacon(TRACK_CLUE, "FREIGHT MARKS", SAFE))
	_beacons.append(_beacon(POST_CLUE, "POSTED FREIGHT SLATE", SAFE))
	_beacons.append(_beacon(EXIT, "EASTERN TURN-OFF", SAFE))
	var rut := _material(Color("#554d39"))
	for side in [-0.68, 0.68]:
		_mesh(_beacons[0], _box(Vector3(2.2, 0.025, 0.14)), rut, Vector3(0, 0.024, side))
	var wood := _material(Color("#957b55"))
	_mesh(_beacons[1], _box(Vector3(0.10, 0.80, 0.10)), wood, Vector3(0, 0.43, 0))
	_mesh(_beacons[1], _box(Vector3(0.91, 0.53, 0.11)), wood, Vector3(0, 0.90, 0))
	for height in [0.77, 0.90, 1.03]:
		_mesh(_beacons[1], _box(Vector3(0.66, 0.025, 0.013)), rut, Vector3(0, height, -0.06))
	_watch = Node3D.new()
	$SurveyVisuals.add_child(_watch)
	var coat := _material(Color("#9b624b"))
	var cap := _material(Color("#d9bb97"))
	for offset in [-0.55, 0.55]:
		_mesh(_watch, _box(Vector3(0.52, 1.13, 0.42)), coat, Vector3(offset, 0.62, 0))
		_mesh(_watch, _box(Vector3(0.34, 0.36, 0.35)), cap, Vector3(offset, 1.35, 0))
	var label := _label(_watch, "ROAD WATCH", ALERT)
	label.position.y = 1.82
	$SurveyHUD/Panel/Margin/Readout/Restart.pressed.connect(restart_mission)
	_reset_survey()


func _place_at_spawns() -> void:
	battle.formations.clear()
	battle.lead.title = "Neris Alder"
	super._place_at_spawns()
	battle.hero_heading = Vector2.RIGHT
	_hero_yaw = -PI * 0.5


func _physics_process(delta: float) -> void:
	if stage < Stage.CLEARED:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	_step_watch(delta)
	var hero := hero_world_position()
	var watching := _watch_has_sight(hero)
	_watched_seconds = _watched_seconds + delta if watching else maxf(0.0, _watched_seconds - 2.0 * delta)
	var prior := stage
	if _watched_seconds >= INTERCEPT_SECONDS:
		stage = Stage.TURNED_BACK
	elif _interact and not command_view and not watching and hero.distance_to(_beacons[stage].global_position) <= REACH:
		stage = (stage + 1) as Stage
	_interact = false
	_refresh_survey(watching)
	if stage != prior and stage >= Stage.CLEARED:
		mission_finished.emit(stage == Stage.CLEARED)


func _step_watch(delta: float) -> void:
	var feet := Vector2(_watch.position.x, _watch.position.z)
	var target := _watch_points[_watch_target]
	var next := feet.move_toward(target, WATCH_SPEED * delta)
	if not _terrain.can_move(feet, next, false):
		return
	_watch.position = _ground(next)
	if next == target:
		if _watch_target == 0 or _watch_target == _watch_points.size() - 1:
			_watch_direction *= -1
		_watch_target += _watch_direction


func _watch_has_sight(hero: Vector3) -> bool:
	return _watch.global_position.distance_to(hero) <= WATCH_SIGHT_RANGE and _terrain.clear_ranged_lane(
		_watch.position + Vector3.UP * 1.5, to_local(hero) + Vector3.UP * 1.5)


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view and stage < Stage.CLEARED:
			_interact = true
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view and stage < Stage.CLEARED:
			_interact = true
			return
	if stage < Stage.CLEARED:
		super._unhandled_input(event)


func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_interact = false


func _sync_view() -> void:
	super._sync_view()
	_selection.hide()
	_destination_marker.hide()
	_formation_label.text = "Neris Alder  ·  Traveling alone"
	if command_view:
		_controls_label.text = "Release L2 / Shift to return to Neris\nR3 / M: overview or sector   ·   L3 / Home: center on Neris"
	else:
		_mode_label.text = "HERO VIEW  /  SCOUTING"
		_controls_label.text = "Left stick / WASD: walk   ·   Right stick / Q E R F: camera\nCross / Space: inspect   ·   L2 / Shift: survey the terrain"


func restart_mission() -> void:
	restart_battle()
	_reset_survey()


func _reset_survey() -> void:
	stage = Stage.TRACK
	_interact = false
	_watched_seconds = 0.0
	_watch_target = 1
	_watch_direction = 1
	_watch.position = _ground(_watch_points[0])
	_refresh_survey(false)


func _refresh_survey(watching: bool) -> void:
	for i in range(_beacons.size()):
		_beacons[i].visible = stage == i
	match stage:
		Stage.TRACK:
			_goal.text = "Follow the sunken track to the freight marks."
			_evidence.text = "Look for evidence that carters use the cut."
			_cue.text = "The track walls hide Neris from the road watch."
		Stage.POST:
			_goal.text = "Inspect the freight slate at the boundary post."
			_evidence.text = "Fresh wheel ruts run east through the narrow track."
			_cue.text = "Wait by the east ramp if the watch is passing."
		Stage.EXIT:
			_goal.text = "Take the eastern turn-off and bring back word."
			_evidence.text = "The slate lists Greyhollow as the next stop. It says nothing about what is buried there."
			_cue.text = "Use the post wall for cover before crossing the road."
		Stage.CLEARED:
			_goal.text = "Survey complete"
			_evidence.text = "The freight route leads to Greyhollow. The prophecy's meaning is still uncertain."
			_cue.text = ""
		Stage.TURNED_BACK:
			_goal.text = "The watch sent Neris back."
			_evidence.text = "Use the covered track and cross the road once the watch has moved on."
			_cue.text = ""
	if watching and stage < Stage.CLEARED:
		_cue.text = "The watch can see you. Break sight now (%.1f s)." % (INTERCEPT_SECONDS - _watched_seconds)


func _beacon(path: NodePath, caption: String, color: Color) -> Node3D:
	var node := Node3D.new()
	$SurveyVisuals.add_child(node)
	node.global_position = battlefield_marker(path).global_position
	_mesh(node, _ring(1.05, 1.4), _material(color, true), Vector3.UP * 0.05)
	_label(node, caption, color)
	return node


func _label(parent: Node3D, caption: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 40
	label.pixel_size = 0.017
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 10
	label.modulate = color
	label.position.y = 1.2
	parent.add_child(label)
	return label
