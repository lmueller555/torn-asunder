extends SceneTree

const Scene := preload("res://game/battlefield/sereth_cut_playtest.tscn")
const Mission := preload("res://game/battlefield/sereth_cut_playtest.gd")
const Cut := preload("res://game/battlefield/sereth_voices_at_the_cut.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Account := Cut.AccountStatus
const Bundle := Cut.BundleStatus
const DT := 1.0 / 60.0
const TO_WITNESS := ["Routes/ApproachRoadWest", "Routes/WestLaneRoadJunction", "Routes/WestLaneEntrance",
	"Routes/GateInnerTurn", "Routes/GateOuterTurn", "Objectives/WitnessAccount"]
const WITNESS_TO_CUT := ["Routes/CemeteryHold", "Routes/CemeteryStairTop", "Routes/CemeteryStairFoot",
	"Routes/GraveCutApproach", "Objectives/ExposedRecords"]
const HOLD_TO_ROOM := ["Routes/GateOuterTurn", "Routes/GateInnerTurn", "Routes/LaneWestTurn",
	"Routes/LaneSouthTurn", "Routes/LaneSecurityBend", "Routes/LaneEastTurn", "Routes/LaneClerkTurn",
	"Routes/ClerkYard", "Routes/RecordRoomDoor", "Routes/RecordRoomInside", "Objectives/AccountEntry"]

var _mission: Mission
var _results: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_finished.connect(func(won: bool) -> void: _results.append(won))
	var passed := _check_extraction() and await _check_recovery_clear() and _check_room_contest_and_hero_loss()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Sereth Cut playtest: physical extraction, guard-screened drop, empty retreat and recovery, both real objectives, contested clerk, hero loss and retry passed.")
	quit(0 if passed else 1)


func _check_extraction() -> bool:
	if _mission._field.name != &"StillKingdomCut" or _mission.battle.bounds.size != Vector2(390, 200) \
			or not _mission.hero_world_position().is_equal_approx(_point("Spawns/Sereth")):
		return _fail("Sereth did not spawn on the full authored Still Kingdom Cut.")
	_key(KEY_SPACE)
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.account_status != Account.UNHEARD or _mission.objective.bundle_status != Bundle.EXPOSED \
			or _mission._raider.visible:
		return _fail("Remote input started an objective or raid.")
	if not _walk_markers(TO_WITNESS):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_A)
	_key(KEY_SPACE)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	if _mission.objective.account_status != Account.UNHEARD:
		return _fail("Command view incorrectly accepted a field conversation.")
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.account_status != Account.HEARD or not _mission._raider.visible \
			or not _mission._pressure.text.contains("approaching") or not _mission._account_readout.text.contains("recognized"):
		return _fail("Physical witness interaction did not report Iren's account and warned advance.")
	if not _wait(func() -> bool: return _mission.objective.bundle_status == Bundle.WITH_ENEMY, 1300):
		return false
	if _mission._raider.global_position != _point("Objectives/ExposedRecords") or not _results.is_empty() \
			or not _mission._bundle.visible or not _mission._exit_beacon.visible:
		return _fail("The party did not visibly reach and carry the exposed records before any loss.")
	if not _wait(func() -> bool: return _mission.objective.outcome == Cut.Outcome.FAILED, 7200):
		return false
	if _mission.objective.failure != Cut.Failure.BUNDLE_EXTRACTED \
			or _mission._raider.global_position != _point("Objectives/EnemyRetreatExit") \
			or _mission._bundle.visible or _results != [false]:
		return _fail("Only the tracked carrier physically arriving at the east retreat should fail this run.")
	_joy(JOY_BUTTON_START)
	return (_mission.objective.account_status == Account.UNHEARD and _mission.objective.bundle_status == Bundle.EXPOSED \
		and _mission._bundle.visible and _mission._bundle.global_position == _point("Objectives/ExposedRecords") \
		and not _mission._raider.visible and _mission.hero_world_position().is_equal_approx(_point("Spawns/Sereth"))) \
		or _fail("Options did not reset objectives, actors, bundle, and hero.")


func _check_recovery_clear() -> bool:
	# Stage the actual Stair Guard before interviewing Iren; the captive screen isn't a timer or a script flag.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_DPAD_RIGHT)
	var guard: Battle.Formation = _mission.battle.formations[1]
	for id in ["Routes/GateInnerTurn", "Routes/GateOuterTurn", "Routes/CemeteryHold"]:
		_mission.cursor = _local_xz(_point(id))
		_joy(JOY_BUTTON_X)
		if guard.order != Battle.Order.MOVE or not _wait(func() -> bool: return guard.order == Battle.Order.HOLD, 900) \
				or guard.position != _mission.cursor:
			return _fail("Stair Guard did not physically march to " + id)
	_key(KEY_H)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _walk_markers(TO_WITNESS):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _wait(func() -> bool: return _mission.objective.bundle_status == Bundle.WITH_ENEMY and _mission._screened(), 2000):
		return false
	var stopped_at := _mission._raider.global_position
	if not _walk_markers(["Routes/CemeteryHold", "Routes/CemeteryStairTop"]) or not _walk_to(stopped_at):
		return false
	if not _mission._pressure.text.contains("stalled") or _mission._raider.global_position != stopped_at:
		return _fail("The physical Hold did not stall the carrier in place.")
	await _checkpoint("01-carrier-screened")
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.bundle_status != Bundle.DROPPED or not _mission._raider.visible \
			or _mission._raid != Mission.Raid.RETREATING_EMPTY or _mission._room_contested() \
			or _mission._bundle.global_position != stopped_at or _mission._raider.global_position != stopped_at \
			or _mission._exit_beacon.visible or _mission._raider_label.text != "Retreating" or _results != [false]:
		return _fail("Disarm must leave the real bundle at contact and the living party visible and noncontesting.")
	await _checkpoint("02-disarmed-bundle")
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.bundle_status != Bundle.WITH_SERETH \
			or _mission._bundle.global_position.distance_to(_mission.hero_world_position()) >= 1.2:
		return _fail("The very next local action must pick up the dropped bundle.")
	_tick(29)
	var actual_step := _mission._raider.global_position.distance_to(stopped_at)
	if actual_step <= 1.0 or actual_step > Mission.CARRIER_SPEED * DT * 30 + 0.05 \
			or _mission._bundle.global_position.distance_to(_mission.hero_world_position()) >= 1.2 \
			or not _mission._pressure.text.contains("withdrawing"):
		return _fail("The empty party did not travel continuously while Sereth kept the recovered bundle.")
	await _checkpoint("03-living-retreat")
	if not _walk_markers(["Routes/CemeteryStairTop", "Routes/CemeteryHold"] + HOLD_TO_ROOM):
		return false
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.account_status != Account.RELAYED:
		return _fail("Physical relay did not precede the clerk's filing.")
	_tick()
	if _mission.objective.account_status != Account.FILED or _mission.objective.outcome != Cut.Outcome.ACTIVE:
		return _fail("Filing alone counted as victory or failed to persist through the recovery.")
	if not _walk_markers(["Spawns/VillageClerk", "Objectives/BundleSecure"]):
		return false
	_joy(JOY_BUTTON_A)
	_tick(5)
	if _mission.objective.outcome != Cut.Outcome.SUCCEEDED or _mission._bundle.global_position != _point("Objectives/BundleSecure") \
			or _mission._raid != Mission.Raid.RETREATING_EMPTY or not _mission._raider.visible \
			or _results != [false, true]:
		return _fail("Filing and securing the real bundle must clear and emit once without waiting for the retreat.")
	if not _wait(func() -> bool: return not _mission._raider.visible, 7500):
		return false
	if _mission._raider.global_position != _point("Objectives/EnemyRetreatExit") or _results != [false, true] \
			or _mission.objective.bundle_status != Bundle.SECURED or _mission.objective.outcome != Cut.Outcome.SUCCEEDED:
		return _fail("The empty party should disappear only at the real exit, without reporting a new result or extraction.")
	_key(KEY_BACKSPACE)
	return _mission.objective.outcome == Cut.Outcome.ACTIVE or _fail("Backspace did not restart after success.")


func _check_room_contest_and_hero_loss() -> bool:
	if not _walk_markers(TO_WITNESS):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _walk_markers(WITNESS_TO_CUT):
		return false
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.bundle_status != Bundle.WITH_SERETH:
		return _fail("A timely physical pickup could not beat the signaled raider at the cut.")
	if not _walk_markers(["Routes/GraveCutApproach", "Routes/CemeteryStairFoot", "Routes/CemeteryStairTop",
			"Routes/CemeteryHold"] + HOLD_TO_ROOM):
		return false
	if not _wait(func() -> bool: return _mission._raid == Mission.Raid.AT_ROOM, 4700):
		return false
	if _mission._raider.global_position != _point("Routes/RecordRoomInside") or not _mission._pressure.text.contains("contested"):
		return _fail("A visible party did not contest the clerk when physically inside the record room.")
	_joy(JOY_BUTTON_A)
	_tick(150)
	if _mission.objective.account_status != Account.RELAYED or _mission.objective.outcome != Cut.Outcome.ACTIVE:
		return _fail("An actual contested room did not pause the relayed account.")
	if not _walk_markers(["Routes/RecordRoomInside"]):
		return false
	if not _mission._pressure.text.contains("exposed"):
		return _fail("Unsafe close contact did not visibly warn Sereth.")
	if not _wait(func() -> bool: return _mission.objective.outcome == Cut.Outcome.FAILED, 280):
		return false
	return (_mission.objective.failure == Cut.Failure.SERETH_FELL and _results == [false, true, false]) \
		or _fail("Sustained visible unscreened contact did not produce Sereth's separate defeat.")


func _checkpoint(_label: String) -> void:
	# Local render diagnostics can capture the same live-input checkpoints.
	pass


func _walk_markers(ids: Array) -> bool:
	for id: String in ids:
		if not _walk_to(_point(id)):
			return _fail("Locomotion did not reach " + id)
	return true


func _walk_to(world: Vector3) -> bool:
	var target := _local_xz(world)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 100
	for _step in range(budget):
		var move := target - _mission.battle.hero_position
		if move.length() < 0.1:
			break
		move = move.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, move.x)
		_axis(JOY_AXIS_LEFT_Y, move.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _mission.hero_world_position().distance_to(world) < 0.16 \
		or _fail("Hero stuck at %s before %s." % [_mission.hero_world_position(), world])


func _wait(condition: Callable, frame_limit: int) -> bool:
	for _step in range(frame_limit):
		if condition.call():
			return true
		_tick()
	return _fail("Expected event did not occur. Raid: %s at %s; account: %s; bundle: %s." % [
		_mission._raid, _mission._raider.global_position, _mission.objective.account_status, _mission.objective.bundle_status,
	])


func _tick(count := 1) -> void:
	for _step in range(count):
		_mission._physics_process(DT)


func _point(id: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + id)).global_position


func _local_xz(point: Vector3) -> Vector2:
	var local := _mission.to_local(point)
	return Vector2(local.x, local.z)


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
