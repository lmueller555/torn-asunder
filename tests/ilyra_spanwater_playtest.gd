extends SceneTree

const Scene := preload("res://game/battlefield/ilyra_spanwater_playtest.tscn")
const Mission := preload("res://game/battlefield/ilyra_spanwater_playtest.gd")
const Rescue := preload("res://game/battlefield/ilyra_spanwater_evacuation.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const NEAR := Rescue.Group.NEAR
const FAR := Rescue.Group.FAR
const FIRST := Rescue.Launch.FIRST
const SECOND := Rescue.Launch.SECOND
const DT := 1.0 / 60.0

var _mission: Mission
var _outcomes: Array[bool] = []
var _failures := 0
var _screen_persistent := false
var _saw_held := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	_mission.mission_finished.connect(func(won: bool) -> void: _outcomes.append(won))
	await physics_frame
	await physics_frame
	_check(_mission._field.name == &"SpanwaterLockCampaign", "The mission must instantiate the shared campaign terrain.")
	var water := _mission._field.get_node("Geometry/Landing/LowBasinTint") as MeshInstance3D
	var deck := _mission._field.get_node("Geometry/Landing/LandingDeck") as MeshInstance3D
	_check(_mission._river.mesh == water.mesh and _mission._stairs_water.mesh == water.mesh \
		and _mission._river.material_override == water.material_override and _mission._gangplank.mesh == deck.mesh,
		"Debug overlays use existing terrain resources, not new candidate art.")
	if _rescue_near_first() and _rescue_far_first() and _check_visible_closure() and _check_empty_launch_retry():
		_check(_outcomes == [true, true, false, true], "Only terminal outcomes emit, once per attempt.")
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Ilyra at Spanwater: actual hero calls, patrol screening, both boarding orders and two real exits, visible current/closure, empty-launch recovery and restart passed.")
	quit(0 if _failures == 0 else 1)


func _rescue_near_first() -> bool:
	var objective := _mission.objective
	_key(KEY_SPACE)
	_tick()
	if not _check(objective.group_status(NEAR) == Rescue.GroupStatus.SHELTERED and objective.group_status(FAR) == Rescue.GroupStatus.SHELTERED,
			"Remote Cross did not send a group."):
		return false
	if not _hero_route(["Routes/LandingApproach", "Spawns/HouseholdsNear"]):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_A)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _check(objective.group_status(NEAR) == Rescue.GroupStatus.SHELTERED, "Command-view Cross is not a call."):
		return false
	_joy(JOY_BUTTON_A)
	if not _wait(func() -> bool: return _mission._approach_contested and _mission._groups[0].next == 2, 1100,
			"The near party did not physically reach the contested ramp."):
		return false
	var pause := _mission._groups[0].view.position
	for _step in range(80):
		_tick()
	if not _check(objective.group_status(NEAR) == Rescue.GroupStatus.APPROACHING and pause == _mission._groups[0].view.position 			and _mission._cue.text.contains("PATROL"), "Patrol pressure should be visible and physically stop an approaching party."):
		return false
	if not _screen() or not _hero_route(["Routes/HouseholdScreenTurn", "Spawns/HouseholdsFar"]):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _wait(func() -> bool: return objective.group_status(NEAR) == Rescue.GroupStatus.SAFE, 2800,
			"The first group never reached the downstream exit."):
		return false
	if not _check(objective.outcome == Rescue.Outcome.ACTIVE and objective.group_status(FAR) != Rescue.GroupStatus.SAFE 			and _mission._boats[0].view.position.is_equal_approx(_mission._boat_exit),
			"The physical exit of the first load must not clear the second load."):
		return false
	return _finish_both()


func _rescue_far_first() -> bool:
	_saw_held = false
	_joy(JOY_BUTTON_START)
	var objective := _mission.objective
	if not _check(objective.group_status(NEAR) == Rescue.GroupStatus.SHELTERED and not _mission._river.visible 			and _mission._boats[0].view.position == _mission._upstream, "Options should restore both routes and water state."):
		return false
	if not _screen() or not _hero_route(["Routes/LandingApproach", "Spawns/HouseholdsNear", "Routes/HouseholdScreenTurn", "Spawns/HouseholdsFar"]):
		return false
	_joy(JOY_BUTTON_A)
	if not _wait(func() -> bool: return objective.passenger_group(FIRST) == FAR, 3200,
			"The far households could not physically board before the nearer party was called."):
		return false
	if not _check(objective.group_status(FAR) == Rescue.GroupStatus.ABOARD 			and _mission._groups[1].view.position.distance_to(_mission._boats[0].view.position) < 0.8 			and _mission._boats[0].view.position == _mission._berth,
			"The far party must cross the marked boarding path onto the boat at the real berth."):
		return false
	if not _hero_route(["Routes/HouseholdScreenTurn", "Spawns/HouseholdsNear"]):
		return false
	# Board the second group just before the stair closes, with the loaded boat still out.
	var closure_time := Mission.RELEASE_AT + (_mission._landing.x - _mission._sweep_start.x) / Mission.RIVER_SPEED \
		+ Mission.CLOSED_HEIGHT / Mission.RISE_SPEED
	if not _wait(func() -> bool: return _mission._elapsed >= closure_time - 17.0, 2000, "The visible rise never approached closure."):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _wait(func() -> bool: return objective.landing_closed, 1500, "The second launch never saw the landing close."):
		return false
	if not _check(objective.outcome == Rescue.Outcome.ACTIVE and objective.group_status(NEAR) == Rescue.GroupStatus.ABOARD \
			and not _mission._gangplank.visible, "A loaded departure must remain live when the stairs close."):
		return false
	if not _finish_both():
		return false
	return _check(_saw_held and _screen_persistent, "A physical launch must wait at an outflow hold while the screen persists.")


func _check_visible_closure() -> bool:
	_key(KEY_BACKSPACE)
	var objective := _mission.objective
	if not _wait(func() -> bool: return objective.last_departure_warned, 5200, "The actual rise never gave a last-departure warning."):
		return false
	var water_before := _mission._stairs_water.position.y
	if not _check(objective.release_started and _mission._ford_closed and not objective.landing_closed 			and _mission._river.visible and _mission._stairs_water.visible and _mission._cue.text.contains("LAST DEPARTURE"),
			"The separate lower-landing warning should follow the main-channel ford closure."):
		return false
	if not _wait(func() -> bool: return objective.outcome == Rescue.Outcome.FAILED, 3000,
			"The real stairs rise did not close the landing and strand households."):
		return false
	var foot := _marker("Routes/LandingFoot")
	var approach := Vector2(foot.x, _mission._landing_box.end.y + 0.02)
	return _check(objective.failure == Rescue.Failure.LANDING_CLOSED and _mission._stairs_water.position.y > water_before 		and _mission._boats[0].view.position == _mission._berth and not _mission._gangplank.visible 		and not _mission._can_move(approach, approach - Vector2(0, 0.22), false),
		"A physically rising and closed low zone must hide boarding access and block ingress even with an empty craft at the berth.")


func _check_empty_launch_retry() -> bool:
	_key(KEY_BACKSPACE)
	_mission.report_launch_disabled(FIRST)
	if not _screen():
		return false
	var objective := _mission.objective
	if not _check(objective.launch_status(FIRST) == Rescue.LaunchStatus.DISABLED and objective.outcome == Rescue.Outcome.ACTIVE,
			"An empty launch loss cannot fail the rescue."):
		return false
	if not _hero_route(["Routes/LandingApproach", "Spawns/HouseholdsNear"]):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _hero_route(["Routes/HouseholdScreenTurn", "Spawns/HouseholdsFar"]):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _wait(func() -> bool: return objective.group_status(NEAR) == Rescue.GroupStatus.SAFE, 4300,
			"The surviving launch did not physically make the first trip."):
		return false
	if not _wait(func() -> bool: return _mission._boats[1].leg == Mission.BoatLeg.RETURNING, 40,
			"The surviving launch did not start a real return trip."):
		return false
	if not _wait(func() -> bool: return objective.passenger_group(SECOND) == FAR, 4000,
			"The surviving launch did not physically return and board the other group."):
		return false
	return _check(_mission._boats[1].view.position == _mission._berth, "The second trip must board at the actual berth.") and _finish_both()


func _finish_both() -> bool:
	var objective := _mission.objective
	if not _wait(func() -> bool: return objective.outcome != Rescue.Outcome.ACTIVE, 5600, "Neither victory nor the visible closure occurred."):
		return false
	return _check(objective.outcome == Rescue.Outcome.SUCCEEDED and objective.group_status(NEAR) == Rescue.GroupStatus.SAFE 		and objective.group_status(FAR) == Rescue.GroupStatus.SAFE and _mission._boats[1].view.position == _mission._boat_exit,
		"The groups must both actually cross the exit. Last state: %s / %s; elapsed %.1f." 			% [objective.failure, _mission._status.text, _mission._elapsed])


func _screen() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_RIGHT_STICK)
	var point := _marker("Routes/LandingApproach")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = root.get_camera_3d().unproject_position(point)
	root.push_input(event, true)
	var guard := _mission.battle.formations[0]
	var success := _wait(func() -> bool: return guard.order == Battle.Order.HOLD 		and guard.position.distance_to(_mission._screen_point) < 0.15, 700,
		"The real projected marine order failed to reach the landing rise.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return success


func _hero_route(paths: Array) -> bool:
	for path: String in paths:
		var local := _mission.to_local(_marker(path))
		var point := Vector2(local.x, local.z)
		var budget := ceili(_mission.battle.hero_position.distance_to(point) / Battle.HERO_SPEED / DT) + 80
		for _step in range(budget):
			var offset := point - _mission.battle.hero_position
			if offset.length() < 0.15:
				break
			var aim := offset.normalized().rotated(_mission._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, aim.x)
			_axis(JOY_AXIS_LEFT_Y, aim.y)
			_tick()
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		if not _check(_mission.battle.hero_position.distance_to(point) <= 0.15, "Ilyra did not physically reach " + path):
			return false
	return true


func _marker(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _wait(condition: Callable, ticks: int, message: String) -> bool:
	for _step in range(ticks):
		if condition.call():
			return true
		_tick()
	return _check(condition.call(), message)


func _tick() -> void:
	_mission._physics_process(DT)
	for launch in Rescue.LAUNCHES:
		if _mission.objective.launch_status(launch) == Rescue.LaunchStatus.HELD_AT_OUTFLOW:
			_saw_held = _mission._boats[launch - 1].view.position.is_equal_approx(_mission._outbound_hold)
	if _mission._patrol.visible and _mission._patrol.position.distance_to(_mission._ground(_mission._patrol_start)) < 0.15:
		_screen_persistent = true
	_check(not (_mission._boats[0].leg == Mission.BoatLeg.BERTH and _mission._boats[1].leg == Mission.BoatLeg.BERTH),
		"Two actual boats occupied the same authored berth.")


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures += 1
		push_error(message)
	return ok
