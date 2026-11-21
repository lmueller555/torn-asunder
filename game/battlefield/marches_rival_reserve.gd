extends Node3D
## A provisional field formation: it follows authored routes and contests one cart lane.
## This adds interdiction, not melee/ranged attacks or combat damage.

enum Status { WAITING, MARCHING, BLOCKING, SCREENED }

const TRAVEL_SPEED := 9.5
const BLOCK_RADIUS := 4.3
const SCREEN_RADIUS := 6.5

var status := Status.WAITING
var _route := PackedVector3Array()
var _next := 0
var _banner: Label3D


func _ready() -> void:
	var horse := _material(Color("#695043"))
	var coat := _material(Color("#da785d"))
	for x in [-1.17, 0.0, 1.17]:
		for z in [-1.05, 0.76]:
			_piece(Vector3(0.67, 0.72, 1.37), Vector3(x, 0.69, z), horse)
			for hoof_x in [-0.21, 0.21]:
				for hoof_z in [-0.40, 0.42]:
					_piece(Vector3(0.13, 0.49, 0.16), Vector3(x + hoof_x, 0.25, z + hoof_z), horse)
			_piece(Vector3(0.35, 0.44, 0.45), Vector3(x, 1.06, z - 0.61), horse)
			_piece(Vector3(0.41, 0.55, 0.38), Vector3(x, 1.43, z + 0.10), coat)
			_piece(Vector3(0.28, 0.27, 0.28), Vector3(x, 1.82, z + 0.10), coat)
	_banner = Label3D.new()
	_banner.position.y = 3.0
	_banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_banner.font_size = 40
	_banner.pixel_size = 0.035
	_banner.outline_size = 11
	_banner.modulate = Color("#ffc0a7")
	add_child(_banner)
	_sync_banner()


func reset(at: Vector3) -> void:
	global_position = at
	rotation = Vector3.ZERO
	status = Status.WAITING
	_route = PackedVector3Array()
	_next = 0
	_sync_banner()


func mobilize(route: PackedVector3Array) -> void:
	if status != Status.WAITING or route.is_empty():
		return
	_route = route.duplicate()
	_next = 0
	status = Status.MARCHING
	_sync_banner()


## Allies must actually reach and Hold near the rival reserve. A moving formation isn't a screen.
func step(delta: float, can_move: Callable, held_positions: PackedVector3Array) -> void:
	if status == Status.MARCHING:
		_march(delta, can_move)
	if status in [Status.BLOCKING, Status.SCREENED]:
		status = Status.BLOCKING
		for point in held_positions:
			if global_position.distance_to(point) <= SCREEN_RADIUS:
				status = Status.SCREENED
				break
	_sync_banner()


func blocks_cart_step(from: Vector3, to: Vector3) -> bool:
	if status != Status.BLOCKING:
		return false
	var start := Vector2(from.x, from.z)
	var destination := Vector2(to.x, to.z)
	var center := Vector2(global_position.x, global_position.z)
	var closest := Geometry2D.get_closest_point_to_segment(center, start, destination)
	return center.distance_squared_to(closest) <= BLOCK_RADIUS * BLOCK_RADIUS


func _march(delta: float, can_move: Callable) -> void:
	var remaining := delta * TRAVEL_SPEED
	while remaining > 0.0 and _next < _route.size():
		var here := global_position
		var target := _route[_next]
		var offset := target - here
		if offset.length_squared() > 0.00001:
			rotation.y = atan2(-offset.x, -offset.z)
		var trial := here.move_toward(target, remaining)
		if not can_move.call(here, trial):
			return
		global_position = trial
		remaining -= here.distance_to(trial)
		if trial != target:
			break
		_next += 1
	if _next == _route.size():
		status = Status.BLOCKING


func _sync_banner() -> void:
	_banner.text = ["Rival reserve · Forming", "Rival reserve · Moving", "Rival reserve · Blocking", "Rival reserve · Screened"][status]


func _piece(size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	var part := MeshInstance3D.new()
	part.mesh = box
	part.material_override = material
	part.position = at
	add_child(part)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
