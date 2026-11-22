extends "res://game/overworld/marches_overworld_renderer.gd"
## Mount only shared geographic assets, never Mara's camps, gates or route art.
const Opening := preload("res://game/overworld/cairnspine/sova_opener_route.gd")
const Camp := preload("res://game/overworld/cairnspine/sova_opener_camp.gd")

var camp_art: Node3D

func _ready() -> void:
	camera = $Camera
	_party = $Party
	_build_lighting()
	_mount("marches-corridor.glb", Vector3.ZERO)
	var points := Opening.points()
	anchors[Opening.MINE] = points[0]
	anchors[Opening.CAMP] = points[-1]
	_mount("greyhollow-mine.glb", Vector3(0,36,-70))
	route_points = [points]
	_build_routes()
	_build_local_standard()
	_set_regional()
	_dress_approach.call_deferred()


func _build_local_standard() -> void:
	# The inherited builder supplies the generic travel glyph, not a waypoint.
	# Its old initial placement key is internal and removed before presentation.
	anchors["marches_camp"] = anchors[Opening.CAMP]
	_build_party()
	anchors.erase("marches_camp")
	for item: MeshInstance3D in _party.get_children():
		if item.mesh is ArrayMesh:
			(item.material_override as StandardMaterial3D).albedo_color = Color("#65694c")


func _dress_approach() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_inside_tree() or not is_instance_valid(_ground):
		return
	camp_art = Camp.make(_terrain, Opening.points())
	if camp_art:
		add_child(camp_art)


func _terrain(xz: Vector2) -> Vector3:
	var hit := _ground.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(xz.x, 300, xz.y), Vector3(xz.x, -10, xz.y)))
	if hit.is_empty() or hit.collider.get_parent() != _ground or hit.normal.y < .89:
		return Vector3.INF
	return hit.position


func _set_regional() -> void:
	look_from(Vector3(59,34,-75),Vector3(17,131,183))


func look_from(target: Vector3, offset: Vector3) -> void:
	_look = target
	camera.position = target + offset
	camera.look_at(target)
	_update_grove_tiers()
	presentation_camera_changed.emit()


func toggle_zoom(point: Vector3) -> void:
	if _view_follow or not camera:
		return
	_zoomed = not _zoomed
	if not _zoomed:
		_set_regional()
		return
	var mine := point.distance_to(anchors[Opening.MINE]) < 10.0
	look_from(point+Vector3(3,3,-5), Vector3(25,62,78) if mine else Vector3(12,29,42))
