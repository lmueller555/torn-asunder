extends Control
## North-up battlefield display. Only caller-supplied, currently visible
## enemies can appear: this control never queries the battlefield or scene tree.

signal point_requested(battlefield_point: Vector2)

enum ObjectiveKind { PICKUP, EXIT, ALERT }
enum Icon { HERO, ALLY, ENEMY, PICKUP, EXIT, ALERT }

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
	## Four ground-plane corners in perimeter order, in the same X/Z space.
	var camera_footprint := PackedVector2Array()


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


@export var terrain_texture: Texture2D:
	set(value):
		terrain_texture = value
		queue_redraw()
@export var click_to_focus := false:
	set(value):
		click_to_focus = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE

var _field_bounds := Rect2()
var _glyphs: Array[Glyph] = []
var _clipped_sector: Array[PackedVector2Array] = []


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP if click_to_focus else Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(170.0, 132.0)


func set_field_bounds(bounds: Rect2) -> void:
	var normalized := bounds.abs() if bounds.position.is_finite() and bounds.size.is_finite() else Rect2()
	if normalized == _field_bounds:
		return
	_field_bounds = normalized
	_glyphs.clear()
	_clipped_sector.clear()
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
		for marker in snapshot.allies:
			_add_marker(marker, Icon.ALLY, marker != null and marker.id == snapshot.selected_ally)
		_add_marker(snapshot.hero, Icon.HERO)
		if _field_bounds.has_area() and _is_polygon(snapshot.camera_footprint):
			_clipped_sector = Geometry2D.intersect_polygons(snapshot.camera_footprint, _bounds_polygon())
	queue_redraw()


## Fitted, letterboxed map rectangle in this control's local pixels.
func map_rect() -> Rect2:
	var available := (size - Vector2.ONE * PADDING * 2.0).max(Vector2.ZERO)
	if not _field_bounds.has_area():
		return Rect2(size * 0.5, Vector2.ZERO)
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
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Variant = unproject(event.position)
	if point != null:
		point_requested.emit(point)
		accept_event()


func _draw() -> void:
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
