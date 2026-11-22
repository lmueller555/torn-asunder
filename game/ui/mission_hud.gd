extends Control
## The in-mission overlay. Callers own gameplay, world projection and the minimap.
## All drawing dimensions below use the approved 960 × 540 reference.

const _SCRIPT_PATH := "res://game/ui/mission_hud.gd"
const _LAYER_NAME := &"MissionHudLayer"
const _REFERENCE := Vector2(960.0, 540.0)
const _IVORY := Color("#f4e6b7")
const _OBJECTIVE := Color("#f4de9f")
const _NUMBER := Color("#f4cf76")
const _CONTEXT := Color("#cdbf9e")
const _SHADOW := Color("#100f0b")
const _OUTLINE := Color("#211e15")
const _ART_KEYS := [
	"roster", "bp", "bp_max", "objective", "objective_visible",
	"hero_hp", "hero_max_hp", "hero_anchor", "enemy", "enemy_anchor", "combat", "feedback", "context",
]

var _state: Dictionary = {}
var _regular: Font
var _bold: Font


static func mount(host: Node) -> Control:
	var existing := host.get_node_or_null(NodePath(_LAYER_NAME))
	if existing != null:
		return existing.get_node_or_null(^"MissionHUD") as Control
	var layer := CanvasLayer.new()
	layer.name = _LAYER_NAME
	layer.layer = 1
	var hud := (load(_SCRIPT_PATH) as GDScript).new() as Control
	hud.name = &"MissionHUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.focus_mode = Control.FOCUS_NONE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	host.add_child(layer)
	return hud


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_regular = _make_font(400)
	_bold = _make_font(700)
	resized.connect(queue_redraw)


func _make_font(weight: int) -> Font:
	var font := SystemFont.new()
	# DejaVu Sans is the reference. A shipped font also works on devices
	# without a desktop font service or without DejaVu Sans installed.
	font.font_names = PackedStringArray(["DejaVu Sans"])
	font.font_weight = weight
	font.allow_system_fallback = false
	if font.has_char(65):
		return font
	const FALLBACK := "res://assets/fonts/SourceSans3.ttf"
	if ResourceLoader.exists(FALLBACK):
		var fallback := FontVariation.new()
		fallback.base_font = load(FALLBACK) as Font
		fallback.variation_opentype = {&"wght": float(weight)}
		font.fallbacks = [fallback]
	if font.has_char(65):
		return font
	return ThemeDB.fallback_font


## Arrays and dictionaries are copied: mutable caller-owned snapshots must not
## change the rendered state or prevent a later change from being detected.
func present(state: Dictionary) -> void:
	var next: Dictionary = {}
	for key: String in _ART_KEYS:
		if state.has(key):
			next[key] = state[key]
	if next == _state:
		return
	_state = next.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if _state.is_empty() or _regular == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var scale_factor := minf(vp.x / _REFERENCE.x, vp.y / _REFERENCE.y)
	if scale_factor <= 0.0:
		return
	var view := vp / scale_factor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)

	var combat := bool(_state.get("combat", false))
	var roster: Variant = _state.get("roster", [])
	if roster is Array:
		_draw_roster(roster, view.x, combat)
	var enemy: Variant = _state.get("enemy", {})
	if combat and enemy is Dictionary and not enemy.is_empty():
		_draw_enemy(enemy, view.x)
		var enemy_anchor: Variant = _state.get("enemy_anchor")
		if enemy_anchor is Vector2 and enemy_anchor.is_finite():
			var marker: Vector2 = enemy_anchor / scale_factor
			if Rect2(Vector2.ZERO, view).has_point(marker):
				_brackets(marker)
	var anchor: Variant = _state.get("hero_anchor")
	if combat and anchor is Vector2 and anchor.is_finite() and _has_stat(_state.get("hero_hp"), _state.get("hero_max_hp")):
		var foot: Vector2 = anchor / scale_factor
		if foot.x >= 39.0 and foot.x <= view.x - 39.0 and foot.y >= 1.0 and foot.y <= view.y - 6.0:
			_hp(Vector2(foot.x - 38.0, foot.y), 76.0,
				_ratio(_state.get("hero_hp", 0.0), _state.get("hero_max_hp", 0.0)))
	var objective := str(_state.get("objective", ""))
	if bool(_state.get("objective_visible", true)) and not objective.is_empty():
		_label(Vector2(view.x * 0.5, view.y - 95.0), objective, 17, _OBJECTIVE, false, 0, 1.5, view.x - 56.0)
	var context := str(_state.get("context", ""))
	if not context.is_empty():
		_label(Vector2(view.x * 0.5, view.y - 116.0), context, 14, _CONTEXT, false, 0, 1.25, view.x - 56.0)
	var feedback := str(_state.get("feedback", ""))
	if not feedback.is_empty():
		var offset := 137.0 if not context.is_empty() else 120.0
		_label(Vector2(view.x * 0.5, view.y - offset), feedback, 16, _IVORY, true, 0, 1.35, view.x - 56.0)
	if _has_stat(_state.get("bp"), _state.get("bp_max")):
		_draw_resource(Vector2(view.x * 0.5 - 338.0, view.y - 60.0))


func _draw_roster(roster: Array, view_width: float, combat: bool) -> void:
	var y := 47.0
	for entry: Variant in roster:
		if not entry is Dictionary:
			continue
		var selected := bool(entry.get("selected", false))
		var size_px := 21 if selected else 17
		var text := _unit_name(entry)
		var text_limit := minf(310.0, view_width * 0.43 - 80.0)
		if _has_stat(entry.get("hp"), entry.get("max_hp")):
			_hp(Vector2(62.0, y), 166.0 if selected else 106.0,
				_ratio(entry.hp, entry.max_hp), selected)
		elif selected:
			_diamond(Vector2(49.0, y + 16.0), 9.0)
		var label_y := y + (12.0 if selected else 6.0)
		_label(Vector2(61.0, label_y), text, size_px, _IVORY, selected, -1, 1.5, text_limit)
		if combat and bool(entry.get("engaged", false)):
			var face := _bold if selected else _regular
			var text_width := minf(text_limit, face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
			_sword(Vector2(61.0 + text_width + 12.0, label_y + 8.0))
		y += 42.0 if selected else 31.0


func _draw_enemy(enemy: Dictionary, view_width: float) -> void:
	var right := view_width - 50.0
	_hp(Vector2(right - 122.0, 50.0), 122.0,
		_ratio(enemy.get("hp", 0.0), enemy.get("max_hp", 0.0)), false, true)
	_label(Vector2(right, 56.0), _unit_name(enemy), 19, _IVORY, false, 1, 1.5, view_width * 0.43 - 50.0)


func _unit_name(entry: Dictionary) -> String:
	var display_name := str(entry.get("name", ""))
	return "%s Lv.%s" % [display_name, entry.level] if entry.has("level") else display_name


func _draw_resource(origin: Vector2) -> void:
	const WIDTH := 685.0
	var balance: Variant = _state.bp
	var ratio := _ratio(balance, _state.bp_max)
	_frame(origin, WIDTH, 18.0, 12.0)
	_diamond(origin + Vector2(-13, 9), 22.0, "BP")
	_rect(origin + Vector2(13, 5), Vector2(WIDTH - 30.0, 8.0), Color("#312b21"))
	if ratio > 0.0:
		var fill := (WIDTH - 48.0) * ratio
		_rect(origin + Vector2(13, 5), Vector2(fill, 8.0), Color("#9b8f70"))
		_rect(origin + Vector2(13, 5), Vector2(fill, 2.0), Color("#eddbaf"))
		_rect(origin + Vector2(13, 11), Vector2(fill, 2.0), Color("#62563e"))
	var number := str(roundi(float(balance))) if _is_numeric(balance) else str(balance)
	_label(origin + Vector2(WIDTH - 32.0, 1.0), number, 16, _NUMBER, true, 1, 1.1, 96.0)


func _hp(pos: Vector2, width: float, ratio: float, selected := false, hostile := false) -> void:
	if selected:
		_frame(pos + Vector2(-12, -4), width + 24.0, 16.0, 9.0)
		_diamond(pos + Vector2(-13, 4), 11.0)
	else:
		_rect(pos - Vector2.ONE, Vector2(width + 2.0, 6.0), Color("#281a14"))
	var height := 7.0 if selected else 4.0
	_rect(pos, Vector2(width, height), Color("#533123") if hostile else Color("#433523"))
	var fill := maxf(0.0, width * ratio - 1.0)
	if fill <= 0.0:
		return
	_rect(pos, Vector2(fill, height), Color("#b78844") if hostile else Color("#6b962c"))
	_rect(pos, Vector2(fill, 1.1), Color("#e7ba6a") if hostile else Color("#b4d783"))
	draw_line(pos + Vector2(0, height), pos + Vector2(fill, height),
		Color("#634315") if hostile else Color("#4c6922"), 0.7, true)


func _frame(origin: Vector2, w: float, h: float, tip: float) -> void:
	var hull := _points(origin, [
		Vector2(0, h * 0.5), Vector2(tip, 0), Vector2(w - tip, 0),
		Vector2(w, h * 0.5), Vector2(w - tip, h), Vector2(tip, h),
	])
	_polygon(_points(Vector2(1, 2), hull), Color(0.027, 0.023, 0.016, 0.82))
	_polygon(hull, Color("#292218"), Color("#6f603f"), 2.0)
	var bevel := _points(origin, [
		Vector2(2, h * 0.5), Vector2(tip + 0.4, 1.5), Vector2(w - tip - 0.5, 1.5),
		Vector2(w - 2.0, h * 0.5), Vector2(w - tip - 0.5, h - 1.5), Vector2(tip + 0.4, h - 1.5),
	])
	_polygon(bevel, Color("#18150e"), Color("#e0d0a0"), 1.15)
	draw_polyline(bevel.slice(0, 4), Color("#fff2bc"), 0.55, true)


func _diamond(origin: Vector2, r: float, legend := "") -> void:
	var corners := _points(origin, [Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r)])
	_polygon(_points(Vector2(1, 2), corners), Color("#100d07"))
	_polygon(corners, Color("#282115"), Color("#a7966b"), 2.0)
	var inner := r - 4.0
	_polygon(_points(origin, [
		Vector2(-inner, 0), Vector2(0, -inner), Vector2(inner, 0), Vector2(0, inner),
	]), Color("#18140d"), Color("#e3d19c"), 1.0)
	for side: float in [-1.0, 1.0]:
		draw_polyline(_points(origin, [
			Vector2(side * inner, 0), Vector2(side * (r - 7.0), -2),
			Vector2(side * (r - 7.0), 2), Vector2(side * inner, 0),
		]), Color("#796842"), 0.7, true)
	if not legend.is_empty():
		_label(origin - Vector2(0, 6), legend, 16, Color("#f3cc71"), true, 0, 0.7, 35.0)


func _brackets(origin: Vector2) -> void:
	const HIGHLIGHT := Color("#ee5a39")
	draw_polyline(_points(origin, [
		Vector2(-13, -9), Vector2(-23, -5), Vector2(-27, 0),
		Vector2(-26, 4), Vector2(-21, 8), Vector2(-16, 10),
	]), HIGHLIGHT, 2.0, true)
	draw_polyline(_points(origin, [
		Vector2(16, -8), Vector2(24, -4), Vector2(28, 1),
		Vector2(25, 6), Vector2(20, 9),
	]), HIGHLIGHT, 2.0, true)


func _sword(origin: Vector2) -> void:
	draw_line(origin + Vector2(-4, 5), origin + Vector2(5, -5), Color("#36180f"), 4.5, true)
	_polygon(_points(origin, [
		Vector2(-4, 2), Vector2(4, -7), Vector2(7, -6), Vector2(6, -3), Vector2(-2, 4),
	]), Color("#f3673e"), Color("#431a10"), 0.8)
	draw_line(origin + Vector2(-4, 6), origin + Vector2(-1, 3), Color("#b53824"), 2.2, true)
	draw_line(origin + Vector2(-5, 0), origin + Vector2(1, 6), Color("#e64f31"), 1.7, true)


## alignment: -1 left, 0 centered, +1 right; y supplied as visible glyph top.
func _label(pos: Vector2, value: String, px: int, color: Color, bold: bool,
		align: int, outline_width: float, max_width: float) -> void:
	if value.is_empty() or max_width <= 0.0:
		return
	var font := _bold if bold else _regular
	var caption := value.replace("\n", " ")
	var extent := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if extent > max_width:
		var cut := caption.substr(0, mini(caption.length(), 120))
		while not cut.is_empty():
			cut = cut.substr(0, cut.length() - 1)
			caption = cut.strip_edges() + "…"
			extent = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			if extent <= max_width:
				break
	var baseline := pos + Vector2(-extent * (align + 1) / 2.0, px * 0.76)
	draw_string_outline(font, baseline + Vector2(0.8, 1.2), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, _SHADOW)
	draw_string_outline(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT,
		-1, px, maxi(1, roundi(outline_width * 2.0)), _OUTLINE)
	draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _rect(origin: Vector2, size_px: Vector2, color: Color) -> void:
	draw_rect(Rect2(origin, size_px), color)


func _polygon(points: PackedVector2Array, fill: Color, stroke := Color.TRANSPARENT, thickness := 0.0) -> void:
	draw_colored_polygon(points, fill)
	if thickness > 0.0:
		var border := points.duplicate()
		border.append(points[0])
		draw_polyline(border, stroke, thickness, true)


func _points(origin: Vector2, offsets: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for offset: Vector2 in offsets:
		result.append(origin + offset)
	return result


func _is_numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _has_stat(value: Variant, maximum: Variant) -> bool:
	return _is_numeric(value) and _is_numeric(maximum) and float(value) >= 0.0 and float(maximum) > 0.0


func _ratio(value: Variant, maximum: Variant) -> float:
	if not _is_numeric(value) or not _is_numeric(maximum) or float(maximum) <= 0.0:
		return 0.0
	return clampf(float(value) / float(maximum), 0.0, 1.0)
