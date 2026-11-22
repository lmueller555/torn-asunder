extends RefCounted
## Original weathered public court: built into the shelf, oriented to the open
## walking route, unoccupied. No lectern, signal, inscription or story result.
const Pigment := preload("res://game/overworld/cairnspine/sova_assembly_stone.gdshader")
const STONE := Color("#908779")
const CAP := Color("#afaa97")
const PAVING := Color("#82796b")
var soil: Callable
var center := Vector2.ZERO
var surface := SurfaceTool.new()
var contacts := PackedVector3Array()
var wall_contacts := 0


static func make(at: Callable, where: Vector2) -> MeshInstance3D:
	var b := new()
	b.soil=at
	b.center=where
	b.surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	b._courtyard()
	b.surface.generate_normals()
	var mat:=ShaderMaterial.new()
	mat.shader=Pigment
	b.surface.set_material(mat)
	var node:=MeshInstance3D.new()
	node.name="OpenAssemblyCourt"
	node.mesh=b.surface.commit()
	node.set_meta(&"court_footing",b.contacts)
	node.set_meta(&"court_wall_contacts",b.wall_contacts)
	return node


func _courtyard() -> void:
	# An open low horseshoe of fitted stones, with tall bonded end-piers
	# adjacent to the west mouth. Paths leave the court unblocked both ways.
	for side: float in [-1.0,1.0]:
		for i in range(18):
			var t:=float(i)/17.0
			var a:=lerpf(.28,2.88,t)
			var p:=center+Vector2(cos(a)*14.0,sin(a)*10.05*side)
			var yaw:=-atan2(cos(a)*side*10.05,-sin(a)*14.0)
			var key:=i*19.37+side*4.0
			var base:=_ground(p)
			var front:=sin(PI*t)
			_block(base,Vector3(2.38, .74+front*.25, 2.1+cos(key)*.19),yaw,key,STONE)
			_block(base+Vector3.UP*(.56+front*.20),Vector3(2.39,.44,1.84+sin(key)*.19),yaw+.032,key+2.3,CAP if i%3 else STONE)
			if i%3==1:
				var return_at:=p+Vector2(.0,side)*1.32
				_block(_ground(return_at),Vector3(1.48,.47+front*.31,1.67),yaw+.08,key+3.5,STONE.darkened(.12))
		for pier in [Vector2(-13.0,side*2.68),Vector2(13.2,side*2.67)]:
			var p:=_ground(center+pier)
			_block(p,Vector3(2.4,1.20,2.83),.14*side,side+4.6,STONE.darkened(.08))
			_block(p+Vector3.UP*.93,Vector3(1.94,.70,2.32),.18*side,side+2.1,STONE)
			_block(p+Vector3.UP*1.45,Vector3(2.1,.33,2.57),.19*side,side+5.8,CAP)
	wall_contacts = contacts.size()
	# Irregular worn flagstones in offset courses; the walk axis is read as
	# continuous fitted pavement, not spaced dots or an objective diagram.
	for row in range(-4,5):
		for col in range(-9,10):
			var x:=col*1.29+(0.56 if row%2 else 0.0)
			var z:=row*1.23+sin(col*.99+row*.17)*.19
			var spread:=Vector2(x/13.4,z/6.24)
			if spread.length()>1.03 or (absi(row)>2 and (row*13+col*11)%9==1):
				continue
			var phase:=col*1.78+row*3.38
			var p:=_ground(center+Vector2(x,z))
			var w:=Vector3(1.29+cos(phase)*.13,.12+cos(phase*.69)*.025,1.21+sin(phase)*.17)
			_block(p-Vector3.UP*.025,w,.11*sin(phase),phase,PAVING.lightened(.14*absf(sin(phase))))


func _ground(xz: Vector2) -> Vector3:
	var p: Vector3=soil.call(xz)
	contacts.append(p)
	return p


func _block(base: Vector3,s: Vector3,yaw: float,key: float,pigment: Color) -> void:
	var bottom:=PackedVector3Array()
	var breast:=PackedVector3Array()
	var cap:=PackedVector3Array()
	var k:=.75+cos(key*1.73)*.059
	for q: Vector2 in [Vector2(-k,-1),Vector2(k,-1),Vector2(1,-k),Vector2(1,k),Vector2(k,1),Vector2(-k,1),Vector2(-1,k),Vector2(-1,-k)]:
		var local:=Vector2(q.x*s.x,q.y*s.z)*.50
		var tier:=float(bottom.size())
		local*=1.0+.045*sin(tier*2.63+key)
		var horizontal:=Vector3(local.x,0,local.y).rotated(Vector3.UP,yaw)
		bottom.append(base+horizontal*.88-Vector3.UP*minf(.18,s.y*.50))
		breast.append(base+horizontal+Vector3.UP*s.y*.29)
		cap.append(base+horizontal*(.88+sin(tier*1.7+key)*.043)+Vector3.UP*s.y*(.87+cos(tier*1.87+key)*.08))
	for i in range(8):
		var j:=(i+1)%8
		var col:=pigment.darkened(.14+.08*sin(i*1.5+key))
		_triangle(bottom[i],breast[i],breast[j],col)
		_triangle(bottom[i],breast[j],bottom[j],col)
		_triangle(breast[i],cap[i],cap[j],col.lightened(.06))
		_triangle(breast[i],cap[j],breast[j],col.lightened(.06))
		_triangle(cap[i],base+Vector3.UP*s.y*.95,cap[j],pigment.lightened(.08))


func _triangle(a: Vector3,b: Vector3,c: Vector3,tone: Color) -> void:
	surface.set_color(tone.srgb_to_linear())
	for v in [a,b,c]:
		surface.add_vertex(v)
