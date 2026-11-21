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
## - Logs each controller as it connects, for checking a pad on a new machine.
##
## The state is static, so scripts that only preload this file (and headless tests,
## which run without the autoload) can still query it.

## SDL mapping body for a DualShock 3 seen as a raw HID device on macOS. The button
## numbers follow the DS3's own HID report order (Select, L3, R3, Start, D-pad
## up/right/down/left, L2, R2, L1, R1, Triangle, Circle, Cross, Square, PS).
const PS3_MAC_MAPPING := "a:b14,b:b13,back:b0,dpdown:b6,dpleft:b7,dpright:b5,dpup:b4,guide:b16," \
	+ "leftshoulder:b10,leftstick:b1,lefttrigger:b8,leftx:a0,lefty:a1,rightshoulder:b11," \
	+ "rightstick:b2,righttrigger:b9,rightx:a2,righty:a3,start:b3,x:b15,y:b12"
## Name fragments SDL and macOS report for PlayStation 3 pads and common clones.
const PS3_NAMES: PackedStringArray = ["ps3", "playstation(r)3", "playstation 3", "dualshock 3", "sixaxis", "shanwan"]
## Before any pad is chosen, a stick has to move this far to choose it.
const ADOPT_AXIS := 0.5

## The joypad that last pressed a button or pushed a stick or trigger; -1 if none yet.
static var active_device := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var lowered := joy_name.to_lower()
	for fragment in PS3_NAMES:
		if lowered.contains(fragment):
			return true
	return false


## One line describing a pad: name, SDL GUID and whether Godot knows its layout.
static func describe(device_id: int) -> String:
	return "%s [%s]%s" % [Input.get_joy_name(device_id), Input.get_joy_guid(device_id),
		"" if Input.is_joy_known(device_id) else " (unrecognised layout)"]


## The mapping line to apply for an unrecognised PS3 pad on macOS, or "" if none applies.
static func fallback_mapping(guid: String, joy_name: String, known: bool, os_name: String) -> String:
	if known or os_name != "macOS" or guid.is_empty() or not looks_like_playstation3(joy_name):
		return ""
	return "%s,PS3 Controller,%s" % [guid, PS3_MAC_MAPPING]


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
		print("Applied the PlayStation 3 layout to an unrecognised pad.")
	print("Controller %d connected: %s" % [device_id, describe(device_id)])
	if not Input.is_joy_known(device_id):
		push_warning("Controller '%s' has no known layout; buttons may not match the on-screen prompts." % Input.get_joy_name(device_id))
