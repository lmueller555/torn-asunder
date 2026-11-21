extends SceneTree

const Scene := preload("res://game/battlefield/raska_mine_witness_campaign.tscn")
const Mission := preload("res://game/battlefield/raska_mine_witness.gd")
const Witness := preload("res://game/battlefield/orc_mine_witness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0
const ROUTE := [
	"OrcApproach", "RidgeEastFoot", "RidgeEastCrest", "RidgeOverlook", "RidgeWestCrest",
	"RidgeWestFoot", "RidgeWestApproach", "WestAssembly", "QuarryTurn", "RoadWest",
	"MineYard", "TunnelEntrance", "TunnelMidpoint", "TunnelExit",
]

var _mission: Mission
var _failures := 0
var _clear_pawns := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var spawn := _point("Spawns/OrcCrewParty")
	var rally := _point("Routes/OrcApproach")
	var outlet := _point("Routes/TunnelExit")
	var turn := _point("Routes/EvacuationTurn")
	var safety := _point("Objectives/MinerEvacuation")
	var site := _mission._field
	var hero_camera := root.get_camera_3d()
	_check(site.name == &"YearOneMineCampaign" and _mission.hero_world_position().is_equal_approx(spawn)
		and rally.distance_to(outlet) > 210.0, "The witness mission uses the actual campaign valley and wide staging distance.")
	_check(_mission._crew_route[2] == turn and _mission._crew_route[-1] == safety,
		"The civilian route clears the far portal before turning west to Druid safety.")

	_tick(60 * 65)
	_check(not _mission._window_started and not _mission._detachment.visible
		and _mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER,
		"No global timer moves the detachment before Raska reaches the outlet.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var sector := root.get_camera_3d()
	_check(sector != hero_camera and sector.size == 116.0 and _mission._mode_label.text.begins_with("TACTICAL SECTOR"),
		"L2 shows the close tactical sector.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_check(_mission._sector.overview and sector.size > 390.0
		and root.get_visible_rect().has_point(sector.unproject_position(outlet)),
		"Wide overview frames the far outlet while Raska is still at the east start.")
	_button(JOY_BUTTON_LEFT_STICK)
	_check(not _mission._sector.overview and _mission._sector.view_center().is_equal_approx(_xz(spawn)),
		"L3 returns to the playable local sector.")

	var pass_screen := _mission.battle.formations[0]
	var reserve := _point("Routes/EastReserve")
	_command_move(reserve)
	_check(pass_screen.order == Battle.Order.MOVE and pass_screen.destination.distance_to(_xz(reserve)) < 0.04,
		"A real tactical mouse input orders the pass screen to its east reserve.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(root.get_camera_3d() == hero_camera and _mission._field == site,
		"Returning to Raska keeps the same battlefield and formation route.")

	_follow_route(ROUTE)
	_check(pass_screen.order == Battle.Order.HOLD and pass_screen.position.distance_to(_xz(reserve)) < 0.04,
		"The pass screen walks to the reserve while Raska crosses the valley.")
	_check(_mission._window_started and _mission._detachment.visible and _mission._screen_beacon.visible
		and _mission._goal.text.contains("from sealing"), "The outlet triggers a visible and announced detachment advance.")
	_wait_for(Witness.Phase.FAILED, 60 * 30)
	_check(_mission.objective.failure == Witness.Failure.OUTLET_WINDOW_CLOSED
		and _mission._detachment.global_position == _mission._screen_end
		and _mission._goal.text == "The detachment sealed the outlet",
		"The failure is caused by the detachment reaching its physical seal marker, not by an invisible timer.")
	_check(_mission._crew.global_position.distance_to(safety) > 1.0, "Ignoring the attack cuts off workers before safety.")

	_key(KEY_BACKSPACE)
	_check(_mission.hero_world_position().is_equal_approx(spawn) and not _mission._window_started
		and not _mission._screen_held and _mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER,
		"Backspace restarts the large map, its civilians and the visible event.")
	_follow_route(ROUTE)
	_drive_to(turn)
	_drive_to(_point("Routes/EvacuationTrail"))
	for i in range(240):
		if _mission._screen_held:
			break
		_walk_tick(_mission._detachment.global_position)
	_stop()
	_check(_mission._screen_held and not _mission._detachment.visible
		and _mission._goal.text.contains("Outlet screened") and _mission._hint.text.contains("Druid safety"),
		"Raska can visibly intercept the flank threat and the HUD explains the civilians' remaining objective.")
	_drive_to(_point("Routes/EvacuationTrail"))
	_drive_to(turn)
	_drive_to(outlet)
	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER,
		"An early interaction at the outlet cannot pre-accept the witness's terms.")
	_wait_for(Witness.Phase.TERMS_OFFERED, 60 * 35)
	_check(_mission._crew.global_position.is_equal_approx(safety) and _mission._goal.text.contains("offers her terms"),
		"The witness offer is triggered by the civilians' actual safe arrival.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_A)
	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Witness.Phase.TERMS_OFFERED,
		"Command controls cannot accept the offer on Raska's behalf.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_A)
	_tick(2)
	_check(_mission.objective.phase == Witness.Phase.ESCORTING and _mission._rally_beacon.visible
		and _mission._goal.text.contains("Escort the witness"), "Raska accepts in person and gets the rally escort objective.")

	var return_route := ROUTE.duplicate()
	return_route.reverse()
	return_route.pop_front() # already at the outlet
	return_route.pop_back() # stop just inside the Orc rally before the witness arrives
	_follow_route(return_route)
	var prior := _mission.hero_world_position()
	var near_rally := rally + (prior - rally).normalized() * 2.0
	_drive_to(near_rally)
	_tick(60)
	_check(_mission.hero_world_position().distance_to(rally) < Mission.RALLY_RADIUS
		and _mission._witness.global_position.distance_to(rally) > Mission.RALLY_RADIUS
		and _mission.objective.phase == Witness.Phase.ESCORTING,
		"Raska entering the rally doesn't win while the witness stays outside its boundary.")
	_drive_to(rally, true)
	_check(_mission.objective.phase == Witness.Phase.SUCCEEDED
		and _mission._witness.global_position.distance_to(rally) <= Mission.RALLY_RADIUS
		and _mission._goal.text == "Witness safe at the Orc rally",
		"The witness physically follows the full ridge route and completes the mission on her own arrival.")
	_check(_clear_pawns, "All animated detachment, civilian and witness routes stayed clear of physical terrain.")
	_button(JOY_BUTTON_START)
	_check(_mission.hero_world_position().is_equal_approx(spawn) and _mission._field == site
		and _mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER,
		"Options restarts the successful attempt without replacing the battlefield.")

	_mission.queue_free()
	await process_frame
	if not _failures:
		print("Campaign Raska witness: real large-map inputs; visible detachment interception and failure; civilian safety; offer, acceptance, personal escort, arrival, and retry verified.")
	quit(0 if not _failures else 1)


func _follow_route(route: Array) -> void:
	for id: String in route:
		_drive_to(_point("Routes/" + id))


func _drive_to(target: Vector3, allow_success := false) -> void:
	var budget := ceili(_mission.hero_world_position().distance_to(target) / Battle.HERO_SPEED / DT) + 90
	for i in range(budget):
		if _mission.hero_world_position().distance_to(target) < 0.13 or _mission._finished():
			break
		_walk_tick(target)
	_stop()
	_check(_mission.hero_world_position().distance_to(target) < 0.14
		or allow_success and _mission.objective.phase == Witness.Phase.SUCCEEDED,
		"Actual hero movement reaches %s; got %s." % [target, _mission.hero_world_position()])


func _walk_tick(target: Vector3) -> void:
	var aim := (_xz(target) - _mission.battle.hero_position).normalized().rotated(_mission._hero_yaw)
	_axis(JOY_AXIS_LEFT_X, aim.x)
	_axis(JOY_AXIS_LEFT_Y, aim.y)
	_tick()


func _stop() -> void:
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)


func _wait_for(phase: Witness.Phase, budget: int) -> void:
	for i in range(budget):
		if _mission.objective.phase == phase or _mission._finished():
			break
		_tick()
	_check(_mission.objective.phase == phase, "Expected phase %s, got %s." % [phase, _mission.objective.phase])


func _command_move(target: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_camera_3d().unproject_position(target)
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)


func _point(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _xz(point: Vector3) -> Vector2:
	var local := _mission.to_local(point)
	return Vector2(local.x, local.z)


func _tick(count := 1) -> void:
	for i in range(count):
		var actors := [_mission._detachment, _mission._crew, _mission._witness]
		var previous := [_xz(actors[0].global_position), _xz(actors[1].global_position), _xz(actors[2].global_position)]
		_mission._physics_process(DT)
		if not _clear_pawns:
			continue
		for actor in range(actors.size()):
			var position := _xz(actors[actor].global_position)
			if position != previous[actor] and not _mission._terrain.can_move(previous[actor], position, actor < 2):
				_clear_pawns = false
				_check(false, "Moving actor %d crossed obstructed terrain at %s." % [actor, position])


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


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


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
