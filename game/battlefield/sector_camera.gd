extends RefCounted
## Uses an orthographic tactical window close enough to read platoons, plus
## a whole-field overview. Coordinates are local to the battlefield scene.

const SAFE_FRACTION := 0.30

var bounds: Rect2
var sector_size: float
var overview := false
var focus := Vector2.ZERO


func _init(field: Rect2, vertical_span: float) -> void:
	bounds = field
	sector_size = maxf(16.0, vertical_span)


func center_on(point: Vector2) -> void:
	overview = false
	focus = clamp_to_field(point)


func toggle(point: Vector2) -> void:
	if overview:
		center_on(point)
	else:
		overview = true


func view_center() -> Vector2:
	return bounds.get_center() if overview else focus


func view_size(aspect: float) -> float:
	if not overview:
		return sector_size
	# Fit the field at any orbit yaw, including a narrow or portrait viewport.
	return maxf(sector_size, bounds.size.length() * 1.06 / minf(maxf(aspect, 0.1), 1.0))


func clamp_to_field(point: Vector2) -> Vector2:
	return point.clamp(bounds.position, bounds.end)


func follow_cursor(point: Vector2, height: float, yaw: float, pitch: float, aspect: float) -> void:
	if overview:
		return
	var distance := (point - focus).rotated(yaw)
	var projected := Vector2(distance.x, distance.y * sin(pitch) - height * cos(pitch))
	var safe := Vector2(sector_size * aspect, sector_size) * SAFE_FRACTION
	var excess := projected - projected.clamp(-safe, safe)
	var correction := Vector2(excess.x, excess.y / sin(pitch)).rotated(-yaw)
	focus = clamp_to_field(focus + correction)


func pan(direction: Vector2, delta: float) -> bool:
	if overview or direction.is_zero_approx():
		return false
	var before := focus
	focus = clamp_to_field(focus + direction.limit_length() * sector_size * 0.77 * delta)
	return focus != before


static func pointer_edge(pointer: Vector2, rect: Rect2) -> Vector2:
	if not rect.has_point(pointer):
		return Vector2.ZERO
	var short_edge := minf(rect.size.x, rect.size.y)
	var margin := minf(clampf(short_edge * 0.045, 22.0, 44.0), short_edge * 0.45)
	var start := rect.position + Vector2.ONE * margin
	var end := rect.end - Vector2.ONE * margin
	return (pointer - pointer.clamp(start, end)) / margin
