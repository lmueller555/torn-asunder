extends Node
## Controller support shared by every scene, loaded as the `Controller` autoload.
##
## - Tracks the joypad the player is actually using, so a stray HID device that
##   connects first (common on macOS) can't swallow the input.
## - Recognises PlayStation 3 controllers (DualShock 3 / Sixaxis). Godot reads
##   controllers through SDL, which maps a DS3 on macOS to the standard layout:
##   Cross = A, Circle = B, Square = X, Triangle = Y, L2/R2 = trigger axes,
##   Start = START, Select = BACK. If Godot doesn't recognise the pad (some clones),
##   a DS3 layout mapping is applied on macOS so the buttons aren't scrambled.
## - Recognises Xbox 360 controllers. SDL maps them to the same standard layout
##   (A = Cross, B = Circle, X = Square, Y = Triangle, LB/RB = L1/R1, LT/RT = L2/R2,
##   Start = Options, Back = Create). An unrecognised 360 pad on macOS (seen through
##   the community 360Controller driver) gets that driver's layout.
## - Logs each controller as it connects, for checking a pad on a new machine.
##
## The state is static, so scripts that only preload this file (and headless tests,
## which run without the autoload) can still query it.

## SDL mapping body for a DualShock 3 seen as a raw HID device on macOS. The button
## numbers follow the DS3's own HID report order (Select, L3, R3, Start, D-pad
## up/right/down/left, L2, R2, L1, R1, Triangle, Circle, Cross, Square, PS).
const Bindings := preload("res://game/settings/control_bindings.gd")
const PS3_MAC_MAPPING := "a:b14,b:b13,back:b0,dpdown:b6,dpleft:b7,dpright:b5,dpup:b4,guide:b16," \
	+ "leftshoulder:b10,leftstick:b1,lefttrigger:b8,leftx:a0,lefty:a1,rightshoulder:b11," \
	+ "rightstick:b2,righttrigger:b9,rightx:a2,righty:a3,start:b3,x:b15,y:b12"
## SDL mapping body for a wired Xbox 360 pad as the 360Controller driver exposes it on macOS.
const XBOX360_MAC_MAPPING := "a:b0,b:b1,back:b9,dpdown:b12,dpleft:b13,dpright:b14,dpup:b11,guide:b10," \
	+ "leftshoulder:b4,leftstick:b6,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5," \
	+ "rightstick:b7,righttrigger:a5,rightx:a3,righty:a4,start:b8,x:b2,y:b3"
## Name fragments reported for Xbox 360 pads and licensed third-party 360 pads.
const XBOX360_NAMES: PackedStringArray = ["xbox 360", "x360", "xbox360"]
## Name fragments SDL and macOS report for PlayStation 3 pads and common clones.
const PS3_NAMES: PackedStringArray = ["ps3", "playstation(r)3", "playstation 3", "dualshock 3", "sixaxis", "shanwan"]
## Before any pad is chosen, a stick has to move this far to choose it.
const ADOPT_AXIS := 0.5

## The joypad that last pressed a button or pushed a stick or trigger; -1 if none yet.
static var active_device := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Resolve the saved controller layout early so battle prompts read correctly.
	Bindings.layout()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_on_joy_connection_changed(device, true)


func _input(event: InputEvent) -> void:
	# _input runs before any scene's _unhandled_input, so battle scripts see the
	# new pad on the same press that picked it up.
	note_event(event)


## Records which joypad the player is using. Safe to call from tests.
static func note_event(event: InputEvent) -> void:
	# A button press switches pads. Stick motion only picks the first pad: stray HID
	# devices can send noisy axis motion and must not steal the controls.
	if event is InputEventJoypadButton and event.pressed:
		active_device = event.device
	elif event is InputEventJoypadMotion and active_device < 0 and absf(event.axis_value) >= ADOPT_AXIS:
		active_device = event.device


## The joypad to read sticks from: the one in use, else the first connected; -1 if none.
static func device() -> int:
	var connected := Input.get_connected_joypads()
	if active_device >= 0 and connected.has(active_device):
		return active_device
	return connected[0] if not connected.is_empty() else -1


static func is_playstation3(device_id: int) -> bool:
	return looks_like_playstation3(Input.get_joy_name(device_id))


static func looks_like_playstation3(joy_name: String) -> bool:
	return _matches(joy_name, PS3_NAMES)


static func is_xbox360(device_id: int) -> bool:
	return looks_like_xbox360(Input.get_joy_name(device_id))


static func looks_like_xbox360(joy_name: String) -> bool:
	return _matches(joy_name, XBOX360_NAMES)


static func _matches(joy_name: String, fragments: PackedStringArray) -> bool:
	var lowered := joy_name.to_lower()
	for fragment in fragments:
		if lowered.contains(fragment):
			return true
	return false


## One line describing a pad: name, SDL GUID and whether Godot knows its layout.
static func describe(device_id: int) -> String:
	return "%s [%s]%s" % [Input.get_joy_name(device_id), Input.get_joy_guid(device_id),
		"" if Input.is_joy_known(device_id) else " (unrecognised layout)"]


## The mapping line to apply for an unrecognised PS3 or Xbox 360 pad on macOS, or ""
## if none applies.
static func fallback_mapping(guid: String, joy_name: String, known: bool, os_name: String) -> String:
	if known or os_name != "macOS" or guid.is_empty():
		return ""
	if looks_like_playstation3(joy_name):
		return "%s,PS3 Controller,%s" % [guid, PS3_MAC_MAPPING]
	if looks_like_xbox360(joy_name):
		return "%s,Xbox 360 Controller,%s" % [guid, XBOX360_MAC_MAPPING]
	return ""


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected:
		if active_device == device_id:
			active_device = -1
		print("Controller disconnected: %d" % device_id)
		return
	var mapping := fallback_mapping(Input.get_joy_guid(device_id), Input.get_joy_name(device_id),
		Input.is_joy_known(device_id), OS.get_name())
	if not mapping.is_empty():
		Input.add_joy_mapping(mapping, true)
		print("Applied the %s layout to an unrecognised pad." % mapping.get_slice(",", 1))
	print("Controller %d connected: %s" % [device_id, describe(device_id)])
	if not Input.is_joy_known(device_id):
		push_warning("Controller '%s' has no known layout; buttons may not match the on-screen prompts." % Input.get_joy_name(device_id))
