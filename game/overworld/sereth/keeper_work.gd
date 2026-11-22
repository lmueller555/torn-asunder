extends RefCounted
## Permanent roadside exterior shapes only, with no people or mission state.
const Surface := preload("res://game/overworld/sereth/keeper_surface.gdshader")
var _land
var _mount: Node3D
var _rand := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _tones := {"Ashlar":"#8d8977","Foundation":"#61594e","Timber":"#654c37",
	"Slate":"#50606a","Brush":"#6d6d43","CopperGrass":"#8b7850","Conifer":"#283a31","Talus":"#746a56"}

func build(land: Node3D) -> void:
	_land=land
	_rand.seed=470253
	_mount=Node3D.new()
	_mount.name="NeutralKeeperPost"
	land.add_child(_mount)
	_post()
	_road_edge()
	_cover()
	for layer: String in _batches:
		_emit(layer,_batches[layer])

func _box(key: String,p: Vector3,size: Vector3,r := Vector3.ZERO) -> void:
	if not _batches.has(key):
		_batches[key]=[]
	_batches[key].append(Transform3D(Basis.from_euler(r).scaled_local(size),p))

func _foot(p: Vector2,from: float,thick: float) -> void:
	var point: Vector3 =_land.at(p)
	var top:=maxf(point.y+.30,from)
	var floor:=point.y-.26
	_box("Timber",Vector3(point.x,(floor+top)*.5,point.z),Vector3(thick,top-floor,thick*.88))
	_box("Foundation",point+Vector3.UP*.15,Vector3(thick*1.7,.48,thick*1.76))

func _post() -> void:
	var xy: Vector2=_land.POST
	var base: Vector3=_land.at(xy)
	var s:=base.y
	# Continuous footings, low west porch, open sheltered north-side threshold.
	for z: float in [-3.85,3.85]:
		for k in range(10):
			var x: float=xy.x-8.0+k*1.69
			_box("Foundation",_land.at(Vector2(x,xy.y+z),.21),Vector3(1.66,.85,.95),Vector3(0,.08*sin(k),0))
			for row in range(4):
				var p:=Vector3(x+.29*sin(row*1.8+k),s+.65+row*.79,xy.y+z)
				_box("Ashlar",p,Vector3(1.63,.77+_rand.randf_range(-.05,.05),.75),Vector3(0,.065*sin(k),0))
	for x: float in [-8.31,8.31]:
		for k in range(6):
			var z:=xy.y-3.62+k*1.35
			if x<0 and k in [1,2,3]:
				continue
			for row in range(5):
				_box("Ashlar",Vector3(xy.x+x,s+.37+row*.73,z+.16*sin(row+k)),Vector3(.94,.71,1.3))
	for p in [xy+Vector2(-12,-3.4),xy+Vector2(-12,3.4),xy+Vector2(-8.4,-3.4),xy+Vector2(-8.4,3.4)]:
		_foot(p,s+3.87,.36)
	for z: float in [-3.9,3.9]:
		_box("Timber",Vector3(xy.x-1.55,s+3.92,xy.y+z),Vector3(22.1,.45,.51))
	for x in range(15):
		var x_ := xy.x-12.5+float(x)*1.50
		for side: int in [-1,1]:
			for course in range(5):
				var z: float=.39+float(course)*.96
				var y:=s+6.19-z*.47
				_box("Slate",Vector3(x_+.15*sin(x+course),y,xy.y+z*side),
					Vector3(1.54+_rand.randf_range(-.055,.085),.18,1.18),Vector3(side*.44,0,.017*sin(x)))
		_box("Slate",Vector3(x_,s+6.23,xy.y),Vector3(1.58,.22,.66),Vector3(0,0,.021*sin(x)))
	for i in range(5):
		_box("Foundation",_land.at(xy+Vector2(-11.-i*.68,.7+(i%2)*.07),.14),Vector3(.76,.40,3.76))
	# A quiet rail gives the exposed road an edge without blocking it.
	# Two low gate piers and a raised retaining edge establish the neutral
	# porch precinct, not a gate across the open road.
	for minor: float in [-5.2,5.5]:
		var g:=xy+Vector2(-14.4,minor)
		for layer in range(4):
			_box("Ashlar",_land.at(g,.36+layer*.56),Vector3(1.34-layer*.03,.57,1.62),Vector3(0,.10*sin(layer),0))
		_box("Slate",_land.at(g,2.60),Vector3(1.65,.26,1.86))
	var y0:=xy.y+9.45
	for x: float in [-13.,-8.,-2.,5.,11.]:
		var p:=xy+Vector2(x,y0-xy.y+.26*cos(x))
		_foot(p,_land.at(p).y+1.55,.24)
	for x: float in [-10.5,-4.9,1.6,8.0]:
		var point: Vector3 = _land.at(xy+Vector2(x,y0-xy.y),1.23)
		_box("Timber",point,Vector3(5.96,.22,.20),Vector3(0,.085*sin(x),0))

func _road_edge() -> void:
	# Shallow supported stones confined to one side of each existing path.
	for i in range(54):
		var x:= -90.0+i*3.30+_rand.randf_range(-.35,.35)
		if i%11 in [3,4,5] or absf(x-_land.POST.x)<17:
			continue
		var z: float = _land.road(x)-4.1-.59*sin(i*.69)
		var p: Vector3=_land.at(Vector2(x,z),.16)
		_box("Foundation",p,Vector3(1.8,.55,.85),Vector3(.1*sin(i),.31*cos(i),.09))
	for i in range(48):
		var x: float=-84.0+i*2.80
		var z: float=_land.track(x)+4.3+.82*sin(i*.50)
		for k in range(2):
			if i%14 in [4,5,6,10,13]:
				continue
			var size: float=_rand.randf_range(.55,1.38)
			var p: Vector3 =_land.at(Vector2(x + k*.97,z+.69*sin(k+i)),.14*size)
			_box("Talus",p,Vector3(size*1.42,size*.60,size),Vector3(.23*sin(i),i*.42,.15*cos(i)))

func _cover() -> void:
	var noise := FastNoiseLite.new()
	noise.seed=7353
	noise.frequency=.036
	for j in range(43):
		for i in range(76):
			var p := Vector2(-239.0+i*6.22,-176.0+j*7.16)+Vector2(_rand.randf_range(-2.6,2.6),_rand.randf_range(-2.7,2.7))
			var road: float =absf(p.y-_land.road(p.x))
			var track: float =absf(p.y-_land.track(p.x))
			if road<7.1 or track<3.8 or p.distance_to(_land.POST)<24.0 or p.distance_to(_land.ARRIVAL)<13.:
				continue
			var b := noise.get_noise_2dv(p)
			var h := _rand.randf_range(.42,1.59)
			if b>.19 and absf(p.y)>39.0 and _rand.randf()>.30:
				_box("Conifer",_land.at(p,h*1.7),Vector3(1.66,h*4.12,1.81),Vector3(.10*sin(i),i*2.,.16*cos(j)))
			elif b>.16 or (absf(track)<13.0 and _rand.randf()>.41):
				_box("Brush" if _rand.randf()>.45 else "CopperGrass",_land.at(p,h*.12),Vector3(1.9,h*.71,1.8),Vector3(.17,i,-.11))

func _emit(layer: String, entries: Array) -> void:
	var mesh: Mesh
	if layer=="Conifer":
		# Multi-tier single mesh; clipped borders break the silhouette.
		mesh=_tree()
	elif layer in ["Brush","CopperGrass","Talus"]:
		var m := SphereMesh.new()
		if layer=="Talus":
			m.radial_segments=7
			m.rings=3
			mesh=m
		else:
			m.radial_segments=5
			m.rings=3
			mesh=m
	else:
		mesh=BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.mesh=mesh
	mm.instance_count=entries.size()
	for i in entries.size():
		mm.set_instance_transform(i,entries[i])
		var c:=_rand.randf_range(.72,1.0)
		mm.set_instance_color(i,Color(c,_rand.randf_range(.79,.99),c*.97))
	var node := MultiMeshInstance3D.new()
	node.name=layer
	node.multimesh=mm
	var material := ShaderMaterial.new()
	material.shader=Surface
	material.set_shader_parameter("tint",Color(_tones[layer]))
	material.set_shader_parameter("timber",layer=="Timber")
	node.material_override=material
	if layer in ["Conifer","Brush","CopperGrass"]:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mount.add_child(node)

func _tree() -> Mesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(5):
		var y:= -.39+ring*.166
		var w:= .67-ring*.11
		for i in range(9):
			var a:=i*TAU/9.0+ring*.59
			var b:float=a+TAU/9.0
			var r:=Vector3(cos(a)*w,y+.058,sin(a)*w)
			var q:=Vector3(cos(b)*w,y+.058,sin(b)*w)
			var mid:=Vector3(cos((a+b)*.5)*w*1.22,y-.04,sin((a+b)*.5)*w*1.22)
			for p: Vector3 in [Vector3(.07*ring,y+.24,.016*ring),r,mid,Vector3(.07*ring,y+.24,.016*ring),mid,q]:
				s.add_vertex(p)
	s.generate_normals()
	return s.commit()
