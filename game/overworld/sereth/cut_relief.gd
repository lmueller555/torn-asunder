extends Node3D
## Native overworld-scale interpretation, not the mission battlefield or a context approval.
const Ground := preload("res://game/overworld/sereth/cut_ground.gdshader")
const Landmarks := preload("res://game/overworld/sereth/cut_landmark_art.gd")
const X0 := -495.0
const Z0 := -353.0
const STEP := 3.0
const NX := 331
const NZ := 231
const ROUTE := [Vector2(-164,36),Vector2(-131,42),Vector2(-99,37),Vector2(-59,32),Vector2(-15,34),
	Vector2(25,30),Vector2(65,22),Vector2(98,23),Vector2(137,25)]
const CAMP := ROUTE[0]
const CUT := ROUTE[-1]
const MARK_Y := .25
var camera: Camera3D
var party: Node3D
var _painted: PackedVector2Array = []
var _grass := StandardMaterial3D.new()
var _slate := StandardMaterial3D.new()
var _ink := StandardMaterial3D.new()
var _timber := StandardMaterial3D.new()
var _mantle := StandardMaterial3D.new()

func _ready() -> void:
	camera=$Camera
	party=$Party
	_grass.albedo_color=Color("#3f5148")
	_grass.vertex_color_use_as_albedo=true
	_slate.albedo_color=Color("#696e6b")
	_ink.albedo_color=Color("#444843")
	_timber.albedo_color=Color("#5d4b40")
	_mantle.albedo_color=Color("#cec2a0")
	for m: StandardMaterial3D in [_grass,_slate,_ink,_timber,_mantle]:
		m.roughness=.93
	_painted=planar_route()
	_make_relief()
	_make_foliage()
	Landmarks.new().build(self)
	_pin_path()
	_marker()
	lens(CAMP, false)

static func planar_route() -> PackedVector2Array:
	var path:=Curve2D.new()
	for i in ROUTE.size():
		var tangent: Vector2=(ROUTE[mini(i+1,ROUTE.size()-1)]-ROUTE[maxi(0,i-1)])*.17
		path.add_point(ROUTE[i],-tangent if i>0 else Vector2.ZERO,
			tangent if i<ROUTE.size()-1 else Vector2.ZERO)
	path.bake_interval=1.0
	return path.get_baked_points()

static func terrain_height(x: float,z: float) -> float:
	var hill:=5.1*sin(x*.015+z*.021)+3.4*cos(x*.017-z*.024)+1.8*sin(x*.029+z*.034)+.38*sin(x*.23-z*.22)
	hill+=19.0*exp(-pow((z-119.0)/54.0,2.)-pow((x+88.)/166.,2.))
	hill+=23.0*exp(-pow((z+126.)/56.,2.)-pow((x-108.)/184.,2.))
	hill+=41.*exp(-pow((z+264.)/87.,2.)-pow((x+234.)/236.,2.))
	hill+=46.*exp(-pow((z+289.)/116.,2.)-pow((x-184.)/213.,2.))
	hill+=29.*exp(-pow((z-259.)/99.,2.)-pow((x+42.)/269.,2.))
	var width:=smoothstep(22.,79.,x)*(1.-smoothstep(169.,215.,x))
	var lower:=exp(-pow((z+18.+sin((x-88.)*.036)*4.)/13.,2.))
	hill-=width*lower*9.7
	hill+=width*7.2*smoothstep(-30.,-43.,z)*(1.-smoothstep(65.,92.,absf(z)))
	# Grade only the existing broad west/east approach. Feather to the unmodified grave bank.
	if x>CAMP.x-46. and x<CUT.x+48. and z>3. and z<73.:
		var c:float=CAMP.y
		for i in range(1,ROUTE.size()):
			var b:Vector2=ROUTE[i]
			var a:Vector2=ROUTE[i-1]
			c=b.y
			if x<b.x:
				c=lerpf(a.y,b.y,clampf(inverse_lerp(a.x,b.x,x),0.,1.))
				break
		var mix_weight:float=.83*(1.-smoothstep(7.,33.,absf(z-c))) \
			*smoothstep(CAMP.x-46.,CAMP.x-8.,x)*(1.-smoothstep(CUT.x+7.,CUT.x+48.,x))
		var subgrade:=4.2+3.1*sin(x*.014)+1.2*cos(x*.026)+.11*sin(z*.17+x*.15)
		hill=lerpf(hill,subgrade,mix_weight)
	return hill

static func surface_y(p:Vector2) -> float:
	var fx:float=(p.x-X0)/STEP
	var fz:float=(p.y-Z0)/STEP
	var i:=clampi(floori(fx),0,NX-2)
	var j:=clampi(floori(fz),0,NZ-2)
	var u:=clampf(fx-i,0.,1.)
	var v:=clampf(fz-j,0.,1.)
	var x:=X0+i*STEP
	var z:=Z0+j*STEP
	var a:=terrain_height(x,z)
	var b:=terrain_height(x+STEP,z)
	var c:=terrain_height(x,z+STEP)
	var d:=terrain_height(x+STEP,z+STEP)
	if v<=u:
		return a+(b-a)*u+(d-b)*v
	return a+(d-c)*u+(c-a)*v

static func at(p:Vector2,lift:=0.) -> Vector3:
	return Vector3(p.x,surface_y(p)+lift,p.y)

static func route_curve() -> Curve3D:
	var out:=Curve3D.new()
	out.bake_interval=.7
	for p in planar_route():
		out.add_point(at(p,MARK_Y))
	return out

func _road_distance(p:Vector2) -> float:
	if p.y<10. or p.y>54. or p.x<CAMP.x-25. or p.x>CUT.x+25.:
		return INF
	var near:=INF
	# The baked curve has about one point/metre; skips below terrain sample spacing.
	for q in range(0,_painted.size(),3):
		near=minf(near,p.distance_squared_to(_painted[q]))
	return sqrt(near)

func _make_relief() -> void:
	var surf:=SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material:=ShaderMaterial.new()
	material.shader=Ground
	surf.set_material(material)
	for j in NZ:
		for i in NX:
			var p:=Vector2(X0+i*STEP,Z0+j*STEP)
			var h:=terrain_height(p.x,p.y)
			var nearer:=_road_distance(p)
			var dist:=maxf(0.,p.x-138.)
			if dist>0. and absf(p.y-25.)<8.0:
				nearer=minf(nearer,absf(p.y-25.-sin(dist*.022)*5.))
			if p.x<CAMP.x:
				nearer=minf(nearer,absf(p.y-CAMP.y+sin((CAMP.x-p.x)*.024)*4.))
			var station:=1.-smoothstep(6.,14.,p.distance_to(CAMP+Vector2(-1.,-7.)))
			var road:=maxf(1.0-smoothstep(2.8,6.2,nearer),station*.53)
			var cut:=smoothstep(20.,83.,p.x)*(1.-smoothstep(167.,219.,p.x)) 				*exp(-pow((p.y+24.)/23.,2.))
			surf.set_color(Color(road,cut,0.,1.))
			surf.add_vertex(Vector3(p.x,h,p.y))
	for j in range(NZ-1):
		for i in range(NX-1):
			var o:=j*NX+i
			for q: int in [o,o+1,o+NX+1,o,o+NX+1,o+NX]:
				surf.add_index(q)
	surf.generate_normals()
	var result:=MeshInstance3D.new()
	result.name="SlateRelief"
	result.mesh=surf.commit()
	add_child(result)
	result.create_trimesh_collision()
	for child in result.get_children():
		if child is StaticBody3D:
			child.collision_layer=2
			child.collision_mask=0

func _make_foliage() -> void:
	var rand:=RandomNumberGenerator.new()
	rand.seed=973133
	var where:Array[Transform3D]=[]
	var rocks:Array[Transform3D]=[]
	var bare:Array[Transform3D]=[]
	var varied:Array[Transform3D]=[]
	for z in range(-326,306,7):
		for x in range(-466,466,7):
			var p:=Vector2(x+rand.randf_range(-2.3,2.3),z+rand.randf_range(-2.3,2.3))
			var road:=_road_distance(p)
			if (p.x<CAMP.x or p.x>CUT.x) and absf(p.y-34.)<10. or road<8.0 					or p.distance_to(CAMP+Vector2(0,-7))<32. or p.distance_to(Vector2(116,4))<37.:
				continue
			var density:=.13+.18*(.5+.5*cos(x*.029+z*.031))+.16*smoothstep(50.,105.,absf(float(z)))
			var toss:=rand.randf()
			if toss<density:
				var s:=rand.randf_range(.47,1.59)
				var t:=Transform3D(Basis(Vector3.UP,rand.randf()*TAU).scaled(Vector3.ONE*s),at(p))
				if toss<.032:
					bare.append(t)
				elif int((x+z)*2.3)%4==0:
					varied.append(t)
				else:
					where.append(t)
			elif toss> .951:
				var s:=rand.randf_range(.30,1.0)
				rocks.append(Transform3D(Basis(Vector3.UP,rand.randf()*TAU).scaled(Vector3.ONE*s),at(p,.06)))
	var tree:=CylinderMesh.new()
	tree.top_radius=.17
	tree.bottom_radius=1.27
	tree.height=2.75
	tree.radial_segments=7
	tree.material=_grass
	var high:=CylinderMesh.new()
	high.top_radius=.035
	high.bottom_radius=.88
	high.height=2.9
	high.radial_segments=7
	high.material=_grass
	var middle:=CylinderMesh.new()
	middle.top_radius=.14
	middle.bottom_radius=1.03
	middle.height=2.65
	middle.radial_segments=7
	middle.material=_grass
	var scrub:=SphereMesh.new()
	scrub.radius=1.20
	scrub.height=1.70
	scrub.radial_segments=6
	scrub.rings=4
	scrub.material=_grass
	var trunk:=CylinderMesh.new()
	trunk.top_radius=.08
	trunk.bottom_radius=.14
	trunk.height=2.1
	trunk.radial_segments=6
	trunk.material=_timber
	var rock:=SphereMesh.new()
	rock.radius=1.2
	rock.height=1.60
	rock.radial_segments=7
	rock.rings=3
	rock.material=_slate
	_batch(&"SlateScree",rock,rocks,.12)
	_batch(&"MoorFirLower",tree,where,1.85)
	_batch(&"MoorFirMid",middle,where,2.50)
	_batch(&"MoorFirUpper",high,where,3.52)
	_batch(&"MoorTrunks",trunk,where,.93)
	_batch(&"WinterStems",trunk,bare,.97)
	_batch(&"WindHeather",scrub,varied,.49)

func _batch(label:StringName,mesh:Mesh,frames:Array[Transform3D],lift:float) -> void:
	var count:=frames.size()
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=mesh
	multi.instance_count=count
	for i in count:
		var t:=frames[i]
		t.origin.y+=lift*t.basis.get_scale().y
		multi.set_instance_transform(i,t)
		var k:=.74+.30*(.5+.5*sin(float(i)*3.127+t.origin.x*.02))
		multi.set_instance_color(i,Color(k,k,k,1.))
	var n:=MultiMeshInstance3D.new()
	n.name=label
	n.multimesh=multi
	add_child(n)

func _pin_path() -> void:
	var pins:=CylinderMesh.new()
	pins.top_radius=.49
	pins.bottom_radius=.58
	pins.height=.22
	pins.radial_segments=8
	var bead_material:=StandardMaterial3D.new()
	bead_material.albedo_color=Color("#73846e")
	bead_material.roughness=.93
	pins.material=bead_material
	var dots:Array[Transform3D]=[]
	for j in range(5,_painted.size()-5,8):
		dots.append(Transform3D(Basis.IDENTITY,at(_painted[j],.21)))
	_batch(&"SurveyPins",pins,dots,0.)

func _marker() -> void:
	var disk:=CylinderMesh.new()
	disk.top_radius=2.4
	disk.bottom_radius=2.4
	disk.height=.12
	disk.radial_segments=20
	disk.material=_ink
	var pad:=MeshInstance3D.new()
	pad.mesh=disk
	pad.position.y=.06
	party.add_child(pad)
	var edge:=CylinderMesh.new()
	edge.top_radius=1.63
	edge.bottom_radius=1.63
	edge.height=.24
	edge.material=_mantle
	var brass:=MeshInstance3D.new()
	brass.mesh=edge
	brass.position.y=.25
	party.add_child(brass)

func lens(anchor:Vector2,detail:bool,transit:=false) -> void:
	var point:=at(anchor)
	var aim:=point+Vector3(0,0,-9)
	if not detail and not transit:
		aim=Vector3(-15.,0,21.)
		camera.position=aim+Vector3(14.,283.,221.)
	elif transit:
		camera.position=aim+Vector3(-13.,83.,132.)
	elif anchor.distance_to(CUT)<2.:
		aim=at(Vector2(116.,-8.))
		camera.position=aim+Vector3(-45.,45.,64.)
	else:
		aim=point+Vector3(1.,0.,-9.)
		camera.position=aim+Vector3(-14.,48.,64.)
	camera.look_at(aim,Vector3.UP)
