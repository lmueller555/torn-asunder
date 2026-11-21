extends CanvasLayer

signal leave_requested

const Bindings := preload("res://game/settings/control_bindings.gd")
const TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")
const BODY_FONT := preload("res://assets/fonts/SourceSans3.ttf")
const GOLD := Color("#d7ab70")
const IVORY := Color("#ede3d5")
const GROUPS := {
	"Keyboard": [&"key"], "Mouse": [&"mouse"], "Controller": [&"button", &"stick", &"trigger"]
}

enum Page { MENU, SETTINGS, CAPTURE, LEAVE, RESTART, RESTORE }

var bindings_path := Bindings.PATH

var _overlay: ColorRect
var _content: VBoxContainer
var _page := Page.MENU
var _leave_label := ""
var _restart: Callable
var _previous_focus: WeakRef
var _group := "Keyboard"
var _capture_group: StringName
var _capture_slot: int
var _feedback := ""
var _resume_on_cancel_release := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.009, 0.014, 0.016, 0.78)
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()


static func is_pause_press(event: InputEvent) -> bool:
	return (event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)


func open(leave_label: String, restart := Callable()) -> void:
	if _overlay.visible or get_tree().paused:
		return
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if is_instance_valid(focus) else null
	_leave_label = leave_label
	_restart = restart
	get_tree().paused = true
	_overlay.show()
	_show_menu()


func close(restore_focus := true) -> void:
	if not _overlay.visible:
		return
	_overlay.hide()
	_resume_on_cancel_release = false
	get_tree().paused = false
	if restore_focus and _previous_focus:
		var focus := _previous_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _exit_tree() -> void:
	if is_instance_valid(_overlay) and _overlay.visible and get_tree():
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if _page == Page.CAPTURE:
		if is_pause_press(event):
			get_viewport().set_input_as_handled()
			_show_settings()
			return
		var code := Bindings.capture_code(_capture_group, event)
		if code >= 0:
			get_viewport().set_input_as_handled()
			var result := Bindings.bind(_capture_group, _capture_slot, code, bindings_path)
			_feedback = "Binding saved." if result == OK else "That input could not be assigned."
			_show_settings()
		return
	if _resume_on_cancel_release and event is InputEventJoypadButton and event.is_action_released("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if is_pause_press(event) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match _page:
			Page.MENU:
				if event is InputEventJoypadButton and not is_pause_press(event):
					_resume_on_cancel_release = true
				else:
					close()
			Page.SETTINGS, Page.LEAVE, Page.RESTART: _show_menu()
			Page.RESTORE: _show_settings()


func _show_menu() -> void:
	_build(Page.MENU, "Paused")
	var resume := _button("Resume", close)
	resume.name = "ResumeGame"
	_button("Settings", _show_settings)
	if _restart.is_valid():
		_button("Restart", _show_restart).name = "RestartGame"
	_button(_leave_label, _show_leave).name = "LeaveGame"
	resume.grab_focus()


func _show_leave() -> void:
	_build(Page.LEAVE, _leave_label)
	if _leave_label == "Return to Campaign Map":
		_label(_content, "Leave this attempt? Progress since deployment will be lost.")
	var stay := _button("Stay", _show_menu)
	var leave := _button("Leave", func() -> void:
		close(false)
		leave_requested.emit()
	)
	leave.name = "ConfirmLeave"
	stay.grab_focus()


func _show_restart() -> void:
	_build(Page.RESTART, "Restart")
	_label(_content, "Start this attempt again? Current progress will be lost.")
	_button("Cancel", _show_menu).grab_focus()
	var restart := _button("Restart", func() -> void:
		close()
		if _restart.is_valid():
			_restart.call()
	)
	restart.name = "ConfirmRestart"


func _show_settings() -> void:
	_build(Page.SETTINGS, "Settings · Controls", true)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_content.add_child(tabs)
	var active_tab: Button
	for group: String in GROUPS:
		var tab := _button(group, _select_group.bind(group), tabs)
		if group == _group:
			tab.toggle_mode = true
			tab.set_pressed_no_signal(true)
			active_tab = tab
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 360
	_content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for kind: StringName in GROUPS[_group]:
		for slot: int in Bindings.ROWS[kind]:
			var action: String = Bindings.ROWS[kind][slot]
			var assigned := Bindings.describe(kind, Bindings.physical(kind, slot))
			_button("%s    ·    %s" % [action, assigned], _show_capture.bind(kind, slot), rows)
	_label(_content, "Pause: Escape / Options or Menu. Assigning a used input swaps the two bindings.")
	if not _feedback.is_empty():
		_label(_content, _feedback)
		_feedback = ""
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	_content.add_child(footer)
	_button("Back", _show_menu, footer)
	_button("Restore Defaults", _show_restore, footer)
	active_tab.grab_focus()


func _select_group(group: String) -> void:
	_group = group
	_show_settings()


func _show_capture(group: StringName, slot: int) -> void:
	_build(Page.CAPTURE, Bindings.ROWS[group][slot])
	_capture_group = group
	_capture_slot = slot
	var prompt: String = {
		&"key": "Press a keyboard key.",
		&"mouse": "Click a mouse button or move the wheel.",
		&"button": "Press a controller button.",
		&"stick": "Move the stick on the axis you want to assign.",
		&"trigger": "Pull the trigger you want to assign.",
	}[group]
	_label(_content, prompt + " Press Escape or Options / Menu to cancel.")
	if group != &"mouse":
		_button("Cancel", _show_settings).grab_focus()


func _show_restore() -> void:
	_build(Page.RESTORE, "Restore Defaults")
	_label(_content, "Restore the default bindings for every input device?")
	_button("Keep My Bindings", _show_settings).grab_focus()
	_button("Restore", func() -> void:
		_feedback = "Defaults restored." if Bindings.restore(bindings_path) == OK else "Defaults could not be saved."
		_show_settings()
	)


func _build(page: Page, title: String, wide := false) -> void:
	_page = page
	for child in _overlay.get_children():
		_overlay.remove_child(child)
		child.queue_free()
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 780 if wide else 510
	panel.add_theme_stylebox_override("panel", _box(Color("#171d1e"), Color("#867054"), 1, 24))
	center.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	panel.add_child(_content)
	var heading := _label(_content, title)
	heading.add_theme_font_override("font", TITLE_FONT)
	heading.add_theme_font_size_override("font_size", 27)


func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", IVORY)
	parent.add_child(label)
	return label


func _button(text: String, action: Callable, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 37
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 21)
	for style in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(style, IVORY)
	button.add_theme_stylebox_override("normal", _box(Color("#252e2e"), Color("#42504e")))
	button.add_theme_stylebox_override("hover", _box(Color("#353429"), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color("#483a2e"), GOLD))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 2))
	button.pressed.connect(action)
	(parent if parent else _content).add_child(button)
	return button


func _box(fill: Color, border: Color, width := 1, padding := 11) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding if padding > 11 else 2
	style.content_margin_bottom = style.content_margin_top
	return style
