extends Control
## Scene-independent dialogue playback. The caller decides what completing a beat unlocks.

signal completed(beat_id: StringName)
signal cancelled(beat_id: StringName)

const BACKDROP := preload("res://assets/art/vault.webp")
const DISPLAY_FACE := preload("res://assets/fonts/Cinzel.ttf")
const BODY_FACE := preload("res://assets/fonts/SourceSans3.ttf")
const IVORY := Color("#f4e8d5")
const GOLD := Color("#d9ad70")
const MUTED := Color("#b5afa2")
const BORDER := Color("#716451")

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


func _ready() -> void:
	hide()
	_build()


# Call after adding the scene to the tree. A currently playing scene is not replaced.
func present(beat_id: StringName, content: Dictionary) -> bool:
	if not is_node_ready() or _active or beat_id == &"" or not _valid_content(content):
		return false
	_beat_id = beat_id
	_lines = content.lines.duplicate(true)
	_line_index = 0
	_active = true
	_previous_focus = get_viewport().gui_get_focus_owner()
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
	var lines: Variant = content.get("lines")
	if not lines is Array or lines.is_empty():
		return false
	for line in lines:
		if not line is Dictionary or not _has_text(line.get("speaker")) or not _has_text(line.get("text")):
			return false
		var portrait: Variant = line.get("portrait")
		if portrait != null and not portrait is Texture2D:
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
	_scroll.scroll_vertical = 0
	_counter.text = "%02d / %02d" % [_line_index + 1, _lines.size()]
	_advance_button.text = "Finish" if _line_index == _lines.size() - 1 else "Continue"


func _close(finished: bool) -> void:
	var id := _beat_id
	_active = false
	_beat_id = &""
	_lines.clear()
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
	var hint := _label(footer, "InputHint", "Enter / Cross: Advance     Esc / Circle: Back", 18, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button = _button("BackButton", "Back", cancel)
	footer.add_child(_back_button)
	_advance_button = _button("AdvanceButton", "Continue", advance)
	footer.add_child(_advance_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_advance_button)
	_advance_button.focus_neighbor_left = _advance_button.get_path_to(_back_button)


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
