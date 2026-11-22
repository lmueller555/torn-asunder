extends Control
## Scene-independent dialogue playback. The caller decides what completing a beat unlocks.

signal completed(beat_id: StringName)
signal cancelled(beat_id: StringName)

const GreyhollowShots := preload("res://game/greyhollow_cinematic_shots.gd")
const BACKDROP := preload("res://assets/art/vault.webp")
const DISPLAY_FACE := preload("res://assets/fonts/Cinzel.ttf")
const BODY_FACE := preload("res://assets/fonts/SourceSans3.ttf")
const IVORY := Color("#f4e8d5")
const GOLD := Color("#d9ad70")
const MUTED := Color("#b5afa2")
const BORDER := Color("#716451")
const DEFAULT_HINT := "Enter / Cross: Advance     Esc / Circle: Back"
const CINEMATIC_HINT := "Enter / Cross: Advance     Esc / Circle: Skip"
const CINEMATIC_BLACK := Color("#080a0a")

var _beat_id := &""
var _lines: Array = []
var _line_index := 0
var _active := false
var _previous_focus: Control
var _heading: Label
var _location: Label
var _portrait: TextureRect
var _portrait_fallback: Label
var _speaker: Label
var _body: Label
var _scroll: ScrollContainer
var _counter: Label
var _advance_button: Button
var _back_button: Button
var _cinematic := false
var _reduced_motion := false
var _cinematic_shots: GreyhollowShots
var _shot_cover: ColorRect
var _shot_fade: Tween
var _portrait_frame: PanelContainer


func _ready() -> void:
	hide()
	_build()


# Call after adding the scene to the tree. A currently playing scene is not replaced.
func present(beat_id: StringName, content: Dictionary, reduced_motion := false, skippable := false) -> bool:
	if not is_node_ready() or _active or beat_id == &"" or not _valid_content(content):
		return false
	_beat_id = beat_id
	_lines = content.lines.duplicate(true)
	_line_index = 0
	_active = true
	_previous_focus = get_viewport().gui_get_focus_owner()
	_reduced_motion = reduced_motion
	var cinematic := StringName(content.get("presentation", &"")) == &"cinematic"
	if cinematic != _cinematic:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_cinematic = cinematic
		if _cinematic:
			_build_cinematic()
		else:
			_build()
	if _cinematic:
		_configure_cinematic(content)
	_back_button.text = "Skip Scene" if _cinematic or skippable else "Back"
	_heading.text = content.title
	_location.text = content.location
	show()
	_render_line()
	_advance_button.grab_focus()
	return true


func advance() -> void:
	if not _active:
		return
	if _line_index == _lines.size() - 1:
		_close(true)
		return
	_line_index += 1
	_render_line()


func cancel() -> void:
	if _active:
		_close(false)


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree():
		return
	var forwards := false
	var backwards := false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var key: Key = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
		forwards = key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		backwards = key == KEY_ESCAPE
	elif event is InputEventJoypadButton:
		forwards = event.button_index == JOY_BUTTON_A # DualSense Cross
		backwards = event.button_index == JOY_BUTTON_B # DualSense Circle
	if backwards or forwards:
		# Handle once, rather than also sending the action to the focused button.
		get_viewport().set_input_as_handled()
		if not event.is_pressed() or event.is_echo():
			return
		# Preserve explicit Back selection when tabbing or using directional focus.
		if backwards or get_viewport().gui_get_focus_owner() == _back_button:
			cancel()
		else:
			advance()


func _valid_content(content: Dictionary) -> bool:
	if not _has_text(content.get("title")) or not _has_text(content.get("location")):
		return false
	var presentation: Variant = content.get("presentation", &"")
	if not (presentation is String or presentation is StringName) or StringName(presentation) not in [&"", &"cinematic"]:
		return false
	var setting: Variant = content.get("setting", &"")
	if not (setting is String or setting is StringName) or StringName(setting) not in [&"", &"greyhollow"]:
		return false
	if StringName(setting) != &"" and StringName(presentation) != &"cinematic":
		return false
	var lines: Variant = content.get("lines")
	if not lines is Array or lines.is_empty():
		return false
	for line in lines:
		if not line is Dictionary or not _has_text(line.get("speaker")) or not _has_text(line.get("text")):
			return false
		var portrait: Variant = line.get("portrait")
		if portrait != null and not portrait is Texture2D:
			return false
		if line.has("action") and not line.action is bool:
			return false
		if line.has("shot"):
			var shot: Variant = line.shot
			if StringName(setting) != &"greyhollow" or not (shot is String or shot is StringName):
				return false
			if not GreyhollowShots.supports(StringName(shot)):
				return false
	return true


func _has_text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


func _render_line() -> void:
	var line: Dictionary = _lines[_line_index]
	_speaker.text = line.speaker
	_body.text = line.text
	_portrait.texture = line.get("portrait")
	_portrait.visible = _portrait.texture != null
	_portrait_fallback.visible = not _portrait.visible
	_portrait_fallback.text = line.speaker.get_slice(" ", 0).substr(0, 1).to_upper()
	if _cinematic:
		_render_cinematic_line(line)
	_scroll.scroll_vertical = 0
	_counter.text = "%02d / %02d" % [_line_index + 1, _lines.size()]
	_advance_button.text = "Finish" if _line_index == _lines.size() - 1 else "Continue"


func _close(finished: bool) -> void:
	var id := _beat_id
	_active = false
	_beat_id = &""
	_lines.clear()
	if _cinematic:
		if _shot_fade and _shot_fade.is_valid():
			_shot_fade.kill()
		_clear_cinematic_shots()
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	if finished:
		completed.emit(id)
	else:
		cancelled.emit(id)


func _build() -> void:
	theme = Theme.new()
	theme.default_font = BODY_FACE
	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.024, 0.78)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchor(SIDE_LEFT, 0.09)
	panel.set_anchor(SIDE_RIGHT, 0.91)
	panel.set_anchor(SIDE_TOP, 0.12)
	panel.set_anchor(SIDE_BOTTOM, 0.88)
	panel.add_theme_stylebox_override("panel", _style(Color("#171a1a"), BORDER, 30.0))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_location = _label(column, "DialogueLocation", "", 20, GOLD)
	_heading = _label(column, "DialogueTitle", "", 36, IVORY, DISPLAY_FACE)
	column.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 36)
	column.add_child(row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(254, 300)
	portrait_frame.add_theme_stylebox_override("panel", _style(Color("#242824"), BORDER, 1.0))
	row.add_child(portrait_frame)
	_portrait_fallback = _label(portrait_frame, "PortraitFallback", "", 76, BORDER, DISPLAY_FACE)
	_portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait = TextureRect.new()
	_portrait.name = "SpeakerPortrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_portrait)

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 13)
	row.add_child(words)
	_speaker = _label(words, "SpeakerName", "", 27, GOLD, DISPLAY_FACE)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	words.add_child(_scroll)
	_body = _label(_scroll, "DialogueLine", "", 29, IVORY)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 7)

	column.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_counter = _label(footer, "LineCounter", "", 22, GOLD)
	_counter.custom_minimum_size.x = 100
	var hint := _label(footer, "InputHint", DEFAULT_HINT, 18, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button = _button("BackButton", "Back", cancel)
	footer.add_child(_back_button)
	_advance_button = _button("AdvanceButton", "Continue", advance)
	footer.add_child(_advance_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_advance_button)
	_advance_button.focus_neighbor_left = _advance_button.get_path_to(_back_button)


func _build_cinematic() -> void:
	# The film window and subtitles are separate. Darkness never fades the controls or text.
	var picture := ColorRect.new()
	picture.color = CINEMATIC_BLACK
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.name = "CinematicPicture"
	add_child(picture)
	_place(picture, Rect2(0.0, 0.136, 1.0, 0.519))
	_shot_cover = ColorRect.new()
	_shot_cover.name = "CinematicFade"
	_shot_cover.color = CINEMATIC_BLACK
	_shot_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(_shot_cover)
	_shot_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame_band(Rect2(0.0, 0.0, 1.0, 0.136))
	_frame_band(Rect2(0.0, 0.655, 1.0, 0.345))
	_frame_rule(0.136)
	_frame_rule(0.655)

	var header := VBoxContainer.new()
	add_child(header)
	_place(header, Rect2(0.065, 0.023, 0.87, 0.1))
	header.add_theme_constant_override("separation", 0)
	_location = _label(header, "DialogueLocation", "", 19, GOLD)
	_heading = _label(header, "DialogueTitle", "", 34, IVORY, DISPLAY_FACE)
	_location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override("panel", _style(Color("#161b19"), BORDER, 2.0))
	add_child(_portrait_frame)
	_place(_portrait_frame, Rect2(0.065, 0.699, 0.082, 0.165))
	_portrait_fallback = _label(_portrait_frame, "PortraitFallback", "", 42, BORDER, DISPLAY_FACE)
	_portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait = TextureRect.new()
	_portrait.name = "SpeakerPortrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)

	var words := VBoxContainer.new()
	words.name = "CinematicWords"
	words.add_theme_constant_override("separation", 3)
	add_child(words)
	_place(words, Rect2(0.17, 0.674, 0.765, 0.21))
	_speaker = _label(words, "SpeakerName", "", 23, GOLD, DISPLAY_FACE)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	words.add_child(_scroll)
	_body = _label(_scroll, "DialogueLine", "", 30, IVORY)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	add_child(footer)
	_place(footer, Rect2(0.065, 0.913, 0.87, 0.06))
	_counter = _label(footer, "LineCounter", "", 19, GOLD)
	_counter.custom_minimum_size.x = 100
	var hint := _label(footer, "InputHint", CINEMATIC_HINT, 18, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button = _button("BackButton", "Skip Scene", cancel)
	footer.add_child(_back_button)
	_advance_button = _button("AdvanceButton", "Continue", advance)
	footer.add_child(_advance_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_advance_button)
	_advance_button.focus_neighbor_left = _advance_button.get_path_to(_back_button)


func _configure_cinematic(content: Dictionary) -> void:
	if StringName(content.get("setting", &"")) != &"greyhollow":
		return
	_cinematic_shots = GreyhollowShots.new()
	var picture := _shot_cover.get_parent() as Control
	picture.add_child(_cinematic_shots)
	picture.move_child(_cinematic_shots, 0)
	_cinematic_shots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _render_cinematic_line(line: Dictionary) -> void:
	var is_action: bool = line.get("action", false)
	_portrait_frame.visible = _portrait.visible and not is_action
	var words := _speaker.get_parent() as Control
	words.set_anchor(SIDE_LEFT, 0.17 if _portrait_frame.visible else 0.065, true)
	_speaker.add_theme_color_override("font_color", MUTED if is_action else GOLD)
	_body.add_theme_font_size_override("font_size", 28 if is_action else 30)
	var cut := _cinematic_shots != null and _cinematic_shots.frame(StringName(line.get("shot", &"outlet")))
	if _reduced_motion or _cinematic_shots == null:
		_shot_cover.modulate.a = 0.0
	elif cut or _line_index == 0:
		if _shot_fade and _shot_fade.is_valid():
			_shot_fade.kill()
		_shot_cover.modulate.a = 1.0
		_shot_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_shot_fade.tween_property(_shot_cover, "modulate:a", 0.0, 0.33 if _line_index == 0 else 0.22)


func _clear_cinematic_shots() -> void:
	if is_instance_valid(_cinematic_shots):
		_cinematic_shots.get_parent().remove_child(_cinematic_shots)
		_cinematic_shots.queue_free()
		_cinematic_shots = null


func _frame_band(bounds: Rect2) -> void:
	var band := ColorRect.new()
	band.color = CINEMATIC_BLACK
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_place(band, bounds)


func _frame_rule(y: float) -> void:
	var rule := ColorRect.new()
	rule.color = Color("#393327")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	_place(rule, Rect2(0.0, y, 1.0, 0.0014))


func _place(control: Control, bounds: Rect2) -> void:
	control.set_anchor(SIDE_LEFT, bounds.position.x, true)
	control.set_anchor(SIDE_TOP, bounds.position.y, true)
	control.set_anchor(SIDE_RIGHT, bounds.end.x, true)
	control.set_anchor(SIDE_BOTTOM, bounds.end.y, true)


func _label(parent: Control, node_name: String, text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label


func _button(node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(147, 49)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_stylebox_override("normal", _style(Color("#222524"), BORDER, 7.0))
	button.add_theme_stylebox_override("hover", _style(Color("#363028"), GOLD, 7.0))
	button.add_theme_stylebox_override("pressed", _style(Color("#443626"), GOLD, 7.0))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 7.0, 2))
	button.pressed.connect(callback)
	return button


func _style(fill: Color, border: Color, margin: float, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, margin)
	return style
