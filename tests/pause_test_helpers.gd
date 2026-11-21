extends RefCounted


static func leave_battle(title: Node) -> bool:
	var pause := title._stage.get_node_or_null("PauseBattle") as Button
	if not pause or not pause.is_visible_in_tree():
		return false
	pause.pressed.emit()
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
