extends Node
## One scene-local visual attachment. The map resource and both solids stay stock.

const Works := preload("res://assets/models/environment/mara_mine_storehouse/works_shell.gd")
const FarWorks := preload("res://assets/models/environment/mara_mine_storehouse/works_shell_far.gd")
const Distance := preload("res://assets/models/environment/mara_mine_storehouse/works_distance.gd")
const Atlas := preload("res://assets/models/environment/mara_mine_storehouse/miner_storehouse_atlas.png")
const MAP := "res://game/battlefields/year_one_mine_campaign.tscn"


func _ready() -> void:
	# The parent mounts its ordinary battlefield during _ready, after child
	# _ready runs. Mount artwork only after that exact scene is in place.
	get_parent().ready.connect(_mount_storehouse, CONNECT_ONE_SHOT)


func _mount_storehouse() -> void:
	var field := get_parent().get_node_or_null(^"YearOneMineCampaign") as Node3D
	if field == null or field.scene_file_path != MAP:
		return
	var body := field.get_node_or_null(^"Geometry/Mine/MinerStorehouse") as StaticBody3D
	if body == null:
		return
	var old_wall := body.get_node_or_null(^"Mesh") as MeshInstance3D
	var old_roof := field.get_node_or_null(^"Geometry/Mine/MinerRoof/Mesh") as MeshInstance3D
	if old_wall == null or old_roof == null:
		return

	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .94
	material.metallic_specular = .12
	material.albedo_texture = Atlas
	var near_kit := Works.new().build(material)
	var far_kit := FarWorks.new().build(material)
	var view := Distance.new()
	view.name = "ClosedWorksStorehouse"
	view.configure(near_kit.mesh, far_kit.mesh)
	near_kit.free()
	far_kit.free()
	# The original wall's local origin is centered 2.1 m above the yard.
	view.position.y = -2.1
	body.add_child(view)
	view.update_for_camera(get_viewport().get_camera_3d())
	old_wall.hide()
	old_roof.hide()
