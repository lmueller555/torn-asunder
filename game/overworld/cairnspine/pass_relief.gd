extends Node3D
## Provisional Cairnspine regional relief. Landscape only: no scene registration,
## faction permissions, placeholder deployments or narrative dressing.
const GROUND := preload("res://game/overworld/cairnspine/pass_ground.gdshader")
const ASSEMBLY := Vector2(-138, 1)
const STAGING := Vector2(-113, 11)
const FORECOURT := Vector2(111, -15)
const VAULT := Vector2(157, -16)
const TERRACE_ENTRY := Vector2(119, 42)
const TERRACE := Vector2(131, 55)
const SHELF := [ASSEMBLY, STAGING, Vector2(-93,-20), Vector2(-78,-20), Vector2(-14,-20),
	Vector2(19,-20), Vector2(85,-19), FORECOURT, VAULT]
const SIDE := [STAGING, Vector2(-91,29), Vector2(-69,54), Vector2(-66,68),
	Vector2(-58,71), Vector2(16,70), Vector2(69,69), Vector2(72,56),
	Vector2(71,31), Vector2(94,20), FORECOURT]
const WITNESS := [Vector2(94,20), Vector2(115,24), TERRACE_ENTRY, TERRACE]
const VALLEY_ENTRY := [Vector2(-243,-24), Vector2(-198,-24), Vector2(-169,-10), ASSEMBLY, STAGING]
const LO := Vector2(-310, -244)
const HI := Vector2(302, 260)
const STEPS := Vector2i(238, 196)

var _rough := FastNoiseLite.new()
var _vegetation := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _travel: Dictionary
var _stone: StandardMaterial3D
var _laid: StandardMaterial3D
var _dark: StandardMaterial3D
var _paved: StandardMaterial3D
var _tree_material: StandardMaterial3D

func _ready() -> void:
	_rough.seed = 1529
	_rough.frequency = .038
	_rough.fractal_octaves = 4
	_vegetation.seed = 522
	_vegetation.frequency = .026
	_rng.seed = 5522824
	_travel = {"Shelf": _spline(SHELF), "SideBench": _spline(SIDE),
		"WitnessSpur": _spline(WITNESS), "ValleyApproach": _spline(VALLEY_ENTRY)}
	_draw_terrain()
	_draw_distant_relief()
	_anchors()
	_stone = _mat(Color("#797964"))
	_laid = _mat(Color("#8d8c76"))
	_dark = _mat(Color("#444846"))
	_paved = _mat(Color("#6c6454"))
	_tree_material = _mat(Color.WHITE)
	_tree_material.vertex_color_use_as_albedo = true
	_scatter_woods()
	_scatter_talus()
	_assembly()
	_forecourt()
	_witness_wall()

static func _hill(p: Vector2, center: Vector2, radius: Vector2, elevation: float) -> float:
	var off := (p - center) / radius
	return exp(-off.length_squared() * 2.5) * elevation

func _route_height(p: Vector2, path: Array, heights: Array, limit: float) -> Vector2:
	var nearest := Vector2(10000, 0)
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var v := b - a
		var t := clampf((p-a).dot(v) / v.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + t*v)
		if d < nearest.x and d < limit:
			nearest = Vector2(d, lerpf(heights[i], heights[i+1], t))
	return nearest

func ground(p: Vector2) -> float:
	var n := _rough.get_noise_2dv(p)
	var broad := _vegetation.get_noise_2dv(p)
	var h := -1.0 + broad * 5.0 + n * 2.7
	h += _hill(p, Vector2(112, -123), Vector2(161, 114), 97)
	h += _hill(p, Vector2(-11, -153), Vector2(135, 89), 81)
	h += _hill(p, Vector2(155, -37), Vector2(92, 119), 66)
	h += _hill(p, Vector2(217, 73), Vector2(102, 84), 69)
	h += _hill(p, Vector2(-205, -160), Vector2(130, 125), 88)
	h += _hill(p, Vector2(-207, 135), Vector2(126, 112), 54)
	h += _hill(p, Vector2(8, 171), Vector2(147, 98), 59)
	h += _hill(p, Vector2(7, 5), Vector2(89, 47), 29)
	# Glacial shoulders and cut strata are tied to relief, not scattered cubes.
	h += clampf(h * .14, 1.0, 9.0) * maxf(-.41, n)
	var s := _route_height(p, SHELF, [0, 0, 1, 2, 13.8, 14.1, 14.0, 14.1, 14.1], 37.0)
	var b := _route_height(p, SIDE, [0, 0, 0.5, 1.3, 2, 8.1, 9.2, 10, 13, 14.1, 14.1], 30.0)
	var t := _route_height(p, WITNESS, [14.1, 14.1, 14.1, 14.1], 27.0)
	var v := _route_height(p, VALLEY_ENTRY, [.3, .3, .2, 0, 0], 25.0)
	h = lerpf(h, s.y + n * .26, 1.0-smoothstep(4.2, 24.2, s.x))
	h = lerpf(h, b.y + n * .21, 1.0-smoothstep(6.2, 22.0, b.x))
	h = lerpf(h, t.y + n * .21, 1.0-smoothstep(7.3, 19.3, t.x))
	h = lerpf(h, v.y + n * .21, 1.0-smoothstep(6.0, 22.0, v.x))
	h = _pad(h, p, ASSEMBLY, Vector2(19, 14), .045, .48)
	h = _pad(h, p, FORECOURT, Vector2(21, 13), 14.12, .61)
	h = _pad(h, p, TERRACE, Vector2(15, 11), 14.12, .57)
	h = _pad(h, p, VAULT, Vector2(15, 11), 14.12, .56)
	return h

func _pad(h: float, p: Vector2, center: Vector2, rad: Vector2, y: float, shoulder: float) -> float:
	return lerpf(h, y, 1-smoothstep(1.0, 1.0 + shoulder, ((p-center)/rad).length()))

func at(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, ground(p) + lift, p.y)

func _paint_track(p: Vector2) -> float:
	if p.x < -251 or p.x > 163 or p.y < -29 or p.y > 78:
		return 0.0
	var alpha := 0.0
	for key: String in _travel.keys():
		var samples: PackedVector2Array = _travel[key]
		var dist := INF
		for i in range(0, samples.size() - 1, 2):
			var b := mini(i + 2, samples.size() - 1)
			var closest := Geometry2D.get_closest_point_to_segment(p, samples[i], samples[b])
			dist = minf(dist, p.distance_to(closest))
		var half := 2.15 if key == "Shelf" else 3.0
		alpha = maxf(alpha, 1.0 - smoothstep(half - 1.0, half + 1.9, dist))
	return alpha

func _draw_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(STEPS.y+1):
		for col in range(STEPS.x+1):
			var p := LO + (HI - LO) * Vector2(float(col)/STEPS.x, float(row)/STEPS.y)
			var h := ground(p)
			var dx := ground(p + Vector2(1,0))-ground(p-Vector2(1,0))
			var dz := ground(p + Vector2(0,1))-ground(p-Vector2(0,1))
			st.set_normal(Vector3(-dx, 2.0, -dz).normalized())
			st.set_color(Color(_paint_track(p), 0, 0, 1))
			st.add_vertex(Vector3(p.x,h,p.y))
	for row in range(STEPS.y):
		for col in range(STEPS.x):
			var a := row * (STEPS.x + 1) + col
			var b := a + STEPS.x + 1
			for ix in [a, a+1, b, a+1, b+1, b]:
				st.add_index(ix)
	var field := MeshInstance3D.new()
	field.name = "SurveyRelief"
	field.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	field.material_override = mat
	add_child(field)

static func _spline(controls: Array) -> PackedVector2Array:
	var curve := Curve2D.new()
	curve.bake_interval = 1.5
	for i in controls.size():
		var first: Vector2 = controls[i - 1] if i else controls[i]
		var last: Vector2 = controls[i + 1] if i + 1 < controls.size() else controls[i]
		var arm := (last - first) * .13
		curve.add_point(controls[i], -arm, arm)
	return curve.get_baked_points()

func _draw_distant_relief() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const DIM := Vector2i(166, 98)
	for j in range(DIM.y + 1):
		for i in range(DIM.x + 1):
			var p := Vector2(-1480 + 3180.0 * i / DIM.x, -1540 + 2180.0 * j / DIM.y)
			var n := _vegetation.get_noise_2dv(p * .34)
			var ridge := _hill(p, Vector2(-475,-492), Vector2(375,160), 112)
			ridge += _hill(p, Vector2(44,-533), Vector2(359,234), 125)
			ridge += _hill(p, Vector2(424,-551), Vector2(342,209), 145)
			ridge += _hill(p, Vector2(713,-578), Vector2(396,237), 135)
			ridge += _hill(p, Vector2(-219,-735), Vector2(323,180), 174)
			ridge += _hill(p, Vector2(442,-778), Vector2(476,207), 209)
			ridge += _hill(p, Vector2(725,-182), Vector2(390,363), 135)
			ridge += _hill(p, Vector2(885,130), Vector2(391,326), 122)
			ridge += _hill(p, Vector2(1195,282), Vector2(435,340), 179)
			var ridge_edges := maxf(smoothstep(249.0, 385.0, absf(p.x)), smoothstep(200.0, 323.0, absf(p.y)))
			var y := (ridge + n*(10 + ridge*.20)) * ridge_edges - 6.2
			st.set_color(Color(0,0,0,1))
			st.add_vertex(Vector3(p.x, y, p.y))
	for j in range(DIM.y):
		for i in range(DIM.x):
			var a := j * (DIM.x + 1) + i
			var b := a + DIM.x + 1
			for ix in [a,a+1,b,a+1,b+1,b]:
				st.add_index(ix)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "FarCairnspine"
	node.mesh = st.commit()
	var mat := _mat(Color("#374952"))
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _anchors() -> void:
	var anchors := Node3D.new()
	anchors.name = "SurveyAnchors"
	add_child(anchors)
	for item in [["ValleyApproach",VALLEY_ENTRY[0]],["Assembly",ASSEMBLY],
		["SafeStaging",STAGING],["ShelfFoot",SHELF[3]],["SideBlindBend",SIDE[6]],
		["Forecourt",FORECOURT],["WitnessTerraceEntry",TERRACE_ENTRY],["WitnessTerrace",TERRACE],["VaultExterior",VAULT]]:
		var pin := Marker3D.new()
		pin.name = item[0]
		pin.position = at(item[1])
		anchors.add_child(pin)

func sampled_route(key: String) -> PackedVector3Array:
	var way := PackedVector3Array()
	for p: Vector2 in _travel.get(key, PackedVector2Array()):
		way.append(at(p))
	return way

func _mat(albedo: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = .94
	return m

func _clear_of_road(p: Vector2, clearance: float) -> bool:
	for samples: PackedVector2Array in _travel.values():
		for index in range(0, samples.size(), 4):
			if p.distance_squared_to(samples[index]) < clearance * clearance:
				return false
	return ((p - ASSEMBLY).length() > 25 and (p - FORECOURT).length() > 27
		and (p - VAULT).length() > 21 and (p-TERRACE).length() > 21)

func _scatter_woods() -> void:
	var tall: Array[Transform3D] = []
	var wide: Array[Transform3D] = []
	for iz in range(83):
		for ix in range(95):
			var p := LO + Vector2(18+ix*6.08, 12+iz*5.98) + Vector2(_rng.randf_range(-3.2, 3.2), _rng.randf_range(-3.2, 3.2))
			var h := ground(p)
			var pitch := absf(h-ground(p+Vector2(2,1)))
			var belt := _vegetation.get_noise_2dv(p*.73)
			if h > 79 or pitch > 2.0 or belt < -.01 or not _clear_of_road(p, 6.7):
				continue
			if _rng.randf() > smoothstep(-.01,.33,belt) * .93:
				continue
			var size_ := _rng.randf_range(.62,1.43)
			var b := Basis.from_euler(Vector3(_rng.randf_range(-.14,.14),_rng.randf()*TAU,_rng.randf_range(-.09,.09)))
			var shape := Transform3D(b.scaled(Vector3(size_,size_*_rng.randf_range(.98,1.17),size_)), at(p, -.24))
			if _rng.randf() < .39:
				wide.append(shape)
			else:
				tall.append(shape)
	_batch("ClosedPineCrowns", _pine(1.0, 1.0, .31), _tree_material, tall)
	_batch("OpenSpurCrowns", _pine(.83, 1.24, 1.88), _tree_material, wide)

func _pine(height: float, width: float, seed_: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_crown(st, 0, 8.85*height, .215, .045, 7, Color("#464736"), 0.0, .06, 0.0)
	for i in range(6):
		var foot := (1.1 + i * 1.08) * height
		var top := foot + (3.14 - i * .17) * height
		var r := (2.29 - i * .30) * width
		var c := Color("#18332a").lerp(Color("#44533b"), i*.157)
		_crown(st, foot, top, r, .07, 11, c, i*.63+seed_, .54*height, .18+seed_*.08)
	st.generate_normals()
	return st.commit()

func _crown(st: SurfaceTool, low: float, top: float, wide: float, narrow: float, faces: int,
		c: Color, tilt: float, jitter: float, reach: float) -> void:
	for i in faces:
		var a := TAU*float(i)/faces+tilt
		var b := TAU*float(i+1)/faces+tilt
		var r := wide * (1.0 + .23*sin(a*3.+tilt+.7)+.11*cos(a*5.-tilt))
		var rr := wide * (1.0 + .23*sin(b*3.+tilt+.7)+.11*cos(b*5.-tilt))
		var p := Vector3(r*cos(a),low+jitter*sin(i*2.3+tilt),r*sin(a))
		var q := Vector3(rr*cos(b),low+jitter*sin((i+1)*2.3+tilt),rr*sin(b))
		var u := Vector3(narrow*cos(a)+reach*sin(tilt),top,narrow*sin(a)+reach*cos(tilt))
		var v := Vector3(narrow*cos(b)+reach*sin(tilt),top,narrow*sin(b)+reach*cos(tilt))
		var mid := (p+q+u+v)*.25 + Vector3(cos((a+b)*.5),0,sin((a+b)*.5))*wide*.08
		st.set_color(c.lightened(.14*(.5+.5*sin(i*1.33+tilt))).srgb_to_linear())
		for vert in [p,mid,q,q,mid,v,v,mid,u,u,mid,p]:
			st.add_vertex(vert)

func _scatter_talus() -> void:
	var rocks: Array[Transform3D] = []
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = 1.0
	mesh.height = 1.5
	for i in range(375):
		var p := Vector2(_rng.randf_range(-228,222), _rng.randf_range(-140,138))
		var h := ground(p)
		if not _clear_of_road(p, 6.4) or (h < 17 and _rough.get_noise_2dv(p) < .32):
			continue
		var s := _rng.randf_range(.35,2.10)
		rocks.append(Transform3D(Basis.from_euler(Vector3(_rng.randf(),_rng.randf()*TAU,0)).scaled(Vector3(s*1.44,s*.66,s)), at(p,-.06)))
	_batch("BeddedTalus", mesh, _dark, rocks)

func _batch(name_: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = multi
	node.material_override = material
	add_child(node)

func _block(parent: Node3D, p: Vector3, dims: Vector3, m: Material, spin := 0.0) -> void:
	var shape := BoxMesh.new()
	shape.size = dims
	var stone := MeshInstance3D.new()
	stone.mesh = shape
	stone.material_override = m
	stone.position = p
	stone.rotation.y = spin
	parent.add_child(stone)

func _assembly() -> void:
	var root := Node3D.new()
	root.name = "OpenAssemblyCourt"
	add_child(root)
	# Open, low wide footprint: only permanent civic masonry, no hearing props.
	for i in range(27):
		var theta := deg_to_rad(28 + i*11.8)
		var p := ASSEMBLY + Vector2(cos(theta)*13.5,sin(theta)*9.1)
		var m := _laid if i % 6 == 0 else _stone
		_block(root,at(p,.47),Vector3(2.5,.82,1.72),m,theta+PI*.47)
		if i % 4 == 0:
			_block(root,at(p,.95),Vector3(1.25,.45,.80),_laid,theta)
	for i in range(39):
		var angle := float(i)*2.39996
		var radius := sqrt(float(i) / 39) * 10
		var p := ASSEMBLY + Vector2(cos(angle)*radius, sin(angle)*radius*.59)
		_block(root,at(p,.045),Vector3(1.31,.12,.94),_paved,angle)

func _forecourt() -> void:
	var root := Node3D.new()
	root.name = "ForecourtAndClosedVault"
	add_child(root)
	for i in range(15):
		for j in range(8):
			var p := Vector2(118+i*2.34,-24+j*2.03)
			_block(root, at(p,.08), Vector3(2.29,.14,1.96),_paved)
	# Plain fixed exterior silhouette, no mechanism, no new door motif or objective.
	for i in range(5):
		_block(root,at(VAULT+Vector2(2.7,-5.7),.75+i*1.17),Vector3(5.5,1.15,3.4),_stone)
		_block(root,at(VAULT+Vector2(2.7,5.7),.75+i*1.17),Vector3(5.5,1.15,3.4),_laid)
	_block(root,at(VAULT+Vector2(2.2,0),5.93),Vector3(5.8,1.75,14.1),_stone)
	_block(root,at(VAULT+Vector2(3.02,0),2.7),Vector3(1.2,5.2,8.1),_dark)
	_block(root,at(VAULT+Vector2(4.8,0),7.1),Vector3(6.1,.62,14.5),_laid)
	for i in range(7):
		var p := VAULT+Vector2(3,-6.4+i*2.15)
		_block(root, at(p, 7.65), Vector3(4.3,.64,1.78), _stone)

func _witness_wall() -> void:
	var root := Node3D.new()
	root.name = "WitnessTerraceFoot"
	add_child(root)
	for i in range(19):
		var theta := deg_to_rad(172-i*10.4)
		var p := TERRACE + Vector2(13.1*cos(theta), 9.0*sin(theta))
		_block(root, at(p,.55), Vector3(2.43, .91, 1.48), _stone, theta+PI*.50)
		if i % 3 == 0:
			_block(root, at(p,1.14), Vector3(1.35,.45,1.15), _laid, theta)
