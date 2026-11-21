extends SceneTree
## Exact registered Mine placement, scoped art and unchanged field collision.

const Registry := preload("res://game/campaign_deployments.gd")
const Mine := preload("res://game/battlefields/year_one_mine_campaign.tscn")
const Distance := preload("res://assets/models/environment/mara_mine_storehouse/works_distance.gd")
const WALL := ^"Geometry/Mine/MinerStorehouse"
const ROOF := ^"Geometry/Mine/MinerRoof"
const MODEL := ^"ClosedWorksStorehouse"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original := Mine.instantiate()
	var passed := true
	for id in ["mara_mine_escort", "sova_mine_tunnels", "orc_mine_witness"]:
		var scene: PackedScene = Registry.for_mission(id).scene
		var mission := scene.instantiate()
		root.add_child(mission)
		mission.set_physics_process(false)
		await process_frame
		var field := mission.get_node(^"YearOneMineCampaign")
		passed = _check_placement(field, original, id == "mara_mine_escort") and passed
		mission.queue_free()
		await process_frame
	original.free()
	if passed:
		print("Mine storehouse: Mara-only exact instance, original resources, two visual meshes and one cast shadow; Sova and Raska remain stock.")
	else:
		push_error("Reviewed storehouse art, camera transition, or unchanged stock Mine placements differ.")
	quit(0 if passed else 1)


func _check_placement(field: Node, original: Node, reviewed: bool) -> bool:
	if field.scene_file_path != Mine.resource_path:
		return false # Heavy Infantry replay also requires this exact path.
	for path: NodePath in [WALL, ROOF]:
		var current := field.get_node(path) as StaticBody3D
		var stock := original.get_node(path) as StaticBody3D
		var current_shape := current.get_node(^"Collision") as CollisionShape3D
		var stock_shape := stock.get_node(^"Collision") as CollisionShape3D
		if (current.transform != stock.transform or current.collision_layer != stock.collision_layer
			or current_shape.shape != stock_shape.shape or current_shape.transform != stock_shape.transform
			or current.get_node(^"Mesh").visible == reviewed):
			return false
	var art := field.get_node(WALL).get_node_or_null(MODEL) as Distance
	if not reviewed:
		return art == null
	if (not art or not art.visible or art.position != Vector3(0.0, -2.1, 0.0)
		or art.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		or not art.find_children("*", "CollisionObject3D", true, false).is_empty()
		or art._near.get_faces().size() != 1270 * 3 or art._far.get_faces().size() != 218 * 3):
		return false
	var near_mat := art._near.surface_get_material(0) as StandardMaterial3D
	if near_mat == null or near_mat != art._far.surface_get_material(0):
		return false
	var atlas := near_mat.albedo_texture.get_image()
	if atlas.get_size() != Vector2i(512, 256) or atlas.get_format() != Image.FORMAT_RGB8 or not atlas.has_mipmaps():
		return false

	# Sample the verified hysteresis without altering the live gameplay camera.
	var probe := Camera3D.new()
	root.add_child(probe)
	probe.projection = Camera3D.PROJECTION_ORTHOGONAL
	probe.keep_aspect = Camera3D.KEEP_HEIGHT
	probe.size = 40.0
	art.update_for_camera(probe)
	var correct := art.mesh == art._near and not art.using_far
	probe.size = 116.0
	art.update_for_camera(probe)
	correct = correct and art.mesh == art._far and art.using_far
	probe.size = 52.0
	art.update_for_camera(probe)
	correct = correct and art.mesh == art._far
	probe.size = 40.0
	art.update_for_camera(probe)
	correct = correct and art.mesh == art._near and not art.using_far
	probe.free()
	return correct
