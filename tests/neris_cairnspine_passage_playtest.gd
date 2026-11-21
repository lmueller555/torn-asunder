extends SceneTree

const Scene := preload("res://game/battlefield/neris_cairnspine_passage_playtest.tscn")
const Mission := preload("res://game/battlefield/neris_cairnspine_passage_playtest.gd")
const Passage := preload("res://game/battlefield/neris_cairnspine_passage.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Group := Passage.Group
const Route := Passage.Route
const Status := Passage.Status
const Outcome := Passage.Outcome

var _mission: Mission
var _results: Array[bool] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_finished.connect(func(won: bool) -> void: _results.append(won))
	if _debug_visuals_reused() and _split_and_screen() and _reroute() and _defeat_and_retry():
		print("Neris passage playtest: physical separate guides, both lanes and detachments, waiting/guard recovery, fresh reroute by backtracking, two terrace arrivals, defeat and reset passed.")
	_mission.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _debug_visuals_reused() -> bool:
	var friendly: Node3D = _mission._formation_members[1][0]
	var reference := friendly.get_child(0) as MeshInstance3D
	var refugee := _mission._parties[Group.REFUGEES].actor.get_child(0).get_child(0) as MeshInstance3D
	return _check(refugee.mesh == reference.mesh and refugee.material_override == reference.material_override,
		"The playtest added its own character art instead of reusing the existing debug actor.")


func _split_and_screen() -> bool:
	if not _reset_ok() or not _prepare_parties(true):
		return false
	if not _dispatch("ShelfDecision", Group.REFUGEES, Route.SHELF) \
			or not _dispatch("SideDecision", Group.WITNESSES, Route.SIDE):
		return false
	if not _both_blocked():
		return false
	var party := _mission._parties[Group.REFUGEES]
	var before := party.position
	var witness := _mission._parties[Group.WITNESSES].position
	_tick(70)
	if not _check(party.position == before and witness == _mission._parties[Group.WITNESSES].position
		and _mission.objective.outcome == Outcome.ACTIVE, "Contested groups walked into melee or waiting fabricated a failure."):
		return false

	for marker: String in Mission.SIDE + Mission.TERRACE:
		if not _walk(_mission._route(marker)):
			return false
	if not _walk(_mission._spot("Objectives", "WitnessTerrace")):
		return false
	_press_interact(false)
	if not _check(_results.is_empty() and _mission.objective.outcome == Outcome.ACTIVE,
		"Hero presence or interaction on the terrace completed rescue on its own."):
		return false

	if not _screen(0, Mission.SHELF) or not _until(
		func() -> bool: return _mission.objective.group_status(Group.REFUGEES) == Status.SAFE, "Refugees did not physically reach their terrace on the screened shelf."
	):
		return false
	if not _check(_in_terrace(Group.REFUGEES)
		and _mission.objective.group_status(Group.WITNESSES) == Status.BLOCKED and _results.is_empty(),
		"One group reaching its safe marker improperly released the other or cleared the mission."):
		return false
	if not _screen(1, Mission.SIDE) or not _until(func() -> bool: return not _results.is_empty(), "The screened side route never delivered the witnesses."):
		return false
	return _check_complete([true])


func _reroute() -> bool:
	_button(JOY_BUTTON_START, true)
	_button(JOY_BUTTON_START, false)
	if not _reset_ok() or not _prepare_parties(false):
		return false
	if not _dispatch("ShelfDecision", Group.REFUGEES, Route.SHELF) \
			or not _dispatch("SideDecision", Group.WITNESSES, Route.SIDE) or not _both_blocked():
		return false
	var refugee := _mission._parties[Group.REFUGEES]
	var origin := refugee.position
	if not _walk(_mission._route("SafeStaging")):
		return false
	_press_interact(false)
	if not _check(_mission.objective.group_route(Group.REFUGEES) == Route.SHELF and refugee.position == origin,
		"Reroute accepted an interaction away from a decision point."):
		return false
	if not _walk(_mission._route("SideDecision")):
		return false
	_tick(12)
	if not _check(_mission.objective.group_route(Group.REFUGEES) == Route.SHELF, "Visiting a decision point rerouted automatically."):
		return false
	_press_interact(true)
	var old_climb := _mission._route("ShelfClimb")
	if not _check(_mission.objective.group_route(Group.REFUGEES) == Route.SIDE
		and refugee.position.distance_to(origin) < 1.0 and refugee.next_stop() == old_climb,
		"The fresh alternate order teleported the refugees or skipped the safe way back."):
		return false
	if not _until(
		func() -> bool: return refugee.position == _mission._route("SafeStaging") or refugee.next_stop() == _mission._route("SideDecision"),
		"The rerouted party never physically backtracked to staging."
	):
		return false
	if not _screen(1, Mission.SIDE) or not _until(func() -> bool: return _results.size() == 2, "Both groups did not finish by the only screened route."):
		return false
	return _check(_mission._patrols[0].contests(), "Rerouting illicitly erased the shelf company.") and _check_complete([true, true])


func _defeat_and_retry() -> bool:
	_key(KEY_BACKSPACE, true)
	_key(KEY_BACKSPACE, false)
	if not _reset_ok():
		return false
	_mission.report_group_lost(Group.WITNESSES)
	_tick()
	if not _check(_mission.objective.outcome == Outcome.FAILED and _results == [true, true, false], "A confirmed loss did not fail exactly once."):
		return false
	_tick(100)
	if not _check(_results == [true, true, false], "An already terminal result repeated."):
		return false
	_key(KEY_BACKSPACE, true)
	_key(KEY_BACKSPACE, false)
	return _reset_ok()


func _prepare_parties(negative_checks: bool) -> bool:
	if negative_checks:
		if not _walk(_mission._route("WitnessStaging")):
			return false
		_press_interact(false)
		if not _check(_mission.objective.group_status(Group.WITNESSES) == Status.STAGED, "Early witness signal skipped the first guide."):
			return false
	if not _walk(_mission._route("RefugeeStaging")):
		return false
	_press_interact(false)
	if not _check(_mission.objective.group_status(Group.REFUGEES) == Status.WAITING
		and _mission._parties[Group.REFUGEES].path.is_empty(), "The first guide moved the refugees without a route confirmation."):
		return false
	if not _walk(_mission._route("WitnessStaging")):
		return false
	_press_interact(true)
	return _check(_mission.objective.group_status(Group.WITNESSES) == Status.WAITING, "The separate witness guide did not respond.")


func _dispatch(marker: String, group: Group, route: Route) -> bool:
	if not _walk(_mission._route(marker)):
		return false
	_press_interact(group == Group.REFUGEES)
	var patrol := _mission._patrols[route - 1]
	return _check(_mission.objective.group_route(group) == route
		and _mission.objective.group_status(group) == Status.MOVING
		and patrol.active and patrol.position.distance_to(patrol.path[0]) < 2.0,
		"The route order did not launch the correct party and its physically approaching pressure.")


func _both_blocked() -> bool:
	if not _until(func() -> bool:
		for group: Group in [Group.REFUGEES, Group.WITNESSES]:
			var party := _mission._parties[group]
			if _mission.objective.group_status(group) != Status.BLOCKED or party.position != party.last_safe():
				return false
		return true, "Two actual patrols did not stop their groups at their last safe markers."
	):
		print("Patrol positions: ", _mission._patrols[0].position, " ", _mission._patrols[1].position)
		return false
	return _check(_mission._parties[0].last_safe() == _mission._route("ShelfHold")
		and _mission._parties[1].last_safe() == _mission._route("SideHighBend")
		and _mission._pressure_label.text.contains("Shelf contested")
		and _mission._pressure_label.text.contains("Side path contested"),
		"Separate real wait points and visible pressure feedback were not preserved.")


func _screen(index: int, path: Array) -> bool:
	for marker: String in path:
		if not _move_guard(index, marker):
			return false
	var patrol := _mission._patrols[index]
	if not _check(patrol.screened and patrol.contests(), "A new Hold should start the screen without teleporting the rival out."):
		return false
	if not _until(func() -> bool: return not patrol.contests(), "A holding platoon did not physically drive pressure back."):
		return false
	return _check(patrol.position.distance_to(patrol.choke()) > 6.0, "Pressure cleared without the rival moving back.")


func _move_guard(index: int, marker: String) -> bool:
	var spot := _mission._route(marker)
	_key(KEY_SHIFT, true)
	_mission.selected_index = index
	_mission.cursor = spot
	_button(JOY_BUTTON_X, true)
	_button(JOY_BUTTON_X, false)
	_key(KEY_SHIFT, false)
	var guard := _mission.battle.formations[index]
	return _until(
		func() -> bool: return guard.order == Battle.Order.HOLD and guard.position.is_equal_approx(spot),
		"The real command-view Move/Hold could not reach " + marker
	)


func _check_complete(expected: Array) -> bool:
	_tick(25)
	return _check(_results == expected and _mission.objective.outcome == Outcome.SUCCEEDED
		and _in_terrace(Group.REFUGEES) and _in_terrace(Group.WITNESSES)
		and _mission._goal.text.contains("Both groups are safe")
		and _mission._field.name == &"CairnspineVaultRoad", "A clear did not correspond to two actual safe destinations in Cairnspine.")


func _in_terrace(group: Group) -> bool:
	var party := _mission._parties[group]
	return _mission.objective.group_status(group) == Status.SAFE and _mission._terrace.has_point(party.actor.global_position + Vector3.UP * 0.8) \
		and party.position == _mission._spot("Objectives", Mission.SAFETY[group])


func _reset_ok() -> bool:
	return _check(_mission.objective.outcome == Outcome.ACTIVE
		and _mission.battle.hero_position == _mission._spot("Spawns", "NerisGuide")
		and _mission._parties[0].position == _mission._route("RefugeeStaging")
		and _mission._parties[1].position == _mission._route("WitnessStaging")
		and _mission._parties[0].path.is_empty() and _mission._parties[1].path.is_empty()
		and not _mission._patrols[0].active and not _mission._patrols[1].active, "Retry retained stale movement, routes or outcomes.")


func _walk(point: Vector2) -> bool:
	for _step in range(1300):
		var delta := point - _mission.battle.hero_position
		if delta.length() < 0.25:
			break
		var axis := delta.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, axis.x)
		_axis(JOY_AXIS_LEFT_Y, axis.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _check(_mission.battle.hero_position.distance_to(point) < 0.27, "Neris could not walk to %s from %s." % [point, _mission.battle.hero_position])


func _until(condition: Callable, error: String) -> bool:
	for _step in range(1350):
		if condition.call():
			return true
		_tick()
	return _check(false, error)


func _press_interact(pad: bool) -> void:
	if pad:
		_button(JOY_BUTTON_A, true)
		_button(JOY_BUTTON_A, false)
	else:
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)
	_tick()


func _tick(count := 1) -> void:
	for _step in count:
		_mission._physics_process(0.06)


func _key(code: Key, pressed: bool) -> void:
	var input := InputEventKey.new()
	input.pressed = pressed
	input.physical_keycode = code
	root.push_input(input, true)


func _button(code: JoyButton, pressed: bool) -> void:
	var input := InputEventJoypadButton.new()
	input.pressed = pressed
	input.button_index = code
	root.push_input(input, true)


func _axis(code: JoyAxis, value: float) -> void:
	var input := InputEventJoypadMotion.new()
	input.axis = code
	input.axis_value = value
	root.push_input(input, true)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failed = true
		push_error(message)
	return ok
