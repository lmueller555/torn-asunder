extends SceneTree

const PanelScene := preload("res://game/campaign_dialogue.tscn")
const Beats := preload("res://game/campaign_dialogues.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const Survey := preload("res://game/battlefield/ilyra_coast_survey.gd")

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
	passed = _check_ilyra_coast_survey_beats() and passed
	passed = _check_ilyra_spanwater_beats() and passed
	passed = _check_raska_well_road_beats() and passed
	passed = _check_raska_spanwater_beats() and passed
	passed = _check_sova_public_record_beats() and passed
	passed = _check_sova_vault_return_beats() and passed
	passed = _check_neris_beats() and passed
	passed = _check_neris_passage_beats() and passed
	passed = _check_sereth_cut_beats() and passed
	passed = _check_sereth_pass_writ_beats() and passed
	passed = _check_sereth_no_proxy_beats() and passed
	_panel.queue_free()
	_underlay.queue_free()
	await process_frame
	if passed:
		print("Verified campaign dialogue, branching outcomes, mission continuity (including the Dryad and Undead finales), mixed-device input, and replay.")
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


func _check_ilyra_coast_survey_beats() -> bool:
	var start := _completions.size()
	var cases := [
		[Beats.ILYRA_COAST_SURVEY_DISPATCH, ["ancestral stone", "fishing inlet", "armed crews", "skirts the shoal", "inland ramp", "next pass"]],
		[Beats.ILYRA_COAST_SURVEY_BEACH_DEBRIEF, ["acknowledged both readings from the beach", "the stone and the inlet together", "Give the villages the same chart", "need boats in the shallows"]],
		[Beats.ILYRA_COAST_SURVEY_HEADLAND_DEBRIEF, ["acknowledged both readings from the high relay", "the stone and the inlet together", "The same chart for all of them", "need boats in the shallows"]],
	]
	var expected_ids: Array[StringName] = []
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		expected_ids.append(id)
		var beat := Beats.get_beat(id)
		if beat.is_empty() or not _panel.present(id, beat):
			return _fail("A Two Shorelines beat was missing or invalid: %s" % id)
		var account := ""
		var portrait_seen := false
		for index in range(beat.lines.size()):
			account += _label("DialogueLine").text + "\n"
			if _label("SpeakerName").text == Beats.ILYRA:
				if not _portrait().visible or _portrait().texture != Beats.ILYRA_PORTRAIT:
					return _fail("Ilyra's existing portrait did not show in her survey beat.")
				portrait_seen = true
			if index < beat.lines.size() - 1:
				_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[1]:
			if not phrase in account:
				return _fail("A survey beat lost its orders, relay, chart terms, or pilot offer: %s" % id)
		if not portrait_seen or _button("AdvanceButton").text != "Finish" \
				or _completions.size() != start + expected_ids.size() - 1:
			return _fail("Survey dialogue completed before the last line's Finish: %s" % id)
		_send_key(KEY_ENTER)
		if _panel.visible or _completions.back() != id:
			return _fail("Survey dialogue did not finish under its own stable ID: %s" % id)
	if _completions.slice(start) != expected_ids:
		return _fail("Survey dialogue emitted duplicate or out-of-order completions.")

	for fixture: Array in [
		[Survey.SignalSite.BEACH, Beats.ILYRA_COAST_SURVEY_BEACH_DEBRIEF],
		[Survey.SignalSite.HEADLAND, Beats.ILYRA_COAST_SURVEY_HEADLAND_DEBRIEF],
	]:
		if not _check_survey_debrief_selection(fixture[0], fixture[1]):
			return false
	return Beats.survey_debrief_id(Survey.Phase.SUCCEEDED, Survey.SignalSite.NONE) == &"" \
		or _fail("A successful phase without a retained relay selected a debrief.")


func _check_survey_debrief_selection(site: Survey.SignalSite, expected: StringName) -> bool:
	var survey := Survey.new()
	var report := Survey.Observation.new()
	report.hero_inspected_marker = true
	for reading in [Survey.Reading.FISHING_INLET, Survey.Reading.ANCESTRAL_STONE]:
		report.hero_at_reading = reading
		survey.advance(report)
	if Beats.survey_debrief_id(survey.phase, survey.signal_site) != &"":
		return _fail("Recorded readings alone picked a success debrief.")
	var relay := report.beach if site == Survey.SignalSite.BEACH else report.headland
	report.requested_signal = site
	relay.staffed = true
	relay.cutter_at_stop = true
	relay.line_of_sight_clear = true
	relay.signal_credit = 1.0
	survey.advance(report)
	if Beats.survey_debrief_id(survey.phase, survey.signal_site) != &"":
		return _fail("An unacknowledged signal at a valid relay picked a debrief.")
	relay.line_of_sight_clear = false
	survey.advance(report)
	if Beats.survey_debrief_id(survey.phase, survey.signal_site) != &"":
		return _fail("An interrupted relay picked a success debrief.")
	relay.line_of_sight_clear = true
	survey.advance(report)
	survey.advance(report)
	if Beats.survey_debrief_id(survey.phase, survey.signal_site) != expected:
		return _fail("A successful replacement signal did not select the debrief for its actual relay.")
	survey.restart()
	report.cutter_disabled = true
	survey.advance(report)
	return Beats.survey_debrief_id(survey.phase, survey.signal_site) == &"" \
		or _fail("Cutter defeat incorrectly selected a debrief.")


func _check_ilyra_spanwater_beats() -> bool:
	var cases := [
		[Beats.ILYRA_SPANWATER_DISPATCH, ["one launch at the berth", "not open the sea gate", "last departure", "hold at the outflow", "the launches stay", "near group or the far one", "past the boat exit"]],
		[Beats.ILYRA_SPANWATER_DEBRIEF, ["Both household groups are past the boat exit", "ports that ordered the pursuit have recalled their pledged ships", "one family a little farther downriver", "Only what you see change hands", "I still want our coast back"]],
	]
	var start := _completions.size()
	var ids: Array[StringName] = []
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		ids.append(id)
		if beat.is_empty() or not _panel.present(id, beat):
			return _fail("An Ilyra Spanwater beat was missing or invalid: %s" % id)
		var visible_text := ""
		var portrait_seen := false
		for index in range(beat.lines.size()):
			visible_text += _label("DialogueLine").text + "\n"
			if _label("SpeakerName").text == Beats.ILYRA:
				if not _portrait().visible or _portrait().texture != Beats.ILYRA_PORTRAIT:
					return _fail("Ilyra's existing portrait did not appear at Spanwater.")
				portrait_seen = true
			if index < beat.lines.size() - 1:
				_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[1]:
			if not phrase in visible_text:
				return _fail("Ilyra's Spanwater dialogue lost an order or an ending fact: %s" % id)
		if id == Beats.ILYRA_SPANWATER_DEBRIEF:
			for variant_fact in ["near group", "far group", "both launches", "reserve", "patrol", "Orrun,"]:
				if variant_fact in visible_text:
					return _fail("The shared Elven ending asserted a boarding order, boat count, reserve fate, or new command.")
		if not portrait_seen or _button("AdvanceButton").text != "Finish" \
				or _completions.size() != start + ids.size() - 1:
			return _fail("Ilyra's Spanwater dialogue completed before the final explicit Finish.")
		_send_key(KEY_SPACE)
		if _panel.visible or _completions.back() != id:
			return _fail("Ilyra's Spanwater beat did not finish under its own stable ID: %s" % id)
	return _completions.slice(start) == ids or _fail("Ilyra's finale emitted duplicate or out-of-order completions.")


func _check_raska_well_road_beats() -> bool:
	var cases := [
		[Beats.RASKA_WELL_ROAD_DISPATCH, ["Open the storehouse", "Give them water and seats", "The lower cart waits", "both carts through the Basin exit"]],
		[Beats.RASKA_WELL_ROAD_DEBRIEF, ["Both carts reached the Basin", "counted the last barrels", "Our pastures were on the old shore", "Not the sea"]],
	]
	var initial_count := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.is_empty() or not _panel.present(id, beat):
			return _fail("A Well Road beat was missing or invalid: %s" % id)
		var words := ""
		var portrait_seen := false
		for index in range(beat.lines.size()):
			words += _label("DialogueLine").text + "\n"
			if _label("SpeakerName").text == Beats.RASKA:
				portrait_seen = _portrait().visible and _portrait().texture == Beats.RASKA_PORTRAIT
				if not portrait_seen:
					return _fail("Raska's existing portrait did not render in a Well Road beat.")
			_panel.advance()
		for phrase: String in fixture[1]:
			if not phrase in words:
				return _fail("Well Road dialogue lost an escort requirement or consequence: %s" % id)
		if not portrait_seen or _panel.visible or _completions.back() != id:
			return _fail("Well Road dialogue did not finish under its own ID: %s" % id)
	return _completions.size() == initial_count + cases.size() or _fail("Well Road emitted duplicate completions.")


func _check_raska_spanwater_beats() -> bool:
	var cases := [
		[Beats.RASKA_SPANWATER_DISPATCH, ["spillway sends water down the old riverbed", "assembly town stands below that waterline", "counted the last barrels", "The assembly sent me for the river", "The sea gate stays shut", "our companies go home", "get to the high bank", "low crossing won't stay open"]],
		[Beats.RASKA_SPANWATER_DEBRIEF, ["Water reached the mark", "The sea gate stayed shut", "the assembly town is safe", "Boats at the low landing", "People on the feeder path", "Leave those lanes to them", "left by the causeway"]],
		[Beats.RASKA_SPANWATER_CODA, ["saw Mara hand the Godbridle to Sova", "The Elven witness saw it too", "Sova took custody", "Separate page"]],
	]
	var start := _completions.size()
	var ids: Array[StringName] = []
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		ids.append(id)
		if beat.is_empty() or not _panel.present(id, beat):
			return _fail("A Spanwater beat was missing or invalid: %s" % id)
		var words := ""
		var portrait_seen := false
		for index in range(beat.lines.size()):
			words += _label("DialogueLine").text + "\n"
			if _label("SpeakerName").text == Beats.RASKA:
				portrait_seen = _portrait().visible and _portrait().texture == Beats.RASKA_PORTRAIT
				if not portrait_seen:
					return _fail("Raska's portrait did not render at Spanwater.")
			if index < beat.lines.size() - 1:
				_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[1]:
			if not phrase in words:
				return _fail("Spanwater dialogue lost an order, cost, or witness fact: %s" % id)
		if (id != Beats.RASKA_SPANWATER_CODA and "Godbridle" in words) or "Orrun," in words:
			return _fail("Spanwater introduced a bridle action into the river operation.")
		if not portrait_seen or _button("AdvanceButton").text != "Finish" or _completions.size() != start + ids.size() - 1:
			return _fail("Spanwater completion fired before an explicit Finish: %s" % id)
		_send_key(KEY_SPACE)
		if _panel.visible or _completions.back() != id:
			return _fail("A Spanwater beat did not finish under its own ID: %s" % id)
	return _completions.slice(start) == ids or _fail("Spanwater dialogue emitted duplicate or out-of-order completions.")


func _check_sova_public_record_beats() -> bool:
	var cases := [
		[Beats.SOVA_PUBLIC_RECORD_DISPATCH, ["recessed lectern", "public scribe", "keep the exit clear", "Let them go", "all three passages"]],
		[Beats.SOVA_PUBLIC_RECORD_DEBRIEF, ["command to raise the Cairnspine", "Elven coast drowned", "Red Basin lost its sea", "I made a copy for Ilyra", "they need to be able to say no"]],
		[Beats.SOVA_GODBRIDLE_HANDOVER, ["take custody of it", "Break the seal so the witnesses can see", "not to sign away anyone's claim", "Close the case"]],
	]
	var initial_count := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.is_empty() or not _panel.present(id, beat):
			return _fail("Sova's hearing or custody beat was missing: %s" % id)
		var account := _finish_visible_beat(beat)
		for detail: String in fixture[1]:
			if not detail in account:
				return _fail("Sova's dialogue lost a hearing rule or historical fact: %s" % id)
		if "Orrun," in account or _completions.back() != id or _panel.visible:
			return _fail("A new command or incorrect completion entered Sova's hearing/custody beat.")
	var handover := Beats.get_beat(Beats.SOVA_GODBRIDLE_HANDOVER)
	var speakers: Array[String] = []
	for line: Dictionary in handover.lines:
		speakers.append(line.speaker)
	if not speakers.has(Beats.ORC_WITNESS) or not speakers.has(Beats.ELVEN_WITNESS):
		return _fail("The Year Four custody transfer lacked both witnesses.")
	return _completions.size() == initial_count + cases.size() or _fail("Sova's beats emitted duplicate completions.")


func _check_sova_vault_return_beats() -> bool:
	var cases := [
		[Beats.SOVA_VAULT_RETURN_DISPATCH, "No New Command",
			["shelf is the shorter climb", "side path bends back to the same forecourt",
				"custody terms", "I'll carry the Godbridle", "witness road open", "Clear the ring",
				"No one gives a new command"]],
		[Beats.SOVA_VAULT_RETURN_DEBRIEF, "Leave the Record Open",
			["hand you that case at Spanwater", "From the terrace", "door shut",
				"Orrun is still carrying out Mara's order", "Godbridle is back in the vault",
				"We gave no new command", "open to every valley", "reason to blame us"]],
	]
	var start := _completions.size()
	var ids: Array[StringName] = []
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.get("title", "") != fixture[1] or not "Year Five" in beat.get("location", "") or not _panel.present(id, beat):
			return _fail("The Year Five vault beat was missing, invalid, or set in the wrong year: %s" % id)
		var words := ""
		var speakers := {}
		for index in range(beat.lines.size()):
			var speaker := _label("SpeakerName").text
			words += _label("DialogueLine").text + "\n"
			speakers[speaker] = true
			if speaker == Beats.SOVA and (not _portrait().visible or _portrait().texture != Beats.SOVA_PORTRAIT):
				return _fail("Sova's portrait did not render at the vault.")
			if index < beat.lines.size() - 1:
				if index % 2 == 0:
					_send_pad(JOY_BUTTON_A)
				else:
					_send_key(KEY_ENTER)
		for phrase: String in fixture[2]:
			if not phrase in words:
				return _fail("A vault beat lost a route, custody, or consequence detail: %s" % phrase)
		if id == Beats.SOVA_VAULT_RETURN_DEBRIEF:
			for witness in [Beats.ORC_WITNESS, Beats.ELVEN_WITNESS, Beats.MARCH_WITNESS]:
				if not speakers.has(witness):
					return _fail("The return lost a witness from the separate terrace: %s" % witness)
		if not speakers.has(Beats.SOVA) or "Orrun," in words or _button("AdvanceButton").text != "Finish" or _completions.size() != start + ids.size():
			return _fail("The vault dialogue issued a command, lost Sova, or advanced without Finish.")
		_send_key(KEY_SPACE)
		if _panel.visible or _completions.back() != id:
			return _fail("The vault beat did not finish under its own ID.")
		ids.append(id)
	return _completions.slice(start) == ids or _fail("Vault dialogue emitted duplicate or out-of-order completions.")


func _check_neris_beats() -> bool:
	var cases := [
		[Beats.NERIS_FAILING_GROVE_DISPATCH, "What We Planted Here",
			["The grove said no", "keep the old feeder open", "The well is still the town's",
				"No crossing", "call the volunteers", "sunken track", "raised road"]],
		[Beats.NERIS_FAILING_GROVE_DEBRIEF, "Room for the First Tree",
			["The first tree is upright", "soil is wet", "can't fit the whole grove here today",
				"send a crew to the feeder", "Their ground is still dry", "still ask to hold it",
				"your answer about the crossing stands"]],
		[Beats.NERIS_SPANWATER_FEEDER_DISPATCH, "Water at the Town Gauge",
			["first tree is still on well water", "opening the spillway, not the sea gate",
				"full river won't help", "clear the rack", "work screen", "raised path",
				"The gauge at the town end"]],
		[Beats.NERIS_SPANWATER_FEEDER_DEBRIEF, "Take the Gauge",
			["water's at the town mark and holding", "stayed in place through the crest", "your gauge book",
				"wells stay in town hands", "nursery plot stays yours", "rack patrol after storms"]],
	]
	var start := _completions.size()
	var ids: Array[StringName] = []
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.get("title", "") != fixture[1] or not _panel.present(id, beat):
			return _fail("Neris's dialogue was missing or invalid: %s" % id)
		var spoken := ""
		var speakers := {}
		for index in range(beat.lines.size()):
			var speaker := _label("SpeakerName").text
			spoken += _label("DialogueLine").text + "\n"
			speakers[speaker] = true
			if speaker == Beats.NERIS and (not _portrait().visible or _portrait().texture != Beats.NERIS_PORTRAIT):
				return _fail("Neris's existing portrait did not render: %s" % id)
			if index < beat.lines.size() - 1:
				_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[2]:
			if not phrase in spoken:
				return _fail("A Dryad beat lost a local choice or objective: %s" % phrase)
		if not speakers.has(Beats.NERIS) or not speakers.has(Beats.GROVE_ENVOY) or not speakers.has(Beats.FEEDER_KEEPER):
			return _fail("Neris, the grove, and the town did not all speak for themselves.")
		if id == Beats.NERIS_SPANWATER_FEEDER_DEBRIEF and ("jam" in spoken or "Godbridle" in spoken or "boats" in spoken):
			return _fail("The feeder report assumed optional debris or a different campaign's outcome.")
		if "Orrun," in spoken or _button("AdvanceButton").text != "Finish" or _completions.size() != start + ids.size():
			return _fail("A Dryad beat issued a new command or skipped explicit Finish: %s" % id)
		_send_key(KEY_SPACE)
		if _panel.visible or _completions.back() != id:
			return _fail("A Dryad beat did not finish under its own ID: %s" % id)
		ids.append(id)
	return _completions.slice(start) == ids or _fail("Dryad dialogue emitted duplicate or out-of-order completions.")


func _check_neris_passage_beats() -> bool:
	var cases := [
		[Beats.NERIS_CAIRNSPINE_PASSAGE_DISPATCH, "A Road We Can Share", "Cairnspine valley assembly",
			[Beats.REFUGEE_GUIDE, Beats.NERIS, Beats.REFUGEE_GUIDE, Beats.WITNESS_GUIDE, Beats.NERIS],
			["The groves refused the crossing", "Sova has his own escort", "shelf or the side path",
				"last safe marker", "Give me a signal", "confirm each route", "volunteers hold it",
				"the terrace, not the vault gate"]],
		[Beats.NERIS_CAIRNSPINE_PASSAGE_DEBRIEF, "Room by the Stove", "Cairnspine witness terrace",
			[Beats.REFUGEE_GUIDE, Beats.WITNESS_GUIDE, Beats.NERIS, Beats.REFUGEE_GUIDE, Beats.WITNESS_GUIDE],
			["Both groups are here", "what they see at the vault, not before",
				"The last volunteers stay with the witnesses", "nursery tree still needs watering",
				"I'll ask the family", "I'll ask them while we wait"]],
	]
	var emitted := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.get("title") != fixture[1] or not beat.get("location", "").begins_with(fixture[2]) \
				or "Year Five" not in beat.location or beat.lines.size() != fixture[3].size() or not _panel.present(id, beat):
			return _fail("The independent Year Five passage beat did not open under its own ID.")
		var spoken := ""
		for index in beat.lines.size():
			var speaker: String = fixture[3][index]
			if _label("SpeakerName").text != speaker:
				return _fail("Neris and the local guides did not speak for themselves.")
			if speaker == Beats.NERIS:
				if not _portrait().visible or _portrait().texture != Beats.NERIS_PORTRAIT:
					return _fail("Neris did not reuse her existing portrait.")
			elif _portrait().visible or not _label("PortraitFallback").visible:
				return _fail("A local guide did not use the existing dialogue fallback.")
			spoken += _label("DialogueLine").text + "\n"
			if index < beat.lines.size() - 1:
				_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[4]:
			if phrase not in spoken:
				return _fail("The passage dialogue lost a local choice or escort instruction: " + phrase)
		if id == Beats.NERIS_CAIRNSPINE_PASSAGE_DEBRIEF:
			for assumption in ["closed the vault", "returned the bridle", "Orrun", "Sereth", "the shelf", "the side path"]:
				if assumption in spoken:
					return _fail("The passage debrief purported to know another outcome or a specific winning route.")
		if _button("AdvanceButton").text != "Finish" or _completions.size() != emitted:
			return _fail("A passage beat skipped explicit Finish.")
		_send_key(KEY_SPACE)
		emitted += 1
		if _panel.visible or _completions.size() != emitted or _completions.back() != id:
			return _fail("A passage beat did not complete once and under its own ID.")
	return true


func _check_sereth_cut_beats() -> bool:
	var dispatch := Beats.get_beat(Beats.SERETH_CUT_DISPATCH)
	var debrief := Beats.get_beat(Beats.SERETH_CUT_DEBRIEF)
	if dispatch.get("title", "") != "Before Anyone Writes It Down" or debrief.get("title", "") != "In Her Own Words":
		return _fail("Sereth's independent dispatch and debrief were missing.")
	var cases := [
		[Beats.SERETH_CUT_DISPATCH, dispatch, [Beats.VILLAGE_CLERK, Beats.HOUSEHOLD_GUARD, Beats.SERETH, Beats.VILLAGE_CLERK, Beats.SERETH]],
		[Beats.SERETH_CUT_DEBRIEF, debrief, [Beats.IREN, Beats.VILLAGE_CLERK, Beats.SERETH, Beats.VILLAGE_CLERK, Beats.SERETH]],
	]
	var completions := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat: Dictionary = fixture[1]
		var speakers: Array = fixture[2]
		if "Year Three" not in beat.get("location", "") or beat.lines.size() != speakers.size() \
				or not _panel.present(id, beat):
			return _fail("Sereth's Year Three beat did not open under its own ID: %s" % id)
		for index in range(speakers.size()):
			if _label("SpeakerName").text != speakers[index]:
				return _fail("The records and the witness's testimony gained the wrong speaker: %s" % id)
			var is_sereth: bool = speakers[index] == Beats.SERETH
			if _portrait().visible != is_sereth or _label("PortraitFallback").visible == is_sereth \
					or (is_sereth and _portrait().texture != Beats.SERETH_PORTRAIT):
				return _fail("The panel gave a voice or civilian an invented portrait, or lost Sereth's.")
			if index < speakers.size() - 1:
				if index % 2 == 0:
					_send_pad(JOY_BUTTON_A)
				else:
					_send_key(KEY_ENTER)
		if _button("AdvanceButton").text != "Finish" or not _panel.visible:
			return _fail("Sereth's beat closed before explicitly finishing.")
		_send_key(KEY_SPACE)
		if _panel.visible or _completions.back() != id:
			return _fail("Sereth's beat did not complete exactly once under its own ID: %s" % id)

	if _completions.slice(completions) != [Beats.SERETH_CUT_DISPATCH, Beats.SERETH_CUT_DEBRIEF]:
		return _fail("Sereth's dialogue completion order or count changed.")
	return ("account book" in dispatch.lines[3].text and "even if the papers aren't here yet" in dispatch.lines[3].text
		and "I'll sign that much" in debrief.lines[0].text and "I recognized the voice" in debrief.lines[0].text
		and "own entry in the register" in debrief.lines[1].text and "Seal the bundle for cataloging" in debrief.lines[2].text
		and "doesn't tell us who wants to return" in debrief.lines[2].text and "secure the Godbridle" in debrief.lines[3].text
		and "If you come across a letter" in debrief.lines[4].text) \
		or _fail("The cut beats lost Iren's agency, ambiguity, separate written records, or the unchanged commission.")


func _check_sereth_pass_writ_beats() -> bool:
	var cases := [
		[Beats.SERETH_PASS_WRIT_DISPATCH, "An Audience, Not a Seizure", "Cairnspine west road",
			[Beats.COURT_COURIER, Beats.SERETH, Beats.HOUSEHOLD_GUARD, Beats.SERETH, Beats.COURT_COURIER],
			["Mara has handed the bridle to Sova", "take the writ to the Keeper myself",
				"screen the open road or take the sheep track on foot", "a lookout", "Keep the post clear",
				"wait for an answer", "west rally", "Don't chase the riders"]],
		[Beats.SERETH_PASS_WRIT_DEBRIEF, "A Hearing Only", "Cairnspine west rally",
			[Beats.HOUSEHOLD_GUARD, Beats.SERETH, Beats.COURT_COURIER, Beats.SERETH, Beats.COURT_COURIER],
			["a hearing only, at the valley assembly", "I countersigned those terms", "The Keeper's name and yours",
				"No entry to the vault", "No right to take or use the bridle", "neither signature can answer for the dead",
				"they may send someone to be heard"]],
	]
	var emitted := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.get("title") != fixture[1] or not beat.get("location", "").begins_with(fixture[2]) \
				or "Year Four" not in beat.location or beat.lines.size() != fixture[3].size() or not _panel.present(id, beat):
			return _fail("Sereth's Year Four dialogue did not open separately under its own ID.")
		var spoken := ""
		for index in beat.lines.size():
			var speaker: String = fixture[3][index]
			if _label("SpeakerName").text != speaker:
				return _fail("The writ dialogue gave an order or testimony to the wrong speaker.")
			if speaker == Beats.SERETH:
				if not _portrait().visible or _portrait().texture != Beats.SERETH_PORTRAIT:
					return _fail("Sereth did not reuse his existing portrait.")
			elif _portrait().visible or not _label("PortraitFallback").visible:
				return _fail("The guard or courier did not use the existing text fallback.")
			spoken += _label("DialogueLine").text + "\n"
			if index < beat.lines.size() - 1:
				_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[4]:
			if phrase not in spoken:
				return _fail("The writ dialogue lost a route-independent term or instruction: " + phrase)
		if id == Beats.SERETH_PASS_WRIT_DEBRIEF:
			for assumption in ["riders", "reserve", "sheep track", "Orrun", "letter", "handed you the bridle"]:
				if assumption in spoken:
					return _fail("The debrief presumed a route, a reserve encounter, or a later outcome.")
		if _button("AdvanceButton").text != "Finish" or _completions.size() != emitted:
			return _fail("A writ beat skipped explicit Finish.")
		_send_key(KEY_SPACE)
		emitted += 1
		if _panel.visible or _completions.size() != emitted or _completions.back() != id:
			return _fail("A writ beat did not complete once under its own ID.")
	return true


func _check_sereth_no_proxy_beats() -> bool:
	var cases := [
		[Beats.SERETH_NO_PROXY_DISPATCH, "The Lamp in the Window", "Cairnspine valley assembly",
			[Beats.VILLAGE_CLERK, Beats.SERETH, Beats.COURT_SPEAKER, Beats.SERETH, Beats.HOUSEHOLD_GUARD],
			["cataloging the bundle", "My sister wrote", "leave a lamp in the window", "That's all she asks",
				"those who left no wishes", "granted a hearing here", "where the witnesses can hear it",
				"If you refuse", "The household stays with you", "shelf and the side path"]],
		[Beats.SERETH_NO_PROXY_DEBRIEF, "What She Asked", "Cairnspine terrace approach",
			[Beats.HOUSEHOLD_GUARD, Beats.COURT_COURIER, Beats.SERETH_VALE, Beats.AT_SERETHS_WINDOW],
			["didn't cross the custody line", "The rival company pulled back", "can use the approach",
				"Your commission is revoked", "Let the witnesses go on", "Sereth lights a lamp",
				"leaves it beside the lamp"]],
	]
	var start := _completions.size()
	for fixture: Array in cases:
		var id: StringName = fixture[0]
		var beat := Beats.get_beat(id)
		if beat.get("title") != fixture[1] or not beat.get("location", "").begins_with(fixture[2]) \
				or "Year Five" not in beat.location or beat.lines.size() != fixture[3].size() or not _panel.present(id, beat):
			return _fail("Sereth's Year Five beat did not open under its own ID.")
		var spoken := ""
		for index in beat.lines.size():
			var speaker: String = fixture[3][index]
			if _label("SpeakerName").text != speaker:
				return _fail("Sereth's finale gave an action or testimony to the wrong speaker.")
			if speaker in [Beats.SERETH, Beats.SERETH_VALE]:
				if not _portrait().visible or _portrait().texture != Beats.SERETH_PORTRAIT:
					return _fail("The commission changed Sereth's portrait rather than his title.")
			elif _portrait().visible or not _label("PortraitFallback").visible:
				return _fail("The finale added a portrait for a different person or the later coda.")
			spoken += _label("DialogueLine").text + "\n"
			if index < beat.lines.size() - 1:
				if index % 2 == 0:
					_send_key(KEY_ENTER)
				else:
					_send_pad(JOY_BUTTON_A)
		for phrase: String in fixture[4]:
			if phrase not in spoken:
				return _fail("Sereth's finale lost an objective or consequence: " + phrase)
		if id == Beats.SERETH_NO_PROXY_DEBRIEF:
			for other_claim in ["Orrun", "the vault is closed", "we delivered the witnesses", "shelf", "side path", "a voice answered"]:
				if other_claim in spoken:
					return _fail("The win assumed a route, supernatural answer, or somebody else's victory.")
		if _button("AdvanceButton").text != "Finish" or not _panel.visible:
			return _fail("A finale beat skipped explicit Finish.")
		_send_key(KEY_SPACE)
		if _panel.visible or _completions.back() != id:
			return _fail("The finale beat did not complete under its authored ID.")
	return _completions.slice(start) == [Beats.SERETH_NO_PROXY_DISPATCH, Beats.SERETH_NO_PROXY_DEBRIEF] \
		or _fail("The finale duplicated or reordered dialogue completion.")


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
