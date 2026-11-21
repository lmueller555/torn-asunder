extends Node3D
## Editable static spillway wheel, bearings and limestone support.
## The visual scene is independent of mission state, movement and collisions.

@export var surface_material: Material

const WOOD := 0
const STONE := 1
const IRON := 2
const BRONZE := 3
const FOOT := 4
const POLISHED := 5
const MODE_DISTANCE := 39.0
const AXLE_Y := 1.79
const WHEEL_Z := -0.55
var _builder: SurfaceTool



func _ready() -> void:
	build(surface_material)


func build(material: Material) -> void:
	var near := _variant(false,material)
	var far := _variant(true,material)
	var both := near.get_aabb().merge(far.get_aabb())
	near.custom_aabb = both
	far.custom_aabb = both
	near.visibility_range_end = MODE_DISTANCE
	far.visibility_range_begin = MODE_DISTANCE
	# Far mesh retains the actual profiles of rim/spokes, frame and
	# masonry; reuse its immutable surface as a genuine shadow caster.
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow := MeshInstance3D.new()
	shadow.name = &"WheelShadowProxy"
	shadow.mesh = far.mesh
	shadow.custom_aabb = both
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.visibility_range_end = MODE_DISTANCE
	add_child(shadow)


func _variant(far: bool,material: Material) -> MeshInstance3D:
	_builder = SurfaceTool.new()
	_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	_builder.set_material(material)

	_masonry(far)

	# Twin oak housings run back from the bolt-down face over one common
	# shaft. Front wheel and rear drum are one fixed mechanical assembly.
	for z: float in [-.23,.60]:
		_box(Vector3(0,.674,z),Vector3(.74,.108,.40),IRON)
		_block_prism(Vector3(0,1.158,z),Vector3(.43,.895,.31),.045,WOOD)
		_box(Vector3(0,1.369,z),Vector3(.48,.117,.336),IRON)
		_box(Vector3(0,1.587,z),Vector3(.62,.143,.42),IRON)
		_axial(z-.24,z+.24,.219,.0,AXLE_Y,BRONZE,far)
		if not far:
			for x: float in [-.254,.254]:
				_pin(x,.739,z,.041,IRON)
				_pin(x*.82,1.668,z,.055,POLISHED)
	for side in [-1.0,1.0]:
		_beam(Vector3(0,1.51,.61),Vector3(side*.89,.707,.94),.145,.16,WOOD)
		if not far:
			_box(Vector3(side*.89,.684,.94),Vector3(.267,.085,.262),IRON)
	_box(Vector3(0,.715,.955),Vector3(2.22,.105,.36),WOOD)
	_axial(-.83,.99,.102,0.0,AXLE_Y,IRON,far)
	_axial(.82,1.02,.27,0.0,AXLE_Y,WOOD,far)
	_axial(.83,.864,.294,0.0,AXLE_Y,IRON,far)
	_axial(.984,1.018,.294,0.0,AXLE_Y,IRON,far)
	_axial(WHEEL_Z-.206,WHEEL_Z+.16,.222,0.0,AXLE_Y,WOOD,far)
	_axial(WHEEL_Z-.234,WHEEL_Z-.173,.247,0.0,AXLE_Y,BRONZE,far)
	_axial(WHEEL_Z-.259,WHEEL_Z-.213,.139,0.0,AXLE_Y,POLISHED,far)

	var rim_sides := 18 if far else 30
	_track(rim_sides,.848,1.001,.128,WOOD,far)
	_track(rim_sides,.967,1.038,.174,IRON,far)
	if not far:
		_track(rim_sides,1.002,1.028,.180,POLISHED,true)
	for j in range(6):
		var angle := (j+.33)*TAU/6.0
		var ray := Vector3(cos(angle),sin(angle),0.0)
		var hub := Vector3(0,AXLE_Y,WHEEL_Z)
		_beam(hub+ray*.185,hub+ray*.905,.128,.118,WOOD)
		var shoe := hub + ray*.852
		_beam(shoe-ray*.070,shoe+ray*.092,.185,.143,IRON)
		if not far:
			_axial(shoe.z-.084,shoe.z-.07,.025,shoe.x,shoe.y,POLISHED,true)
			var handle := hub+ray*.997
			_axial(handle.z-.16,handle.z+.121,.045,handle.x,handle.y,WOOD,true)
	_builder.index()
	var part := MeshInstance3D.new()
	part.name = &"Far" if far else &"Near"
	part.mesh = _builder.commit()
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(part)
	return part

func _masonry(far: bool) -> void:
	# Stock solid extents are kept visibly occupied, not just a footprint.
	# Each cut uses three planar projections, with independent texture
	# phase per block and the same interpolation across a face diagonal.
	if far:
		_planar_box(Vector3.ZERO,Vector3(3.71,1.25,2.91),STONE,0.19)
		return
	_planar_box(Vector3(0.0,0.0,0.0),Vector3(3.702,1.241,2.902),FOOT,0.29)
	_planar_box(Vector3(0,-.544,0),Vector3(3.769,.155,2.969),STONE,.11)
	_planar_box(Vector3(0,.508,0),Vector3(3.747,.244,2.949),STONE,.18)
	for side in [-1.0,1.0]:
		for row in range(2):
			var y := -.24 + .423*row
			var x_joints: Array = [-1.871,-.96,.07,1.16,1.871] if row==0 else [-1.871,-1.41,-.35,.71,1.871]
			var z_joints: Array = [-1.457,-.58,.51,1.457] if row==0 else [-1.457,-1.03,.05,.93,1.457]
			for j in range(x_joints.size()-1):
				var a: float = x_joints[j] + (.008 if j==0 else .018)
				var b: float = x_joints[j+1] - .017
				var d := .033 + .011 * sin(17.0*j+7.0*row)
				_planar_box(Vector3((a+b)*.5,y+sin(j*5.1)*.005,side*(1.448+d*.21)),
					Vector3(b-a,.399,d*2),STONE,.09+fposmod(j*.17+row*.27,.29))
			for j in range(z_joints.size()-1):
				var a: float = z_joints[j] + (.01 if j==0 else .017)
				var b: float = z_joints[j+1] - .014
				var d := .032 + .010 * cos(5.7*j+9.0*row)
				_planar_box(Vector3(side*(1.847+d*.23),y+sin(j*3.9)*.004,(a+b)*.5),
					Vector3(d*2,.397,b-a),STONE,.06+fposmod(j*.19+row*.22,.32))


func _planar_box(center: Vector3,size: Vector3,tile: int,shift: float) -> void:
	var h := size*.5
	var p := [
		center+Vector3(-h.x,-h.y,-h.z),center+Vector3(h.x,-h.y,-h.z),
		center+Vector3(h.x,-h.y,h.z),center+Vector3(-h.x,-h.y,h.z),
		center+Vector3(-h.x,h.y,-h.z),center+Vector3(h.x,h.y,-h.z),
		center+Vector3(h.x,h.y,h.z),center+Vector3(-h.x,h.y,h.z),
	]
	var u_x := minf(.73, size.x*.247)
	var u_z := minf(.74, size.z*.249)
	var v_y := minf(.80,size.y*.57)
	_planar_face(p[4],p[5],p[6],p[7],Vector3.UP,tile,shift,u_x,u_z)
	_planar_face(p[3],p[2],p[1],p[0],Vector3.DOWN,tile,shift,u_x,u_z)
	_planar_face(p[0],p[1],p[5],p[4],Vector3.FORWARD,tile,shift,u_x,v_y)
	_planar_face(p[2],p[3],p[7],p[6],Vector3.BACK,tile,shift,u_x,v_y)
	_planar_face(p[3],p[0],p[4],p[7],Vector3.LEFT,tile,shift,u_z,v_y)
	_planar_face(p[1],p[2],p[6],p[5],Vector3.RIGHT,tile,shift,u_z,v_y)


func _planar_face(a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3,tile: int,
		phase: float,u_width: float,v_width: float) -> void:
	# Fixed rectangular planar coordinates for the entire face. UVs at A
	# and C shared by both triangles; no center vertex or radial fan.
	var u := fposmod(phase,.90-u_width)+.04
	var v := fposmod(.18+phase*1.81,.90-v_width)+.04
	var pa := _uv(tile,u,v)
	var pb := _uv(tile,u+u_width,v)
	var pc := _uv(tile,u+u_width,v+v_width)
	var pd := _uv(tile,u,v+v_width)
	if (b-a).cross(c-a).dot(n)>0:
		_add(a,c,b,pa,pc,pb,n)
		_add(a,d,c,pa,pd,pc,n)
	else:
		_add(a,b,c,pa,pb,pc,n)
		_add(a,c,d,pa,pc,pd,n)


func _track(n: int,inner: float,outer: float,thick: float,tile: int,cheap: bool) -> void:
	var inset := minf(.028,(outer-inner)*.38)
	var half := thick*.5
	var sections: Array[Vector2] = [Vector2(inner,-half+.020),Vector2(inner+inset,-half),Vector2(outer-inset,-half),
		Vector2(outer,-half+.020),Vector2(outer,half-.020),Vector2(outer-inset,half),Vector2(inner+inset,half),Vector2(inner,half-.020)]
	if cheap:
		sections=[Vector2(inner,-half),Vector2(outer,-half),Vector2(outer,half),Vector2(inner,half)]
	for j in range(n):
		var a := TAU*j/n
		var b := TAU*(j+1)/n
		for k in range(sections.size()):
			var u := sections[k]
			var v := sections[(k+1)%sections.size()]
			var radial := Vector3(cos((a+b)*.5),sin((a+b)*.5),0.0)
			var normal := (radial*(v.y-u.y) + Vector3.FORWARD*(v.x-u.x)).normalized()
			_quad(_ring_point(a,u),_ring_point(b,u),_ring_point(b,v),_ring_point(a,v),normal,tile,fposmod(j*.14,.33),.58)

func _ring_point(angle: float,section:Vector2) -> Vector3:
	return Vector3(section.x*cos(angle),AXLE_Y+section.x*sin(angle),WHEEL_Z+section.y)

func _axial(from_z: float,to_z: float,r: float,x: float,y: float,tile:int,cheap:bool) -> void:
	var n := 8 if cheap else 12
	var z0 := Vector3(x,y,from_z)
	var z1 := Vector3(x,y,to_z)
	for i in range(n):
		var a := TAU*i/n
		var b := TAU*(i+1)/n
		var u := r*Vector3(cos(a),sin(a),0)
		var v := r*Vector3(cos(b),sin(b),0)
		_quad(z0+u,z0+v,z1+v,z1+u,(u+v).normalized(),tile,.11,.73)
		_tri(z0,z0+u,z0+v,Vector3.FORWARD,tile)
		_tri(z1,z1+v,z1+u,Vector3.BACK,tile)

func _pin(x:float,y:float,z:float,r:float,tile:int) -> void:
	_block_prism(Vector3(x,y,z),Vector3(r*2.0,.045,r*2.0),.012,tile)

func _beam(a: Vector3,b: Vector3,w: float,h: float,tile:int) -> void:
	var along := (b-a).normalized()
	var right := along.cross(Vector3.FORWARD).normalized()*w*.5
	var depth := Vector3.FORWARD*h*.5
	var points := [a-right-depth,a+right-depth,a+right+depth,a-right+depth,
		b-right-depth,b+right-depth,b+right+depth,b-right+depth]
	_quad(points[0],points[1],points[5],points[4],-depth,tile,.06,.81)
	_quad(points[2],points[3],points[7],points[6],depth,tile,.09,.80)
	_quad(points[1],points[2],points[6],points[5],right,tile,.10,.81)
	_quad(points[3],points[0],points[4],points[7],-right,tile,.11,.75)
	_quad(points[0],points[1],points[2],points[3],-along,tile,.12,.72)
	_quad(points[7],points[6],points[5],points[4],along,tile,.12,.72)

func _box(at: Vector3,size: Vector3,tile: int)->void:
	_block_prism(at,size,0.0,tile)

func _block_prism(at: Vector3,size: Vector3,clip: float,tile: int,offset:=.11) -> void:
	var h := size*.5
	var c := minf(clip,minf(h.x,h.z)*.82)
	var loop: Array[Vector2] = [Vector2(-h.x,-h.z),Vector2(h.x,-h.z),Vector2(h.x,h.z),Vector2(-h.x,h.z)]
	if c>0.0:
		loop=[Vector2(-h.x+c,-h.z),Vector2(h.x-c,-h.z),Vector2(h.x,-h.z+c),Vector2(h.x,h.z-c),
			Vector2(h.x-c,h.z),Vector2(-h.x+c,h.z),Vector2(-h.x,h.z-c),Vector2(-h.x,-h.z+c)]
	for j in range(loop.size()):
		var a := loop[j]
		var b := loop[(j+1)%loop.size()]
		var p := at+Vector3(a.x,-h.y,a.y)
		var q := at+Vector3(b.x,-h.y,b.y)
		var up := Vector3.UP*size.y
		var out := Vector3(b.y-a.y,0,a.x-b.x).normalized()
		_quad(p,q,q+up,p+up,out,tile,offset,.67)
		_tri(at+Vector3.UP*h.y,p+up,q+up,Vector3.UP,tile)
		_tri(at-Vector3.UP*h.y,p,q,Vector3.DOWN,tile)

func _quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,out:Vector3,tile:int,offset:float,span:float)->void:
	var norm := (b-a).cross(c-a)
	if norm.length_squared()<1e-14:
		return
	norm=norm.normalized()
	var pa := _uv(tile,offset,.06)
	var pb := _uv(tile,offset+span,.06)
	var pc := _uv(tile,offset+span,.94)
	var pd := _uv(tile,offset,.94)
	if norm.dot(out)>0:
		_add(a,c,b,pa,pc,pb,norm)
		_add(a,d,c,pa,pd,pc,norm)
	else:
		_add(a,b,c,pa,pb,pc,-norm)
		_add(a,c,d,pa,pc,pd,-norm)

func _tri(a:Vector3,b:Vector3,c:Vector3,out:Vector3,tile:int)->void:
	var pa := _uv(tile,.50,.50)
	var pb := _uv(tile,.09,.11)
	var pc := _uv(tile,.89,.71)
	if (b-a).cross(c-a).dot(out)>0:
		_add(a,c,b,pa,pc,pb,out)
	else:
		_add(a,b,c,pa,pb,pc,out)

func _add(a:Vector3,b:Vector3,c:Vector3,pa:Vector2,pb:Vector2,pc:Vector2,norm:Vector3)->void:
	_builder.set_normal(norm)
	_builder.set_uv(pa)
	_builder.add_vertex(a)
	_builder.set_uv(pb)
	_builder.add_vertex(b)
	_builder.set_uv(pc)
	_builder.add_vertex(c)

func _uv(tile:int,u:float,v:float)->Vector2:
	return Vector2((posmod(tile,3)+.025+.95*clampf(u,0.0,1.0))/3.0,
		(floorf(tile/3.0)+.025+.95*clampf(v,0.0,1.0))/2.0)
