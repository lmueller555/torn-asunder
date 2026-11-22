extends RefCounted
## North-only, art geometry. No collision, traffic, water or gate ownership.
const MAT:=preload("res://game/overworld/raska/north_weather.gdshader")
const MIN_LANE:=4.7
const STONE:=Color("#958170")
const DARK:=Color("#5b5548")
const OLD_CAP:=Color("#b09c82")
const EARTH:=Color("#82745f")
const NORTH_WORK:=Vector2(-107,-64)
var rng:=RandomNumberGenerator.new()
var extent:Rect2
var anchor_count:=0
var footings:PackedVector3Array
var foot_misses:=0
var probe:PhysicsDirectSpaceState3D
var _stone:=SurfaceTool.new()
var _dirt:=SurfaceTool.new()
var _earth:=SurfaceTool.new()
var _plants:Dictionary={}
var _fol:=SphereMesh.new()
var _twig:=CylinderMesh.new()

func build(relief:Node3D)->Node3D:
	rng.seed=24133
	probe=relief.get_world_3d().direct_space_state
	_fol.radial_segments=6
	_fol.rings=3
	_twig.radial_segments=5
	_twig.top_radius=.035
	_twig.bottom_radius=.085
	_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	_earth.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three discontinuous landward dry-stone runs step away from the causeway.
	# Existing N route / feeder / apron remain physically and visually distinct.
	for tuple:Array in [[Vector2(-165,-58),Vector2(-134,-53),2],[Vector2(-103,-56),Vector2(-81,-48),2],
		[Vector2(-100,-66),Vector2(-80,-61),2],[Vector2(-92,-76),Vector2(-70,-69),1],
		[Vector2(-100,-66),Vector2(-104,-58),1],[Vector2(-92,-76),Vector2(-99,-66),1]]:
		retaining(relief,tuple[0],tuple[1],tuple[2])
	# Scuffed, fine-gravel approaches clothed in weathered earth, no hard white stripe.
	ribbon(relief,Vector2(-199,-47.7),Vector2(-133,-43.5),7.6)
	for zone:Array in [[Vector2(-178,-64),Vector2(31,13),29],[Vector2(-105,-66),Vector2(25,21),32],
		[Vector2(-142,-31),Vector2(25,9),22],[Vector2(-77,-66),Vector2(14,13),17],
		[Vector2(-208,-71),Vector2(24,17),22]]:
		plants(relief,zone[0],zone[1],zone[2])
	for s:int in range(58):
		var x:=rng.randf_range(-215,-58)
		var z:=rng.randf_range(-90,-23)
		var p:=Vector2(x,z)
		if not side_clear(relief,p,5.9): continue
		var g:float=record_footing(relief,p)
		chunk(_stone,Vector3(p.x,g-.09,p.y),Vector3(rng.randf_range(.28,.96),rng.randf_range(.15,.39),rng.randf_range(.23,.8)),rng.randf_range(-PI,PI),DARK.lerp(STONE,rng.randf()))
		anchor_count+=1
	var group:=Node3D.new()
	group.name=&"NorthCausewayDressing"
	finish(group,_stone,"DryReliefWork")
	finish(group,_earth,"NorthTerraceBanks",false)
	finish(group,_dirt,"WornApproachSurface",false)
	for label in _plants:
		var row:Array=_plants[label]
		batch(group,label,_twig if label=="Trunks" else _fol,row[0],row[1])
	return group

func side_clear(relief:Node3D,p:Vector2,m:=MIN_LANE)->bool:
	return p.y< -20.0 and relief._distance(p,relief.NORTH)>m and relief._distance(p,relief.FEEDER)>m+1.25 and relief.ground(p)>3.5

func retaining(relief:Node3D, a:Vector2,b:Vector2,rows:int)->void:
	var length:=a.distance_to(b)
	var axis:=(b-a).normalized()
	var ortho:=Vector2(axis.y,-axis.x)
	var yaw:=-axis.angle()
	var cells:=int(length/1.61)
	if length>16.: embankment(relief,a,b,rows,axis,ortho)
	for row in range(rows+1):
		for i in range(cells):
			# Broken segments, asymmetric returns and recessed joints.
			if (i%13==0 and row>0) or (i==cells-2 and row==rows): continue
			var offset:=.45+row*.39
			var p:=a+axis*(i*1.63 + offset+rng.randf_range(-.09,.09))+ortho*(row*.86)
			if not side_clear(relief,p,5.9): continue
			var gy:float=record_footing(relief,p)
			var col:=DARK.lerp(STONE,rng.randf_range(.49,.96))
			if row==rows: col=STONE.lerp(OLD_CAP,rng.randf_range(.22,.66))
			var h:=rng.randf_range(.50,.66) if row<rows else rng.randf_range(.36,.56)
			chunk(_stone,Vector3(p.x,gy-.25+row*.49,p.y),Vector3(rng.randf_range(1.47,1.76),h,rng.randf_range(.88,1.21)),yaw+rng.randf_range(-.065,.065),col)
			anchor_count+=1
	# Buried, irregular earth side widening, so top ledges are terraces not floating blocks.
	for i in range(cells-1):
		var p:=a+axis*((i+.52)*1.63)+ortho*.91
		if not side_clear(relief,p,6.25): continue
		var gy:float=record_footing(relief,p)
		chunk(_stone,Vector3(p.x,gy-.38,p.y),Vector3(1.67,.75,2.14),yaw,DARK.lerp(EARTH,.52))
		anchor_count+=1

func embankment(relief:Node3D,a:Vector2,b:Vector2,steps:int,axis:Vector2,ortho:Vector2)->void:
	var n:=int(a.distance_to(b)/1.9)
	var vertices:PackedVector3Array
	var pigments:PackedColorArray
	for i in range(n+1):
		var t:=i/float(n)
		var taper:=smoothstep(0.,.16,t)*(1.0-smoothstep(.84,1.,t))
		for j in range(6):
			var off:float=.61+steps*.75+j*.98
			var w:float=float(j)/5.
			var q:=a.lerp(b,t)+ortho*(off+sin(t*PI*2.0)*w*.66)+axis*.22
			var y:=record_footing(relief,q)
			var lift:float=(steps*.47+.10)*(1.0-smoothstep(.07,1.,w))*taper
			vertices.append(Vector3(q.x,y+lift+.043,q.y))
			var pigment:=Color("#766d59").lerp(Color("#536047"),w*.29+rng.randf_range(.06,.30))
			pigment.a=taper*(1.0-smoothstep(.64,1.0,w))*.88
			pigments.append(pigment.srgb_to_linear())
	for i in range(n):
		for j in range(5):
			var a0:=i*6+j
			for k in [a0,a0+6,a0+1,a0+1,a0+6,a0+7]:
				_earth.set_color(pigments[k])
				_earth.add_vertex(vertices[k])

func ribbon(relief:Node3D,a:Vector2,b:Vector2,width:float)->void:
	var dir:=(b-a).normalized()
	var cross:=Vector2(-dir.y,dir.x)
	var strips: Array[Vector3]=[]
	var colors:Array[Color]=[]
	var n:=int(a.distance_to(b)/1.65)
	for i in range(n+1):
		var t:=i/float(n)
		var pt:=a.lerp(b,t)
		var fade:=sin(t*PI)
		var swell:=width*(.58+.42*fade)+.31*sin(i*.57)
		for edge in [-1.,-.49,-.24,.0,.24,.51,1.]:
			var p:Vector2=pt+cross*float(edge)*swell*.5
			# Base road has no raised collision; local conforming overlay is cosmetic.
			var gy:float=record_footing(relief,p)
			strips.append(Vector3(p.x,gy+.095,p.y))
			var rut:float=.048 if absf(edge)>.2 and absf(edge)<.27 else 0.
			var c:=EARTH.darkened(rut).lerp(STONE,fade*.28)
			if absf(edge)>.9: c=c.lerp(Color("#716c52"),.47)
			c=c.lerp(DARK,rng.randf_range(.0,.12))
			c.a=(1.0-smoothstep(.43,1.,absf(edge)))*smoothstep(0.,.17,t)*(1.0-smoothstep(.75,1.,t))*.68
			colors.append(c)
	for row in range(n):
		for j in range(6):
			var i:=row*7+j
			for q in [i,i+1,i+7,i+1,i+8,i+7]:
				_dirt.set_color(colors[q].srgb_to_linear())
				_dirt.add_vertex(strips[q])

func chunk(surface:SurfaceTool,at:Vector3,size:Vector3,angle:float,c:Color)->void:
	var ring: Array[Vector2] = [Vector2(-.49,-.33),Vector2(-.30,-.50),Vector2(.32,-.49),Vector2(.49,-.32),
		Vector2(.48,.33),Vector2(.30,.49),Vector2(-.35,.48),Vector2(-.51,.25)]
	var t:=Basis(Vector3.UP,angle)
	var points: Array[Vector3]=[]
	for level:float in [0.,.22,.79,1.]:
		for p in ring:
			var taper:=.87 if level==0. or level==1. else 1.
			var pos:=Vector3(p.x*size.x*taper,level*size.y,p.y*size.z*taper)
			pos.y+=rng.randf_range(-.041,.041)
			points.append(at+t*pos)
	for rr in range(3):
		for i in range(8):
			var j:=(i+1)%8
			var pigment:=c.darkened(rng.randf_range(.0,.13)) if rr<2 else c.lightened(.035)
			for q in [rr*8+i,(rr+1)*8+i,rr*8+j,(rr+1)*8+i,(rr+1)*8+j,rr*8+j]:
				surface.set_color(pigment.srgb_to_linear())
				surface.add_vertex(points[q])
	for i in range(1,7):
		for v in [24,24+i,25+i]:
			surface.set_color(c.lightened(.045).srgb_to_linear())
			surface.add_vertex(points[v])

func plants(relief:Node3D,center:Vector2,half:Vector2,attempt:int)->void:
	for i in range(attempt):
		var p:=center+Vector2(rng.randf_range(-half.x,half.x),rng.randf_range(-half.y,half.y))
		if not side_clear(relief,p,6.7): continue
		var g:float=record_footing(relief,p)
		var h:=rng.randf_range(.30,1.22) if i%5 else rng.randf_range(1.27,2.82)
		var yaw:=rng.randf_range(0,TAU)
		var shade:String=["Juniper","DryBrush","TallScrub"][i%3]
		var tint:=Color("#575f42") if shade=="Juniper" else (Color("#777450") if shade=="DryBrush" else Color("#646a4e"))
		if h>1.25:
			add_plant("Trunks",Color("#665c47"),Vector3(p.x,g+h*.36,p.y),Vector3(h*.62,h*.79,h*.63),yaw)
		for leaf in range(2 if h<1.25 else 4):
			var phi:=yaw+leaf*2.51
			var r:=h*rng.randf_range(.09,.31)
			add_plant(shade,tint,Vector3(p.x+cos(phi)*r,g+h*(.36+.14*leaf),p.y+sin(phi)*r),
				Vector3(h*rng.randf_range(.32,.61),h*rng.randf_range(.31,.53),h*rng.randf_range(.30,.62)),phi)
		anchor_count+=1

func add_plant(key:String,tint:Color,p:Vector3,size:Vector3,angle:float)->void:
	if not _plants.has(key): _plants[key]=[[],tint]
	_plants[key][0].append(Transform3D(Basis(Vector3.UP,angle).scaled(size),p))

func batch(root:Node3D,key:String,mesh:Mesh,poses:Array,tint:Color)->void:
	var item:=MultiMeshInstance3D.new()
	item.name=key
	var batchmesh:=MultiMesh.new()
	batchmesh.mesh=mesh
	batchmesh.transform_format=MultiMesh.TRANSFORM_3D
	batchmesh.instance_count=poses.size()
	for i in range(poses.size()): batchmesh.set_instance_transform(i,poses[i])
	item.multimesh=batchmesh
	var pigment:=StandardMaterial3D.new()
	pigment.albedo_color=tint
	pigment.roughness=.94
	item.material_override=pigment
	root.add_child(item)

func finish(root:Node3D,surface:SurfaceTool,key:String,cast:=true)->void:
	surface.generate_normals()
	var draw:=MeshInstance3D.new()
	draw.name=key
	draw.mesh=surface.commit()
	var m:=ShaderMaterial.new()
	m.shader=MAT if cast else preload("res://game/overworld/raska/north_gravel.gdshader")
	# Isolated static triangles; no collision is authored.
	draw.material_override=m
	if not cast: draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(draw)


func record_footing(relief:Node3D,p:Vector2)->float:
	var y:float=relief.ground(p)
	var base:=Vector3(p.x,y,p.y)
	var seat:=probe.intersect_ray(PhysicsRayQueryParameters3D.create(base+Vector3.UP*4,base+Vector3.DOWN*4))
	if seat.is_empty() or seat.collider.get_parent().name!="BankRelief":
		foot_misses+=1
	else:
		base=seat.position
	footings.append(base)
	return base.y
