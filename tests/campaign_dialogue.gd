extends SceneTree

const PanelScene := preload("res://game/campaign_dialogue.tscn")
const Beats := preload("res://game/campaign_dialogues.gd")

var _panel: Control
var _underlay: Button
var _completions: Array[StringName] = []
var _cancellations: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_underlay = Button.new()
	_underlay.text = "Underlying route"
	root.add_child(_underlay)
	_underlay.grab_focus()
	_panel = PanelScene.instantiate()
	root.add_child(_panel)
	_panel.completed.connect(func(id: StringName) -> void: _completions.append(id))
	_panel.cancelled.connect(func(id: StringName) -> void: _cancellations.append(id))
	var passed := _check_authoring_and_invalid_data()
	passed = (await _check_advancement()) and passed
	passed = _check_cancellation_and_replay() and passed
	_panel.queue_free()
	_underlay.queue_free()
	await process_frame
	if passed:
		print("Verified campaign dialogue content, mixed-device input, explicit completion, cancel, and fresh replay.")
	quit(0 if passed else 1)


func _check_authoring_and_invalid_data() -> bool:
	var dispatch := Beats.get_beat(Beats.MARA_MINE_DISPATCH)
	var debrief := Beats.get_beat(Beats.MARA_MINE_DEBRIEF)
	if dispatch.lines.size() != 4 or debrief.lines.size() != 4 or not Beats.get_beat(&"missing").is_empty():
		return _fail("The dialogue catalog did not return the two intended standalone beats.")
	var first_line: String = dispatch.lines[0].text
	dispatch.lines[0].text = "Do not leak this edit."
	if Beats.get_beat(Beats.MARA_MINE_DISPATCH).lines[0].text != first_line:
		return _fail("A caller could mutate the authored dialogue for later replays.")
	var invalid_beats := [
		{},
		{"title": "Empty", "location": "Here", "lines": []},
		{"title": "  ", "location": "Here", "lines": [{"speaker": "Name", "text": "Line"}]},
		{"title": "Invalid line type", "location": "Here", "lines": [27]},
		{"title": "Missing speaker", "location": "Here", "lines": [{"text": "Line"}]},
		{"title": "Invalid portrait", "location": "Here", "lines": [{"speaker": "Name", "text": "Line", "portrait": "fake"}]},
	]
	for beat: Dictionary in invalid_beats:
		if _panel.present(&"invalid", beat):
			return _fail("Malformed dialogue entered playback.")
	if _panel.present(&"", debrief) or _panel.visible or not _completions.is_empty() or not _cancellations.is_empty():
		return _fail("Invalid dialogue became visible or emitted an outcome.")
	return true


func _check_advancement() -> bool:
	var id := Beats.MARA_MINE_DISPATCH
	var content := Beats.get_beat(id)
	if not _panel.present(id, content):
		return _fail("Valid dispatch did not open.")
	var original_text: String = content.lines[0].text
	content.lines[0].text = "Mutated copy after presenting."
	if _label("DialogueLine").text != original_text or root.gui_get_focus_owner() != _button("AdvanceButton"):
		return _fail("Opening the panel misrendered the first line or failed to focus Continue.")
	if _panel.present(Beats.MARA_MINE_DEBRIEF, Beats.get_beat(Beats.MARA_MINE_DEBRIEF)):
		return _fail("A second presentation silently replaced the playing beat.")
	if not _label("PortraitFallback").visible or _portrait().visible:
		return _fail("A speaker without an asset did not get a fallback.")
	_send_key(KEY_ENTER, true)
	if not _at_line("01 / 04"):
		return _fail("A held-key repeat advanced the scene.")
	_send_key(KEY_ENTER)
	if not _at_line("02 / 04") or _label("SpeakerName").text != "King Mara Halden":
		return _fail("Enter skipped or failed to advance the dialogue by one line.")
	if not _portrait().visible or not _portrait().texture or _label("PortraitFallback").visible:
		return _fail("Mara's line did not display his existing portrait.")
	_send_pad(JOY_BUTTON_A)
	if not _at_line("03 / 04"):
		return _fail("DualSense Cross did not advance exactly once.")
	await process_frame
	await process_frame
	_click(_button("AdvanceButton"))
	if not _at_line("04 / 04") or _button("AdvanceButton").text != "Finish" or not _completions.is_empty():
		return _fail("Clicking Continue skipped the last line or completed without an explicit Finish.")
	_send_key(KEY_SPACE)
	_panel.advance()
	_panel.cancel()
	if _panel.visible or _completions != [id] or not _cancellations.is_empty():
		return _fail("Finish failed to emit exactly one completion for the active beat.")
	if root.gui_get_focus_owner() != _underlay:
		return _fail("Closing the overlay did not restore underlying focus.")
	return true


func _check_cancellation_and_replay() -> bool:
	var id := Beats.MARA_MINE_DEBRIEF
	for use_pad in [true, false]:
		if not _panel.present(id, Beats.get_beat(id)) or not _at_line("01 / 04"):
			return _fail("A debrief replay did not restart from the first line.")
		if not "None of the miners came with us" in _label("DialogueLine").text:
			return _fail("The debrief lost the current campaign outcome.")
		_send_pad(JOY_BUTTON_A)
		if use_pad:
			_send_pad(JOY_BUTTON_B)
		else:
			_send_key(KEY_ESCAPE)
		_panel.cancel()
		_panel.advance()
		if _panel.visible or _completions.size() != 1:
			return _fail("Cancel was treated as a completed debrief.")
	if _cancellations != [id, id]:
		return _fail("Escape and Circle did not emit exactly one cancel each.")
	if not _panel.present(id, Beats.get_beat(id)):
		return _fail("A cancelled beat could not be replayed.")
	_button("BackButton").grab_focus()
	_send_key(KEY_ENTER)
	if _panel.visible or _cancellations != [id, id, id]:
		return _fail("Keyboard activation of the selected Back button advanced instead.")
	return true


func _send_key(key_code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code
	event.pressed = true
	event.echo = echo
	root.push_input(event)


func _send_pad(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	root.push_input(event)


func _click(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = pressed
		root.push_input(event, true)


func _at_line(counter: String) -> bool:
	return _label("LineCounter").text == counter


func _button(id: String) -> Button:
	return _panel.find_child(id, true, false) as Button


func _label(id: String) -> Label:
	return _panel.find_child(id, true, false) as Label


func _portrait() -> TextureRect:
	return _panel.find_child("SpeakerPortrait", true, false) as TextureRect


func _fail(message: String) -> bool:
	push_error(message)
	return false
