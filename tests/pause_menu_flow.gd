extends SceneTree

const Main := preload("res://game/title_screen.tscn")
const Bindings := preload("res://game/settings/control_bindings.gd")
var _test_path := "user://pause-test-bindings-%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := await _verify()
	DirAccess.remove_absolute(_test_path)
	Bindings.load_saved()
	paused = false
	quit(0 if passed else 1)


func _verify() -> bool:
	if Bindings.restore(_test_path) != OK:
		return _fail("Could not initialize test bindings.")
	if Bindings.bind(&"key", KEY_J, KEY_K, _test_path) != OK \
			or Bindings.bind(&"button", JOY_BUTTON_X, JOY_BUTTON_Y, _test_path) != OK \
			or Bindings.bind(&"trigger", JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT, _test_path) != OK:
		return _fail("Could not save input swaps.")
	Bindings.load_saved(_test_path)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_K
	var logical := Bindings.translate(release) as InputEventKey
	if logical.physical_keycode != KEY_J or logical.pressed or Bindings.translate(logical) != logical \
			or Bindings.physical(&"key", KEY_K) != KEY_J:
		return _fail("Keyboard rebinding did not swap and translate releases exactly once.")
	var attack := InputEventJoypadButton.new()
	attack.button_index = JOY_BUTTON_Y
	attack.pressed = true
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 0.85
	if Bindings.translate(attack).button_index != JOY_BUTTON_X \
			or Bindings.translate(trigger).axis != JOY_AXIS_TRIGGER_LEFT \
			or Bindings.bind(&"button", JOY_BUTTON_X, JOY_BUTTON_START, _test_path) == OK:
		return _fail("Controller remaps or reserved pause input are incorrect.")
	if Bindings.restore(_test_path) != OK or Bindings.physical(&"key", KEY_J) != KEY_J:
		return _fail("Restore Defaults did not restore the bindings.")

	var title = Main.instantiate()
	root.add_child(title)
	title._pause_menu.bindings_path = _test_path
	title._show_skirmish()
	var view := title.find_child("InfantrySkirmish", true, false)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	root.push_input(start, true)
	if not paused or view.can_process():
		return _fail("Controller Start did not pause skirmish simulation.")
	var elapsed: float = view.battle.elapsed
	await physics_frame
	await physics_frame
	if view.battle.elapsed != elapsed or not _press(title._pause_menu, "Settings"):
		return _fail("Battle advanced during pause or Settings was missing.")
	if not _press(title._pause_menu, "Advance / aim up    ·    W"):
		return _fail("Could not open the first keyboard binding.")
	var replacement := InputEventKey.new()
	replacement.keycode = KEY_F5
	replacement.physical_keycode = KEY_F5
	replacement.pressed = true
	root.push_input(replacement, true)
	Bindings.load_saved(_test_path)
	if Bindings.physical(&"key", KEY_W) != KEY_F5:
		return _fail("The binding captured in the menu did not survive reload.")
	if not _press(title._pause_menu, "Restore Defaults") or not _press(title._pause_menu, "Restore"):
		return _fail("The menu did not offer a confirmation for restoring defaults.")
	if Bindings.physical(&"key", KEY_W) != KEY_W:
		return _fail("Restoring defaults in the menu did not reset the saved binding.")
	if not _press(title._pause_menu, "Controller") or not _press(title._pause_menu, "Restore Defaults"):
		return _fail("The controller reference or Restore Defaults was missing.")
	# Use Escape to back out of each page, then controller Start to resume.
	for count in range(2):
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		root.push_input(esc, true)
	if not paused:
		return _fail("Backing out of Settings resumed too early.")
	root.push_input(start, true)
	if paused or not view.can_process():
		return _fail("Controller Start did not resume skirmish.")
	title._pause_game()
	if not _press(title._pause_menu, "LeaveGame") or not _press(title._pause_menu, "ConfirmLeave"):
		return _fail("Leaving a skirmish did not require a confirmation.")
	if paused or title._page != title.Page.SKIRMISH_SETUP:
		return _fail("Leaving the skirmish kept the game paused or opened the wrong page.")
	title.queue_free()
	print("Pause controls, persistence, simulation freeze, and exit passed.")
	return true


func _press(menu: Node, name: String) -> bool:
	for child in menu.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and (button.name == name or button.text == name):
			button.pressed.emit()
			return true
	return false


func _fail(reason: String) -> bool:
	push_error(reason)
	return false
