extends SceneTree

const Mine := preload("res://game/battlefield/command_mine.tscn")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _harness: Harness
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_harness = Mine.instantiate()
	root.add_child(_harness)
	# Moving the whole scene must not displace its local bounds or picks.
	_harness.position = Vector3(7.0, 3.0, 15.0)
	_harness.set_physics_process(false)
	await physics_frame
	await physics_frame

	var battle := _harness.battle
	var infantry := battle.formations[0]
	var archers := battle.formations[1]
	_check(_harness.hero_world_position().is_equal_approx(_marker("Spawns/HumanEscort").global_position), "Hero reads the shared spawn at ground height.")
	_check(infantry.position == _point("Spawns/HumanInfantry") and archers.position == _point("Spawns/HumanArchers"), "Both formations read the authored mine spawns.")
	_check(battle.clamp_to_field(Vector2(100, -100)) == Vector2(45, -32), "The mine uses its own asymmetric field bounds.")

	_key(KEY_SHIFT, true)
	var junction := _point("Routes/RoadJunction")
	_click(_marker("Routes/RoadJunction").global_position)
	_check(infantry.order == Battle.Order.MOVE and infantry.destination.distance_to(junction) < 0.01, "The command camera ray picks the mine road.")
	_tick(20)
	var before_switch := infantry.position
	_key(KEY_SHIFT, false)
	_key(KEY_W, true)
	var hero_before := battle.hero_position
	_tick(20)
	_key(KEY_W, false)
	_check(battle.hero_position.x > hero_before.x, "The hero moves east from the authored facing.")
	_check(_harness.battle == battle and infantry.position.x > before_switch.x and infantry.order == Battle.Order.MOVE, "Road orders continue on the same mine battlefield during hero movement.")
	_tick(700)
	_check(infantry.position.distance_to(junction) < 0.01 and infantry.order == Battle.Order.HOLD, "Infantry traverse the mine road and settle at the junction.")

	_key(KEY_SHIFT, true)
	_key(KEY_X, true)
	_click(_marker("Routes/RidgeWestFoot").global_position)
	_tick(180)
	_check(archers.position.distance_to(_point("Routes/RidgeWestFoot")) < 0.01, "Archers can reach the base of the ridge.")
	# Move up the center lane before turning toward the overlook to avoid its cover.
	var ridge_lane := Vector3(-4.0, 4.0, -18.0)
	_click(_harness.to_global(ridge_lane))
	_tick(510)
	_check(archers.position.distance_to(Vector2(ridge_lane.x, ridge_lane.z)) < 0.01, "The formation climbs the west ramp and clears the ridge cover.")
	var overlook := _marker("Routes/RidgeOverlook")
	_click(overlook.global_position)
	_check(archers.order == Battle.Order.MOVE and archers.destination.distance_to(_point("Routes/RidgeOverlook")) < 0.01, "Picking an elevated point does not project through it to the basin.")
	_tick(140)
	_check(archers.position.distance_to(_point("Routes/RidgeOverlook")) < 0.01 and archers.order == Battle.Order.HOLD, "Formation reaches the crest overlook.")
	_check(is_equal_approx(_harness._formation_models[1].global_position.y, overlook.global_position.y), "Formation stands at the ridge elevation.")

	# The boulder lies across this straight order; the unit must stop, not phase through.
	var obstacle := Vector2(21.0, -6.0)
	infantry.position = Vector2(21.0, -2.0)
	battle.order_move(0, obstacle + Vector2(0.0, -5.0))
	_tick(160)
	_check(infantry.order == Battle.Order.BLOCKED and infantry.position.y > obstacle.y, "Solid boulders block a formation and its order reports Blocked.")
	var before_hidden_pick := archers.destination
	_click(_harness.to_global(Vector3(21.0, 2.5, -6.0)))
	_check(archers.destination == before_hidden_pick, "Clicking a boulder cannot issue an order through it.")

	_key(KEY_SHIFT, false)
	battle.hero_position = Vector2(21.0, -2.0)
	_key(KEY_A, true)
	_tick(80)
	_key(KEY_A, false)
	_check(battle.hero_position.y < -2.0 and battle.hero_position.y > obstacle.y, "The hero moves toward solid cover but cannot cross it.")
	battle.hero_position = _point("Routes/RidgeOverlook")
	_check(is_equal_approx(_harness.hero_world_position().y, overlook.global_position.y), "Hero world position includes the authored ground elevation.")
	battle.hero_position = _point("Routes/TunnelMidpoint")
	_check(is_equal_approx(_harness.hero_world_position().y, _marker("Routes/TunnelMidpoint").global_position.y), "Tunnel ground query ignores the roof.")

	_harness.queue_free()
	await process_frame
	if _failures == 0:
		print("Mine command field: markers, road continuity, terrain picks, ridge movement and solid obstructions passed.")
	quit(0 if _failures == 0 else 1)


func _tick(count: int) -> void:
	for index in range(count):
		_harness._physics_process(1.0 / 60.0)


func _marker(path: String) -> Marker3D:
	return _harness.battlefield_marker(NodePath("Markers/" + path))


func _point(path: String) -> Vector2:
	var point := _harness.to_local(_marker(path).global_position)
	return Vector2(point.x, point.z)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _click(position: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = root.get_camera_3d().unproject_position(position)
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
