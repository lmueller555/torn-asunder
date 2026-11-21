extends SceneTree
## Verify narrow visual replacement in the registered deployment, not the shared field.

const Deployments := preload("res://game/campaign_deployments.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Shore := preload("res://game/battlefields/moonwash_survey_shore.tscn")
const POLE := ^"Geometry/Headlands/HighSignalStand"
const FLAG := ^"Geometry/Headlands/HighFlag"
const RING := ^"Markers/Objectives/HeadlandSignal"
const HOLD := ^"Markers/BoatRoute/HeadlandHold"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stock := Shore.instantiate()
	var mission: Node3D = Deployments.for_mission(&"ilyra_coast_survey").scene.instantiate()
	root.add_child(mission)
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var ok := _check(stock, mission)
	stock.free()
	mission.queue_free()
	await process_frame
	if ok:
		print("Headland Relay: live single-surface cosmetic, both stock colliders/envelopes, Beach skin, unchanged ring/Hold/LOS and no collision or animation passed.")
	else:
		push_error("A Headland Relay integration or geometry invariant failed.")
	quit(0 if ok else 1)


func _check(stock: Node, mission: Node3D) -> bool:
	var field: Node3D = mission._field
	var pole := field.get_node(POLE) as StaticBody3D
	var flag := field.get_node(FLAG) as StaticBody3D
	var asset := pole.get_node_or_null(^"HeadlandRelayArt") as Node3D
	if not asset or not asset.transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var mesh := asset.get_node_or_null(^"HeadlandRelayVisual") as MeshInstance3D
	if not mesh or not mesh.is_visible_in_tree() or mesh.mesh.get_surface_count() != 1 			or not mesh.transform.is_equal_approx(Transform3D.IDENTITY) 			or not asset.find_children("*", "CollisionObject3D", true, false).is_empty() 			or not asset.find_children("*", "AnimationPlayer", true, false).is_empty():
		return false
	var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if not mat or not mat.albedo_texture or not mat.normal_texture or not mat.roughness_texture 			or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if (mesh.mesh.get_faces().size() / 3) != 928:
		return false
	var extent: Array[AABB] = []
	for path in [POLE, FLAG]:
		var solid := field.get_node(path) as StaticBody3D
		var original := stock.get_node(path) as StaticBody3D
		var c := solid.get_node(^"Collision") as CollisionShape3D
		var original_c := original.get_node(^"Collision") as CollisionShape3D
		if not original.get_node(^"Mesh").visible or solid.get_node(^"Mesh").visible 				or original.has_node(^"HeadlandRelayArt") or solid.transform != original.transform 				or c.transform != original_c.transform or c.shape.size != original_c.shape.size 				or solid.collision_layer != original.collision_layer or c.disabled != original_c.disabled:
			return false
		var box: Vector3 = c.shape.size
		extent.append(AABB(pole.to_local(c.global_position) - box*.5, box).grow(.0001))
	var faces := mesh.mesh.get_faces()
	for i in range(0, faces.size(), 3):
		if not _inside(extent[0], faces, i) and not _inside(extent[1], faces, i):
			return false
	var beach := field.get_node_or_null(^"Geometry/Beach/BeachSignalStand/BeachSignalStandArt/StandVisual") as MeshInstance3D
	if not beach or not beach.is_visible_in_tree():
		return false
	var marker := field.get_node(RING) as Marker3D
	var release := field.get_node(HOLD) as Marker3D
	if marker.position != stock.get_node(RING).position or release.position != stock.get_node(HOLD).position 			or mission._signal_flags[1].global_position != marker.global_position:
		return false
	var point := marker.global_position
	var terrain := Terrain.new(field)
	var pick: Variant = terrain.destination_from_ray(point + Vector3.UP*8.0, point - Vector3.UP*2.0)
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP*2.6,
		release.global_position + Vector3.UP*2.5, Terrain.SOLID_MASK)
	ray.collide_with_areas = false
	return pick is Vector2 and pick.is_equal_approx(Vector2(point.x, point.z)) 		and not terrain.formation_fits_at(Vector2(pole.global_position.x, pole.global_position.z)) 		and field.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _inside(box: AABB, faces: PackedVector3Array, i: int) -> bool:
	return box.has_point(faces[i]) and box.has_point(faces[i+1]) and box.has_point(faces[i+2])
