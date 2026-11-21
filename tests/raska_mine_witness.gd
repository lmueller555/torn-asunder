extends SceneTree

const Scene := preload("res://game/battlefield/raska_mine_witness.tscn")
const Mission := preload("res://game/battlefield/raska_mine_witness.gd")
const Witness := preload("res://game/battlefield/orc_mine_witness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const ROUTE := ["RidgeEastFoot", "RidgeOverlook", "RidgeWestFoot", "RoadWest", "MineYard", "TunnelEntrance", "TunnelMidpoint", "TunnelExit"]

var _mission: Mission
var _failures := 0
var _hero_arrived_without_witness := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var spawn := _marker(^"Markers/Spawns/OrcCrewParty")
	var rally := _marker(Mission.RALLY)
	var outlet := _marker(Mission.OUTLET)
	_check(_mission.hero_world_position() == spawn, "Raska did not start at the actual Orc Crew Party spawn.")

	_walk(rally)
	_press(KEY_SPACE)
	_tick(4)
	_check(_mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER, "Raska alone cannot win by interacting at his rally.")
	_press(KEY_BACKSPACE)
	for waypoint in ROUTE:
		_walk(_route(waypoint))
	_check(_mission._window_started and not _mission._screen_held and _mission._detachment.global_position.distance_to(_mission._screen_start) > 0.1, "Approaching the outlet did not visibly start the detachment's advance.")
	_press(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER, "Raska cannot accept terms before the crew escapes.")
	_tick(800)
	_check(_mission.objective.phase == Witness.Phase.FAILED and _mission.objective.failure == Witness.Failure.OUTLET_WINDOW_CLOSED and _mission._detachment.global_position == _mission._screen_end, "The final window should close only when the detachment reaches the marked approach.")

	_button(JOY_BUTTON_START)
	_check(_mission.hero_world_position() == spawn and not _mission._window_started and _mission._detachment.global_position == _mission._screen_start, "Options did not reset hero, window and detachment.")
	for waypoint in ROUTE:
		_walk(_route(waypoint))
	_walk(_mission._screen_end)
	_walk(_route("EvacuationTrail"))
	_tick(60)
	_check(_mission._screen_held, "Raska could not intercept the scripted detachment before its arrival.")
	_walk(_mission._screen_end)
	_walk(outlet)
	_tick(680)
	_check(_mission.objective.phase == Witness.Phase.TERMS_OFFERED and _mission._crew.global_position == _marker(Mission.SAFETY), "The witness did not offer terms after the other workers reached actual Druid safety.")
	_check(_mission._witness.global_position.distance_to(outlet) < 1.0, "The willing witness was not waiting at the outlet.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mission.battle.order_move(0, _mission.battle.formations[0].position + Vector2.LEFT)
	_button(JOY_BUTTON_A)
	_press(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Witness.Phase.TERMS_OFFERED and _mission.battle.formations[0].order == Battle.Order.HOLD, "Command Cross must remain Hold, not accept the witness's offer.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_A)
	_tick(2)
	_check(_mission.objective.phase == Witness.Phase.ESCORTING and _mission._rally_beacon.visible, "Hero-view Cross did not accept the offer and reveal the real rally.")
	_walk(_route("TunnelMidpoint"))
	_check(_mission._witness.global_position.distance_to(outlet) > 4.0 and absf(_mission._witness.global_position.x - outlet.x) < 0.5, "The witness did not physically follow Raska down the tunnel.")
	for index in range(ROUTE.size() - 3, -1, -1):
		_walk(_route(ROUTE[index]))
	_walk(spawn)
	_walk(rally)
	_tick(110)
	_check(_hero_arrived_without_witness, "The hero reaching the rally before the witness must not complete the escort.")
	_check(_mission._witness.global_position.distance_to(rally) <= Mission.RALLY_RADIUS and _mission.objective.phase == Witness.Phase.SUCCEEDED, "Only the witness's arrival at the real rally should finish the escort.")
	_mission._restart.pressed.emit()
	_check(_mission.objective.phase == Witness.Phase.WAITING_FOR_OFFER and not _mission._screen_held and not _mission._rally_beacon.visible, "The HUD replay did not reset escort and staging state.")
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Raska mine witness: ridge/tunnel traversal, visible pressure, terms and Hold separation, safe workers, actual delivery and replay passed.")
	quit(0 if _failures == 0 else 1)


func _route(id: String) -> Vector3:
	return _marker(NodePath("Markers/Routes/" + id))


func _marker(path: NodePath) -> Vector3:
	return _mission.battlefield_marker(path).global_position


func _walk(target: Vector3) -> void:
	for _frame in range(850):
		var delta := target - _mission.hero_world_position()
		var horizontal := Vector2(delta.x, delta.z)
		if horizontal.length() < 0.15:
			break
		if _mission._finished():
			break
		var stick := horizontal.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	var reached := _mission.hero_world_position()
	# Success can resolve as the witness arrives while the hero is still near the rally.
	_check(Vector2(reached.x, reached.z).distance_to(Vector2(target.x, target.z)) < 0.20 or _mission.objective.phase == Witness.Phase.SUCCEEDED, "Could not walk to %s from %s." % [target, reached])


func _tick(count := 1) -> void:
	for _index in range(count):
		_mission._physics_process(1.0 / 60.0)
		if (_mission.objective.phase == Witness.Phase.ESCORTING
				and _mission.hero_world_position().distance_to(_mission._rally) <= Mission.RALLY_RADIUS
				and _mission._witness.global_position.distance_to(_mission._rally) > Mission.RALLY_RADIUS):
			_hero_arrived_without_witness = true


func _press(code: Key) -> void:
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
