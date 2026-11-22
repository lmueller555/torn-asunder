extends Node3D
## Presentation only, additive on the frozen Year Four scene.
const Relief := preload("res://game/overworld/sereth/keeper_relief.gd")
const Paint := preload("res://game/overworld/sereth/keeper_context.gdshader")
const LandscapeMaterial := preload("res://game/overworld/sereth/keeper_horizon_ground.gdshader")
const Beds := preload("res://game/overworld/sereth/keeper_yard.gdshader")
const CLUSTERS := [
	Vector4(-104,-36,32,25),Vector4(-56,-47,24,19),Vector4(-118,56,39,31),
	Vector4(-61,72,30,27),Vector4(19,67,38,26),Vector4(59,-45,30,20),
	Vector4(93,-81,46,32),Vector4(100,27,36,22),Vector4(-169,-82,31,44),
	Vector4(137,70,29,30),Vector4(-30,-102,71,33),Vector4(31,-67,29,14),
]
var _rand := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _placed: Dictionary = {}
var _batches: Dictionary = {}
var _border: Array[Vector3] = []

func _ready() -> void:
	_detail.call_deferred()

func _detail() -> void:
	_rand.seed=69934
	_noise.seed=920547
	_noise.frequency=.045
	var relief := get_parent() as Relief
	if not relief or not relief.mount_ready():
		return
	# Keep previous V1 land and post in place; replace only their thin spruce scatter.
	var scatter := relief.get_node_or_null("NeutralKeeperPost/Conifer") as Node3D
	if scatter:
		scatter.hide()
	# Fade the old decorative road tail outside certified route extent, not
	# the protected true road, its ground, or the certified sheep track.
	var substrate := relief.get_node("KeeperRelief") as MeshInstance3D
	var context_material := ShaderMaterial.new()
	context_material.shader=LandscapeMaterial
	substrate.material_override=context_material
	_yard()
	_scree()
	_copses()
	for tag: String in _batches:
		_emit(tag,_batches[tag])
	_background()

func _fit(tag: String, p: Vector2, h: float, scale_: Vector3, angle: Vector3) -> void:
	if not _batches.has(tag):
		_batches[tag]=[]
	var y := Relief.at(p,h)
	_batches[tag].append(Transform3D(Basis.from_euler(angle).scaled_local(scale_),y))
	if not _placed.has(tag):
		_placed[tag]=[]
	_placed[tag].append(Relief.at(p))

func _yard() -> void:
	# Dry laid hardstanding only: fill remains continuous with the actual porch
	# approach and trails off before the exposed road. Not another route.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := Vector2i(42,20)
	const CENTER := Vector2(7.5,-11.5)
	for j in range(N.y+1):
		for i in range(N.x+1):
			var uv := Vector2(2.0*i/N.x-1.,2.0*j/N.y-1.)
			var p := CENTER+uv*Vector2(21.4,8.1)
			var edges := pow(absf(uv.x),3)+pow(absf(uv.y),3)
			var fade := (1.-smoothstep(.46,1.0,edges+_noise.get_noise_2dv(p*2.)*.27)) \
				* smoothstep(5.7,8.5,absf(p.y-Relief.road(p.x)))
			st.set_color(Color(1,1,1,fade))
			st.set_normal(Vector3.UP)
			st.add_vertex(Relief.at(p,.046))
	for j in range(N.y):
		for i in range(N.x):
			var a := j*(N.x+1)+i
			var b := a+N.x+1
			for k: int in [a,a+1,b,a+1,b+1,b]:
				st.add_index(k)
	var yard := MeshInstance3D.new()
	yard.name="FadedKeeperHardstanding"
	yard.mesh=st.commit()
	var m := ShaderMaterial.new()
	m.shader=Beds
	yard.material_override=m
	yard.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(yard)
	# Short runner of land-sited pavers between the porch and western piers.
	for i in range(11):
		for j in range(2):
			var p := Vector2(-8.1+i*.61, -10.55+j*.77 + .11*sin(i))
			_fit("Setts",p,.10,Vector3(.58,.34,.72),Vector3(0,.22*sin(i*2.14+j),0))
	# Distinct curtain of old retaining stone on the uphill side of the precinct.
	for i in range(25):
		var x := -11.5+i*1.48
		var z := -17.8-.48*cos(i*.37)
		if i in [9,10,19,20]:
			continue
		_fit("RetainingCourse",Vector2(x,z),.21,Vector3(1.39,.57,.71),Vector3(.07,.17*sin(i),0))
		if i in [1,2,3,6,7,11,13,14,16,21,22,23]:
			_fit("RetainingCourse",Vector2(x+.18,z+.10),.65,Vector3(1.28,.42,.63),Vector3(.024,.10*sin(i),.04))
		_border.append(Relief.at(Vector2(x,z)))
	for i in range(12):
		# Fallen stone chips reinforce the retaining wall; no new architecture.
		var xy := Vector2(-10+i*2.45,-18.75-.95*sin(i*.71))
		_fit("ColluvialSlate",xy,.11,Vector3(.82,.49,.58),Vector3(.26,i*1.8,.23))

func _scree() -> void:
	# Stepped talus packets on the OUTER shoulder of the lower sheep track.
	# Leave its existing curve and the exposed road completely undisturbed.
	for site: float in [-65.0,-43.0,-11.0,29.0,53.0,72.0]:
		for i in range(13):
			var x := site + _rand.randf_range(-4.3,4.3)
			var z := Relief.track(x)+_rand.randf_range(5.5,11.8)
			var size_ := _rand.randf_range(.48,1.32)
			_fit("ColluvialSlate",Vector2(x,z),size_*.15,Vector3(size_*1.47,size_*.67,size_),
				Vector3(_rand.randf_range(-.19,.34),_rand.randf()*TAU,.34))
		for i in range(3):
			var x := site-1.4+i*1.43
			var z := Relief.track(x)+7.6+i*.68
			_fit("ScreeSteps",Vector2(x,z),.30,Vector3(1.65,.68,1.02),Vector3(.17,.24*sin(i+site),.14))
	for site: float in [-137.0,112.0,131.0,146.0]:
		for i in range(7):
			var x := site+_rand.randf_range(-5.,5.)
			var z := Relief.road(x)-_rand.randf_range(7.2,14.3)
			var s := _rand.randf_range(.50,1.76)
			_fit("ColluvialSlate",Vector2(x,z),s*.11,Vector3(s*1.4,s*.75,s*.89),Vector3(.29*sin(i),i*1.27,.26))

static func sight_clear(p: Vector2) -> bool:
	# Strictly keep long views toward west threshold, arrival and bends.
	return p.distance_to(Relief.ARRIVAL)>29.0 and p.distance_to(Relief.POST)>27.5 \
		and absf(p.y-Relief.road(p.x))>11.5 and absf(p.y-Relief.track(p.x))>5.8

func _grove(p: Vector2) -> float:
	var blend := 0.0
	for c: Vector4 in CLUSTERS:
		var q := (p-Vector2(c.x,c.y)).rotated(c.x*.016)
		blend=maxf(blend,1.-smoothstep(.32,1.13,(q/Vector2(c.z,c.w)).length()))
	return clampf(blend+_noise.get_noise_2dv(p*.81)*.55,0,1)

func _copses() -> void:
	for j in range(59):
		for i in range(80):
			var p := Vector2(-229.+i*5.13,-165.+j*5.12)+Vector2(_rand.randf_range(-2.1,2.1),_rand.randf_range(-2.32,2.32))
			if not sight_clear(p):
				continue
			var cover := _grove(p)
			var spin := _rand.randf()*TAU
			if cover>.51 and _rand.randf()<.43*cover:
				var h := _rand.randf_range(3.3,7.7)
				var s := _rand.randf_range(.74,1.39)
				_fit("RidgeCrown",p,-.04,Vector3(s,h/5.7,s),Vector3(.065*sin(i),spin,.11*cos(j)))
				_fit("RidgeBark",p,.64,Vector3(.19,1.41,.22),Vector3(0,spin,.073*sin(i)))
			elif cover>.21 and _rand.randf()<.37:
				var k := _rand.randf_range(.53,1.52)
				_fit("QuietHeather",p,k*.23,Vector3(k*1.3,k*.56,k*1.1),Vector3(0,spin,.14*sin(i)))

func _crown() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 5:
		var w := 1.46-row*.273
		var y := 1.19+row*.96
		for i in range(10):
			var a := TAU*i/10.+row*.63
			var b := TAU*(i+1)/10.+row*.63
			var m := (a+b)*.5
			var scale_ := .93+.17*cos(float(i)*2.66+row)
			var left := Vector3(cos(a)*w,y+.11,sin(a)*w)
			var right := Vector3(cos(b)*w,y+.19,sin(b)*w)
			var spike := Vector3(cos(m)*w*1.37*scale_,y-.22+.10*sin(m),sin(m)*w*1.37*scale_)
			var top := Vector3(.07*row,y+1.30,.031*row)
			for point: Vector3 in [top,left,spike,top,spike,right,Vector3(.04*row,y-.32,0),spike,left,
				Vector3(.04*row,y-.32,0),right,spike]:
				st.add_vertex(point)
	st.generate_normals()
	return st.commit()

func _emit(tag: String, frames: Array) -> void:
	var types := {"Setts":"#72665a","RetainingCourse":"#837d6b","ScreeSteps":"#716c61",
		"ColluvialSlate":"#77746a","RidgeCrown":"#364937","RidgeBark":"#605342","QuietHeather":"#655b46"}
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	if tag=="RidgeCrown":
		multi.mesh=_crown()
	elif tag in ["QuietHeather","ColluvialSlate"]:
		var stones := SphereMesh.new()
		stones.radial_segments=6
		stones.rings=3
		multi.mesh=stones
	else:
		multi.mesh=BoxMesh.new()
	multi.instance_count=frames.size()
	for i in frames.size():
		multi.set_instance_transform(i,frames[i])
		var grain := _rand.randf_range(.71,1.0)
		multi.set_instance_color(i,Color(grain,_rand.randf_range(.79,.98),grain*.94))
	var mat := ShaderMaterial.new()
	mat.shader=Paint
	mat.set_shader_parameter("tint",Color(types[tag]))
	mat.set_shader_parameter("needles",tag=="RidgeCrown")
	var node := MultiMeshInstance3D.new()
	node.name=tag
	node.multimesh=multi
	node.material_override=mat
	if tag in ["RidgeCrown","QuietHeather","RidgeBark"]:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

static func height_(p: Vector2) -> float:
	# Low coarser apron sits below every measured play plane, rising only into
	# distant skyline. No duplicate road pigment and no physical body.
	var r := p.length()
	var spin := p.angle()
	var warp := r + 56.*sin(spin*4.3+.42)+21.*cos(spin*8.3)
	var a := 68.0*exp(-pow((warp-276.0)/114.,2.))*(.72+.24*sin(spin*6.8+.8))
	var b := 128.0*exp(-pow((warp-493.0)/117.,2.))*(.64+.29*sin(spin*5.7))
	var c := 164.0*exp(-pow((warp-778.0)/181.,2.))*(.68+.27*sin(spin*4.7+.33))
	var base := a+b+c+14.*sin(p.x*.026+p.y*.019)*sin(p.y*.046)
	var gateway := 1.-smoothstep(47.,92.,absf(p.y+14.))
	var join := smoothstep(152.,233.,absf(p.x))*(1.-smoothstep(325.,460.,absf(p.x)))
	if p.x>0.:
		base += gateway*join*37.
	var rear := smoothstep(147.,243.,maxf(absf(p.x),absf(p.y)*1.14))
	return base*rear-14.

func _background() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N:=Vector2i(103,103)
	for j in range(N.y+1):
		for i in range(N.x+1):
			var p := Vector2(-1150.+i*2300./N.x,-1150.+j*2300./N.y)
			st.set_color(Color(.82,.86,.91))
			st.add_vertex(Vector3(p.x,height_(p),p.y))
	for j in range(N.y):
		for i in range(N.x):
			var a := j*(N.x+1)+i
			var b := a+N.x+1
			for k:int in [a,a+1,b,a+1,b+1,b]:
				st.add_index(k)
	st.generate_normals()
	var rear := MeshInstance3D.new()
	rear.name="LayeredCairnspineHaze"
	rear.mesh=st.commit()
	var mat := ShaderMaterial.new()
	mat.shader=Paint
	mat.set_shader_parameter("tint",Color("#62665b"))
	mat.set_shader_parameter("distant",true)
	rear.material_override=mat
	rear.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rear)
	var camera := get_parent().get_node("Camera") as Camera3D
	camera.far=1480.0
