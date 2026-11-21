extends "res://tests/raska_well_road_playtest.gd"
## Same deployed scene and player inputs as the ordinary cart-route regression.

const Pass := preload("res://game/combat/mounted_brace_encounter.gd")
const Stage := Mission.PassStage


class RefusingPass extends Pass:
	func order_pass(_end: Vector2) -> bool:
		return false


func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := await _exercise(true)
	if passed:
		passed = await _exercise(false)
	if passed:
		passed = _wash_without_pass_and_late_request()
	if passed:
		passed = _refused_pass_falls_back()
	_mission.queue_free()
	await process_frame
	if passed and _failures == 0:
		print("Well Road live brace: safe staged carts, physical reserve pass and retreat, facing-dependent cohesion, refused-pass fallback, old routes and reset passed.")
	quit(0 if passed and _failures == 0 else 1)


func _exercise(frontal: bool) -> bool:
	_key(KEY_BACKSPACE)
	_march_to_gate()
	var brace := _mission.battle.formations[0]
	if not _at_stage(Mission.PassStage.AVAILABLE, "Arrival Hold is not a deliberate challenge."):
		return false
	_face_and_hold(frontal)
	_tick(41)
	if not _at_stage(Stage.ARMED, "Explicit Brace Hold at SaltChargeGate arms the optional pass.") \
			or not _mission._pass.brace_ready or (brace.heading.x > 0.0) != frontal:
		return _fail("The actual detailed order did not produce the expected facing and settled Hold.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_key(KEY_G)
	_tick()
	_wait(func() -> bool: return _mission._rival.status == Rival.Status.MARCHING, 700)
	var staged := _marker("Routes/SaltRoadWest")
	var upper := _mission._carts[UPPER].wagon
	if not upper.global_position.is_equal_approx(staged) or not _mission._cue.text.contains("approaching"):
		return _fail("The actual salt approach did not visibly warn or stage outside the swept lane.")
	await _checkpoint("01-warning" if frontal else "04-rear-warning")
	_wait(func() -> bool: return _mission._pass_stage == Stage.RUNNING, 1600)
	if not _at_stage(Stage.RUNNING, "The actual reserve entered the lane.") \
			or not _mission._rival.global_position.is_equal_approx(_marker("Routes/MountedChargeStart")):
		return _fail("The actual reserve did not stage and start from its authored marker.")
	var charge_start := _mission._rival.global_position
	var expected := Pass.Result.REPELLED if frontal else Pass.Result.LANDED
	for tick in 1400:
		if _mission._pass.result != Pass.Result.NONE:
			break
		_tick()
		if not upper.global_position.is_equal_approx(staged) or not _riders_clear_of_carts():
			return _fail("A wagon entered the physically swept route during the charge.")
		if tick == 400 and frontal:
			await _checkpoint("02-physical-charge")
	if _mission._pass.result != expected or _mission._rival.global_position.distance_to(charge_start) <= 65.0 \
			or _mission._brace_line.cohesion != (84.0 if frontal else 76.0) \
			or _mission._mounted_line.cohesion != (80.0 if frontal else 100.0) \
			or _mission._hero_fell or _mission._carts[UPPER].lost or _mission._carts[LOWER].lost:
		return _fail("Did not get a real directional, cohesion-only impact. Stage %s, result %s, cohesion %.2f / %.2f" % [
			_mission._pass_stage, _mission._pass.result, _mission._brace_line.cohesion, _mission._mounted_line.cohesion,
		])
	await _checkpoint("03-frontal-impact" if frontal else "05-rear-impact")
	var impact := _mission._rival.global_position
	if not frontal:
		_key(KEY_T)
		_tick(32)
		if _mission.objective.route_for(UPPER) != WellRoad.Route.WASH or upper.global_position.x >= staged.x \
				or upper.global_position.distance_to(staged) > 5.0:
			return _fail("A landed charge denied safe physical backtracking from the staging point.")
	var settled := Stage.WITHDRAWN if frontal else Stage.SPENT
	for tick in 4200:
		if _mission._pass_stage == settled:
			break
		_tick()
		if not _riders_clear_of_carts():
			return _fail("The single reserve passed through a wagon while leaving the charge.")
	var rider_goal := "Routes/MountedWarning" if frontal else "Routes/MountedChargeStart"
	if not _at_stage(settled, "The live riders withdrew or restaged physically.") \
			or not _mission._rival.global_position.is_equal_approx(_marker(rider_goal)) \
			or _mission._rival.global_position.distance_to(impact) < 60.0:
		return _fail("The aftermath skipped the real rider movement.")
	await _checkpoint("06-riders-withdrew" if frontal else "07-riders-returned")
	_board_lower()
	_key(KEY_G if frontal else KEY_T)
	_wait(func() -> bool: return _mission.objective.outcome != WellRoad.Outcome.ACTIVE, 6500)
	if not _both_delivered():
		return false
	print("Well Road %s: cohesion %.0f infantry / %.0f riders; both carts intact." % [
		"frontal brace" if frontal else "rear contact and wash reroute", _mission._brace_line.cohesion, _mission._mounted_line.cohesion,
	])
	return true


func _wash_without_pass_and_late_request() -> bool:
	_key(KEY_BACKSPACE)
	if _mission._brace_line.cohesion != 100.0 or _mission._mounted_line.cohesion != 100.0 \
			or not _at_stage(Stage.AVAILABLE, "Retry resets only the attempt."):
		return _fail("Old contact or arm leaked across attempts.")
	_march_to_gate()
	_face_and_hold(true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_key(KEY_T)
	_tick()
	_board_lower()
	_key(KEY_T)
	_wait(func() -> bool: return _mission.objective.outcome != WellRoad.Outcome.ACTIVE, 6500)
	if not _both_delivered() or _mission._rival.status != Rival.Status.WAITING \
			or _mission._pass.result != Pass.Result.NONE or _mission._brace_line.cohesion != 100.0:
		return _fail("Both covered washes cannot bypass even an armed challenge freely.")
	_key(KEY_BACKSPACE)
	_march_to_gate()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_key(KEY_G)
	_wait(func() -> bool: return _mission._carts[UPPER].waiting_on == "Mounted reserve", 3800)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1)
	_button(JOY_BUTTON_RIGHT_STICK)
	_face_and_hold(true)
	_tick()
	return (_at_stage(Stage.AVAILABLE, "Late Hold leaves the old ordinary screen path intact.") \
		and _mission._notice.contains("mobilized") and _mission._pass.result == Pass.Result.NONE \
		and _mission._rival.status == Rival.Status.BLOCKING) \
		or _fail("Late brace attempted to charge through a cart already on the salt road.")


func _refused_pass_falls_back() -> bool:
	_key(KEY_BACKSPACE)
	_march_to_gate()
	_face_and_hold(true)
	_mission._pass = RefusingPass.new(_mission._mounted_line, _mission._brace_line,
		_xz(_mission._rival.global_position), Mission.Roster.ANTI_RIDING,
		_mission._terrain.can_move.bind(true), _mission._terrain.clear_melee_contact)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_key(KEY_G)
	var cart := _mission._carts[UPPER]
	_wait(func() -> bool: return cart.waiting_on == "Mounted pass", 700)
	if not _at_stage(Stage.ARMED, "The rejecting pass waits at the actual staging marker first."):
		return false
	var staged := cart.wagon.global_position
	_wait(func() -> bool: return _mission._pass_stage == Stage.SPENT, 1800)
	if not _at_stage(Stage.SPENT, "A refused charge releases the staged cart to normal movement.") \
			or not _mission._instructions.text.contains("Mounted pass unavailable") \
			or _mission._pass.result != Pass.Result.NONE or _mission._brace_line.cohesion != 100.0:
		return _fail("Rejection failed to produce notice, neutral contact and ordinary route control.")
	_wait(func() -> bool: return cart.waiting_on == "Mounted reserve", 1900)
	if cart.waiting_on != "Mounted reserve" or cart.wagon.global_position.x <= staged.x + 20.0:
		return _fail("Rejection still trapped the cart at staging instead of the original physical blockade.")
	_key(KEY_T)
	_tick(40)
	return (_mission.objective.route_for(UPPER) == WellRoad.Route.WASH \
		and cart.wagon.global_position.x < _mission._rival.global_position.x - 5.0) \
		or _fail("The original wash reroute was not available after rejection.")


func _march_to_gate() -> void:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1)
	_button(JOY_BUTTON_RIGHT_STICK)
	var brace := _mission.battle.formations[0]
	for mark in ["Routes/SaltRoadWest", "Routes/SaltChargeGate"]:
		_order_at(_marker(mark))
		_finish_march(brace, _marker(mark))


func _face_and_hold(frontal: bool) -> void:
	var mouse := InputEventMouseMotion.new()
	var marker := _marker("Routes/MountedChargeStart" if frontal else "Routes/SaltRoadWest")
	mouse.position = root.get_camera_3d().unproject_position(marker)
	root.push_input(mouse, true)
	_button(JOY_BUTTON_A)


func _board_lower() -> void:
	# Fixture staging only; use the actual storehouse interaction and household movement.
	_mission.battle.hero_position = _xz(_marker("Objectives/LowerStorehouse"))
	_key(KEY_C)
	_button(JOY_BUTTON_A)
	_wait(func() -> bool: return _mission.objective.cart_state(LOWER) == WellRoad.CartState.READY, 700)


func _riders_clear_of_carts() -> bool:
	for cart in _mission._carts:
		if cart.wagon.global_position.distance_to(_mission._rival.global_position) <= 5.0:
			return false
	return true


func _both_delivered() -> bool:
	var objective := _mission.objective
	return (objective.outcome == WellRoad.Outcome.SUCCEEDED and objective.cart_state(UPPER) == WellRoad.CartState.SAFE \
		and objective.cart_state(LOWER) == WellRoad.CartState.SAFE) or _fail("Both actual cart arrivals did not clear.")


func _at_stage(stage: int, message: String) -> bool:
	return _mission._pass_stage == stage or _fail(message)


func _checkpoint(_label: String) -> void:
	pass


func _fail(message: String) -> bool:
	push_error(message)
	return false
