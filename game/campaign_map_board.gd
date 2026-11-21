extends Control
## Draws a stylized Vareth map using authored shapes and lightweight markers.

const World := preload("res://game/campaign_world.gd")
const TYPE := preload("res://assets/fonts/SourceSans3.ttf")

const GOLD := Color("#efc784")
const PALE := Color("#e7dfc7")
const QUIET := Color("#afb5a3")
const BLOCKED := Color("#bb8e77")

var world: World
var selected_id := ""
var token_position := Vector2.ZERO
var completed_ids := PackedStringArray()


func point_at(map_position: Vector2) -> Vector2:
	return map_position * size


func waypoint_at(screen_point: Vector2) -> String:
	for node in world.waypoints():
		if point_at(node.map_position).distance_to(screen_point) <= 28.0:
			return node.id
	return ""


func set_token_position(value: Vector2) -> void:
	token_position = value
	queue_redraw()


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_draw_terrain()
	if world:
		for edge in world.routes():
			_draw_route(edge)
		for node in world.waypoints():
			_draw_waypoint(node)
		if not world.current_waypoint_id().is_empty():
			_draw_token()
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), Color("#706c53"), false, 1.0)


func _draw_terrain() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#263332"))
	_polygon([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.77), Vector2(0.85, 0.84),
		Vector2(0.72, 0.79), Vector2(0.59, 0.8), Vector2(0.46, 0.91),
		Vector2(0.25, 0.87), Vector2(0.17, 0.94), Vector2(0, 0.91),
	], Color("#45503d"))
	_polygon([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.16), Vector2(0.82, 0.26),
		Vector2(0.68, 0.21), Vector2(0.57, 0.28), Vector2(0.34, 0.19),
		Vector2(0.22, 0.29), Vector2(0, 0.23),
	], Color("#5b5e46"))
	_polygon([
		Vector2(0, 0.53), Vector2(0.18, 0.45), Vector2(0.33, 0.54),
		Vector2(0.51, 0.48), Vector2(0.67, 0.53), Vector2(0.83, 0.41),
		Vector2(1, 0.46), Vector2(1, 0.74), Vector2(0.69, 0.7),
		Vector2(0.58, 0.61), Vector2(0.32, 0.73), Vector2(0, 0.75),
	], Color("#50583f"))
	var river := _points([
		Vector2(0.78, 0), Vector2(0.7, 0.13), Vector2(0.73, 0.22), Vector2(0.66, 0.34),
		Vector2(0.62, 0.44), Vector2(0.66, 0.58), Vector2(0.56, 0.68),
		Vector2(0.43, 0.69), Vector2(0.39, 0.76), Vector2(0.28, 0.83),
		Vector2(0.28, 0.91), Vector2(0.24, 1),
	])
	draw_polyline(river, Color("#344b43"), 11.0, true)
	draw_polyline(river, Color("#658780"), 5.0, true)
	draw_polyline(river, Color("#91a6a0"), 1.0, true)
	for i in range(1, 9):
		var x := size.x * i / 9.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.85, 0.83, 0.67, 0.055))
	for i in range(1, 6):
		var y := size.y * i / 6.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.85, 0.83, 0.67, 0.055))
	for mountain: Vector2 in [
		Vector2(0.11, 0.29), Vector2(0.18, 0.24), Vector2(0.24, 0.27),
		Vector2(0.31, 0.22), Vector2(0.37, 0.19), Vector2(0.45, 0.19),
		Vector2(0.54, 0.22), Vector2(0.6, 0.18), Vector2(0.83, 0.26),
		Vector2(0.89, 0.24), Vector2(0.94, 0.31),
	]:
		_draw_peak(point_at(mountain), 34.0 + 29.0 * absf(sin(mountain.x * 23.0)))
	for i in range(38):
		var x := 0.05 + (i * 37 % 91) / 100.0
		var y := 0.76 + (i * 13 % 10) / 100.0 + 0.02 * sin(i * 4.0)
		if absf(x - 0.24) > 0.075:
			_draw_tree(point_at(Vector2(x, y)), 6.0 + (i % 5) * 2.0)
	var area := "CAIRNSPINE APPROACH" if world and world.campaign_id() == "sova" else "WESTERN MARCHES"
	draw_string(TYPE, Vector2(26, 30), "VARETH  /  " + area, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, QUIET)
	var compass := Vector2(size.x - 45.0, 44.0)
	draw_line(compass - Vector2(0, 17), compass + Vector2(0, 15), QUIET, 1.0, true)
	draw_line(compass - Vector2(9, 3), compass + Vector2(9, -3), QUIET, 1.0, true)
	draw_string(TYPE, compass + Vector2(-5, -21), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, PALE)


func _draw_peak(p: Vector2, width: float) -> void:
	var left := p + Vector2(-width, 0)
	var summit := p + Vector2(-0.19 * width, -0.86 * width)
	var right := p + Vector2(width, 0)
	draw_colored_polygon(PackedVector2Array([left, summit, right]), Color("#373e33"))
	draw_colored_polygon(PackedVector2Array([left, summit, p + Vector2(0.14 * width, 0)]), Color("#737562"))
	draw_polyline(PackedVector2Array([left, summit, right]), Color("#92917a"), 1.1, true)


func _draw_tree(p: Vector2, height: float) -> void:
	var canopy := PackedVector2Array([p + Vector2(-0.42 * height, 0), p + Vector2(0, -height), p + Vector2(0.42 * height, 0)])
	draw_colored_polygon(canopy, Color("#293931"))
	draw_line(p, p + Vector2(0, 4), Color("#354336"), 1.5)


func _draw_route(edge: Dictionary) -> void:
	var source := point_at(world.waypoint(edge.from_id).map_position)
	var target := point_at(world.waypoint(edge.to_id).map_position)
	var required: String = edge.get("required_clear_id", "")
	var blocked := not required.is_empty() and not completed_ids.has(required)
	var highlighted: bool = selected_id == edge.to_id or selected_id == edge.from_id
	var tint := BLOCKED if blocked else GOLD if highlighted else QUIET
	var distance := source.distance_to(target)
	if distance < 60.0:
		return
	var vector := (target - source).normalized()
	var steps := maxi(1, roundi((distance - 50.0) / 12.0))
	for i in range(steps + 1):
		var p := source + vector * lerpf(25.0, distance - 25.0, float(i) / steps)
		draw_circle(p, 2.05 if highlighted else 1.6, tint, true, -1.0, true)
	if blocked:
		var lock_point := (source + target) * 0.5
		draw_circle(lock_point, 13.0, Color("#242523"), true, -1.0, true)
		draw_arc(lock_point + Vector2(0, -2), 4.2, PI, TAU, 12, BLOCKED, 1.5, true)
		draw_rect(Rect2(lock_point + Vector2(-5, -1), Vector2(10, 7)), BLOCKED)


func _draw_waypoint(node: Dictionary) -> void:
	var p := point_at(node.map_position)
	var selected: bool = node.id == selected_id
	var tint := GOLD if selected else PALE
	draw_circle(p + Vector2(1, 3), 22.0, Color(0.04, 0.06, 0.04, 0.64), true, -1.0, true)
	draw_circle(p, 21.0, Color("#28332a"), true, -1.0, true)
	draw_arc(p, 21.0, 0.0, TAU, 32, tint, 2.0 if selected else 1.25, true)
	if selected:
		draw_arc(p, 26.0, 0.0, TAU, 36, GOLD, 1.0, true)
	match node.kind:
		World.WaypointKind.CAMP:
			draw_polyline(PackedVector2Array([p + Vector2(-11, 8), p + Vector2(0, -10), p + Vector2(11, 8), p + Vector2(-11, 8)]), tint, 2.0, true)
			draw_line(p + Vector2(0, -3), p + Vector2(0, 8), tint, 2.0, true)
		World.WaypointKind.BATTLEFIELD:
			draw_line(p + Vector2(-8, -8), p + Vector2(9, 9), tint, 2.4, true)
			draw_line(p + Vector2(8, -8), p + Vector2(-9, 9), tint, 2.4, true)
			draw_line(p + Vector2(-11, 3), p + Vector2(-3, 11), tint, 2.0, true)
			draw_line(p + Vector2(11, 3), p + Vector2(3, 11), tint, 2.0, true)
		_:
			draw_polyline(PackedVector2Array([p + Vector2(-10, 0), p + Vector2(8, 0), p + Vector2(2, -6)]), tint, 2.0, true)
			draw_line(p + Vector2(8, 0), p + Vector2(2, 6), tint, 2.0, true)
	var label: String = node.label
	var label_width := TYPE.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
	var label_origin := Vector2(clampf(p.x - label_width * 0.5, 11.0, size.x - label_width - 11.0), p.y + 49.0)
	draw_rect(Rect2(label_origin + Vector2(-7, -20), Vector2(label_width + 14.0, 26.0)), Color(0.085, 0.1, 0.08, 0.84))
	draw_string(TYPE, label_origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, tint)


func _draw_token() -> void:
	var ground := point_at(token_position)
	var p := ground + Vector2(0, -37)
	draw_line(p, ground - Vector2(0, 16), GOLD, 2.0, true)
	var corners := PackedVector2Array([p + Vector2(0, -15), p + Vector2(13, 0), p + Vector2(0, 13), p + Vector2(-13, 0), p + Vector2(0, -15)])
	draw_colored_polygon(corners, GOLD)
	draw_polyline(corners, Color("#31241a"), 2.0, true)
	draw_polyline(PackedVector2Array([p + Vector2(-5, 3), p + Vector2(0, -4), p + Vector2(5, 3)]), Color("#473122"), 2.0, true)


func _polygon(relative: Array[Vector2], tint: Color) -> void:
	draw_colored_polygon(_points(relative), tint)


func _points(relative: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in relative:
		points.append(point_at(point))
	return points
