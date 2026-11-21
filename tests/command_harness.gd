extends SceneTree

const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _harness: Harness
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_harness = HarnessScene.instantiate()
	root.add_child(_harness)
	var battle := _harness.battle
	var infantry := battle.formations[0]
	var archers := battle.formations[1]
	var hero_spawn := battle.hero_position
	var archer_spawn := archers.position

	_check(root.get_camera_3d().name == &"HeroCamera", "Hero camera is active on launch.")
	_key(KEY_D, true)
	await _frames(10)
	_key(KEY_D, false)
	_check(battle.hero_position.x > hero_spawn.x, "WASD moves the hero.")
	var hero_before_command := battle.hero_position

	_axis(JOY_AXIS_TRIGGER_LEFT, 0.35)
	_check(not _harness.command_view, "Trigger noise does not enter command view.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.85)
	_check(_harness.command_view and root.get_camera_3d().name == &"CommandCamera", "L2 activates the command camera.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.40)
	_check(_harness.command_view, "Trigger hysteresis prevents flicker.")
	_button(JOY_BUTTON_DPAD_LEFT)
	_check(_harness.selected_index == 1, "D-pad selection wraps to the second formation.")
	var old_cursor := _harness.cursor
	_axis(JOY_AXIS_LEFT_X, 0.8)
	await _frames(10)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_check(_harness.cursor.x > old_cursor.x, "Left stick moves the cursor in command view.")
	_check(battle.hero_position == hero_before_command, "Command cursor input does not move the hero.")

	_button(JOY_BUTTON_X)
	_check(archers.order == Battle.Order.MOVE and archers.destination == _harness.cursor, "Square issues a Move order to the cursor.")
	await _frames(10)
	var mid_move := archers.position
	_check(mid_move != archer_spawn and infantry.order == Battle.Order.HOLD, "Only the selected formation moves while command view is active.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(not _harness.command_view and root.get_camera_3d().name == &"HeroCamera", "Releasing L2 immediately restores the hero camera.")
	_key(KEY_W, true)
	await _frames(10)
	_key(KEY_W, false)
	_check(battle.hero_position.y < hero_before_command.y, "Hero movement resumes on release.")
	_check(_harness.battle == battle and archers.position != mid_move and archers.order == Battle.Order.MOVE, "The same formation keeps moving after returning to the hero.")
	_button(JOY_BUTTON_A)
	_check(archers.order == Battle.Order.MOVE, "Cross cannot issue a Hold order in hero view.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_A)
	var held_at := archers.position
	await _frames(10)
	_check(archers.position == held_at and archers.destination == held_at and archers.order == Battle.Order.HOLD, "Cross cancels movement and holds at the current position.")
	_key(KEY_SHIFT, true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(_harness.command_view, "Holding Shift keeps command view active when L2 is released.")
	_click(MOUSE_BUTTON_LEFT, infantry.position)
	_check(_harness.selected_index == 0, "Left click selects the formation under the pointer.")
	var destination := infantry.position + Vector2(0.0, 2.0)
	_click(MOUSE_BUTTON_RIGHT, destination)
	_check(infantry.order == Battle.Order.MOVE and infantry.destination.is_equal_approx(destination), "Right click issues Move at the projected ground position.")
	_key(KEY_SHIFT, false)
	_check(not _harness.command_view, "Releasing Shift alone returns to hero view.")
	await _frames(60)
	_check(infantry.position.is_equal_approx(destination) and infantry.order == Battle.Order.HOLD, "Arriving at the destination stops there without overshooting.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_harness.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _harness.command_view, "Losing application focus clears a held trigger.")

	_harness.queue_free()
	await process_frame
	if _failures == 0:
		print("Command harness: hero movement, L2/Shift transitions, cursor, selection, continued orders, Hold and arrival passed.")
	quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _click(code: MouseButton, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.position = root.get_camera_3d().unproject_position(Vector3(point.x, 0.0, point.y))
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
