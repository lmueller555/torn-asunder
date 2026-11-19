extends Control

var _time := 0.0
var _embers: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var random := RandomNumberGenerator.new()
	random.seed = 2731
	for i in range(34):
		_embers.append(Vector3(random.randf(), random.randf(), random.randf()))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for ember in _embers:
		var rise := fposmod(ember.y + _time * (0.04 + ember.z * 0.025), 1.0)
		var opacity := sin(rise * PI) * (0.16 + ember.z * 0.32)
		var drift := sin(ember.x * TAU + _time * 0.7) * 12.0
		var point := Vector2(size.x * ember.x + drift, size.y * (1.0 - rise))
		draw_circle(point, 0.7 + ember.z * 1.4, Color(1.0, 0.60, 0.30, opacity))
