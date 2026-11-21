extends RefCounted
## Scoped, packed Crossing presentation for the opt-in Marches review route.
const ASSETS := "res://assets/overworld/marches/crossing/"
const Look := preload("res://game/overworld/marches_crossing_materials.gd")
const Bridge := preload("res://game/overworld/marches_crossing_bridge.gd")
const ID := "marches_crossing"
const ROAD := "marches_road"
const OFFSET := Vector3(420, 0, 0)
const MILL_PIVOT := Vector3(407, 10.6, -57)

const BRIDGE := {"west_attachment":[294.417,7.18,-79],"east_attachment":[339.583,7.18,-79],"crown":[317.0,7.5,-79],"width":7.2}
const GROVES := [
	[Vector3(667,16.77319832,14),224.0,0.590,0.432],
	[Vector3(701,15.24571107,-50),218.0,0.570,0.295],
	[Vector3(765,17.75038986,-109),54.0,0.560,0.637],
	[Vector3(793,13.08349611,-48),287.0,0.550,0.634],
	[Vector3(849,28.60575600,-87),126.0,0.650,0.383],
	[Vector3(862,30.24878845,-69),28.0,0.540,0.406],
]

static func available() -> bool:
	var resources := {"crossing.glb":"PackedScene","seed-mill.glb":"PackedScene",
		"crossing-scenic-rims.scn":"PackedScene","south-softened-vista.res":"ArrayMesh",
		"marches-road-to-crossing.tres":"Curve3D","bank-masks.jpg":"Texture2D",
		"tributary-water-no-ford.jpg":"Texture2D","horizon-pigment.jpg":"Texture2D",
		"north-water-pigment.jpg":"Texture2D","south-water-pigment.jpg":"Texture2D"}
	for name: String in resources:
		if not ResourceLoader.exists(ASSETS+name,resources[name]):
			return false
	return true


static func route() -> Curve3D:
	return load(ASSETS+"marches-road-to-crossing.tres") as Curve3D


static func mount(host: Node3D, rendered_west: Node3D) -> Node3D:
	var east_model := load(ASSETS+"crossing.glb") as PackedScene
	var mill_model := load(ASSETS+"seed-mill.glb") as PackedScene
	var trimmed := load(ASSETS+"south-softened-vista.res") as ArrayMesh
	var mineral := load(ASSETS+"bank-masks.jpg") as Texture2D
	if not east_model or not mill_model or not trimmed or not mineral:
		return null
	var east := east_model.instantiate() as Node3D
	var mill := mill_model.instantiate() as Node3D
	if not east or not mill:
		for node in [east,mill]:
			if node:
				node.free()
		return null
	var vista := rendered_west.find_child("MarchesVista", true, false) as MeshInstance3D
	var obsolete_water := rendered_west.find_child("MarchesVistaWaterEast", true, false) as MeshInstance3D
	var ground := east.find_child("CrossingGround", true, false) as MeshInstance3D
	var texture := load(ASSETS+"tributary-water-no-ford.jpg") as Texture2D
	if not vista or not obsolete_water or not ground or not texture:
		east.free()
		mill.free()
		return null
	var pigments := Look.mount(east, preload("res://assets/overworld/marches/crossing/tributary.gdshader"), texture)
	if pigments.has("error"):
		push_warning("Crossing art study not installed: %s" % pigments.error)
		east.free()
		mill.free()
		return null
	var original_pigment := vista.get_active_material(0)
	east.name = "MarchesCrossingArt"
	east.position = OFFSET
	for mesh: MeshInstance3D in east.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "CrossingRiver":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mill.name = "NorthBridgeSeedMill"
	mill.position = MILL_PIVOT
	east.add_child(mill)
	if not _mount_packed_horizon(east,vista,ground,original_pigment,trimmed):
		east.free()
		return null
	obsolete_water.hide()
	host.add_child(east)
	ground.create_trimesh_collision()
	_apply_ground_detail(ground, mineral)
	_apply_apron_sediment(east.find_child("CrossingEastHorizon",true,false) as MeshInstance3D,mineral)
	east.add_child(Bridge.make_deck(BRIDGE))
	return east

static func _apply_ground_detail(ground: MeshInstance3D, mineral: Texture2D) -> void:
	var material := ground.get_active_material(0) as StandardMaterial3D
	if not material or not material.albedo_texture:
		return
	var tile := preload("res://assets/overworld/marches/detail/marches-surface-detail.png").get_image()
	if tile.is_compressed():
		tile.decompress()
	tile.generate_mipmaps()
	var detail := ShaderMaterial.new()
	detail.shader = preload("res://assets/overworld/marches/detail/marches_surface.gdshader")
	if mineral:
		detail.shader=preload("res://assets/overworld/marches/crossing/crossing-ground.gdshader")
		detail.set_shader_parameter("mineral_masks",mineral)
	detail.set_shader_parameter("macro_map", material.albedo_texture)
	detail.set_shader_parameter("detail_map", ImageTexture.create_from_image(tile))
	detail.set_shader_parameter("detail_strength",0.73)
	detail.set_shader_parameter("silt_pixel_depth",0.056)
	detail.set_shader_parameter("rock_pixel_depth",0.18)
	ground.set_surface_override_material(0, detail)

static func _apply_apron_sediment(apron: MeshInstance3D, mineral: Texture2D) -> void:
	if not apron:
		return
	var original := apron.get_active_material(0) as StandardMaterial3D
	if not original or not original.albedo_texture:
		return
	var treatment := ShaderMaterial.new()
	treatment.shader=preload("res://assets/overworld/marches/crossing/crossing-bank.gdshader")
	treatment.set_shader_parameter("macro_map",original.albedo_texture)
	treatment.set_shader_parameter("macro_edge",original.albedo_texture)
	treatment.set_shader_parameter("clamp_macro",not original.texture_repeat)
	treatment.set_shader_parameter("mineral_masks",mineral)
	apron.set_surface_override_material(0,treatment)

static func _mount_packed_horizon(east: Node3D,vista: MeshInstance3D,ground: MeshInstance3D,original: StandardMaterial3D, trimmed: ArrayMesh) -> bool:
	if not original:
		return false
	var crossing_original := ground.mesh.surface_get_material(0) as StandardMaterial3D
	if not crossing_original:
		return false
	var scenery := load(ASSETS+"crossing-scenic-rims.scn") as PackedScene
	if not scenery:
		return false
	var backdrop := scenery.instantiate() as Node3D
	if not backdrop or backdrop.get_child_count()!=3 or trimmed.surface_get_array_index_len(0)!=159690:
		if backdrop:
			backdrop.free()
		return false
	for row in [["CrossingEastHorizon","horizon-pigment.jpg",0.94],["NorthScenicWater","north-water-pigment.jpg",0.81],["SouthScenicWater","south-water-pigment.jpg",0.81]]:
		var target := backdrop.get_node_or_null(NodePath(row[0])) as MeshInstance3D
		var image := load(ASSETS+row[1]) as Texture2D
		if not target or not image:
			backdrop.free()
			return false
		var colour := StandardMaterial3D.new()
		colour.albedo_texture=image
		colour.cull_mode=BaseMaterial3D.CULL_DISABLED
		colour.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		colour.texture_repeat=false
		colour.metallic=0.0
		colour.roughness=float(row[2])
		target.set_surface_override_material(0,colour)
	var apron := ShaderMaterial.new()
	apron.shader=preload("res://assets/overworld/marches/crossing/softened-vista.gdshader")
	apron.set_shader_parameter("old_vista_albedo",original.albedo_texture)
	apron.set_shader_parameter("crossing_albedo",crossing_original.albedo_texture)
	vista.mesh=trimmed
	vista.set_surface_override_material(0,apron)
	east.add_child(backdrop)
	return true
