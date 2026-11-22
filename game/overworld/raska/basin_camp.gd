extends Node3D
## Private first-approach environment study, not mounted in the production game.
## The route passes west/northwest off the sector; it does not fake a Greyhollow arrival.
const CAMP := Vector2(39.0, 28.0)
const RIM := Vector2(-119.0,-81.0)
const COURSE := [CAMP,Vector2(22,33),Vector2(2,19),Vector2(-16,1),Vector2(-36,-8),
	Vector2(-57,-18),Vector2(-67,-35),Vector2(-84,-53),Vector2(-101,-65),RIM]
const COURSE_LEVELS := [2.27,2.38,1.3,-2.5,-8.5,-11.0,-7.3,-1.5,2.0,2.28]
const ROCK := Color("#a86a4c")
var terrain_mat := ShaderMaterial.new()
var rng := RandomNumberGenerator.new()
var relief := FastNoiseLite.new()
var grain := FastNoiseLite.new()
var wood: StandardMaterial3D
var iron: StandardMaterial3D
var cloth: Array[Material]
var pale: StandardMaterial3D
var porch: StandardMaterial3D
var flags: StandardMaterial3D
var terrain: MeshInstance3D

func _ready() -> void:
	rng.seed = 772023
	relief.seed = 307
	relief.frequency = .024
	relief.fractal_octaves = 3
	grain.seed = 714
	grain.frequency = .14
	terrain_mat.shader = preload("res://game/overworld/raska/basin_stone.gdshader")
	wood = color_mat("#4d372b")
	iron = color_mat("#292b2b")
	pale = color_mat("#b78e67")
	porch = color_mat("#715038")
	flags = color_mat("#aa662e")
	for c: String in ["#704735", "#5a5144", "#666d61", "#a79878", "#8d7457"]:
		var textile := ShaderMaterial.new()
		textile.shader = preload("res://game/overworld/raska/basin_cloth.gdshader")
		textile.set_shader_parameter("dye",Color(c))
		cloth.append(textile)
	light_sector()
	build_terrain()
	build_camp()
	scatter()
	set_camera(false)
	_prepare_compound()


func river_center(z: float) -> float:
	return -29.0 + sin(z*.038 + .25)*21.0 + 0.27*z

func mesa(x: float,z: float, cx: float,cz:float, rx:float,rz:float) -> float:
	var d := Vector2((x-cx)/rx,(z-cz)/rz).length() + relief.get_noise_2d(x,z)*0.24
	return pow(1.0-smoothstep(.51,1.09,d),1.7)

func height(x: float,z: float) -> float:
	var channel := absf(x-river_center(z))
	var h := 2.2 + relief.get_noise_2d(x,z)*7.5 + grain.get_noise_2d(x,z)*.38
	h -= 12.0 * (1.0-smoothstep(3.0,25.0,channel))
	h += 49.0 * mesa(x,z,-108,-22,30,35)
	h += 63.0 * mesa(x,z,98,-68,65,46)
	h += 43.0 * mesa(x,z,111,8,44,42)
	h += 51.0 * mesa(x,z,-122,87,60,62)
	h += 41.0 * mesa(x,z,69,114,59,42)
	h += 31.0 * mesa(x,z,-50,-110,41,33)
	h += 83.0 * mesa(x,z,-257,-184,110,93)
	h += 92.0 * mesa(x,z,-178,-276,111,95)
	h += 108.0 * mesa(x,z,15,-301,125,94)
	h += 81.0 * mesa(x,z,207,-172,82,96)
	h += 72.0 * mesa(x,z,242,145,89,96)
	var grade := 1.0 - smoothstep(9.0,23.0,Vector2(x-39.0,z-24.0).length())
	h=lerpf(h,2.2+(z-24.0)*.025,grade*.89)
	var p := Vector2(x,z)
	if x < -133.0 or x > 48.0 or z < -91.0 or z > 43.0:
		return h
	var closest := 17.0
	var road_level := h
	for i in range(COURSE.size()-1):
		var a: Vector2=COURSE[i]
		var b: Vector2=COURSE[i+1]
		var at:=Geometry2D.get_closest_point_to_segment(p,a,b)
		var gap:=at.distance_to(p)
		if gap<closest:
			closest=gap
			road_level=lerpf(COURSE_LEVELS[i],COURSE_LEVELS[i+1],at.distance_to(a)/a.distance_to(b))
	return lerpf(road_level,h,smoothstep(2.5,13.0,closest))

func world(p:Vector2, lift:=0.0) -> Vector3:
	return Vector3(p.x,height(p.x,p.y)+lift,p.y)

func distance_to_course(p: Vector2) -> float:
	var closest := 1000.0
	for i in range(COURSE.size()-1):
		var a:Vector2=COURSE[i];var b:Vector2=COURSE[i+1]
		closest = minf(closest,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
	return closest

func pigment(x: float, z: float, y: float) -> Color:
	var h := relief.get_noise_2d(x,z) *.5+.5
	var channel := absf(x-river_center(z))
	var flat := Color("#9f6948").lerp(Color("#bd986d"),h)
	var salt:=clampf(h*.55 + grain.get_noise_2d(x,z)*.27+.4,0.0,1.0)
	var dry := Color("#89715a").lerp(Color("#dfc9a0"),salt)
	var band := wrapf(y+sin(z*.062)*1.3,0.0,9.0) / 9.0
	var face := Color("#70473d").lerp(Color("#a65f41"),h*.51+band*.37)
	var a := flat.lerp(dry,(1.0-smoothstep(4.0,17.0,channel))*.99)
	a = a.lerp(face,smoothstep(14.0,31.0,y))
	var road := distance_to_course(Vector2(x,z))
	var apron := Vector2(x-34.0,z-28.0).length()
	return a.lerp(Color("#ba9778").lerp(Color("#cdb69a"),h),maxf(1.0-smoothstep(1.25,3.6,road), (1.0-smoothstep(7.0,24.0,apron))*.46))

func build_terrain() -> void:
	var coordinates := PackedFloat32Array()
	for i in 29:
		coordinates.append(-350.0 + i*6.30)
	for i in 231:
		coordinates.append(-171.5 + i*1.49)
	for i in 29:
		coordinates.append(177.0 + i*6.30)
	var sz := coordinates.size()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var colors := PackedColorArray()
	var ids := PackedInt32Array()
	for j in sz:
		var z := coordinates[j]
		for i in sz:
			var x := coordinates[i]
			var y := height(x,z)
			v.append(Vector3(x,y,z))
			n.append(Vector3(height(x-.65,z)-height(x+.65,z),1.3,height(x,z-.65)-height(x,z+.65)).normalized())
			colors.append(pigment(x,z,y).srgb_to_linear())
			if i<sz-1 and j<sz-1:
				var k := j*sz+i
				ids.append_array([k,k+1,k+sz,k+sz,k+1,k+sz+1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=v
	arrays[Mesh.ARRAY_NORMAL]=n
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=ids
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	terrain = mount(mesh,terrain_mat,Vector3.ZERO)
	terrain.name="RedBasinRelief"

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
	env.ambient_light_energy=.47
	env.fog_enabled=true
	env.fog_density=.0018
	env.fog_light_color=Color("#cfad86")
	env.fog_light_energy=.72
	var we := WorldEnvironment.new()
	we.environment=env
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-37,0)
	light.light_color=Color("#ffe0ac")
	light.light_energy=1.02
	light.shadow_enabled=true
	light.directional_shadow_max_distance=300
	add_child(light)

func color_mat(html: String) -> StandardMaterial3D:
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

func tent(p:Vector2, yaw: float, width:float, length:float, peak:float, fabric:Material, show_front := false) -> void:
	var t := Node3D.new()
	add_child(t)
	t.position=world(p,.06)
	t.rotation.y=yaw
	var l:=length*.5
	var w:=width*.5
	var points:=PackedVector3Array([
		Vector3(-w,.23,l),Vector3(w,.23,l),Vector3(-w,.23,-l),Vector3(w,.23,-l),
		Vector3(0,peak,l),Vector3(0,peak,-l),Vector3(-w*.52,peak*.64,l),Vector3(w*.52,peak*.64,l),
		Vector3(-w*.52,peak*.64,-l),Vector3(w*.52,peak*.64,-l)])
	var skin := PackedVector3Array()
	var faces := PackedInt32Array()
	for step in 7:
		var u:=float(step)/6.0
		var z:=lerpf(l,-l,u)
		var sag:=sin(u*PI)*(.17 + sin(5.0*u)*.14)
		var skew:=sin(u*PI)*.21
		skin.append(Vector3(-w+skew,.23+sin(u*6.0)*.07,z))
		skin.append(Vector3(-w*.52+skew,peak*.64-sag*.7,z))
		skin.append(Vector3(skew,peak-sag,z))
		skin.append(Vector3(w*.52+skew,peak*.64-sag*.8,z))
		skin.append(Vector3(w+skew,.23-sin(u*8.0)*.11,z))
		if step<6:
			for side in 4:
				var k:=step*5+side
				faces.append_array([k,k+5,k+1,k+1,k+5,k+6])
	faceted(fabric,skin,faces,t)
	if show_front:
		faceted(porch,PackedVector3Array([points[0],Vector3(-.34,.08,l),points[4],Vector3(.34,.08,l),points[1]]),
			PackedInt32Array([0,1,2,2,3,4]),t)
	else:
		faceted(fabric,points,PackedInt32Array([0,4,1]),t)
	beam(Vector3(0,peak,l+.15),Vector3(0,peak,-l-.14),.12,wood,t)
	for z: float in [-l,l]:
		for s: float in [-1.0,1.0]:
			beam(Vector3(0,peak,z),Vector3(w*s,0,z),.07,pale,t)
			beam(Vector3(w*.53*s,peak*.64,z),Vector3((w+.85)*s,0,z+signf(z)*.62),.047,wood,t)
	for z: float in [-l,-l*.35,l*.35,l]:
		for s: float in [-1.0,1.0]:
			beam(Vector3(w*s,.25,z),Vector3(w*.51*s,peak*.64,z),.027,pale,t)

func build_camp() -> void:
	var zone:=Node3D.new()
	zone.name="BasinCampLandmark"
	add_child(zone)
	tent(Vector2(39,23),-.27,9.4,11.7,4.3,cloth[0],true)
	tent(Vector2(30,14),-.4,5.4,7,2.5,cloth[3],true)
	tent(Vector2(48,16),-.15,5.7,8.4,2.7,cloth[2])
	tent(Vector2(52,26),.1,5.8,7.7,2.5,cloth[4],true)
	tent(Vector2(30,28),.52,5.1,7,2.8,cloth[1],true)
	tent(Vector2(45,36),2.5,4.8,6.7,2.4,cloth[3],true)
	_build_operations_portico()
	var supply:=Vector2(53,32)
	for i in range(10):
		var p:=supply + Vector2(rng.randf_range(-3,3),rng.randf_range(-2,2))
		var barrel:=CylinderMesh.new()
		barrel.radial_segments=8
		barrel.top_radius=.44
		barrel.bottom_radius=.48
		barrel.height=.92
		mount(barrel,pale if i%2==0 else porch,world(p,.46))
		for h in [.24,.65]:
			var hoop:=CylinderMesh.new()
			hoop.radial_segments=8
			hoop.top_radius=.49
			hoop.bottom_radius=.49
			hoop.height=.08
			mount(hoop,iron,world(p,h))
	for i in range(14):
		var ang:=float(i)*TAU/16.0
		var p:=Vector2(40,24)+Vector2(cos(ang)*21.0,sin(ang)*16.0)
		var op:=p+Vector2(.29,.17)
		if i in [5,6,7,8,9,10]:
			continue
		beam(world(p,-.12),world(op,1.12),.129,wood)
	var flagp:=world(Vector2(35,34))
	beam(flagp,flagp+Vector3(.12,5.7,.07),.097,wood)
	faceted(flags,PackedVector3Array([flagp+Vector3(.12,5.7,.05),flagp+Vector3(2.61,5.31,-.15),flagp+Vector3(2.3,4.38,-.09),flagp+Vector3(.11,4.7,.05)]),
		PackedInt32Array([0,1,2,0,2,3]))
	var openp := world(Vector2(35,35))
	for i in 5:
		var at:=openp+Vector3(cos(i*TAU/5.0)*1.21,.09,sin(i*TAU/5.0)*1.2)
		box(Vector3(.66,.49,.43),at,porch).rotation.y=float(i)
	$Party.position=world(CAMP)
	$Party.name="Party"

# Portable, unlabeled staging/operations landmark. It has no interaction or new lore.
func _build_operations_portico() -> void:
	var node := Node3D.new()
	node.name="OperationsPorticoStudy"
	add_child(node)
	node.position=world(Vector2(38.0,30.1))
	node.rotation.y=-.28
	var a := Vector3(-3.45,2.9,-2.3)
	var b := Vector3(3.42,2.83,-2.3)
	var c := Vector3(-3.34,2.22,2.32)
	var d := Vector3(3.31,2.02,2.26)
	var roof:=PackedVector3Array([a,b,d,c,(a+b+c+d)*.25-Vector3.UP*.22,Vector3(-3.12,2.75,.2),Vector3(3.26,2.62,.45)])
	faceted(cloth[2],roof,PackedInt32Array([0,1,4,1,6,4,6,2,4,2,3,4,3,5,4,5,0,4]),node)
	for p:Vector3 in [a,b,c,d]:
		beam(p,Vector3(p.x,-.18,p.z),.137,wood,node)
		var cap:=Vector3(p.x,.31,p.z)
		box(Vector3(.51,.46,.48),cap,porch,node).rotation.y=rng.randf_range(-.42,.42)
	for side in [-1.0,1.0]:
		beam(Vector3(side*3.27,2.11,2.22),Vector3(side*2.05,1.15,2.25),.091,wood,node)
		beam(Vector3(side*3.34,2.18,2.26),Vector3(side*3.39,1.28,.9),.09,wood,node)
	beam(c,d,.09,pale,node)
	for i in 7:
		var xyz:=Vector3(-2.92+i*.97,0.025,1.34)
		box(Vector3(.89,.14,2.58),xyz,wood,node).rotation.y = rng.randf_range(-.02,.02)
	var desk := Vector3(.37,.65,-.62)
	box(Vector3(1.82,.18,.74),desk,porch,node)
	for x in [-.32,1.08]:
		for z in [-.86,-.39]:
			box(Vector3(.12,.70,.11),Vector3(x,.33,z),wood,node)
	box(Vector3(1.07,.08,.52),desk+Vector3(.02,.126,-.035),pale,node).rotation.y=.090
	var strips:=PackedVector3Array([Vector3(-2.8,2.08,2.38),Vector3(-1.92,2.04,2.38),Vector3(-1.97,.56,2.41),Vector3(-2.72,.49,2.39)])
	faceted(flags,strips,PackedInt32Array([0,1,2,0,2,3]),node)
	for i in 8:
		var offset := Vector2(31.9-i*.84,32.8+(i*i)*.039)
		var rock:=box(Vector3(.91,.38+rng.randf_range(.0,.21),.55),world(offset,.21),porch)
		rock.rotation = Vector3(rng.randf_range(-.10,.12),rng.randf_range(-.53,.66),rng.randf_range(-.10,.18))

func scatter() -> void:
	var stone_templates: Array[ArrayMesh]=[]
	for k in range(4):
		var rim_pts:=PackedVector3Array()
		for row in range(3):
			for i in range(6):
				var theta:=float(i)*TAU/6.0
				rim_pts.append(Vector3(cos(theta)*(1.0-.22*row)*rng.randf_range(.77,1.12)+.2*row,
					row*.48+rng.randf_range(-.14,.14),sin(theta)*(1.0-.24*row)*rng.randf_range(.78,1.16)))
		rim_pts.append(Vector3(.41,1.02,-.13))
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 6:
			var j: int=(i+1)%6
			for row in 2:
				for id: int in [i+row*6,j+row*6,(row+1)*6+i,(row+1)*6+i,j+row*6,(row+1)*6+j]:
					st.set_color(ROCK.lightened(rng.randf_range(-.10,.10)).srgb_to_linear())
					st.add_vertex(rim_pts[id])
			for id: int in [12+i,12+j,18]:
				st.set_color(ROCK.lightened(rng.randf_range(-.10,.11)).srgb_to_linear())
				st.add_vertex(rim_pts[id])
		st.set_smooth_group(-1)
		st.generate_normals()
		stone_templates.append(st.commit())
	for i in 360:
		var p:=Vector2(rng.randf_range(-157,156),rng.randf_range(-122,145))
		if p.distance_to(Vector2(40,24))<24 or distance_to_course(p)<4.0:
			continue
		var y:=height(p.x,p.y)
		var s:=rng.randf_range(.36,1.8)
		if absf(p.x-river_center(p.y))>16 and i%7==0:
			s *= 2.4
		var r:=mount(stone_templates[i%4],terrain_mat,world(p,-.46*s))
		r.scale=Vector3(s*rng.randf_range(.95,1.32),s*rng.randf_range(.59,.98),s*rng.randf_range(.59,1.41))
		r.rotation.y=rng.randf_range(-PI,PI)

func set_camera(close:bool) -> void:
	var target:=world(Vector2(9,9)) if not close else world(Vector2(39,22))
	$Camera.position=target + (Vector3(86,143,157) if not close else Vector3(23,41,48))
	$Camera.look_at(target+Vector3.UP*2.2)


func _prepare_compound()->void:
	terrain.create_trimesh_collision()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	var works:=preload("res://game/overworld/raska/operations_compound.gd").new()
	var sculpture:Node3D=works.mount(self)
	add_child(sculpture)
	if works.missed!=0 or works.sample_count<700 or works.route_clearance<3.6 or works.min_wash_clearance<19. or sculpture.find_children("*","CollisionObject3D",true,false).size()!=0:
		push_error("Basin art violated sheltered footing or protected approach.")
