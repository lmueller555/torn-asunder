extends SceneTree

const Scene := preload("res://game/battlefield/raska_spanwater.tscn")
const Mission := preload("res://game/battlefield/raska_spanwater.gd")
const Release := preload("res://game/battlefield/raska_spanwater_release.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var obj := _mission.objective
	var exit := _point("Objectives/HighBankExit")
	# Sample a real final approach before the objective unlocks, rather than
	# injecting an exit observation or relying on a guessed acceptance radius.
	_mission.battle.hero_position = exit - Vector2(4.0, 0.0)
	_drive_to(exit, 0.20)
	_check(obj.phase == Release.Phase.SECURE_SPILLWAY and not _mission._exit_beacon.visible,
		"Reaching HighBankExit physically before river stage does not win.")
	_mission.restart_mission()
	var crossing_approach := Vector2(_mission._crossing_rect.get_center().x, _mission._crossing_rect.position.y - 0.35)
	var crossing_inside := crossing_approach + Vector2(0.0, 1.3)
	_mission.battle.hero_position = crossing_approach
	_drive_to(crossing_inside, 0.15)
	_check(_mission._crossing_depth(_mission.battle.hero_position) > 0.0 and not _mission._crossing_closed,
		"The low crossing admits real hero movement before release.")
	_mission.restart_mission()

	for path in ["Routes/ServiceCauseway", "Routes/LockApron", "Objectives/SpillwayWheel"]:
		_drive_to(_point(path), 0.20)
	_key(KEY_SPACE)
	_tick(2)
	_check(obj.phase == Release.Phase.SECURE_SPILLWAY and _mission._withdrawal_count == 0,
		"Raska cannot open the still-contested spillway by interacting early.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	var regulars := _mission.battle.formations[0]
	for path in ["Routes/UpstreamApproach", "Routes/ServiceCauseway", "Routes/LockApron", "Objectives/SpillwayWheel"]:
		_order_at(_point(path))
		_finish_march(regulars, _point(path), path)
	_tick(100)
	_check(obj.phase == Release.Phase.READY_AT_WHEEL and _mission._goal.text.contains("must open"),
		"Projected formation orders secure the wheel by pushing the visible guard back.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_check(_mission.selected_index == 1, "The lower towns can be selected before they withdraw.")
	_button(JOY_BUTTON_A)
	_tick()
	_check(obj.phase == Release.Phase.READY_AT_WHEEL, "Command-view Cross is Hold, not a wheel interaction.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_mission.battle.hero_position = _point("Objectives/SeaGate")
	_button(JOY_BUTTON_A)
	_tick()
	_check(obj.phase == Release.Phase.READY_AT_WHEEL and _mission._withdrawal_count == 0,
		"The same interaction at the sea gate does nothing.")
	_mission.battle.hero_position = _point("Objectives/SpillwayWheel")
	var support_departed_from := _mission._formation_models[1].position
	_button(JOY_BUTTON_A)
	_tick(8)
	_check(obj.phase == Release.Phase.RELEASING and obj.release_progress > 0.0 \
		and _mission._withdrawal_count == 1 and _mission.battle.formations.size() == 1 \
		and _mission.selected_index == 0 and _mission._departure_label.visible and not _mission._crossing_closed \
		and _mission._formation_models[1].position != support_departed_from \
		and is_equal_approx(_mission._flow.scale.x, _mission._flow_length * obj.release_progress),
		"Raska’s authorized Cross starts a visible sweep and recalls the lower towns once without closing the ford early.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_check(_mission.selected_index == 0, "A departing friendly cannot be selected or commanded.")
	var stand := _point("Objectives/SpillwayWheel") + Vector2(-5.6, 0.0)
	_order_at(stand)
	_finish_march(regulars, stand, "screen outside the wheel ring")
	_tick(150)
	var paused := obj.release_progress
	var paused_front := _mission._flow.scale.x
	_check(obj.phase == Release.Phase.PAUSED and paused > 0.0 and paused < 1.0 \
		and _mission._march_distance > 0.0 and not _mission._crossing_closed and _mission._goal.text.contains("paused"),
		"The visible approach pauses the front while regulars screen the guard short of the wheel.")
	_tick(420)
	_check(obj.phase == Release.Phase.PAUSED and obj.release_progress == paused and _mission._flow.scale.x == paused_front,
		"A prolonged contested stand-off cannot progress, close the ford, or expire through a hidden timer.")

	_order_at(_point("Objectives/SpillwayWheel"))
	_finish_march(regulars, _point("Objectives/SpillwayWheel"), "returned to the wheel")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	for i in range(1400):
		if obj.phase == Release.Phase.EXTRACT:
			break
		_tick()
	_check(obj.phase == Release.Phase.EXTRACT and obj.release_progress == 1.0 and _mission._crossing_closed \
		and _mission._exit_beacon.visible and _mission._crossing_beacon.visible and _mission._withdrawal_count == 1,
		"Recapture resumes the same front without a second interact; river stage closes only the ford and unlocks exit.")
	_mission.battle.hero_position = crossing_approach
	_drive_to(crossing_inside, 0.15, false)
	_check(_mission._crossing_depth(_mission.battle.hero_position) == 0.0,
		"After river stage, the same real movement is physically blocked at the ford.")
	_mission.battle.hero_position = crossing_inside
	_drive_to(crossing_approach, 0.18)
	_check(_mission._crossing_depth(_mission.battle.hero_position) == 0.0,
		"A hero caught in the low crossing can retreat instead of being trapped by the new blocker.")
	regulars.position = crossing_approach
	regulars.hold()
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	_order_at(crossing_inside)
	_tick(40)
	_check(regulars.order == Battle.Order.BLOCKED and _mission._crossing_depth(regulars.position) == 0.0,
		"The closed crossing blocks real formation orders as well as the hero.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)

	_mission.battle.hero_position = _point("Objectives/SpillwayWheel")
	for path in ["Routes/MarchCounterattackApproach", "Routes/HighBankStaging", "Routes/HighBank", "Objectives/HighBankExit"]:
		_drive_to(_point(path), Mission.EXIT_RADIUS if path.ends_with("HighBankExit") else 0.20)
	_check(obj.phase == Release.Phase.SUCCEEDED, "The actual raised path lets Raska reach the exit and win.")
	_key(KEY_BACKSPACE)
	_check(obj.phase == Release.Phase.SECURE_SPILLWAY and not _mission._crossing_closed and not _mission._flow.visible \
		and _mission.battle.formations.size() == 2 and _mission._withdrawal_count == 0,
		"Restart clears all effects, selection and geometry state for the next attempt.")

	regulars = _mission.battle.formations[0]
	regulars.position = _point("Objectives/SpillwayWheel")
	regulars.hold()
	_mission.battle.hero_position = regulars.position
	_tick(100)
	_key(KEY_SPACE)
	_tick(3)
	_check(obj.phase == Release.Phase.RELEASING and _mission._withdrawal_count == 1,
		"A second attempt publishes its one new withdrawal.")
	regulars.position = _point("Routes/UpstreamApproach")
	regulars.hold()
	_tick(8)
	_check(obj.phase == Release.Phase.PAUSED and _mission._march_distance > 0.0,
		"An empty wheel pauses first while the guard physically approaches.")
	_tick(150)
	_check(obj.phase == Release.Phase.FAILED and obj.failure == Release.Failure.SPILLWAY_SHUT \
		and is_zero_approx(_mission._march_distance) and not _mission._crossing_closed,
		"Only the guard reaching the wheel proves shutdown and fails the incomplete release.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Spanwater verified: projected commands, physical interaction and exit, one friendly withdrawal, contest/recovery, ford movement, visible shutdown and retry.")
	quit(0 if _failures == 0 else 1)


func _point(path: String) -> Vector2:
	var marker := _mission.battlefield_marker(NodePath("Markers/" + path))
	return _mission._marker_position(marker)


func _order_at(point: Vector2) -> void:
	var pointer := root.get_camera_3d().unproject_position(_mission.to_global(_mission._ground(point)))
	_check(root.get_visible_rect().has_point(pointer), "Projected formation target is visible: %s." % point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = pointer
	root.push_input(event, true)


func _finish_march(formation: Battle.Formation, point: Vector2, context: String) -> void:
	var budget := ceili(formation.position.distance_to(point) / Battle.FORMATION_SPEED / DT) + 30
	for i in range(budget):
		if formation.order != Battle.Order.MOVE:
			break
		_tick()
	_check(formation.order == Battle.Order.HOLD and formation.position.distance_to(point) < 0.085,
		"Formation takes the legal route to %s; got %s (%s)." % [context, formation.position, formation.order])


func _drive_to(point: Vector2, tolerance: float, must_reach := true) -> void:
	var budget := ceili(_mission.battle.hero_position.distance_to(point) / Battle.HERO_SPEED / DT) + 65
	for i in range(budget):
		if _mission.battle.hero_position.distance_to(point) <= tolerance or _mission._finished():
			break
		var aim := (point - _mission.battle.hero_position).normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if must_reach:
		_check(_mission.battle.hero_position.distance_to(point) <= tolerance,
			"Raska physically reaches %s; got %s." % [point, _mission.battle.hero_position])


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


func _tick(count := 1) -> void:
	for i in range(count):
		_mission._physics_process(DT)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
