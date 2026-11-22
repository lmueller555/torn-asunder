extends Node3D
## Exact shared exterior art study in its established coordinate frame. This
## does not instantiate a battlefield, invent damage, or certify art approval.
const ASSETS:="res://assets/overworld/marches/"
const MINE_ORIGIN:=Vector3(0,36,-70)
# West approach sightline only; overworld and battlefield scale differ.
const WEST_VANTAGE:=Vector2(-34.0,-46.0)
var arrival_ground:=Vector3.INF
var ground:MeshInstance3D
var mine:Node3D

func prepare_exact_exterior()->bool:
	if ground and mine:
		return arrival_ground.is_finite()
	var corridor:=_mount("marches-corridor.glb",Vector3.ZERO)
	mine=_mount("greyhollow-mine.glb",MINE_ORIGIN)
	if not corridor or not mine:
		return false
	ground=corridor.find_child("MarchesGround",true,false) as MeshInstance3D
	if not ground:
		return false
	for piece:MeshInstance3D in corridor.find_children("*","MeshInstance3D",true,false):
		if piece!=ground:
			piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrival_ground=_floor_from_mesh(WEST_VANTAGE)
	return arrival_ground.is_finite() and mine.find_children("*","MeshInstance3D",true,false).size()>0

func _floor_from_mesh(p:Vector2)->Vector3:
	# Detached CPU ray against the actual imported ground triangles, not the height of a prop.
	var transform_to_sector:=Transform3D.IDENTITY
	var current:Node3D=ground
	while current!=self:
		transform_to_sector=current.transform*transform_to_sector
		current=current.get_parent() as Node3D
		if not current: return Vector3.INF
	var query_top:=Vector3(p.x,260.,p.y)
	var query_bottom:=Vector3(p.x,-110.,p.y)
	var local_from_world:=transform_to_sector.affine_inverse()
	var a:=local_from_world*query_top
	var b:=local_from_world*query_bottom
	var outline:=ground.mesh.get_faces()
	var nearest:=Vector3.INF
	for i in range(0,outline.size(),3):
		var point:Variant=Geometry3D.segment_intersects_triangle(a,b,outline[i],outline[i+1],outline[i+2])
		if point is Vector3:
			var world:Vector3=transform_to_sector*point
			if not nearest.is_finite() or world.y>nearest.y:
				nearest=world
	return nearest

func _mount(file:String,at:Vector3)->Node3D:
	var asset:=load(ASSETS+file) as PackedScene
	if not asset:
		return null
	var node:=asset.instantiate() as Node3D
	if node:
		add_child(node)
		node.position=at
	return node

func _ready()->void:
	if not prepare_exact_exterior():
		return
	_reuse_study_detail()
	for xz:Vector2 in [Vector2(5,-34),Vector2(26,-22),Vector2(69,-21)]:
		var at:=_floor_from_mesh(xz)
		if at.is_finite():
			var grove:=_mount("marches-copse-near.glb",at+Vector3.DOWN*.48)
			if grove: _enable_native_tree_pigment(grove)
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#a3a89d")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#cccfbb")
	env.ambient_light_energy=.51
	env.fog_enabled=true
	env.fog_density=.001
	env.fog_light_color=Color("#b7bdad")
	var environment:=WorldEnvironment.new()
	environment.environment=env
	add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-51,-34,0)
	light.light_color=Color("#ffe5b9")
	light.light_energy=.94
	light.shadow_enabled=true
	light.directional_shadow_max_distance=260
	add_child(light)
	set_lens(false)

func set_lens(near:bool)->void:
	if near:
		$Camera.look_at_from_position(MINE_ORIGIN+Vector3(55,54,66),MINE_ORIGIN+Vector3(0,5,-4))
	else:
		$Camera.look_at_from_position(MINE_ORIGIN+Vector3(-78,162,190),MINE_ORIGIN+Vector3(0,3,0))

func _reuse_study_detail()->void:
	# Same terrain-detail treatment and placements as the shared Greyhollow study.
	var macro:=ground.get_active_material(0) as StandardMaterial3D
	if not macro or not macro.albedo_texture:
		return
	var source:=load(ASSETS+"detail/marches-surface-detail.png") as Texture2D
	if not source:
		return
	var tile:=source.get_image()
	if tile.is_compressed():
		tile.decompress()
	if not tile.has_mipmaps():
		tile.generate_mipmaps()
	var detail:=ShaderMaterial.new()
	detail.shader=load(ASSETS+"detail/marches_surface.gdshader") as Shader
	detail.set_shader_parameter("macro_map",macro.albedo_texture)
	detail.set_shader_parameter("detail_map",ImageTexture.create_from_image(tile))
	detail.set_shader_parameter("detail_strength",.64)
	detail.set_shader_parameter("silt_pixel_depth",.058)
	detail.set_shader_parameter("rock_pixel_depth",.19)
	ground.set_surface_override_material(0,detail)

func _enable_native_tree_pigment(model:Node3D)->void:
	var materials:Dictionary={}
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for slot in mesh.get_surface_override_material_count():
			var source:=mesh.get_active_material(slot) as StandardMaterial3D
			if not source:
				continue
			var key:=source.get_instance_id()
			if not materials.has(key):
				var native_color:=source.duplicate() as StandardMaterial3D
				native_color.vertex_color_use_as_albedo=true
				materials[key]=native_color
			mesh.set_surface_override_material(slot,materials[key])


# Compatibility with shared MarchesView controls; no new bindings.
signal zoom_requested
var _zoomed:=false

func configure_overworld_art(_world,_clears,_reduced:bool)->void:
	pass

func show_party_state(_travelling:bool,_selected_id:String)->void:
	pass

func toggle_zoom(_at:Vector3)->void:
	_zoomed=not _zoomed
	zoom_requested.emit()
