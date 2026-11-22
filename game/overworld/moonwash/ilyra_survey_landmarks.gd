extends RefCounted
## Original regional landmarks for the Year Three Survey coast. The terrain and
## battle-briefing pin remain authoritative. No fire, actors, signal or progress.
const Route := preload("res://game/overworld/moonwash/ilyra_survey_route.gd")
const ShaderDef := preload("res://game/overworld/moonwash/ilyra_survey_material.gdshader")
const Tread := preload("res://game/overworld/moonwash/ilyra_survey_tread.gdshader")
const ANCHORS := {
	&"stone": Route.WEST_KNOLL,
	&"strand": Route.BEACH_SHELF,
	&"headland": Route.EAST_RELAY_RISE,
}
const PALETTE := {
	&"plank": [Color("#8a6445"),0], &"edge": [Color("#ad9063"),0],
	&"limestone": [Color("#a39779"),1], &"split": [Color("#69665b"),1],
	&"bronze": [Color("#56756f"),2], &"reed": [Color("#978d48"),3],
	&"drygrass": [Color("#c4ac64"),3], &"tread": [Color("#9e8b5e"),4],
}
var _anchor := Vector3.ZERO
var _probe: Callable
var _surfaces: Dictionary = {}
var _tread_uv: Dictionary = {}
var _solid_bounds := AABB()
var _support := PackedVector3Array()
var _insets := PackedFloat32Array()
var _invalid := false


func build(kind: StringName, ground_at: Callable, regional: bool) -> MeshInstance3D:
	_anchor = ANCHORS.get(kind, Vector3.INF)
	_probe = ground_at
	match kind:
		&"stone": _ancestral_bank(regional)
		&"strand": _strand(regional)
		&"headland": _headland(regional)
		_: return null
	if _invalid:
		return null
	var mesh := ArrayMesh.new()
	for stock: StringName in _surfaces:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in _surfaces[stock]:
			if stock == &"tread":
				surface.set_uv(_tread_uv[vertex])
			surface.add_vertex(vertex)
		surface.generate_normals()
		var material := ShaderMaterial.new()
		material.shader = Tread if stock == &"tread" else ShaderDef
		material.resource_name = "Survey Shore " + stock
		material.set_shader_parameter(&"tint", PALETTE[stock][0])
		if stock != &"tread":
			material.set_shader_parameter(&"stock", PALETTE[stock][1])
			material.set_shader_parameter(&"regional", regional)
		surface.set_material(material)
		surface.commit(mesh)
	var art := MeshInstance3D.new()
	art.name = StringName("Survey%s%s" % [str(kind).capitalize(), "Regional" if regional else "Near"])
	art.mesh = mesh
	art.position = _anchor
	art.set_meta(&"survey_support", _support)
	art.set_meta(&"survey_solid_bounds", _solid_bounds)
	art.set_meta(&"survey_insets", _insets)
	return art


func _ancestral_bank(regional: bool) -> void:
	var main := _foot(Vector2.ZERO,.35)
	# Stepped strata, broken shoulder, two tiny old chisel grooves. Not an
	# objective token or illuminated marker.
	_rock(main,Vector3(4.8,1.40,3.4),.29,&"split",8)
	_rock(main+Vector3(-.34,.73,.27),Vector3(3.0,3.73,1.46),.16,&"limestone",7)
	_rock(main+Vector3(.92,.29,.32),Vector3(1.8,1.4,1.1),.45,&"split",6)
	for i in range(3):
		var point := Vector2(-3.0+i*2.7,1.8+sin(i*1.4)*.9)
		_rock(_foot(point,.14),Vector3(1.8,.58,1.25),i*.43,&"limestone",6)
	if regional:
		return
	for j in range(4):
		var a := main + Vector3(-.8 + j*.40,1.92 + j*.12,1.00)
		_beam(a,a+Vector3(.41,.69,-.18),.040,&"split")
	for i in range(5):
		_tuft(Vector2(-3.9 + i*2.0,-1.8 + cos(i)*.68),i,.89,false)


func _strand(regional: bool) -> void:
	# The fishing platform stays in the real dry cove. Every piling has its
	# own ground, but the working deck stays level. No skiff is under way.
	var points := [Vector2(-4.5,-2.15),Vector2(-4.5,2.15),Vector2(4.45,-2.15),Vector2(4.45,2.15)]
	var legs := PackedVector3Array()
	var top := -INF
	for xz: Vector2 in points:
		var base := _foot(xz,.17)
		legs.append(base)
		top = maxf(top,base.y)
	top += .80
	for leg in legs:
		_beam(leg,Vector3(leg.x,top+.40,leg.z),.28,&"plank")
		_box(Vector3(leg.x,top+.34,leg.z),Vector3(.41,.09,.41),.12,&"edge")
	for edge: float in [-1.66,1.66]:
		_beam(Vector3(-4.9,top-.19,edge),Vector3(4.93,top-.19,edge),.29,&"plank")
	if regional:
		_box(Vector3(0,top,0),Vector3(10.1,.25,4.42),.0,&"edge")
	else:
		for i in range(23):
			var x := (i - 11) * .437
			_box(Vector3(x,top + sin(i*2.0)*.024,0),Vector3(.411,.20,4.44+sin(i*1.47)*.13),.0,&"edge" if i % 4 else &"plank")
			if i % 3 == 0:
				for side: float in [-1.48,1.48]:
					_box(Vector3(x,top+.103,side),Vector3(.072,.018,.072),.0,&"bronze")
	# Low, wide empty frame and stays. Unlike the pointed stone high relay it
	# reads as fishing/landing gear from the water, and nothing is lit or raised.
	var left := _foot(Vector2(-1.95,-2.28),.18)
	var right := _foot(Vector2(2.08,-2.26),.18)
	var high := top + 4.32
	var la := Vector3(left.x,high,left.z)
	var ra := Vector3(right.x,high-.20,right.z)
	_beam(left,la,.35,&"plank")
	_beam(right,ra,.35,&"plank")
	_beam(la+Vector3(-.31,0,.10),ra+Vector3(.30,0,-.08),.31,&"edge")
	_beam(la-Vector3.UP*1.22,la+Vector3(1.18,-.03,.04),.22,&"plank")
	_beam(ra-Vector3.UP*1.13,ra+Vector3(-1.12,0,-.06),.22,&"plank")
	var step_foot := _foot(Vector2(-6.4,0),.045)
	for i in range(3 if regional else 7):
		var count := 3 if regional else 7
		var t := float(i) / (count-1)
		var length := 3.48 - t*.30
		var x := lerpf(-6.35,-4.95,t)
		var ramp_y := lerpf(step_foot.y+.10,top+.07,t)
		_box(Vector3(x,ramp_y,0),Vector3(.39 if regional else .214,.19,length),.0,&"edge")
	for stock in range(3 if regional else 5):
		var x := 2.46 + (stock % 2)*.91
		var z := .21+(stock / 2)*.76
		var y := top + .41 + sin(stock*1.11)*.11
		_box(Vector3(x,y,z),Vector3(.86,.61,.69),stock*.13,&"plank")
		_box(Vector3(x,y+.307,z),Vector3(.91,.085,.72),stock*.13,&"edge")
		if not regional:
			for side: float in [-.25,.25]:
				_box(Vector3(x+side,y-.045,z),Vector3(.073,.49,.70),stock*.13,&"bronze")
	var thickets := [
		Vector3(-6.2,.75,4.0), Vector3(-4.9,1.05,4.32), Vector3(-4.27,.64,5.04),
		Vector3(-5.51,.47,5.63), Vector3(1.12,.78,5.24), Vector3(3.56,1.08,4.77),
		Vector3(3.89,.72,5.38), Vector3(5.18,.64,4.93), Vector3(6.05,.49,4.49),
	]
	for i in range(thickets.size()):
		if regional and i not in [1,5,7]:
			continue
		var t: Vector3 = thickets[i]
		_tuft(Vector2(t.x,t.z),i,t.y,regional)
	for i in range(3 if regional else 7):
		var t := float(i)
		var spread := pow(t/6.0,1.32)
		_rock(_foot(Vector2(-5.5+spread*9.1,-4.57 + cos(t*2.1)*.90),.26),
			Vector3(1.76+sin(t)*.43,.54+absf(sin(t))*.52,1.18),.36+t*.41,&"limestone",6)
	_strand_tread()


func _strand_tread() -> void:
	# Fade the thin, non-colliding sand apron back into the existing
	# approach. The sampled grid drapes the native slope rather than flattening it.
	var grid: Array[PackedVector3Array] = []
	for idx in range(15):
		var t := float(idx)/14.0
		var center := Vector2(lerpf(-15.8,6.14,t),lerpf(-19.2,1.0,t) + sin(t*PI)*3.6)
		var width := lerpf(.9,4.7,smoothstep(.0,.61,t)) * (1.0 - smoothstep(.82,1.1,t))
		var row := PackedVector3Array()
		for col in range(7):
			var w := float(col-3)/3.0
			var lateral := width*w
			var xy := center + Vector2(-.22,.975)*lateral
			xy.x += sin(idx*2.23+col*.97)*.34
			xy.y += cos(idx*1.7+col*2.2)*.45
			var vertex := _foot(xy,-.052)
			_tread_uv[vertex] = Vector2(t, w)
			row.append(vertex)
		grid.append(row)
	for i in range(grid.size()-1):
		for j in range(6):
			_quad(grid[i][j],grid[i+1][j],grid[i+1][j+1],grid[i][j+1],&"tread")


func _headland(regional: bool) -> void:
	# Narrow tapered limestone relay, open metal crown and dry stone windbreak
	# rather than another beach rack. All quiet; no lit beacon or progress art.
	var center := _foot(Vector2.ZERO,.22)
	_rock(center,Vector3(5.2,1.41,4.9),.21,&"split",8)
	_rock(center+Vector3(0,.57,0),Vector3(4.2,1.57,3.83),.18,&"limestone",8)
	var stem := center + Vector3.UP*1.89
	_rock(stem,Vector3(2.05,3.41,1.86),.17,&"limestone",7)
	_rock(stem+Vector3.UP*2.78,Vector3(2.50,.81,2.31),.09,&"split",8)
	var crown := stem + Vector3.UP*3.45
	_rock(crown,Vector3(2.02,.84,1.83),.10,&"bronze",8)
	for i in range(4 if regional else 8):
		var count := 4 if regional else 8
		var angle := TAU * float(i)/count+.11
		var dir := Vector3(cos(angle),0,sin(angle))
		var edge := Vector3(cos(angle+TAU/count),0,sin(angle+TAU/count))
		var from := crown + dir*.87 + Vector3.UP*.37
		var tip := crown + dir*1.04 + Vector3.UP*1.52
		_beam(from,tip,.18,&"bronze")
		_beam(tip,crown+edge*1.04+Vector3.UP*1.52,.132,&"bronze")
		if not regional:
			_beam(from,tip+edge*.38,.078,&"bronze")
	var windbreak_count := 8 if regional else 13
	for i in range(windbreak_count):
		var a := deg_to_rad(196.0 + 168.0 * float(i)/(windbreak_count-1))
		var end_falloff := sin(PI*float(i)/(windbreak_count-1))
		var imbalance := sin(float(i)*2.25)*.59
		var place := Vector2(cos(a),sin(a))*Vector2(7.35+imbalance,5.25+imbalance)
		place.x -= (1.0-end_falloff)*.42
		var base := _foot(place,.35+(1.0-end_falloff)*.23)
		var size := (TAU*6.4/20.0) * (1.41 if regional else 1.0) * (.88 + end_falloff*.18)
		var lift := .54 + end_falloff*.42 + imbalance*.28
		_rock(base,Vector3(size,lift,1.23+imbalance*.3),-a+1.5+imbalance*.6,&"split",6)
		_rock(base+Vector3.UP*(lift*.61),Vector3(size*.91,.37+end_falloff*.32,1.18),-a+1.59-imbalance*.3,&"limestone",6)
		if i % 3 != 1 and end_falloff > .48:
			_rock(base+Vector3.UP*(lift*.98),Vector3(size*.80,.39,.98),-a+1.39,&"limestone",6)
	var prep := _foot(Vector2(-4.2,1.85),.10)
	_rock(prep,Vector3(2.63,.94,1.61),.29,&"split",7)
	_box(prep+Vector3.UP*.67,Vector3(2.26,.23,1.27),.29,&"edge")
	if not regional:
		for i in range(6):
			_tuft(Vector2(-5.4+i*2.07,3.94+cos(i*1.6)*.55),i,.61,false)


func _foot(local: Vector2, inset: float) -> Vector3:
	var hit: Variant = _probe.call(Vector2(_anchor.x,_anchor.z)+local)
	if hit is not Vector3 or not hit.is_finite():
		_invalid = true
		return Vector3(local.x,0,local.y)
	var foot: Vector3 = hit - _anchor - Vector3.UP*inset
	_support.append(foot)
	_insets.append(inset)
	return foot


func _tuft(at: Vector2, seed: int, scale: float, regional: bool) -> void:
	var footing := _foot(at,.08)
	for leaf in range(6 if regional else 13):
		var a := float(seed*7+leaf)*2.39996
		var dir := Vector3(cos(a),0,sin(a))
		var p := footing+dir*(.20+absf(cos(a))*.38)*scale
		var side := Vector3(-dir.z,0,dir.x)
		var height:= (.71+absf(sin(a*2.1))*.94)*scale
		var lean := Vector3(.32,0,.18 + sin(seed*4.0)*.19)*height
		var elbow := p+Vector3.UP*height*.53+dir*height*.13+lean*.29
		var tip := p+Vector3.UP*height+dir*height*.37+lean
		var width := (.068+.051*cos(a))*scale
		var stock := &"drygrass" if leaf % 3 == 0 else &"reed"
		_quad(p-side*width,p+side*width,elbow+side*width*.67,elbow-side*width*.67,stock)
		_tri(elbow-side*width*.67,elbow+side*width*.67,tip,stock)


func _rock(at: Vector3, size: Vector3, spin: float, stock: StringName, sides: int) -> void:
	var base := PackedVector3Array()
	var edge := PackedVector3Array()
	var top := PackedVector3Array()
	for i in range(sides):
		var a := float(i)*TAU/sides
		var stride := .91 + sin(i*2.17+spin)*.15
		var p := Vector3(cos(a)*size.x*.54,0,sin(a)*size.z*.54).rotated(Vector3.UP,spin)*stride
		base.append(at+p*.87 - Vector3.UP*.13)
		edge.append(at+p+Vector3.UP*size.y*(.23+sin(i*1.57+spin)*.05))
		top.append(at+p*(.71+cos(i*1.26)*.08)+Vector3.UP*size.y*(.85+cos(i*2.14)*.13))
	for i in range(sides):
		var next := (i+1)%sides
		_quad(base[i],base[next],edge[next],edge[i],stock)
		_quad(edge[i],edge[next],top[next],top[i],stock)
		_tri(top[i],top[next],at+Vector3.UP*size.y*.93,stock)


func _box(at: Vector3, size: Vector3, yaw: float, stock: StringName) -> void:
	var corners := PackedVector3Array()
	for i in range(8):
		var band := Vector3(0.5 if (i&1) else -0.5,0.5 if (i&2) else -0.5,0.5 if (i&4) else -0.5) * size
		corners.append(at+band.rotated(Vector3.UP,yaw))
	_box_faces(corners,stock)


func _beam(a: Vector3, b: Vector3, width: float, stock: StringName) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.RIGHT if absf(axis.y)>.94 else Vector3.UP).normalized() * width*.5
	var rise := side.cross(axis).normalized()*width*.46
	var corners := PackedVector3Array()
	for i in range(8):
		corners.append((b if (i&4) else a) + side*(1.0 if (i&1) else -1.0) + rise*(1.0 if (i&2) else -1.0))
	_box_faces(corners,stock)


func _box_faces(p: PackedVector3Array, stock: StringName) -> void:
	for face in [[0,1,3,2],[4,6,7,5],[0,2,6,4],[1,5,7,3],[0,4,5,1],[2,3,7,6]]:
		_quad(p[face[0]],p[face[1]],p[face[2]],p[face[3]],stock)


func _tri(a: Vector3,b: Vector3,c: Vector3,stock: StringName) -> void:
	if stock != &"tread":
		for p: Vector3 in [a,b,c]:
			_solid_bounds = _solid_bounds.expand(p)
	if not _surfaces.has(stock):
		_surfaces[stock] = []
	_surfaces[stock].append_array([a,b,c])


func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,stock: StringName) -> void:
	_tri(a,b,c,stock)
	_tri(a,c,d,stock)
