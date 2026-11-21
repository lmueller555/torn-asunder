extends SceneTree

const Scene := preload("res://game/battlefield/sova_mine_evacuation_campaign.tscn")
const Mission := preload("res://game/battlefield/sova_mine_evacuation.gd")
const Evacuation := preload("res://game/battlefield/sova_mine_tunnels.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _failures := 0
var _worker_clearance := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_tick()
	var spawn := _marker("Spawns/DruidGuard")
	var mouth := _marker("Routes/TunnelEntrance")
	var bend := _marker("Routes/TunnelMidpoint")
	var outlet := _marker("Routes/TunnelExit")
	var turn := _marker("Routes/EvacuationTurn")
	var safety := _marker("Objectives/MinerEvacuation")
	var site := _mission._field
	var hero_camera := root.get_camera_3d()
	_check(site.name == &"YearOneMineCampaign" and _mission.battle.bounds == Rect2(-160, -108, 320, 224),
		"Sova starts on the actual campaign valley.")
	_check(_mission.hero_world_position().is_equal_approx(spawn) and _party(0) == mouth and _party(1) == bend,
		"The campaign plugs both worker stages and the hero into authored markers.")
	_check(_mission._route[Mission.EXIT_WAYPOINT] == outlet
		and _mission._route[Mission.EXIT_WAYPOINT + 1] == turn and _mission._route[-1] == safety,
		"The worker route clears the far portal before turning west; the witness truce point remains the outlet.")
	_check(mouth.distance_to(safety) > 75.0, "The safety zone is on the campaign map, not the pocket.")

	# Wait longer than a released trip without interacting. This slice has no timed defeat.
	_key(KEY_SPACE)
	_tick(60 * 65)
	_check(_mission.objective.outcome == Evacuation.Outcome.ACTIVE
		and _status(0) == Evacuation.GroupStatus.STAGED and _status(1) == Evacuation.GroupStatus.STAGED,
		"An out-of-range release does not move either group, and there's no hidden deadline.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var sector := root.get_camera_3d()
	_check(sector != hero_camera and sector.size == 116.0
		and _mission._mode_label.text.begins_with("TACTICAL SECTOR"),
		"Holding L2 opens the local sector at the mine yard.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_check(_mission._sector.overview and sector.size > 390.0
		and _mission._mode_label.text.begins_with("FIELD OVERVIEW"),
		"R3 opens the valley-wide overview.")
	for point in [spawn, safety, _marker("Objectives/GodbridleExit")]:
		_check(root.get_visible_rect().has_point(sector.unproject_position(point)),
			"Overview contains the widely separated mission landmarks.")
	_button(JOY_BUTTON_LEFT_STICK)
	_check(not _mission._sector.overview and sector.size == 116.0
		and _mission._sector.view_center().is_equal_approx(_xz(spawn)),
		"L3 returns to Sova's local sector.")

	var assembly := _marker("Objectives/MinerAssembly")
	_command_move(assembly)
	var guard := _mission.battle.formations[0]
	_check(guard.order == Battle.Order.MOVE and guard.destination.distance_to(_xz(assembly)) < 0.04,
		"A real mouse order sends the tunnel guard to the campaign mine assembly area.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(root.get_camera_3d() == hero_camera and _mission._field == site, "Releasing L2 preserves the battlefield in hero view.")
	_drive_to(mouth)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key(KEY_SPACE)
	_tick()
	_check(_status(0) == Evacuation.GroupStatus.STAGED, "Command Space does not release a staged party.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_A)
	_tick()
	_check(_status(0) == Evacuation.GroupStatus.MOVING and _status(1) == Evacuation.GroupStatus.STAGED,
		"A hero-view Cross independently releases the mouth group.")
	_drive_to(bend)
	_key(KEY_SPACE)
	_tick()
	_check(_status(1) == Evacuation.GroupStatus.MOVING, "The hero can enter the covered bend and release its group with Space.")
	_finish(outlet, safety)
	_check(guard.order == Battle.Order.HOLD and guard.position.distance_to(_xz(assembly)) < 0.06,
		"The actual guard order completes across hero and command view changes.")

	_button(JOY_BUTTON_START)
	_tick()
	_check(_mission.objective.outcome == Evacuation.Outcome.ACTIVE and _mission.hero_world_position().is_equal_approx(spawn)
		and _party(0) == mouth and _party(1) == bend and not _mission._witness_at_truce,
		"Retry restores the large-map spawn, both stages, and the unseparated witness.")
	_drive_to(mouth)
	_drive_to(bend)
	_button(JOY_BUTTON_A)
	_tick()
	_wait_safe(1)
	_check(_status(0) == Evacuation.GroupStatus.STAGED and _mission._witness_at_truce
		and _mission.objective.outcome == Evacuation.Outcome.ACTIVE,
		"Releasing the bend first puts that group and witness in place but cannot complete the mission alone.")
	_drive_to(mouth)
	_button(JOY_BUTTON_A)
	_tick()
	_finish(outlet, safety)
	_check(_worker_clearance, "Both actual walking groups maintain clearance through the full portal-to-safety route.")
	_key(KEY_BACKSPACE)
	_check(_mission.objective.outcome == Evacuation.Outcome.ACTIVE and _mission._field == site
		and _mission.hero_world_position().is_equal_approx(spawn), "Backspace also retries without replacing the valley.")

	_mission.queue_free()
	await process_frame
	if not _failures:
		print("Campaign Sova evacuation: both release orders, physical worker path, real guard/camera controls, no deadline, safety/truce and retry verified.")
	quit(0 if not _failures else 1)


func _finish(outlet: Vector3, safety: Vector3) -> void:
	_wait_safe(0)
	_wait_safe(1)
	_check(_mission.objective.outcome == Evacuation.Outcome.SUCCEEDED and _mission._goal_label.text == "Evacuation complete",
		"Both parties plus the willing witness complete the evacuation.")
	_check(_party(0).distance_to(safety) < 1.0 and _party(1).distance_to(safety) < 1.0
		and _party(0).distance_to(_party(1)) > 1.5, "Workers arrive at two clear positions at Druid safety.")
	_check(_mission._witness.global_position.distance_to(outlet) < 1.0
		and _mission._witness.global_position.distance_to(safety) > 60.0, "The willing witness waits in truce at the distinct tunnel outlet.")


func _wait_safe(group: int) -> void:
	for i in range(60 * 55):
		if _status(group) == Evacuation.GroupStatus.SAFE:
			return
		_tick()
	_check(false, "Worker group %d did not reach the campaign safety marker." % group)


func _drive_to(target: Vector3) -> void:
	var destination := _xz(target)
	var budget := ceili(destination.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 90
	for i in range(budget):
		var remaining := destination - _mission.battle.hero_position
		if remaining.length() < 0.12:
			break
		var input := remaining.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, input.x)
		_axis(JOY_AXIS_LEFT_Y, input.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_mission.hero_world_position().distance_to(target) < 0.13, "Actual hero movement reaches %s." % target)


func _command_move(target: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_camera_3d().unproject_position(target)
	_check(root.get_visible_rect().has_point(event.position), "The guard target is visible in the local sector.")
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)


func _tick(count := 1) -> void:
	for i in range(count):
		var prior := [_party(0), _party(1)]
		_mission._physics_process(DT)
		if _worker_clearance:
			for group in range(2):
				var from := _xz(prior[group])
				var to := _xz(_party(group))
				if from != to and not _mission._terrain.can_move(from, to, true):
					_worker_clearance = false
					_check(false, "Worker group %d intersected terrain near %s." % [group, to])


func _party(group: int) -> Vector3:
	return _mission._groups[group].global_position


func _marker(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _xz(world: Vector3) -> Vector2:
	var local := _mission.to_local(world)
	return Vector2(local.x, local.z)


func _status(group: int) -> Evacuation.GroupStatus:
	return _mission.objective.group_status(group)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
