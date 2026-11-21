extends SceneTree

const Scene := preload("res://game/battlefield/neris_spanwater_playtest.tscn")
const Mission := preload("res://game/battlefield/neris_spanwater_playtest.gd")
const Feeder := preload("res://game/battlefield/neris_spanwater_feeder.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _outcomes: Array[bool] = []
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	_mission.mission_finished.connect(func(won: bool) -> void: _outcomes.append(won))
	await physics_frame
	await physics_frame
	_recover_and_win()
	_restart_and_miss_crest()
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Neris at Spanwater: true input and terrain motion, screened board work, debris repair, visible river/gauge separation, crest failure and retry passed.")
	quit(0 if _failures == 0 else 1)


func _recover_and_win() -> void:
	var objective := _mission.objective
	var ford_edge := Vector2(46.45, 0)
	var ford_inside := Vector2(46.55, 0)
	_check(_mission._can_move_in_lane(ford_edge, ford_inside, false),
		"The actual dry ford admits traffic before release.")
	var crew_start := _mission._crew.position
	var rack_point := _marker("Objectives/FeederInletRack")
	_key(KEY_SPACE)
	_tick()
	_check(objective.phase == Feeder.Phase.CLEAR_INLET and _mission._silt.visible,
		"A remote interaction must not clear the rack or remove its visible blockage.")
	_drive_to(_marker("Routes/FeederPathWest"))
	_drive_to(rack_point)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_A)
	_tick()
	_check(objective.phase == Feeder.Phase.CLEAR_INLET, "Command-view Hold is not a rack interaction.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_A)
	_tick()
	_check(objective.phase == Feeder.Phase.FIT_BOARDS and not _mission._silt.visible and _mission._crew.position != crew_start,
		"Hero Cross at the physical rack must clear it while the actual crew walks in.")
	_wait(func() -> bool: return _mission._elapsed >= Mission.WARNING_AT + 0.5, 1000)
	_check("warning" in _mission._cue.text and not objective.released and not _mission._river_visual.visible
		and objective.board_progress == 0.0 and _mission._patrol.visible,
		"The visible pre-release warning must not imply water or give unscreened crew work credit.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	_check(_mission.command_view and _mission._cue.is_visible_in_tree() and "warning" in _mission._cue.text,
		"The same pre-release warning must remain visible while issuing orders.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_wait(func() -> bool: return _mission._contested, 1100)
	_check(_mission._contested and _mission._patrol.position.distance_to(rack_point) <= Mission.CONTEST_RADIUS + 0.05
		and objective.board_progress == 0.0, "Physically arriving March troops must contest the rack.")

	_wait(func() -> bool: return _mission._elapsed >= Mission.RELEASE_AT + 4.0, 550)
	_check(objective.released and _mission._river_visual.visible and _mission._inlet_visual.visible
		and not _mission._channel_visual.visible and objective.board_progress == 0.0,
		"Release must begin independently of readiness, with two visible fronts but no water downstream of the unfinished rack.")
	var guarded := _mission.battle.formations[1]
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	_button(JOY_BUTTON_DPAD_RIGHT)
	var screen := _mission.to_global(_mission._ground(_mission._screen_point))
	_order_at(screen)
	_check(_mission.selected_index == 1 and guarded.order == Battle.Order.MOVE,
		"The real command camera pointer must dispatch the selected guard.")
	_wait(func() -> bool: return objective.phase == Feeder.Phase.CLEAR_DEBRIS, 500)
	_check(objective.phase == Feeder.Phase.CLEAR_DEBRIS and _mission._silt.visible and objective.gauge_progress == 0.0,
		"The incoming water front should visibly jam the unfinished rack.")
	_check(not _mission._can_move_in_lane(ford_edge, ford_inside, false)
		and _mission._can_move_in_lane(ford_inside, ford_edge, false),
		"Flooding must close the ford but permit retreat from its footprint.")
	_check(_mission._can_move_in_lane(_xz(rack_point), _xz(rack_point) + Vector2(0.05, 0), false)
		and not _mission._channel_visual.visible, "Flooding must leave the raised Dryad maintenance path usable.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_key(KEY_SPACE)
	_tick()
	_check(objective.phase == Feeder.Phase.CLEAR_DEBRIS, "Rushing a clearance into a contested rack must not remove its jam.")
	_wait(func() -> bool: return _mission._screened and not _mission._contested, 850)
	_check(guarded.order == Battle.Order.HOLD and guarded.position.distance_to(_mission._screen_point) < 0.4
		and _mission._screened and not _mission._contested, "Hold must make the visible March patrol withdraw out of range.")
	_key(KEY_SPACE)
	_tick()
	var board_start := _mission._boards[0].position
	_check(objective.phase == Feeder.Phase.FIT_BOARDS and not _mission._silt.visible,
		"A fresh local interaction must recover the jam after the screen is established.")
	_tick(145)
	_check(objective.board_progress > 0.0 and _mission._boards[0].position.distance_to(board_start) > 0.5
		and objective.gauge_progress == 0.0, "Workers' fitting progress must visibly place guide boards, not add gauge credit.")
	_wait(func() -> bool: return _mission._crest_visual.visible, 1000)
	_check(_mission._crest_visual.visible and "Crest" in _mission._cue.text,
		"The approaching crest must be a visible front with a usable warning.")
	_wait(func() -> bool: return objective.phase == Feeder.Phase.RAISE_GAUGE, 1100)
	_check(objective.phase == Feeder.Phase.RAISE_GAUGE and objective.board_progress == 1.0
		and _mission._ford_closed and objective.gauge_progress == 0.0 and _outcomes.is_empty(),
		"Completed boards and full river stage alone cannot win or fill the town gauge.")
	_tick(90)
	_check(_mission._channel_visual.visible and _mission._channel_visual.scale.x > 0.0
		and _mission._channel_visual.position.x < _mission._gauge_water.x and objective.gauge_progress == 0.0,
		"The separate downstream water front must move physically before the gauge can rise.")
	for path in ["Routes/FeederMaintenanceBend", "Routes/FeederPathEast"]:
		_drive_to(_marker(path))
	_check(_mission._channel_visual.visible and _outcomes.is_empty(),
		"Neris can follow the actual open maintenance path as the feeder advances.")
	_wait(func() -> bool: return objective.gauge_progress > 0.0 or not _outcomes.is_empty(), 1300)
	_check(objective.gauge_progress > 0.0 and objective.gauge_progress < 1.0 and _outcomes.is_empty()
		and absf(_mission._channel_visual.position.x + _mission._channel_visual.scale.x * 0.5 - _mission._gauge_water.x) < 0.03,
		"The gauge starts after the visible front reaches town, then fills separately.")
	_wait(func() -> bool: return not _outcomes.is_empty(), 550)
	_tick(15)
	_check(_outcomes == [true] and objective.phase == Feeder.Phase.SUCCEEDED and objective.gauge_progress == 1.0
		and "town mark" in _mission._goal.text, "Only a full town gauge with river stage finishes, once.")


func _restart_and_miss_crest() -> void:
	var objective := _mission.objective
	_button(JOY_BUTTON_START)
	_check(objective.phase == Feeder.Phase.CLEAR_INLET and _mission._elapsed == 0.0 and _mission._silt.visible
		and not _mission._patrol.visible and not _mission._river_visual.visible and not _mission._channel_visual.visible
		and _mission.battle.hero_position == _xz(_marker("Spawns/DryadCrew"))
		and _mission._can_move_in_lane(Vector2(46.45, 0), Vector2(46.55, 0), false),
		"Options retry must restore spawns, dry ford, blockage, and all stages of water.")
	_wait(func() -> bool: return _outcomes.size() == 2, 4300)
	_tick(25)
	_check(_outcomes == [true, false] and objective.failure == Feeder.Failure.FEEDER_BURIED and objective.released
		and "buried" in _mission._status.text, "Inaction must meet the same release and actually lose at the visible crest, once.")


func _drive_to(at: Vector3) -> void:
	var target := _xz(at)
	var budget := ceili(_mission.battle.hero_position.distance_to(target) / Battle.HERO_SPEED / DT) + 40
	for tick in range(budget):
		var offset := target - _mission.battle.hero_position
		if offset.length() <= 0.18:
			break
		var stick := offset.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_mission.battle.hero_position.distance_to(target) <= 0.18,
		"Neris did not walk to %s (stopped at %s)." % [target, _mission.battle.hero_position])


func _order_at(at: Vector3) -> void:
	var pointer := root.get_camera_3d().unproject_position(at)
	_check(root.get_visible_rect().has_point(pointer), "The intended screen must be visible in the command camera.")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = pointer
	root.push_input(event, true)


func _marker(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _xz(at: Vector3) -> Vector2:
	var local := _mission.to_local(at)
	return Vector2(local.x, local.z)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _wait(condition: Callable, budget: int) -> void:
	for tick in range(budget):
		if condition.call():
			break
		_tick()


func _tick(count := 1) -> void:
	for tick in range(count):
		_mission._physics_process(DT)


func _check(ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
		push_error(detail)
