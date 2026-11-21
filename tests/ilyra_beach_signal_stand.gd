extends SceneTree
## The reviewed stand is an Ilyra-only cosmetic, never a source of objective state.

const Deployments := preload("res://game/campaign_deployments.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Shore := preload("res://game/battlefields/moonwash_survey_shore.tscn")
const POLE := ^"Geometry/Beach/BeachSignalStand"
const FLAG := ^"Geometry/Beach/BeachFlag"
const RING := ^"Markers/Objectives/BeachSignal"
const HOLD := ^"Markers/BoatRoute/BeachHold"
const HIGH := ^"Geometry/Headlands/HighSignalStand/Mesh"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stock := Shore.instantiate()
	var scene: PackedScene = Deployments.for_mission(&"ilyra_coast_survey").scene
	var mission := scene.instantiate()
	root.add_child(mission)
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var field: Node3D = mission._field
	var pole := field.get_node_or_null(POLE) as StaticBody3D
	var art := pole.get_node_or_null(^"BeachSignalStandArt") if pole else null
	var passed := art != null and _check_skin(stock,field,pole,art)
	if not passed:
		push_error("Ilyra's exact cosmetic or stock stand/flag collision/visibility contract failed.")
	stock.free()
	mission.queue_free()
	await process_frame
	if passed:
		print("Beach signal skin: Ilyra-only live mounting, exact stock boxes and both actual ground pick and signal ray, unchanged high stand and zero new collision/animation passed.")
	quit(0 if passed else 1)


func _check_skin(stock: Node, field: Node3D, pole: StaticBody3D, art: Node) -> bool:
	var flag := field.get_node(FLAG) as StaticBody3D
	var mesh := art.get_node_or_null(^"StandVisual") as MeshInstance3D
	if not mesh or mesh.mesh.get_surface_count() != 1 or not mesh.is_visible_in_tree() 			or not art.find_children("*","CollisionObject3D",true,false).is_empty() 			or not art.find_children("*","AnimationPlayer",true,false).is_empty() 			or stock.get_node(POLE).has_node(^"BeachSignalStandArt"):
		return false
	if not field.get_node(HIGH).visible or pole.get_node(^"Mesh").visible 			or flag.get_node(^"Mesh").visible:
		return false
	var terrain := Terrain.new(field)
	var extent: Array[AABB] = []
	for body in [pole,flag]:
		var original := stock.get_node(POLE if body == pole else FLAG) as StaticBody3D
		var original_shape := original.get_node(^"Collision") as CollisionShape3D
		var live_shape := body.get_node(^"Collision") as CollisionShape3D
		if body.transform != original.transform or live_shape.transform != original_shape.transform 				or live_shape.shape.size != original_shape.shape.size 				or body.collision_layer != original.collision_layer:
			return false
		var box: Vector3 = live_shape.shape.size
		extent.append(AABB(pole.to_local(body.global_position)-box*.5,box).grow(.0001))
	if not (art as Node3D).transform.is_equal_approx(Transform3D.IDENTITY) or not mesh.transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var tri := mesh.mesh.get_faces()
	for i in range(0,tri.size(),3):
		if not _within_triangle(extent[0],tri,i) and not _within_triangle(extent[1],tri,i):
			return false
	var marker := field.get_node(RING) as Marker3D
	var release := field.get_node(HOLD) as Marker3D
	if marker.position != stock.get_node(RING).position or release.position != stock.get_node(HOLD).position:
		return false
	var point := marker.global_position
	var pick: Variant = terrain.destination_from_ray(point + Vector3.UP*8.0, point - Vector3.UP*2.0)
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP*2.6,
		release.global_position + Vector3.UP*2.5, Terrain.SOLID_MASK)
	ray.collide_with_areas = false
	return pick is Vector2 and pick.is_equal_approx(Vector2(point.x,point.z)) 		and terrain.formation_fits_at(pick) 		and not terrain.formation_fits_at(Vector2(pole.global_position.x,pole.global_position.z)) 		and field.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _within_triangle(box: AABB, tri: PackedVector3Array, i: int) -> bool:
	return box.has_point(tri[i]) and box.has_point(tri[i+1]) and box.has_point(tri[i+2])
