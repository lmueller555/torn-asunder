extends RefCounted
## One closed static Mine works shell and its low roof. No physics, UI or animation.

const WHITE := Color.WHITE
const MAIN := 0
const OAK := 1
const STONE := 2
const SLATE := 3
const FACE_NORMAL := [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]
const PLANK := Color(.96,.984,.99)
const STRAP := Color(.57,.63,.65)
const FRAME := Color(.93,.88,.815)
const COLLAR := Color(.66,.61,.54)
var _surface: SurfaceTool


func build(material: StandardMaterial3D) -> MeshInstance3D:
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in range(4):
		_side(face)
	_low_roof()
	_surface.index()
	var mesh := _surface.commit()
	mesh.surface_set_material(0,material)
	var kit := MeshInstance3D.new()
	kit.name = "OfflineClosedWorksStorehouseStudy"
	kit.mesh = mesh
	return kit


func _side(face: int) -> void:
	var half := 4.0 if face%2 == 0 else 3.5
	# A continuous back surface within the exact solid protects ground,
	# silhouettes and LOS even between chipped sill stones or frames.
	_rect(face,Vector2(-half+.002,0),Vector2(half-.002,.86),.032,
		STONE,Color(.60,.56,.51))
	_rect(face,Vector2(-half+.002,.82),Vector2(half-.002,4.2),.031,
		MAIN,PLANK.lightened(.02*face))
	_sill(face,half)
	for y in [.90,3.78]:
		_bar(face,Vector2(-half+.11,y),Vector2(half-.11,y),.22,.002,FRAME,STONE if y<1.0 else OAK)
	var post_centers := [-half+.115,-half*.47,half*.05,half*.52,half-.115]
	if face == 1:
		post_centers = [-half+.12,-1.62,-.45,1.86,half-.115]
	elif face == 2:
		post_centers = [-half+.12,-2.30,-.36,1.80,half-.115]
	for s in post_centers:
		_bar(face,Vector2(s,1.015),Vector2(s,3.79),.214,.003,FRAME,OAK)
	# Lower thin meeting rails and distinct scarf-to-upright geometry keep
	# it from reading as a flat decorative brick box at eye height.
	_bar(face,Vector2(-half+.13,1.25),Vector2(half-.13,1.25),.10,.006,COLLAR,OAK)
	if face == 1:
		# A raised, completely boarded loading hatch. No figure-sized
		# silhouette, bright interior, stair or usable portal.
		_brace(face,Vector2(-3.20,1.37),Vector2(-1.62,3.70))
		_brace(face,Vector2(1.89,3.62),Vector2(3.27,1.36))
		_shutter(face,Vector2(-.30,2.02),Vector2(1.71,3.07))
	elif face == 3:
		_brace(face,Vector2(-3.15,3.63),Vector2(-.25,1.36))
		_brace(face,Vector2(.31,1.38),Vector2(3.15,3.64))
		_bar(face,Vector2(-1.48,2.61),Vector2(.15,2.61),.08,.006,COLLAR,OAK)
	else:
		_brace(face,Vector2(-half+.28,1.36),Vector2(-.3,3.65 if face==0 else 3.55))
		_brace(face,Vector2(.26,3.64),Vector2(half-.27,1.36))
		_bar(face,Vector2(-.36,2.43),Vector2(half-.25,2.43),.087,.005,COLLAR,OAK)


func _brace(face: int,a: Vector2,b: Vector2) -> void:
	_bar(face,a,b,.144,.002,FRAME.lightened(.055),OAK)
	# Small exposed mortise plates locate the structural joints visually.
	for end in [a,b]:
		_rect(face,end-Vector2(.04,.042),end+Vector2(.04,.042),.001,OAK,STRAP)


func _shutter(face: int,a: Vector2,b: Vector2) -> void:
	_rect(face,a,b,.013,MAIN,Color(.72,.71,.623))
	for x in [a.x,b.x,lerpf(a.x,b.x,.49)]:
		_bar(face,Vector2(x,a.y-.02),Vector2(x,b.y+.02),.10,.001,FRAME,OAK)
	for y in [a.y,b.y]:
		_bar(face,Vector2(a.x-.046,y),Vector2(b.x+.046,y),.124,.001,FRAME,OAK)
	var mid := lerpf(a.y,b.y,.50)
	_bar(face,Vector2(a.x+.16,mid),Vector2(b.x-.13,mid),.106,0.0,COLLAR,OAK)
	for x in [a.x+.20,b.x-.24]:
		_rect(face,Vector2(x-.082,mid-.10),Vector2(x+.082,mid+.10),0.0,OAK,STRAP)
		_rect(face,Vector2(x-.028,mid-.032),Vector2(x+.028,mid+.032),0.0,OAK,STRAP.lightened(.31))


func _sill(face: int,half: float) -> void:
	var origin := -half+.017
	for course in range(2):
		var cursor := origin
		var i := 0
		while cursor < half-.084:
			var jitter := .54+.15*sin(float(i)*1.73+course*1.17+face*.67)
			var end := minf(half-.012,cursor+jitter)
			var y := .020 + float(course)*.402 + .02*sin(i*1.822+face)
			var bottom := maxf(.003,y)
			var top := minf(.846,bottom+.34+.035*cos(i*1.581+face*1.673))
			var shade := .87+.12*sin(i*2.1+face*.54+course*.52)
			var c := Color(shade,shade*.991,shade*.978)
			var chip := minf(.070,(end-cursor)*.31)
			var start := cursor+.008
			var shell := .011+.010*sin(i*.77+face+course)
			var rim: Array[Vector2] = [
				Vector2(start,bottom+chip*.50),Vector2(start+chip,bottom),
				Vector2(end-chip*.65,bottom+.007),Vector2(end,top-chip*.55),
				Vector2(end-chip,top),Vector2(start+chip*.57,top-.011),
			]
			if top-bottom>.12 and end-cursor>.13:
				_stone(face,rim,c,shell,i)
			cursor=end+.016
			i+=1


func _stone(face: int,rim: Array[Vector2],tint: Color,shell: float,index: int) -> void:
	var uv := []
	var front := []
	for j in rim.size():
		var p := rim[j]
		uv.append(_tile(STONE,Vector2(.19 + .115*float(j),.22 + .09*float(j%3) + .044*float(index%5))))
		front.append(_point(face,p,shell))
	for i in range(1,rim.size()-1):
		_tri([front[0],front[i],front[i+1]], [uv[0],uv[i],uv[i+1]], FACE_NORMAL[face],tint)
	# The top facets, not any extra support, make the irregular course read.
	_quad([front[3],front[4],_point(face,rim[4],.032),_point(face,rim[3],.032)],
		(FACE_NORMAL[face]+Vector3.UP),tint.lightened(.11),_uv_rect(STONE))
	_quad([front[4],front[5],_point(face,rim[5],.032),_point(face,rim[4],.032)],
		(FACE_NORMAL[face]+Vector3.UP),tint.lightened(.11),_uv_rect(STONE))


func _rect(face: int,a: Vector2,b: Vector2,d: float,texture: int,tint: Color) -> void:
	_quad([_point(face,a,d),_point(face,Vector2(b.x,a.y),d),_point(face,b,d),
		_point(face,Vector2(a.x,b.y),d)],FACE_NORMAL[face],tint,_uv_rect(texture))


func _bar(face: int,a: Vector2,b: Vector2,width: float,d: float,tint: Color,texture: int) -> void:
	var normal := (b-a).orthogonal().normalized()*width*.5
	var beveled := normal*.88
	var outline := [a+normal,b+normal,b-normal,a-normal]
	var inside := [a+beveled,b+beveled,b-beveled,a-beveled]
	var back: Array[Vector3] = []
	var front: Array[Vector3] = []
	for j in 4:
		back.append(_point(face,outline[j],d+.028))
		front.append(_point(face,inside[j],d))
	var uv := _uv_rect(texture)
	uv = [uv[0],uv[3],uv[2],uv[1]] # grain along the beam, not across its face
	_quad(front,FACE_NORMAL[face],tint,uv)
	for j in [0,2]:
		var k: int = (j+1)%4
		_quad([front[j],front[k],back[k],back[j]],FACE_NORMAL[face],
			tint.lightened(.08) if j==0 else tint.darkened(.11),_uv_rect(texture))


func _low_roof() -> void:
	# The broad stock overhang is a real solid. Preserve its entire plan
	# extent and fitted shallow roof, not a false gap or playable ledge.
	var corners: Array[Vector3] = [
		Vector3(-4.40,4.447,-3.90),Vector3(4.40,4.447,-3.90),
		Vector3(4.40,4.447,3.90),Vector3(-4.40,4.447,3.90),
	]
	var ridge_l := Vector3(-4.40,4.507,0)
	var ridge_r := Vector3(4.40,4.507,0)
	_quad([corners[0],corners[1],ridge_r,ridge_l],Vector3.UP,Color(.98,1,.975),_uv_rect(SLATE))
	var tiles := _uv_rect(SLATE)
	tiles = [tiles[1],tiles[0],tiles[3],tiles[2]]
	_quad([corners[2],corners[3],ridge_l,ridge_r],Vector3.UP,Color(.91,.93,.985),tiles)
	for i in 4:
		var a := corners[i]
		var b := corners[(i+1)%4]
		var out := [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT][i] as Vector3
		var base := 4.031
		_quad([Vector3(a.x,base,a.z),Vector3(b.x,base,b.z),Vector3(b.x,4.242,b.z),Vector3(a.x,4.242,a.z)],
			out,Color(.80,.73,.666),_uv_rect(OAK))
		_quad([Vector3(a.x,4.242,a.z),Vector3(b.x,4.242,b.z),b,a],out,Color(.82,.82,.806),_uv_rect(SLATE))
		var inner_a := Vector3(a.x*4.0/4.4,base,a.z*3.5/3.9)
		var inner_b := Vector3(b.x*4.0/4.4,base,b.z*3.5/3.9)
		_quad([Vector3(a.x,base,a.z),Vector3(b.x,base,b.z),inner_b,inner_a],
			Vector3.DOWN,Color(.70,.70,.65),_uv_rect(OAK))
		if i in [1,3]:
			_tri([a,b,ridge_r if i==1 else ridge_l],_uv_rect(SLATE).slice(0,3),out,Color(.85,.855,.85))


func _point(face: int,s: Vector2,d: float) -> Vector3:
	match face:
		0: return Vector3(s.x,s.y,-3.5+d)
		1: return Vector3(4-d,s.y,s.x)
		2: return Vector3(-s.x,s.y,3.5-d)
		_: return Vector3(-4+d,s.y,-s.x)


func _tile(texture: int,p: Vector2) -> Vector2:
	var x := float(texture % 2)*.5
	var y := .50 if texture >= STONE else 0.0
	return Vector2(x+.006+p.x*.488,y+.009+p.y*.482)


func _uv_rect(texture: int) -> Array:
	return [_tile(texture,Vector2(0,1)),_tile(texture,Vector2(1,1)),
		_tile(texture,Vector2(1,0)),_tile(texture,Vector2(0,0))]


func _quad(p: Array[Vector3],expect: Vector3,tint: Color,uv: Array) -> void:
	_tri([p[0],p[1],p[2]],[uv[0],uv[1],uv[2]],expect,tint)
	_tri([p[0],p[2],p[3]],[uv[0],uv[2],uv[3]],expect,tint)


func _tri(p: Array[Vector3],uv: Array,expect: Vector3,tint: Color) -> void:
	var normal := (p[2]-p[0]).cross(p[1]-p[0]).normalized()
	if normal.dot(expect) < 0:
		normal = -normal
		p.reverse()
		uv.reverse()
	for i in 3:
		_surface.set_normal(normal)
		_surface.set_uv(uv[i])
		_surface.set_color(tint)
		_surface.add_vertex(p[i])
