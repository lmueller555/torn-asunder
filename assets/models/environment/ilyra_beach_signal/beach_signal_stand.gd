extends Node3D
## Fixed rendering only: the chart, ground marker and collision belong to the mission.

const WOOD := 1.0
const STONE := 2.0
const METAL := 3.0
const CORD := 4.0
const CLOTH := 5.0
const VARNISH := Color("#62452c")
const ENDGRAIN := Color("#77573a")
const ROCK := Color("#85867d")
const IRON := Color("#3e4544")
const HEMP := Color("#b09767")
const SAIL := Color("#2f5268")
const THREAD := Color("#c2ab76")
const SHADER := preload("beach_signal_stand.gdshader")
var _surface := SurfaceTool.new()


func _ready() -> void:
	add_child(_build())


func _build() -> MeshInstance3D:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two mortarless socket stones, the silver-gray top witness line, and the
	# dark timber seated through their center. Adapted to one pole footprint.
	_bevel(Vector3(0,-1.491,0),Vector3(.56,.212,.56),.042,STONE,ROCK)
	_bevel(Vector3(.006,-1.307,-.004),Vector3(.535,.179,.535),.047,STONE,ROCK.lightened(.08))
	_bevel(Vector3(-.006,-1.201,.001),Vector3(.504,.035,.49),.026,STONE,ROCK.darkened(.16))
	_bevel(Vector3(0,-.006,0),Vector3(.517,2.365,.517),.03,WOOD,VARNISH)
	_bevel(Vector3(.003,1.278,0),Vector3(.506,.327,.499),.028,WOOD,ENDGRAIN)
	_bevel(Vector3(0,1.457,0),Vector3(.544,.17,.544),.041,WOOD,ENDGRAIN)
	_bevel(Vector3(0,1.561,0),Vector3(.47,.073,.47),.032,WOOD,VARNISH)
	# Iron strap collars hide the scarf and protect the stone/wood junction.
	for band in [-1.121,.788,1.361]:
		_bevel(Vector3(0,band,0),Vector3(.55,.075,.55),.018,METAL,IRON)
		for face in [-1.0,1.0]:
			for dx in [-.145,.145]:
				_pin(Vector3(dx,band,face*.276),face)
	# Two cheeks and a cleat keep the standing and return legs of the hoist.
	_bevel(Vector3(.161,.50,-.256),Vector3(.155,.38,.05),.014,WOOD,ENDGRAIN)
	_bevel(Vector3(.176,.46,-.268),Vector3(.177,.073,.026),.013,METAL,IRON)
	_bevel(Vector3(.161,1.431,-.255),Vector3(.161,.184,.059),.014,WOOD,ENDGRAIN)
	_bevel(Vector3(.16,1.437,-.272),Vector3(.082,.071,.018),.008,METAL,IRON.lightened(.22))
	_tube([Vector3(.187,.482,-.260),Vector3(.196,.566,-.272),Vector3(.202,.948,-.274),Vector3(.207,1.416,-.272)],.012,HEMP)
	_tube([Vector3(.16,1.423,-.270),Vector3(.137,.922,-.273),Vector3(.142,.572,-.273),
		Vector3(.097,.504,-.273),Vector3(.205,.458,-.270),Vector3(.107,.429,-.268),
		Vector3(.206,.395,-.270),Vector3(.131,.304,-.266)],.010,HEMP.darkened(.17))
	# Light yard, end binding, and permanently still woven pennant. The
	# entire flying assembly stays inside the old flag box (not pole box).
	_bevel(Vector3(.54,1.502,0),Vector3(1.31,.053,.112),.017,WOOD,ENDGRAIN)
	for x in [.27,1.116]:
		_bevel(Vector3(x,1.472,0),Vector3(.025,.093,.118),.010,CORD,HEMP)
	_pennant()
	_surface.index()
	var mesh := _surface.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mesh.surface_set_material(0,mat)
	var node := MeshInstance3D.new()
	node.name = "StandVisual"
	node.mesh = mesh
	return node


func _pin(c: Vector3, face: float) -> void:
	var corners := PackedVector3Array([c+Vector3(-.016,-.014,0),c+Vector3(.016,-.014,0),
		c+Vector3(.016,.014,0),c+Vector3(-.016,.014,0)])
	for i in 4:
		_tri(corners[i],corners[(i+1)%4],c+Vector3(0,0,.008*face),
			Vector3.BACK*face,METAL,IRON.lightened(.34))


func _pennant() -> void:
	# Broken-edged hemp cloth, not a light or functional flag. Smooth
	# shallow folds contained in the existing 14 cm depth envelope.
	var rows := PackedFloat32Array([0,.07,.28,.5,.74,.94,1.0])
	var columns := PackedFloat32Array([0,.025,.17,.315,.47,.62,.74,.85,.932,.974,1.0])
	for i in columns.size()-1:
		for j in rows.size()-1:
			var u0 := columns[i]
			var u1 := columns[i+1]
			var v0 := rows[j]
			var v1 := rows[j+1]
			var a := _sail_point(u0,v0)
			var b := _sail_point(u1,v0)
			var c := _sail_point(u1,v1)
			var d := _sail_point(u0,v1)
			var median := Vector2((u0+u1)/2.0,(v0+v1)/2.0)
			var shade := SAIL
			if j == 0 or j == rows.size()-2 or i == 0 or i == columns.size()-2:
				shade = THREAD.darkened(.16)
			elif i == 3 or i == 7:
				shade = THREAD
			else:
				shade = shade.lerp(Color("#64869a"),sin(median.x*2.9)*.16)
			_quad(a,b,c,d,Vector3.FORWARD,CLOTH,shade)


func _sail_point(u: float, v: float) -> Vector3:
	var height := 1.472 - .033*u + .009*sin(u*8.3)
	var low := .960 + .039*u + .016*sin(u*14.1) + .06*pow(u,7.0)
	var fold := (.042*sin(u*10.3+v*.65)+.011*cos(u*21.0+v*2.1))*(.72+.24*v)
	return Vector3(lerpf(.263,1.194,u),lerpf(height,low,v),fold)


func _bevel(c: Vector3, size: Vector3, bevel: float, kind: float, tint: Color) -> void:
	var h := size/2.0
	var points := []
	var d := minf(bevel,minf(h.x*.46,h.z*.46))
	var rise := minf(d,h.y*.47)
	var ring_levels := [Vector2(-h.y,d*.48),Vector2(-h.y+rise,0),Vector2(h.y-rise,0),Vector2(h.y,d*.48)]
	if minf(size.x,minf(size.y,size.z)) <= .10:
		ring_levels = [Vector2(-h.y,0),Vector2(h.y,0)]
	for level: Vector2 in ring_levels:
		var x: float = h.x-level.y
		var z: float = h.z-level.y
		var ring := PackedVector3Array()
		for q in [Vector2(-x+d,-z),Vector2(x-d,-z),Vector2(x,-z+d),Vector2(x,z-d),
			Vector2(x-d,z),Vector2(-x+d,z),Vector2(-x,z-d),Vector2(-x,-z+d)]:
			ring.append(c+Vector3(q.x,level.x,q.y))
		points.append(ring)
	for level in range(points.size()-1):
		for i in range(8):
			var j := (i+1)%8
			var a: Vector3 = points[level][i]
			var b: Vector3 = points[level][j]
			var next_a: Vector3 = points[level+1][i]
			var next_b: Vector3 = points[level+1][j]
			var sign_normal := (a+b)*.5 - c
			var value := 1.0
			if i in [1,3,5,7]:
				value += .10 if kind == WOOD else .07
			elif i == 6:
				value -= .10
			var swatch := Color(tint.r*value,tint.g*value,tint.b*value)
			_quad(a,b,next_b,next_a,sign_normal,kind,swatch)
	for p in [0,points.size()-1]:
		var normal := Vector3.DOWN if p == 0 else Vector3.UP
		for j in range(1,7):
			_tri(points[p][0],points[p][j],points[p][j+1],normal,kind,tint.lightened(.075))


func _tube(path: Array, radius: float, tint: Color) -> void:
	var vertices: Array[PackedVector3Array] = []
	for k in path.size():
		var origin: Vector3 = path[k]
		var low: Vector3 = path[maxi(k-1,0)]
		var high: Vector3 = path[mini(k+1,path.size()-1)]
		var flow := (high-low).normalized()
		var side := flow.cross(Vector3.FORWARD).normalized()
		var profile := PackedVector3Array()
		for i in 6:
			profile.append(origin + side.rotated(flow,float(i)*TAU/6.0)*radius)
		vertices.append(profile)
	for k in path.size()-1:
		for i in 6:
			var j := (i+1)%6
			var a := vertices[k][i]
			var b := vertices[k][j]
			_quad(a,b,vertices[k+1][j],vertices[k+1][i],(a+b)*.5-path[k],CORD,tint)


func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,expected: Vector3,kind: float,tint: Color) -> void:
	_tri(a,b,c,expected,kind,tint)
	_tri(a,c,d,expected,kind,tint)


func _tri(a: Vector3,b: Vector3,c: Vector3,expected: Vector3,kind: float,tint: Color) -> void:
	var n := (c-a).cross(b-a).normalized()
	if n.dot(expected) < 0.0:
		var temp := b
		b = c
		c = temp
		n = -n
	for point in [a,b,c]:
		_surface.set_normal(n)
		_surface.set_uv(Vector2(kind,0))
		_surface.set_color(tint)
		_surface.add_vertex(point)
