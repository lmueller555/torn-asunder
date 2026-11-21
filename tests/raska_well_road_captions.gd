extends "res://tests/raska_well_road_staging.gd"
## Exercise the two-wagon wait with deployed movement and player input.


func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _check_staged_captions()
	_mission.queue_free()
	await process_frame
	if passed and _failures == 0:
		print("Well Road cart captions: both selections, camera restoration, physical clearance and Retry passed.")
	quit(0 if passed and _failures == 0 else 1)


func _check_staged_captions() -> bool:
	_march_to_gate()
	_face_and_hold(true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	var approach := ["Routes/UpperWellStaging", "Routes/WestApproachFork", "Routes/WashEntryTurn",
		"Routes/LowerWellStaging", "Objectives/LowerBoarding", "Spawns/LowerHouseholds", "Objectives/LowerStorehouse"]
	for mark in approach:
		_drive_to(_marker(mark))
	_select_cart(LOWER)
	_key(KEY_SPACE)
	_wait(func() -> bool: return _mission.objective.cart_state(LOWER) == WellRoad.CartState.READY, 700)
	if _mission._boarded != 3 or _mission._riders.filter(func(rider): return rider.visible).size() != 3:
		return _fail("Three households must actually board before dispatch.")
	approach.reverse()
	for mark in approach.slice(1, -1):
		_drive_to(_marker(mark))
	_drive_to(_marker("Routes/SaltRoadWest"))
	_drive_to(Vector3(-100.33, 0.0, -7.55)) # Usable close view between both staged wagons.
	_select_cart(UPPER)
	_key(KEY_G)
	_tick()
	_select_cart(LOWER)
	_key(KEY_G)
	var upper := _mission._carts[UPPER]
	var lower := _mission._carts[LOWER]
	_wait(func() -> bool: return upper.waiting_on == "Mounted pass" and lower.waiting_on == "Cart ahead", 2200)
	var front := upper.wagon.global_position
	var rear := lower.wagon.global_position
	if upper.waiting_on != "Mounted pass" or lower.waiting_on != "Cart ahead" \
			or not front.is_equal_approx(_marker("Routes/SaltRoadWest")) \
			or not is_equal_approx(front.distance_to(rear), Mission.SALT_REAR_DISTANCE):
		return _fail("Both salt orders must reach the original separate wait positions.")
	if not _assert_captions(true, LOWER):
		return false
	_select_cart(UPPER)
	_tick()
	if not _assert_captions(true, UPPER):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1)
	_tick()
	if not _assert_captions(false, UPPER, true):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_tick()
	if not _assert_captions(true, UPPER):
		return false
	if not front.is_equal_approx(upper.wagon.global_position) or not rear.is_equal_approx(lower.wagon.global_position):
		return _fail("Selection and camera changes must not advance either staged wagon.")
	_drive_to(Vector3(-81.20, 0.0, -7.55))
	if not _assert_captions(false, UPPER):
		return false
	_wait(func() -> bool: return _mission.objective.outcome != WellRoad.Outcome.ACTIVE, 7600)
	if not _both_delivered():
		return false
	_key(KEY_BACKSPACE)
	_tick()
	return (_mission._riders.filter(func(rider): return rider.visible).is_empty()
		and upper.banner.text == "Upper-well cart: Ready"
		and lower.banner.text == "Lower-well cart: Awaiting households") \
		or _fail("Retry must restore the default labels and disembarked households.")


func _assert_captions(compact: bool, selected: int, tactical := false) -> bool:
	var camera := _mission._command_camera if tactical else _mission._hero_camera
	if root.get_camera_3d() != camera or _mission.selected_cart != selected \
			or not _mission._select.text.contains(Mission.CART_NAMES[selected]) \
			or not _mission._status.text.contains("Waiting: Mounted pass") \
			or not _mission._status.text.contains("Waiting: Cart ahead"):
		return _fail("Use the real camera and preserve selection and both full wait states in the HUD.")
	for index in range(2):
		var label := _mission._carts[index].banner
		var expected: String = Mission.CART_NAMES[index]
		if compact:
			if index == selected:
				expected += " · Selected"
		else:
			expected += ": Waiting: Mounted pass" if index == UPPER else ": Waiting: Cart ahead"
		if label.text != expected or not is_equal_approx(label.pixel_size, 0.012 if compact else 0.028) \
				or not is_equal_approx(label.position.y, 3.60 if compact else 2.8) \
				or label.modulate != (Mission.CART_COLORS[index] if index == selected else Color.WHITE):
			return _fail("Wrong %s label: %s (expected %s)." % ["close" if compact else "full", label.text, expected])
	return true
