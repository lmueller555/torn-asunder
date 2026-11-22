extends "res://game/overworld/raska/spanwater_relief.gd"
## Host adapter of unchanged shared scenery; only north terrain is a Raska seam.
const NORTH_XZ:=Vector2(-108,-42)
var north_ground:=Vector3.INF
func prepare_exact_land()->bool:
	if north_ground.is_finite(): return true
	_noise.seed=132955
	_noise.frequency=.036
	_land()
	var land:=get_node_or_null(^"BankRelief") as MeshInstance3D
	if not land: return false
	north_ground=preload("res://game/overworld/raska/seam_floor.gd").foot(land.mesh,NORTH_XZ)
	return north_ground.is_finite() and north_ground.y>4.9

func _land()->void:
	if not get_node_or_null(^"BankRelief"):
		super._land()

func _ready()->void:
	if not prepare_exact_land(): return
	super._ready()
	get_node("BankRelief").create_trimesh_collision()
	set_lens(false)
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("#82968f")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("#d2d3c8")
	e.ambient_light_energy=.54
	e.fog_enabled=true
	e.fog_density=.00042
	e.fog_light_color=Color("#8b9b93")
	var world:=WorldEnvironment.new()
	world.environment=e
	add_child(world)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-52,0)
	light.light_color=Color("#f9e9cf")
	light.light_energy=.92
	light.shadow_enabled=true
	add_child(light)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	_replace_north_scrub()
	var dressing:=preload("res://game/overworld/raska/north_approach.gd").new()
	var art:Node3D=dressing.build(self)
	add_child(art)
	var valley:=preload("res://game/overworld/raska/north_valley.gd").new()
	var pass_:Node3D=valley.mount(self)
	add_child(pass_)
	preload("res://game/overworld/raska/valley_horizon.gd").new().fit(self)
	if valley.seats<200 or valley.minimum_height<1.55 or valley.clear_min<7.5 or pass_.find_children("*","CollisionObject3D",true,false).size()>0:
		push_error("North valley art preflight failed.")


func _replace_north_scrub()->void:
	# Preserve every out-of-zone stock tree (including all south context).
	for label:String in ["LayeredBankCrowns","DownstreamScrub","NativeBankTrunks"]:
		var old:=get_node_or_null(NodePath(label)) as MultiMeshInstance3D
		if not old or not old.multimesh: continue
		var keep:Array[Transform3D]=[]
		for i in range(old.multimesh.instance_count):
			var pose:=old.multimesh.get_instance_transform(i)
			var p:=Vector2(pose.origin.x,pose.origin.z)
			if not Rect2(-239,-102,192,83).has_point(p): keep.append(pose)
		var result:=MultiMesh.new()
		result.transform_format=MultiMesh.TRANSFORM_3D
		result.mesh=old.multimesh.mesh
		result.instance_count=keep.size()
		for i in range(keep.size()): result.set_instance_transform(i,keep[i])
		old.multimesh=result

func set_lens(close:bool)->void:
	var c:Camera3D=$Camera
	c.fov=46.0 if close else 47.0
	c.position=Vector3(-162,56,-89) if close else Vector3(-249,123,-167)
	c.look_at(Vector3(-99,4.8,-35) if close else Vector3(-65,4.0,-20))
