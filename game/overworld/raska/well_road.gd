extends Node3D
## Original overworld relief: shares design geography, not a tactical transform.
const WEST:=Vector2(-125,0)
const EAST:=Vector2(128,0)
const UPPER:=Vector2(-92,-16)
const LOWER:=Vector2(-91,29)
const WASH_PATH:=[Vector2(-114,8),Vector2(-98,28),Vector2(-70,43),Vector2(-44,58),Vector2(-12,49),Vector2(13,60),Vector2(44,43),Vector2(70,51),Vector2(91,30),EAST]
const WASH_LEVEL:=[.0,-4.8,-5.0,-5.1,-4.8,-5.0,-5.1,-4.8,-4.7,.0]
var west_ground:=Vector3.INF
var east_ground:=Vector3.INF
var terrain:MeshInstance3D
var noise:=FastNoiseLite.new()
var grain:=FastNoiseLite.new()
var rng:=RandomNumberGenerator.new()
var landscape:=ShaderMaterial.new()
var oak:StandardMaterial3D
var reed:StandardMaterial3D
var sandstone:StandardMaterial3D
var dark:StandardMaterial3D
var tile:StandardMaterial3D
var iron:StandardMaterial3D

func prepare_exact_land()->bool:
	if terrain: return west_ground.is_finite() and east_ground.is_finite()
	noise.seed=49334
	noise.frequency=.035
	grain.seed=5332
	grain.frequency=.23
	landscape.shader=preload("res://game/overworld/raska/landscape.gdshader")
	make_ground()
	var floor_probe:=preload("res://game/overworld/raska/seam_floor.gd")
	west_ground=floor_probe.foot(terrain.mesh,WEST)
	east_ground=floor_probe.foot(terrain.mesh,EAST)
	return west_ground.is_finite() and east_ground.is_finite()

func _ready()->void:
	if not prepare_exact_land(): return
	rng.seed=90378
	oak=material("#604533"); reed=material("#87714e"); sandstone=material("#8b735e")
	dark=material("#362c24"); tile=material("#825b3d"); iron=material("#493b36")
	light_sector()
	terrain.create_trimesh_collision()
	build_compound()
	set_camera(false)
	_prepare_context()


func radius(x:float,z:float,cx:float,cz:float,rx:float,rz:float)->float:
	return Vector2((x-cx)/rx,(z-cz)/rz).length() + noise.get_noise_2d(x,z)*.17

func profile(x:float,z:float)->Vector2:
	var gap:=10000.0
	var level:=0.0
	var q:=Vector2(x,z)
	for i in range(WASH_PATH.size()-1):
		var a:Vector2=WASH_PATH[i]
		var b:Vector2=WASH_PATH[i+1]
		var t:=Geometry2D.get_closest_point_to_segment(q,a,b)
		var d:=q.distance_to(t)
		if d<gap:
			gap=d
			level=lerpf(WASH_LEVEL[i],WASH_LEVEL[i+1],a.distance_to(t)/a.distance_to(b))
	return Vector2(gap,level)

func height(p:Vector2)->float:
	var x:=p.x
	var z:=p.y
	var h:=noise.get_noise_2d(x,z)*1.7
	for mesa:Vector4 in [Vector4(-122,-76,65,49),Vector4(-29,-77,43,49),Vector4(61,-93,54,56),Vector4(148,-73,56,44),Vector4(-141,124,48,48),Vector4(-21,150,79,57),Vector4(111,127,71,47),Vector4(195,61,46,70)]:
		var d:=radius(x,z,mesa.x,mesa.y,mesa.z,mesa.w)
		h+=pow(1.0-smoothstep(.45,1.03,d),1.65)*(32.0+mesa.z*.43)*(.45 if mesa.y>95 else 1.0)
	var w:=profile(x,z)
	if absf(x)<155.0:
		h=lerpf(h,.1+grain.get_noise_2d(x,z)*.065,1.0-smoothstep(5.,13.,absf(z)))
		h=lerpf(h,w.y+grain.get_noise_2d(x,z)*.07,1.0-smoothstep(3.8,11.,w.x))
	for yard:Vector2 in [UPPER,LOWER]:
		var d:=p.distance_to(yard)
		h=lerpf(h,1.2 if yard==UPPER else -2.9,1.0-smoothstep(7.,17.,d))
	return h

func at(p:Vector2,lift:=0.0)->Vector3:
	return Vector3(p.x,height(p)+lift,p.y)

func pigment(x:float,z:float,h:float)->Color:
	var n:=noise.get_noise_2d(x,z)
	var g:=grain.get_noise_2d(x,z)
	var w:=profile(x,z)
	var rock:=Color("#44372f").lerp(Color("#8c5944"),clampf(.65+n*.7+h*.002,0.,1.))
	var wash:=Color("#755e52").lerp(Color("#aa876e"),.5+n*.55)
	var crust:=Color("#b5a38b").lerp(Color("#d1c6ae"),clampf(.53+n*.46+g*.29,0.,1.))
	var worn_center:=sin(x*.033)*.58 + noise.get_noise_2d(x,92.)*.87
	var narrow:=absf(absf(z-worn_center)-1.52)
	var wear:float=(1.-smoothstep(.18,.9,narrow+g*.29))*(.58+.34*n)
	var salt:=crust.lerp(Color("#9e8670"),wear*.54)
	var wash_grade:float=1.-smoothstep(3.3,11.2,w.x+g*1.55)
	rock=rock.lerp(wash,wash_grade*.94)
	var cutbank:float=smoothstep(2.7,7.2,w.x)*(1.-smoothstep(8.0,12.8,w.x))
	rock=rock.darkened(cutbank*.13*(.84+.16*n))
	var rough_shoulder:float=absf(z-worn_center*.56)+g*1.45+n*2.3
	var head:float=absf(x)+4.5*g+11.0*n+absf(z)*.72
	var road:float=(1.-smoothstep(2.4,10.5,rough_shoulder))*(1.-smoothstep(108.,155.,head))
	road*=.86+g*.12
	rock=rock.lerp(salt,road)
	for yard:Vector2 in [UPPER,LOWER]:
		var pad:float=1.-smoothstep(4.75,13.0,Vector2(x,z).distance_to(yard)+g*2.2)
		rock=rock.lerp(Color("#a3876e") if yard==UPPER else Color("#928477"),pad*.89)
	if x>-121. and x<-71.:
		var study:=minf(absf(x+92.)+absf(z+11.)*.15,absf(x+92.)+absf(z-16.)*.15)
		var yard_track:float=(1.-smoothstep(1.2,3.4,study+g*.95))*(1.-smoothstep(29.,39.,absf(z)))
		rock=rock.lerp(Color("#ad9075"),yard_track*.62)
	return rock

func make_ground()->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const NX:=225
	const NZ:=185
	const STEP:=2.5
	for j in range(NZ):
		for i in range(NX):
			var p:=Vector2(i-(NX-1)*.5,j-(NZ-1)*.5)*STEP
			var h:=height(p)
			surface.set_color(pigment(p.x,p.y,h))
			var dx:=0.0
			var dz:=0.0
			# Wide central differences with a transverse average condition sharp analytical
			# ridges across the 2.5 m sample grid without altering collision/height.
			const FILTER:=3.35
			for offs in [-2.1,0.0,2.1]:
				dx+=height(p+Vector2(FILTER,offs))-height(p+Vector2(-FILTER,offs))
				dz+=height(p+Vector2(offs,FILTER))-height(p+Vector2(offs,-FILTER))
			surface.set_normal(Vector3(-dx,6.0*FILTER,-dz).normalized())
			surface.add_vertex(Vector3(p.x,h,p.y))
	for j in range(NZ-1):
		for i in range(NX-1):
			var a:=j*NX+i
			for v:int in [a,a+1,a+NX,a+1,a+NX+1,a+NX]:
				surface.add_index(v)
	terrain=mount(surface.commit(),landscape,Vector3.ZERO)
	terrain.name=&"WellRoadGround"
	# Crest shadows on this proxy grid produce repeated triangle sawtooth at the wash lip.
	# Use continuous cutbank/strata shading instead; individual props still cast and receive.
	terrain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func light_sector() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("#526c87")
	sky_mat.sky_horizon_color=Color("#d1bd9a")
	sky_mat.ground_bottom_color=Color("#674c36")
	sky_mat.ground_horizon_color=Color("#d1bd9a")
	var sky := Sky.new()
	sky.sky_material=sky_mat
	var env := Environment.new()
	env.background_mode=Environment.BG_SKY
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#bcb2ad")
	env.ambient_light_energy=.39
	env.fog_enabled=true
	env.fog_density=.00065
	env.fog_light_color=Color("#cfad86")
	env.fog_light_energy=.72
	var we := WorldEnvironment.new()
	we.environment=env
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-37,0)
	light.light_color=Color("#fff0db")
	light.light_energy=.81
	light.shadow_enabled=true
	light.directional_shadow_max_distance=300
	add_child(light)

func material(html: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=Color(html)
	m.roughness=.94
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

func mount(mesh:Mesh,m:Material,at:Vector3,base:Node3D=self) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	item.mesh=mesh
	item.material_override=m
	base.add_child(item)
	item.position=at
	return item

func box(size:Vector3,at:Vector3,m:Material,base:Node3D=self) -> MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=size
	return mount(mesh,m,at,base)

func beam(a:Vector3,b:Vector3,r:float,m:Material,base:Node3D=self) -> void:
	var d:=b-a
	if d.length_squared()<.001:
		return
	var tube := CylinderMesh.new()
	tube.radial_segments=6
	tube.top_radius=r*.82
	tube.bottom_radius=r
	tube.height=d.length()
	var member:=mount(tube,m,(a+b)*.5,base)
	member.quaternion=Quaternion(Vector3.UP,d.normalized())

func faceted(m:Material,points:PackedVector3Array,indices:PackedInt32Array,base:Node3D=self) -> MeshInstance3D:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		surface.add_vertex(points[i])
	surface.generate_normals()
	return mount(surface.commit(),m,Vector3.ZERO,base)


func yard_wall(center:Vector2, from:float, to:float)->void:
	for i in range(15):
		var angle:=lerpf(from,to,i/14.)
		var q:=center+Vector2(cos(angle),sin(angle))*8.9
		var item:=box(Vector3(1.6,.63,.73),at(q,.30),sandstone)
		item.rotation.y=-angle+PI*.5+rng.randf_range(-.13,.13)
		if i%3!=0:
			var cap:=box(Vector3(1.38,.33,.60),at(q,.74),sandstone)
			cap.rotation.y=item.rotation.y+ rng.randf_range(-.09,.09)

func build_compound()->void:
	var upper:=at(UPPER)
	# Roughly round masonry shaft with a real hollow and mixed, staggered courses.
	for row in range(3):
		for i in range(15):
			var a:=TAU*(i+row*.43)/15.
			var j:=rng.randf_range(-.09,.08)
			var p:=upper+Vector3(cos(a)*2.48,.22+row*.42+j,sin(a)*2.48)
			var block:=box(Vector3(1.07,.44,.75),p,sandstone if i%5 else tile)
			block.rotation.y=-a+PI*.5+rng.randf_range(-.06,.06)
	var hole:=CylinderMesh.new()
	hole.top_radius=2.04; hole.bottom_radius=2.03; hole.height=.08
	mount(hole,dark,upper+Vector3(0,.09,0))
	for side in [-1,1]:
		var a:=upper+Vector3(side*3.15,0,0)
		beam(a+Vector3.DOWN*.18,a+Vector3.UP*5.15,.30,oak)
		beam(a+Vector3(0,3.6,0),a+Vector3(-side*1.44,5.05,0),.14,oak)
		for k in [-1,1]:
			beam(a+Vector3(0,-.11,k*.91),a+Vector3(0,1.96,0),.13,oak)
	beam(upper+Vector3(-3.6,5.1,0),upper+Vector3(3.6,5.1,0),.27,oak)
	beam(upper+Vector3(0,4.97,0),upper+Vector3(0,1.6,0),.066,reed)
	var bucket:=CylinderMesh.new()
	bucket.top_radius=.37; bucket.bottom_radius=.28; bucket.height=.52; bucket.radial_segments=9
	mount(bucket,oak,upper+Vector3(0,1.57,0))
	yard_wall(UPPER,PI*.90,PI*1.95)
	yard_wall(LOWER,PI*.11,PI*.67)
	set_yard_entry(UPPER+Vector2(-4.5,6.1),false)
	set_yard_entry(LOWER+Vector2(-5.8,-6.3),true)
	var low:=at(LOWER)
	# Separate low storehouse: masonry plinth, board infill, cared-for thatch and a dark open doorway.
	box(Vector3(12.2,.42,8.1),low+Vector3(0,.06,0),sandstone)
	box(Vector3(11.7,3.5,.58),low+Vector3(0,1.85,3.75),sandstone)
	for side in [-1,1]:
		box(Vector3(.52,3.55,7.53),low+Vector3(side*5.58,1.88,0),sandstone)
		box(Vector3(4.70,3.5,.55),low+Vector3(side*3.37,1.85,-3.76),sandstone)
		beam(low+Vector3(side*1.02,.22,-4.10),low+Vector3(side*1.02,3.76,-4.1),.16,oak)
		beam(low+Vector3(side*5.8,.28,-4.17),low+Vector3(side*5.8,3.82,-4.17),.23,oak)
		beam(low+Vector3(-6.65,6.04,0),low+Vector3(6.65,6.04,0),.17,oak)
		for i in range(33):
			var x:float=(i-16)*.392
			var e:=float(side)*(4.53+rng.randf_range(-.16,.19))
			beam(low+Vector3(x,6.04+rng.randf_range(-.08,.10),0),low+Vector3(x,3.62,e),rng.randf_range(.18,.21),reed, self)
		beam(low+Vector3(-6.64,3.66,side*4.59),low+Vector3(6.70,3.66,side*4.59),.16,oak)
	box(Vector3(2.22,3.31,.12),low+Vector3(0,1.90,-3.02),dark)
	beam(low+Vector3(-1.22,3.73,-4.20),low+Vector3(1.22,3.73,-4.20),.19,oak)
	for pair:Vector2 in [Vector2(-4.8,-5.4),Vector2(-3.6,-5.8),Vector2(4.5,-5.8),Vector2(3.7,-6.4),Vector2(5.5,1.2)]:
		var pos:=at(LOWER+pair)
		var jar:=CylinderMesh.new()
		jar.radial_segments=9; jar.height=rng.randf_range(.72,1.24); jar.top_radius=.43; jar.bottom_radius=.68
		mount(jar,tile,pos+Vector3.UP*jar.height*.5)
	var second:=at(LOWER+Vector2(8.8,2.0))
	var lower_hole:=CylinderMesh.new()
	lower_hole.top_radius=1.27; lower_hole.bottom_radius=1.27; lower_hole.height=.07
	mount(lower_hole,dark,second+Vector3.UP*.08)
	for row in range(2):
		for i in range(11):
			var a:=TAU*(i+row*.51)/11.
			var rim:=box(Vector3(.86,.33,.58),second+Vector3(cos(a)*1.57,.16+row*.32,sin(a)*1.57),sandstone if i%3 else tile)
			rim.rotation.y=-a+PI*.5
	beam(second+Vector3(-1.8,-.1,.16),second+Vector3(-1.8,2.3,.16),.18,oak)
	beam(second+Vector3(1.8,-.1,.16),second+Vector3(1.8,2.3,.16),.18,oak)
	beam(second+Vector3(-1.85,2.24,.16),second+Vector3(1.85,2.24,.16),.14,oak)
	beam(second+Vector3(0,2.17,.16),second+Vector3(0,.86,.16),.046,reed)
	add_wash_crags()

func set_yard_entry(center:Vector2,lower:bool)->void:
	# Grounded, localized retaining stones. No activity is presented.
	for i in range(6 if lower else 5):
		var q:=center+Vector2(i*.91-2.0,rng.randf_range(-.32,.32)+i*.24)
		var slab:=box(Vector3(rng.randf_range(.65,.94),.23,rng.randf_range(.82,1.55)),at(q,.10),sandstone)
		slab.rotation.y=rng.randf_range(-.26,.20)
	if lower:
		var front:=at(center+Vector2(.84,1.5))
		for edge in [-1.,1.]:
			var foot:=front+Vector3(edge*1.76,0,0)
			beam(foot+Vector3.DOWN*.21,foot+Vector3.UP*2.3,.135,oak)
		beam(front+Vector3(-1.95,1.91,0),front+Vector3(1.95,1.87,0),.127,oak)

func add_wash_crags()->void:
	# Landmark groups off route and shoulders; monotony is broken without fictional gameplay.
	var m:=SphereMesh.new()
	m.radial_segments=5
	m.rings=3
	for a:Vector2 in [Vector2(-45,33),Vector2(-3,75),Vector2(38,25),Vector2(74,69),Vector2(95,55),Vector2(-37,-20),Vector2(39,-20)]:
		for i in range(rng.randi_range(4,7)):
			var q:Vector2=a+Vector2(rng.randf_range(-4,4),rng.randf_range(-4,4))
			var stone:=mount(m,sandstone if i%2==0 else tile,at(q,.65))
			stone.scale=Vector3(rng.randf_range(1.4,3.8),rng.randf_range(2.04,7.61),rng.randf_range(1.18,4.4))
			stone.rotation_degrees=Vector3(rng.randf_range(-23,23),rng.randf_range(0,180),rng.randf_range(-15,15))
	for i in range(220):
		var q:=Vector2(rng.randf_range(-171,171),rng.randf_range(-106,107))
		var d:=profile(q.x,q.y).x
		if d<6.5 or absf(q.y)<10. or q.distance_to(UPPER)<12. or q.distance_to(LOWER)<12.: continue
		var s:=rng.randf_range(.38,1.32)
		var stone:=mount(m,sandstone if i%3 else tile,at(q,.12))
		stone.scale=Vector3(s, s*.45,s*.83)
		stone.rotation.y=rng.randf_range(0.,TAU)

func set_camera(close:bool)->void:
	var target:=Vector3(-91,0,7) if close else Vector3(-4,0,8)
	$Camera.position=target+(Vector3(-30,64,-51) if close else Vector3(27,224,141))
	$Camera.look_at(target)


func _prepare_context()->void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	var polish:=preload("res://game/overworld/raska/well_context.gd").new()
	var model:Node3D=polish.compose(self)
	add_child(model)
	if polish.misses!=0 or polish.rays<1000 or polish.route_gap<8.5 or model.find_children("*","CollisionObject3D",true,false).size()>0:
		push_error("Well Road context physical/seating guard failed.")
