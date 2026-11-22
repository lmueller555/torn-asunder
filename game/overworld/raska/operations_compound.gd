extends RefCounted
## Low dry works only; this art group owns no action, triggers, profile, or route.
const OCHRE:=Color("#a9876b")
const ASH:=Color("#877866")
const RIM:=Color("#947a62")
const JOINT:=Color("#665744")
const WALK_GUARD:=3.6
const C:=Vector2(40,24.2)
var rng:=RandomNumberGenerator.new()
var space:PhysicsDirectSpaceState3D
var pads:=SurfaceTool.new()
var stone:=SurfaceTool.new()
var sample_count:=0
var missed:=0
var barrier_count:=0
var route_clearance:=INF
var max_cell_support_delta:=0.0
var min_wash_clearance:=INF

func mount(basin:Node3D)->Node3D:
	rng.seed=177642
	space=basin.get_world_3d().direct_space_state
	pads.begin(Mesh.PRIMITIVE_TRIANGLES)
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	grade(basin,C,Vector2(21.3,17.2),.10)
	flagstones(basin)
	# Two shoulder runs and a staggered low stone return make one perimeter.
	# The west camp track and damp-free dry wash stay open and unchanged.
	for row:Array in [[Vector2(22,22),Vector2(27,12),.91],
		[Vector2(27,12),Vector2(42,9),.89],[Vector2(42,9),Vector2(55,13),.92],
		[Vector2(55,13),Vector2(60,24),.81],[Vector2(60,24),Vector2(58,35),.91],
		[Vector2(58,35),Vector2(49,41),.83],[Vector2(49,41),Vector2(34,41),.88],
		[Vector2(34,41),Vector2(26,38),.77],[Vector2(26,38),Vector2(23,36),.67]]:
		wall(basin,row[0],row[1],row[2])
	var view:=Node3D.new()
	view.name=&"BasinOperationsHardscape"
	commit(view,pads,"WeatheredCampFootprint",preload("res://game/overworld/raska/compound_surface.gdshader"),false)
	commit(view,stone,"ShallowTerracedStonework",preload("res://game/overworld/raska/compound_stone.gdshader"),true)
	return view

func footing(basin:Node3D,p:Vector2)->Vector3:
	var g:Vector3=basin.world(p)
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(g+Vector3.UP*8,g+Vector3.DOWN*8))
	if hit.is_empty() or hit.collider.get_parent()!=basin.terrain:
		missed+=1
		return g
	sample_count+=1
	max_cell_support_delta=maxf(max_cell_support_delta,absf(hit.position.y-g.y))
	return hit.position

func grade(basin:Node3D,c:Vector2,radius:Vector2,raise_:float)->void:
	var verts:PackedVector3Array
	var tone:PackedColorArray
	const RINGS:=14
	const STRIPS:=80
	for i in range(RINGS+1):
		var u:=i/float(RINGS)
		for j in range(STRIPS+1):
			var a:=TAU*j/STRIPS
			var k:=u*(1.0+.043*sin(a*5.)+.043*sin(a*8.+.9))
			var p:=c+Vector2(cos(a)*radius.x,sin(a)*radius.y)*k
			var g:=footing(basin,p)
			var pad_col:=ASH.lerp(OCHRE,.51+.16*cos(a*2.)+.16*rng.randf())
			var xz:=Vector2(g.x,g.z)
			var driveway:float=1.-smoothstep(.4,3.8,basin.distance_to_course(xz))
			pad_col=pad_col.lerp(Color("#b29b79"), driveway*.45)
			pad_col.a=.79*(1.0-smoothstep(.68,1.0,u))
			verts.append(g+Vector3.UP*(.065+raise_*(1.0-u)))
			tone.append(pad_col.srgb_to_linear())
	for i in range(RINGS):
		for j in range(STRIPS):
			var a:=i*(STRIPS+1)+j
			var b:=a+STRIPS+1
			for k in [a,a+1,b,a+1,b+1,b]:
				pads.set_color(tone[k])
				pads.add_vertex(verts[k])

func flagstones(basin:Node3D)->void:
	# Rustic dry-laid hardstand under/from the operations approach, not a road across the desert.
	for row in range(8):
		for col in range(9):
			if (row<2 and col in [0,1,8]) or (row>=6 and col in [0,8]) or (row+col*2)%17==0: continue
			var x:=32.1+col*1.28+(row%2)*.43+rng.randf_range(-.10,.10)
			var z:=26.1+row*1.15+rng.randf_range(-.08,.08)
			var q:=Vector2(x,z)
			var p:=footing(basin,q)
			var pigment:=OCHRE.lerp(Color("#c0a98a"),rng.randf_range(.26,.81))
			block(p+Vector3.DOWN*.11,Vector3(rng.randf_range(1.22,1.5),.32,rng.randf_range(.99,1.18)),rng.randf_range(-.13,.15),pigment)
	# Short tumbled stone apron noses are outside the entrance road centre.
	for i in range(5):
		var q:=Vector2(31.4-i*.69,35.0+i*.21)
		var p:=footing(basin,q)
		block(p+Vector3.DOWN*.15,Vector3(.81,.24,.94),.1*i,ASH.lerp(OCHRE,.48))

func wall(basin:Node3D,a:Vector2,b:Vector2,h:float)->void:
	var delta:=(b-a).normalized()
	var cross:=Vector2(-delta.y,delta.x)
	var count:=int(a.distance_to(b)/1.48)
	var direction:=-delta.angle()
	for row:int in [0,1]:
		for i in range(count):
			var p:=a+delta*(1.48*i+.38+row*.23)+cross*(row*.17)
			if i%7==4 and row==1: continue
			var clearance:float=basin.distance_to_course(p)
			var wash:float=absf(p.x-basin.river_center(p.y))
			# Centerline guard includes wall footprint radius; no high obstacles.
			if clearance<WALK_GUARD or wash<19.: continue
			route_clearance=minf(route_clearance,clearance)
			min_wash_clearance=minf(min_wash_clearance,wash)
			var q:=footing(basin,p)
			var tint:=JOINT.lerp(RIM,rng.randf_range(.68,.92)) if row==0 else RIM.lerp(OCHRE,rng.randf_range(.27,.87))
			var width:=rng.randf_range(1.38,1.52)
			var thick:=rng.randf_range(1.03,1.28) - row*.25
			block(q+Vector3.UP*(-.21+row*h*.43),Vector3(width,h*.66,thick),direction+rng.randf_range(-.075,.075),tint)
			barrier_count+=1

func block(at:Vector3,size:Vector3,yaw:float,tint:Color)->void:
	var eight: Array[Vector2]=[Vector2(-.50,-.30),Vector2(-.33,-.50),Vector2(.31,-.48),Vector2(.51,-.32),
		Vector2(.50,.29),Vector2(.28,.51),Vector2(-.31,.49),Vector2(-.52,.31)]
	var points:PackedVector3Array
	var rot:=Basis(Vector3.UP,yaw)
	for y:float in [0.,.22,.80,1.]:
		for q:Vector2 in eight:
			var inset:=.89 if y==0.0 or y==1.0 else 1.0
			points.append(at+rot*Vector3(q.x*size.x*inset,y*size.y+rng.randf_range(-.045,.045),q.y*size.z*inset))
	for row in range(3):
		var a:=row*8
		for i in range(8):
			var k:=(i+1)%8
			for v in [a+i,a+i+8,a+k,a+k,a+i+8,a+k+8]:
				stone.set_color(tint.darkened(.11 if row==0 else .03).srgb_to_linear())
				stone.add_vertex(points[v])
	for i in range(1,7):
		for v in [24,24+i,25+i]:
			stone.set_color(tint.lightened(.04).srgb_to_linear())
			stone.add_vertex(points[v])

func commit(root:Node3D,s:SurfaceTool,key:String,program:Shader,cast:bool)->void:
	s.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name=key
	mesh.mesh=s.commit()
	var style:=ShaderMaterial.new()
	style.shader=program
	mesh.material_override=style
	if not cast: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
