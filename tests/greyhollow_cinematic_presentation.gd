extends SceneTree

const PanelScene := preload("res://game/campaign_dialogue.tscn")
const Portrait := preload("res://assets/art/mara.webp")
const BEAT := &"cinematic_fixture"
const FIXTURE := {
	"title": "After the rescue",
	"location": "Greyhollow",
	"presentation": &"cinematic",
	"setting": &"greyhollow",
	"lines": [
		{"speaker": "At the shelter", "action": true, "text": "A worker comes in from the cold."},
		{"speaker": "King Mara Halden", "text": "What did you find?", "portrait": Portrait, "shot": &"shelter_detail"},
		{"speaker": "At the shelter", "action": true, "text": "The worker opens a bundle.", "shot": &"black"},
	],
}
var _dialogue: Control
var _completed: Array[StringName] = []
var _cancelled: Array[StringName] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var underlying := Button.new()
	underlying.text = "Return focus here"
	root.add_child(underlying)
	underlying.grab_focus()
	_dialogue = PanelScene.instantiate()
	root.add_child(_dialogue)
	_dialogue.completed.connect(func(id: StringName) -> void: _completed.append(id))
	_dialogue.cancelled.connect(func(id: StringName) -> void: _cancelled.append(id))
	var bad := FIXTURE.duplicate(true)
	bad.lines[0].shot = &"bad-shot"
	_check(not _dialogue.present(BEAT, bad) and not _dialogue.visible, "Unknown camera tracks must not enter playback.")
	_check(_dialogue.present(BEAT, FIXTURE), "The opt-in cinematic does not start.")
	var original_set: WeakRef = weakref(_node("GreyhollowSet"))
	var set_view := original_set.get_ref() as SubViewport
	_check(set_view != null and set_view.own_world_3d and set_view.gui_disable_input, "The set must use its own isolated viewport.")
	if set_view:
		_check(set_view.get_child(0).scene_file_path == "res://game/battlefields/year_one_mine_campaign.tscn",
			"The cinematic must use the unchanged field without a battle script or artifact prop.")
	_check(_label("DialogueLine").text == FIXTURE.lines[0].text and not _node("SpeakerPortrait").is_visible_in_tree(),
		"An action card does not show future text or a speaking portrait.")
	_check(_node("CinematicFade").modulate.a == 1.0 and root.gui_get_focus_owner() == _node("AdvanceButton"),
		"The opening fade must not block Continue focus.")
	_key(KEY_ENTER, true)
	_check(_label("LineCounter").text == "01 / 03", "Key repeat skipped the opening.")
	_key(KEY_ENTER)
	_check(_label("LineCounter").text == "02 / 03" and _label("DialogueLine").text == FIXTURE.lines[1].text
		and _node("SpeakerPortrait").is_visible_in_tree(), "The first advance does not show exactly one line and its speaker.")
	_pad(JOY_BUTTON_B)
	_check(not _dialogue.visible and _cancelled == [BEAT] and _completed.is_empty()
		and root.gui_get_focus_owner() == underlying, "Skip must close once as cancellation and restore focus.")
	await process_frame
	_check(original_set.get_ref() == null, "Skipping left the 3D viewport attached.")

	_check(_dialogue.present(BEAT, FIXTURE, true), "Reduced-motion replay does not start.")
	_check(_label("LineCounter").text == "01 / 03" and _node("CinematicFade").modulate.a == 0.0,
		"Reduced motion must immediately present the opening without a fade.")
	await process_frame
	await process_frame
	var action_left := _check_framing()
	_pad(JOY_BUTTON_A)
	_check(_label("LineCounter").text == "02 / 03" and _node("CinematicFade").modulate.a == 0.0,
		"Reduced motion must use an immediate camera cut during controller advancement.")
	await process_frame
	await process_frame
	var speaker_left := _check_framing()
	var portrait_bounds := (_node("SpeakerPortrait") as Control).get_global_rect()
	_check(speaker_left > action_left and portrait_bounds.size.x > 0.0 and portrait_bounds.end.x < speaker_left,
		"Dialogue with a visible portrait must get a padded subtitle gutter rather than cover the portrait.")
	_key(KEY_SPACE)
	_check(_label("LineCounter").text == "03 / 03" and _label("DialogueLine").text == FIXTURE.lines[2].text
		and not _node("SpeakerPortrait").is_visible_in_tree() and not _node("GreyhollowSet").get_parent().visible
		and _completed.is_empty(),
		"The reveal card must require its own explicit finish.")
	_pad(JOY_BUTTON_A)
	_dialogue.advance()
	_check(not _dialogue.visible and _completed == [BEAT] and _cancelled == [BEAT],
		"Finish must emit exactly one completion and not cancel.")

	var normal := FIXTURE.duplicate(true)
	normal.erase("presentation")
	normal.erase("setting")
	normal.lines = [{"speaker": "Guide", "text": "Ordinary campaign dialogue."}]
	_check(_dialogue.present(&"ordinary", normal) and _node("CinematicPicture") == null
		and (_node("BackButton") as Button).text == "Back" and _label("PortraitFallback").is_visible_in_tree(),
		"Cinematic playback changed the normal dialogue or left a shot behind.")
	_key(KEY_ESCAPE)
	_dialogue.queue_free()
	underlying.queue_free()
	await process_frame
	if not _failed:
		print("Verified Greyhollow cinematic framing, progression, keyboard/controller skip, reduced motion, cleanup, and normal dialogue fallback.")
	quit(1 if _failed else 0)


func _check_framing() -> float:
	var panel := _dialogue.get_global_rect()
	var top := _label("DialogueTitle").get_global_rect()
	var picture := (_node("CinematicPicture") as Control).get_global_rect()
	var words := _label("DialogueLine").get_global_rect()
	var advance := (_node("AdvanceButton") as Control).get_global_rect()
	_check(panel.has_area() and panel.encloses(top) and panel.encloses(picture)
		and panel.encloses(words) and panel.encloses(advance), "Cinematic elements overflow the dialogue panel.")
	_check(picture.size.x >= panel.size.x * 0.99 and picture.size.y > panel.size.y * 0.4
		and picture.position.y > top.end.y and words.position.y > picture.end.y and advance.position.y > words.end.y,
		"The film frame must be nonzero and below the title, followed by subtitles and controls without overlap.")
	return words.position.x


func _label(id: String) -> Label:
	return _node(id) as Label


func _node(id: String) -> Node:
	return _dialogue.find_child(id, true, false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true


func _key(key: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.echo = echo
	root.push_input(event)


func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)
