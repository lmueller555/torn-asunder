extends SceneTree

const Scene := preload("res://game/battlefield/sova_public_record_playtest.tscn")
const Mission := preload("res://game/battlefield/sova_public_record_playtest.gd")
const Hearing := preload("res://game/battlefield/sova_public_record.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _mission: Mission
var _clears := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var header := _mission.get_node("HearingHUD/Panel/Margin/Readout/Title") as Label
	_check("YEAR THREE" in header.text, "The deployed hearing still uses a pre-Greyhollow date.")
	_mission.mission_cleared.connect(func() -> void: _clears += 1)
	var spawn := _marker(^"Markers/Spawns/SovaHearing")
	_check(_mission.hero_world_position().is_equal_approx(spawn), "Sova did not start at the authored hearing approach.")
	for venue in [Hearing.Venue.OPEN, Hearing.Venue.RECESSED]:
		_play_venue(venue)
		_check(_mission.objective.phase == Hearing.Phase.SUCCEEDED and _mission.objective.passages_read == 3, "Completing three actual passages did not clear the selected venue.")
		var completed := _clears
		_tick(330)
		_check(_clears == completed, "Terminal state emitted another clear.")
		var layout := _mission._layouts[venue]
		for keeper in layout.departing:
			_check(not keeper.visible and keeper.global_position.is_equal_approx(layout.public_exit), "A peaceful Keeper did not reach the real selected exit.")
		_button(JOY_BUTTON_START, true)
		_check(_mission.hero_world_position().is_equal_approx(spawn), "Options did not reset Sova's authored start.")
		_check(_mission.objective.venue == Hearing.Venue.NONE and _mission.objective.passages_read == 0 and _mission._layouts[1].visuals.visible and _mission._layouts[2].visuals.visible, "Replay did not restore both advertised venues and fresh progress.")
	_check(_clears == 2, "There should be one clear per completed placement.")
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Playable hearing: both real lecterns, three passages, physical exit/ring pressure, live guards, neutral exits and replay passed.")
	quit(0 if _failures == 0 else 1)


func _play_venue(venue: Hearing.Venue) -> void:
	var layout := _mission._layouts[venue]
	var other: int = Hearing.Venue.RECESSED if venue == Hearing.Venue.OPEN else Hearing.Venue.OPEN
	var prefix: String = Mission.VENUE_PREFIX[venue]
	var other_exit := _mission._layouts[other].public_exit
	_key(KEY_SPACE, true)
	_tick()
	_key(KEY_SPACE, false)
	_check(_mission.objective.phase == Hearing.Phase.CHOOSING_VENUE, "Remote interaction chose a lectern.")
	_walk(_hearing_marker("OpenWestApproach" if venue == Hearing.Venue.OPEN else "RecessedApproach"))
	_walk(layout.ring_center)
	_walk(layout.lectern)
	_check(layout.public_exit == _hearing_marker(prefix + "PublicExit") and layout.scribe.global_position == _hearing_marker(prefix + "Scribe"), "The venue did not bind its authored public exit and scribe.")

	_key(KEY_SHIFT, true)
	_button(JOY_BUTTON_A, true)
	_tick()
	_button(JOY_BUTTON_A, false)
	_check(_mission.battle.formations[0].order == Battle.Order.HOLD and _mission.objective.venue == Hearing.Venue.NONE, "Command Cross did not stay a Hold.")
	_key(KEY_SHIFT, false)
	_read(venue, true)
	_advance_until(func() -> bool: return _mission.objective.passages_read == 1)
	_read(venue, false)
	_check(_mission.objective.venue == venue and layout.visuals.visible and not _mission._layouts[other].visuals.visible, "Cross/Space did not lock the selected public ring and exit.")
	_check(_mission.objective.phase == Hearing.Phase.READING and _clears == (0 if venue == Hearing.Venue.OPEN else 1), "The first passage prematurely cleared the hearing.")
	var keeper_start: Vector3 = layout.departing[1].global_position
	_tick(25)
	_check(layout.departing[1].global_position.distance_to(keeper_start) > 1.0 and _mission.objective.phase == Hearing.Phase.READING and _mission.battle.formations.size() == 2, "Neutral Keepers did not visibly depart, or their movement disrupted the hearing.")

	_read(venue, true)
	_tick(14)
	_read(venue, false)
	var partial := _mission.objective.passage_progress
	_check(partial > 0.2, "The current passage has no player-driven progress.")
	var assembly := _marker(^"Markers/Routes/ValleyAssembly")
	var guard := _mission.battle.formations[0]
	_route_guard(guard, [_guard_marker("MusterTurn")])
	_give_order(0, assembly)
	var from := guard.position
	_tick(24)
	_check(guard.position.distance_to(from) > 1.0 and not _mission.command_view and is_equal_approx(_mission.objective.passage_progress, partial), "An allied Move order did not stay live after returning to the lectern.")
	_await_guard(guard, assembly)

	# A guard physically blocks the chosen public exit. The other exit remains independent.
	var shared_west := _guard_marker("OpenWestLane")
	var exit_lane := _guard_marker(prefix + "WestLane")
	if venue == Hearing.Venue.RECESSED:
		_route_guard(guard, [shared_west, _hearing_marker("RecessedApproach")])
	_route_guard(guard, [exit_lane])
	_check(guard.position.distance_to(_flat(other_exit)) > 20.0 and _mission.objective.interruption == Hearing.Interruption.EXIT_BLOCKED and layout.exit_label.text.contains("Blocked"), "The public exit warning was not tied to the physically blocked selected exit.")
	_read(venue, true)
	_tick(25)
	_read(venue, false)
	_check(is_equal_approx(_mission.objective.passage_progress, partial) and _mission.objective.passages_read == 1, "Reading through a blocked exit changed progress.")
	if venue == Hearing.Venue.RECESSED:
		_route_guard(guard, [_hearing_marker("RecessedApproach"), shared_west])
	_route_guard(guard, [assembly])
	_check(_mission.objective.phase == Hearing.Phase.READING and layout.exit_label.text.contains("Open"), "Moving the guard reopened no path to resume.")
	if venue == Hearing.Venue.OPEN:
		_route_guard(guard, [exit_lane, layout.ring_center])
		_check(_mission.objective.interruption == Hearing.Interruption.RING_CONTESTED and _mission.objective.passage_progress == 0.0 and _mission.objective.passages_read == 1, "An armed formation entering the real ring did not reset only the current passage.")
		_route_guard(guard, [exit_lane, assembly])
		_read(venue, true)
		_tick(12)
		_read(venue, false)

	# Sova stepping away resets only the current passage. Going back to the same
	# actual lectern permits further reading, but arriving alone isn't a clear.
	_walk(layout.ring_center)
	_check(_mission.objective.interruption == Hearing.Interruption.LEFT_LECTERN and _mission.objective.passage_progress == 0.0 and _mission.objective.passages_read == 1, "Leaving the podium did not reset only the active passage.")
	_walk(layout.lectern)
	_read(venue, true)
	_advance_until(func() -> bool: return _mission.objective.passages_read == 2)
	_read(venue, false)
	_check(_mission.objective.phase != Hearing.Phase.SUCCEEDED, "Two passages cleared the hearing.")
	_read(venue, true)
	_advance_until(func() -> bool: return _mission.objective.phase == Hearing.Phase.SUCCEEDED)
	_read(venue, false)


func _route_guard(guard: Battle.Formation, route: Array) -> void:
	for point: Vector3 in route:
		_give_order(0, point)
		_await_guard(guard, point)


func _give_order(index: int, world: Vector3) -> void:
	_key(KEY_SHIFT, true)
	_mission.selected_index = index
	_mission.cursor = _flat(world)
	_button(JOY_BUTTON_X, true)
	_key(KEY_SHIFT, false)


func _await_guard(guard: Battle.Formation, world: Vector3) -> void:
	_advance_until(func() -> bool: return guard.order != Battle.Order.MOVE)
	_check(guard.position.is_equal_approx(_flat(world)), "The commanded formation did not reach its real point: %s (at %s)." % [world, guard.position])


func _walk(target: Vector3) -> void:
	for _index in range(600):
		var distance := _flat(target) - _flat(_mission.hero_world_position())
		if distance.length() < 0.18:
			break
		var stick := distance.normalized().rotated(_mission._hero_yaw)
		_march_lead(Vector2(stick.x, stick.y))
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_flat(target).distance_to(_flat(_mission.hero_world_position())) < 0.2, "Sova could not walk to %s from %s." % [target, _mission.hero_world_position()])


func _read(venue: Hearing.Venue, down: bool) -> void:
	if venue == Hearing.Venue.OPEN:
		_button(JOY_BUTTON_A, down)
	else:
		_key(KEY_SPACE, down)


func _advance_until(condition: Callable) -> void:
	for _index in range(950):
		if condition.call():
			return
		_tick()
	_check(false, "An expected motion or passage did not complete.")


func _marker(path: NodePath) -> Vector3:
	return _mission.battlefield_marker(path).global_position


func _guard_marker(id: String) -> Vector3:
	return (_mission.get_node("GuardRoutes/" + id) as Marker3D).global_position


func _hearing_marker(id: String) -> Vector3:
	return _marker(NodePath("Markers/Hearing/" + id))


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _tick(count := 1) -> void:
	for _index in range(count):
		_mission._physics_process(0.05)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _button(code: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = down
	root.push_input(event, true)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


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
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED * (1.0 / 60.0))
