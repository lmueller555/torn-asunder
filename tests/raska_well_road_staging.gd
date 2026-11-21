extends "res://tests/raska_well_road_brace.gd"
## All positioning comes from deployed movement, storehouse and command input.

var _minimum_gap := INF


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	# Reverse the dispatch order as well as the physical lead wagon. The lower
	# approach is roughly five seconds longer, so advance it that much in trial 3.
	var passed := await _pair(UPPER, 1, UPPER, false, false, "upper-dispatched-first")
	if passed:
		passed = await _pair(LOWER, 1, UPPER, false, true, "lower-dispatched-first-rear-wash")
	if passed:
		passed = await _pair(LOWER, 325, LOWER, true, false, "lower-leads-and-turns-back")
	_mission.queue_free()
	await process_frame
	quit(0 if passed and _failures == 0 else 1)


func _pair(dispatched_first: int, dispatch_gap: int, front_index: int, turn_back: bool, rear_wash: bool, name: String) -> bool:
	_key(KEY_BACKSPACE)
	_march_to_gate()
	_face_and_hold(true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	for mark in ["Routes/UpperWellStaging", "Routes/WestApproachFork", "Routes/WashEntryTurn",
		"Routes/LowerWellStaging", "Objectives/LowerBoarding", "Spawns/LowerHouseholds", "Objectives/LowerStorehouse"]:
		_drive_to(_marker(mark))
	_select_cart(LOWER)
	_key(KEY_SPACE)
	_wait(func() -> bool: return _mission.objective.cart_state(LOWER) == WellRoad.CartState.READY, 700)
	if _mission.objective.cart_state(LOWER) != WellRoad.CartState.READY:
		return _fail("The real households did not finish boarding.")
	_select_cart(dispatched_first)
	_key(KEY_G)
	_tick(dispatch_gap)
	_select_cart(1 - dispatched_first)
	_key(KEY_G)
	var front := _mission._carts[front_index]
	var rear := _mission._carts[1 - front_index]
	var gate := _marker("Routes/SaltRoadWest")
	var front_frame := -1
	var rear_frame := -1
	_minimum_gap = INF
	for frame in 1700:
		_tick()
		if front_frame == -1 and front.wagon.global_position.is_equal_approx(gate):
			front_frame = frame
		if rear_frame == -1 and rear.waiting_on == "Cart ahead":
			rear_frame = frame
		_observe_gap(front, rear, gate)
		if front_frame >= 0 and rear_frame >= 0:
			break
	var back := rear.wagon.global_position
	if front_frame < 0 or rear_frame < 0 or _mission._salt_stage_front != front_index \
			or not is_equal_approx(back.distance_to(gate), Mission.SALT_REAR_DISTANCE) \
			or _minimum_gap < 8.0 or not _mission._terrain.formation_fits_at(_xz(back)) \
			or _mission._terrain.destination_from_ray(back + Vector3.UP * 20, back - Vector3.UP * 8) == null:
		return _fail("Two real near-simultaneous salt orders did not get separate grounded wait positions.")
	await _checkpoint(name + "-staged")
	if rear_wash:
		_select_cart(1 - front_index)
		_key(KEY_T)
		_tick(30)
		if _mission.objective.route_for(1 - front_index) != WellRoad.Route.WASH \
				or not front.wagon.global_position.is_equal_approx(gate) \
				or rear.wagon.global_position.distance_to(gate) <= back.distance_to(gate):
			return _fail("The rear cart could not take its own physical turn to the wash.")
	# Assert the marker is not handed over until the lead wagon is physically
	# clear, even though its route enum changes immediately when rerouted.
	if turn_back:
		_select_cart(front_index)
		_key(KEY_T)
		_tick()
		if _mission.objective.route_for(front_index) != WellRoad.Route.WASH \
				or _mission._salt_stage_front != front_index \
				or not rear.wagon.global_position.is_equal_approx(back):
			return _fail("Choosing Wash released or teleported a wagon before the real turn.")
	var saw_departure := false
	var saw_rear_leave := false
	for frame in 4700:
		_tick()
		_observe_gap(front, rear, gate)
		var front_distance := front.wagon.global_position.distance_to(gate)
		if front_distance >= Mission.SALT_FRONT_RELEASE:
			saw_departure = true
		if not rear.wagon.global_position.is_equal_approx(back):
			if not rear_wash and (not saw_departure or front_distance < Mission.SALT_FRONT_RELEASE):
				return _fail("Follower moved before the front wagon cleared the gate.")
			saw_rear_leave = true
		if saw_rear_leave:
			break
	if not saw_rear_leave or _minimum_gap < 8.0:
		return _fail("Safe release did not move both wagons without overlap.")
	var left_front := front.wagon.global_position
	var left_rear := rear.wagon.global_position
	for frame in 8000:
		_tick()
		_observe_gap(front, rear, gate)
		if _mission.objective.outcome != WellRoad.Outcome.ACTIVE:
			break
	if not _both_delivered() or _minimum_gap < 8.0 \
			or (turn_back and left_front.x >= gate.x) \
			or left_rear.is_equal_approx(back):
		return _fail("The salt/wash stagger did not preserve independent real arrivals and lane clearance.")
	print("%s: front marker/rear stop frames %d/%d, minimum staging clearance %.2f m; both carts safe." % [
		name, front_frame, rear_frame, _minimum_gap,
	])
	return true


func _observe_gap(front: Mission.Convoy, rear: Mission.Convoy, gate: Vector3) -> void:
	var a := front.wagon.global_position
	var b := rear.wagon.global_position
	if a.distance_to(gate) <= 18.0 and b.distance_to(gate) <= 18.0:
		_minimum_gap = minf(_minimum_gap, a.distance_to(b))


func _select_cart(index: int) -> void:
	if _mission.selected_cart != index:
		_key(KEY_C)
