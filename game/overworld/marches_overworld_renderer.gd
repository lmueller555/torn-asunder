extends Node3D
## Authored Seven Marches relief, renderer-facing positions and in-world presentation.
signal presentation_camera_changed

const World := preload("res://game/campaign_world.gd")
const ASSETS := "res://assets/overworld/marches/"
const ROUTE := Color("#e2c58d")
const CampSite := preload("res://game/overworld/marches_camp_site.gd")
const CrossingSite := preload("res://game/overworld/marches_crossing_site.gd")
const CROSSING := "marches_crossing"
const SITES := ["marches_camp", "year_one_mine", "marches_road", CampSite.CAMP_ID, CROSSING]
const GROVE_PLACES := [
	Vector3(-286,170,3), Vector3(-261,148,3), Vector3(-208,153,5), Vector3(-176,146,9),
	Vector3(-160,49,2), Vector3(5,-34,4), Vector3(26,-22,2), Vector3(69,-21,7),
	Vector3(221,-21,8), Vector3(-326,181,6), Vector3(-299,181,0), Vector3(-243,188,9),
	Vector3(-215,183,4), Vector3(-193,181,7), Vector3(-166,165,1), Vector3(-79,105,3),
	Vector3(-16,90,7), Vector3(61,135,0), Vector3(142,169,2), Vector3(181,160,5),
	Vector3(214,141,1), Vector3(254,125,6),
]
var anchors: Dictionary[String, Vector3] = {}
var route_points: Array[PackedVector3Array] = []
var route_keys: Array[Vector2i] = []
var _curves: Dictionary[String, Curve3D] = {}
var _route_pins: Array[MultiMeshInstance3D] = []
var _open_pigment: StandardMaterial3D
var _closed_pigment: StandardMaterial3D
var _world: World
var _completed_for_probe := PackedStringArray()
var _missing := PackedStringArray()
var _tree_materials: Dictionary = {}
var _ground: MeshInstance3D
var _groves: Array[Array] = []
var _camp_views: Node3D
var _crossing: Node3D
var _focus_site := ""
const EAST_FOCUS := [CROSSING, "marches_road", CampSite.CAMP_ID]
var camera: Camera3D
var _party: Node3D
var _look := Vector3(-20,13,42)
var _view_follow := false
var _reduced_motion := false
var _active := false
var _zoomed := false

func _ready() -> void:
	camera = $Camera
	_party = $Party
	_read_contract()
	_build_lighting()
	var west := _mount("marches-corridor.glb", Vector3.ZERO)
	var crossing := CrossingSite.route()
	if west and crossing and crossing.point_count==265:
		_crossing=CrossingSite.mount(self,west)
		if _crossing:
			var line := PackedVector3Array()
			for i in crossing.point_count:
				line.append(crossing.get_point_position(i))
			anchors[CROSSING]=line[-1]
			route_points.append(line)
			route_keys.append(Vector2i(SITES.find(CrossingSite.ROAD),SITES.find(CROSSING)))
			_insert_curve(CrossingSite.ROAD,CROSSING,line)
	_mount("marches-camp.glb", anchors["marches_camp"])
	_mount("greyhollow-mine.glb", anchors["year_one_mine"])
	_add_forward_camp_art()
	_build_routes()
	_refresh_links()
	_build_party()
	_set_regional()
	_place_groves.call_deferred()

func configure_overworld_art(world: World, completed: PackedStringArray, reduced: bool) -> void:
	_world = world
	_completed_for_probe = completed.duplicate()
	_reduced_motion = reduced

func show_party_state(travelling: bool, selected: String) -> void:
	if not is_node_ready():
		return
	if not travelling:
		if _view_follow or not _active or (_focus_site != selected and (_focus_site in EAST_FOCUS or selected in EAST_FOCUS)):
			_focus_site = selected
			_zoomed = false
			_set_regional()
		_view_follow=false
	else:
		if not _view_follow:
			_look = _party.position
		_view_follow=not _reduced_motion
	_active=true

func _set_regional() -> void:
	_look=Vector3(-20,13,42)
	var offset := Vector3(-116,370,430)
	if _focus_site==CROSSING and _crossing:
		_look=Vector3(682,11,-19)
		offset=Vector3(-111,390,382)
	elif _focus_site in EAST_FOCUS and _crossing:
		_look=Vector3(455,13,46)
		offset=Vector3(-116,465,530)
	camera.position=_look+offset
	camera.look_at(_look)
	_update_grove_tiers()
	presentation_camera_changed.emit()

func toggle_zoom(point: Vector3) -> void:
	if _view_follow or camera==null:
		return
	_zoomed=not _zoomed
	if not _zoomed:
		_set_regional()
		return
	var look:=point+Vector3(1,4,-3)
	camera.position=look+Vector3(61,50,71)
	camera.look_at(look)
	_update_grove_tiers()
	presentation_camera_changed.emit()

func _process(delta: float) -> void:
	if _view_follow and camera!=null:
		_look=_look.lerp(_party.position,1-exp(-delta*8.0))
		camera.position=_look+Vector3(-62,131,154)
		camera.look_at(_look+Vector3.UP*5.0)
		_update_grove_tiers()
		presentation_camera_changed.emit()

func _read_point(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		return Vector3(value.x, value.y, value.z)
	return Vector3.INF

func _read_contract() -> void:
	if not FileAccess.file_exists(ASSETS+"anchors.json"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"anchors.json"))
	if not data is Dictionary:
		return
	var proposed: Variant = data.get("anchors", {})
	if proposed is Dictionary:
		for id in SITES:
			if proposed.has(id):
				var point := _read_point(proposed[id])
				if point.is_finite():
					anchors[id] = point
	var routes: Variant = data.get("routes", [])
	if routes is Dictionary:
		routes = routes.values()
	if routes is Array:
		for entry: Variant in routes:
			var start_id := ""
			var end_id := ""
			if entry is Dictionary:
				start_id = str(entry.get("start", ""))
				end_id = str(entry.get("end", ""))
				entry = entry.get("points", [])
			if not entry is Array:
				continue
			var line := PackedVector3Array()
			for sample: Variant in entry:
				var point := _read_point(sample)
				if point.is_finite():
					line.append(point)
			if line.size() > 1:
				route_points.append(line)
				route_keys.append(Vector2i(SITES.find(start_id),SITES.find(end_id)))
				if not start_id.is_empty() and not end_id.is_empty():
					_insert_curve(start_id,end_id,line)

func _add_forward_camp_art() -> void:
	if _world==null or _world.waypoint(CampSite.CAMP_ID).is_empty():
		return
	var pts := CampSite.route()
	if pts.size()<2:
		return
	var near := load(CampSite.ASSETS+"marches-road-camp-fit.glb") as PackedScene
	var far := load(CampSite.ASSETS+"marches-road-camp-fit-regional.glb") as PackedScene
	if near==null or far==null:
		return
	anchored_camp(pts,near,far)


func anchored_camp(pts: PackedVector3Array, near: PackedScene, far: PackedScene) -> void:
	anchors[CampSite.CAMP_ID]=pts[-1]
	route_points.append(pts)
	route_keys.append(Vector2i(SITES.find(CampSite.ROAD_ID),SITES.find(CampSite.CAMP_ID)))
	var shell:=Node3D.new()
	shell.name="MarchesRoadCampArt"
	add_child(shell)
	shell.position=CampSite.MOUNT
	shell.rotation.y=PI
	var detail := near.instantiate() as Node3D
	var distant := far.instantiate() as Node3D
	shell.add_child(detail)
	shell.add_child(distant)
	_enable_vegetation_pigment(detail)
	_enable_vegetation_pigment(distant)
	_camp_views=shell
	_groves.append([shell,detail,distant])


func _insert_curve(start_id: String, end_id: String, points: PackedVector3Array) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.1
	for p in points:
		curve.add_point(p)
	_curves[start_id+"/"+end_id] = curve

func _mount(file: String, point: Vector3) -> Node3D:
	var path := ASSETS+file
	if not ResourceLoader.exists(path, "PackedScene"):
		_missing.append(file)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		_missing.append(file)
		return null
	var view := packed.instantiate() as Node3D
	view.position = point
	add_child(view)
	if file == "marches-corridor.glb":
		# The far vista and shallow water are backdrop, not shadow casters.
		for mesh: MeshInstance3D in view.find_children("*","MeshInstance3D",true,false):
			if mesh.name!="MarchesGround":
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ground = view.find_child("MarchesGround",true,false) as MeshInstance3D
		if _ground != null:
			_ground.create_trimesh_collision()
			var base := _ground.get_active_material(0) as StandardMaterial3D
			if base != null and base.albedo_texture != null:
				var tile := preload("res://assets/overworld/marches/detail/marches-surface-detail.png").get_image()
				if tile.is_compressed():
					tile.decompress()
				if not tile.has_mipmaps():
					tile.generate_mipmaps()
				var material := ShaderMaterial.new()
				material.shader = preload("res://assets/overworld/marches/detail/marches_surface.gdshader")
				material.set_shader_parameter("macro_map",base.albedo_texture)
				material.set_shader_parameter("detail_map",ImageTexture.create_from_image(tile))
				material.set_shader_parameter("detail_strength",0.64)
				material.set_shader_parameter("silt_pixel_depth",0.058)
				material.set_shader_parameter("rock_pixel_depth",0.19)
				_ground.set_surface_override_material(0,material)
	return view

func _place_groves() -> void:
	var near_stem := ASSETS+"marches-copse-near.glb"
	var far_stem := ASSETS+"marches-copse-regional.glb"
	if _ground==null or not ResourceLoader.exists(near_stem) or not ResourceLoader.exists(far_stem):
		return
	var near := load(near_stem) as PackedScene
	var far := load(far_stem) as PackedScene
	if near==null or far==null:
		return
	if not is_inside_tree():
		return
	var scene_tree := get_tree()
	await scene_tree.physics_frame
	await scene_tree.physics_frame
	if not is_inside_tree():
		return
	for i in GROVE_PLACES.size():
		var entry: Vector3 = GROVE_PLACES[i]
		var planar := Vector2(entry.x,entry.y)
		var near_road := false
		for line in route_points:
			for p: Vector3 in line:
				if Vector2(p.x,p.z).distance_to(planar) < 18.0:
					near_road = true
					break
			if near_road:
				break
		if near_road:
			continue
		var point := Vector3(planar.x,0.0,planar.y)
		if Vector2(anchors["marches_camp"].x,anchors["marches_camp"].z).distance_to(planar)<33.0 or Vector2(anchors["year_one_mine"].x,anchors["year_one_mine"].z).distance_to(planar)<35.0:
			continue
		var down := PhysicsRayQueryParameters3D.create(point+Vector3.UP*220.0,point-Vector3.UP*50.0)
		var sample := get_world_3d().direct_space_state.intersect_ray(down)
		if sample.is_empty() or sample.normal.y < 0.77:
			continue
		var grove := Node3D.new()
		add_child(grove)
		grove.position = sample.position + Vector3.DOWN*0.48
		var soft_up := Vector3.UP.slerp(sample.normal,0.56)
		grove.basis = Basis(Quaternion(Vector3.UP,soft_up))*Basis(Vector3.UP,0.78*entry.z)
		grove.scale = Vector3.ONE*(0.74+float(i%4)*0.105)
		var wide := far.instantiate() as Node3D
		var close := near.instantiate() as Node3D
		grove.add_child(wide)
		grove.add_child(close)
		_enable_vegetation_pigment(wide)
		_enable_vegetation_pigment(close)
		_groves.append([grove,close,wide])
	_place_crossing_groves(near,far)
	_update_grove_tiers()
	print("OVERWORLD GROVES rendered groups=",_groves.size())

func _place_crossing_groves(near: PackedScene,far: PackedScene) -> void:
	if not _crossing:
		return
	var sites: Array[Array] = []
	for row: Array in CrossingSite.GROVES:
		var origin: Vector3 = row[0]
		var ray := PhysicsRayQueryParameters3D.create(origin+Vector3.UP*15.0,origin-Vector3.UP*15.0)
		var sample := get_world_3d().direct_space_state.intersect_ray(ray)
		if sample.is_empty() or absf(sample.position.y-origin.y)>.004:
			push_warning("Refusing misgrounded crossing copse: "+str(origin))
			return
		sites.append([sample,row])
	for pair: Array in sites:
		var sample: Dictionary = pair[0]
		var row: Array = pair[1]
		var grove := Node3D.new()
		add_child(grove)
		grove.position = sample.position + Vector3.DOWN*float(row[3])
		var soft_up := Vector3.UP.slerp(sample.normal,0.56)
		grove.basis = Basis(Quaternion(Vector3.UP,soft_up))*Basis(Vector3.UP,deg_to_rad(float(row[1])))
		grove.scale = Vector3.ONE*float(row[2])
		var wide := far.instantiate() as Node3D
		var close := near.instantiate() as Node3D
		grove.add_child(wide)
		grove.add_child(close)
		_enable_vegetation_pigment(wide)
		_enable_vegetation_pigment(close)
		_groves.append([grove,close,wide])

func _enable_vegetation_pigment(model: Node3D) -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for slot in range(mesh.get_surface_override_material_count()):
			var source := mesh.get_active_material(slot) as StandardMaterial3D
			if source==null:
				continue
			var id := source.get_instance_id()
			if not _tree_materials.has(id):
				var painted := source.duplicate() as StandardMaterial3D
				painted.vertex_color_use_as_albedo = true
				_tree_materials[id] = painted
			mesh.set_surface_override_material(slot,_tree_materials[id])

func _update_grove_tiers() -> void:
	for entry in _groves:
		var distance_square: float = camera.global_position.distance_squared_to(entry[0].global_position)
		var threshold := 52670.0 if entry[1].visible else 44100.0
		var close := distance_square < threshold
		entry[1].visible = close
		entry[2].visible = not close

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("#879a91")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("#aabbb4")
	atmosphere.ambient_light_energy = 0.27
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("#9eb0a8")
	atmosphere.fog_light_energy = 0.38
	atmosphere.fog_sun_scatter = 0.07
	atmosphere.fog_mode = Environment.FOG_MODE_DEPTH
	atmosphere.fog_depth_begin = 310.0
	atmosphere.fog_depth_end = 1170.0
	atmosphere.fog_depth_curve = 1.35
	world.environment = atmosphere
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -51, 0)
	sun.light_color = Color("#ffe5c2")
	sun.light_energy = 0.61
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 270.0
	sun.directional_shadow_split_1 = 0.15
	sun.directional_shadow_split_2 = 0.32
	sun.directional_shadow_split_3 = 0.60
	add_child(sun)

func _build_routes() -> void:
	if route_points.is_empty():
		return
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#82956d") # Road guidance, never the live gold cursor tether.
	var disabled := glow.duplicate() as StandardMaterial3D
	disabled.albedo_color = Color("#776864")
	_open_pigment = glow
	_closed_pigment = disabled
	var dash := SphereMesh.new()
	dash.radius = 0.78
	dash.height = 1.56
	dash.radial_segments = 8
	dash.rings = 4
	for band_index in route_points.size():
		var line := route_points[band_index]
		var remaining := 5.1
		var visible_points := PackedVector3Array()
		for i in range(1,line.size()):
			var start := line[i-1]
			var finish := line[i]
			var len := start.distance_to(finish)
			if len < 0.001:
				continue
			while remaining <= len:
				var point := start.lerp(finish, remaining/len)
				if SITES.all(func(id: String) -> bool: return not anchors.has(id) or point.distance_to(anchors[id]) > 6.0):
					visible_points.append(point + Vector3.UP*1.25)
				remaining += 7.7
			remaining -= len
		if visible_points.is_empty():
			continue
		var group := MultiMesh.new()
		group.transform_format = MultiMesh.TRANSFORM_3D
		group.mesh = dash
		group.instance_count = visible_points.size()
		for i in visible_points.size():
			group.set_instance_transform(i,Transform3D(Basis.IDENTITY,visible_points[i]))
		var marks := MultiMeshInstance3D.new()
		marks.multimesh = group
		marks.material_override = glow if band_index == 0 else disabled
		_route_pins.append(marks)
		marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marks)

func _link_locked(from_id: String, to_id: String) -> bool:
	if _world==null:
		return to_id=="marches_road"
	for edge: Dictionary in _world.routes():
		if (edge.from_id==from_id and edge.to_id==to_id) or (edge.from_id==to_id and edge.to_id==from_id):
			var clear_id: String = edge.get("required_clear_id","")
			return not clear_id.is_empty() and not _completed_for_probe.has(clear_id)
	return true

func _refresh_links() -> void:
	for i in range(mini(_route_pins.size(),route_keys.size())):
		var ends := route_keys[i]
		if ends.x>=0 and ends.y>=0:
			_route_pins[i].material_override = _closed_pigment if _link_locked(SITES[ends.x],SITES[ends.y]) else _open_pigment

func _mesh_under(node: Node3D, mesh: Mesh, pos: Vector3, tone: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tone
	mat.roughness = 0.84
	part.material_override = mat
	node.add_child(part)
	return part

func _build_party() -> void:
	_party.position = anchors["marches_camp"] + Vector3.UP*0.25
	var ring := TorusMesh.new()
	ring.inner_radius = 2.45
	ring.outer_radius = 2.70
	ring.rings = 32
	ring.ring_segments = 8
	var arc := _mesh_under(_party,ring,Vector3(0,0.16,0),Color("#e6c48a"))
	var arc_mat := arc.material_override as StandardMaterial3D
	arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Only a small original standard at map scale, not a reused gameplay model.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.075
	pole.bottom_radius = 0.098
	pole.height = 3.65
	pole.radial_segments = 8
	_mesh_under(_party,pole,Vector3(0,1.85,0),Color("#5a452e"))
	var tip := SphereMesh.new()
	tip.radius = 0.13
	tip.height = 0.26
	tip.radial_segments = 8
	tip.rings = 4
	_mesh_under(_party,tip,Vector3(0,3.74,0),Color("#c5a46c"))
	var cloth := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.04,3.41,0),Vector3(0.10,1.95,0.03),Vector3(1.16,2.26,0.14),Vector3(1.76,2.39,-0.13),Vector3(1.57,3.11,-0.12),Vector3(0.84,3.22,0.12)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,5,5,2,3,5,3,4])
	cloth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var banner := _mesh_under(_party,cloth,Vector3.ZERO,Color("#9f4a38"))
	(banner.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED

