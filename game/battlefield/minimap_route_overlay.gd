extends Control
## Opt-in route-only drawing; callers supply one selected ally's public plan.
## No enemy, terrain, world-order, or route-selection queries.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const LABEL_SIZE := 15
const BADGE_RADIUS := 8.0
const BADGE_GAP := 20.0
const BADGE_INSET := 9.5

var _waypoints := PackedVector2Array()
var _active_leg := PackedVector2Array()
var _map_band := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## An omitted origin shows only the planned route. A caller supplies the ally's
## current position only when it is actually marching toward the queue head.
func show_route(map: Minimap, pending: PackedVector2Array, active_from: Variant = null) -> void:
	_waypoints.clear()
	_active_leg.clear()
	_map_band = map.map_rect() if map else Rect2()
	if _map_band.has_area():
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


## Spread only the labels when the whole-field projection crowds several
## waypoints together. Exact points, active paths, and input never move.
func badge_pixels() -> PackedVector2Array:
	var badges := PackedVector2Array()
	var extent := get_parent_control().size if get_parent_control() else size
	var safe := Rect2(Vector2.ONE * BADGE_INSET, (extent - Vector2.ONE * BADGE_INSET * 2.0).max(Vector2.ZERO))
	for index in _waypoints.size():
		var point := _waypoints[index]
		var crowded := _pin_is_crowded(index)
		var preferred := 1.0 if point.y < 20.0 else -1.0
		var chosen := point
		var found := false
		# Prefer short leaders. Alternate above/below before fanning farther
		# left or right, and search far enough for all eight queue entries.
		for step in range(_waypoints.size()):
			for side in [preferred, -preferred]:
				for lateral in [-1.0, 1.0] if step > 0 else [0.0]:
					var y: float = point.y + side * (BADGE_RADIUS + 7.0)
					if crowded and _map_band.position.y >= BADGE_INSET + BADGE_RADIUS + 3.0:
						# Use the empty north/south letterbox of long, shallow maps.
						y = (_map_band.position.y - BADGE_RADIUS - 3.0 if side < 0.0
							else _map_band.end.y + BADGE_RADIUS + 3.0)
					var candidate := Vector2(point.x + step * BADGE_GAP * lateral, y).clamp(safe.position, safe.end)
					if _badge_fits(candidate, badges):
						chosen = candidate
						found = true
						break
				if found:
					break
			if found:
				break
		badges.append(chosen)
	return badges


func _pin_is_crowded(index: int) -> bool:
	for neighbor in _waypoints.size():
		if index != neighbor and _waypoints[index].distance_squared_to(_waypoints[neighbor]) < BADGE_GAP * BADGE_GAP:
			return true
	return false


func _badge_fits(candidate: Vector2, badges: PackedVector2Array) -> bool:
	for badge in badges:
		if badge.distance_squared_to(candidate) < BADGE_GAP * BADGE_GAP:
			return false
	return true


func _draw() -> void:
	if _waypoints.size() > 1:
		draw_polyline(_waypoints, Color(Minimap.SECTOR, 0.65), 1.5, true)
	if _active_leg.size() == 2:
		draw_line(_active_leg[0], _active_leg[1], Minimap.INK, 4.5, true)
		draw_line(_active_leg[0], _active_leg[1], Minimap.PICKUP, 2.6, true)
	var captions := badge_pixels()
	for index in _waypoints.size():
		var tint := _waypoint_tint(index)
		draw_line(_waypoints[index], captions[index], tint, 1.0, true)
		draw_circle(_waypoints[index], 2.6, tint, true, -1.0, true)
	var font := get_theme_default_font()
	for index in captions.size():
		var badge := captions[index]
		var tint := _waypoint_tint(index)
		draw_circle(badge, BADGE_RADIUS, Minimap.INK, true, -1.0, true)
		draw_circle(badge, BADGE_RADIUS, tint, false, 0.75, true)
		var number := str(index + 1)
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(font, badge + Vector2(-width * 0.5, 5.0), number,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, tint)


func _waypoint_tint(index: int) -> Color:
	return Minimap.PICKUP if index == 0 and not _active_leg.is_empty() else Minimap.SECTOR
