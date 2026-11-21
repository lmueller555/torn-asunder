extends SceneTree

const Scene := preload("res://game/battlefield/waypoint_command_harness.tscn")
const Waypoints := preload("res://game/battlefield/waypoint_command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _scene: Waypoints
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = Scene.instantiate()
	root.add_child(_scene)
	var infantry := _scene.battle.formations[0]
	var archers := _scene.battle.formations[1]
	var start := infantry.position
	var head := start + Vector2(1.0, 0.0)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_scene.route_for(0).is_empty(), "Append outside command view does not issue an order.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_scene.cursor = head
	_button(JOY_BUTTON_X)
	_check(infantry.destination == head and _scene.route_for(0) == PackedVector2Array([head]),
			"Square starts at the terrain cursor.")
	_button(JOY_BUTTON_RIGHT_STICK)
	var bend := head + Vector2(0.0, -1.5)
	_point_at(bend)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_check(infantry.destination == head and _scene.route_for(0).size() == 2 and _scene.route_for(0)[1].is_equal_approx(bend),
			"Overview append extends, does not jump to the tail, and rejects duplicates.")
	_scene.cursor = Vector2(200.0, -200.0)
	_button(JOY_BUTTON_X)
	_check(_scene.route_for(0).size() == 2, "Out-of-bounds Move rejects without replacing a valid route.")
	_check(_scene._waypoint_labels[1].visible, "Both pending points appear in overview.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_check(_scene.route_for(1).is_empty() and not _scene._waypoint_labels[0].visible,
			"Unrelated platoons do not inherit the selected route.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(23)
	_check(infantry.position.x >= head.x - 0.001 and infantry.destination.is_equal_approx(bend),
			"The first destination was physically reached before the bend.")
	await _frames(38)
	_check(infantry.position.is_equal_approx(bend) and infantry.order == Battle.Order.HOLD
			and _scene.route_for(0).is_empty() and archers.order == Battle.Order.HOLD,
			"Actual travel clears the pending route even after returning to the hero.")

	_key(KEY_SHIFT, true)
	_button(JOY_BUTTON_DPAD_LEFT)
	_scene.cursor = bend + Vector2(-5.0, 0.0)
	_key(KEY_G, true)
	_scene.cursor = bend + Vector2(-5.0, 1.0)
	_key(KEY_G, true)
	_scene.cursor = bend + Vector2(0.0, 4.0)
	_button(JOY_BUTTON_X)
	_check(_scene.route_for(0) == PackedVector2Array([_scene.cursor]), "A valid Move replaces the whole route.")
	_button(JOY_BUTTON_A)
	_check(_scene.route_for(0).is_empty() and infantry.order == Battle.Order.HOLD,
			"Hold clears all pending points.")
	_scene.cursor = bend + Vector2(0.0, 3.0)
	_key(KEY_G, true)
	_scene.restart_battle()
	_check(_scene.route_for(0).is_empty() and _scene.route_for(1).is_empty(), "Restart clears routes.")
	_scene.queue_free()
	await process_frame
	if _failures == 0:
		print("Waypoint harness: actual two-leg march, sector/overview input, route isolation, direct replacement, cancel and restart passed.")
	quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)


func _button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)


func _point_at(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_camera_3d().unproject_position(Vector3(point.x, 0.0, point.y))
	root.push_input(event, true)


func _check(condition: bool, reason: String) -> void:
	if not condition:
		_failures += 1
		push_error(reason)
