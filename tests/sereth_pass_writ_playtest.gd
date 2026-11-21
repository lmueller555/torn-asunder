extends SceneTree

const Scene := preload("res://game/battlefield/sereth_pass_writ_playtest.tscn")
const Mission := preload("res://game/battlefield/sereth_pass_writ_playtest.gd")
const Writ := preload("res://game/battlefield/sereth_pass_writ.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Phase := Writ.Phase
const Reserve := Writ.Reserve
const DT := 1.0 / 60.0
const TRACK_IN := ["Routes/WestRoadFork", "Routes/WestTrackJunction", "Routes/WestTrackTurn",
	"Routes/WestRampTop", "Routes/WestRampBottom", "Routes/SheepTrackBend", "Routes/SheepPinch", "Routes/CoveredTrackHold"]
const TRACK_OUT := ["Routes/EastRampBottom", "Routes/EastRampTop", "Routes/EastTrackLanding",
	"Routes/TrackEmergence", "Routes/TrackWallCorner", "Routes/PostTrackTurn", "Objectives/WritHandover"]
const ROAD := ["Routes/RoadScreen", "Routes/OpenRoadBrace", "Routes/RoadCenter", "Routes/ScoutRoadBypassWest",
	"Routes/ScoutRoadBypassEast", "Routes/RoadEastStraight", "Routes/LookoutBendRoad", "Routes/PostEastTurn"]
const RALLY := ["Routes/WestRoadFork", "Routes/WestMarchEdge", "Routes/RallyOpenTurn",
	"Routes/RallyScreenCorner", "Objectives/WithdrawalRally"]
const POST := ["Routes/PostRoadApproach", "Routes/PostDoorway", "Objectives/WritHandover"]

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
	var passed := _check_spawn_and_occupation() and _check_covered_reply_and_return() and _check_hold_clears_post()
	if passed:
		print("Sereth writ playtest: real patrol alert/occupation, covered rally clear, correlated Keeper arrival, physical Hold relief from the open road, and input retry passed.")
	_mission.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _check_spawn_and_occupation() -> bool:
	if _mission._field.name != &"CairnspineBoundaryPost" or _mission.battle.bounds.size != Vector2(290, 178) \
		or not _mission.hero_world_position().is_equal_approx(_point("Spawns/Sereth")):
		return _fail("The scene did not bind the actual boundary field and spawns.")
	var patrol_spawn := _mission._patrol.global_position
	_key(KEY_SPACE)
	_tick(80)
	if _mission.objective.phase != Phase.CARRYING_WRIT or _mission._patrol.global_position.distance_to(patrol_spawn) < 4.0 \
		or _mission._reserve_flag.visible or _mission._reserve.visible:
		return _fail("Remote offer did something, the patrol never moved, or the unalerted reserve already revealed.")
	if not _walk_markers(RALLY):
		return false
	if _mission.objective.phase != Phase.CARRYING_WRIT or _mission._rally_flag.visible:
		return _fail("An unearned rally cleared or revealed withdrawal.")
	if not _walk_markers(["Routes/RallyScreenCorner", "Routes/RallyOpenTurn", "Routes/WestMarchEdge", "Routes/WestRoadFork"]):
		return false
	if not _walk_markers(ROAD.slice(0, 4)) or not _walk_markers(["Routes/ScoutRampFoot", "Routes/ScoutRampTop", "Routes/HighBankScout"]):
		return false
	if not _mission._lookout_flag.visible:
		return _fail("The hero reached the high bank without actually spotting the lookout.")
	if not _walk_markers(["Routes/ScoutRampTop", "Routes/ScoutRampFoot"] + ROAD.slice(4, 7)):
		return false
	if not _wait(func() -> bool: return _mission.objective.post_occupation_warned, 2200):
		return false
	if not _mission._yard.has_point(_mission._patrol.global_position + Vector3.UP * 0.8) \
		or not _mission._pressure.text.contains("POST OCCUPIED") or not _results.is_empty():
		return _fail("Warning did not correspond to an actual patrol in the yard with time to recover.")
	if not _wait(func() -> bool: return _mission.objective.phase == Phase.FAILED, 400):
		return false
	if _mission.objective.failure != Writ.Failure.KEEPER_DRIVEN_AWAY or _mission._keeper.visible or _results != [false]:
		return _fail("Uninterrupted occupation did not conclusively drive the Keeper away.")
	_joy(JOY_BUTTON_START)
	return (_mission.objective.phase == Phase.CARRYING_WRIT and _mission._keeper.visible \
		and _mission.objective.reserve == Reserve.UNALERTED and not _mission._reserve_flag.visible \
		and _mission._reserve.global_position == _point("Spawns/MarchMountedReserve") \
		and _mission.hero_world_position().is_equal_approx(_point("Spawns/Sereth"))) \
		or _fail("Options did not reset the actual actors, reserve, and mission state.")


func _check_covered_reply_and_return() -> bool:
	if not _walk_markers(TRACK_IN):
		return false
	if _mission.objective.reserve != Reserve.UNALERTED or _mission._patrol_intent or _mission.hero_world_position().y > -3.9:
		return _fail("A concealed hero mobilized the lookout from the low track.")
	if not _walk_markers(TRACK_OUT):
		return false
	if not _mission._reserve_flag.visible or _mission.objective.reserve == Reserve.UNALERTED:
		return _fail("Emergence did not warn and reveal the reserve.")
	_key(KEY_SHIFT)
	_key(KEY_M)
	_joy(JOY_BUTTON_A)
	_key(KEY_SPACE)
	_tick()
	if not _mission.command_view or not _mission._sector.overview or _mission.objective.phase != Phase.CARRYING_WRIT:
		return _fail("The actual command overview failed or improperly offered the writ.")
	_key(KEY_SHIFT, false)
	var keeper_home := _mission._keeper.global_position
	_joy(JOY_BUTTON_A)
	_tick()
	var token := _mission.objective.pending_offer_id
	if token <= 0 or _mission.objective.phase != Phase.AWAITING_KEEPER or _mission.objective.audience_granted \
		or _mission._keeper.global_position != keeper_home:
		return _fail("Field input was not a separate offer before the Keeper actor accepted.")
	_tick(20)
	if _mission._keeper.global_position.distance_to(keeper_home) < 0.7 or _mission.objective.phase != Phase.AWAITING_KEEPER:
		return _fail("Keeper did not physically approach or answered before arriving.")
	# Break a live offer by moving out of contact before the Keeper arrives.
	var handover := _point("Objectives/WritHandover")
	if not _walk_to(handover + Vector3.LEFT * 2.20) or _mission.objective.phase != Phase.CARRYING_WRIT 		or _mission.objective.audience_granted or _mission.objective.pending_offer_id != 0:
		return _fail("Stepping away did not invalidate the live offer.")
	if not _walk_to(handover):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.pending_offer_id <= token:
		return _fail("A fresh field offer reused the interrupted response token.")
	if not _wait(func() -> bool: return _mission.objective.phase == Phase.WITHDRAWING, 80):
		return false
	if not _mission._keeper.global_position.is_equal_approx(_mission._keeper_reply_spot) \
		or not _mission.objective.audience_granted or not _mission._rally_flag.visible \
		or not _mission._keeper_text.text.contains("No entry") or _results != [false]:
		return _fail("Consent was not tied to physical arrival, or skipped the distinct withdrawal.")
	var return_track := TRACK_OUT.duplicate()
	return_track.reverse()
	var return_west := TRACK_IN.duplicate()
	return_west.reverse()
	if not _walk_markers(return_track + return_west + RALLY):
		return false
	if _mission.objective.phase != Phase.SUCCEEDED or _results != [false, true]:
		return _fail("Covered withdrawal failed to clear at the real west rally.")
	_key(KEY_BACKSPACE)
	return (_mission.objective.phase == Phase.CARRYING_WRIT and not _mission._rally_flag.visible \
		and not _mission.objective.audience_granted and _mission.objective.pending_offer_id == 0) \
		or _fail("Backspace did not retry after success.")


func _check_hold_clears_post() -> bool:
	_key(KEY_SHIFT)
	_key(KEY_X)
	_key(KEY_M)
	var guard: Battle.Formation = _mission.battle.formations[1]
	if not _orders_to(guard, ROAD):
		return false
	_key(KEY_SHIFT, false)
	if not _walk_markers(ROAD.slice(0, 7)):
		return false
	if not _wait(func() -> bool: return _mission.objective.post_occupation_warned, 2200):
		return false
	_key(KEY_SHIFT)
	if not _orders_to(guard, ["Routes/PostRoadApproach"]):
		return false
	_key(KEY_H)
	if not _wait(func() -> bool: return not _mission.objective.post_occupation_warned, 220):
		return false
	if _mission.objective.phase == Phase.FAILED or guard.order != Battle.Order.HOLD:
		return _fail("An actual Hold could not relieve the occupation before defeat.")
	_key(KEY_SHIFT, false)
	if not _walk_markers(["Routes/PostEastTurn"] + POST):
		return false
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.phase != Phase.AWAITING_KEEPER or not _wait(func() -> bool: return _mission.objective.phase == Phase.WITHDRAWING, 100):
		return _fail("The Keeper never replied at the now-screened road approach.")
	if _mission.objective.reserve != Reserve.COMMITTED or not _mission._reserve_flag.visible:
		return _fail("No physical road commitment was observed while the courier used the guarded route.")
	var west := ROAD.duplicate()
	west.reverse()
	if not _walk_markers(["Routes/PostDoorway", "Routes/PostRoadApproach"] + west + RALLY):
		return false
	_tick(5)
	return _results == [false, true, true] or _fail("The guarded road withdrawal did not emit exactly one additional clear.")


func _orders_to(guard: Battle.Formation, markers: Array) -> bool:
	for id: String in markers:
		if not _mission._command_camera.is_current():
			return _fail("Command input cannot project an order from hero view.")
		var point := _point(id)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = _mission._command_camera.unproject_position(point)
		root.push_input(event, true)
		if guard.order != Battle.Order.MOVE or guard.destination.distance_to(_local_xz(point)) > 0.18:
			return _fail("Actual mouse command did not target %s; cursor %s, order %s." % [id, _mission.cursor, guard.order])
		var steps := ceili(guard.position.distance_to(guard.destination) / Battle.FORMATION_SPEED / DT) + 8
		if not _wait(func() -> bool: return guard.order == Battle.Order.HOLD, steps):
			return false
	return true


func _walk_markers(ids: Array) -> bool:
	for id: String in ids:
		if not _walk_to(_point(id)):
			return _fail("Hero movement did not reach " + id)
	return true


func _walk_to(world: Vector3) -> bool:
	if _mission.objective.phase == Phase.SUCCEEDED:
		return _mission.hero_world_position().distance_to(world) <= Mission.RALLY_RADIUS
	var target := _local_xz(world)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 30
	for _step in range(budget):
		var move := target - _mission.battle.hero_position
		if move.length() < 0.1 or _mission.objective.phase in [Phase.SUCCEEDED, Phase.FAILED]:
			break
		move = move.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, move.x)
		_axis(JOY_AXIS_LEFT_Y, move.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	var tolerance := Mission.RALLY_RADIUS if _mission.objective.phase == Phase.SUCCEEDED else 0.18
	return _mission.hero_world_position().distance_to(world) <= tolerance \
		or _fail("Hero stuck at %s before %s (phase %d)." % [_mission.hero_world_position(), world, _mission.objective.phase])


func _wait(condition: Callable, frame_limit: int) -> bool:
	for _step in range(frame_limit):
		if condition.call():
			return true
		_tick()
	return _fail("Expected event timed out. Phase %d, reserve %d at %s, patrol %s, post %.1f s." % [
		_mission.objective.phase, _mission.objective.reserve, _mission._reserve.global_position,
		_mission._patrol.global_position, _mission.objective.post_occupation_seconds,
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


func _key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
