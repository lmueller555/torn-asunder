extends Control
## Standalone interaction fixture; never listens to title or mission input.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Atlas := preload("res://tests/fixtures/minimap_valley.svg")
const WORLD := Rect2(-160.0, -110.0, 320.0, 220.0)

var _map: Minimap
var _readout: Label
var _play_button: Button
var _sight_button: Button
var _frame := Minimap.Frame.new()
var _clock := 0.0
var _focus := Vector2(-64.0, 6.0)
var _auto_follow := true
var _playing := true
var _enemy_in_sight := true


func _ready() -> void:
	_build_ui()
	_update_display()


func _process(delta: float) -> void:
	if _playing:
		_clock += delta
		_update_display()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE: _toggle_play()
		KEY_C: _cycle_selection()
		KEY_V: _toggle_sight()
		KEY_HOME: _follow_hero()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#10171b")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_label(column, "TORN ASUNDER  /  BATTLEFIELD UI LAB", 18, Color("#a5c7bd"))
	_label(column, "Valley watch", 37, Color("#fff1c4"))
	_label(column, "Standalone minimap preview  ·  320 × 220 m fixture", 19, Color("#c2d2d5"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	_map = Minimap.new()
	_map.terrain_texture = Atlas
	_map.click_to_focus = true
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_map)
	_map.set_field_bounds(WORLD)
	_map.point_requested.connect(_focus_point)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 290.0
	sidebar.add_theme_constant_override("separation", 10)
	row.add_child(sidebar)
	_label(sidebar, "FIELD KEY", 17, Color("#a5c7bd"))
	_label(sidebar, "▲  Hero and facing", 19, Minimap.HERO)
	_label(sidebar, "■  Allied formation", 19, Minimap.ALLY)
	_label(sidebar, "□  Selected formation outline", 19, Minimap.PICKUP)
	_label(sidebar, "●  Visible enemy", 19, Minimap.ENEMY)
	_label(sidebar, "◆  Pickup objective", 19, Minimap.PICKUP)
	_label(sidebar, "⊓  Exit objective", 19, Minimap.EXIT)
	_label(sidebar, "▱  Command camera footprint", 19, Minimap.SECTOR)
	sidebar.add_child(HSeparator.new())
	_readout = _label(sidebar, "", 18, Color("#e0e8e9"))

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	_play_button = _button(controls, "Pause  [Space]", _toggle_play)
	_button(controls, "Cycle unit  [C]", _cycle_selection)
	_sight_button = _button(controls, "Lose enemy contact  [V]", _toggle_sight)
	_button(controls, "Center on hero  [Home]", _follow_hero)
	_label(column, "Click anywhere in the minimap to move the command footprint.", 17, Color("#b1c1c3"))
	_frame.selected_ally = &"Infantry"


func _update_display() -> void:
	var walk := sin(_clock * 0.34)
	var hero_at := Vector2(-64.0 + 44.0 * walk, 5.0 + 12.0 * cos(_clock * 0.27))
	var direction := Vector2(cos(_clock * 0.34), -0.2 * sin(_clock * 0.27)).normalized()
	_frame.hero = Minimap.Marker.new(&"Mara", hero_at, direction)
	_frame.allies = [
		Minimap.Marker.new(&"Infantry", Vector2(-90.0 + walk * 20.0, -12.0)),
		Minimap.Marker.new(&"Archers", Vector2(22.0 + 12.0 * cos(_clock * 0.3), -39.0)),
	]
	_frame.objectives = [
		Minimap.Marker.new(&"Godbridle", Vector2(-68, 32)),
		Minimap.Marker.new(&"East exit", Vector2(148, 2), Vector2.UP, Minimap.ObjectiveKind.EXIT),
	]
	_frame.visible_enemies.clear()
	if _enemy_in_sight:
		_frame.visible_enemies.append(Minimap.Marker.new(&"Road guard", Vector2(92, 24.0 + 10.0 * walk)))
	if _auto_follow:
		_focus = hero_at + Vector2(16, 1)
	var view_yaw := 0.26 + sin(_clock * 0.20) * 0.27
	var corners := PackedVector2Array()
	for offset in [Vector2(-43, -27), Vector2(43, -27), Vector2(43, 27), Vector2(-43, 27)]:
		corners.append(_focus + offset.rotated(view_yaw))
	_frame.camera_footprint = corners
	_map.show_frame(_frame)
	_readout.text = "Selected: %s\nEnemy contact: %s\nFocus: %d, %d m" % [
		_frame.selected_ally, "visible" if _enemy_in_sight else "not visible", roundi(_focus.x), roundi(_focus.y),
	]


func _focus_point(point: Vector2) -> void:
	_focus = point
	_auto_follow = false
	_update_display()


func _follow_hero() -> void:
	_auto_follow = true
	_update_display()


func _cycle_selection() -> void:
	_frame.selected_ally = &"Archers" if _frame.selected_ally == &"Infantry" else &"Infantry"
	_update_display()


func _toggle_sight() -> void:
	_enemy_in_sight = not _enemy_in_sight
	_sight_button.text = "Lose enemy contact  [V]" if _enemy_in_sight else "Restore enemy contact  [V]"
	_update_display()


func _toggle_play() -> void:
	_playing = not _playing
	_play_button.text = "Pause  [Space]" if _playing else "Play  [Space]"


func _label(parent: Control, copy: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, copy: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = copy
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size.y = 40.0
	parent.add_child(button)
	button.pressed.connect(handler)
	return button
