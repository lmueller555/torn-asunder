extends SceneTree

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Overlay := preload("res://game/battlefield/minimap_route_overlay.gd")


func _initialize() -> void:
	var map := Minimap.new()
	var overlay := Overlay.new()
	var passed := _exercise(map, overlay) and _exercise_wide_field(map, overlay)
	overlay.free()
	map.free()
	if passed:
		print("Minimap route overlay: letterbox projection, active-vs-pending route, resizing, defensive copies, separated full-queue badges, and clear passed.")
	quit(0 if passed else 1)


func _exercise(map: Minimap, overlay: Overlay) -> bool:
	map.size = Vector2(400.0, 240.0)
	map.set_field_bounds(Rect2(-20.0, -10.0, 40.0, 20.0))
	var goals := PackedVector2Array([Vector2.ZERO, Vector2(20.0, 10.0)])
	overlay.show_route(map, goals, Vector2(-20.0, -10.0))
	if overlay.waypoint_pixels() != PackedVector2Array([Vector2(200, 120), Vector2(389, 214.5)]) \
			or overlay.active_leg_pixels() != PackedVector2Array([Vector2(11, 25.5), Vector2(200, 120)]):
		return _fail("Route diagnostics did not use the exact fitted map projection.")
	var returned := overlay.waypoint_pixels()
	returned.clear()
	if overlay.waypoint_pixels().size() != 2:
		return _fail("A caller changed the queued overlay through a returned array.")
	overlay.show_route(map, goals)
	if overlay.waypoint_pixels().size() != 2 or not overlay.active_leg_pixels().is_empty():
		return _fail("A holding or blocked formation displayed an active leg.")
	map.size = Vector2(300.0, 300.0)
	overlay.show_route(map, goals, Vector2(-20, -10))
	if overlay.waypoint_pixels()[0] != Vector2(150, 150) or overlay.active_leg_pixels()[0] != Vector2(11, 80.5):
		return _fail("Resizing did not reproject the same route on the new letterbox.")
	overlay.show_route(map, PackedVector2Array([Vector2.ZERO, Vector2(21, 0)]))
	if not overlay.waypoint_pixels().is_empty() or not overlay.active_leg_pixels().is_empty():
		return _fail("An out-of-bounds plan was partially drawn with wrong numbering.")
	overlay.show_route(map, goals, Vector2.ZERO)
	overlay.clear_route()
	return (overlay.waypoint_pixels().is_empty() and overlay.active_leg_pixels().is_empty()) \
		or _fail("Closing or clearing the plot retained its old route.")


func _exercise_wide_field(map: Minimap, overlay: Overlay) -> bool:
	# Approximate the smallest Cut command map. Eight legitimate separate
	# positions on the road are closer on screen than a single old badge.
	map.size = Vector2(170, 132)
	overlay.size = map.size
	map.set_field_bounds(Rect2(-396, -100, 792, 200))
	for end: float in [-1.0, 1.0]:
		var dense := PackedVector2Array()
		for index in range(8):
			dense.append(Vector2(end * (391 - index * 0.3), -14))
		overlay.show_route(map, dense, Vector2.ZERO)
		var badges := overlay.badge_pixels()
		if badges.size() != 8 or badges != overlay.badge_pixels():
			return _fail("A full queue did not retain one stable badge per index.")
		var pins := overlay.waypoint_pixels()
		if pins[0].distance_to(pins[7]) > 1.0 or overlay.active_leg_pixels()[1] != pins[0]:
			return _fail("The fixture was not crowded, or the active leg lost its true endpoint.")
		for index in range(8):
			var badge := badges[index]
			if not pins[index].is_equal_approx(map.project(dense[index])):
				return _fail("Packing a label moved the actual projected queue point.")
			if map.map_rect().grow(Overlay.BADGE_RADIUS).has_point(badge):
				return _fail("A crowded badge obscured the projected battlefield instead of using the letterbox.")
			if not Rect2(Vector2.ONE * 8.0, map.size - Vector2.ONE * 16.0).has_point(badge):
				return _fail("An edge badge became clipped.")
			for previous in range(index):
				if badge.distance_to(badges[previous]) < 19.99:
					return _fail("Visible badges still overlap in a full dense queue.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
