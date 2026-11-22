extends RefCounted
## Private Year Three rescue art only. No colliders, ready/state setters, route,
## labels, actors or live line. Exact general-purpose harbor remains untouched.
const RECEIVER := Vector3(23.9,-.10,37.0)
const STRANDED := [Vector3(20.0,3.20,28.0),Vector3(25.0,3.12,27.92)]
const OFFSETS := [-8.3,-7.15,-5.30,-2.85,.0,3.18,5.86,7.40,8.24]
const HALVES := [.15,1.42,2.30,2.86,3.03,2.96,2.60,1.68,.13]
const SHEER := [2.37,2.09,1.96,1.89,1.79,1.84,2.07,2.50,2.93]
const FLOOR_PIGMENTS := ["#766047","#7c654b","#80694d","#866f52","#7a6349"]
var coast: Node3D
var bark: Material
var oak: Material
var trim: Material
var dark: Material
var cord: Material
var quarters: Array[Material] = []
var tint: Array[Material] = []
var station_options: Array[Material] = []

func build() -> Node3D:
	coast=Node3D.new()
	coast.name="YearThreeRescueDressingStudy"
	bark=_mat("#463c35")
	oak=_mat("#7e634c")
	trim=_mat("#bea178")
	dark=_mat("#302d29")
	cord=_mat("#c3a672")
	for c in FLOOR_PIGMENTS:
		quarters.append(_mat(c))
	for c in ["#2c3c39","#465a4c","#587365","#668375","#769580"]:
		tint.append(_mat(c))
	for c in ["#d6ad5d","#a1b7ac"]:
		station_options.append(_mat(c))
	_ship()
	for i in 2:
		_station(coast,STRANDED[i],station_options[i],false,i)
	return coast

func _ship() -> void:
	var boat:=Node3D.new()
	boat.name="ReceivingVessel"
	boat.position=RECEIVER
	coast.add_child(boat)
	for i in 5:
		var v:=PackedVector3Array()
		var lower:=float(i)*.2
		var upper:=lower+.20
		for sg in [-1.0,1.0]:
			for seg in range(OFFSETS.size()-1):
				var a:=_section(seg,lower,sg)
				var b:=_section(seg+1,lower,sg)
				var c:=_section(seg+1,upper,sg)
				var d:=_section(seg,upper,sg)
				if sg>0:
					v.append_array([a,b,c,a,c,d])
				else:
					v.append_array([a,c,b,a,d,c])
		_surface(boat,v,tint[i]).name="LapstrakeBand%d"%i
	for side in [-1.0,1.0]:
		for i in range(OFFSETS.size()-1):
			var a:=_section(i,1.0,side)
			var b:=_section(i+1,1.0,side)
			_beam(boat,a,b,.087,trim)
			for ratio in [.33,.68]:
				var ledge_a:=_section(i,ratio,side)
				var ledge_b:=_section(i+1,ratio,side)
				_beam(boat,ledge_a,ledge_b,.034,bark)
		for i in range(1,OFFSETS.size()-1):
			var at:=_section(i,.99,side)
			if side<0 and at.x>-5.4 and at.x<5.2:
				continue # leave the receiving side open at the two line stations
			_beam(boat,at,at+Vector3.UP*.37,.047,bark)
	# Staggered fore-to-aft deck planks, little pigment distance across seams.
	for row in 16:
		var zmid:=-2.70+float(row)*.358
		var half:=_long_span(absf(zmid)+.19)
		if half.x>=half.y:
			continue
		var edge:=half.x
		var u:=0
		var stagger:=1.95 if row%2==0 else .82
		while edge < half.y-.02:
			var tail:=minf(half.y,edge+(stagger if u==0 else 3.12 + sin(float(row+u))*.18))
			if tail-edge>.035:
				_box(boat,Vector3(tail-edge-.017,.09,.343),Vector3((edge+tail)*.5,1.37,zmid),
					quarters[(row*9+u*5+row%3+u*u)%5])
			edge=tail
			u+=1
	for side in [-1.0,1.0]:
		for idx in range(1,OFFSETS.size()-1):
			var rim:=_section(idx,.98,side)
			var foot:=Vector3(rim.x,1.37,rim.z*.75)
			_beam(boat,foot,rim-Vector3.UP*.10,.046,bark)
			_box(boat,Vector3(.29,.15,.09),foot.lerp(rim,.79),oak)
	var spine_a = Vector3(-8.16,.69,0)
	var spine_b = Vector3(-8.35,2.22,0)
	_beam(boat,spine_a,spine_b,.085,oak)
	_beam(boat,Vector3(7.62,.81,0),Vector3(8.3,2.65,0),.10,oak)
	# Idle receiving ship has furled canvas, not an invented distress signal.
	var mast:=Vector3(1.95,1.40,.27)
	var top:=mast+Vector3(.16,5.98,.06)
	_beam(boat,mast,top,.13,oak)
	var yard_a:=top+Vector3(-2.64,-.82,-.31)
	var yard_b:=top+Vector3(2.11,-.65,.37)
	_beam(boat,yard_a,yard_b,.075,oak)
	_beam(boat,yard_a+Vector3(0,-.085,0),yard_b+Vector3(0,-.105,0),.12,cord)
	for i in range(1,6):
		var at:=yard_a.lerp(yard_b,float(i)/6.0)
		_beam(boat,at+Vector3(0,.06,-.13),at+Vector3(.02,-.24,.12),.026,dark)
	for position: Vector3 in [Vector3(-4,1.68,-1.95),Vector3(-3.1,1.68,.79),Vector3(5.3,1.74,1.60)]:
		_beam(boat,top-Vector3.UP*.65,position,.023,cord)
	for x in [-5.75,4.72]:
		_box(boat,Vector3(.16,.24,3.33),Vector3(x,1.54,0.02),oak)
	var boxes: Array[Vector3]=[Vector3(-5.1,1.60,.8),Vector3(-4.5,1.66,1.42),Vector3(5.95,1.58,.47)]
	for j in boxes.size():
		_box(boat,Vector3(.56,.35+float(j%2)*.09,.46),boxes[j],quarters[j+1])
	for i in 2:
		var pick: Vector3=STRANDED[i]
		_station(boat,Vector3(pick.x-RECEIVER.x,1.43,-2.35),station_options[i],true,i)

func _section(i:int,t:float,side:float) -> Vector3:
	var radius: float=HALVES[i]
	var h:float=SHEER[i]
	var z := side*radius*lerpf(.23,1.0,smoothstep(0.0,.86,t))*lerpf(1.0,.91,smoothstep(.83,1.0,t))
	var k := -.70+(.17*absf(OFFSETS[i]))
	return Vector3(OFFSETS[i],lerpf(k,h,t),z)

func _long_span(z:float) -> Vector2:
	var low:=0.0
	var high:=0.0
	for i in range(4):
		if z >= HALVES[i]-.16 and z < HALVES[i+1]-.16:
			var t:=inverse_lerp(HALVES[i]-.16,HALVES[i+1]-.16,z)
			low=lerpf(OFFSETS[i],OFFSETS[i+1],t)
	for i in range(4,OFFSETS.size()-1):
		if z <= HALVES[i]-.16 and z > HALVES[i+1]-.16:
			var t:=inverse_lerp(HALVES[i]-.16,HALVES[i+1]-.16,z)
			high=lerpf(OFFSETS[i],OFFSETS[i+1],t)
	return Vector2(low,high)

func _station(base:Node3D,at:Vector3,marker:Material,receiver:bool,index:int) -> void:
	var n:=Node3D.new()
	n.name=("ReceiverFitting" if receiver else "TransferFitting") + ("Aft" if index==0 else "Forward")
	n.position=at
	base.add_child(n)
	_box(n,Vector3(.48,.105,.44),Vector3.ZERO,oak)
	_beam(n,Vector3.ZERO,Vector3(.015,.76,.02),.091,bark)
	_beam(n,Vector3(-.195,.57,0),Vector3(.195,.57,0),.074,trim)
	var post:=Vector3(.27,.0,.08 if receiver else -.08)
	_beam(n,post,post+Vector3(0,1.3,.0),.033,oak)
	var sign_v:=PackedVector3Array([post+Vector3(0,1.28,.0),post+Vector3(-.68,1.14,.12),post+Vector3(-.46,.94,.03)])
	_surface(n,sign_v,marker)
	# Slack coil on this deck only: there is deliberately no rope over the water.
	var coil:=PackedVector3Array()
	for i in 56:
		var z:=float(i)/55.0
		var angle:=z*TAU*2.5
		var rad:=lerpf(.095,.34,z)
		coil.append(Vector3(cos(angle)*rad-.33,.112+z*.021,sin(angle)*rad+(.44 if receiver else -.45)))
	_tube(n,coil,.026,cord)

func _tube(parent:Node3D,curve:PackedVector3Array,rad:float,mat:Material) -> void:
	var vs:=PackedVector3Array()
	for i in range(curve.size()-1):
		var a:=curve[i]
		var b:=curve[i+1]
		var along:Vector3=(b-a).normalized()
		var side:=along.cross(Vector3.UP).normalized()
		for j in 5:
			var p:=TAU*float(j)/5.0
			var q:=TAU*float(j+1)/5.0
			var d:Vector3=(side*cos(p)+Vector3.UP*sin(p))*rad
			var e:Vector3=(side*cos(q)+Vector3.UP*sin(q))*rad
			vs.append_array([a+d,b+d,b+e,a+d,b+e,a+e])
	_surface(parent,vs,mat)

func _surface(parent:Node3D,vs:PackedVector3Array,mat:Material) -> MeshInstance3D:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for p in vs:
		surface.add_vertex(p)
	surface.generate_normals()
	return _mount(parent,surface.commit(),Vector3.ZERO,mat)
func _box(parent:Node3D,dim:Vector3,at:Vector3,mat:Material) -> MeshInstance3D:
	var b:=BoxMesh.new()
	b.size=dim
	return _mount(parent,b,at,mat)
func _beam(parent:Node3D,a:Vector3,b:Vector3,r:float,mat:Material) -> void:
	var d:Vector3=b-a
	if d.length_squared()<.002:
		return
	var c:=CylinderMesh.new()
	c.radial_segments=7
	c.top_radius=r*.8
	c.bottom_radius=r
	c.height=d.length()
	_mount(parent,c,(a+b)*.5,mat).quaternion=Quaternion(Vector3.UP,d.normalized())
func _mount(parent:Node3D,mesh:Mesh,at:Vector3,mat:Material) -> MeshInstance3D:
	var m:=MeshInstance3D.new()
	m.mesh=mesh
	m.material_override=mat
	m.position=at
	parent.add_child(m)
	return m
func _mat(hex:String) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=Color(hex)
	m.roughness=.87
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m
