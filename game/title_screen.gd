extends Control

const Campaigns := preload("res://game/campaigns.gd")
const ProfileStore := preload("res://game/profile_store.gd")
const Embers := preload("res://game/embers.gd")
const Drills := preload("res://game/combat/drills.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const TITLE_ART := preload("res://assets/art/title.webp")
const VAULT_ART := preload("res://assets/art/vault.webp")
const DISPLAY_FACE := preload("res://assets/fonts/Cinzel.ttf")
const UI_FACE := preload("res://assets/fonts/SourceSans3.ttf")

const GOLD := Color("#d9ad70")
const IVORY := Color("#f4e8d5")
const MUTED := Color("#b5afa2")
const HAIRLINE := Color("#716451")
const DARK := Color("#171a1a")

enum Page { TITLE, VAULT, LOAD, SETTINGS, QUIT, BRIEFING, DRILLS }

var _profile := ProfileStore.new()
var _body_face := FontVariation.new()
var _page: Page
var _stage: Control
var _hint: Label
var _notice: Label
var _using_controller := false
var _selected := 0
var _portraits: Array[Button] = []
var _selection_title: Label
var _selection_region: Label
var _selection_summary: Label
var _active_campaign: Dictionary
var _drill_index := 0
var _drill_rank := Platoon.MAX_RANK
var _drill_buttons: Array[Button] = []
var _drill_title: Label
var _drill_description: Label
var _drill_rank_label: Label
var _drill_rank_heading: Label
var _drill_lower_rank: Button
var _drill_metrics: Array[Label] = []
var _drill_baseline: Array[Label] = []
var _drill_results: Array[Label] = []


func _ready() -> void:
	_body_face.base_font = UI_FACE
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	_body_face.variation_opentype = {weight_axis: 465}
	_map_controller_button("ui_accept", JOY_BUTTON_A)
	_map_controller_button("ui_cancel", JOY_BUTTON_B)
	_apply_fullscreen()
	_show_title()


func _map_controller_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _input(event: InputEvent) -> void:
	var controller_button := event is InputEventJoypadButton and event.is_pressed()
	var controller_stick: bool = event is InputEventJoypadMotion and absf(event.axis_value) > 0.65
	if controller_button or controller_stick:
		_using_controller = true
		_update_hint()
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_using_controller = false
		_update_hint()

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	match _page:
		Page.TITLE:
			_show_quit()
		Page.DRILLS:
			_show_briefing()
		_:
			_show_title()


func _show_title() -> void:
	_open_page(Page.TITLE)
	_label(_stage, "TORN", Rect2(86, 111, 520, 112), 103, IVORY, DISPLAY_FACE)
	_label(_stage, "ASUNDER", Rect2(89, 204, 540, 96), 75, GOLD, DISPLAY_FACE)
	_rule(Rect2(94, 328, 352, 1), HAIRLINE)
	_color_rect(_stage, Rect2(94, 327, 47, 2), GOLD)

	var saves := _profile.saved_campaigns(Campaigns.ALL)
	var actions: Array[Button] = []
	var new_game := _button("New Game", Rect2(94, 359, 352, 52), _show_vault.bind(0))
	actions.append(new_game)
	var resume := _button("Continue", Rect2(94, 420, 352, 52))
	if saves.is_empty():
		resume.disabled = true
	else:
		resume.pressed.connect(_open_campaign.bind(saves[0]))
		actions.append(resume)
	actions.append(_button("Load", Rect2(94, 481, 352, 52), _show_load))
	actions.append(_button("Settings", Rect2(94, 542, 352, 52), _show_settings))
	actions.append(_button("Quit", Rect2(94, 603, 352, 52), _show_quit))
	_link_cycle(actions, SIDE_TOP, SIDE_BOTTOM)
	new_game.grab_focus()


func _show_vault(initial_index: int) -> void:
	_open_page(Page.VAULT)
	var back := _heading("Campaign Vault", "Choose a leader to begin their campaign.")
	_portraits.clear()
	for index in range(Campaigns.ALL.size()):
		var campaign := Campaigns.ALL[index]
		var card := _portrait(campaign, Rect2(76 + index * 217, 224, 203, 292))
		card.focus_entered.connect(_select_portrait.bind(index))
		card.pressed.connect(_open_campaign.bind(campaign))
		_portraits.append(card)

	_rule(Rect2(76, 547, 1288, 1), HAIRLINE)
	_selection_region = _label(_stage, "", Rect2(76, 565, 920, 26), 19, GOLD)
	_selection_title = _label(_stage, "", Rect2(76, 594, 960, 41), 31, IVORY, DISPLAY_FACE)
	_selection_summary = _label(_stage, "", Rect2(76, 642, 900, 69), 22, MUTED)
	_selection_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var begin := _button("Begin Campaign", Rect2(1090, 611, 274, 57), _begin_selected)
	_link_cycle(_portraits, SIDE_LEFT, SIDE_RIGHT)
	for card in _portraits:
		_link_focus(card, SIDE_TOP, back)
		_link_focus(card, SIDE_BOTTOM, begin)
	_link_focus(back, SIDE_BOTTOM, _portraits[initial_index])
	_link_focus(begin, SIDE_TOP, _portraits[initial_index])
	_select_portrait(initial_index)
	_portraits[initial_index].grab_focus()


func _select_portrait(index: int) -> void:
	_selected = index
	for i in range(_portraits.size()):
		var color: Color = GOLD if i == index else HAIRLINE
		_portraits[i].add_theme_stylebox_override("normal", _box(DARK, color))
	var campaign := Campaigns.ALL[index]
	_selection_region.text = "%s  /  %s" % [campaign.faction.to_upper(), campaign.region.to_upper()]
	_selection_region.add_theme_color_override("font_color", campaign.accent)
	_selection_title.text = "%s %s" % [campaign.title, campaign.name]
	_selection_summary.text = campaign.briefing
	for button_name in ["Begin Campaign", "Back"]:
		var button := _stage.get_node_or_null(button_name) as Button
		if button:
			_link_focus(button, SIDE_TOP if button_name == "Begin Campaign" else SIDE_BOTTOM, _portraits[index])


func _begin_selected() -> void:
	_open_campaign(Campaigns.ALL[_selected])


func _open_campaign(campaign: Dictionary) -> void:
	_active_campaign = campaign
	var result := _profile.mark_played(campaign.id)
	_show_briefing()
	if result != OK:
		_show_notice("The campaign selection could not be saved.")


func _show_briefing() -> void:
	var campaign := _active_campaign
	_open_page(Page.BRIEFING)
	var back := _heading("Campaign Briefing", campaign.opening)
	_portrait(campaign, Rect2(76, 230, 320, 448), false)
	_label(_stage, campaign.faction.to_upper(), Rect2(442, 255, 736, 32), 20, campaign.accent)
	_label(
		_stage, "%s %s" % [campaign.title, campaign.name],
		Rect2(442, 292, 900, 60), 42, IVORY, DISPLAY_FACE
	)
	_rule(Rect2(442, 369, 675, 1), HAIRLINE)
	var briefing := _label(_stage, "", Rect2(442, 387, 675, 130), 27, IVORY)
	briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	briefing.text = campaign.briefing
	var drills := _button("Combat Drills", Rect2(442, 570, 274, 57), _show_drills)
	_link_focus(back, SIDE_BOTTOM, drills)
	_link_focus(drills, SIDE_TOP, back)
	back.grab_focus()


func _show_drills() -> void:
	_open_page(Page.DRILLS)
	var back := _heading("Combat Drills", "Compare combat outcomes across training ranks.")
	_drill_buttons.clear()
	for index in range(Drills.EXERCISES.size()):
		var exercise := Drills.EXERCISES[index]
		var button := _button(exercise.name, Rect2(76, 225 + 67 * index, 345, 55), _select_drill.bind(index))
		button.focus_entered.connect(_select_drill.bind(index))
		_drill_buttons.append(button)
	_link_cycle(_drill_buttons, SIDE_TOP, SIDE_BOTTOM)

	_color_rect(_stage, Rect2(464, 225, 900, 457), Color(0.047, 0.054, 0.055, 0.9))
	_rule(Rect2(464, 225, 900, 1), HAIRLINE)
	_drill_title = _label(_stage, "", Rect2(492, 245, 520, 56), 36, IVORY, DISPLAY_FACE)
	_drill_description = _label(_stage, "", Rect2(492, 317, 823, 66), 23, MUTED)
	_drill_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drill_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_drill_lower_rank = _button("−", Rect2(1038, 251, 51, 43), _change_drill_rank.bind(-1))
	_drill_lower_rank.tooltip_text = "Lower rank"
	_drill_rank_label = _label(_stage, "", Rect2(1092, 251, 180, 43), 21, IVORY)
	_drill_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var raise_rank := _button("+", Rect2(1275, 251, 51, 43), _change_drill_rank.bind(1))
	raise_rank.tooltip_text = "Raise rank"
	_link_focus(back, SIDE_BOTTOM, _drill_lower_rank)
	_link_focus(_drill_lower_rank, SIDE_TOP, back)
	_link_focus(raise_rank, SIDE_TOP, back)
	_link_focus(_drill_lower_rank, SIDE_RIGHT, raise_rank)
	_link_focus(raise_rank, SIDE_LEFT, _drill_lower_rank)
	for button in _drill_buttons:
		_link_focus(button, SIDE_RIGHT, _drill_lower_rank)

	_label(_stage, "Rank 0", Rect2(902, 398, 164, 36), 20, MUTED)
	_drill_rank_heading = _label(_stage, "", Rect2(1135, 398, 180, 36), 20, GOLD)
	_drill_metrics.clear()
	_drill_baseline.clear()
	_drill_results.clear()
	for row in range(3):
		var y := 443 + 65 * row
		_rule(Rect2(492, y, 833, 1), HAIRLINE)
		_drill_metrics.append(_label(_stage, "", Rect2(492, y + 9, 402, 46), 24, IVORY))
		_drill_baseline.append(_label(_stage, "", Rect2(902, y + 9, 165, 46), 24, MUTED))
		_drill_results.append(_label(_stage, "", Rect2(1135, y + 9, 180, 46), 24, GOLD))

	_select_drill(_drill_index)
	_drill_buttons[_drill_index].grab_focus()


func _select_drill(index: int) -> void:
	_drill_index = index
	_link_focus(_drill_lower_rank, SIDE_LEFT, _drill_buttons[index])
	for i in range(_drill_buttons.size()):
		_drill_buttons[i].add_theme_color_override("font_color", GOLD if i == index else IVORY)
	_update_drill()


func _change_drill_rank(change: int) -> void:
	_drill_rank = clampi(_drill_rank + change, 0, Platoon.MAX_RANK)
	_update_drill()


func _update_drill() -> void:
	var exercise := Drills.EXERCISES[_drill_index]
	var metrics: Array = exercise.metrics
	var baseline := Drills.run(exercise.id, 0)
	var results := Drills.run(exercise.id, _drill_rank)
	_drill_title.text = exercise.name
	_drill_description.text = exercise.description
	_drill_rank_label.text = "%s %d" % ["Curse rating" if exercise.id == &"curse" else "Training rank", _drill_rank]
	_drill_rank_heading.text = "Rank %d" % _drill_rank
	for row in range(_drill_metrics.size()):
		var has_metric := row < metrics.size()
		_drill_metrics[row].text = metrics[row] if has_metric else ""
		_drill_baseline[row].text = baseline[row] if has_metric else ""
		_drill_results[row].text = results[row] if has_metric else ""


func _show_load() -> void:
	_open_page(Page.LOAD)
	var back := _heading("Load Campaign", "Resume a saved campaign.")
	var saves := _profile.saved_campaigns(Campaigns.ALL)
	if saves.is_empty():
		_label(_stage, "No saved campaigns yet.", Rect2(76, 243, 710, 50), 25, MUTED)
		back.grab_focus()
		return

	var actions: Array[Button] = [back]
	for i in range(saves.size()):
		var campaign := saves[i]
		var text := "%s %s  ·  %s" % [campaign.title, campaign.name, campaign.faction]
		var button := _button(text, Rect2(76, 224 + i * 71, 710, 59), _open_campaign.bind(campaign))
		actions.append(button)
	_link_cycle(actions, SIDE_TOP, SIDE_BOTTOM)
	actions[1].grab_focus()


func _show_settings() -> void:
	_open_page(Page.SETTINGS)
	var back := _heading("Settings", "Adjust display and menu motion.")
	var fullscreen := _setting_button("Fullscreen", "fullscreen", 233)
	var motion := _setting_button("Reduced motion", "reduced_motion", 329)
	var choices: Array[Button] = [back, fullscreen, motion]
	_link_cycle(choices, SIDE_TOP, SIDE_BOTTOM)
	fullscreen.grab_focus()


func _setting_button(title: String, key: String, y: float) -> Button:
	var button := _button(title, Rect2(76, y, 554, 63))
	var status := _label(button, "", Rect2(410, 0, 115, 63), 21, GOLD)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.text = "ON" if _profile.setting(key) else "OFF"
	button.pressed.connect(func() -> void:
		var enabled := not _profile.setting(key)
		if _profile.set_setting(key, enabled) != OK:
			_show_notice("The setting could not be saved.")
			return
		status.text = "ON" if enabled else "OFF"
		_notice.hide()
		if key == "fullscreen":
			_apply_fullscreen()
		else:
			var embers := _stage.get_node("Embers") as Control
			embers.visible = not enabled
			embers.set_process(not enabled)
	)
	return button


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _profile.setting("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _show_quit() -> void:
	_open_page(Page.QUIT)
	var back := _heading("Quit Game", "Close Torn Asunder?")
	var cancel := _button("Keep Playing", Rect2(76, 232, 310, 58), _show_title)
	var quit := _button("Quit Game", Rect2(76, 307, 310, 58), get_tree().quit)
	var choices: Array[Button] = [back, cancel, quit]
	_link_cycle(choices, SIDE_TOP, SIDE_BOTTOM)
	cancel.grab_focus()


func _open_page(page: Page) -> void:
	_page = page
	if is_instance_valid(_stage):
		remove_child(_stage)
		_stage.queue_free()
	_stage = Control.new()
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var is_title := page == Page.TITLE
	var background := _texture(
		_stage, TITLE_ART if is_title else VAULT_ART, Rect2(0, 0, 1440, 810)
	)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_title:
		_shade(_stage, Rect2(0, 0, 1140, 810), false, Color(0.02, 0.025, 0.024, 0.65))
	else:
		_color_rect(_stage, Rect2(0, 0, 1440, 810), Color(0.025, 0.029, 0.03, 0.49))
	_shade(_stage, Rect2(0, 612, 1440, 198), true, Color(0.016, 0.02, 0.02, 0.92))

	var embers := Embers.new()
	embers.name = "Embers"
	_stage.add_child(embers)
	embers.position = Vector2(500, 0) if is_title else Vector2.ZERO
	embers.size = Vector2(940, 730) if is_title else Vector2(1440, 730)
	embers.visible = not _profile.setting("reduced_motion")
	embers.set_process(embers.visible)

	_rule(Rect2(76, 744, 1288, 1), Color(0.63, 0.55, 0.43, 0.36))
	_hint = _label(_stage, "", Rect2(76, 753, 1200, 38), 17, MUTED)
	_update_hint()
	_notice = _label(_stage, "", Rect2(76, 704, 1140, 32), 21, Color("#fbb89b"))
	_notice.hide()


func _heading(title: String, subtitle: String) -> Button:
	_label(_stage, title, Rect2(76, 67, 1050, 76), 57, IVORY, DISPLAY_FACE)
	_label(_stage, subtitle, Rect2(77, 148, 1050, 34), 23, MUTED)
	_rule(Rect2(76, 196, 1288, 1), HAIRLINE)
	return _button("Back", Rect2(1192, 91, 172, 48), _go_back)


func _update_hint() -> void:
	if not is_instance_valid(_hint):
		return
	if _using_controller:
		_hint.text = "D-pad   Navigate       Cross   Select"
		if _page != Page.TITLE:
			_hint.text += "       Circle   Back"
	else:
		_hint.text = "↑ ↓ ← →   Navigate       Enter   Select"
		if _page != Page.TITLE:
			_hint.text += "       Esc   Back"


func _show_notice(message: String) -> void:
	_notice.text = message
	_notice.show()


func _portrait(campaign: Dictionary, rect: Rect2, interactive: bool = true) -> Button:
	var card := Button.new()
	card.name = campaign.id
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stage.add_child(card)
	card.position = rect.position
	card.size = rect.size
	card.add_theme_stylebox_override("normal", _box(DARK, HAIRLINE))
	card.add_theme_stylebox_override("hover", _box(DARK, GOLD))
	card.add_theme_stylebox_override("pressed", _box(DARK, IVORY))
	card.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 2))
	card.tooltip_text = "%s %s" % [campaign.title, campaign.name]
	if not interactive:
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_texture(card, campaign.portrait, Rect2(Vector2(3, 3), rect.size - Vector2(6, 6)))
	if interactive:
		_shade(card, Rect2(3, rect.size.y - 120, rect.size.x - 6, 117), true, Color("#101313"))
		_label(card, campaign.faction.to_upper(), Rect2(14, rect.size.y - 67, rect.size.x - 28, 24), 16, campaign.accent)
		_label(card, campaign.name, Rect2(14, rect.size.y - 44, rect.size.x - 28, 34), 21, IVORY, DISPLAY_FACE)
	return card


func _button(text: String, rect: Rect2, action: Callable = Callable()) -> Button:
	var button := Button.new()
	button.name = text
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _body_face)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color("#928b80"))
	button.add_theme_stylebox_override("normal", _box(Color(0.08, 0.09, 0.09, 0.74), HAIRLINE))
	button.add_theme_stylebox_override("hover", _box(Color("#292622"), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color("#403123"), GOLD))
	button.add_theme_stylebox_override("focus", _box(Color(0.64, 0.42, 0.20, 0.16), GOLD, 2))
	button.add_theme_stylebox_override("disabled", _box(Color(0.06, 0.07, 0.07, 0.46), Color("#4a4540")))
	_stage.add_child(button)
	button.position = rect.position
	button.size = rect.size
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _box(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = 19
	box.content_margin_right = 16
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _link_cycle(buttons: Array[Button], previous: Side, next: Side) -> void:
	for index in range(buttons.size()):
		_link_focus(buttons[index], previous, buttons[posmod(index - 1, buttons.size())])
		_link_focus(buttons[index], next, buttons[(index + 1) % buttons.size()])


func _link_focus(from: Button, direction: Side, to: Button) -> void:
	from.set_focus_neighbor(direction, from.get_path_to(to))


func _label(
	parent: Control, text: String, rect: Rect2, font_size: int, color: Color, font: Font = null
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font if font else _body_face)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _texture(parent: Control, art: Texture2D, rect: Rect2) -> TextureRect:
	var texture := TextureRect.new()
	texture.texture = art
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture)
	texture.position = rect.position
	texture.size = rect.size
	return texture


func _color_rect(parent: Control, rect: Rect2, color: Color) -> void:
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	fill.position = rect.position
	fill.size = rect.size


func _rule(rect: Rect2, color: Color) -> void:
	_color_rect(_stage, rect, color)


func _shade(parent: Control, rect: Rect2, vertical: bool, color: Color) -> void:
	var gradient := Gradient.new()
	var clear := Color(color, 0.0)
	gradient.colors = PackedColorArray([clear, color] if vertical else [color, clear])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 2 if vertical else 512
	texture.height = 256 if vertical else 2
	texture.fill_to = Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	_texture(parent, texture, rect).stretch_mode = TextureRect.STRETCH_SCALE
