extends SceneTree
## PlayStation 3 controller support: recognising the pad, the macOS fallback layout
## for unrecognised DS3s, and battles following whichever pad the player picks up.

const ControllerSupport := preload("res://game/controller.gd")
const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_names()
	_check_fallback_mapping()
	await _check_pad_switching()
	if _failures == 0:
		print("Controller support: PS3 recognition, the macOS DS3 fallback layout, and following the pad in use passed.")
	quit(0 if _failures == 0 else 1)


func _check_names() -> void:
	for joy_name in ["PS3 Controller", "Sony PLAYSTATION(R)3 Controller", "DualShock 3", "SHANWAN PS3 GamePad", "Sixaxis"]:
		_check(ControllerSupport.looks_like_playstation3(joy_name), "%s is recognised as a PlayStation 3 pad." % joy_name)
	for joy_name in ["PS4 Controller", "DualSense Wireless Controller", "Xbox Wireless Controller", ""]:
		_check(not ControllerSupport.looks_like_playstation3(joy_name), "%s is not treated as a PlayStation 3 pad." % joy_name)


func _check_fallback_mapping() -> void:
	var guid := "030000004c0500006802000000000000"
	var line := ControllerSupport.fallback_mapping(guid, "PLAYSTATION(R)3 Controller", false, "macOS")
	_check(line.begins_with(guid + ",PS3 Controller,"), "An unrecognised DS3 on macOS gets the PS3 layout.")
	var targets := {}
	for pair in line.split(",").slice(2):
		var parts := pair.split(":")
		_check(parts.size() == 2 and not targets.has(parts[0]), "Mapping entry %s is well formed and unique." % pair)
		targets[parts[0]] = parts[1]
	for wanted in ["a", "b", "x", "y", "back", "start", "guide", "leftshoulder", "rightshoulder", "lefttrigger", "righttrigger",
			"leftstick", "rightstick", "dpup", "dpdown", "dpleft", "dpright", "leftx", "lefty", "rightx", "righty"]:
		_check(targets.has(wanted), "The PS3 layout maps %s." % wanted)
	_check(targets.get("a") == "b14" and targets.get("x") == "b15" and targets.get("lefttrigger") == "b8" and targets.get("start") == "b3",
		"Cross, Square, L2 and Start follow the DS3's HID button order.")
	_check(ControllerSupport.fallback_mapping(guid, "PS3 Controller", true, "macOS").is_empty(), "A recognised pad keeps Godot's own layout.")
	_check(ControllerSupport.fallback_mapping(guid, "PS3 Controller", false, "Linux").is_empty(), "The macOS HID layout is not forced on other systems.")
	_check(ControllerSupport.fallback_mapping(guid, "Xbox Wireless Controller", false, "macOS").is_empty(), "Other pads are left alone.")
	Input.add_joy_mapping(line, true) # Must parse without an engine error.
	Input.remove_joy_mapping(guid)


func _check_pad_switching() -> void:
	ControllerSupport.active_device = -1
	var harness = HarnessScene.instantiate()
	harness.lead_platoon_enabled = false
	root.add_child(harness)
	await physics_frame
	var battle: Battle = harness.battle
	# A stray device nudges a stick first and claims the controls.
	_axis(0, JOY_AXIS_LEFT_X, 0.2)
	await physics_frame
	_check(harness._input_device == 0, "The first pad heard takes the controls.")
	var start := battle.hero_position
	# The real controller presses a button and pushes its stick.
	_button(1, JOY_BUTTON_A)
	_check(ControllerSupport.active_device == 1 and harness._input_device == 1, "Pressing a button on another pad hands it the controls.")
	_axis(1, JOY_AXIS_LEFT_X, 1.0)
	_axis(0, JOY_AXIS_LEFT_X, -1.0)
	for i in range(20):
		await physics_frame
	_check(battle.hero_position.x > start.x, "The stick of the pad in use steers; the stray pad is ignored.")
	_axis(1, JOY_AXIS_LEFT_X, 0.0)
	_axis(1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	await physics_frame
	_check(harness.command_view, "L2 on the pad in use opens command view.")
	_axis(1, JOY_AXIS_TRIGGER_LEFT, 0.0)
	await physics_frame
	_check(not harness.command_view, "Releasing L2 returns to the hero.")
	harness.queue_free()
	await process_frame


func _axis(device: int, code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = code
	event.axis_value = amount
	ControllerSupport.note_event(event)
	root.push_input(event, true)


func _button(device: int, code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = code
		event.pressed = pressed
		ControllerSupport.note_event(event)
		root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
