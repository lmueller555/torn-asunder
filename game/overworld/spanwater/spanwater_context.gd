extends Node3D
## Private off-title environment only; keeps the surveyed physical relief.
const Relief := preload("res://game/overworld/spanwater/spanwater_relief.gd")
const BIOMES := preload("res://game/overworld/spanwater/context_biomes.gdshader")
const RIDGES := preload("res://game/overworld/spanwater/context_ridges.gdshader")
const Plant := preload("res://game/overworld/spanwater/landing_addon.gd")
var _relief: Relief
var _placer: Plant
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _groups: Dictionary = {}
var _samples: Array[Vector3] = []

func _ready() -> void:
	_compose.call_deferred()

func _compose() -> void:
	_relief = get_parent().get_node_or_null("SpanwaterRelief") as Relief
	_placer = get_parent().get_node_or_null("SouthBankStagingDressing") as Plant
	if not _relief or not _placer:
		return
	_rng.seed = 633802
	_noise.seed = 128211
	_noise.frequency = .032
	var old := _relief.get_node("WeatheredHorizon") as MeshInstance3D
	# Leave the reference mesh in-tree for fallback and only hide its visual.
	old.hide()
	_ridges()
	var terrain := _relief.get_node("BankRelief") as MeshInstance3D
	var bank := ShaderMaterial.new()
	bank.shader = BIOMES
	terrain.material_override = bank
	_plant_bank()
	var camera := get_parent().get_node("Camera") as Camera3D
	camera.far = 2200
	var world := get_parent().get_node("WorldEnvironment") as WorldEnvironment
	var env := world.environment
	var sky := Sky.new()
	var haze := ProceduralSkyMaterial.new()
	haze.sky_top_color = Color("#6f889c")
	haze.sky_horizon_color = Color("#c1c6b7")
	haze.ground_bottom_color = Color("#68736d")
	haze.ground_horizon_color = Color("#c1c6b7")
	sky.sky_material = haze
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_density = .00082
	env.fog_sky_affect = .12

func _ridge_height(p: Vector2) -> float:
	var turn := p.angle()
	var r := p.length()
	# Asymmetric crest stacks; narrow, high skyline behind broader foothills.
	var warped := r + 46.0*sin(turn*5.0+.2) + 27.0*sin(turn*10.0)
	var front := 86.0 * exp(-pow((warped - 545.0)/183.0,2))
	var middle := 161.0 * exp(-pow((warped - 845.0)/193.0,2))
	var rear := 206.0 * exp(-pow((warped - 1320.0)/265.0,2))
	var front_shape := .48 + .33*sin(turn*4.0+2.2) + .17*sin(turn*11.0)
	var middle_shape := .60 + .32*sin(turn*3.0+1.4) + .08*sin(turn*17.0)
	var rear_shape := .63 + .25*sin(turn*6.0-.4) + .11*sin(turn*13.0)
	var y := front*front_shape + middle*middle_shape + rear*rear_shape
	y += _noise.get_noise_2dv(p*.24)*(11.0+y*.18)
	# Retain an open far-valley mouth along each end of the unchanged river.
	var center := _relief.center(p.x)
	var bank := maxf(62.0,absf(p.x)*.12)
	y *= lerpf(.075,1.0,smoothstep(bank*.55,bank*1.65,absf(p.y-center)))
	var outside := smoothstep(228.0,460.0,maxf(absf(p.y),absf(p.x)*.59))
	return y*outside-8.3

func _ridges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const NX := 148
	const NZ := 142
	for j in range(NZ+1):
		for i in range(NX+1):
			var p := Vector2(-1900.0+3800.0*i/NX,-1900.0+3800.0*j/NZ)
			var y := _ridge_height(p)
			st.set_color(Color(smoothstep(420.0,1390.0,p.length()),smoothstep(19.0,105.0,y),0,1))
			st.add_vertex(Vector3(p.x,y,p.y))
	for j in NZ:
		for i in NX:
			var a := j*(NX+1)+i
			var b := a+NX+1
			for k in [a,a+1,b,a+1,b+1,b]:
				st.add_index(k)
	st.generate_normals()
	var ridges := MeshInstance3D.new()
	ridges.name = "InterlockedRegionalRidges"
	ridges.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = RIDGES
	ridges.material_override = material
	ridges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridges)

func _protected(p: Vector2) -> bool:
	return p.distance_to(Vector2(118,31)) < 30 or p.distance_to(Vector2(-52,-29)) < 44 \
		or p.distance_to(Relief.SEA)<19 or _relief._route_mask(p)>.052 \
		or _relief._distance(p,Relief.FEEDER)<7.3 or p.distance_to(Relief.FORD)<11.0

func _instance(which: String, p: Vector3, scale_: Vector3, rot := Vector3.ZERO) -> void:
	if not _groups.has(which):
		_groups[which] = []
	var mat := Basis.from_euler(rot).scaled_local(scale_)
	_groups[which].append(Transform3D(mat,p))

func _plant_bank() -> void:
	for j in range(73):
		for i in range(113):
			var p := Vector2(-294.0+i*5.4,-202.0+j*5.62)+Vector2(_rng.randf_range(-2.4,2.4),_rng.randf_range(-2.5,2.5))
			if _protected(p):
				continue
			var y := _placer._ground(p.x,p.y)
			var wet := absf(p.y-_relief.center(p.x))/_relief.width_(p.x)
			var branch := _relief._branch(p)
			var clump := _noise.get_noise_2dv(p*.93)
			var canopy := _noise.get_noise_2dv(p*.42 + Vector2(19,143))
			var roll := _rng.randf()
			var pos := Vector3(p.x,y,p.y)
			var heading := _rng.randf()*TAU
			var shadow := Vector3(0,heading,0)
			if y < .47:
				continue # Do not introduce anything in the static riverbed.
			if (wet < 1.25 or branch < 12.8) and y<3.6:
				if roll>.59 or clump<-.11:
					continue
				if clump>.14:
					for k in 4:
						var shift := Vector2(_rng.randf_range(-1.35,1.35),_rng.randf_range(-1.15,1.15))
						var q := p+shift
						var qy := _placer._ground(q.x,q.y)
						if qy>.46 and not _protected(q):
							var a := _rng.randf_range(.89,1.56)
							_instance("OpenReedFans",Vector3(q.x,qy-.06,q.y),Vector3(a,a*1.3,a),shadow)
							_samples.append(Vector3(q.x,qy,q.y))
				else:
					var s := _rng.randf_range(.55,1.34)
					_instance("BankRoundedStone",pos+Vector3.UP*s*.10,
						Vector3(s*1.6,s*.72,s*.94),Vector3(.20,heading,.28))
					_samples.append(pos)
			elif wet < 2.8 or (branch < 31 and p.y < 120):
				if clump<-.17 or roll>.78:
					continue
				var a := _rng.randf_range(.65,1.58)
				_instance("SedgeTerrace",pos-Vector3.UP*.045,Vector3(a*.98,a*.69,a*.84),shadow)
				_samples.append(pos)
			elif canopy>.24 and roll<.12 and absf(p.y)>62:
				var h := _rng.randf_range(2.4,6.2)
				_instance("AlderTrunks",pos+Vector3.UP*h*.48,Vector3(.36,h,.36),Vector3(.07,heading,.08))
				for k in range(4):
					var spin := heading+k*2.39
					var d := h*(.16+k*.058)
					var l := Vector3(cos(spin)*d,h*(.76+k*.10),sin(spin)*d)
					var w := h*_rng.randf_range(.47,.63)
					_instance("AlderCanopies" if k%2 else "AlderLightTips",pos+l,
						Vector3(w,w*.76,w*.91),Vector3(.1,spin,.19))
				_samples.append(pos)
	for label: String in _groups:
		_emit(label,_groups[label])

func _grass_shape() -> Mesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a := i*2.399
		var n := Vector3(cos(a),0,sin(a))
		var tangent := n.cross(Vector3.UP)
		var foot := n*(.054+.031*i)
		var mid := foot+n*(.16+.012*i)+Vector3.UP*(.31+.029*i)
		var end := mid+n*(.13+.07*sin(i))+Vector3.UP*(.30+.08*sin(i*2.3))
		var l := foot-tangent*.057
		var r := foot+tangent*.057
		var ml := mid-tangent*.037
		var mr := mid+tangent*.037
		for v in [l,r,ml,ml,r,mr,ml,mr,end]:
			s.add_vertex(v)
	s.generate_normals()
	return s.commit()

func _emit(label: String, items: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = .94
	var colors := {"OpenReedFans":"#a28c54","SedgeTerrace":"#7b7950","BankRoundedStone":"#817e6b",
		"AlderTrunks":"#5a4933","AlderCanopies":"#454f2f","AlderLightTips":"#5c663c"}
	m.albedo_color = Color(colors[label])
	if label in ["OpenReedFans","SedgeTerrace"]:
		mm.mesh = _grass_shape()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif label == "AlderTrunks":
		var trunk := CylinderMesh.new()
		trunk.radial_segments = 5
		trunk.top_radius = .18
		trunk.bottom_radius = .48
		trunk.height = 1.0
		mm.mesh = trunk
	else:
		var form := SphereMesh.new()
		form.radial_segments = 8 if label.begins_with("Alder") else 6
		form.rings = 4
		mm.mesh = form
	mm.instance_count = items.size()
	for index in items.size():
		mm.set_instance_transform(index,items[index])
		var v := _rng.randf_range(.71,1.0)
		mm.set_instance_color(index,Color(v,v*_rng.randf_range(.88,1.01),v*.88))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.material_override = m
	# Keep sparse undergrowth regional-friendly. Only meaningful silhouettes shade.
	if label in ["OpenReedFans","SedgeTerrace"]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
