extends RefCounted
## Uses an orthographic tactical window close enough to read platoons, plus
## a whole-field overview. Coordinates are local to the battlefield scene.

const SAFE_FRACTION := 0.30
const FULL_SCREEN := Rect2(0.0, 0.0, 1.0, 1.0)
const MIN_FRAME_SIDE := 0.40

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


## Returns (vertical span, effective pitch, horizontal shift, vertical shift).
## Authored bounds are X/Z. The safe frame is in normalized upper-left-origin
## viewport coordinates. An absent or invalid frame keeps ordinary overview.
func projection(aspect: float, yaw: float, pitch: float, safe_frame: Rect2) -> Vector4:
	var usual := Vector4(view_size(aspect), pitch, 0.0, 0.0)
	if not overview or not safe_frame.position.is_finite() or not safe_frame.size.is_finite() \
			or not FULL_SCREEN.encloses(safe_frame) or minf(safe_frame.size.x, safe_frame.size.y) < MIN_FRAME_SIDE \
			or safe_frame == FULL_SCREEN:
		return usual
	# Keep the same right-stick pitch input; shift its neutral point nearly
	# overhead on long fields so near cliffs don't obscure the far playable bank.
	var degrees := clampf(rad_to_deg(pitch), 50.0, 75.0)
	var overview_pitch := deg_to_rad(remap(degrees, 50.0, 59.0, 70.0, 84.0) if degrees < 59.0
		else remap(degrees, 59.0, 75.0, 84.0, 88.0))
	var ux := absf(cos(yaw))
	var uz := absf(sin(yaw))
	var width := ux * bounds.size.x + uz * bounds.size.y
	var depth := uz * bounds.size.x + ux * bounds.size.y
	var ratio := maxf(aspect, 0.1)
	var vertical_span := 1.06 * maxf(width / (ratio * safe_frame.size.x),
		depth * sin(overview_pitch) / safe_frame.size.y)
	vertical_span = maxf(sector_size, vertical_span)
	var center := safe_frame.get_center()
	return Vector4(vertical_span, overview_pitch,
		(0.5 - center.x) * ratio * vertical_span, (center.y - 0.5) * vertical_span)


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
