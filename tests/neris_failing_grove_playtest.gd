extends SceneTree

const Scene := preload("res://game/battlefield/neris_failing_grove_playtest.tscn")
const Mission := preload("res://game/battlefield/neris_failing_grove_playtest.gd")
const Grove := preload("res://game/battlefield/neris_failing_grove.gd")
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
	_exercise()
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Neris grove: genuine inputs and movement, patrol/screen and pause/resume, raised-road sled, neutral well, nursery transplant and retry passed.")
	quit(0 if _failures == 0 else 1)


func _exercise() -> void:
	var objective := _mission.objective
	var sled_spawn := _marker("Spawns/RootSled")
	var crew_spawn := _marker("Spawns/VolunteerCrew")
	_check(_mission._sled_banner.text == "ROOT SLED" and _mission._sled_banner.is_visible_in_tree()
		and _mission._sled_banner.modulate.a == 1.0 and not _mission._crew_banner.is_visible_in_tree(),
		"The distant original sled remains named, and uncalled volunteers aren't shown.")
	_check(_mission._sled.global_position == sled_spawn and _mission._crew.global_position == crew_spawn and not _mission._crew.visible,
		"Starting sled and volunteers must use actual spawn markers.")
	_key(KEY_SPACE)
	_tick()
	_check(objective.phase == Grove.Phase.AWAITING_ENVOY, "A remote interaction must not reach the envoy.")
	_drive_to(_marker("Routes/GroveAssembly"))
	_drive_to(sled_spawn + Vector3(0.0, 0.0, -10.0))
	_check(_mission._sled_banner.is_visible_in_tree() and _mission._sled_banner.modulate.a > 0.0
		and _mission._sled_banner.modulate.a < 1.0
		and is_equal_approx(_mission._sled_banner.modulate.a, _mission._sled_banner.outline_modulate.a),
		"The nearby transition fades both the sled text face and outline smoothly.")
	_drive_to(_marker("Objectives/GroveEnvoy"))
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_A)
	_tick()
	_check(objective.phase == Grove.Phase.AWAITING_ENVOY, "Command-view Hold must not activate the envoy.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_A)
	_tick()
	_check(objective.phase == Grove.Phase.AWAITING_VOLUNTEERS and _mission._call_beacon.visible and not _mission._crew.visible,
		"Hero Cross at the envoy should expose the separate call point.")
	_key(KEY_SPACE)
	_tick()
	_check(objective.phase == Grove.Phase.AWAITING_VOLUNTEERS, "Repeating the envoy interaction must not call volunteers remotely.")

	_drive_to(_marker("Objectives/VolunteerCall"))
	_key(KEY_SPACE)
	_tick()
	var patrol_spawn := _mission._patrol.global_position
	_tick(25)
	_check(objective.phase == Grove.Phase.LOADING and objective.loading_progress == 0.0 and _mission._crew.visible \
		and _mission._crew.global_position != crew_spawn and _mission._sled.global_position != sled_spawn,
		"Volunteers and sled must move to the pad before any loading.")
	_check(_mission._patrol.visible and _mission._patrol.global_position != patrol_spawn and _mission._screen_beacon.visible,
		"The low-track warning should correspond to an actual advancing patrol.")
	_wait(func() -> bool: return objective.interruption == Grove.Interruption.YARD_CONTESTED, 950)
	_check(objective.phase == Grove.Phase.LOADING and objective.interruption == Grove.Interruption.YARD_CONTESTED \
		and _mission._in_zone(_mission._patrol, _mission._yard_zone), "Visible physical yard pressure must pause loading.")
	var work_before := objective.loading_progress
	_tick(60)
	_check(is_equal_approx(work_before, objective.loading_progress), "Waiting under pressure cannot add or erase work.")

	_drive_to(_marker("Objectives/RootBallLoad") + Vector3(3.6, 0.0, -3.1))
	_check(_mission._sled.visible and _mission._crew.visible and not _mission._sled_banner.is_visible_in_tree()
		and not _mission._crew_banner.is_visible_in_tree() and _mission._screen_beacon.visible,
		"Close hero view clears only the two overlapping captions, not the actors or screen beacon.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	_check(_mission._sled_banner.is_visible_in_tree() and _mission._crew_banner.is_visible_in_tree()
		and _mission._sled_banner.modulate.a == 1.0 and _mission._crew_banner.outline_modulate.a == 1.0,
		"Actual tactical input immediately restores both original captions at full opacity.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_DPAD_RIGHT) # Select the guard that holds the track.
	var guard := _mission.battle.formations[1]
	_order_at(_marker("Routes/LoadingScreenHold"))
	_wait(func() -> bool: return guard.order != Battle.Order.MOVE, 500)
	_check(_mission.selected_index == 1 and guard.order == Battle.Order.HOLD and guard.position.distance_to(_xz(_marker("Routes/LoadingScreenHold"))) < 0.15,
		"The actual mapped formation order must reach and hold at the track screen.")
	_wait(func() -> bool: return objective.interruption == Grove.Interruption.NONE, 480)
	_check(objective.phase == Grove.Phase.LOADING and not _mission._in_zone(_mission._patrol, _mission._yard_zone),
		"Holding should make the patrol physically leave the yard and allow work to resume.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_wait(func() -> bool: return objective.phase == Grove.Phase.ESCORTING, 650)
	_check(objective.phase == Grove.Phase.ESCORTING and objective.loading_progress == 1.0 and not _mission._cloth.visible \
		and _mission._sled.global_position.distance_to(_marker("Objectives/RootBallLoad")) < 0.2
		and _mission._tree.global_position.y > _mission._sled.global_position.y,
		"The tree must finish loading visibly before road travel.")

	_check(_mission._sled_banner.text == "LOADED ROOT SLED" and not _mission._sled_banner.is_visible_in_tree()
		and not _mission._crew_banner.is_visible_in_tree(),
		"The loaded state stays accurate and nearby hero captions remain clear.")
	var previous := _mission._sled.global_position
	var visited := 0
	for tick in range(3400):
		if objective.phase != Grove.Phase.ESCORTING:
			break
		_tick()
		var current := _mission._sled.global_position
		if not _check(current.distance_to(previous) <= Mission.SLED_SPEED * DT + 0.01 and current.y >= 2.8,
			"The actual sled must move on the raised track without warping or dropping onto the foot approach."):
			break
		if _mission._sled_next > visited:
			_check(current.distance_to(_marker(Mission.SLED_ROUTE[visited])) < 0.18, "Sled skipped a required authored waypoint.")
			visited = _mission._sled_next
		previous = current
	var bed := _marker("Objectives/TransplantBed")
	_check(objective.phase == Grove.Phase.AWAITING_TRANSPLANT and _outcomes.is_empty() and visited == Mission.SLED_ROUTE.size() \
		and _mission._sled.global_position.distance_to(bed) < 0.18, "Actual nursery arrival must wait for Neris's explicit transplant.")

	for path in Mission.SLED_ROUTE:
		_drive_to(_marker(path))
	_drive_to(_marker("Landmarks/ExistingWell") + Vector3(0.0, 0.0, 4.0))
	_key(KEY_SPACE)
	_tick()
	_check(objective.phase == Grove.Phase.AWAITING_TRANSPLANT and _outcomes.is_empty(), "The existing town well has no mission interaction.")
	_drive_to(bed)
	_button(JOY_BUTTON_A)
	_tick(12)
	_check(objective.phase == Grove.Phase.SUCCEEDED and _outcomes == [true] and _mission._goal.text.contains("planted") \
		and _mission._tree.global_position.distance_to(_mission._sled.global_position) > 2.9,
		"Physical transplant wins exactly once and moves the tree into the nursery soil.")

	_check(_mission._sled.visible and _mission._sled_banner.text == "EMPTY ROOT SLED"
		and not _mission._sled_banner.is_visible_in_tree() and not _mission._crew.visible,
		"Planting leaves the original empty sled, removes its stale loaded cue, and retires the volunteers.")
	_key(KEY_BACKSPACE)
	_check(_mission._sled_banner.is_visible_in_tree() and _mission._sled_banner.text == "ROOT SLED"
		and _mission._sled_banner.modulate.a == 1.0 and not _mission._crew_banner.is_visible_in_tree(),
		"Real restart restores the original distant label and no volunteers.")
	_check(objective.phase == Grove.Phase.AWAITING_ENVOY and _mission._sled.global_position == sled_spawn and not _mission._patrol.visible \
		and not _mission._crew.visible and _mission._cloth.visible and not _mission.command_view,
		"Restart must reset actors, clothing, terrain poses, and objective gates.")
	_mission.report_sled_destroyed()
	_tick(12)
	_check(objective.phase == Grove.Phase.FAILED and objective.failure == Grove.Failure.SLED_DESTROYED and _outcomes == [true, false],
		"An explicit future destruction report should produce one failure; patrol presence alone never does.")


func _marker(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _xz(at: Vector3) -> Vector2:
	var local := _mission.to_local(at)
	return Vector2(local.x, local.z)


func _drive_to(at: Vector3) -> void:
	var point := _xz(at)
	var budget := ceili(_mission.battle.hero_position.distance_to(point) / Battle.LEAD_SPEED / DT) + 55
	for tick in range(budget):
		var offset := point - _mission.battle.hero_position
		if offset.length() <= 0.18:
			break
		var aim := offset.normalized().rotated(_mission._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y))
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_mission.battle.hero_position.distance_to(point) <= 0.18, "Neris did not physically reach %s (stopped at %s)." % [point, _mission.battle.hero_position])


func _order_at(at: Vector3) -> void:
	var pointer := root.get_camera_3d().unproject_position(at)
	_check(root.get_visible_rect().has_point(pointer), "The screen order must use a projected target on the real map.")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = pointer
	root.push_input(event, true)


func _wait(condition: Callable, budget: int) -> void:
	for tick in range(budget):
		if condition.call():
			break
		_tick()


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
	for tick in range(count):
		_mission._physics_process(DT)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures += 1
		push_error(message)
	return ok


## Outside combat the leader travels with their platoon by Move orders, as the
## player sets them; in combat the stick steers the leader directly.
func _march_lead(aim: Vector2) -> void:
	var battle = _mission.battle
	if battle.direct_hero_control():
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		return
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if aim.length_squared() > 0.0:
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED * DT)
