extends SceneTree

const Scene := preload("res://game/battlefield/mara_moonwash_playtest.tscn")
const Deployment := preload("res://game/campaign_deployments.gd")
const Mission := preload("res://game/battlefield/mara_moonwash_playtest.gd")
const Quay := preload("res://game/battlefield/mara_moonwash_quay.gd")
const Levy := preload("res://game/battlefield/moonwash_levy_patrol.gd")
const Patrol := preload("res://game/battlefield/patrol_detection_policy.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _failures := 0
var _observed_contact := false
var _capture := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")
	var deployment := Deployment.for_mission("mara_moonwash_quay")
	_check(deployment.scene == Scene, "The tested scene is the registered High Quay.")
	_mission = deployment.scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var patrol := _mission.levy
	var spawn := _point("Spawns/LocalLevy")
	_check(patrol.position == spawn and patrol.decision.intent == Patrol.Intent.PATROL and not _mission._levy_status.visible,
		"One levy starts at its authored waypoint without a map-wide alert.")
	_tick(30)
	_check(patrol.position.x < spawn.x and patrol.decision.intent == Patrol.Intent.PATROL,
		"The levy moves along the actual lower quay instead of pursuing an undiscovered party.")

	# Keep the stationary formations clear for the direct hero confrontation.
	for group in _mission.battle.formations:
		group.position = _point("Routes/InlandBypass")
	_drive_spawn_until_contact(spawn)
	var contact_pos := _mission.battle.hero_position
	_check(patrol.decision.intent == Patrol.Intent.ENGAGE and patrol.decision.contact_id == Levy.HERO_ID
		and _mission._levy_status.visible and _mission._levy_status.text.contains("in contact")
		and _mission._levy_label.visible, "Actual hero approach produces a sighting and readable close-contact warning.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick(5)
	_check(patrol.decision.contact_id == Levy.HERO_ID and _mission._follow_shift == Vector3.ZERO
		and root.get_camera_3d() == _mission._command_camera, "Real hero contact never follows the selected platoon or changes camera mode.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var closest := INF
	for step in range(40):
		_set_hero_aim(patrol.position)
		_tick()
		closest = minf(closest, _mission.battle.hero_position.distance_to(patrol.position))
	_stop_hero()
	_check(closest >= Levy.body_clearance(false) - 0.01
		and _mission.battle.hero_position.distance_to(contact_pos) < 0.35
		and _mission.objective.phase == Quay.Phase.WITHDRAWING and not _mission._hero_down,
		"A direct move cannot cross the levy without inventing damage. Closest: %.3f, displacement: %.3f." % [
			closest, _mission.battle.hero_position.distance_to(contact_pos),
		])
	_drive("Routes/QuaySafeTurn")
	_drive("Routes/InlandBypass")
	_tick(210)
	_check(patrol.decision.intent == Patrol.Intent.PATROL and patrol.decision.visible_contacts.is_empty()
		and not _mission._levy_status.visible and not _mission._levy_label.visible,
		"Breaking contact and moving out along the real bypass lets the levy return to its authored patrol.")
	var after_retreat := patrol.position
	_tick(100)
	_check(patrol.position.distance_to(after_retreat) > 1.0 and patrol.decision.intent == Patrol.Intent.PATROL,
		"The returning guard physically moves after losing the contact, not just changing a label.")

	_mission.restart_mission()
	patrol = _mission.levy
	_mission.battle.hero_position = _point("Routes/InlandApproach")
	var group := _mission.battle.formations[1]
	_command()
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_order(group, "Spawns/LocalLevy")
	_joy(JOY_BUTTON_RIGHT_STICK)
	_tick(8)
	_check(not _mission._sector.overview and group.order == Battle.Order.MOVE
		and _mission._follow_shift == Vector3.ZERO, "An approaching guard does not follow before physical contact.")
	_joy(JOY_BUTTON_RIGHT_STICK)
	for step in range(1500):
		if group.order == Battle.Order.BLOCKED:
			break
		_tick()
	_check(group.order == Battle.Order.BLOCKED and patrol.decision.intent == Patrol.Intent.ENGAGE
		and patrol.decision.contact_id == &"Royal Rear Guard",
		"An ordered platoon, not just the hero, reaches physical contact with the levy on the quay.")
	_joy(JOY_BUTTON_A)
	_tick()
	_check(group.order == Battle.Order.HOLD and _mission._levy_status.text.contains("screening"),
		"Hold makes the contact a visible screen while other troops remain movable.")
	await _check_follow(group)

	_mission.restart_mission()
	patrol = _mission.levy
	# Two positions within the finite sight radius, separated by the real storehouse.
	patrol.position = Vector2(63.6, -3.0)
	_mission.battle.hero_position = Vector2(63.6, -17.5)
	_check(_mission.battle.hero_position.distance_to(patrol.position) < Levy.SIGHT_RANGE
		and not _mission._terrain.clear_ranged_lane(_mission._ground(patrol.position, 1.38),
			_mission._ground(_mission.battle.hero_position, 1.30)), "The authored storehouse supplies nearby solid cover.")
	_tick()
	_check(patrol.decision.contact_id != Levy.HERO_ID \
		and not patrol.decision.visible_contacts.any(func(contact: Patrol.Contact) -> bool: return contact.id == Levy.HERO_ID),
		"The actual geometry blocks acquisition of the covered hero even if an uncovered formation alerts the levy.")

	_joy(JOY_BUTTON_START)
	_check(_mission.levy != patrol and _mission.levy.position == spawn and not _mission._levy_status.visible
		and _mission.objective.phase == Quay.Phase.WITHDRAWING, "Retry resets position, alert and memory.")
	_observed_contact = false
	_run_bypass()
	_check(_mission.objective.phase == Quay.Phase.SUCCEEDED and not _observed_contact and _mission._follow_shift == Vector3.ZERO,
		"An actual full withdrawal along the inland approach finishes without physical contact or a follow camera.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("High Quay local levy: authored march, real cover, visible pursuit, physical contact, order-safe follow, retreat, no-contact bypass and retry passed.")
	quit(0 if _failures == 0 else 1)


func _check_follow(group: Battle.Formation) -> void:
	var camera := _mission._command_camera
	var span := _mission.local_sector_size
	_check(_mission._sector.overview and camera.size > span and _mission._follow_shift == Vector3.ZERO,
		"Physical contact never takes over whole-field overview.")
	var baseline := _local_layout("Routes/QuaySafeTurn")
	var cursor := _mission.cursor
	var focus := _mission._sector.focus
	var aim_at := _marker("Routes/InlandBypass")
	var aim_pixel := camera.unproject_position(aim_at.global_position)
	await _capture_frame("ordinary-local-screen")
	_tick(36)
	_check(_mission._follow_shift.length() > 0.0 and _mission._follow_shift.length() <= Mission.FOLLOW_MAX_SHIFT + 0.001
		and camera.position != baseline.origin and camera.basis == baseline.basis and camera.size == span
		and _mission.cursor == cursor and _mission._sector.focus == focus and group.order == Battle.Order.HOLD
		and root.get_camera_3d() == camera, "Real selected contact gives only a bounded 110m orthographic framing shift.")
	await _capture_frame("selected-levy-follow")
	_joy(JOY_BUTTON_DPAD_LEFT)
	_check(_mission.selected_index == 0 and camera.transform == baseline,
		"Selecting away restores the exact ordinary projection before rendering.")
	_tick(12)
	_check(_mission._follow_shift == Vector3.ZERO and camera.transform == baseline
		and _mission.levy.decision.contact_id == &"Royal Rear Guard", "Another platoon's contact never steals the selected camera.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_tick(12)
	_check(_mission._follow_shift != Vector3.ZERO, "Reselect the physical contact to frame it again while idle.")
	_axis(JOY_AXIS_RIGHT_X, 0.13)
	_check(_mission._follow_shift != Vector3.ZERO, "One under-deadzone component does not interrupt follow.")
	_axis(JOY_AXIS_RIGHT_Y, 0.13)
	_check(_mission._follow_shift == Vector3.ZERO and camera.transform == baseline,
		"A diagonally live right stick restores the original camera before the orbit begins.")
	_tick(8)
	_check(camera.basis != baseline.basis and _mission._follow_shift == Vector3.ZERO, "Held orbit works and keeps follow suspended.")
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	baseline = _local_layout("Routes/QuaySafeTurn")
	_tick()
	_axis(JOY_AXIS_LEFT_X, 0.6)
	_check(camera.transform == baseline and _mission._follow_shift == Vector3.ZERO,
		"Moving the real aim stick restores the lens before its next cursor update.")
	_tick(5)
	_check(_mission.cursor != cursor and _mission._follow_shift == Vector3.ZERO, "Manual cursor movement stays in charge.")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	var remote := _local_layout("Routes/InlandApproach")
	_tick(10)
	_check(camera.transform == remote and _mission._follow_shift == Vector3.ZERO,
		"A distant sector where the contact cannot fit does not follow it.")
	baseline = _local_layout("Routes/QuaySafeTurn")
	_tick(12)
	_joy(JOY_BUTTON_RIGHT_STICK)
	_check(camera.size > span and _mission._follow_shift == Vector3.ZERO, "Overview restores from an active contact lens.")
	await _capture_frame("overview-after-follow")
	_joy(JOY_BUTTON_RIGHT_STICK)

	baseline = _local_layout("Routes/QuaySafeTurn")
	aim_pixel = camera.unproject_position(aim_at.global_position)
	_tick(20)
	var motion := InputEventMouseMotion.new()
	motion.position = aim_pixel
	root.push_input(motion, true)
	_check(camera.transform == baseline and _mission._mouse_cursor_active
		and _mission.cursor.distance_to(_point("Routes/InlandBypass")) < 0.05,
		"The first pointer aim uses the exact normal projection, not the shifted lens.")
	_tick(4)
	_check(_mission._follow_shift == Vector3.ZERO, "Pointer aiming keeps follow suspended.")

	baseline = _local_layout("Routes/QuaySafeTurn")
	aim_pixel = camera.unproject_position(aim_at.global_position)
	_tick(20)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = aim_pixel
	root.push_input(click, true)
	_check(camera.transform == baseline and group.order == Battle.Order.MOVE
		and group.destination.distance_to(_point("Routes/InlandBypass")) < 0.05,
		"An immediate right-click from follow issues the exact underlying Move without changing its ray.")
	_joy(JOY_BUTTON_A)
	_tick(10)
	_check(group.order == Battle.Order.HOLD and _mission._follow_shift != Vector3.ZERO,
		"Existing Hold is still delivered and a live contact can reacquire while the camera is idle.")
	baseline = _local_layout("Routes/QuaySafeTurn")
	_tick(10)
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(camera.transform == baseline and _mission._follow_shift == Vector3.ZERO
		and root.get_camera_3d() == _mission._hero_camera and not _mission.command_view,
		"Focus loss restores the exact tactical projection and does not strand the hero in command.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	baseline = _local_layout("Routes/QuaySafeTurn")
	_tick(10)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(camera.transform == baseline and _mission._follow_shift == Vector3.ZERO
		and root.get_camera_3d() == _mission._hero_camera, "L2 release restores the normal lens and direct hero camera.")
	await _capture_frame("hero-after-follow")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_local_layout("Routes/QuaySafeTurn")
	_tick(10)
	_check(_mission._follow_shift != Vector3.ZERO, "Retry fixture has an active shift to remove.")
	_joy(JOY_BUTTON_START)
	_check(_mission._follow_shift == Vector3.ZERO and not _mission.command_view and root.get_camera_3d() == _mission._hero_camera,
		"Options resets an active follow without affecting the ordinary retry.")


func _local_layout(id: String) -> Transform3D:
	# Keep the already-established contact and vary only the pre-existing
	# sector/cursor placement so the camera geometries are deterministic.
	_mission._restore_levy_follow()
	_mission.cursor = _point(id)
	_mission._sector.center_on(_mission.cursor)
	_mission._mouse_cursor_active = false
	_mission._update_cameras()
	_mission._sync_view()
	return _mission._command_camera.transform


func _capture_frame(name: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	for _frame in range(6):
		await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_capture.path_join(name + ".png")) == OK,
		"Save follow QA frame " + name)


func _run_bypass() -> void:
	var vanguard := _mission.battle.formations[0]
	var rear := _mission.battle.formations[1]
	_command()
	_order(vanguard, "Routes/InlandBypass")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_order(rear, "Routes/QuaySafeTurn")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_drive("Routes/QuaySafeTurn")
	_drive("Routes/InlandBypass")
	_wait_for_order(rear, "Routes/QuaySafeTurn")
	_wait_for_order(vanguard, "Routes/InlandBypass")
	_command()
	_order(rear, "Routes/InlandBypass")
	_joy(JOY_BUTTON_DPAD_LEFT)
	_order(vanguard, "Routes/InlandApproach")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_drive("Routes/InlandApproach")
	_wait_for_order(rear, "Routes/InlandBypass")
	_wait_for_order(vanguard, "Routes/InlandApproach")
	_command()
	_joy(JOY_BUTTON_DPAD_RIGHT)
	for id: String in ["Routes/InlandApproach", "Routes/InlandStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		_order(rear, id)
		_wait_for_order(rear, id)
	_joy(JOY_BUTTON_DPAD_LEFT)
	for id: String in ["Routes/InlandStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		_order(vanguard, id)
		_wait_for_order(vanguard, id)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	for id: String in ["Routes/InlandStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		_drive(id)


func _drive_spawn_until_contact(target: Vector2) -> void:
	var saw_pursuit := false
	for step in range(1100):
		if _mission.levy.decision.intent == Patrol.Intent.PURSUE:
			saw_pursuit = true
		if _mission.levy.decision.intent == Patrol.Intent.ENGAGE:
			break
		_set_hero_aim(target)
		_tick()
	_stop_hero()
	_check(saw_pursuit, "The enemy pursues when a genuinely visible nearby hero is acquired.")


func _command() -> void:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1)
	_joy(JOY_BUTTON_RIGHT_STICK)


func _order(group: Battle.Formation, id: String) -> void:
	var target := _marker(id)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = root.get_camera_3d().unproject_position(target.global_position)
	root.push_input(click, true)
	_check(group.order == Battle.Order.MOVE and group.destination.distance_to(_point(id)) < 0.04,
		"A real projected order sends %s toward %s." % [group.title, id])


func _wait_for_order(group: Battle.Formation, id: String) -> void:
	var target := _point(id)
	var budget := ceili(group.position.distance_to(target) / Battle.FORMATION_SPEED / DT) + 95
	for step in range(budget):
		if group.order != Battle.Order.MOVE:
			break
		_tick()
	_check((group.order == Battle.Order.HOLD and group.position.distance_to(target) < 0.05)
		or (id == "Objectives/UpperQuayExit" and group.order == Battle.Order.EXTRACTED),
		"%s actually reaches %s." % [group.title, id])


func _drive(id: String) -> void:
	var target := _point(id)
	var reached := false
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.LEAD_SPEED / DT) + 100
	for step in range(budget):
		if target.distance_to(_mission.battle.hero_position) < 0.14 \
			or (id == "Objectives/UpperQuayExit" and _mission.objective.hero_extracted):
			reached = true
			break
		_set_hero_aim(target)
		_tick()
	_stop_hero()
	_check(reached, "Actual hero travel reaches %s; got %s." % [id, _mission.battle.hero_position])


func _set_hero_aim(target: Vector2) -> void:
	var aim := (target - _mission.battle.hero_position).normalized().rotated(_mission._hero_yaw)
	_march_lead(Vector2(aim.x, aim.y))


func _stop_hero() -> void:
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_LEFT_Y, 0)


func _marker(id: String) -> Marker3D:
	return _mission.battlefield_marker(NodePath("Markers/" + id))


func _point(id: String) -> Vector2:
	var local := _mission.to_local(_marker(id).global_position)
	return Vector2(local.x, local.z)


func _tick(count := 1) -> void:
	for step in range(count):
		_mission._physics_process(DT)
		_observed_contact = _observed_contact or _mission.levy.decision.intent == Patrol.Intent.ENGAGE


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)


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
