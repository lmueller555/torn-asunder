extends RefCounted


static func leave_battle(title: Node) -> bool:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	title.get_viewport().push_input(escape, true)
	return confirm_leave(title._pause_menu)


static func confirm_leave(menu: Node) -> bool:
	return _press_sequence(menu, ["LeaveGame", "ConfirmLeave"])


static func confirm_restart(menu: Node) -> bool:
	return _press_sequence(menu, ["RestartGame", "ConfirmRestart"])


static func _press_sequence(menu: Node, names: Array[String]) -> bool:
	for name in names:
		var button := menu.find_child(name, true, false) as Button
		if not button or not button.is_visible_in_tree():
			return false
		button.pressed.emit()
	return true
