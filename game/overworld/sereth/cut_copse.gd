extends Node3D
## Private relief dressing: deterministic native mesh batches, no story or physics.
const V2 := preload("res://game/overworld/sereth/cut_relief.gd")
const Pigment := preload("res://game/overworld/sereth/cut_copse.gdshader")
const OMIT := ["MoorFirLower","MoorFirMid","MoorFirUpper","MoorTrunks","WinterStems","WindHeather"]
# Long lobes leave natural negative space between the camp, road and cemetery.
const GROVES := [
	Vector4(-243,-18,56,33),Vector4(-188,-40,36,30),Vector4(-120,-30,53,26),
	Vector4(-90,84,82,44),Vector4(-197,104,49,49),Vector4(-46,-77,61,37),
	Vector4(33,-49,40,48),Vector4(64,89,54,36),Vector4(144,88,32,60),
	Vector4(191,-58,40,51),Vector4(165,-102,46,53),Vector4(219,56,43,50),
	Vector4(-224,-113,63,57),Vector4(-134,-162,51,71),Vector4(54,-160,100,43),
	Vector4(202,-166,77,49),Vector4(-288,116,75,52),Vector4(259,113,63,53),
]
var _relief: V2
var _noise := FastNoiseLite.new()
var _rand := RandomNumberGenerator.new()
var _stems: Array[Transform3D] = []
var _placed: Array[Vector3] = []
var _group_counts: Dictionary = {}
var _front_shadow_count := 0

func _ready() -> void:
	_dress.call_deferred()

func _dress() -> void:
	_relief = get_parent() as V2
	if not _relief or not _relief.has_node("SlateRelief"):
		return
	_rand.seed = 170361
	_noise.seed = 73143
	_noise.frequency = .048
	var pine: Array[Array] = [[],[],[]]
	var brush: Array[Array] = [[],[]]
	var near_shadows: Array[Array] = [[],[],[]]
	for j in 112:
		for i in 126:
			var p := Vector2(-328.+i*5.3,-260.+j*4.9)+Vector2(_rand.randf_range(-2.3,2.3),_rand.randf_range(-2.1,2.1))
			if protected(p):
				continue
			var w := copse_weight(p)
			var bark := _noise.get_noise_2dv(p*1.4 + Vector2(87,14))
			var draw := _rand.randf()
			var y := V2.surface_y(p)
			var pos := Vector3(p.x,y,p.y)
			var rot := _rand.randf()*TAU
			if w > .46 and draw < .42*w:
				if _stems.size()>=940:
					continue
				var kind := _rand.randi_range(0,2)
				var h := _rand.randf_range(4.1,8.6)
				var spread := _rand.randf_range(.81,1.4)
				var pose := Basis.from_euler(Vector3(_rand.randf_range(-.055,.055),rot,_rand.randf_range(-.10,.10)))
				var crown := Transform3D(pose.scaled_local(Vector3(spread,h/6.5,spread)),pos-Vector3.UP*.12)
				pine[kind].append(crown)
				if _front_shadow_count<135 and (p.distance_to(V2.CAMP)<87 or p.distance_to(V2.CUT)<95):
					near_shadows[kind].append(crown)
					_front_shadow_count+=1
				_stems.append(Transform3D(pose.scaled_local(Vector3(.27,h*.46,.26)),pos+Vector3.UP*h*.2))
				_placed.append(pos)
			elif (w>.27 or bark>.32) and draw < .36 and brush[0].size()+brush[1].size()<1100:
				var kind := int(_rand.randf()>.56)
				var span := _rand.randf_range(.68,1.69)
				var form := Basis(Vector3.UP,rot).scaled(Vector3(span,span*_rand.randf_range(.68,1.1),span))
				brush[kind].append(Transform3D(form,pos-Vector3.UP*.065))
				_placed.append(pos)
	for label: String in OMIT:
		var old := _relief.get_node_or_null(label) as MultiMeshInstance3D
		if old:
			old.hide()
	for i in 3:
		var forest := _pine(i)
		_emit("PineCrown%d" % i,forest,pine[i],Color("#425744").lerp(Color("#4f634d"),.23*i))
		_emit("NearCrownShadow%d" % i,forest,near_shadows[i],Color("#425744"),true)
	for i in 2:
		_emit("HeatherShoulder%d" % i,_heather(i),brush[i],Color("#66634e").lerp(Color("#586043"),.75*i))
	var bark_mesh := CylinderMesh.new()
	bark_mesh.radial_segments=5
	bark_mesh.height=1.0
	bark_mesh.top_radius=.28
	bark_mesh.bottom_radius=.65
	_emit("PineTrunk",bark_mesh,_stems,Color("#534338"))
	_soft_light()

func protected(p: Vector2) -> bool:
	var west := V2.CAMP+Vector2(-3,-9)
	var cut := Vector2(117,-11)
	if p.distance_to(west)<34 or p.distance_to(cut)<43 or p.distance_to(Vector2(137,-52))<23:
		return true
	if _relief._road_distance(p)<9.8:
		return true
	if p.x<V2.CAMP.x:
		return absf(p.y-V2.CAMP.y+sin((V2.CAMP.x-p.x)*.024)*4.)<11.5
	if p.x>V2.CUT.x:
		return absf(p.y-25.-sin((p.x-138.)*.022)*5.)<11.5
	return false

func copse_weight(p: Vector2) -> float:
	var cover := 0.0
	for spec: Vector4 in GROVES:
		var local := (p-Vector2(spec.x,spec.y)).rotated(.37+spec.x*.007)
		var d := (local/Vector2(spec.z,spec.w)).length()
		cover = maxf(cover,1.0-smoothstep(.31,1.18,d))
	var fragment := _noise.get_noise_2dv(p*.51)
	return clampf(cover+fragment*.40,.0,1.0)

func _pine(variant: int) -> Mesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Serrated branch whorls overlap with asymmetrical tips and a leaning leader.
	var shelves := 4 if variant==1 else 5
	const B := 10
	for ring in range(shelves):
		var lift := float(ring)/float(shelves-1)
		var h := 1.65+lift*3.83
		var w := lerpf(1.64+.18*variant,.27,lift)
		var twist := ring*.55+variant*.83
		var base := Vector3(.32*lift*sin(variant*2.1+.36),h,.35*lift*cos(variant*.91))
		for i in range(B):
			var a := TAU*float(i)/B + twist
			var b := TAU*float(i+1)/B + twist
			var a_dir := Vector3(cos(a),0,sin(a))
			var b_dir := Vector3(cos(b),0,sin(b))
			var middle := (a_dir+b_dir).normalized()
			var n1 := .87+.20*sin(i*2.5+twist*2.1)
			var n2 := .87+.20*sin((i+1)*2.5+twist*2.1) if i+1<B else .87+.20*sin(twist*2.1)
			var left := base + a_dir*w*n1 + Vector3.UP*.32
			var right := base + b_dir*w*n2 + Vector3.UP*.32
			var point := base+middle*w*(1.35+.16*cos(i*3.44+twist)) +Vector3.UP*(.14-.28*sin(i*1.5+twist))
			var high := base+Vector3.UP*lerpf(1.49,1.07,lift)
			var shade := .76+.22*(.5+.5*cos(a+lift*.45))
			_tri(s,high,left,point,Color(shade,shade*.98,shade*.93))
			_tri(s,high,point,right,Color(shade*.91,shade,shade*.92))
			_tri(s,base-Vector3.UP*.38,point,left,Color(.48,.54,.53))
			_tri(s,base-Vector3.UP*.38,right,point,Color(.46,.54,.51))
	s.generate_normals()
	return s.commit()

func _heather(variant: int) -> Mesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lobe in range(4):
		var a := lobe*2.39
		var base := Vector3(cos(a)*.43,0,sin(a)*.43)
		var boss := base+Vector3(.05*sin(a),.55+.19*cos(a+variant),.12)
		for i in range(6):
			var p := i*TAU/6.0
			var q := (i+1)*TAU/6.0
			var near := base+Vector3(cos(p)*.56,.14+.05*sin(p*2.0),sin(p)*.62)
			var next := base+Vector3(cos(q)*.56,.14+.05*sin(q*2.0),sin(q)*.62)
			_tri(s,boss,near,next,Color(.83+.11*sin(p+variant),.90+.08*sin(p+variant),.75))
	s.generate_normals()
	return s.commit()

func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tone: Color) -> void:
	tool.set_color(tone)
	for point in [a,b,c]:
		tool.add_vertex(point)

func _emit(id: String, mesh: Mesh, batch: Array, tone: Color, shadows_only := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.mesh=mesh
	mm.instance_count=batch.size()
	_group_counts[id]=batch.size()
	for i in batch.size():
		mm.set_instance_transform(i,batch[i])
		var v := _rand.randf_range(.81,1.0)
		mm.set_instance_color(i,Color(v,_rand.randf_range(.87,1.0),v*.96,1))
	var m := ShaderMaterial.new()
	m.shader=Pigment
	m.set_shader_parameter("tint",tone)
	m.set_shader_parameter("underbrush",id.begins_with("Heather"))
	var group := MultiMeshInstance3D.new()
	group.name=id
	group.multimesh=mm
	group.material_override=m
	# Only the handful nearest the playable eye casts occlusion. World-scale
	# silhouettes stay batched without a second full forest shadow pass.
	group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if shadows_only \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(group)

func _soft_light() -> void:
	# Calmer environment contrast to keep relief readable under darker crowns.
	var air := _relief.get_node("Air") as WorldEnvironment
	var source := air.environment
	if not source:
		return
	var local := source.duplicate() as Environment
	local.ambient_light_color=Color("#a7b3b8")
	local.ambient_light_energy=.49
	local.fog_density=.00049
	air.environment=local
	var sun := _relief.get_node("Sun") as DirectionalLight3D
	sun.light_energy=.72
	sun.light_angular_distance=4.0
