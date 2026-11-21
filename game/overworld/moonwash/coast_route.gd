extends Resource
## Typed package of the exact local 334-point bathymetry-checked road and thicket placement.
## No runtime JSON, CSV, temporary files or direct GLTF decoding.
const COAST_OFFSET := Vector3(1478.0, 0.0, 150.0)
const ROAD := "moonwash_road"
const HARBOR := "moonwash_harbor"
const SOURCE := "res://assets/overworld/moonwash/moonwash-sector-data.tres"
const ROAD_WORLD := Vector3(1060.0, 32.9719, -57.0)
const HARBOR_WORLD := Vector3(1477.0, 8.6, 130.0)

@export var approach_local: PackedVector3Array
@export var thicket_labels: PackedStringArray
@export var thicket_world_ground: PackedVector3Array
## Per thicket: X uniform scale, Y yaw in degrees, Z burial depth in metres.
@export var thicket_pose: PackedVector3Array
@export var thicket_soft_ground_tilt: PackedFloat64Array


static func points() -> PackedVector3Array:
	var data := ResourceLoader.load(SOURCE) as Resource if ResourceLoader.exists(SOURCE) else null
	return data.call("world_points") if data and data.has_method("world_points") else PackedVector3Array()


func world_points() -> PackedVector3Array:
	if approach_local.size() != 334:
		return PackedVector3Array()
	var world := PackedVector3Array()
	var length := 0.0
	for local: Vector3 in approach_local:
		if not local.is_finite():
			return PackedVector3Array()
		var point := local + COAST_OFFSET
		if not world.is_empty():
			if point == world[-1]:
				return PackedVector3Array()
			length += point.distance_to(world[-1])
		world.append(point)
	if not world[0].is_equal_approx(ROAD_WORLD) or not world[-1].is_equal_approx(HARBOR_WORLD) 			or absf(length - 485.07596) > 0.01:
		return PackedVector3Array()
	return world


func valid_thickets() -> bool:
	if thicket_labels.size() != 8 or thicket_world_ground.size() != 8 			or thicket_pose.size() != 8 or thicket_soft_ground_tilt.size() != 8:
		return false
	var names := {}
	for i in range(8):
		var pose := thicket_pose[i]
		var tilt := thicket_soft_ground_tilt[i]
		if thicket_labels[i].is_empty() or names.has(thicket_labels[i]) or not thicket_world_ground[i].is_finite() 				or not pose.is_finite() or pose.x <= 0.0 or pose.z < 0.0 or not is_finite(tilt) or tilt < 0.0 or tilt > 1.0:
			return false
		names[thicket_labels[i]] = true
	return true
