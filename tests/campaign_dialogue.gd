extends SceneTree

const PanelScene := preload("res://game/campaign_dialogue.tscn")
const Beats := preload("res://game/campaign_dialogues.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")

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
	passed = _check_other_mine_beats() and passed
	passed = _check_grain_beats() and passed
	passed = _check_high_quay_beats() and passed
	passed = _check_ilyra_moonwash_beats() and passed
	_panel.queue_free()
	_underlay.queue_free()
	await process_frame
	if passed:
		print("Verified campaign dialogue, Grain and Moonwash branches, High Quay continuity, mixed-device input, and replay.")
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


func _check_other_mine_beats() -> bool:
	var cases := [
		[Beats.RASKA_MINE_DISPATCH, Beats.RASKA, Beats.RASKA_PORTRAIT, ["let the workers through", "someone willing"]],
		[Beats.RASKA_MINE_DEBRIEF, Beats.RASKA, Beats.RASKA_PORTRAIT, ["changed your mind", "the night your river stopped", "Mara's carrier cleared the pass"]],
		[Beats.SOVA_MINE_DISPATCH, Beats.SOVA, Beats.SOVA_PORTRAIT, ["send the first group", "get them somewhere safe"]],
		[Beats.SOVA_MINE_DEBRIEF, Beats.SOVA, Beats.SOVA_PORTRAIT, ["Both groups are through the tunnels", "she went with Raska", "Mara's carrier cleared the pass", "old sealed record"]],
	]
	var start_completions := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var content := Beats.get_beat(id)
		if content.is_empty() or content.lines.size() < 3 or content.lines.size() > 5 or not _panel.present(id, content):
			return _fail("A new mine conversation had invalid content: %s" % id)
		var visible_text := ""
		var portraits := 0
		for index in range(content.lines.size()):
			visible_text += _label("DialogueLine").text + "\n"
			if _label("SpeakerName").text == fixture[1]:
				if not _portrait().visible or _portrait().texture != fixture[2]:
					return _fail("A faction leader is missing their existing portrait: %s" % id)
				portraits += 1
			if index < content.lines.size() - 1:
				_panel.advance()
		for phrase: String in fixture[3]:
			if not phrase in visible_text:
				return _fail("A mine conversation lost its required story fact: %s" % id)
		if portraits == 0 or _button("AdvanceButton").text != "Finish":
			return _fail("A beat did not show its lead speaker or reach explicit Finish: %s" % id)
		_panel.advance()
		if _completions.back() != id or _panel.visible:
			return _fail("A new beat did not complete under its own stable ID: %s" % id)
	if _completions.size() != start_completions + cases.size():
		return _fail("New beats did not send exactly one completion each.")
	return true


func _check_grain_beats() -> bool:
	var dispatch := Beats.get_beat(Beats.MARA_GRAIN_DISPATCH)
	if not _panel.present(Beats.MARA_GRAIN_DISPATCH, dispatch):
		return _fail("Grain dispatch was missing or invalid.")
	var dispatch_text := _finish_visible_beat(dispatch)
	if not "mill yard" in dispatch_text or not "lower ford" in dispatch_text or not "town store" in dispatch_text:
		return _fail("The dispatch lost a delivery destination.")
	var cases := [
		[true, false, Beats.MARA_GRAIN_SEED_DEBRIEF, ["plant the south fields", "bread cart never reached the town store"]],
		[false, true, Beats.MARA_GRAIN_BREAD_DEBRIEF, ["keep the ovens lit this week", "mill yard got no seed"]],
		[true, true, Beats.MARA_GRAIN_BOTH_DEBRIEF, ["growers are coming for their shares", "bread grain made the town store"]],
	]
	var seen := {}
	for fixture: Array in cases:
		var result := _simulate_grain_result(fixture[0], fixture[1])
		var id := Beats.grain_debrief_id(result)
		var beat := Beats.get_beat(id)
		if id != fixture[2] or seen.has(id) or not _panel.present(id, beat):
			return _fail("A real delivery result did not select its own council beat: %s" % result)
		seen[id] = true
		var account := _finish_visible_beat(beat)
		for detail: String in fixture[3]:
			if not detail in account:
				return _fail("Council testimony lost a delivered or missing load: %s" % result)
		if _completions.back() != id or not "speak to Orrun" in account:
			return _fail("A council beat changed the shared handoff or signalled the wrong completion.")
		beat.lines[0].text = ""
		if not _has_grain_source(id):
			return _fail("A retrieved council beat mutated the authored result.")
	for invalid: StringName in [_simulate_grain_result(false, false), &"mara_grain_crossing", &"BOTH", &"unknown"]:
		if Beats.grain_debrief_id(invalid) != &"" or not Beats.get_beat(Beats.grain_debrief_id(invalid)).is_empty():
			return _fail("An invalid or failed mission result selected a success debrief.")
	return true


func _simulate_grain_result(seed_delivers: bool, bread_delivers: bool) -> StringName:
	var grain := Grain.new()
	var dispatch := Grain.Observation.new()
	dispatch.seed.dispatch_ordered = true
	dispatch.bread.dispatch_ordered = true
	grain.advance(dispatch)
	var finish := Grain.Observation.new()
	finish.seed.at_receiving_yard = seed_delivers
	finish.seed.turn_back_ordered = not seed_delivers
	finish.bread.at_receiving_yard = bread_delivers
	finish.bread.turn_back_ordered = not bread_delivers
	grain.advance(finish)
	return grain.clear_result


func _finish_visible_beat(beat: Dictionary) -> String:
	var text := ""
	for index in range(beat.lines.size()):
		text += _label("DialogueLine").text + "\n"
		_panel.advance()
	return text


func _has_grain_source(id: StringName) -> bool:
	var source := Beats.get_beat(id)
	return not source.lines[0].text.is_empty()


func _check_high_quay_beats() -> bool:
	var ids: Array[StringName] = [
		Beats.MARA_WATER_REQUEST,
		Beats.MARA_HIGH_QUAY_DISPATCH,
		Beats.MARA_HIGH_QUAY_DEBRIEF,
	]
	var seen: Array[String] = []
	var start := _completions.size()
	for id in ids:
		var beat := Beats.get_beat(id)
		if beat.is_empty() or not _panel.present(id, beat):
			return _fail("A High Quay campaign beat was missing or invalid: %s" % id)
		seen.append(_finish_visible_beat(beat))
		if _panel.visible or _completions.back() != id:
			return _fail("The High Quay beat did not complete under its own stable ID: %s" % id)
	if _completions.size() != start + ids.size() or _completions.slice(start) != ids:
		return _fail("High Quay dialogue emitted duplicate or out-of-order completions.")
	if not "Whose water will fill them?" in seen[0] or not "return water to the dry headwater channels" in seen[0]:
		return _fail("The intermission lost the cautious command or its unanswered cost.")
	if not "current running inland" in seen[1] or not "upper stairs" in seen[1] or not "Leave the boats to Ilyra" in seen[1]:
		return _fail("The briefing lost the inquiry, retreat route, or independent Elven duty.")
	if not "stranded on stone" in seen[2] or not "farms on your list" in seen[2] or not "There won't be a second order" in seen[2]:
		return _fail("The final report changed the campaign's incomplete water result or Mara's refusal.")
	if "Orrun," in seen[1] or "Orrun," in seen[2]:
		return _fail("Another order was given after the shared intermission.")
	return true


func _check_ilyra_moonwash_beats() -> bool:
	var cases := [
		[Beats.ILYRA_MOONWASH_DISPATCH, ["Stone's rising under the moorings", "Godbridle", "we're staying"]],
		[Beats.moonwash_debrief_id(_simulate_moonwash_result(true)), ["Both crews are aboard", "provision a few survey boats ourselves", "Sova's public account"]],
		[Beats.moonwash_debrief_id(_simulate_moonwash_result(false)), ["Both crews are aboard", "fishing villages lend us stores", "Sova read the sealed record in public"]],
	]
	var start := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if id == &"" or not _panel.present(id, beat):
			return _fail("An Ilyra rescue beat was missing or invalid: %s" % id)
		var spoken := ""
		var portrait_seen := false
		for index in range(beat.lines.size()):
			spoken += _label("DialogueLine").text + "\n"
			if _label("SpeakerName").text == Beats.ILYRA:
				portrait_seen = _portrait().visible and _portrait().texture == Beats.ILYRA_PORTRAIT
				if not portrait_seen:
					return _fail("Ilyra's existing portrait did not show in her rescue beat.")
			_panel.advance()
		for detail: String in fixture[1]:
			if not detail in spoken:
				return _fail("Moonwash dialogue lost a rescue or survey consequence: %s" % id)
		if not portrait_seen or _completions.back() != id or _panel.visible:
			return _fail("Ilyra's beat did not complete under its own ID: %s" % id)
	if _completions.size() != start + cases.size() or cases[1][0] == cases[2][0]:
		return _fail("Rescue result beats duplicated or collapsed into the same branch.")
	for invalid: StringName in [_simulate_moonwash_result(true, true), &"failed", &"both", &"unknown"]:
		if Beats.moonwash_debrief_id(invalid) != &"":
			return _fail("An invalid rescue outcome selected a successful debrief.")
	return true


func _simulate_moonwash_result(cargo: bool, hero_falls := false) -> StringName:
	var rescue := Moonwash.new()
	for transfer in [Moonwash.Transfer.FORWARD, Moonwash.Transfer.AFT]:
		var rig := Moonwash.Observation.new()
		rig.hero_rigged_transfer = transfer
		rescue.advance(rig)
	var arrival := Moonwash.Observation.new()
	arrival.forward.crew_at_receiving_deck = true
	arrival.aft.crew_at_receiving_deck = true
	arrival.cargo_at_receiving_deck = cargo
	arrival.hero_fell = hero_falls
	rescue.advance(arrival)
	return rescue.clear_result


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
