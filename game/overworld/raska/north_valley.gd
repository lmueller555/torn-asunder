extends RefCounted
## Cosmetic valley batches. No collision, gate, routing or save references.
const Ground:=preload("res://game/overworld/raska/north_valley_ground.gdshader")
var rng:=RandomNumberGenerator.new()
var space:PhysicsDirectSpaceState3D
var branches:Array[Transform3D]=[]
var canopy_a:Array[Transform3D]=[]
var canopy_b:Array[Transform3D]=[]
var reeds:Array[Transform3D]=[]
var copses:Array[Transform3D]=[]
var warded:int=0
var seats:=0
var minimum_height:=INF
var clear_min:=INF

func mount(site:Node3D)->Node3D:
	rng.seed=31273
	space=site.get_world_3d().direct_space_state
	# Existing neutral shader remains unmodified, only swap ground in this isolated view.
	var land:=site.get_node("BankRelief") as MeshInstance3D
	var pigment:=ShaderMaterial.new()
	pigment.shader=Ground
	land.material_override=pigment
	var horizon:=site.get_node_or_null("WeatheredHorizon") as MeshInstance3D
	if horizon:
		var hills:=StandardMaterial3D.new()
		hills.albedo_color=Color("#47594e")
		hills.roughness=.97
		horizon.material_override=hills
	for cr:Array in [[-173.,43.,33],[-94.,32.,27],[-17.,42.,42],[77.,54.,33],[161.,58.,39],[-221.,27.,24]]:
		bank_bands(site,cr[0],cr[1],cr[2])
	for cl:Array in [[Vector2(-176,-119),Vector2(38,24),27],[Vector2(-137,-151),Vector2(54,17),29],
		[Vector2(-16,-119),Vector2(40,28),35],[Vector2(80,-142),Vector2(45,26),32],[Vector2(142,-114),Vector2(32,25),25],
		[Vector2(-209,-173),Vector2(24,35),18],[Vector2(222,-129),Vector2(35,26),28],[Vector2(39,-183),Vector2(74,30),37]]:
		upland(site,cl[0],cl[1],cl[2])
	var node:=Node3D.new()
	node.name=&"RaskaNorthValleyContext"
	var ball:=SphereMesh.new()
	ball.radial_segments=7; ball.rings=4
	var taper:=CylinderMesh.new()
	taper.radial_segments=6; taper.top_radius=.1; taper.bottom_radius=.44
	batch(node,"WillowBoughs",taper,branches,Color("#484639"))
	batch(node,"WillowCanopy",ball,canopy_a,Color("#53664b"))
	batch(node,"BankUnderstory",ball,canopy_b,Color("#7a8054"))
	batch(node,"UplandWoodland",ball,copses,Color("#445b47"))
	batch(node,"DryReeds",fine_reeds(),reeds,Color("#928357"))
	return node

func bank_bands(site:Node3D,cent:float,spread:float,attempt:int)->void:
	for i in range(attempt):
		var x:=cent+rng.randf_range(-spread,spread)
		var shore:float=site.center(x)-site.width_(x)*rng.randf_range(1.06,1.61)
		var p:=Vector2(x,shore)
		var got:=try_foot(site,p,7.5,1.55)
		if not got.is_finite(): continue
		if i%7==0:
			var h:=rng.randf_range(3.8,7.0)
			willow(got,h)
		elif i%3==0:
			for k in range(3):
				var spread_a:=Vector3(rng.randf_range(-.55,.55),rng.randf_range(.23,.48),rng.randf_range(-.44,.44))
				var scale_r:=rng.randf_range(.41,1.16)
				canopy_b.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(scale_r,.42+scale_r*.18,scale_r*.85)),got+spread_a))
		else:
			var scale_r:=rng.randf_range(.49,1.5)
			reeds.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(scale_r,rng.randf_range(.66,1.58),scale_r)),got))

func upland(site:Node3D,c:Vector2,extent:Vector2,attempt:int)->void:
	for i in range(attempt):
		var p:=c+Vector2(rng.randf_range(-extent.x,extent.x),rng.randf_range(-extent.y,extent.y))
		var g:=try_foot(site,p,13.0,4.9)
		if not g.is_finite(): continue
		var h:=rng.randf_range(2.4,7.7)
		var yaw:=rng.randf_range(0,TAU)
		for k in [0,1]:
			var d:=Vector3(cos(yaw+k*2.82),0,sin(yaw+k*2.82))*h*.20
			var l:=Vector3(h*.51,h*rng.randf_range(.69,1.16),h*.50)
			copses.append(Transform3D(Basis(Vector3.UP,yaw).scaled(l),g+d+Vector3.UP*(h*(.38+k*.06))))

func try_foot(site:Node3D,p:Vector2,shoulder:float,min_y:float)->Vector3:
	if p.y>=-14. or site._distance(p,site.NORTH)<shoulder or site._distance(p,site.FEEDER)<shoulder or p.distance_to(site.WHEEL)<25. or p.distance_to(Vector2(-100,-63))<17.:
		warded+=1
		return Vector3.INF
	var a:=Vector3(p.x,110,p.y)
	var result:=space.intersect_ray(PhysicsRayQueryParameters3D.create(a,a+Vector3.DOWN*140))
	if result.is_empty() or result.collider.get_parent().name!="BankRelief" or result.position.y<min_y or result.normal.y<.65:
		return Vector3.INF
	seats+=1
	minimum_height=minf(minimum_height,result.position.y)
	clear_min=minf(clear_min,site._distance(p,site.NORTH))
	return result.position

func willow(at:Vector3,h:float)->void:
	var angle:=rng.randf_range(0,TAU)
	var lean:=Vector3(cos(angle),0,sin(angle))*.27*h
	var root:=at+Vector3.DOWN*.08
	var top:=root+Vector3.UP*h*.72+lean
	stem(root,top,h*.21)
	for k in range(7):
		var th:=angle+k*2.4
		var twig:=Vector3(cos(th),0,sin(th))*h*rng.randf_range(.16,.39)
		var y:=h*rng.randf_range(.77,1.04)
		var tip:=root+lean*.67+twig+Vector3.UP*y
		stem(root.lerp(top,rng.randf_range(.51,.78)),tip,h*rng.randf_range(.045,.071))
		var sag:=tip+Vector3.DOWN*h*rng.randf_range(.08,.23)
		var l:=Vector3(h*rng.randf_range(.45,.71),h*rng.randf_range(.43,.66),h*rng.randf_range(.43,.60))
		var pose:=Transform3D(Basis(Vector3.UP,th).scaled(l),sag)
		if k%4==1: canopy_b.append(pose)
		else: canopy_a.append(pose)

func stem(a:Vector3,b:Vector3,d:float)->void:
	var up:=(b-a).normalized()
	var x:=up.cross(Vector3.FORWARD).normalized()
	if x.is_zero_approx(): x=up.cross(Vector3.RIGHT).normalized()
	var z:=x.cross(up).normalized()
	branches.append(Transform3D(Basis(x*d,up*a.distance_to(b),z*d),(a+b)*.5))

func fine_reeds()->Mesh:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a:=float(i)*2.3999
		var bend:=Vector3(cos(a),0,sin(a))
		var cross:=Vector3(-bend.z,0,bend.x)
		var p:=bend*.13
		var mid:=p+bend*(.20+float(i)*.031)+Vector3.UP*(.35+float(i)*.038)
		var tip:=mid+bend*.31+Vector3.UP*(.39+float(i)*.027)
		for v:Vector3 in [p+cross*.06,p-cross*.06,mid-cross*.034,p+cross*.06,mid-cross*.034,mid+cross*.034,mid+cross*.034,mid-cross*.034,tip]:
			s.add_vertex(v)
	s.generate_normals()
	return s.commit()

func batch(root:Node3D,name_:String,mesh:Mesh,poses:Array[Transform3D],tint:Color)->void:
	var oi:=MultiMeshInstance3D.new()
	oi.name=name_
	var m:=MultiMesh.new()
	m.transform_format=MultiMesh.TRANSFORM_3D
	m.use_colors=true
	m.mesh=mesh
	m.instance_count=poses.size()
	for i in range(poses.size()):
		m.set_instance_transform(i,poses[i])
		m.set_instance_color(i,Color.WHITE.darkened(rng.randf_range(.01,.19)))
	oi.multimesh=m
	var shade:=StandardMaterial3D.new()
	shade.albedo_color=tint
	shade.vertex_color_use_as_albedo=true
	shade.cull_mode=BaseMaterial3D.CULL_DISABLED if name_=="DryReeds" else BaseMaterial3D.CULL_BACK
	shade.roughness=.94
	oi.material_override=shade
	if name_ in ["DryReeds","UplandWoodland"]: oi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(oi)
