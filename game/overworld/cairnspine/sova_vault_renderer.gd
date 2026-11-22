extends "res://game/overworld/cairnspine/sova_assembly_renderer.gd"
const VaultRoutes := preload("res://game/overworld/cairnspine/sova_vault_routes.gd")
const UpperValley := preload("res://game/overworld/cairnspine/sova_vault_relief.gd")


func _ready() -> void:
	camera=$Camera
	_party=$Party
	_build_lighting()
	relief=UpperValley.new()
	relief.name="YearThreeValley"
	add_child(relief)
	_ground=relief.get_node(^"SurveyRelief") as MeshInstance3D
	if not _ground:
		return
	_ground.create_trimesh_collision()
	var shelf := VaultRoutes.shelf()
	var approach := VaultRoutes.approach()
	anchors[VaultRoutes.ASSEMBLY]=shelf[0]
	anchors[VaultRoutes.ROAD]=shelf[-1]
	anchors[VaultRoutes.VAULT]=approach[-1]
	anchors["marches_camp"]=shelf[0]
	_build_party()
	anchors.erase("marches_camp")
	for item: MeshInstance3D in _party.get_children():
		if item.mesh is ArrayMesh:
			(item.material_override as StandardMaterial3D).albedo_color=Color("#65694c")
	route_points=[shelf,approach]
	_build_routes()
	for ribbon in _route_pins:
		ribbon.material_override=_open_pigment
	_set_regional()
	_verify_footing.call_deferred()


func show_party_state(travelling: bool, selected: String) -> void:
	# Camera follows the physically moving locator, never across an unloaded
	# sector. Reduced motion holds the regional lens.
	_focus_site=selected
	super.show_party_state(travelling,selected)


func _set_regional() -> void:
	_aim(Vector3(-6,18,4),Vector3(-18,316,186))


func toggle_zoom(point: Vector3) -> void:
	if _view_follow:
		return
	_zoomed=not _zoomed
	if not _zoomed:
		_set_regional()
	elif point.x < 70:
		_aim(Vector3(-141,1,1),Vector3(-9,40,62))
	elif point.x < 135:
		# Road reads the branching shelf; it does not reveal a different door.
		_aim(Vector3(133,14,-16),Vector3(-19,85,30))
	else:
		# Read the same west face from approach height. No staged era swap:
		# actual geology, time-independent stone and common lighting.
		_aim(Vector3(151,16.8,-16.1),Vector3(-48,37,-13))


func _process(delta: float) -> void:
	if _view_follow and is_instance_valid(camera):
		var target:=_look.lerp(_party.position,1-exp(-delta*8.0))
		_aim(target,Vector3(-30,107,30))
