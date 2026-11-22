extends Control
## North-up battlefield display. Only caller-supplied, currently visible
## enemies can appear: this control never queries the battlefield or scene tree.

signal point_requested(battlefield_point: Vector2)
signal move_requested(battlefield_point: Vector2)
signal append_requested(battlefield_point: Vector2)

enum ObjectiveKind { PICKUP, EXIT, ALERT }
enum Icon { HERO, ALLY, ENEMY, PICKUP, EXIT, ALERT, NEUTRAL }

const PADDING := 11.0
const BACK := Color("#101b20")
const FIELD := Color("#253330")
const EDGE := Color("#62736d")
const GRID := Color(0.69, 0.77, 0.70, 0.13)
const INK := Color("#10191e")
const HERO := Color("#fff1c4")
const ALLY := Color("#7edbb8")
const ENEMY := Color("#ff8d80")
const PICKUP := Color("#ffcc77")
const EXIT := Color("#aee3f5")
const ALERT := Color("#f3a76f")
const SECTOR := Color("#c7e8f5")

const TACTICAL_COMPACT_SIZE := Vector2(225.0, 165.0)
const TACTICAL_EXPANDED_SIZE := Vector2(432.0, 316.0)
const TACTICAL_MARGIN := Vector2(52.0, 50.0)
const TACTICAL_FRAME := Color("#131912e8")
const TACTICAL_FIELD := Color("#394336")
const TACTICAL_EDGE := Color("#a69c7190")
const TACTICAL_TEXT := Color("#eedca5")
const TACTICAL_UNIT_GREEN := Color("#b8df83")
const TACTICAL_UNIT_RED := Color("#e8876c")
const TACTICAL_UNIT_BLUE := Color("#82c0dd")
const ROUTE_CYCLE_SECONDS := 0.5
const ROUTE_INK := Color("#222b1c")
const ROUTE_BRIGHT := Color("#76c33e")
const ROUTE_HIGHLIGHT := Color("#9bdb58")
const ROUTE_MUTED := Color("#788e58")
const ROUTE_CHEVRON := Color("#dcff9d")
const MAP_CURSOR := Color("#e4ddba")
const FOG_DARKNESS := 0.64
const FOG_SIZE := Vector2i(96, 70)


class Marker:
	var id: StringName
	var position: Vector2
	var heading: Vector2
	var objective_kind: ObjectiveKind

	func _init(key: StringName, at: Vector2, facing := Vector2.UP, kind := ObjectiveKind.PICKUP) -> void:
		id = key
		position = at
		heading = facing
		objective_kind = kind


class Frame:
	var hero: Marker
	var allies: Array[Marker] = []
	var objectives: Array[Marker] = []
	var visible_enemies: Array[Marker] = []
	var selected_ally: StringName
	var selected_hero := false
	## Optional known/visible neutral units, never inferred from terrain art.
	var visible_neutrals: Array[Marker] = []
	## Four ground-plane corners in perimeter order, in the same X/Z space.
	var camera_footprint := PackedVector2Array()
	## Player-owned marker id -> PackedVector2Array(current position, queued stops).
	var platoon_routes: Dictionary = {}
	## Optional explicit stops after the origin when the route includes navigation bends.
	var platoon_stops: Dictionary = {}
	## Optional world X/Z; separate from the committed route destination.
	var command_cursor: Variant = null
	## Selected troop's actual attack radius, never detection/aggro radius.
	var attack_range := 0.0
	## Optional explored world regions. Empty means no exploration model available.
	var explored_areas: Array[Rect2] = []


class Glyph:
	var id: StringName
	var position: Vector2
	var heading: Vector2
	var icon: Icon
	var selected: bool

	func _init(marker: Marker, shape: Icon, is_selected := false) -> void:
		id = marker.id
		position = marker.position
		heading = marker.heading
		icon = shape
		selected = is_selected


## Legacy layouts stay unchanged unless an authored HUD opts in.
@export var tactical_style := false:
	set(value):
		tactical_style = value
		clip_contents = value
		_update_route_animation()
		update_minimum_size()
		queue_redraw()

@export var terrain_texture: Texture2D:
	set(value):
		terrain_texture = value
		queue_redraw()
@export var click_to_focus := false:
	set(value):
		click_to_focus = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE

@export var right_click_to_move := false

var _tactical_panel: PanelContainer
var _tactical_expanded := false
var _field_bounds := Rect2()
var _glyphs: Array[Glyph] = []
var _clipped_sector: Array[PackedVector2Array] = []
var _ally_routes: Dictionary = {}
var _ally_stops: Dictionary = {}
var _selected_route_id: StringName
var _route_phase := 0.0
var _command_cursor: Variant = null
var _attack_range := 0.0
var _explored_areas: Array[Rect2] = []
var _fog_texture: ImageTexture


func _ready() -> void:
	resized.connect(queue_redraw)
	visibility_changed.connect(_update_route_animation)
	_update_route_animation()
	mouse_filter = Control.MOUSE_FILTER_STOP if click_to_focus else Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return TACTICAL_COMPACT_SIZE if tactical_style else Vector2(170.0, 132.0)


static func tactical_overlay_size(expanded: bool) -> Vector2:
	return TACTICAL_EXPANDED_SIZE if expanded else TACTICAL_COMPACT_SIZE


## Place a direct Control/CanvasLayer child. A legacy map in a Container
## instead sizes/anchors its wrapper; it must not reposition the map child.
## Expansion never changes visibility, cursor mode, projection or accepted orders.
func place_tactical_overlay(expanded: bool) -> void:
	if not tactical_style or get_parent() is Container:
		return
	_place_tactical(self, expanded)


## One-time adapter for existing Panel/Margin/Readout/Map scenes.
## Keep the Widget and its passive route/reticle overlay under the same parent.
func configure_tactical_panel(panel: PanelContainer, labels: Array[Control]) -> void:
	if not panel or not panel.is_ancestor_of(self):
		return
	_tactical_panel = panel
	tactical_style = true
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for label in labels:
		if label and panel.is_ancestor_of(label):
			label.hide()
	var margins := panel.get_node_or_null(^"Margin") as MarginContainer
	if margins:
		for side in ["left", "right", "top", "bottom"]:
			margins.add_theme_constant_override("margin_" + side, 0)
	_place_tactical(panel, false)


func set_tactical_expanded(expanded: bool) -> void:
	if not tactical_style or expanded == _tactical_expanded:
		return
	_tactical_expanded = expanded
	if _tactical_panel:
		_place_tactical(_tactical_panel, expanded)
	else:
		place_tactical_overlay(expanded)


## Unbound by legacy authored commands; M remains the 3D camera overview.
## Callers gate the current controller and consume only their own toggle input.
static func is_tactical_toggle(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return key == KEY_N and event.pressed and not event.echo
	return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP \
		and event.pressed and Input.get_joy_axis(event.device, JOY_AXIS_TRIGGER_LEFT) > 0.5


static func _place_tactical(control: Control, expanded: bool) -> void:
	var extent := tactical_overlay_size(expanded)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_END
	# Set ends before starts so a lower-right legacy panel cannot trigger
	# nearest-anchor expansion with its prior minimum.
	control.offset_right = -TACTICAL_MARGIN.x
	control.offset_left = -TACTICAL_MARGIN.x - extent.x
	control.offset_top = TACTICAL_MARGIN.y
	control.offset_bottom = TACTICAL_MARGIN.y + extent.y


func set_field_bounds(bounds: Rect2) -> void:
	var normalized := bounds.abs() if bounds.position.is_finite() and bounds.size.is_finite() else Rect2()
	if normalized == _field_bounds:
		return
	_field_bounds = normalized
	_glyphs.clear()
	_clipped_sector.clear()
	_ally_routes.clear()
	_ally_stops.clear()
	_selected_route_id = &""
	_route_phase = 0.0
	_command_cursor = null
	_attack_range = 0.0
	_set_explored([])
	_update_route_animation()
	queue_redraw()


func show_frame(snapshot: Frame) -> void:
	_glyphs.clear()
	_clipped_sector.clear()
	if snapshot:
		for marker in snapshot.objectives:
			if marker:
				match marker.objective_kind:
					ObjectiveKind.EXIT: _add_marker(marker, Icon.EXIT)
					ObjectiveKind.ALERT: _add_marker(marker, Icon.ALERT)
					_: _add_marker(marker, Icon.PICKUP)
		for marker in snapshot.visible_enemies:
			_add_marker(marker, Icon.ENEMY)
		for marker in snapshot.visible_neutrals:
			_add_marker(marker, Icon.NEUTRAL)
		for marker in snapshot.allies:
			_add_marker(marker, Icon.ALLY, marker != null and marker.id == snapshot.selected_ally)
		_add_marker(snapshot.hero, Icon.HERO, snapshot.selected_hero)
		if _field_bounds.has_area() and _is_polygon(snapshot.camera_footprint):
			_clipped_sector = Geometry2D.intersect_polygons(snapshot.camera_footprint, _bounds_polygon())
	_sync_tactical_frame(snapshot)
	queue_redraw()


## Tactical charts fill the approved landscape face; legacy charts letterbox.
func map_rect() -> Rect2:
	var padding := 4.0 if tactical_style else PADDING
	var available := (size - Vector2.ONE * padding * 2.0).max(Vector2.ZERO)
	if not _field_bounds.has_area():
		return Rect2(size * 0.5, Vector2.ZERO)
	if tactical_style:
		return Rect2(Vector2.ONE * padding, available)
	var scale_factor := minf(available.x / _field_bounds.size.x, available.y / _field_bounds.size.y)
	var fitted := _field_bounds.size * scale_factor
	return Rect2((size - fitted) * 0.5, fitted)


## +X is east, +Z (the Vector2's Y) south. Elevation never affects projection.
func project(point: Vector2) -> Vector2:
	var map := map_rect()
	if not map.has_area():
		return map.position
	return _project_to(point, map)


func unproject(pixel: Vector2) -> Variant:
	var map := map_rect()
	if not map.has_area() or not _contains(map, pixel):
		return null
	return _field_bounds.position + (pixel - map.position) / map.size * _field_bounds.size


func marker_pixel(id: StringName) -> Variant:
	for marker in _glyphs:
		if marker.id == id:
			return project(marker.position)
	return null


func sector_pixels() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	var map := map_rect()
	if map.has_area():
		for polygon in _clipped_sector:
			if polygon.size() < 3:
				continue
			var pixels := PackedVector2Array()
			for point in polygon:
				pixels.append(_project_to(point, map))
			polygons.append(pixels)
	return polygons


func _gui_input(event: InputEvent) -> void:
	if not click_to_focus or not event is InputEventMouseButton or not event.pressed:
		return
	var is_move: bool = right_click_to_move and event.button_index == MOUSE_BUTTON_RIGHT
	if event.button_index != MOUSE_BUTTON_LEFT and not is_move:
		return
	var point: Variant = unproject(event.position)
	# The map consumes its own clicks even on the letterbox. Do not issue
	# an unrelated projected world order through the map's padding.
	accept_event()
	if point == null:
		return
	if is_move:
		if tactical_style and event.ctrl_pressed and append_requested.has_connections():
			append_requested.emit(point)
		else:
			move_requested.emit(point)
	else:
		point_requested.emit(point)


func _draw() -> void:
	if tactical_style:
		_draw_tactical()
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	var map := map_rect()
	if not map.has_area():
		return
	draw_rect(map, FIELD)
	if terrain_texture:
		draw_texture_rect(terrain_texture, map, false)
	for i in range(1, 5):
		var mark := map.position + map.size * float(i) / 5.0
		draw_line(Vector2(mark.x, map.position.y), Vector2(mark.x, map.end.y), GRID, 1.0)
		draw_line(Vector2(map.position.x, mark.y), Vector2(map.end.x, mark.y), GRID, 1.0)
	for polygon in sector_pixels():
		draw_colored_polygon(polygon, Color(SECTOR, 0.10))
		var closed := polygon.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, Color(SECTOR, 0.77), 1.5, true)
	draw_rect(map, EDGE, false, 1.0)
	draw_string(get_theme_default_font(), map.position + Vector2(8.0, 18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, SECTOR)
	for marker in _glyphs:
		_draw_marker(marker, _project_to(marker.position, map))


func _sync_tactical_frame(snapshot: Frame) -> void:
	if not tactical_style:
		return
	_ally_routes.clear()
	_ally_stops.clear()
	var selected: StringName = &""
	_command_cursor = null
	_attack_range = 0.0
	if snapshot:
		if snapshot.command_cursor is Vector2 and _contains(_field_bounds, snapshot.command_cursor):
			_command_cursor = snapshot.command_cursor
		_attack_range = maxf(0.0, snapshot.attack_range) if is_finite(snapshot.attack_range) else 0.0
		for glyph in _glyphs:
			if glyph.icon != Icon.ALLY and glyph.icon != Icon.HERO:
				continue
			var supplied: Variant = snapshot.platoon_routes.get(glyph.id)
			if not supplied is PackedVector2Array or supplied.size() < 2:
				continue
			# Only trust route ownership from actual player glyphs, and use their live
			# position as the origin. An invalid stop terminates the displayed route.
			var points := PackedVector2Array([glyph.position])
			for i in range(1, supplied.size()):
				var point: Vector2 = supplied[i]
				if not _contains(_field_bounds, point):
					break
				if not points[-1].is_equal_approx(point):
					points.append(point)
			if points.size() > 1:
				_ally_routes[glyph.id] = points
				var supplied_stops: Variant = snapshot.platoon_stops.get(glyph.id)
				if supplied_stops is PackedVector2Array:
					var stops := PackedVector2Array()
					for stop: Vector2 in supplied_stops:
						if not _contains(_field_bounds, stop):
							break
						stops.append(stop)
					_ally_stops[glyph.id] = stops
				else:
					_ally_stops[glyph.id] = points.slice(1)
				if glyph.selected:
					selected = glyph.id
		_set_explored(snapshot.explored_areas)
	else:
		_set_explored([])
	if _selected_route_id != selected:
		_route_phase = 0.0
	_selected_route_id = selected
	_update_route_animation()


func _set_explored(areas: Array[Rect2]) -> void:
	if areas == _explored_areas:
		return
	_explored_areas = areas.duplicate()
	if areas.is_empty() or not _field_bounds.has_area():
		_fog_texture = null
		return
	var fog := Image.create(FOG_SIZE.x, FOG_SIZE.y, false, Image.FORMAT_RGBA8)
	var dark := Color(0.09, 0.11, 0.085, FOG_DARKNESS)
	fog.fill(dark)
	var bounds := Rect2i(Vector2i.ZERO, FOG_SIZE)
	var map := Rect2(Vector2.ZERO, Vector2(FOG_SIZE))
	var reveal: Array[Rect2i] = []
	for region in areas:
		if not region.position.is_finite() or not region.size.is_finite():
			continue
		var overlap := region.abs().intersection(_field_bounds)
		if not overlap.has_area():
			continue
		var lo := Vector2i(_project_to(overlap.position, map).floor())
		var hi := Vector2i(_project_to(overlap.end, map).ceil())
		reveal.append(Rect2i(lo, hi - lo).intersection(bounds))
	for rect in reveal:
		fog.fill_rect(rect.grow(1).intersection(bounds), Color(dark, FOG_DARKNESS * 0.5))
	for rect in reveal:
		fog.fill_rect(rect, Color(dark, 0.0))
	_fog_texture = ImageTexture.create_from_image(fog)


func _update_route_animation() -> void:
	set_process(tactical_style and is_visible_in_tree() and not _selected_route_id.is_empty())


func _process(delta: float) -> void:
	_route_phase = fposmod(_route_phase + delta / ROUTE_CYCLE_SECONDS, 1.0)
	queue_redraw()


func _draw_tactical() -> void:
	var face := Rect2(Vector2.ZERO, size)
	var scale_factor := clampf(size.x / TACTICAL_EXPANDED_SIZE.x, 0.5, 1.5)
	draw_rect(face, TACTICAL_FRAME)
	var map := map_rect()
	if map.has_area():
		draw_rect(map, TACTICAL_FIELD)
		if terrain_texture:
			draw_texture_rect(terrain_texture, map, false, Color(1.0, 0.98, 0.89))
		if _fog_texture:
			draw_texture_rect(_fog_texture, map, false)
		if _is_expanded_face() and _attack_range > 0.0:
			for marker in _glyphs:
				if marker.selected and (marker.icon == Icon.HERO or marker.icon == Icon.ALLY):
					_draw_attack_ring(marker.position, map, scale_factor)
		for key in _ally_routes:
			if key != _selected_route_id:
				_draw_route(_ally_routes[key], _ally_stops[key], map, false, scale_factor)
		var active_path: Curve2D
		if _ally_routes.has(_selected_route_id):
			active_path = _draw_route(_ally_routes[_selected_route_id], _ally_stops[_selected_route_id],
				map, true, scale_factor)
		for marker in _glyphs:
			_draw_tactical_marker(marker, _project_to(marker.position, map), scale_factor)
		if active_path:
			_draw_chevron(route_chevron(active_path, _route_phase, scale_factor), scale_factor)
		if _is_expanded_face() and _command_cursor is Vector2:
			_draw_cursor(_project_to(_command_cursor, map), scale_factor)
	draw_rect(face.grow(-0.5), TACTICAL_EDGE, false, 1.0)
	var font := get_theme_default_font()
	var north := Vector2(8, 16) * maxf(0.8, scale_factor)
	var font_size := maxi(9, roundi(12.0 * scale_factor))
	draw_string_outline(font, north, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, INK)
	draw_string(font, north, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TACTICAL_TEXT)


func _is_expanded_face() -> bool:
	return _tactical_expanded or size.x > (TACTICAL_COMPACT_SIZE.x + TACTICAL_EXPANDED_SIZE.x) / 2.0


func _draw_attack_ring(center: Vector2, map: Rect2, scale_factor: float) -> void:
	var ring := PackedVector2Array()
	for i in range(48):
		ring.append(_project_to(center + Vector2.from_angle(TAU * float(i) / 48.0) * _attack_range, map))
	for clipped in Geometry2D.intersect_polygons(ring, PackedVector2Array([
		map.position, Vector2(map.end.x, map.position.y), map.end, Vector2(map.position.x, map.end.y),
	])):
		# Clip the fill, but draw just the actual arc (not a false ring over the map edge).
		draw_colored_polygon(clipped, Color(0.61, 0.69, 0.34, 0.08))
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		if _contains(map, a) and _contains(map, b):
			draw_line(a, b, Color(0.66, 0.73, 0.42, 0.68), maxf(1.0, scale_factor), true)


func _route_pixels(points: PackedVector2Array, map: Rect2) -> Curve2D:
	var path := Curve2D.new()
	path.bake_interval = 2.0
	for point in points:
		path.add_point(_project_to(point, map))
	return path


func _draw_route(points: PackedVector2Array, stops: PackedVector2Array, map: Rect2,
		selected: bool, scale_factor: float) -> Curve2D:
	var path := _route_pixels(points, map)
	var length := path.get_baked_length()
	if length < 1.0:
		return path
	var width := (7.2 if selected else 4.0) * scale_factor
	var dash := (17.2 if selected else 13.0) * scale_factor
	var gap := (5.4 if selected else 4.8) * scale_factor
	var tint := ROUTE_BRIGHT if selected else ROUTE_MUTED
	draw_polyline(path.get_baked_points(), ROUTE_INK, width + 3.6 * scale_factor, true)
	var period := dash + gap
	var from := 0.0
	while from < length:
		var to := minf(length, from + dash)
		var trail := PackedVector2Array()
		var s := from
		while s < to:
			trail.append(path.sample_baked(s))
			s += 2.0
		trail.append(path.sample_baked(to))
		if trail.size() > 1:
			draw_polyline(trail, tint, width, true)
			if selected:
				for i in trail.size():
					trail[i].y -= 1.7 * scale_factor
				draw_polyline(trail, ROUTE_HIGHLIGHT, maxf(0.8, 1.15 * scale_factor), true)
		from += period
	for i in stops.size():
		var at := _project_to(stops[i], map)
		var r := (4.8 if i == stops.size() - 1 else 3.1) * scale_factor
		draw_circle(at, r + scale_factor, ROUTE_INK, true, -1.0, true)
		draw_circle(at, r, tint.lightened(0.22 if selected else 0.08), true, -1.0, true)
	return path


## Pure map-space pose. The arrow follows projected distance around bends,
## independent of frame rate and without inventing a battlefield indicator.
static func route_chevron(path: Curve2D, phase: float, scale_factor: float) -> PackedVector2Array:
	var length := path.get_baked_length()
	if length < 3.0:
		return PackedVector2Array()
	var rate := 0.09 + 0.82 * fposmod(phase, 1.0)
	var s := length * rate
	var at := path.sample_baked(s)
	var tangent := (path.sample_baked(minf(length, s + 6.0 * scale_factor))
		- path.sample_baked(maxf(0.0, s - 6.0 * scale_factor))).normalized()
	if tangent.is_zero_approx():
		tangent = (path.sample_baked(minf(length, s + 2.0)) - at).normalized()
	if tangent.is_zero_approx():
		return PackedVector2Array()
	var side := tangent.orthogonal()
	# Scale down for an unusually short order so the arrow does not overwhelm it.
	var k := minf(scale_factor, length / 22.0)
	return PackedVector2Array([
		at + tangent * 13.0 * k, at - tangent * 8.7 * k + side * 8.6 * k,
		at - tangent * 4.2 * k, at - tangent * 8.7 * k - side * 8.6 * k,
	])


func _draw_chevron(vertices: PackedVector2Array, scale_factor: float) -> void:
	if vertices.size() != 4:
		return
	draw_colored_polygon(vertices, ROUTE_CHEVRON)
	vertices.append(vertices[0])
	draw_polyline(vertices, ROUTE_INK, maxf(1.0, 2.0 * scale_factor), true)


func _draw_cursor(at: Vector2, scale_factor: float) -> void:
	var radius := 6.5 * scale_factor
	draw_circle(at, radius, ROUTE_INK, false, 3.0 * scale_factor, true)
	draw_circle(at, radius, MAP_CURSOR, false, 1.4 * scale_factor, true)
	for ray in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(at + ray * radius, at + ray * (radius + 4.0 * scale_factor), MAP_CURSOR,
			maxf(0.75, scale_factor), true)


func _draw_tactical_marker(marker: Glyph, at: Vector2, scale_factor: float) -> void:
	match marker.icon:
		Icon.HERO, Icon.ALLY, Icon.ENEMY, Icon.NEUTRAL:
			var tint := TACTICAL_UNIT_GREEN
			if marker.icon == Icon.ENEMY:
				tint = TACTICAL_UNIT_RED
			elif marker.icon == Icon.NEUTRAL:
				tint = TACTICAL_UNIT_BLUE
			draw_circle(at, 6.0 * scale_factor, INK, true, -1, true)
			draw_circle(at, 4.4 * scale_factor, tint, true, -1, true)
		_:
			# Retain objective shape semantics at the presentation's smaller scale.
			draw_set_transform(at, 0.0, Vector2.ONE * scale_factor)
			_draw_marker(marker, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
	if marker.selected:
		# Clamp only the emblem at the border, never the projected unit point.
		var pole := (at + Vector2(0, -18) * scale_factor).clamp(Vector2(5, 5),
			(size - Vector2(19, 15) * scale_factor).max(Vector2(5, 5)))
		var pennant := PackedVector2Array([pole, pole + Vector2(16, 4) * scale_factor,
			pole + Vector2(0, 9) * scale_factor])
		draw_line(pole, at, INK, maxf(1.2, 4.0 * scale_factor), true)
		draw_line(pole, at, TACTICAL_TEXT, maxf(0.8, 1.5 * scale_factor), true)
		draw_colored_polygon(pennant, TACTICAL_TEXT)
		pennant.append(pennant[0])
		draw_polyline(pennant, ROUTE_INK, maxf(0.8, scale_factor), true)


func _draw_marker(marker: Glyph, at: Vector2) -> void:
	match marker.icon:
		Icon.HERO:
			var facing := marker.heading.normalized() if marker.heading.is_finite() and not marker.heading.is_zero_approx() else Vector2.UP
			var yaw := Vector2.UP.angle_to(facing)
			var arrow := PackedVector2Array()
			for vertex in [Vector2(0, -9), Vector2(6, 6), Vector2(0, 3), Vector2(-6, 6)]:
				arrow.append(at + vertex.rotated(yaw))
			draw_colored_polygon(arrow, HERO)
			arrow.append(arrow[0])
			draw_polyline(arrow, INK, 1.4, true)
		Icon.ALLY:
			if marker.selected:
				draw_rect(Rect2(at - Vector2.ONE * 8.0, Vector2.ONE * 16.0), PICKUP, false, 1.8)
			draw_rect(Rect2(at - Vector2.ONE * 5.0, Vector2.ONE * 10.0), INK)
			draw_rect(Rect2(at - Vector2.ONE * 3.5, Vector2.ONE * 7.0), ALLY)
		Icon.NEUTRAL:
			draw_circle(at, 5.8, INK, true, -1.0, true)
			draw_circle(at, 4.0, TACTICAL_UNIT_BLUE, true, -1.0, true)
		Icon.ENEMY:
			draw_circle(at, 5.8, INK, true, -1.0, true)
			draw_circle(at, 4.0, ENEMY, true, -1.0, true)
		Icon.PICKUP:
			var diamond := PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 0),
				at + Vector2(0, 7), at + Vector2(-7, 0)])
			draw_colored_polygon(diamond, PICKUP)
			diamond.append(diamond[0])
			draw_polyline(diamond, INK, 1.3, true)
			draw_circle(at, 1.4, INK)
		Icon.EXIT:
			var gate := PackedVector2Array([at + Vector2(-5, 5), at + Vector2(-5, -5),
				at + Vector2(5, -5), at + Vector2(5, 5)])
			draw_polyline(gate, INK, 4.0, true)
			draw_polyline(gate, EXIT, 2.0, true)
			draw_line(at - Vector2(3, 0), at + Vector2(3, 0), EXIT, 1.5, true)

		Icon.ALERT:
			var caution := PackedVector2Array([at + Vector2(0, -8), at + Vector2(8, 6), at + Vector2(-8, 6)])
			draw_colored_polygon(caution, ALERT)
			caution.append(caution[0])
			draw_polyline(caution, INK, 1.4, true)
			draw_line(at + Vector2(0, -3), at + Vector2(0, 1), INK, 1.5, true)
			draw_circle(at + Vector2(0, 3), 0.9, INK)


func _add_marker(marker: Marker, shape: Icon, selected := false) -> void:
	if marker and _field_bounds.has_area() and _contains(_field_bounds, marker.position):
		_glyphs.append(Glyph.new(marker, shape, selected))


func _project_to(point: Vector2, map: Rect2) -> Vector2:
	return map.position + (point - _field_bounds.position) / _field_bounds.size * map.size


func _bounds_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		_field_bounds.position, Vector2(_field_bounds.end.x, _field_bounds.position.y),
		_field_bounds.end, Vector2(_field_bounds.position.x, _field_bounds.end.y),
	])


static func _contains(rect: Rect2, point: Vector2) -> bool:
	return point.is_finite() and point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y


static func _is_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	for point in points:
		if not point.is_finite():
			return false
	return true
