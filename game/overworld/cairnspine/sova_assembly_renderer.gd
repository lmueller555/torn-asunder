extends "res://game/overworld/marches_overworld_renderer.gd"
## Native preview of the western valley sector, separate from the mine's coordinates.
const Valley := preload("res://game/overworld/cairnspine/sova_assembly_relief.gd")
const ASSEMBLY := "cairnspine_assembly"
# Inside the court's open west entrance, before the hearing placement.
const ARRIVAL := Vector3(-153.4,.485,.4)
var relief: Valley
var validated := false

func _ready() -> void:
	camera = $Camera
	_party = $Party
	_build_lighting()
	relief = Valley.new()
	relief.name = "YearThreeValley"
	add_child(relief)
	_ground = relief.get_node(^"SurveyRelief") as MeshInstance3D
	if not _ground:
		return
	_ground.create_trimesh_collision()
	anchors[ASSEMBLY] = ARRIVAL
	anchors["marches_camp"] = ARRIVAL
	_build_party()
	anchors.erase("marches_camp")
	for item: MeshInstance3D in _party.get_children():
		if item.mesh is ArrayMesh:
			(item.material_override as StandardMaterial3D).albedo_color = Color("#65694c")
	_set_regional()
	_verify_footing.call_deferred()


func _set_regional() -> void:
	_aim(Vector3(-170,0,4),Vector3(-19,95,142))


func toggle_zoom(_point: Vector3) -> void:
	_zoomed = not _zoomed
	if _zoomed:
		_aim(Vector3(-143,1,0),Vector3(-9,40,62))
	else:
		_set_regional()


func _aim(target: Vector3, offset: Vector3) -> void:
	_look = target
	camera.position = target + offset
	camera.look_at(target)
	presentation_camera_changed.emit()


func _verify_footing() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	for frame in range(2):
		await tree.physics_frame
		if not is_inside_tree():
			return
	var hit := _ground.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		ARRIVAL+Vector3.UP*7,ARRIVAL-Vector3.UP*7))
	validated = not hit.is_empty() and hit.collider.get_parent() == _ground \
		and absf(hit.position.y+.44-ARRIVAL.y)<.13 and relief.has_node(^"OpenAssemblyCourt")
