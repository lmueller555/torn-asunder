extends RefCounted
## Reversible field camp, not an additional waypoint or persistent installation.
## Weathercloth, lapped timber and cold stone in a volunteer work camp.
const Opening := preload("res://game/overworld/cairnspine/sova_opener_route.gd")
const ShaderDef := preload("res://game/overworld/cairnspine/sova_opener_camp.gdshader")
const TONES := {
	&"wood": Color("#745332"), &"wood_wear": Color("#a2885f"),
	&"canvas": Color("#777553"), &"canvas_wear": Color("#aaa87a"),
	&"stone": Color("#91897a"), &"rope": Color("#554638"),
	&"track": Color("#8a7554"), &"apron": Color("#8b806c"), &"iron": Color("#48483f"),
}
var ground: Callable
var art := Node3D.new()
var support := PackedVector3Array()
var shelf: Dictionary = {}
var faded: Dictionary = {}
var invalid := false
var angle := .39


static func make(sample: Callable, path: PackedVector3Array) -> Node3D:
	var builder := new()
	builder.ground = sample
	builder.art.name = "CairnspineFieldCamp"
	builder._tread(path)
	builder._shelter(Vector2(131,-94),1.0,false)
	builder.angle = .08
	builder._shelter(Vector2(125,-101),.72,true)
	builder._workyard(Vector2(131,-102))
	builder._apron(Vector2(128,-97))
	if builder.invalid:
		builder.art.free()
		return null
	builder._finish()
	return builder.art


func _tread(path: PackedVector3Array) -> void:
	var last := PackedVector3Array()
	for i in range(Opening.SPUR-2,path.size()):
		var center := path[i]
		var d := path[mini(path.size()-1,i+1)] - path[i-1]
		var shoulder := Vector2(-d.z,d.x).normalized()
		var current := PackedVector3Array()
		var t := inverse_lerp(Opening.SPUR-2,path.size()-1,i)
		for j in range(5):
			var lateral := float(j-2)*.90
			var span := shoulder * (lateral + sin(i * 1.86 + j) * .17)
			var foot := _foot(Vector2(center.x,center.z)+span)+Vector3.UP*.066
			var alpha := sin(PI*t) if t<.21 else 0.89
			faded[foot] = alpha * clampf(1.0 - absf(lateral)/1.79,0,1)
			current.append(foot)
		if last.size() > 0:
			for j in range(4):
				_quad(last[j],last[j+1],current[j+1],current[j],&"track")
		last = current


func _shelter(center: Vector2, s: float, lean_to: bool) -> void:
	var W := 3.1 * s
	var depth := 2.25 * s
	var feet := PackedVector3Array()
	for offset in [Vector2(-W,-depth),Vector2(W,-depth),Vector2(-W,depth),Vector2(W,depth)]:
		feet.append(_foot(center+offset.rotated(angle)))
	var h := -INF
	for foot in feet:
		h = maxf(h,foot.y)
	var post := h + 2.32*s
	for j in range(4):
		var cap := Vector3(feet[j].x,post - (.49*s if lean_to and j>1 else .0),feet[j].z)
		_beam(feet[j]-Vector3.UP*.08,cap,.23*s,&"wood")
		var opposite := feet[1-j] if j<2 else feet[5-j]
		_beam(cap.lerp(Vector3(opposite.x,cap.y,opposite.z),.30),cap-Vector3.UP*.67*s,.123*s,&"wood_wear")
		var peg := _foot(center+(Vector2((-W if j%2==0 else W)*1.28,(-depth if j<2 else depth)*1.34)).rotated(angle))
		_beam(peg,cap,.065*s,&"rope")
		_beam(peg-Vector3.UP*.10,peg+Vector3.UP*.22,.086*s,&"wood")
		_lash(cap-Vector3.UP*.16*s,.16*s,7,.113*s,j*.73)
		_lash(peg+Vector3.UP*.06,.072*s,4,.05*s,j*.38)
	# Small split slate footstones keep the front rope rig from drifting
	# visually above the shelf; both the fabric and stakes stay reversible.
	for j in range(4):
		_rock(feet[j]-Vector3.UP*.04,.35*s,j*.71)
	# Rear weathercloth hangs just lower than each eave, without boxy solid walls.
	var back_z := -depth*.95
	for j in range(6):
		var x1 := lerpf(-W*.94,W*.94,j/6.0)
		var x2 := lerpf(-W*.94,W*.94,(j+1)/6.0)
		var sag := .54*s+.11*cos(j*1.57)
		_quad(_at(center,x1,back_z,post-.19*s),_at(center,x2,back_z,post-.19*s),
			_at(center,x2,back_z+.15*s,post-sag),_at(center,x1,back_z+.14*s,post-sag-.13*s),&"canvas")
	for side in [-1,1]:
		for i in range(7):
			var x1 := lerpf(-W*1.16,W*1.16,float(i)/7.0)
			var x2 := lerpf(-W*1.16,W*1.16,float(i+1)/7.0)
			var outer := post-.05*s - (.42*s if lean_to and side==1 else .0)
			var ridge := post+1.30*s - (.69*s if lean_to else .0)
			var a := _at(center,x1,0,ridge + cos(x1*.89)*.036)
			var b := _at(center,x2,0,ridge + cos(x2*.89)*.036)
			var c := _at(center,x2,side*depth*.62,lerpf(ridge,outer,.66)-.22*s+cos(x2*2.7)*.068)
			var d := _at(center,x1,side*depth*.62,lerpf(ridge,outer,.66)-.22*s+cos(x1*2.7)*.068)
			var e := _at(center,x2,side*depth*1.18,outer+cos(x2*2.22)*.085)
			var f := _at(center,x1,side*depth*1.18,outer+cos(x1*2.22)*.085)
			_quad(a,b,c,d,&"canvas_wear" if i in [1,5] else &"canvas")
			_quad(d,c,e,f,&"canvas_wear" if i in [1,5] else &"canvas")
			_beam(a,d,.036*s,&"canvas_wear")
			_beam(d,f,.036*s,&"canvas_wear")
			_beam(f,e,.036*s,&"rope")
	_beam(_at(center,-W*1.12,0,post+s*.98),_at(center,W*1.12,0,post+s*.98),.17*s,&"wood")


func _apron(center: Vector2) -> void:
	# Scattered slate and tamped fines share one dry terrace. Outer feather is
	# triangulated on surveyed terrain, not a level disc dropped on a hillside.
	var rings: Array[PackedVector3Array] = []
	var pin := _foot(center)+Vector3.UP*.059
	faded[pin] = .79
	for ring in range(1,5):
		var points := PackedVector3Array()
		var spread := float(ring)/4.0
		for i in range(22):
			var a := float(i)*TAU/22.0
			var wobble := 1.0+.13*sin(a*3.0)+.07*cos(a*8.0+ring*.35)
			var delta := (Vector2(cos(a)*8.62,sin(a)*5.91)*spread*wobble).rotated(.21)
			var foot := _foot(center+delta)+Vector3.UP*(.055 + .013*sin(i*2.77))
			faded[foot] = 0.0 if ring==4 else (0.84 if ring<3 else .55)
			points.append(foot)
		rings.append(points)
	for i in range(22):
		var next := (i+1)%22
		_tri(pin,rings[0][i],rings[0][next],&"apron")
		for j in range(1,4):
			_quad(rings[j-1][i],rings[j][i],rings[j][next],rings[j-1][next],&"apron")
	for dxz: Vector2 in [Vector2(-6.1,1.1),Vector2(-5.3,2.0),Vector2(-4.8,1.75),
		Vector2(3.6,-2.7),Vector2(4.8,-3.8),Vector2(6.1,-3.4),Vector2(6.6,-2.7),
		Vector2(5.7,3.2),Vector2(5.1,3.5),Vector2(5.8,3.82)]:
		var p := _foot(center+dxz)
		_rock(p,.21+absf(sin(dxz.x*2.0))*.38,dxz.y*1.15)


func _lash(center: Vector3, radius: float, loops: int, rise: float, phase: float) -> void:
	for j in range(loops):
		var a := j*TAU/(loops-1) + phase
		var b := (j+1)*TAU/(loops-1) + phase
		var base := center+Vector3.UP*(rise*j/maxi(1,loops-1))
		_beam(base+Vector3(cos(a)*radius,0,sin(a)*radius),
			base+Vector3(cos(b)*radius,rise/maxi(1,loops-1),sin(b)*radius),.044,&"rope")


func _workyard(center: Vector2) -> void:
	var nodes := [Vector2(-.7,.8),Vector2(.3,-.8),Vector2(1.3,-.4),Vector2(2.2,.2)]
	for i in range(nodes.size()):
		var p := _foot(center + nodes[i])
		for j in range(3):
			_beam(p+Vector3(-.41,.08+j*.14,0),p+Vector3(.4,.11+j*.14,.13),.18,&"wood" if i%2==0 else &"wood_wear")
	var ash := center + Vector2(1.0,3.72)
	for i in range(9):
		var direction := Vector2(cos(i*.698),sin(i*.698))
		var base := _foot(ash + direction*(1.06+sin(i*1.77)*.13))
		_rock(base, .31 + cos(i*2.29)*.10, i*.67)
	var station := center + Vector2(3.63,1.28)
	var foot := _foot(station)
	for x in [-1,1]:
		var p := _foot(station + Vector2(x*.82,0))
		_beam(p-Vector3.UP*.05,Vector3(p.x,foot.y+.89,p.z),.22,&"wood")
	for wedge: float in [-.87,.87]:
		var seat := _foot(station+Vector2(wedge,.12))
		_rock(seat,.49,wedge*2.15)
		_beam(seat+Vector3.UP*.20,seat+Vector3(.12,.57,-.10),.29,&"wood")
	for j in range(4):
		var z := foot.z + (j-1.5)*.26
		_beam(Vector3(foot.x-1.09,foot.y+.91,z),Vector3(foot.x+1.09,foot.y+.91,z),.26,&"wood_wear")
	_beam(foot+Vector3(.15,.78,-.4),foot+Vector3(.51,1.11,-.37),.12,&"iron")


func _foot(xz: Vector2) -> Vector3:
	var v: Vector3 = ground.call(xz)
	if not v.is_finite():
		invalid=true
		return Vector3(xz.x,0,xz.y)
	support.append(v)
	return v


func _at(center: Vector2,x: float,z: float,y: float) -> Vector3:
	var p := center+Vector2(x,z).rotated(angle)
	return Vector3(p.x,y,p.y)


func _rock(p: Vector3,size: float,phase: float) -> void:
	for i in range(6):
		var a := i*TAU/6+phase
		var b := a+TAU/6
		var x := Vector3(cos(a),0,sin(a))*size
		var y := Vector3(cos(b),0,sin(b))*size
		var inset := Vector3.DOWN*.1
		_quad(p+x+inset,p+y+inset,p+y*.85+Vector3.UP*size*.39,p+x*.86+Vector3.UP*size*.43,&"stone")
		_tri(p+x*.86+Vector3.UP*size*.43,p+y*.85+Vector3.UP*size*.39,p+Vector3.UP*size*.56,&"stone")


func _beam(a: Vector3,b: Vector3,w: float,tone: StringName) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.RIGHT if absf(axis.y)>.91 else Vector3.UP).normalized() * w*.5
	var rise := axis.cross(side).normalized()*w*.48
	var points := PackedVector3Array()
	for k in range(8):
		points.append((b if k&4 else a)+side*(1 if k&1 else -1)+rise*(1 if k&2 else -1))
	for q in [[0,1,3,2],[4,6,7,5],[0,2,6,4],[1,5,7,3],[0,4,5,1],[2,3,7,6]]:
		_quad(points[q[0]],points[q[1]],points[q[2]],points[q[3]],tone)


func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,tone: StringName) -> void:
	_tri(a,b,c,tone)
	_tri(a,c,d,tone)


func _tri(a: Vector3,b: Vector3,c: Vector3,tone: StringName) -> void:
	if not shelf.has(tone):
		shelf[tone] = PackedVector3Array()
	shelf[tone].append_array([a,b,c])


func _finish() -> void:
	var structures := ArrayMesh.new()
	var path := ArrayMesh.new()
	for tone: StringName in shelf:
		var batch := SurfaceTool.new()
		batch.begin(Mesh.PRIMITIVE_TRIANGLES)
		var soil := tone in [&"track",&"apron"]
		for v: Vector3 in shelf[tone]:
			if soil:
				var control: float = faded[v]
				batch.set_color(Color(1,1,1,control))
			batch.add_vertex(v)
		batch.generate_normals()
		if soil:
			var track := ShaderMaterial.new()
			track.shader = preload("res://game/overworld/cairnspine/sova_opener_ground.gdshader")
			track.set_shader_parameter(&"tint",TONES[tone])
			track.set_shader_parameter(&"slate",tone==&"apron")
			batch.set_material(track)
			batch.commit(path)
		else:
			var pigment := ShaderMaterial.new()
			pigment.shader = ShaderDef
			pigment.set_shader_parameter(&"tint",TONES[tone])
			pigment.set_shader_parameter(&"fabric",tone in [&"canvas",&"canvas_wear"])
			batch.set_material(pigment)
			batch.commit(structures)
	for id: String in ["SheltersAndYard","NativeGravelSpur"]:
		var instance := MeshInstance3D.new()
		instance.name=id
		instance.mesh = structures if id == "SheltersAndYard" else path
		if instance.mesh == path:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(instance)
	art.set_meta(&"sova_support",support)
