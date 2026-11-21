extends RefCounted
## Translates reassigned physical inputs into the slots used by battlefield scenes.

const PATH := "user://controls.cfg"
const SWAP_GROUPS := [&"key", &"mouse", &"button", &"stick", &"trigger"]
# One slot can have different meanings in different battlefield modes.
const ROWS := {
	&"key": {
		KEY_W: "Advance / aim up", KEY_A: "Move or aim left", KEY_S: "Retreat / aim down", KEY_D: "Move or aim right",
		KEY_LEFT: "Camera left", KEY_RIGHT: "Camera right", KEY_UP: "Camera up", KEY_DOWN: "Camera down",
		KEY_Q: "Orbit left / previous unit / ability", KEY_E: "Orbit right / next unit / interact",
		KEY_R: "Tilt up", KEY_F: "Tilt down / clear order", KEY_TAB: "Command view (standard missions)",
		KEY_SHIFT: "Command view (authored missions) / guard", KEY_CTRL: "Walk",
		KEY_J: "Light attack / add waypoint to route", KEY_K: "Heavy attack / attack order", KEY_L: "Dodge / guard",
		KEY_U: "Guard", KEY_SPACE: "Interact / dodge / hold", KEY_H: "Hold position",
		KEY_Z: "Previous unit", KEY_X: "Next unit", KEY_M: "Toggle overview", KEY_HOME: "Center on leader",
		KEY_G: "Set waypoint (replaces route) / minimap", KEY_T: "Clear route / turn cart",
		KEY_I: "Tighter formation", KEY_O: "Wider formation", KEY_C: "Focus leader",
		KEY_V: "Sundering Strike", KEY_P: "Toggle overview (standard missions)", KEY_B: "Mission action",
		KEY_ENTER: "Confirm mission action", KEY_KP_ENTER: "Confirm with numeric keypad", KEY_N: "Minimap planning", KEY_BACKSPACE: "Restart (where available)",
		KEY_1: "Select unit 1", KEY_2: "Select unit 2", KEY_3: "Select unit 3", KEY_4: "Select unit 4",
		KEY_5: "Select unit 5", KEY_6: "Select unit 6", KEY_7: "Select unit 7", KEY_8: "Select unit 8", KEY_9: "Select unit 9",
	},
	&"mouse": {
		MOUSE_BUTTON_LEFT: "Select / light attack", MOUSE_BUTTON_RIGHT: "Move order / heavy attack",
		MOUSE_BUTTON_MIDDLE: "Orbit camera", MOUSE_BUTTON_WHEEL_UP: "Zoom in", MOUSE_BUTTON_WHEEL_DOWN: "Zoom out",
	},
	&"button": {
		JOY_BUTTON_A: "Interact / hold", JOY_BUTTON_B: "Dodge / clear route or order",
		JOY_BUTTON_X: "Light attack / add waypoint to route / move order", JOY_BUTTON_Y: "Heavy attack / attack order",
		JOY_BUTTON_LEFT_SHOULDER: "Guard / tighter formation", JOY_BUTTON_RIGHT_SHOULDER: "Officer ability / set waypoint",
		JOY_BUTTON_DPAD_LEFT: "Previous unit", JOY_BUTTON_DPAD_RIGHT: "Next unit",
		JOY_BUTTON_DPAD_UP: "Minimap / clear route", JOY_BUTTON_DPAD_DOWN: "Focus leader / mission action",
		JOY_BUTTON_LEFT_STICK: "Center on leader", JOY_BUTTON_RIGHT_STICK: "Toggle overview",
		JOY_BUTTON_BACK: "Pause (alternate)",
	},
	&"stick": {
		JOY_AXIS_LEFT_X: "Move / aim horizontally", JOY_AXIS_LEFT_Y: "Move / aim vertically",
		JOY_AXIS_RIGHT_X: "Orbit camera", JOY_AXIS_RIGHT_Y: "Tilt camera",
	},
	&"trigger": {JOY_AXIS_TRIGGER_LEFT: "Command view", JOY_AXIS_TRIGGER_RIGHT: "Sundering Strike / wider formation"},
}
const BUTTON_NAMES := {
	JOY_BUTTON_A: "Cross / A", JOY_BUTTON_B: "Circle / B", JOY_BUTTON_X: "Square / X", JOY_BUTTON_Y: "Triangle / Y",
	JOY_BUTTON_LEFT_SHOULDER: "L1 / LB", JOY_BUTTON_RIGHT_SHOULDER: "R1 / RB",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_LEFT_STICK: "Left stick click", JOY_BUTTON_RIGHT_STICK: "Right stick click",
	JOY_BUTTON_BACK: "Create / View", JOY_BUTTON_START: "Options / Menu",
}
const AXIS_NAMES := ["Left stick X", "Left stick Y", "Right stick X", "Right stick Y", "L2 / LT", "R2 / RT"]
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click", MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
}
const TRANSLATED := &"gameplay_binding_translated"

static var _slots: Dictionary = {}
static var _loaded := false


static func load_saved(path := PATH) -> void:
	_loaded = true
	_slots.clear()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for group: StringName in SWAP_GROUPS:
		var source: Variant = config.get_value("bindings", group, {})
		if source is not Dictionary:
			continue
		var valid := true
		for slot: Variant in source:
			var physical: Variant = source[slot]
			if not slot is int or not physical is int or not _valid(group, slot) or not _valid(group, physical):
				valid = false
				break
			if not source.has(physical) or source.values().count(physical) != 1:
				valid = false
				break
		if valid:
			_slots[group] = source


static func _save(slots: Dictionary, path: String) -> Error:
	var config := ConfigFile.new()
	for group: StringName in SWAP_GROUPS:
		config.set_value("bindings", group, slots.get(group, {}))
	var temporary := path + ".tmp"
	var error := config.save(temporary)
	if error != OK:
		return error
	return DirAccess.rename_absolute(temporary, path)


static func _valid(group: StringName, code: int) -> bool:
	match group:
		&"key":
			return code > 0 and code not in [KEY_ESCAPE, KEY_NONE] and not OS.get_keycode_string(code).is_empty()
		&"mouse":
			return code in MOUSE_NAMES or code in [MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
		&"button":
			return code >= 0 and code < JOY_BUTTON_MAX and code != JOY_BUTTON_START
		&"stick":
			return code >= JOY_AXIS_LEFT_X and code <= JOY_AXIS_RIGHT_Y
		&"trigger":
			return code in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	return false


static func physical(group: StringName, slot: int) -> int:
	if not _loaded:
		load_saved()
	var mapping: Dictionary = _slots.get(group, {})
	return mapping.get(slot, slot)


static func bind(group: StringName, slot: int, input: int, path := PATH) -> Error:
	if not ROWS.get(group, {}).has(slot) or not _valid(group, input):
		return ERR_INVALID_PARAMETER
	var previous := physical(group, slot)
	if previous == input:
		return OK
	var next := _slots.duplicate(true)
	var mapping: Dictionary = next.get(group, {})
	var other: int = mapping.find_key(input) if input in mapping else input
	mapping[slot] = input
	mapping[other] = previous
	for entry: int in mapping.keys():
		if entry == mapping[entry]:
			mapping.erase(entry)
	next[group] = mapping
	var error := _save(next, path)
	if error == OK:
		_slots = next
	return error


static func restore(path := PATH) -> Error:
	var error := _save({}, path)
	if error == OK:
		_loaded = true
		_slots.clear()
	return error


static func group_for_axis(axis: int) -> StringName:
	return &"trigger" if axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else &"stick"


static func describe(group: StringName, code: int) -> String:
	match group:
		&"key": return OS.get_keycode_string(code)
		&"mouse": return MOUSE_NAMES.get(code, "Mouse button %d" % code)
		&"button": return BUTTON_NAMES.get(code, "Button %d" % (code + 1))
		_: return AXIS_NAMES[code]


static func capture_code(group: StringName, event: InputEvent) -> int:
	if group == &"key" and event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode if event.physical_keycode else event.keycode
	if group == &"mouse" and event is InputEventMouseButton and event.pressed:
		return event.button_index
	if group == &"button" and event is InputEventJoypadButton and event.pressed:
		return event.button_index
	if event is InputEventJoypadMotion and group in [&"stick", &"trigger"]:
		if group == group_for_axis(event.axis) and absf(event.axis_value) >= 0.7:
			return event.axis
	return -1


static func translate(event: InputEvent) -> InputEvent:
	if event.has_meta(TRANSLATED):
		return event
	var group: StringName
	var input: int
	if event is InputEventKey:
		group = &"key"
		input = event.physical_keycode if event.physical_keycode else event.keycode
	elif event is InputEventMouseButton:
		group = &"mouse"
		input = event.button_index
	elif event is InputEventJoypadButton:
		group = &"button"
		input = event.button_index
	elif event is InputEventJoypadMotion:
		input = event.axis
		group = group_for_axis(input)
	else:
		return event
	if not _loaded:
		load_saved()
	var mapping: Dictionary = _slots.get(group, {})
	if not mapping.has(input):
		return event
	var slot: int = mapping.find_key(input)
	var logical := event.duplicate() as InputEvent
	if logical is InputEventKey:
		logical.physical_keycode = slot
		logical.keycode = slot
	elif logical is InputEventJoypadMotion:
		logical.axis = slot
	else:
		logical.set("button_index", slot)
	logical.set_meta(TRANSLATED, true)
	return logical


static func axis(device: int, slot: JoyAxis) -> float:
	return Input.get_joy_axis(device, physical(group_for_axis(slot), slot))


static func key(slot: Key) -> bool:
	return Input.is_physical_key_pressed(physical(&"key", slot))


static func button(device: int, slot: JoyButton) -> bool:
	return Input.is_joy_button_pressed(device, physical(&"button", slot))


static func mouse(slot: MouseButton) -> bool:
	return Input.is_mouse_button_pressed(physical(&"mouse", slot))
