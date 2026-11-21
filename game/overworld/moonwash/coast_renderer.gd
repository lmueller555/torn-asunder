extends "res://game/overworld/marches_overworld_renderer.gd"

const Coast := preload("res://game/overworld/moonwash/coast_route.gd")
@export var coast_scene: PackedScene
@export var harbor_regional_scene: PackedScene
@export var harbor_near_scene: PackedScene
@export var shoulder_returns_scene: PackedScene
@export var data: Coast
var terrain: Node3D
var _focus := Coast.ROAD

func package_available() -> bool:
	for scene: PackedScene in [coast_scene, harbor_regional_scene, harbor_near_scene, shoulder_returns_scene]:
		if not scene or not scene.can_instantiate():
			return false
	return data != null and data.valid_thickets() and not data.world_points().is_empty()


func mounted_for_play() -> bool:
	return is_instance_valid(_ground) and has_node("MoonwashHarbor") and has_node("MoonwashShoulderReturns") \
		and _groves.size() == 9 # One Harbor LOD pair and eight grounded thickets.


func _ready() -> void:
	camera=$Camera
	_party=$Party
	var lane := data.world_points() if package_available() else PackedVector3Array()
	if lane.is_empty():
		return
	anchors[Coast.ROAD]=lane[0]
	anchors[Coast.HARBOR]=lane[-1]
	anchors["marches_camp"]=lane[0] # Shared party builder uses this private initial mount slot.
	_build_lighting()
	if not _mount_coast():
		return
	route_points.append(lane)
	route_keys.append(Vector2i(-1,-1))
	_build_routes()
	_build_party()
	_set_regional()
	_plant_thickets.call_deferred()


func _mount_coast() -> bool:
	var material_ground := coast_scene.instantiate() as Node3D
	var wide := harbor_regional_scene.instantiate() as Node3D
	var near := harbor_near_scene.instantiate() as Node3D
	var returns := shoulder_returns_scene.instantiate() as Node3D
	if material_ground:
		_ground = material_ground.find_child("MoonwashGround", true, false) as MeshInstance3D
	var returns_meshes := returns.find_children("*", "MeshInstance3D", true, false) if returns else []
	var mineral_count := 0
	var limestone_count := 0
	for mesh: MeshInstance3D in returns_meshes:
		if str(mesh.name).begins_with("Mineral"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mineral_count += 1
		elif str(mesh.name).begins_with("Dry"):
			limestone_count += 1
	if not _ground or not wide or not near or mineral_count != 1 or limestone_count != 1 or returns_meshes.size() != 2:
		for view in [material_ground, wide, near, returns]:
			if view:
				view.free()
		return false
	material_ground.position = Coast.COAST_OFFSET
	returns.name = "MoonwashShoulderReturns"
	returns.position = Coast.COAST_OFFSET
	add_child(returns) # Both visible; the mineral backfill alone does not cast.
	for m: MeshInstance3D in material_ground.find_children("*","MeshInstance3D",true,false):
		if m!=_ground:
			m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(material_ground)
	_ground.create_trimesh_collision()
	terrain=material_ground
	var harbor := Node3D.new()
	harbor.name="MoonwashHarbor"
	harbor.position=Coast.COAST_OFFSET
	add_child(harbor)
	harbor.add_child(near)
	harbor.add_child(wide)
	_groves.append([harbor,near,wide])
	_update_grove_tiers()
	return true

func _plant_thickets() -> void:
	if not is_inside_tree() or not is_instance_valid(_ground) or not data.valid_thickets():
		return
	var near := load(ASSETS + "marches-copse-near.glb") as PackedScene
	var far := load(ASSETS + "marches-copse-regional.glb") as PackedScene
	if not near or not far:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var hits: Array[Dictionary] = []
	for i in range(8):
		var point := data.thicket_world_ground[i]
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 30.0, point - Vector3.UP * 30.0)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider.get_parent() != _ground or absf(hit.position.y - point.y) > 0.003:
			push_warning("Moonwash thickets not mounted: uncertain footing at " + data.thicket_labels[i])
			return
		hits.append(hit)
	for i in range(8):
		var hit := hits[i]
		var pose := data.thicket_pose[i]
		var gro := Node3D.new()
		gro.name = StringName(data.thicket_labels[i].replace(" ", "_"))
		add_child(gro)
		gro.position = hit.position - Vector3.UP * pose.z
		var up := Vector3.UP.slerp(hit.normal, data.thicket_soft_ground_tilt[i])
		gro.basis = Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, deg_to_rad(pose.y))
		gro.scale = Vector3.ONE * pose.x
		var close := near.instantiate() as Node3D
		var wide := far.instantiate() as Node3D
		gro.add_child(close)
		gro.add_child(wide)
		_enable_vegetation_pigment(close)
		_enable_vegetation_pigment(wide)
		_groves.append([gro, close, wide])
	_update_grove_tiers()


func show_party_state(travelling: bool, selected: String) -> void:
	if not is_node_ready() or not terrain:
		return
	if travelling:
		if not _view_follow:
			_look=_party.position
		_view_follow=not _reduced_motion
		_zoomed=false
	elif _view_follow or not _active or _focus!=selected:
		_view_follow=false
		_focus=selected
		_zoomed=false
		_set_regional()
	_active=true


func _set_regional() -> void:
	var target := Vector3(-132,22,-83)
	var offset := Vector3(-91,359,440)
	if _focus==Coast.HARBOR:
		target=Vector3(122,9,108)
		offset=Vector3(86,282,422)
	_aim(target+Coast.COAST_OFFSET,offset)


func toggle_zoom(point: Vector3) -> void:
	if _view_follow or not camera:
		return
	_zoomed=not _zoomed
	if not _zoomed:
		_set_regional()
	elif _focus==Coast.HARBOR:
		_aim(Coast.COAST_OFFSET+Vector3(0,9.1,-5),Vector3(61,73,106))
	else:
		_aim(point+Vector3(22,5,12),Vector3(51,76,89))


func _aim(target: Vector3, offset: Vector3) -> void:
	_look=target
	camera.position=target+offset
	camera.look_at(target)
	_update_grove_tiers()
	presentation_camera_changed.emit()
