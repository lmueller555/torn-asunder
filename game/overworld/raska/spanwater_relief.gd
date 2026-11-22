extends Node3D
## Off-title cartography study; this does not implement flood, chapter, or movement rules.
const SHADING := preload("res://game/overworld/raska/spanwater_surface.gdshader")
const WEATHER := preload("res://game/overworld/raska/lock_weathering.gdshader")
const NORTH := [Vector2(-216,-49), Vector2(-154,-43),Vector2(-108,-42), Vector2(-67,-38),
	Vector2(-38,-29),Vector2(23,-43),Vector2(83,-44),Vector2(151,-48),Vector2(221,-49)]
const SOUTH := [Vector2(-45,102),Vector2(21,85),Vector2(62,74),Vector2(92,65),
	Vector2(114,56),Vector2(115,37),Vector2(114,20)]
const FEEDER := [Vector2(-119,-40),Vector2(-88,-83),Vector2(25,-90),Vector2(137,-86)]
const SEA := Vector2(-14,57)
const WHEEL := Vector2(-38,-28)
const LANDING := Vector2(114,15.5)
const FORD := Vector2(55,0)
const BOAT := [Vector2(-5,0),Vector2(58,1),Vector2(92,1),Vector2(114,10),Vector2(167,3),Vector2(226,0)]
const NORTHERN_EXIT := Vector2(151,-48)

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _layers: Dictionary = {}
var _craft_lock := false

func _ready() -> void:
	_noise.seed = 132955
	_noise.frequency = .036
	_rng.seed = 40452
	_layers = {"Masonry": [], "Caps": [], "Piers": [], "Timber": [], "Metal": [], "StoneDebris": [],
		"LockStone": [], "LockCap": [], "LockCore": [], "WornPath": []}
	_land()
	_backdrop()
	_river()
	_anchors()
	_masonry()
	_polish()
	_scrub()
	_reeds()

func _distance(p: Vector2, route: Array) -> float:
	var d := INF
	for i in range(route.size()-1):
		d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1])))
	return d

func center(x: float) -> float:
	return 8.0*sin(x*.012) + 4.2*sin(x*.034) + 2.3*cos(x*.019)

func width_(x: float) -> float:
	return 21.0 + 4.5*sin(x*.021+1.1) + 3.0*cos(x*.032)

func _branch(p: Vector2) -> float:
	return _distance(p, [Vector2(-49,14),Vector2(-36,38),Vector2(-14,57),Vector2(4,103),Vector2(18,220)])

func ground(p: Vector2) -> float:
	var fringe := absf(p.y-center(p.x))/width_(p.x)
	var bank := smoothstep(.85,1.64,fringe)
	var hills := (1-exp(-pow(maxf(absf(p.y)-55.0,0)*.010,2))) * (2.5 + 29.0 * pow(.5 + .5*sin(p.x*.020 + p.y*.013),2))
	var y := lerpf(-1.0,5.25,bank) + bank * (hills + 2.0*_noise.get_noise_2dv(p))
	var hill_scale := smoothstep(80.0,163.0,absf(p.y))
	y += hill_scale * (_hill(p,Vector2(-104,-177),Vector2(149,77),34)
		+ _hill(p,Vector2(148,-156),Vector2(95,71),22)
		+ _hill(p,Vector2(235,218),Vector2(151,115),36))
	var trench := 1-smoothstep(5.0,19.0,_branch(p))
	y = lerpf(y,-.79,trench)
	var feeder := 1-smoothstep(2.6,5.5,_distance(p,FEEDER))
	y = lerpf(y, minf(y,2.04),feeder*.78)
	y = lerpf(y,5.23,(1.0-smoothstep(5.5,14.0,_distance(p,NORTH))))
	y = lerpf(y,lerpf(1.05,5.20,smoothstep(19,48,p.y)),
		1.0-smoothstep(3.7,11.0,_distance(p,SOUTH)))
	return y

func at(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x,ground(p)+lift,p.y)

func _route_mask(p: Vector2) -> float:
	return maxf(1-smoothstep(3.2,7.8,_distance(p,NORTH)),
		1-smoothstep(2.7,6.1,_distance(p,SOUTH)))

static func _hill(p: Vector2, c: Vector2, rad: Vector2, h: float) -> float:
	return h*exp(-((p-c)/rad).length_squared()*2.3)

func _backdrop() -> void:
	var node := MeshInstance3D.new()
	node.name = "WeatheredHorizon"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := Vector2i(151,103)
	for j in range(N.y+1):
		for i in range(N.x+1):
			var p := Vector2(-1580.0+3160.0*i/N.x,-1260.0+2520.0*j/N.y)
			var edge := smoothstep(205.,453.,maxf(absf(p.y),absf(p.x*.85)))
			var y := _hill(p,Vector2(28,570),Vector2(291,239),134.) + _hill(p,Vector2(-669,415),Vector2(390,166),112.)
			y += _hill(p,Vector2(-415,-655),Vector2(510,189),122.)
			y += _hill(p,Vector2(423, -695),Vector2(436,251),153.)
			y += _hill(p,Vector2(777, 456),Vector2(312,177),115.)
			y += _hill(p,Vector2(1014,-176),Vector2(254,381),143.)
			y += _hill(p,Vector2(-947, -214),Vector2(262,383),104.)
			y += _noise.get_noise_2dv(p*.5)*(13.+y*.36)
			st.add_vertex(Vector3(p.x,y*edge-6.5,p.y))
	for j in range(N.y):
		for i in range(N.x):
			var a := j*(N.x+1)+i
			var b := a+N.x+1
			for k in [a,a+1,b,a+1,b+1,b]:
				st.add_index(k)
	st.generate_normals()
	node.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#4a5143")
	m.roughness = .97
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _land() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := Vector2i(255,205)
	for j in range(N.y+1):
		for i in range(N.x+1):
			var px := (float(i)/N.x-.5)*2.0
			var pz := (float(j)/N.y-.5)*2.0
			var p := Vector2(px*300.0+px*pow(absf(px),8)*590.0,pz*228.0+pz*pow(absf(pz),8)*510.0)
			var dx := ground(p + Vector2(1,0))-ground(p - Vector2(1,0))
			var dz := ground(p + Vector2(0,1))-ground(p - Vector2(0,1))
			st.set_normal(Vector3(-dx,2.,-dz).normalized())
			st.set_color(Color(_route_mask(p),1.0-smoothstep(.83,1.52,absf(p.y-center(p.x))/width_(p.x)),0,1))
			st.add_vertex(at(p))
	for j in range(N.y):
		for i in range(N.x):
			var a := j*(N.x+1)+i
			var b := a+N.x+1
			for z in [a,a+1,b,a+1,b+1,b]:
				st.add_index(z)
	_surface("BankRelief",st.commit(),false)

func _river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const C := 160
	for i in range(C+1):
		var x := -860+1720.0*i/C
		for j in range(7):
			var k := (j-3.0)/3.0
			st.set_normal(Vector3.UP)
			st.set_color(Color(absf(k),0,0,1))
			st.add_vertex(Vector3(x,.42,center(x)+width_(x)*1.17*k))
	for i in range(C):
		for j in range(6):
			var a := i*7+j
			for z in [a,a+7,a+1,a+1,a+7,a+8]:
				st.add_index(z)
	_surface("RiverAppearanceOnly",st.commit(),true)

func _surface(key: String, model: Mesh, river: bool) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADING
	m.set_shader_parameter("water",river)
	var o := MeshInstance3D.new()
	o.name = key
	o.mesh = model
	o.material_override = m
	if river:
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(o)

func _anchors() -> void:
	var place := Node3D.new()
	place.name = "SurveyAnchors"
	add_child(place)
	for i in [["NorthCauseway",NORTH[2]],["SpillwayWheel",WHEEL],["HighNorthExit",NORTHERN_EXIT],
		["SouthApproach",SOUTH[4]],["LowLanding",LANDING],["LowFord",FORD],
		["ClosedSeaGate",SEA],["BoatBerth",BOAT[3]],["DownstreamBoatExit",BOAT[5]]]:
		var m := Marker3D.new()
		m.name = i[0]
		m.position = at(i[1])
		if i[0] in ["BoatBerth","DownstreamBoatExit"]:
			m.position.y = .42
		place.add_child(m)

func _timber(p: Vector2, lift: float, size_: Vector3, angle := 0.0) -> void:
	_add_box("Timber",Vector3(p.x,lift,p.y),size_,angle)

func _add_box(key: String, p: Vector3, size_: Vector3, angle := 0.0) -> void:
	if _craft_lock:
		key = {"Masonry":"LockStone", "Caps":"LockCap", "Piers":"LockCore"}.get(key,key)
	var rotation_ := Basis.from_euler(Vector3(0,angle,0)).scaled_local(size_)
	_layers[key].append(Transform3D(rotation_,p))

func _row(key: String, p: Vector2, y: float, axis: Vector2, length_: float,
		depth: float, layer: int) -> void:
	var dir := axis.normalized()
	var angle := -dir.angle()
	var steps := maxi(1,roundi(length_/2.06))
	for i in steps:
		var t := (i+.5)/steps
		var q := p + dir*((t-.5)*length_ + .13*sin(i*1.8+layer))
		_add_box(key,Vector3(q.x,y+.54,q.y),Vector3(length_/steps*.963,1.02+_rng.randf_range(-.06,.06),depth+_rng.randf_range(-.18,.15)),angle)

func _wall(p: Vector2, base: float, axis: Vector2, length_: float, depth: float, layers: int) -> void:
	for j in layers:
		_row("Masonry",p+axis.normalized()*(.15 if j%2 else -.13),base+j*.96,axis,length_,depth,j)
	_row("Caps",p,base+layers*.96,axis,length_+.6,depth+.4,layers)

func _footing(p: Vector2, axis: Vector2, length_: float, thickness: float, deck: float) -> void:
	# A continuous footing backs the individually fitted blocks and reaches native grade.
	var bottom := minf(-1.4, ground(p) - 1.1)
	var height := deck-bottom
	_add_box("Piers", Vector3(p.x, bottom+height*.5, p.y),
		Vector3(length_,height,thickness), -axis.angle())

func _apron_lock() -> void:
	_craft_lock = true
	# Apron is exposed in the center, enclosed by low retaining parapets.
	_footing(Vector2(-51,-31),Vector2.RIGHT,54,24,5.27)
	for z in [-41.8,-20.3]:
		_wall(Vector2(-51,z),-.95,Vector2.RIGHT,54,2.55,7)
	# Worn service lane and thin dressed paving on either side of it.
	_add_box("WornPath",Vector3(-51,5.37,-32.3),Vector3(53,.23,7.2))
	for band in [-37.75,-25.25,-22.6]:
		for i in range(18):
			var x := -76.0 + (i+.5)*2.87 + .23*sin(i*2.7+band)
			var w := 2.80 + .18*sin(i*3.7+band)
			_add_box("LockCap",Vector3(x,5.34,band),Vector3(w,.23,2.53),.044*sin(i*1.8))
	for x in [-74.5,-27.5]:
		_add_box("LockCap",Vector3(x,5.45,-32.3),Vector3(1.18,.2,7.25))
	for z in [-39.8,-21.6]:
		_wall(Vector2(-50,z),5.35,Vector2.RIGHT,53,1.24,1)
	# North-bank race: paired shoulders along the flow, not a full-river deck.
	# Upstream and downstream cheeks form a recessed, visibly separate sluice.
	for z in [-21.1,-7.1]:
		_footing(Vector2(-51,z),Vector2.RIGHT,39,3.3,2.6)
		_wall(Vector2(-51,z),-.9,Vector2.RIGHT,37,2.6,5)
		for x in [-67.8,-42.]:
			_footing(Vector2(x,z),Vector2.RIGHT,7.7,5.7,4.1)
			_wall(Vector2(x,z),-.7,Vector2.RIGHT,7.3,4.8,7)
			_wall(Vector2(x+.4,z),-.6,Vector2.RIGHT,5.4,3.5,9)
			_add_box("Metal",Vector3(x-.8,4.41,z + (1.74 if z < -15 else -1.74)),
				Vector3(.29,7.53,.46))
	# Dark recessed timber leaves, iron braces, stone sills. Static art only.
	for x in [-66.9,-41.2]:
		_add_box("Piers",Vector3(x,.38,-14.1),Vector3(3.25,1.24,13.7))
		for leaf in range(12):
			_add_box("Timber",Vector3(x,2.12,-19.4+leaf*.96),Vector3(.46,3.19,.91))
		for y in [1.21,3.49]:
			_add_box("Metal",Vector3(x-.31,y,-14.1),Vector3(.25,.21,11.7))
		_add_box("Timber",Vector3(x,7.23,-14.1),Vector3(.48,.61,14.4))
	# Short terrain-backed stair from the public apron to the race shoulder.
	for i in range(9):
		var h := 5.1 - i*.26
		_add_box("Piers",Vector3(-55,h*.5-1.0,-20.1+i*.55),Vector3(4.3,h+2.0,.57))
		_add_box("Caps",Vector3(-55,h,-20.1+i*.55),Vector3(4.45,.19,.59))

	_craft_lock = false

func _masonry() -> void:
	_apron_lock()
	# The old southern gate is deliberately closed, dark and noninteractive.
	for x in [-21.,-7.]:
		_wall(Vector2(x,58),0.1,Vector2.UP,10.9,3.3,7)
	_wall(SEA,6.85,Vector2.RIGHT,19.5,2.8,2)
	for i in range(11):
		_add_box("Metal",Vector3(-20.25+i*1.23,3.46,58),Vector3(1.15,6.2,.6))
	for y in [1.5,3.2,5.3]:
		_add_box("Piers",Vector3(SEA.x,y,57.6),Vector3(14.5,.35,.7))
	# Timber jetty follows the actual low south landing and separate boat berth.
	for z in [12.,15.6,21.,26.,30.]:
		for x in [110.5,117.4]:
			_timber(Vector2(x,z),.23,Vector3(.52,3.5,.63),.14)
	for i in 31:
		_timber(Vector2(114,12.0+i*.59),1.35,Vector3(8.2,.33,.55))
	for i in 15:
		var p := Vector2(114,30.0+i*1.18)
		_timber(p,1.35+i*.206,Vector3(6.6,.36,1.15))
	# Grounded masonry feeder causeway reads as an approach, ending before the apron.
	_craft_lock = true
	for x in [-130.0,-112.0]:
		_footing(Vector2(x,-43.7),Vector2.UP,9.4,5.3,4.8)
		_wall(Vector2(x,-43.7),1.15,Vector2.UP,9.4,4.8,4)
	for z in [-47.3,-40.0]:
		_footing(Vector2(-96.9,z),Vector2.RIGHT,25.4,2.4,4.88)
		_wall(Vector2(-96.9,z),2.05,Vector2.RIGHT,25.4,1.7,3)
	for i in range(18):
		var x := -129.2+i*.95
		_timber(Vector2(x,-43.7),5.31,Vector3(.89,.27,7.3))
	for i in range(18):
		var x := -111.5 + i*1.92
		var step := Vector2(x,-43.7 + smoothstep(-105,-80,x)*7.0)
		_add_box("WornPath",at(step,.06),Vector3(2.18,.28,6.55),-.18)
		for side in [-1.0,1.0]:
			if (i+int(1+side))%7 == 0:
				continue
			var edge := step + Vector2(0,3.1*side)
			_add_box("LockCap",at(edge,.115),Vector3(1.92,.36,1.06),-.18+.03*sin(i*2.4))
	_craft_lock = false
	for z in [-47.2,-40.4]:
		_timber(Vector2(-121,z),6.0,Vector3(18.1,.35,.27))
	# No duplicate wheel from the scoped battlefield receipt. A neutral stance
	# suggests the machinery site without attempting to stage Raska's prop.
	_wall(WHEEL+Vector2(0,-4),4.8,Vector2.RIGHT,8.6,5.3,2)

func _taper_cap() -> Mesh:
	# Cut copings have an overhanging shoulder, then a bevel to the weather face.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	for pair in [Vector2(-.50,.87),Vector2(-.29,1.0),Vector2(.16,.98),Vector2(.50,.77)]:
		var r: Array[Vector3] = []
		for sign_ in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
			r.append(Vector3(sign_.x*pair.y*.5,pair.x,sign_.y*pair.y*.5))
		rings.append(r)
	for j in range(3):
		for i in range(4):
			var k := (i+1)%4
			for point in [rings[j][i],rings[j+1][i],rings[j+1][k],rings[j][i],rings[j+1][k],rings[j][k]]:
				tool.add_vertex(point)
	for index in [0,2,1,0,3,2]:
		tool.add_vertex(rings[3][index])
	for index in [0,1,2,0,2,3]:
		tool.add_vertex(rings[0][index])
	tool.generate_normals()
	return tool.commit()


func _polish() -> void:
	for i in 465:
		var p := Vector2(_rng.randf_range(-237,245),_rng.randf_range(-140,145))
		if ground(p)<1.7 or _route_mask(p)>.20 or _noise.get_noise_2dv(p)<.1:
			continue
		var s := _rng.randf_range(.42,2.8)
		_add_box("StoneDebris",at(p,-.15+s*.30),Vector3(s*.81,s*.60,s*1.12),_rng.randf()*TAU)
	var cols := {"Masonry":"#676254","Caps":"#817e6f","Piers":"#565041","Timber":"#6f5239","Metal":"#514139","StoneDebris":"#7c7860",
		"LockStone":"#6a645a","LockCap":"#888074","LockCore":"#5a544b","WornPath":"#7c6950"}
	for key: String in _layers.keys():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		if key == "StoneDebris":
			var stone := SphereMesh.new()
			stone.radial_segments = 5
			stone.rings = 3
			mm.mesh = stone
		elif key == "LockCap":
			mm.mesh = _taper_cap()
		else:
			mm.mesh = BoxMesh.new()
		var items: Array = _layers[key]
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i,items[i])
			var v := .71 + .29 * pow(sin(i*2.34 + .4),2)
			mm.set_instance_color(i,Color(v,v*.98,v*.94))
		var n := MultiMeshInstance3D.new()
		n.multimesh = mm
		n.name = key
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cols[key])
		m.vertex_color_use_as_albedo = true
		m.roughness = .86
		n.material_override = m
		if key.begins_with("Lock") or key == "WornPath":
			var weather := ShaderMaterial.new()
			weather.shader = WEATHER
			weather.set_shader_parameter("base_color",Color(cols[key]))
			weather.set_shader_parameter("is_path",key == "WornPath")
			n.material_override = weather
		add_child(n)

func _scrub() -> void:
	var leaf := SphereMesh.new()
	leaf.radial_segments = 7
	leaf.rings = 4
	var twig := CylinderMesh.new()
	twig.radial_segments = 5
	twig.top_radius = .23
	twig.bottom_radius = .48
	var leaves: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var shoots: Array[Transform3D] = []
	for j in 65:
		for i in 75:
			var p := Vector2(-274 + i*7.15,-218 + j*6.70) + Vector2(_rng.randf_range(-3,3),_rng.randf_range(-3,3))
			var band := absf(p.y - center(p.x))
			var c := _noise.get_noise_2dv(p*.7)
			if ground(p)<1.15 or _route_mask(p)>.055 or _distance(p,FEEDER)<6.1 or _branch(p)<8.0:
				continue
			if band < 22 or c < .17 or _rng.randf()>.57 or p.distance_to(WHEEL)<40 or p.distance_to(SEA)<17 or p.distance_to(LANDING)<15:
				continue
			var h := _rng.randf_range(1.7,5.7)
			var y := ground(p)
			var spin := _rng.randf()*TAU
			trunks.append(Transform3D(Basis().scaled(Vector3(.35,h*.94,.34)),Vector3(p.x,y+h*.49,p.y)))
			for k in range(3):
				var ang := spin+k*2.44
				var spread := Vector2(cos(ang),sin(ang))*(.4+k*.32)*h*.29
				var shape := Basis.from_euler(Vector3(.2*sin(ang),ang,.2*cos(ang))).scaled(Vector3(h*.42,h*.41,h*.35+float(k)*.1))
				var canopy := Transform3D(shape,Vector3(p.x+spread.x,y+h*(.76+.09*k),p.y+spread.y))
				if k == 1:
					shoots.append(canopy)
				else:
					leaves.append(canopy)
	_cluster("LayeredBankCrowns",leaf,leaves,Color("#465130"))
	_cluster("DownstreamScrub",leaf,shoots,Color("#535d39"))
	_cluster("NativeBankTrunks",twig,trunks,Color("#5c5341"))

func _cluster(key: String, mesh: Mesh, shapes: Array[Transform3D], tint: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = shapes.size()
	for i in shapes.size():
		mm.set_instance_transform(i,shapes[i])
	var n := MultiMeshInstance3D.new()
	n.name = key
	n.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = .98
	n.material_override = m
	add_child(n)

func _reeds() -> void:
	var parts := SurfaceTool.new()
	parts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(5):
		var phi := i*2.4
		var off := Vector3(cos(phi),0,sin(phi))*(.1+.05*i)
		var d := Vector3(sin(phi),0,-cos(phi))
		var leaf := Vector3(cos(phi)*(.21+.04*i),.58+i*.09,sin(phi)*(.21+.04*i)) + off
		parts.set_color(Color("#7b7646").srgb_to_linear())
		for v in [off-d*.07,off+d*.07,leaf,leaf,off+d*.07,off-d*.07]:
			parts.add_vertex(v)
	parts.generate_normals()
	var marks: Array[Transform3D] = []
	for i in 275:
		var x := -215.0 + 445.0*i/274.0 + _rng.randf_range(-1.0,1.0)
		for side in [-1.0,1.0]:
			var z: float = center(x) + side * width_(x) * _rng.randf_range(.97,1.23)
			var p := Vector2(x,z)
			var y := ground(p)
			var wet_curve := .27 + .27*sin(x*.16+side*.93) + .20*cos(x*.041)
			if y < .49 or y > 2.15 or _rng.randf()>wet_curve or p.distance_to(FORD)<7 or p.distance_to(LANDING)<12 or p.distance_to(WHEEL)<18:
				continue
			for k in maxi(1,roundi(_rng.randf_range(2,8))):
				var jitter := Vector2(_rng.randf_range(-1.4,1.4),_rng.randf_range(-.82,.82))
				var pos := at(p+jitter)
				if pos.y < .40:
					continue
				var size_ := _rng.randf_range(.62,1.58)
				var b := Basis.from_euler(Vector3(0,_rng.randf()*TAU,0)).scaled(Vector3(size_,size_,size_))
				marks.append(Transform3D(b,pos))
	_cluster("PatchworkWetlandReeds",parts.commit(),marks,Color("#756b38"))
