extends Node3D
## Original map-scale Year Four entrance. Not terrain for the Pass Writ battle.
signal presentation_camera_changed
const World := preload("res://game/campaign_world.gd")
const TerrainMaterial := preload("res://game/overworld/sereth/keeper_ground.gdshader")
const Dressing := preload("res://game/overworld/sereth/keeper_work.gd")
const STEP := 2.35
const X0 := -272.
const Z0 := -205.
const NX := 226
const NZ := 174
const ARRIVAL := Vector2(-29.,3.)
const POST := Vector2(12.5,-10.1)
const ROAD_START := -157.
const ROAD_END := 126.
var _zoomed := false
@onready var _camera: Camera3D = $Camera

func _ready() -> void:
	_ground()
	Dressing.new().build(self)
	_view()

func configure_overworld_art(_world: World,_clears: PackedStringArray,_reduced: bool) -> void:
	pass

func show_party_state(_moving: bool,_selected: String) -> void:
	pass

func toggle_zoom(_where: Vector3) -> void:
	_zoomed = not _zoomed
	_view()

func _view() -> void:
	_camera.fov = 48.0 if _zoomed else 56.0
	_camera.position = Vector3(-56,43,54) if _zoomed else Vector3(-118,149,142)
	_camera.look_at(Vector3(-9,3,-1) if _zoomed else Vector3(-8,10,-16))
	presentation_camera_changed.emit()

static func road(x: float) -> float:
	return 2.0 - 8.7*sin((x+26.)*.014) + 5.2*sin((x+33.)*.033)

static func track(x: float) -> float:
	return road(x) + (7.0 + 27.0*pow(.5+.5*cos((x+10.0)*.021),1.45)) \
		* smoothstep(-118.,-84.,x)*(1.-smoothstep(60.,106.,x))

static func field(p: Vector2) -> float:
	var x := p.x
	var z := p.y
	var base := 4.1 + 3.6*cos(x*.020-z*.013)+1.25*sin(z*.058+x*.034)
	var ridge := _ridge(p,Vector2(13,-101),Vector2(147,46),36.0) \
		+_ridge(p,Vector2(-150,-154),Vector2(118,61),50.5) \
		+_ridge(p,Vector2(132,-146),Vector2(123,56),61.0) \
		+_ridge(p,Vector2(-112,100),Vector2(107,52),18.0) \
		+_ridge(p,Vector2(108,90),Vector2(135,75),15.0)
	base += ridge*(.86+.14*sin(.097*x + .11*z)) + .73*sin(z*.126-x*.102)
	var slope := 5.45 + .018*x + 1.3*sin(x*.027)
	var path := 1.0 - smoothstep(3.6,20.4,absf(z-road(x)))
	base=lerpf(base,slope,path)
	var lower := 1.0 - smoothstep(2.05,11.,absf(z-track(x)))
	var channel := smoothstep(-110.,-74.,x)*(1.0-smoothstep(62.,103.,x))
	base=lerpf(base,slope-channel*(3.7+.80*cos((x-13.)*.035)),lower*channel)
	var floor_area := 1.0 - smoothstep(.56,1.3,((p-POST)/Vector2(17,12)).length())
	return lerpf(base,5.77+.010*x,floor_area)

static func _ridge(p: Vector2,c: Vector2,rad: Vector2,h: float) -> float:
	return h*exp(-((p-c)/rad).length_squared()*2.15)

static func at(p: Vector2, lift := .0) -> Vector3:
	var grid := (p-Vector2(X0,Z0))/STEP
	var cell := Vector2(clampf(floorf(grid.x),0,NX-2),clampf(floorf(grid.y),0,NZ-2))
	var uv := (grid-cell).clamp(Vector2.ZERO,Vector2.ONE)
	var q := Vector2(X0,Z0)+cell*STEP
	var b := field(q+Vector2(STEP,0))
	var c := field(q+Vector2(0,STEP))
	var y := field(q)*(1.-uv.x-uv.y)+b*uv.x+c*uv.y if uv.x+uv.y<=1. \
		else field(q+Vector2.ONE*STEP)*(uv.x+uv.y-1.)+b*(1.-uv.y)+c*(1.-uv.x)
	return Vector3(p.x,y+lift,p.y)

static func road_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval=.75
	for i in range(285):
		var x := lerpf(ROAD_START,ROAD_END,float(i)/284.)
		curve.add_point(at(Vector2(x,road(x)),.18))
	return curve

func mount_ready() -> bool:
	return has_node("KeeperRelief/KeeperGroundBody") and has_node("NeutralKeeperPost") and at(ARRIVAL).is_finite()

func _ground() -> void:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in NZ:
		for i in NX:
			var p := Vector2(X0+i*STEP,Z0+j*STEP)
			var dr := absf(p.y-road(p.x))
			var dt := absf(p.y-track(p.x))
			var grass := 1.0-smoothstep(1.55,5.7,dr)
			var sheep := (1.0-smoothstep(.80,3.1,dt))*smoothstep(-118.,-80.,p.x)*(1.-smoothstep(61.,105.,p.x))
			var yard := 1.0-smoothstep(7.,14.,p.distance_to(POST))
			s.set_color(Color(maxf(grass,yard*.65),sheep,0,1))
			s.add_vertex(Vector3(p.x,field(p),p.y))
	for j in NZ-1:
		for i in NX-1:
			var a := j*NX+i
			var b := a+NX
			for k: int in [a,a+1,b,a+1,b+1,b]:
				s.add_index(k)
	s.generate_normals()
	var node := MeshInstance3D.new()
	node.name="KeeperRelief"
	node.mesh=s.commit()
	var m := ShaderMaterial.new()
	m.shader=TerrainMaterial
	node.material_override=m
	add_child(node)
	node.create_trimesh_collision()
	for child in node.get_children():
		if child is StaticBody3D:
			child.name="KeeperGroundBody"
			child.collision_layer=2
			child.collision_mask=0
