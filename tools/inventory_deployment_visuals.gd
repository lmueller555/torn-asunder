extends SceneTree
## Read-only inventory of renderable nodes actually instantiated at mission start.
## Visible means CanvasItem/Node3D visibility, not in the camera frustum or rendered.
## No node, resource or deployment is marked approved by this tool.

const Campaigns := preload("res://game/campaigns.gd")
const Deployments := preload("res://game/campaign_deployments.gd")
const Missions := preload("res://game/campaign_missions.gd")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selection := OS.get_cmdline_user_args()
	if selection.size() > 1:
		push_error("Pass at most one mission ID after --.")
		quit(1)
		return
	var rows: Array[Dictionary] = []
	var visited := {}
	for campaign in Campaigns.ALL:
		for mission in Missions.missions_for_campaign(campaign.id):
			if not selection.is_empty() and mission.id != selection[0]:
				continue
			if visited.has(mission.id):
				push_error("Duplicate mission ID %s." % mission.id)
				_failed = true
				continue
			visited[mission.id] = true
			var deployment := Deployments.for_mission(mission.id)
			var scene: PackedScene = deployment.get("scene")
			if not scene:
				push_error("No registered scene for %s." % mission.id)
				_failed = true
				continue
			var instance := scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			# _ready still runs, including native stand adapters, but no live
			# physics advance or input is needed to inventory the opening state.
			instance.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(instance)
			await process_frame
			var items: Array[Dictionary] = []
			_walk(instance, instance, scene.resource_path, items)
			var perimeter: Variant = _mounted_perimeter(instance, mission.id)
			if items.is_empty():
				push_error("No renderable nodes in %s." % mission.id)
				_failed = true
			rows.append({
				"mission_id": mission.id, "deployment": scene.resource_path,
				"battlefield_perimeter": perimeter, "nodes": items,
			})
			instance.queue_free()
			await process_frame
	if rows.is_empty() or _failed:
		if rows.is_empty():
			push_error("No registered mission matches the selection.")
		quit(1)
		return
	print(JSON.stringify({
		"scope": "Instantiated at mission start; includes hidden nodes, not later spawns or full art approval.",
		"deployment_count": rows.size(),
		"deployments": rows,
	}))
	quit(0)


func _mounted_perimeter(mission: Node, mission_id: String) -> Variant:
	if not "battlefield_perimeter" in mission:
		return null
	var perimeter: PackedScene = mission.get("battlefield_perimeter")
	if perimeter == null:
		return null
	var field: PackedScene = mission.get("battlefield_scene")
	var matches := 0
	if field != null and not perimeter.resource_path.is_empty():
		for child in mission.get_children():
			if child.scene_file_path != field.resource_path:
				continue
			for mount in child.get_children():
				if mount is Node3D and mount.scene_file_path == perimeter.resource_path:
					matches += 1
	if matches != 1:
		push_error("%s: expected one configured Node3D perimeter under the opened battlefield." % mission_id)
		_failed = true
	return perimeter.resource_path.trim_prefix("res://")


func _walk(node: Node, mission: Node, host: String, rows: Array[Dictionary]) -> void:
	if not node.scene_file_path.is_empty():
		host = node.scene_file_path
	var kind := _visual_kind(node)
	if not kind.is_empty():
		var visible: bool = node.is_visible_in_tree()
		rows.append({
			"path": String(mission.get_path_to(node)),
			"kind": kind,
			"containing_scene": host,
			"scene_owned": node.owner != null,
			"visible_in_tree": visible,
			"shadow_only": node is GeometryInstance3D and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
			"resource_paths": _resources(node),
		})
	for child in node.get_children():
		_walk(child, mission, host, rows)


func _visual_kind(node: Node) -> String:
	if (node is MeshInstance3D or node is MultiMeshInstance3D or node is CSGShape3D or
			node is SpriteBase3D or node is Decal or node is GPUParticles3D or node is CPUParticles3D or
			node is Label3D or node is Sprite2D or node is TextureRect):
		return node.get_class()
	return ""


func _resources(node: Node) -> Array[String]:
	var resources: Array[Resource] = []
	if node is MeshInstance3D:
		resources.assign([node.mesh, node.material_override])
		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				resources.append(node.get_surface_override_material(i))
				resources.append(node.mesh.surface_get_material(i))
	elif node is MultiMeshInstance3D:
		resources.assign([node.multimesh, node.material_override])
		if node.multimesh:
			resources.append(node.multimesh.mesh)
	elif node is Sprite3D or node is Sprite2D or node is TextureRect:
		resources.append(node.texture)
	elif node is AnimatedSprite3D:
		resources.append(node.sprite_frames)
	elif node is Decal:
		resources.assign([node.texture_albedo, node.texture_normal, node.texture_orm, node.texture_emission])
	elif node is Label3D:
		resources.append(node.font)
	# Include common direct material dependencies, without pretending to crawl
	# arbitrary shaders, sprite frame sets, or later animation/effect resources.
	for resource in resources.duplicate():
		if resource is ShaderMaterial:
			resources.append(resource.shader)
		elif resource is BaseMaterial3D:
			resources.append_array([
				resource.albedo_texture, resource.normal_texture,
				resource.roughness_texture, resource.metallic_texture,
			])
	var paths: Array[String] = []
	for resource in resources:
		if resource and not resource.resource_path.is_empty() and resource.resource_path not in paths:
			paths.append(resource.resource_path)
	paths.sort()
	return paths
