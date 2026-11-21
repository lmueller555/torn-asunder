extends Control
## Opt-in route-only drawing; callers supply one selected ally's public plan.
## No enemy, terrain, world-order, or route-selection queries.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const LABEL_SIZE := 12

var _waypoints := PackedVector2Array()
var _active_leg := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## An omitted origin shows only the planned route. A caller supplies the ally's
## current position only when it is actually marching toward the queue head.
func show_route(map: Minimap, pending: PackedVector2Array, active_from: Variant = null) -> void:
	_waypoints.clear()
	_active_leg.clear()
	if map and map.map_rect().has_area():
		for point in pending:
			var pixel := map.project(point)
			if not point.is_finite() or map.unproject(pixel) == null:
				_waypoints.clear()
				break
			_waypoints.append(pixel)
		if not _waypoints.is_empty() and active_from is Vector2 and active_from.is_finite():
			var origin := map.project(active_from)
			if map.unproject(origin) != null:
				_active_leg.append(origin)
				_active_leg.append(_waypoints[0])
	queue_redraw()


func clear_route() -> void:
	_waypoints.clear()
	_active_leg.clear()
	queue_redraw()


func waypoint_pixels() -> PackedVector2Array:
	return _waypoints.duplicate()


func active_leg_pixels() -> PackedVector2Array:
	return _active_leg.duplicate()


func _draw() -> void:
	if _waypoints.size() > 1:
		draw_polyline(_waypoints, Color(Minimap.SECTOR, 0.65), 1.5, true)
	if _active_leg.size() == 2:
		draw_line(_active_leg[0], _active_leg[1], Minimap.INK, 4.5, true)
		draw_line(_active_leg[0], _active_leg[1], Minimap.PICKUP, 2.6, true)
	for index in _waypoints.size():
		var point := _waypoints[index]
		var tint := Minimap.PICKUP if index == 0 and not _active_leg.is_empty() else Minimap.SECTOR
		draw_circle(point, 2.6, tint, true, -1.0, true)
		# Offset the badge so the reticle can sit on a point without hiding its number.
		var badge := point + Vector2(0.0, 12.0 if point.y < 20.0 else -12.0)
		draw_line(point, badge, tint, 1.0, true)
		draw_circle(badge, 6.5, Minimap.INK, true, -1.0, true)
		var number := str(index + 1)
		var font := get_theme_default_font()
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(font, badge + Vector2(-width * 0.5, 4.0), number,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, tint)
