extends Control
## Transient screen-space input and paint; the renderer host owns map actions.
const GOLD := Color("#f0c873")
const SHADOW := Color("#221811")
const GREEN := Color("#83ce77")
const SPEED := 510.0
const DEADZONE := 0.22

var stick := Vector2.ZERO
var point := Vector2.ZERO
var snapped_id := ""
var has_point := false
var station := Vector2.ZERO
var has_station := false
var available := PackedVector2Array()
var preview := PackedStringArray()


func follow(id: String) -> void:
	snapped_id = id
	stick = Vector2.ZERO


func set_axis(axis: int, value: float) -> void:
	if axis == JOY_AXIS_LEFT_X:
		stick.x = value
	else:
		stick.y = value


func move_pointer(at: Vector2) -> void:
	point = at.clamp(Vector2.ONE * 13.0, (size - Vector2.ONE * 13.0).max(Vector2.ONE * 13.0))
	has_point = true
	snapped_id = ""


func advance(delta: float) -> bool:
	var strength := minf(stick.length(), 1.0)
	if strength <= DEADZONE or not has_point or delta <= 0.0:
		return false
	move_pointer(point + stick.normalized() * ((strength - DEADZONE) / (1.0 - DEADZONE)) * SPEED * delta)
	return true


func _draw() -> void:
	for marker in available:
		if not Rect2(Vector2.ZERO, size).has_point(marker):
			continue
		draw_circle(marker, 9.0, SHADOW, true, -1.0, true)
		draw_arc(marker, 7.5, 0.0, TAU, 24, GREEN, 2.0, true)
		draw_polyline(PackedVector2Array([
			marker + Vector2(-4, -2), marker + Vector2(0, 3), marker + Vector2(4, -2),
		]), GREEN, 2.0, true)
	if not has_point or not Rect2(Vector2.ZERO, size).has_point(point):
		if not preview.is_empty():
			_draw_preview()
		return
	if has_station:
		var distance := station.distance_to(point)
		if distance > 23.0 and Rect2(Vector2.ZERO, size).has_point(station):
			var direction := station.direction_to(point)
			for i in range(14, floori(distance - 12.0), 12):
				var dot_at := station + direction * i
				draw_circle(dot_at, 3.1, SHADOW, true, -1.0, true)
				draw_circle(dot_at, 1.9, GOLD, true, -1.0, true)
	draw_arc(point, 12.0, 0.0, TAU, 48, SHADOW, 5.0, true)
	draw_arc(point, 12.0, 0.0, TAU, 48, GOLD, 2.0, true)
	draw_circle(point, 2.0, GOLD, true, -1.0, true)
	if not preview.is_empty():
		_draw_preview()


func _draw_preview() -> void:
	var font := ThemeDB.fallback_font
	var width := 0.0
	for line in preview:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	var bounds := Rect2(Vector2(28, size.y - 79 - 23.0 * preview.size()), Vector2(width + 28.0, 17.0 + 23.0 * preview.size()))
	draw_rect(bounds, Color("#16201deb"))
	draw_line(bounds.position, bounds.position + Vector2(bounds.size.x, 0), GOLD, 1.0)
	for i in preview.size():
		var line := bounds.position + Vector2(14, 23 + 23 * i)
		draw_string(font, line, preview[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD if i == 0 else Color("#f0e6ce"))
