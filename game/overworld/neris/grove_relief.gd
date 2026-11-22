extends Node3D
## Private native study. Not a complete Neris overworld or art gate approval.
const GROUND := preload("res://game/overworld/neris/grove_earth.gdshader")
const TERRAIN_STEP := 3.7
const CAMP := Vector2(-151.0, 44.0)
const NURSERY := Vector2(144.0, -42.0)
const TRAIL_GUIDES := [CAMP, Vector2(-114, 36), Vector2(-80, 18), Vector2(-53, 22),
	Vector2(-23, 39), Vector2(19, 31), Vector2(45, 9), Vector2(70,-11),
	Vector2(97,-19), Vector2(120,-26), NURSERY]
## Grading stations in world meters, aligned one-to-one with the authored guides.
## The centerline geometry and its ends are unchanged.
const ROAD_ELEVATIONS := [12.86, 10.8, 8.2, 6.65, 7.1, 8.8, 11.7, 14.6, 16.2, 18.25, 19.38]
const ROAD_FLAT_WIDTH := 12.5
const ROAD_SHOULDER_WIDTH := 39.0
const CAMPAIGN_REGIONAL_OFFSET := Vector3(-116, 370, 430)
const CAMPAIGN_NEAR_OFFSET := Vector3(61, 50, 71)
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _route := Curve3D.new()
var _route_points := PackedVector3Array()
var _ground_mesh: MeshInstance3D
var _ground_material:ShaderMaterial
var baked_terrain: Array[MeshInstance3D]=[]
var _base: Dictionary
var _variants: Array[Mesh] = []
var _dead: Array[Mesh] = []
var _recording := false

func _init() -> void:
	_rng.seed=8132234
	_noise.seed=1724
	_noise.frequency = 0.022

signal preparation_progress(completed: int,total: int)
var defer_preparation := false
var preparation_cancelled := false
var scenery_ready := false
var build_slices := 0
var max_slice_usec := 0
var actual_row_compute_usec:=0
var actual_frame_wait_usec:=0
var mesh_commit_usec:=0
var settlement_usec:=0
const COOP_ROW_BUDGET_USEC:=12000
var _zoomed := false

func _prepare_palette()->void:
	_base = {
		"trail": _paint("#a48358"), "verge": _paint("#665a3c"),
		"wood": _paint("#534235"), "stone": _paint("#837966"),
		"washed": _paint("#a2987d"), "roof": _paint("#58493c"),
		"canvas": _paint("#a3aa77"), "dark": _paint("#38382b"),
		"wet": _paint("#5c7040"), "water": _paint("#46736d", 0.35)
	}

func _ready() -> void:
	if defer_preparation:
		return
	_prepare_palette()
	_light()
	await _terrain()
	_after_terrain()
	scenery_ready=true

func prepare_cooperatively() -> bool:
	if scenery_ready:
		return true
	_prepare_palette()
	_light()
	if not await _terrain(true):
		return false
	var after_rows:=Time.get_ticks_usec()
	_after_terrain()
	settlement_usec=Time.get_ticks_usec()-after_rows
	scenery_ready=not preparation_cancelled
	return scenery_ready

func prepare_from_bake(pieces:Array[ArrayMesh])->bool:
	if scenery_ready or pieces.size()!=56 or preparation_cancelled:
		return false
	_prepare_palette()
	_light()
	var start:=Time.get_ticks_usec()
	_ground_material=ShaderMaterial.new()
	_ground_material.shader=GROUND
	for mesh:ArrayMesh in pieces:
		var tile:=MeshInstance3D.new()
		tile.mesh=mesh
		tile.material_override=_ground_material
		add_child(tile)
		baked_terrain.append(tile)
	_ground_mesh=baked_terrain.front()
	mesh_commit_usec=Time.get_ticks_usec()-start
	await get_tree().process_frame
	if preparation_cancelled:
		return false
	var detail:=Time.get_ticks_usec()
	_after_terrain()
	settlement_usec=Time.get_ticks_usec()-detail
	scenery_ready=not preparation_cancelled
	return scenery_ready

func _after_terrain()->void:
	_build_route()
	_forest()
	# Same exact inherited scene placement and random state.
	_rng.state=-8803360722374495698
	_camp()
	_grove()
	_party()
	_regional()
	var n := 0
	var max_error := 0.0
	var steepest := 0.0
	var steepest_at := Vector3.ZERO
	for i in range(0, int(_route.get_baked_length())+1):
		var v := _route.sample_baked(float(i))
		max_error = maxf(max_error, absf(v.y-ground_height(v.x,v.z)-0.38))
		if i > 0:
			var back := _route.sample_baked(float(i)-1.0)
			var local:=absf(v.y-back.y)/Vector2(v.x-back.x,v.z-back.z).length()
			if local > steepest:
				steepest=local
				steepest_at=v
		n+=1
	print("Grove private relief: %d route samples, %.1fm, max height residual %.3fm; steepest 1m grade %.1f%% at %s; anchors %s → %s" %
		[n,_route.get_baked_length(),max_error,steepest*100.,steepest_at,_route_points[0],_route_points[-1]])
	var args := OS.get_cmdline_user_args()
	if "--proof" in args:
		_record.call_deferred()

func _ridge(x: float,z: float,a: float,b: float,w: float,h: float) -> float:
	return exp(-((x-a)*(x-a)/(w*w)+(z-b)*(z-b)/(h*h)))

func height(x: float,z: float) -> float:
	var ground := _natural_height(x,z)
	if x < -190.0 or x > 183.0 or z < -81.0 or z > 84.0:
		return ground
	var along := clampf(x,CAMP.x,NURSERY.x)
	var idx := 0
	while idx < TRAIL_GUIDES.size()-2 and along > TRAIL_GUIDES[idx+1].x:
		idx+=1
	var from:Vector2=TRAIL_GUIDES[idx]
	var to:Vector2=TRAIL_GUIDES[idx+1]
	var t:=inverse_lerp(from.x,to.x,along)
	var road_z:=lerpf(from.y,to.y,t)
	var distance:=Vector2(x-along,z-road_z).length()
	if distance >= ROAD_SHOULDER_WIDTH:
		return ground
	var road_y:=lerpf(ROAD_ELEVATIONS[idx],ROAD_ELEVATIONS[idx+1],smoothstep(0.0,1.0,t))
	return lerpf(road_y,ground,smoothstep(ROAD_FLAT_WIDTH,ROAD_SHOULDER_WIDTH,distance))

func _natural_height(x: float,z: float) -> float:
	var regional := 5.0 + 46.0*_ridge(x,z,-232,-101,105,102) + 55.0*_ridge(x,z,72,-172,100,70)
	regional += 41.0*_ridge(x,z,248,-133,110,112) + 21.0*_ridge(x,z,-214,153,118,105)
	regional += 79.0*_ridge(x,z,-309,-340,165,137) + 113.0*_ridge(x,z,78,-455,225,110)
	regional += 66.0*_ridge(x,z,423,-372,150,132) + 97.0*_ridge(x,z,592,-565,183,175)
	regional += 11.0*_ridge(x,z,61,56,55,90)-13.0*_ridge(x,z,-9,-19,69,65)
	var finish := _ridge(x,z,142,-60,45,35)
	var road_belt:=_ridge(x,z,0.0,13.0,245.0,74.0)
	return regional + _noise.get_noise_2d(x,z)*(6.6-road_belt*5.9)*(1.0-finish*.66) + finish*5.5

func _paint(color: String, roughness := .93) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=Color(color)
	m.roughness=roughness
	return m

func _light() -> void:
	var world_env:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#99a49a")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#b0c0b0")
	env.ambient_light_energy=.47
	env.fog_enabled=true
	env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_light_color=Color("#929c8e")
	env.fog_depth_begin=495.0
	env.fog_depth_end=1125.0
	env.fog_density=.65
	world_env.environment=env
	add_child(world_env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-44,-53,0)
	sun.light_color=Color("#ffdeb1")
	sun.light_energy=.98
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=480
	add_child(sun)

func _terrain_vertex(p:Vector2)->Array:
	var y:=height(p.x,p.y)
	var moisture:=_ridge(p.x,p.y,148,-61,53,58)
	var dry:=_ridge(p.x,p.y,-26,7,75,44)
	var rough:=_noise.get_noise_2d(p.x*1.7,p.y*1.7)
	var color:=Color("#687348").lerp(Color("#a17848"),clampf(dry*1.12+rough*.20,0,1))
	color=color.lerp(Color("#395740"),moisture*.91)
	color=color.lerp(Color("#7d7861"),clampf((y-13)/52.0,0,1))
	var normal:=Vector3(height(p.x-.2,p.y)-height(p.x+.2,p.y),.4,
		height(p.x,p.y-.2)-height(p.x,p.y+.2)).normalized()
	return [Vector3(p.x,y,p.y),normal,color]

func _terrain(cooperative:=false) -> bool:
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEP:=TERRAIN_STEP
	const EAST:=Vector2(STEP,0)
	const SOUTH:=Vector2(0,STEP)
	const DIAGONAL:=Vector2(STEP,STEP)
	var lower:Dictionary[Vector2,Array]={}
	var done:=0
	var started:=Time.get_ticks_usec()
	const CELLS:=410*502
	# The source uses single-precision positions. Key by the exact computed
	# Vector2, not by integer grid indices, to preserve authored rounding.
	for z in range(-258,152):
		var upper:Dictionary[Vector2,Array]={}
		for x in range(-224,278):
			var a:=Vector2(x,z)*STEP
			var points:PackedVector2Array=[a,a+EAST,a+DIAGONAL,a,a+DIAGONAL,a+SOUTH]
			for corner in 6:
				var p:=points[corner]
				var row:=lower if corner==0 or corner==1 or corner==3 else upper
				if not row.has(p):
					row[p]=_terrain_vertex(p)
				var vertex:Array=row[p]
				mesh.set_color(vertex[2])
				mesh.set_normal(vertex[1])
				mesh.add_vertex(vertex[0])
			done+=1
			if cooperative and done%16==0:
				var elapsed:=Time.get_ticks_usec()-started
				if elapsed>=COOP_ROW_BUDGET_USEC:
					actual_row_compute_usec+=elapsed
					max_slice_usec=maxi(max_slice_usec,elapsed)
					build_slices+=1
					preparation_progress.emit(done,CELLS)
					var next_frame:=Time.get_ticks_usec()
					await get_tree().process_frame
					actual_frame_wait_usec+=Time.get_ticks_usec()-next_frame
					if preparation_cancelled:
						return false
					started=Time.get_ticks_usec()
		lower=upper
	if cooperative:
		actual_row_compute_usec+=Time.get_ticks_usec()-started
		preparation_progress.emit(CELLS,CELLS)
		var last_frame:=Time.get_ticks_usec()
		await get_tree().process_frame
		actual_frame_wait_usec+=Time.get_ticks_usec()-last_frame
		if preparation_cancelled:
			return false
	var commit_start:=Time.get_ticks_usec()
	_ground_mesh=MeshInstance3D.new()
	_ground_mesh.mesh=mesh.commit()
	mesh_commit_usec=Time.get_ticks_usec()-commit_start
	_ground_material=ShaderMaterial.new()
	_ground_material.shader=GROUND
	_ground_mesh.material_override=_ground_material
	add_child(_ground_mesh)
	return true

func route_contract() -> Curve3D:
	if not _route_points.is_empty():
		return _route
	_route.bake_interval=0.75
	for i in TRAIL_GUIDES.size()-1:
		var a:Vector2=TRAIL_GUIDES[maxi(0,i-1)]
		var b:Vector2=TRAIL_GUIDES[i]
		var c:Vector2=TRAIL_GUIDES[i+1]
		var d:Vector2=TRAIL_GUIDES[mini(TRAIL_GUIDES.size()-1,i+2)]
		for step in range(32):
			var p:=b.cubic_interpolate(c,a,d,float(step)/32.)
			_route_points.append(_at(p,.38))
	_route_points.append(_at(NURSERY,.38))
	for v in _route_points:
		_route.add_point(v)
	return _route

func _build_route() -> void:
	route_contract()
	var pixel_mask:=Image.create(1024, 688, false, Image.FORMAT_L8)
	var ink:=Rect2(-190,-87,385,168)
	for i in range(ceili(_route.get_baked_length()*3.0)):
		var v:=_route.sample_baked(float(i)/3.0)
		var uv:=(Vector2(v.x,v.z)-ink.position)/ink.size
		var point:=Vector2i(uv*Vector2(pixel_mask.get_size()))
		for dy in range(-15,16):
			for dx in range(-15,16):
				var distance:=Vector2(dx*ink.size.x/1024.0,dy*ink.size.y/688.0).length()
				var shade:=1.0-smoothstep(2.35,4.75,distance)
				var x:=point.x+dx
				var y:=point.y+dy
				if shade>.006 and pixel_mask.get_pixel(x,y).r<shade:
					pixel_mask.set_pixel(x,y,Color(shade,shade,shade))
	_ground_material.set_shader_parameter("route_mask",ImageTexture.create_from_image(pixel_mask))
	_ground_material.set_shader_parameter("route_domain",Vector4(ink.position.x,ink.position.y,ink.size.x,ink.size.y))


func ground_height(x:float,z:float)->float:
	var a:=floorf(x/TERRAIN_STEP)*TERRAIN_STEP
	var b:=floorf(z/TERRAIN_STEP)*TERRAIN_STEP
	var u:=(x-a)/TERRAIN_STEP
	var v:=(z-b)/TERRAIN_STEP
	var corner:=height(a,b)
	var opposite:=height(a+TERRAIN_STEP,b+TERRAIN_STEP)
	if u>=v:
		return corner*(1.0-u)+height(a+TERRAIN_STEP,b)*(u-v)+opposite*v
	return corner*(1.0-v)+height(a,b+TERRAIN_STEP)*(v-u)+opposite*u

func _at(p:Vector2,lift:=0.0)->Vector3:
	return Vector3(p.x,ground_height(p.x,p.y)+lift,p.y)

func _build_tree(tree: int, dry: bool) -> Mesh:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark:=_paint("#655446" if dry else "#4f4432")
	bark.vertex_color_use_as_albedo=true
	bark.albedo_color=Color.WHITE
	s.set_material(bark)
	var h := 11.0 + float(tree)*2.0
	_frustum(s,Vector3.ZERO,Vector3(0,h*.81,0),.50,.09,6,Color("#675342"))
	for i in 5:
		var a:=i*2.399+float(tree)
		var dir:=Vector3(cos(a),0,sin(a))
		var start:=Vector3.UP*(h*(.23+.12*i))
		var end:=start+dir*(2.5-.27*i)+Vector3.UP*(3.6-.34*i)
		_frustum(s,start,end,.22,.04,5,Color("#675342"))
		if dry:
			var tip:=end+dir*1.1+Vector3.UP*1.9
			_frustum(s, end.lerp(start,.46), tip,.10,.023,4,Color("#836b51"))
		else:
			_crown(s,end,Vector3(2.35+.38*sin(i),3.9,2.12),tree+i)
	if not dry:
		_crown(s,Vector3.UP*(h*.79),Vector3(1.8,h*.37,1.8),tree+2)
	return s.commit()

func _frustum(s:SurfaceTool,start:Vector3,finish:Vector3,base:float,tip:float,count:int,col:Color)->void:
	var along:=(finish-start).normalized()
	var ux:=along.cross(Vector3.FORWARD).normalized()
	var uy:=along.cross(ux)
	for i in count:
		var ang:=TAU*i/count
		var bng:=TAU*(i+1)/count
		var d1:=ux*cos(ang)+uy*sin(ang)
		var d2:=ux*cos(bng)+uy*sin(bng)
		var a:=start+d1*base
		var b:=start+d2*base
		var c:=finish+d1*tip
		var d:=finish+d2*tip
		_tri(s,a,c,b,col,d1,d1,d2)
		_tri(s,b,c,d,col.darkened(.035*(i%3)),d2,d1,d2)

func _crown(s:SurfaceTool,p:Vector3,scale:Vector3,seed:int)->void:
	const RING:=8
	const LAYERS:=5
	var layers:Array[PackedVector3Array]=[]
	var normals:Array[PackedVector3Array]=[]
	var wide:=1.28 if seed%3==0 else .88
	for j in LAYERS:
		var row:=PackedVector3Array()
		var out:=PackedVector3Array()
		var elevation:float=[-.84,-.47,.02,.52,.89][j]
		for i in RING:
			var a:=TAU*i/RING + .24*j
			var r:=sqrt(1.0-elevation*elevation)*(.85+.19*sin(3*i+j+seed))
			var unit:=Vector3(cos(a)*r*wide,elevation,sin(a)*r)
			row.append(p+unit*scale)
			out.append(unit.normalized())
		layers.append(row)
		normals.append(out)
	for j in LAYERS-1:
		for i in RING:
			var k:=(i+1)%RING
			var col:=Color("#344c30").lerp(Color("#687e43"),.32+.19*sin(seed+i*1.8)+j*.13)
			_tri(s,layers[j][i],layers[j][k],layers[j+1][i],col,
				normals[j][i],normals[j][k],normals[j+1][i])
			_tri(s,layers[j][k],layers[j+1][k],layers[j+1][i],col.lightened(.025),
				normals[j][k],normals[j+1][k],normals[j+1][i])
	for i in RING:
		var k:=(i+1)%RING
		_tri(s,layers[-1][i],layers[-1][k],p+Vector3.UP*scale.y,Color("#657b43"),
			normals[-1][i],normals[-1][k],Vector3.UP)
		_tri(s,layers[0][k],layers[0][i],p-Vector3.UP*scale.y,Color("#344c30"),
			normals[0][k],normals[0][i],Vector3.DOWN)

func _tri(s:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,col:Color,na:=Vector3.ZERO,nb:=Vector3.ZERO,nc:=Vector3.ZERO)->void:
	var face:=(c-a).cross(b-a).normalized()
	s.set_color(col)
	s.set_normal(na if na!=Vector3.ZERO else face)
	s.add_vertex(a)
	s.set_normal(nb if nb!=Vector3.ZERO else face)
	s.add_vertex(b)
	s.set_normal(nc if nc!=Vector3.ZERO else face)
	s.add_vertex(c)

func _forest() -> void:
	for i in 4:
		_variants.append(_build_tree(i,false))
		_dead.append(_build_tree(i,true))
	var near_meshes:Array[Mesh]=[_variants[0],_oak_mesh(false),_spruce_mesh(false),_dead[1]]
	var far_meshes:Array[Mesh]=[_coppice_lod(),_oak_mesh(true),_spruce_mesh(true),_dead[1]]
	var jitter:=RandomNumberGenerator.new()
	jitter.seed=83101307
	var sectors:Dictionary={}
	var total:=0
	var detailed:=0
	const CHUNK:=126.0
	# Jittered contiguous lattice with smoothly mixed species and canopy density.
	# No texture atlas cut line or separate elevated 'distant forest plane'.
	for ez in range(-103,59):
		for ex in range(-89,111):
			var p:=Vector2(ex,ez)*9.1+Vector2(jitter.randf_range(-4.,4.),jitter.randf_range(-4.,4.))
			var height_a:=ground_height(p.x,p.y)
			var drought:=_ridge(p.x,p.y,-24,0,82,67)
			var intermediate:=_ridge(p.x,p.y,4,-25,315,225)
			var cover:=_noise.get_noise_2d(p.x*.23,p.y*.23)
			var broad_cover:=_noise.get_noise_2d(p.x*.105+330.0,p.y*.105-186.0)
			var density:=clampf(.48 + .20*intermediate + .63*cover + .36*broad_cover
				- smoothstep(37.0,132.0,height_a)*.22 - drought*.44,0.04,.92)
			if jitter.randf() > density or p.distance_to(CAMP)<20 or p.distance_to(NURSERY+Vector2(9,-10))<33:
				continue
			if p.distance_to(Vector2(-21,-5))<21 or (intermediate>.23 and _blocks_road(p,8.5)):
				continue
			var chance:=jitter.randf()
			var type:=3 if drought>.72 else (2 if height_a>31.0+chance*34.0 else (1 if chance>.48 else 0))
			if type==3 and jitter.randf()>.37:
				continue
			var size:=jitter.randf_range(.52,1.25)
			if type==1:
				size*=jitter.randf_range(.68,1.05)
			var scale:=Vector3(size,size*jitter.randf_range(.85,1.17),size)
			var basis:=Basis(Vector3.UP,jitter.randf_range(0,TAU)).scaled(scale)
			if _filter_tree(p):
				continue
			var node_key:=Vector2i(floori(p.x/CHUNK),floori(p.y/CHUNK))
			if not sectors.has(node_key):
				sectors[node_key]=[[],[],[],[]]
			var extent:=Vector3(float(node_key.x)*CHUNK,0.0,float(node_key.y)*CHUNK)
			sectors[node_key][type].append(Transform3D(basis, Vector3(p.x,height_a-.23,p.y)-extent))
			total+=1
	for key:Vector2i in sectors:
		var extent:=Vector3(float(key.x)*CHUNK,0.0,float(key.y)*CHUNK)
		var close_to_trail:=Rect2(-325.0,-242.0,650.0,467.0).has_point(Vector2(extent.x,extent.z)+Vector2.ONE*CHUNK*.5)
		for type in 4:
			if sectors[key][type].is_empty():
				continue
			if close_to_trail and type!=3:
				_forest_batch(near_meshes[type],sectors[key][type],extent,0.,202.,true)
				_forest_batch(far_meshes[type],sectors[key][type],extent,202.,0.,false)
				detailed+=sectors[key][type].size()
			else:
				_forest_batch(far_meshes[type],sectors[key][type],extent,0.,0.,false)
	_add_undergrowth(jitter)
	print("Forest study: ",total," grounded stems, ",detailed," eligible for near canopy LOD; ",sectors.size()," sectors.")

func _blocks_road(p:Vector2,r:float)->bool:
	for j in range(0,_route_points.size(),4):
		var q:=_route_points[j]
		if Vector2(q.x,q.z).distance_squared_to(p)<r*r:
			return true
	return false

func _forest_batch(mesh:Mesh, plants:Array, origin:Vector3, from:float, to:float, casts:bool)->void:
	var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=mesh
	multimesh.instance_count=plants.size()
	for i in plants.size():
		multimesh.set_instance_transform(i,plants[i])
	var holder:=MultiMeshInstance3D.new()
	holder.position=origin
	holder.multimesh=multimesh
	holder.visibility_range_begin=from
	holder.visibility_range_end=to
	holder.visibility_range_begin_margin=8. if from>0. else 0.
	holder.visibility_range_end_margin=8. if to>0. else 0.
	holder.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)

func _canopy_surface()->SurfaceTool:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m:=_paint("#ffffff")
	m.vertex_color_use_as_albedo=true
	s.set_material(m)
	return s

func _coppice_lod()->Mesh:
	var s:=_canopy_surface()
	_frustum(s,Vector3.ZERO,Vector3.UP*9.0,.42,.09,5,Color("#61513d"))
	_simple_leaf(s,Vector3(0,8.4,0),Vector3(3.2,4.7,3.2),Color("#526e3b"),1)
	_simple_leaf(s,Vector3(1.4,6.7,.8),Vector3(2.1,2.3,2.2),Color("#446138"),5)
	return s.commit()

func _oak_mesh(far:bool)->Mesh:
	var s:=_canopy_surface()
	var bark:=Color("#69503b")
	_frustum(s,Vector3.ZERO,Vector3.UP*6.6,.72,.23,7,bark)
	for i in (3 if far else 5):
		var direction:=Vector3(cos(i*2.4),0,sin(i*2.4))
		var crown:=direction*(2.5 if i!=0 else .5)+Vector3.UP*(7.4+1.15*sin(i))
		_frustum(s,Vector3.UP*(2.8+.28*i),crown,.35,.10,5,bark.darkened(i*.032))
		var col:=Color("#5e7137").lerp(Color("#7b8248"),(i%3)*.23)
		_simple_leaf(s,crown,Vector3(3.9,2.2,3.35),col,3+i)
		if not far:
			var major:=crown+direction*2.7+Vector3.UP*.7
			_frustum(s,crown-Vector3.UP*.9,major,.11,.03,4,bark)
			_simple_leaf(s,major,Vector3(2.6,1.82,2.36),col.lightened(.035),11+i)
	if not far:
		_crown(s,Vector3(.5,10.3,.35),Vector3(4.18,2.7,3.64),11)
	return s.commit()

func _spruce_mesh(far:bool)->Mesh:
	var s:=_canopy_surface()
	_frustum(s,Vector3.ZERO,Vector3.UP*10.7,.48,.07,6,Color("#594e3f"))
	for i in (3 if far else 5):
		var ground_y:=3.6+i*(2.4 if far else 1.5)
		var width:=3.95-i*(.96 if far else .53)
		var sides:=7 if far else 10
		var tint:=Color("#385645").lightened(i*.044)
		var crown:=Vector3(.115*sin(i),ground_y,0.)
		for j in sides:
			var angle:=TAU*j/sides+i*.27
			var edge:=Vector3(cos(angle),0,sin(angle))*(width*(1.+.18*sin(j*2.6)))
			var an:=TAU*(j+1)/sides+i*.27
			var next:=Vector3(cos(an),0,sin(an))*(width*(1.+.18*sin((j+1)*2.6)))
			var root:=crown+edge+Vector3.UP*(.28*sin(j*1.7))
			var next_p:=crown+next+Vector3.UP*(.28*sin((j+1)*1.7))
			_tri(s,root,next_p,crown+Vector3.UP*(3.3 if far else 2.9),tint.lightened((j%3)*.024))
			_tri(s,crown+Vector3.DOWN*.28,next_p,root,tint.darkened(.16))
	return s.commit()

func _simple_leaf(s:SurfaceTool,p:Vector3,r:Vector3,tint:Color,seed:int)->void:
	var rim:=PackedVector3Array()
	for i in 7:
		var a:=TAU*i/7.0
		var n:=.84+.20*sin(i*2.18+seed)
		rim.append(Vector3(cos(a)*n,.15*cos(i*1.52+seed),sin(a)*n))
	for i in 7:
		var a:=rim[i]
		var b:=rim[(i+1)%7]
		_tri(s,p+a*r,p+b*r,p+Vector3.UP*r.y,tint.lightened((i%3)*.025),a.normalized(),b.normalized(),Vector3.UP)
		_tri(s,p+b*r,p+a*r,p-Vector3.UP*r.y,tint.darkened(.12),b.normalized(),a.normalized(),Vector3.DOWN)

func _filter_tree(_p:Vector2)->bool:
	return false

func _add_undergrowth(rng:RandomNumberGenerator)->void:
	var writes:Array=[]
	var clay:=_canopy_surface()
	_simple_leaf(clay,Vector3(0,.9,0),Vector3(1.18,1.0,1.25),Color("#657741"),8)
	_simple_leaf(clay,Vector3(-.65,.65,.53),Vector3(.92,.66,.80),Color("#7a8050"),14)
	_simple_leaf(clay,Vector3(.69,.72,-.63),Vector3(.78,.86,.85),Color("#4a6835"),3)
	var shrub:=clay.commit()
	for clump in 94:
		var p:=Vector2(rng.randf_range(-209.,212.),rng.randf_range(-100.,105.))
		if _blocks_road(p,11.0) or p.distance_to(CAMP)<18 or p.distance_to(NURSERY+Vector2(7,-10))<23 				or p.distance_to(Vector2(-21,-5))<27:
			continue
		for i in rng.randi_range(3,8):
			var q:=p+Vector2.from_angle(i*2.399)*rng.randf_range(.45,4.3)
			var size:=rng.randf_range(.51,1.1)
			var b:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size)
			writes.append(Transform3D(b,_at(q,-.04)))
	_forest_batch(shrub,writes,Vector3.ZERO,0.,198.,true)

func _positioned(mesh:Mesh,pos:Vector3,mat:Material, turn:=0.0) -> MeshInstance3D:
	var inst:=MeshInstance3D.new()
	inst.mesh=mesh
	inst.material_override=mat
	inst.position=pos
	inst.rotation.y=turn
	add_child(inst)
	return inst

func _timber(a:Vector3,b:Vector3,r:float,mat:Material, sides:=6)->void:
	var m:=CylinderMesh.new()
	m.top_radius=r*.85
	m.bottom_radius=r
	m.height=a.distance_to(b)
	m.radial_segments=sides
	m.rings=0
	var inst := _positioned(m,(a+b)*.5,mat)
	inst.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func _rock(pos:Vector3,s:Vector3,m:Material,angle:float)->void:
	var box:=PrismMesh.new()
	box.left_to_right=.42
	box.size=s
	_positioned(box,pos,m,angle)

func _stone_wall(origin:Vector2,width:float,depth:float, dir:float)->void:
	var right:=Vector2.from_angle(dir)
	var forward:=right.orthogonal()
	for i in int(width/1.1):
		for j in 2:
			var p:=origin+right*(i*1.1-width*.5 + .34*j) + forward*float(j)*.07
			var box:=BoxMesh.new()
			box.size=Vector3(1.05,.46,depth)*_rng.randf_range(.86,1.05)
			_positioned(box,_at(p,.26+j*.43),_base.stone if i%4!=0 else _base.washed,-dir)

func _camp()->void:
	_camp_pavilion()
	for i in 4:
		var a:=i*TAU/4.0
		var p:=CAMP + Vector2.from_angle(a)*12.5 + Vector2(-6,7)
		_lean_to(p,a+.4,i)
		var rock_point:=_at(p+Vector2(-1,5),.36)
		_rock(rock_point,Vector3(1.33,.65,1.2),_base.stone,float(i))
	var fire:=CAMP+Vector2(-6,7)
	for i in 10:
		_rock(_at(fire+Vector2.from_angle(i*TAU/10.0)*2.2,.32),Vector3(.76,.61,.83),_base.stone,i)
	var post:=_at(CAMP+Vector2(3.0,-5.2))
	_timber(post,post+Vector3.UP*7,.26,_base.wood)
	_timber(post+Vector3.UP*6.0,post+Vector3(4.2,6.0,0),.12,_base.wood)

func _lean_to(site:Vector2,angle:float,variant:int)->void:
	var parallel:=Vector2.from_angle(angle)
	var cross:=parallel.orthogonal()
	var span:=3.5+.17*variant
	var canvas:=SurfaceTool.new()
	canvas.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material:=_paint("#ffffff")
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	canvas.set_material(material)
	var cloth:=Color("#777450") if variant in [0,2] else Color("#90825c")
	for strip in range(-3,3):
		var t0:=strip*span/3.0
		var t1:=(strip+1)*span/3.0
		var seam_left:=_at(site+parallel*t0,2.7-.12*cos(strip*PI/3.0))
		var seam_right:=_at(site+parallel*t1,2.7-.12*cos((strip+1)*PI/3.0))
		var back_left:=_at(site+parallel*t0-cross*2.4,.61+.04*sin(strip*1.7))
		var back_right:=_at(site+parallel*t1-cross*2.4,.61+.04*sin((strip+1)*1.7))
		var drip_left:=_at(site+parallel*t0+cross*2.1,1.91+.11*cos(strip*PI/3.0))
		var drip_right:=_at(site+parallel*t1+cross*2.1,1.91+.11*cos((strip+1)*PI/3.0))
		var dye:=cloth.lightened(.035*((strip+12)%3))
		_tri(canvas,seam_left,back_left,seam_right,dye.darkened(.09))
		_tri(canvas,seam_right,back_left,back_right,dye.darkened(.13))
		_tri(canvas,drip_left,seam_left,seam_right,dye)
		_tri(canvas,drip_left,seam_right,drip_right,dye.lightened(.035))
	var ridge_from:=_at(site-parallel*span,2.7)
	var ridge_to:=_at(site+parallel*span,2.7)
	_timber(ridge_from,ridge_to,.10,_base.wood,7)
	for end in [-1.0,1.0]:
		var joint:Vector2=site+parallel*(float(end)*span*.91)
		_timber(_at(joint-cross*1.82),_at(joint,2.71),.105,_base.wood,7)
		_timber(_at(joint+cross*2.02),_at(joint+cross*2.02,1.93),.091,_base.wood,7)
	_positioned(canvas.commit(),Vector3.ZERO,null)

func _camp_pavilion()->void:
	# Root-cruck rain shelter: overlapping bark scales feed a dry stone collection trough.
	# Shelter center, existing approach, and all gameplay anchors are unchanged.
	var site:=CAMP+Vector2(-8,-2)
	var center:=_at(site)
	const SIDES:=10
	const COURSES:=9
	var roof:=SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cladding:=_paint("#ffffff")
	cladding.cull_mode=BaseMaterial3D.CULL_DISABLED
	cladding.vertex_color_use_as_albedo=true
	roof.set_material(cladding)
	var stained:=_paint("#644933")
	var sapwood:=_paint("#9a7852")
	var iron:=_paint("#637166")
	for i in SIDES:
		var a:=TAU*i/SIDES
		var next:=TAU*(i+1)/SIDES
		var u:=Vector3(cos(a),0,sin(a))
		var v:=Vector3(cos(next),0,sin(next))
		var foot:=_at(site+Vector2(u.x,u.z)*6.4)
		var knee:=center+u*6.73+Vector3.UP*2.9
		var top:=center+u*5.92+Vector3.UP*(4.85+cos(a)*.34)
		var next_top:=center+v*5.92+Vector3.UP*(4.85+cos(next)*.34)
		var hub:=center+Vector3.UP*8.55
		_rock(foot+Vector3.UP*.13,Vector3(1.07,.57,.99),_base.washed,a)
		_timber(foot,knee,.36,stained,7)
		_timber(knee,top,.3,_base.wood,7)
		_timber(knee+u*.21,knee.lerp(top,.49)+u*.21,.17,sapwood,7)
		_timber(top-u*.15,next_top,.22,stained,7)
		_timber(top,hub,.15,_base.wood)
		for band in 3:
			_timber(knee.lerp(top,.61+band*.065),knee.lerp(top,.65+band*.065),.338,_base.canvas)
		# Subroof eaves terminate above ground on high and low shoulders alike.
		_timber(_bark_roof_point(center,u,0.0),_bark_roof_point(center,v,0.0),.138,stained,7)
		for row in COURSES:
			var low:=float(row)/COURSES
			var high:=minf((row+1.24)/COURSES,1.0)
			for tile in 4:
				var start:float=float(tile)/4.0
				var stop:float=float(tile+1)/4.0
				var stagger:=sin(row*2.67+i)*.034
				var p0:=_bark_roof_point(center,u.lerp(v,start),low)+Vector3.UP*.15
				var p1:=_bark_roof_point(center,u.lerp(v,stop),low)+Vector3.UP*.12
				var p2:=_bark_roof_point(center,u.lerp(v,clampf(start+stagger,0,1)),high)
				var p3:=_bark_roof_point(center,u.lerp(v,clampf(stop+stagger,0,1)),high)
				var tint:float=.5+.5*sin(i*2.23+row*2.79+tile*3.3+sin(tile+row))
				var dye:=Color("#514535").lerp(Color("#a17d4d"),tint*.72+.19)
				if i in [4,5,6] and row<4:
					dye=dye.lerp(Color("#67724b"),.31)
				if row in [2,3] and i==2 and tile in [1,2]:
					dye=dye.lightened(.21)
				_tri(roof,p0,p2,p1,dye)
				_tri(roof,p1,p2,p3,dye.darkened(.05))
				_tri(roof,p0-Vector3.UP*.10,p0,p1,dye.darkened(.27))
				_tri(roof,p0-Vector3.UP*.10,p1,p1-Vector3.UP*.10,dye.darkened(.27))
		var bench_dir:=Vector2(u.x,u.z)*5.4
		if i%2==0 and i<8:
			var bench:=BoxMesh.new()
			bench.size=Vector3(2.4,.30,.76)
			_positioned(bench,_at(site+bench_dir,.59),stained,-a+PI*.5)
			for step in [-.62,.62]:
				var sit:Vector2=site+bench_dir+Vector2(-u.z,u.x)*float(step)
				_rock(_at(sit,.22),Vector3(.53,.56,.66),_base.washed,a)
	_positioned(roof.commit(),Vector3.ZERO,null)
	var trough:=site+Vector2(7.15,6.25)
	var barrel:=_at(trough)
	var channel:=center+Vector3(4.22,4.62,6.72)
	var spout:=Vector3(barrel.x,barrel.y+2.53,barrel.z)
	_timber(channel,spout,.19,sapwood,8)
	_timber(channel+Vector3(0,.08,.18),spout+Vector3(0,.08,.18),.09,stained,7)
	_timber(channel+Vector3(0,.08,-.18),spout+Vector3(0,.08,-.18),.09,stained,7)
	# Bare clay bed below the rim, not reflective water.
	var basin:=CylinderMesh.new()
	basin.top_radius=2.02
	basin.bottom_radius=1.82
	basin.height=.36
	basin.radial_segments=12
	_positioned(basin,barrel+Vector3.UP*.25,_paint("#6a5740"))
	for i in 12:
		var at:=trough+Vector2.from_angle(i*TAU/12.0)*2.11
		var tile:=BoxMesh.new()
		tile.size=Vector3(1.05,.59+.12*sin(i*4.2),.58)
		_positioned(tile,_at(at,.43),_base.washed if i%3==0 else _base.stone,-i*TAU/12.0+PI*.5)
		if i%2==0:
			_rock(_at(at,.78),Vector3(.81,.22,.72),iron,float(i))
	# Flat threshold stones follow the approach from the road toward the shelter.
	for i in 7:
		var at:=site+Vector2(4.75+i*.63,2.9+sin(i*.7)*.47)
		_rock(_at(at,.04),Vector3(1.07,.15,.80),_base.washed,.43*i)

func _bark_roof_point(center:Vector3,d:Vector3,t:float)->Vector3:
	var radius:=8.70*(1.0-t)+.27*t
	var height:=4.28+4.37*t+sin(t*PI)*.65
	return center+d*radius+Vector3.UP*(height+d.x*(1.0-t)*.32)

func _grove()->void:
	for i in 15:
		var p:=Vector2(-26,-10)+Vector2.from_angle(i*2.4)*_rng.randf_range(7,21)
		var tree:=_positioned(_dead[i%4],_at(p),null,i*.7)
		tree.scale=Vector3.ONE*_rng.randf_range(.51,.94)
	var spring:=Vector2(-21,-5)
	for i in 13:
		var at:=spring+Vector2.from_angle(i*TAU/13.0)*6
		_rock(_at(at,.24),Vector3(2.0,.55,1.7),_base.washed,i)
	preload("res://game/overworld/neris/grove_nursery_art.gd").build(self,NURSERY)

func _party()->void:
	$Party.position=_route_points[0]
	for ix in 4:
		var rider:=CapsuleMesh.new()
		rider.radius=.32
		rider.height=1.5
		var figurine:=MeshInstance3D.new()
		figurine.mesh=rider
		figurine.material_override=_base.dark if ix!=0 else _base.washed
		figurine.position=Vector3(1-ix*.9,.79,.35*(ix%2))
		$Party.add_child(figurine)

func _regional()->void:
	var toward:=Vector3(-5,10,0)
	$Camera.position=toward+CAMPAIGN_REGIONAL_OFFSET
	$Camera.look_at(toward)

func view_lens(close:bool) -> void:
	if close:
		_near(Vector2($Party.position.x,$Party.position.z))
	else:
		_regional()

func travel_lens() -> void:
	var target:Vector3=$Party.position
	$Camera.position=target+Vector3(-62,131,154)
	$Camera.look_at(target+Vector3.UP*5.0)

func _near(site:Vector2)->void:
	var toward:=_at(site,3)
	$Camera.position=toward+CAMPAIGN_NEAR_OFFSET
	$Camera.look_at(toward)

func _record()->void:
	await get_tree().process_frame
	_regional()
	await _photo("01-regional")
	_near(CAMP+Vector2(0,4))
	await _photo("02-camp")
	_near(NURSERY+Vector2(0,-8))
	await _photo("03-nursery")
	_near(Vector2(-21,-5))
	await _photo("04-old-grove")
	get_tree().quit()

func _photo(which:String)->void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg("/tmp/torn-neris-overworld/proof/"+which+".jpg",.9)


# Compatibility with shared MarchesView controls; no new bindings.
signal zoom_requested

func configure_overworld_art(_world,_clears,_reduced:bool)->void:
	pass

func show_party_state(_travelling:bool,_selected_id:String)->void:
	pass

func toggle_zoom(_at:Vector3)->void:
	_zoomed=not _zoomed
	zoom_requested.emit()
