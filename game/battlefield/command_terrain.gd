extends RefCounted
## Geometry adapter for the command prototype. Layer 1 is solid; layer 2 tags
## its walkable surfaces so the tunnel roof and other obstacles aren't ground.

const SOLID_MASK := 1
const WALKABLE_MASK := 2
const HERO_RADIUS := 0.40
const FORMATION_RADIUS := 1.7
const STEP_HEIGHT := 0.16
const FLOOR_OFFSETS := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

var _field: Node3D
var _terrain_bodies: Array[RID] = []
var _hero_probe := _cylinder(HERO_RADIUS, 1.75)
var _formation_probe := _cylinder(FORMATION_RADIUS, 1.15)


func _init(field: Node3D) -> void:
	_field = field
	for node in field.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.collision_layer & WALKABLE_MASK:
			_terrain_bodies.append(body.get_rid())


func ground_height(point: Vector2) -> float:
	var hit := _ray(Vector3(point.x, 20.0, point.y), Vector3(point.x, -8.0, point.y), WALKABLE_MASK)
	return 0.0 if hit.is_empty() else _field.to_local(hit.position).y


func destination_from_ray(from: Vector3, to: Vector3) -> Variant:
	var hit := _ray(from, to, SOLID_MASK)
	if hit.is_empty() or not _terrain_bodies.has(hit.rid):
		return null
	var point := _field.to_local(hit.position)
	return Vector2(point.x, point.z)


func camera_position(target: Vector3, desired: Vector3) -> Vector3:
	var hit := _ray(target, desired, SOLID_MASK)
	if hit.is_empty():
		return desired
	var clear_distance := maxf(target.distance_to(_field.to_local(hit.position)) - 0.24, 0.0)
	return target.move_toward(desired, clear_distance)


func can_move(from: Vector2, to: Vector2, is_formation: bool) -> bool:
	if from == to:
		return true
	var floor := ground_height(to)
	if absf(floor - ground_height(from)) > STEP_HEIGHT:
		return false
	var radius := FORMATION_RADIUS if is_formation else HERO_RADIUS
	# Check the footprint against steep edges while allowing the ridge ramps.
	for offset: Vector2 in FLOOR_OFFSETS:
		if absf(ground_height(to + offset * radius) - floor) > STEP_HEIGHT + radius * 0.32:
			return false
	var shape := _formation_probe if is_formation else _hero_probe
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = SOLID_MASK
	query.exclude = _terrain_bodies
	query.shape = shape
	var center := Vector3(to.x, floor + shape.height / 2.0 + 0.04, to.y)
	query.transform = Transform3D(_field.global_basis.orthonormalized(), _field.to_global(center))
	return _field.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_field.to_global(from), _field.to_global(to), mask)
	return _field.get_world_3d().direct_space_state.intersect_ray(query)


static func _cylinder(radius: float, height: float) -> CylinderShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape
