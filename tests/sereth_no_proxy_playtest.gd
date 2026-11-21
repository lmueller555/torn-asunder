extends SceneTree

const Scene := preload("res://game/battlefield/sereth_no_proxy_playtest.tscn")
const Mission := preload("res://game/battlefield/sereth_no_proxy_playtest.gd")
const Finale := preload("res://game/battlefield/sereth_no_proxy.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Phase := Finale.Phase
const Route := Finale.Route
const DT := 1.0 / 60.0

var _mission: Mission
var _signals: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_finished.connect(func(won: bool) -> void: _signals.append(won))
	var passed := _check_shelf_and_clear() and _check_side_and_terrace_loss() and _check_custody_loss() and _check_hero_loss()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Sereth finale playtest: reused graybox, physical refusal/split, both speaker lanes, House Hold, local challenge, terrace arrival, real losses and retry passed.")
	quit(0 if passed else 1)


func _check_shelf_and_clear() -> bool:
	var source := _mission._formation_members[Mission.COURT][0].get_child(0) as MeshInstance3D
	var debug_escort := _mission._speaker.marker.get_child(0).get_child(0) as MeshInstance3D
	if source.mesh != debug_escort.mesh or source.material_override != debug_escort.material_override \
			or not _mission._field.name == &"CairnspineVaultRoad":
		return _fail("The finale did not use the shared terrain and existing harness markers.")
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.phase != Phase.AT_ASSEMBLY:
		return _fail("A remote interaction counted as public refusal.")
	if not _command(["ValleyAssembly", "SafeStaging", "ShelfDecision", "ShelfFoot"]) or not _refuse():
		return false
	if not _wait(func() -> bool: return _mission._escort_stalled, 3250):
		return false
	if _mission.objective.speaker_route != Route.SHELF or not _mission._route_status.text.contains("shelf"):
		return _fail("An actual shelf stall did not mark the live route.")
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.bid_halted:
		return _fail("A remote challenge halted the bid.")
	if not _walk(["SafeStaging", "ShelfDecision"]) or not _walk_to(_mission._speaker.position):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_A)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	if _mission.objective.bid_halted:
		return _fail("Command-view Hold counted as the hero's challenge.")
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Phase.CLEARING_TERRACE or not _mission.objective.bid_halted or not _signals.is_empty():
		return _fail("A local challenge did not halt the bid, or it skipped the independent terrace task.")

	if not _command(["ShelfClimb", "ShelfHold", "ShelfRejoin", "Forecourt", "TerraceApproach"]) \
			or not _walk(["ShelfFoot", "ShelfClimb", "ShelfHold", "ShelfRejoin", "Forecourt"]):
		return false
	if not _wait(func() -> bool: return _mission._rival_cleared, 3800):
		return false
	if _mission._rival.marker.visible or _mission.objective.phase != Phase.CLEARING_TERRACE:
		return _fail("The guard did not physically get the rival to withdraw, or Sereth was counted as arrived remotely.")
	if not _walk(["TerraceApproach", "TerraceEntry"]):
		return false
	_tick(4)
	if _mission.objective.phase != Phase.SUCCEEDED or _signals != [true]:
		return _fail("The actual safe arrival did not finish the halted bid exactly once.")
	_joy(JOY_BUTTON_START)
	return _reset_ok()


func _check_side_and_terrace_loss() -> bool:
	if not _command(["ValleyAssembly", "SafeStaging", "ShelfDecision"]) or not _refuse():
		return false
	if not _wait(func() -> bool: return _mission.objective.speaker_route != Route.NONE, 1700):
		return false
	if _mission.objective.speaker_route != Route.SIDE or not _mission._route_status.text.contains("side path"):
		return _fail("Holding the shelf fork did not cause the physical escort to route onto the side path.")
	var guard_path := ["SafeStaging"] + Mission.SIDE.slice(0, 5)
	if not _command(guard_path) or not _wait(func() -> bool: return _mission._escort_stalled, 1500):
		return false
	if not _walk(["SafeStaging"] + Mission.SIDE.slice(0, 4)) or not _walk_to(_mission._speaker.position):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _mission.objective.bid_halted or not _walk(Mission.SIDE.slice(4) + ["TerraceApproach", "SideRejoin"]):
		return _fail("A local side-path challenge did not halt the escort and allow approach to the terrace.")
	if not _wait(func() -> bool: return _mission.objective.occupation_warned, 3800):
		return false
	if _mission.objective.phase != Phase.CLEARING_TERRACE \
			or not _mission._inside(_mission._terrace_zone, _mission._rival.position) \
			or not _mission._pressure.text.contains("Hostile hold"):
		return _fail("The first actual terrace occupation did not warn instead of immediately losing.")
	if not _wait(func() -> bool: return _mission.objective.phase == Phase.FAILED, 500):
		return false
	if _mission.objective.failure != Finale.Failure.WITNESS_POSITION_LOST or _signals != [true, false]:
		return _fail("Leaving the real rival hold unbroken did not lose the witness position.")
	_key(KEY_BACKSPACE)
	return _reset_ok()


func _check_custody_loss() -> bool:
	if not _refuse() or not _wait(func() -> bool: return _mission.objective.phase == Phase.FAILED, 10500):
		return false
	if _mission.objective.failure != Finale.Failure.SPEAKER_CROSSED_CUSTODY_LINE \
			or not _mission._inside(_mission._custody_zone, _mission._speaker.position) or _signals != [true, false, false]:
		return _fail("An unobstructed enemy did not cause defeat by actual custody crossing.")
	_joy(JOY_BUTTON_START)
	return _reset_ok()


func _check_hero_loss() -> bool:
	if not _refuse() or not _walk(["SafeStaging"] + Mission.SHELF + Mission.TERRACE):
		return false
	if not _wait(func() -> bool: return _mission._hero_danger > 0.0, 3400):
		return false
	if not _mission._pressure.text.contains("exposed") or _mission.objective.phase != Phase.INTERCEPTING:
		return _fail("The rival's actual local approach did not warn Sereth.")
	# Deliberately keep Sereth beside the advancing company, using physical
	# movement so the exposure lasts longer than a single passing encounter.
	for _step in range(450):
		if _mission.objective.phase == Phase.FAILED:
			break
		var toward := _mission._rival.position - _mission.battle.hero_position
		var stick := toward.normalized().rotated(_mission._hero_yaw) * 0.72 if toward.length() > 0.4 else Vector2.ZERO
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return (_mission.objective.failure == Finale.Failure.SERETH_FELL and _signals == [true, false, false, false]) \
		or _fail("Sustained unscreened hero contact did not register its separate defeat: %s." % _mission.objective.failure)


func _refuse() -> bool:
	if not _walk(["ValleyAssembly"]):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Phase.RELEASING_COURT_TROOPS or not _mission._goal.text.contains("leaving") \
			or _mission._speaker.marker.visible or not _mission._formation_models[Mission.COURT].visible:
		return _fail("Refusal did not clearly telegraph the roster loss before moving the escort.")
	var at_refusal := _mission.battle.hero_position
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	_tick(6)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if _mission.battle.hero_position != at_refusal:
		return _fail("The witnessed troop-split notice returned movement too soon.")
	if not _wait(func() -> bool: return _mission.objective.phase == Phase.INTERCEPTING, 170):
		return false
	var court := _mission.battle.formations[Mission.COURT]
	return (court.order == Battle.Order.EXTRACTED and not _mission._formation_models[Mission.COURT].visible \
		and _mission._speaker.marker.visible and _mission._speaker.position == court.position \
		and _mission.battle.formations[Mission.HOUSEHOLD].can_receive_orders()) \
		or _fail("The same court troops did not visibly change sides while the household remained.")


func _reset_ok() -> bool:
	return (_mission.objective.phase == Phase.AT_ASSEMBLY and _mission._escort_route == Route.NONE \
		and not _mission._speaker.marker.visible and not _mission._rival_active and not _mission._rival_cleared \
		and _mission._formation_models[Mission.COURT].visible \
		and _mission.battle.hero_position == _mission._route("RefugeeStaging")) or _fail("Retry did not restore both groups and the assembly.")


func _command(ids: Array) -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var guard := _mission.battle.formations[Mission.HOUSEHOLD]
	for id: String in ids:
		var target := _mission._route(id)
		_mission.cursor = target
		_joy(JOY_BUTTON_X)
		var budget := ceili(guard.position.distance_to(target) / Battle.FORMATION_SPEED / DT) + 90
		if not _wait(func() -> bool: return guard.order == Battle.Order.HOLD and guard.position == target, budget):
			return _fail("Household Guard couldn't march to " + id)
		_joy(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return true


func _walk(ids: Array) -> bool:
	for id: String in ids:
		if not _walk_to(_mission._route(id)):
			return _fail("Could not physically reach " + id)
	return true


func _walk_to(target: Vector2) -> bool:
	var budget := ceili(_mission.battle.hero_position.distance_to(target) / Battle.HERO_SPEED / DT) + 120
	for _step in range(budget):
		var remaining := target - _mission.battle.hero_position
		if remaining.length() < 0.13 or _mission.objective.phase == Phase.SUCCEEDED:
			break
		var stick := remaining.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _mission.battle.hero_position.distance_to(target) < 0.14 or _mission.objective.phase == Phase.SUCCEEDED


func _wait(condition: Callable, budget: int) -> bool:
	for _step in range(budget):
		if condition.call():
			return true
		_tick()
	return _fail("Event did not arrive: phase %s, speaker %s, rival %s, guard %s." % [
		_mission.objective.phase, _mission._speaker.position, _mission._rival.position,
		_mission.battle.formations[Mission.HOUSEHOLD].position,
	])


func _tick(count := 1) -> void:
	for _step in count:
		_mission._physics_process(DT)


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


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
