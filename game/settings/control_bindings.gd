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
const HEROES_RESULT := &"gameplay_binding_heroes_result"

## Controller layouts. HEROES lines the battle controls up with Kingdom Under Fire:
## Heroes; CLASSIC is the original slot layout the battle scripts are written in.
enum Layout { CLASSIC, HEROES }
const LAYOUT_NAMES: PackedStringArray = ["Classic", "Kingdom Under Fire: Heroes"]
## The battle mode the Heroes layout is resolved against.
enum Mode { TACTICS, ACTION, COMMAND }
## Logical actions with no classic button of their own. The harness handles them.
const ACT_SET_WAYPOINT := 100
const ACT_ADD_WAYPOINT := 101
const ACT_MOVE_ALL := 102
const ACT_TIGHTER := 103
const ACT_WIDER := 104
const ACT_CAMERA_VIEW := 105
## A trigger counts as held past this pull, and released below the lower value.
const TRIGGER_PRESS := 0.5
const TRIGGER_RELEASE := 0.3
## Synthetic axis for inputs the Heroes layout swallows (it is never read).
const NOOP_AXIS := 9

static var _slots: Dictionary = {}
static var _loaded := false
static var _layout := -1
static var _mode_provider := Callable()
static var _trigger_held := {JOY_AXIS_TRIGGER_LEFT: false, JOY_AXIS_TRIGGER_RIGHT: false}
static var _command_latched := false
static var _y_held := false
static var _y_chorded := false
static var _b_special := false
static var _prompts: Translation


static func load_saved(path := PATH) -> void:
	_loaded = true
	_slots.clear()
	var config := ConfigFile.new()
	var loaded := config.load(path) == OK
	if _layout < 0:
		var saved: Variant = config.get_value("controller", "layout", Layout.HEROES) if loaded else Layout.HEROES
		# Scripted test runs address the battle scripts' own slots directly, whatever
		# a player saved; they opt into the Heroes layout explicitly with set_layout().
		_apply_layout(Layout.CLASSIC if _scripted_run() else (saved if saved in [Layout.CLASSIC, Layout.HEROES] else Layout.HEROES))
	if not loaded:
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
	config.set_value("controller", "layout", layout())
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
	if event.has_meta(HEROES_RESULT):
		return event.get_meta(HEROES_RESULT)
	var swapped := _swap(event)
	if not heroes_active() or not (swapped is InputEventJoypadButton or swapped is InputEventJoypadMotion):
		return swapped
	# Several nodes translate the same raw event; resolve it once so the stateful
	# parts (the Back toggle, trigger edges, Y + B) advance exactly once.
	var result := _heroes(swapped)
	result.set_meta(TRANSLATED, true)
	event.set_meta(HEROES_RESULT, result)
	return result


static func _swap(event: InputEvent) -> InputEvent:
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
	if heroes_active():
		# Back latches the command view; R2's battle meanings arrive only as events.
		if slot == JOY_AXIS_TRIGGER_LEFT:
			return 1.0 if _command_latched else 0.0
		if slot == JOY_AXIS_TRIGGER_RIGHT:
			return 0.0
	return Input.get_joy_axis(device, physical(group_for_axis(slot), slot))


static func key(slot: Key) -> bool:
	return Input.is_physical_key_pressed(physical(&"key", slot))


static func button(device: int, slot: JoyButton) -> bool:
	return Input.is_joy_button_pressed(device, physical(&"button", slot))


static func mouse(slot: MouseButton) -> bool:
	return Input.is_mouse_button_pressed(physical(&"mouse", slot))



# --- Kingdom Under Fire: Heroes layout -------------------------------------------

static func layout() -> int:
	if _layout < 0:
		load_saved()
	return _layout


## Chooses the controller layout and saves it with the bindings.
static func set_layout(next: int, path := PATH) -> Error:
	_apply_layout(next)
	reset_heroes_state()
	return _save(_slots, path) if path != "" else OK


static func _apply_layout(next: int) -> void:
	_layout = next
	if next == Layout.HEROES:
		if _prompts == null:
			_prompts = HeroesPrompts.new()
		_prompts.locale = TranslationServer.get_locale()
		TranslationServer.add_translation(_prompts)
	elif _prompts != null:
		TranslationServer.remove_translation(_prompts)


static func _scripted_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


## Battlefields register a provider returning {mode, overrides, drafting}; the Heroes
## layout applies only while one is registered (menus and the overworld use the
## same buttons in both layouts).
static func set_mode_provider(provider: Callable) -> void:
	_mode_provider = provider
	reset_heroes_state()


static func clear_mode_provider(owner: Object) -> void:
	if _mode_provider.is_valid() and _mode_provider.get_object() == owner:
		_mode_provider = Callable()
		reset_heroes_state()


static func heroes_active() -> bool:
	return layout() == Layout.HEROES and _mode_provider.is_valid()


static func command_latched() -> bool:
	return _command_latched


static func reset_heroes_state() -> void:
	_trigger_held = {JOY_AXIS_TRIGGER_LEFT: false, JOY_AXIS_TRIGGER_RIGHT: false}
	_command_latched = false
	_y_held = false
	_y_chorded = false
	_b_special = false


static func _both_triggers() -> bool:
	return _trigger_held[JOY_AXIS_TRIGGER_LEFT] and _trigger_held[JOY_AXIS_TRIGGER_RIGHT]


static func _heroes(event: InputEvent) -> InputEvent:
	var info: Dictionary = _mode_provider.call()
	var mode: int = info.get("mode", Mode.TACTICS)
	if event is InputEventJoypadMotion:
		var axis_code: int = event.axis
		if axis_code not in _trigger_held:
			return event.duplicate()
		# LT / RT change the selected troop, as D-pad Left / Right do.
		var was_held: bool = _trigger_held[axis_code]
		var held: bool = event.axis_value > TRIGGER_RELEASE if was_held else event.axis_value >= TRIGGER_PRESS
		_trigger_held[axis_code] = held
		if held == was_held:
			return _motion(event.device, NOOP_AXIS, 0.0)
		return _button(event.device, JOY_BUTTON_DPAD_LEFT if axis_code == JOY_AXIS_TRIGGER_LEFT else JOY_BUTTON_DPAD_RIGHT, held)
	var code: int = event.button_index
	var pressed: bool = event.pressed
	if code == JOY_BUTTON_BACK:
		# Back toggles the mini-map, which is our command view.
		if not pressed:
			return _motion(event.device, NOOP_AXIS, 0.0)
		_command_latched = not _command_latched
		return _motion(event.device, JOY_AXIS_TRIGGER_LEFT, 1.0 if _command_latched else 0.0)
	if code == JOY_BUTTON_START:
		return event.duplicate()
	if mode == Mode.COMMAND and info.get("drafting", false):
		# Aiming on the mini-map keeps its own Cross / Circle / D-pad controls.
		if code == JOY_BUTTON_A and pressed and _both_triggers():
			return _button(event.device, JOY_BUTTON_RIGHT_SHOULDER, true)
		return event.duplicate()
	var overrides: Dictionary = info.get("overrides", {})
	if overrides.has(code):
		return _button(event.device, overrides[code], pressed)
	match mode:
		Mode.TACTICS:
			match code:
				JOY_BUTTON_A: return _button(event.device, ACT_ADD_WAYPOINT if _both_triggers() else ACT_SET_WAYPOINT, pressed)
				JOY_BUTTON_X: return _button(event.device, JOY_BUTTON_A, pressed)
				JOY_BUTTON_Y: return _button(event.device, ACT_MOVE_ALL, pressed)
				JOY_BUTTON_LEFT_SHOULDER: return _button(event.device, ACT_WIDER, pressed)
				JOY_BUTTON_RIGHT_SHOULDER: return _button(event.device, ACT_TIGHTER, pressed)
				JOY_BUTTON_RIGHT_STICK: return _button(event.device, ACT_CAMERA_VIEW, pressed)
		Mode.ACTION:
			match code:
				JOY_BUTTON_A: return _button(event.device, JOY_BUTTON_X, pressed)
				JOY_BUTTON_X: return _button(event.device, JOY_BUTTON_A, pressed)
				JOY_BUTTON_Y:
					# Y alone is the heavy attack on release; hold Y and press B for
					# the special attack.
					if pressed:
						_y_held = true
						_y_chorded = false
						return _motion(event.device, NOOP_AXIS, 0.0)
					var tapped := _y_held and not _y_chorded
					_y_held = false
					return _button(event.device, JOY_BUTTON_Y, true) if tapped else _motion(event.device, NOOP_AXIS, 0.0)
				JOY_BUTTON_B:
					if pressed and _y_held:
						_y_chorded = true
						_b_special = true
						return _motion(event.device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
					if not pressed and _b_special:
						_b_special = false
						return _motion(event.device, JOY_AXIS_TRIGGER_RIGHT, 0.0)
					return event.duplicate()
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
					# Officer summons in Heroes; with no officers yet, either guards.
					return _button(event.device, JOY_BUTTON_LEFT_SHOULDER, pressed)
				JOY_BUTTON_RIGHT_STICK: return _button(event.device, ACT_CAMERA_VIEW, pressed)
		Mode.COMMAND:
			match code:
				JOY_BUTTON_A: return _button(event.device, JOY_BUTTON_RIGHT_SHOULDER if _both_triggers() else JOY_BUTTON_X, pressed)
				JOY_BUTTON_B: return _button(event.device, JOY_BUTTON_A, pressed)
				JOY_BUTTON_X: return _button(event.device, JOY_BUTTON_Y, pressed)
				JOY_BUTTON_Y: return _button(event.device, ACT_MOVE_ALL, pressed)
				JOY_BUTTON_LEFT_SHOULDER: return _button(event.device, ACT_WIDER, pressed)
				JOY_BUTTON_RIGHT_SHOULDER: return _button(event.device, ACT_TIGHTER, pressed)
	return event.duplicate()


static func _button(device: int, code: int, pressed: bool) -> InputEventJoypadButton:
	var out := InputEventJoypadButton.new()
	out.device = device
	out.button_index = code as JoyButton
	out.pressed = pressed
	return out


static func _motion(device: int, code: int, value: float) -> InputEventJoypadMotion:
	var out := InputEventJoypadMotion.new()
	out.device = device
	out.axis = code as JoyAxis
	out.axis_value = value
	return out


## What each controller button does in the Heroes layout, for the settings page.
const HEROES_BUTTON_ROWS := {
	JOY_BUTTON_A: "Set waypoint / normal attack / move order",
	JOY_BUTTON_B: "Stop: clear route / dodge (Triangle + Circle: special) / hold",
	JOY_BUTTON_X: "Interact / attack order",
	JOY_BUTTON_Y: "Move all troops / heavy attack",
	JOY_BUTTON_LEFT_SHOULDER: "Wider formation / guard",
	JOY_BUTTON_RIGHT_SHOULDER: "Tighter formation / guard",
	JOY_BUTTON_DPAD_LEFT: "Previous unit / mission action",
	JOY_BUTTON_DPAD_RIGHT: "Next unit / mission action",
	JOY_BUTTON_DPAD_UP: "Clear route / mini-map cursor",
	JOY_BUTTON_DPAD_DOWN: "Mission action",
	JOY_BUTTON_LEFT_STICK: "Center on leader (mini-map)",
	JOY_BUTTON_RIGHT_STICK: "Change camera view / overview",
	JOY_BUTTON_BACK: "Mini-map and command view on / off",
}
const HEROES_TRIGGER_ROWS := {
	JOY_AXIS_TRIGGER_LEFT: "Previous troop (LT + RT + Cross: add waypoint)",
	JOY_AXIS_TRIGGER_RIGHT: "Next troop (LT + RT + Cross: add waypoint)",
}


## The settings rows for the active layout.
static func rows() -> Dictionary:
	if layout() != Layout.HEROES:
		return ROWS
	var result := ROWS.duplicate(true)
	result[&"button"] = HEROES_BUTTON_ROWS.duplicate()
	result[&"trigger"] = HEROES_TRIGGER_ROWS.duplicate()
	return result


## Rewrites the classic button names in battle prompts for the Heroes layout. Labels
## translate their text when drawn, so scripts and tests keep reading the source text.
class HeroesPrompts extends Translation:
	const PHRASES := [
		["Hold Cross / Space", "Hold Square / Space"],
		["Cross / Space", "Square / Space"],
		["Cross or Space", "Square or Space"],
		["Release L2 / Shift", "Press Back (or release Shift)"],
		["Release L2 or Shift", "Press Back (or release Shift)"],
		["Hold L2 / Shift", "Back / hold Shift"],
		["L2 / Shift", "Back / Shift"],
		["L2 + D-pad Up", "Back, then D-pad Up"],
		["Square / right click: move", "Cross / right click: move"],
		["Square / right-click: move", "Cross / right-click: move"],
		["Square / right click: Move", "Cross / right click: Move"],
		["Cross / H: hold", "Circle / H: hold"],
		["Cross / H: Hold", "Circle / H: Hold"],
		["Triangle / K: attack", "Square / K: attack"],
		["R1 / G: append", "LT + RT + Cross / G: append"],
		["R1 / G: Append", "LT + RT + Cross / G: Append"],
		["R2 / V", "Triangle + Circle / V"],
		["D-pad Down / C", "R3 / C"],
	]

	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		var text := String(src_message)
		var changed := text
		for pair: Array in PHRASES:
			changed = changed.replace(pair[0], pair[1])
		return StringName(changed) if changed != text else &""
