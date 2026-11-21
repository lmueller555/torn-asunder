extends SceneTree

const Mission := preload("res://game/battlefield/neris_cairnspine_survey.gd")
const SCENE := preload("res://game/battlefield/neris_cairnspine_survey.tscn")
const DT := 1.0 / 60.0

var _scene: Mission
var _results: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = SCENE.instantiate() as Mission
	root.add_child(_scene)
	_scene.set_physics_process(false)
	_scene.mission_finished.connect(func(won: bool) -> void: _results.append(won))
	await physics_frame
	await physics_frame
	if not _expect(_scene.battle.direct_hero_control() and _scene.battle.formations.is_empty(),
			"Neris must be able to scout alone under direct control."):
		return

	# A visit or button press elsewhere is not evidence. A press in the
	# overview cannot leak into the hero's next step after closing it.
	_inspect()
	if not _expect(_scene.stage == Mission.Stage.TRACK and _results.is_empty(), "An inspection worked from afar."):
		return
	if not _walk(["SheepTrackBend", "SheepPinch"]):
		return
	_axis(JOY_AXIS_TRIGGER_LEFT, 1)
	_inspect(true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_scene._physics_process(DT)
	if not _expect(_scene.stage == Mission.Stage.TRACK, "The sector camera permitted a hero interaction."):
		return
	_inspect(true)
	if not _expect(_scene.stage == Mission.Stage.POST and _results.is_empty(), "One clue cleared the mission."):
		return
	if not _walk(["CoveredTrackHold", "EastRampBottom", "EastRampTop", "EastTrackLanding",
			"TrackEmergence", "TrackWallCorner", "PostTrackTurn"]):
		return
	if not _walk_to(_scene.POST_CLUE):
		return
	if not _wait_until_safe():
		return
	_inspect()
	if not _expect(_scene.stage == Mission.Stage.EXIT and _results.is_empty(), "The second clue did not require a report."):
		return
	if not _walk(["PostDoorway", "PostRoadApproach"]):
		return
	# Follow the surveyed junction, allowing the patrol to pass first.
	if not _wait_until_safe() or not _walk(["PostEastTurn", "EastMarchEdge"]) or not _wait_until_safe():
		return
	_inspect()
	_inspect()
	if not _expect(_scene.stage == Mission.Stage.CLEARED and _results == [true],
			"The supported trench and post route failed to clear exactly once."):
		return

	_scene.restart_mission()
	if not _expect(_scene.stage == Mission.Stage.TRACK and _scene._watched_seconds == 0.0,
			"Restart kept evidence or patrol awareness."):
		return
	var initial_watch := _scene._watch.position
	# Deliberate setup for the detection-path checks, so no extra traversal is
	# required after verifying the complete route above.
	_scene.battle.hero_position = _scene._marker_position(_scene.battlefield_marker(Mission.WATCH_ROUTE[0]))
	for step in range(60):
		_scene._physics_process(DT)
	if not _expect(_scene._watch.position.distance_to(initial_watch) > 3.5
			and _scene._watched_seconds > 0.9 and _scene.stage == Mission.Stage.TRACK,
			"The watch did not physically move, warn, or give time to get away."):
		return
	_scene.battle.hero_position = _scene._marker_position(_scene.battlefield_marker(Mission.TRACK_CLUE))
	for step in range(60):
		_scene._physics_process(DT)
	if not _expect(_scene._watched_seconds == 0.0 and _results == [true], "Getting out of sight failed to clear the warning."):
		return

	_scene.restart_mission()
	# Stay at the center of the patrol's first leg to be continuously seen.
	_scene.battle.hero_position = Vector2(64, -11.4)
	for step in range(240):
		_scene._physics_process(DT)
	if not _expect(_scene.stage == Mission.Stage.TURNED_BACK and _results == [true, false],
			"Exposure did not turn back the player exactly once."):
		return
	print("Verified the physical Year Two survey route, clue gating, reversible patrol sight, and one signal per attempt.")
	quit()


func _walk(names: Array[String]) -> bool:
	for target: String in names:
		if not _walk_to(NodePath("Markers/Routes/" + target)):
			return false
	return true


func _walk_to(path: NodePath) -> bool:
	var point := _scene._marker_position(_scene.battlefield_marker(path))
	var budget := ceili(_scene.battle.hero_position.distance_to(point) / _scene.Battle.HERO_SPEED / DT) + 3
	for step in range(budget):
		var remaining := point - _scene.battle.hero_position
		if remaining.length() <= 0.14 or _scene.stage >= Mission.Stage.CLEARED:
			break
		var direction := remaining.normalized().rotated(_scene._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, direction.x)
		_axis(JOY_AXIS_LEFT_Y, direction.y)
		_scene._physics_process(DT)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _expect(_scene.battle.hero_position.distance_to(point) <= 0.14,
		"Could not walk to %s from %s; stage %s." % [path, _scene.battle.hero_position, _scene.stage])


func _wait_until_safe() -> bool:
	for step in range(270):
		if not _scene._watch_has_sight(_scene.hero_world_position()):
			return true
		_scene._physics_process(DT)
		if _scene.stage >= Mission.Stage.CLEARED:
			break
	return _expect(false, "No safe inspection window at %s, stage %s." % [_scene.battle.hero_position, _scene.stage])


func _inspect(controller := false) -> void:
	if controller:
		var input := InputEventJoypadButton.new()
		input.pressed = true
		input.button_index = JOY_BUTTON_A
		root.push_input(input, true)
	else:
		var input := InputEventKey.new()
		input.pressed = true
		input.physical_keycode = KEY_SPACE
		root.push_input(input, true)
	_scene._physics_process(DT)


func _axis(axis: JoyAxis, value: float) -> void:
	var input := InputEventJoypadMotion.new()
	input.axis = axis
	input.axis_value = value
	root.push_input(input, true)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
