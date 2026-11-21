extends Control

signal start_requested

const Setup := preload("res://game/combat/skirmish_setup.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Skirmish := preload("res://game/combat/infantry_skirmish.gd")
const View := preload("res://game/combat/infantry_skirmish_view.gd")
const DISPLAY_FACE := preload("res://assets/fonts/Cinzel.ttf")
const IVORY := Color("#f4e8d5")
const GOLD := Color("#d9ad70")
const MUTED := Color("#b5afa2")
const SIDES := ["Blue", "Amber"]

var _setup: Setup
var _back: BaseButton
var _side := 0
var _slot := 0
var _count_labels: Array[Label] = []
var _count_less: Array[Button] = []
var _count_more: Array[Button] = []
var _slots: Array[Array] = []
var _level_buttons: Dictionary[int, Button] = {}
var _type_buttons: Dictionary[StringName, Button] = {}
var _type_status: Label
var _step_buttons: Dictionary[int, Button] = {}
var _step := 1
var _rating_labels: Dictionary[Unit.Damage, Label] = {}
var _investment_labels: Dictionary[Unit.Damage, Label] = {}
var _rating_less: Dictionary[Unit.Damage, Button] = {}
var _rating_more: Dictionary[Unit.Damage, Button] = {}
var _heading: Label
var _level_label: Label
var _budget: Label
var _summary: Label
var _start: Button
var _buttons: Array[Button] = []


func initialize(setup: Setup, back_button: BaseButton, rating_names: Dictionary) -> void:
	_setup = setup
	_back = back_button
	name = "SkirmishSetupMenu"
	position = Vector2(76, 205)
	size = Vector2(1288, 526)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = _back.get_theme_font("font", "Button")
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _back.get_theme_stylebox(key, "Button").duplicate() as StyleBox
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		theme.set_stylebox(key, "Button", style)
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
		theme.set_color(key, "Button", _back.get_theme_color(key, "Button"))
	for side in range(SIDES.size()):
		_add_roster(side)

	_panel(Rect2(450, 0, 838, 450))
	_heading = _label("", Rect2(474, 9, 784, 44), 29, IVORY, DISPLAY_FACE)
	_label("Level", Rect2(474, 62, 80, 42), 23, MUTED)
	_level_control("LevelMin", "Min", 574, -Unit.MAX_LEVEL)
	_level_control("LevelMinusTen", "−10", 648, -10)
	_level_control("LevelMinus", "−1", 722, -1)
	_level_label = _label("", Rect2(796, 62, 99, 42), 29, IVORY)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_control("LevelPlus", "+1", 899, 1)
	_level_control("LevelPlusTen", "+10", 973, 10)
	_level_control("LevelMax", "Max", 1047, Unit.MAX_LEVEL)

	_label("Class", Rect2(474, 108, 80, 36), 23, MUTED)
	_type_control(Catalog.HUMAN_INFANTRY, "TypeInfantry", Rect2(574, 109, 116, 34))
	_type_control(Catalog.HUMAN_HEAVY_INFANTRY, "TypeHeavyInfantry", Rect2(700, 109, 179, 34))
	_type_status = _label("", Rect2(896, 108, 365, 36), 19, GOLD)
	_type_status.name = "UnitTypeStatus"

	_label("Combat ratings", Rect2(474, 155, 201, 35), 23, IVORY, DISPLAY_FACE)
	_label("Adjust by", Rect2(680, 155, 82, 35), 19, MUTED)
	for amount: int in [1, 5, 0]:
		var caption := str(amount) if amount else "All"
		var rect := Rect2(766 + 53 * _step_buttons.size(), 157, 49, 33)
		var button := _button("RatingStep" + caption, caption, rect, _set_step.bind(amount), 20)
		button.toggle_mode = true
		_step_buttons[amount] = button
	_budget = _label("", Rect2(928, 155, 333, 35), 22, GOLD)
	_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for type: Unit.Damage in Unit.Damage.values():
		_add_rating(type, rating_names[type])
	_summary = _label("", Rect2(0, 467, 894, 53), 22, MUTED)
	_start = _button("StartSkirmish", "Start Skirmish", Rect2(1008, 466, 280, 54),
		func() -> void: start_requested.emit(), 26)
	_refresh()


func focus_initial() -> void:
	_selected_button().grab_focus()


func _add_roster(side: int) -> void:
	var y := side * 232
	var side_name: String = SIDES[side]
	_panel(Rect2(0, y, 432, 218))
	_label(side_name + " platoons", Rect2(18, y + 10, 239, 43), 26, View.TEAM_COLORS[side], DISPLAY_FACE)
	_count_less.append(_button(side_name + "CountMinus", "−", Rect2(266, y + 14, 42, 39),
		_change_count.bind(side, -1)))
	var count := _label("", Rect2(310, y + 14, 54, 39), 23, IVORY)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_labels.append(count)
	_count_more.append(_button(side_name + "CountPlus", "+", Rect2(368, y + 14, 43, 39),
		_change_count.bind(side, 1)))
	var buttons: Array[Button] = []
	for slot in range(Setup.MAX_PLATOONS):
		var rect := Rect2(18 + (slot % 2) * 201, y + 70 + floori(slot / 2.0) * 64, 193, 55)
		var button := _button(side_name + "Platoon" + str(slot + 1), "", rect, _select.bind(side, slot), 19)
		button.toggle_mode = true
		buttons.append(button)
	_slots.append(buttons)


func _level_control(id: String, caption: String, x: float, delta: int) -> void:
	_level_buttons[delta] = _button(id, caption, Rect2(x, 63, 67, 40), _change_level.bind(delta), 21)


func _type_control(type: StringName, id: String, rect: Rect2) -> void:
	var button := _button(id, Catalog.TYPES[type].name, rect, _change_type.bind(type), 20)
	button.toggle_mode = true
	_type_buttons[type] = button


func _add_rating(type: Unit.Damage, caption: String) -> void:
	var x := 474 + type % 2 * 405
	var y := 198 + floori(type / 2.0) * 62
	var key: String = Unit.Damage.keys()[type].capitalize()
	_rule(Rect2(x, y, 383, 1))
	_label(caption, Rect2(x, y + 3, 180, 32), 22, IVORY)
	_investment_labels[type] = _label("", Rect2(x, y + 32, 185, 24), 17, MUTED)
	_rating_less[type] = _button(key + "Minus", "−", Rect2(x + 191, y + 10, 46, 42), _change_rating.bind(type, -1))
	var value := _label("", Rect2(x + 239, y + 9, 86, 43), 25, IVORY)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_labels[type] = value
	_rating_more[type] = _button(key + "Plus", "+", Rect2(x + 332, y + 10, 46, 42), _change_rating.bind(type, 1))


func _select(side: int, slot: int) -> void:
	_side = side
	_slot = slot
	_refresh()


func _change_count(side: int, delta: int) -> void:
	_setup.set_count(side, _setup.sides[side].size() + delta)
	_slot = mini(_slot, _setup.sides[_side].size() - 1)
	_refresh(_count_less[side] if delta > 0 else _count_more[side])


func _change_level(delta: int) -> void:
	var build := _build()
	build.set_level(build.level + delta)
	_refresh(_level_buttons[-1] if delta > 0 else _level_buttons[1])


func _change_type(type: StringName) -> void:
	_build().set_unit_type(type)
	_refresh(_type_buttons[Catalog.HUMAN_INFANTRY])


func _change_rating(type: Unit.Damage, delta: int) -> void:
	var build := _build()
	var invested := build.points_for(type)
	var amount := _step
	if amount == 0:
		amount = build.remaining_points() if delta > 0 else invested
	build.set_points(type, invested + delta * amount)
	_refresh(_rating_less[type] if delta > 0 else _rating_more[type])


func _set_step(amount: int) -> void:
	_step = amount
	for value in _step_buttons:
		_step_buttons[value].set_pressed_no_signal(value == _step)


func _build() -> Setup.PlatoonBuild:
	return _setup.sides[_side][_slot]


func _selected_button() -> Button:
	return _slots[_side][_slot]


func _refresh(fallback: Button = null) -> void:
	var previous := get_viewport().gui_get_focus_owner()
	var build := _build()
	var total := 0
	for side in range(SIDES.size()):
		var count := _setup.sides[side].size()
		total += count
		_count_labels[side].text = str(count)
		_count_less[side].disabled = count <= 1
		_count_more[side].disabled = count >= Setup.MAX_PLATOONS
		for slot in range(Setup.MAX_PLATOONS):
			var button: Button = _slots[side][slot]
			button.visible = slot < count
			if button.visible:
				var platoon: Setup.PlatoonBuild = _setup.sides[side][slot]
				button.text = "Platoon %d · Lv. %d\n%s" % [slot + 1, platoon.level, Catalog.TYPES[platoon.unit_type].name]
				button.set_pressed_no_signal(side == _side and slot == _slot)

	_heading.text = "%s · Platoon %d" % [SIDES[_side], _slot + 1]
	_heading.modulate = View.TEAM_COLORS[_side]
	_level_label.text = str(build.level)
	for delta in _level_buttons:
		_level_buttons[delta].disabled = (delta < 0 and build.level <= 1) or (delta > 0 and build.level >= Unit.MAX_LEVEL)

	for type in _type_buttons:
		_type_buttons[type].disabled = not build.can_select_unit_type(type)
		_type_buttons[type].set_pressed_no_signal(build.unit_type == type)
	var regular_button := _type_buttons[Catalog.HUMAN_INFANTRY]
	var heavy_button := _type_buttons[Catalog.HUMAN_HEAVY_INFANTRY]
	regular_button.focus_neighbor_right = regular_button.get_path_to(heavy_button) if not heavy_button.disabled else NodePath()
	heavy_button.focus_neighbor_left = heavy_button.get_path_to(regular_button)
	var heavy: Dictionary = Catalog.TYPES[Catalog.HUMAN_HEAVY_INFANTRY]
	var required_melee: int = heavy.promotion_minimum_ratings[Unit.Damage.MELEE]
	_type_status.text = "Heavy Infantry: Melee Power %d / %d" % [build.rating(Unit.Damage.MELEE), required_melee]
	if build.unit_type == Catalog.HUMAN_HEAVY_INFANTRY:
		_type_status.text = "Heavy Infantry: more HP, slower, lighter hits"

	var remaining := build.remaining_points()
	_set_step(_step)
	_budget.text = "%d / %d points available" % [remaining, build.level - 1]
	var base: Dictionary = Catalog.TYPES[Catalog.HUMAN_INFANTRY].ratings
	for type: Unit.Damage in Unit.Damage.values():
		var invested := build.points_for(type)
		_investment_labels[type].text = "Base %d  ·  %d spent" % [base[type], invested]
		_rating_labels[type].text = str(build.rating(type))
		_rating_less[type].disabled = invested == 0
		_rating_more[type].disabled = remaining == 0 or build.rating(type) >= Unit.MAX_RATING
	_summary.text = "%d platoons  ·  %d soldiers per platoon  ·  %d soldiers" % [total, Skirmish.PLATOON_SIZE, total * Skirmish.PLATOON_SIZE]
	_update_focus(previous, fallback)


func _update_focus(previous: Control, fallback: Button) -> void:
	var order: Array[Control] = [_back]
	for button in _buttons:
		button.focus_mode = Control.FOCUS_ALL if button.visible and not button.disabled else Control.FOCUS_NONE
		if button.focus_mode == Control.FOCUS_ALL:
			order.append(button)
	for i in range(order.size()):
		order[i].focus_next = order[i].get_path_to(order[(i + 1) % order.size()])
		order[i].focus_previous = order[i].get_path_to(order[posmod(i - 1, order.size())])
	# Leave the editor in the same place when an action reaches its limit.
	if previous and is_ancestor_of(previous) and previous.focus_mode == Control.FOCUS_NONE:
		if fallback and fallback.focus_mode == Control.FOCUS_ALL:
			fallback.grab_focus()
		else:
			_selected_button().grab_focus()
	_back.focus_neighbor_bottom = _back.get_path_to(_selected_button())


func _button(id: String, caption: String, rect: Rect2, action: Callable, font_size := 23) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	_buttons.append(button)
	return button


func _label(caption: String, rect: Rect2, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _panel(rect: Rect2) -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.047, 0.054, 0.055, 0.91)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	_rule(Rect2(rect.position, Vector2(rect.size.x, 1)))


func _rule(rect: Rect2) -> void:
	var rule := ColorRect.new()
	rule.color = Color("#716451")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	rule.position = rect.position
	rule.size = rect.size
