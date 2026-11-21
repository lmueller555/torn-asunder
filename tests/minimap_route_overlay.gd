extends SceneTree

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Overlay := preload("res://game/battlefield/minimap_route_overlay.gd")


func _initialize() -> void:
	var map := Minimap.new()
	var overlay := Overlay.new()
	var passed := _exercise(map, overlay)
	overlay.free()
	map.free()
	if passed:
		print("Minimap route overlay: letterbox projection, active-vs-pending route, resizing, defensive copies and clear passed.")
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


func _fail(message: String) -> bool:
	push_error(message)
	return false
