extends RefCounted
## Decorative backdrop only. No collision, markers, routes, triggers, water or load state.
const MAT:=preload("res://game/overworld/raska/valley_horizon.gdshader")
func fit(site:Node3D)->void:
	var old:=site.get_node_or_null("WeatheredHorizon")
	if not old: return
	site.remove_child(old)
	old.free()
	var root:=MeshInstance3D.new()
	root.name=&"NeutralValleyContinuation"
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const GRID:=Vector2i(99,95)
	const DX:=22.0
	for row in range(GRID.y):
		for i in range(GRID.x):
			var p:=Vector2(-1067.+i*DX,-1034.+row*DX)
			# Inside stock BankRelief extents, continuation is always below the
			# original surface. Only decorative outlying land gently rolls upward.
			var edge:=maxf(absf(p.x)/890.,absf(p.y)/738.)
			var overlap:=smoothstep(.96,1.26,edge)
			var shelf:float=site.ground(p)-5.0-2.0*(1.0-overlap)
			var cut:float=(1.0-smoothstep(42.,172.,absf(p.y-site.center(p.x))))
			var range_:=hill(p,Vector2(434,829),Vector2(420,195),65.)+hill(p,Vector2(623,986),Vector2(342,364),91.)
			range_+=hill(p,Vector2(1196,690),Vector2(391,502),105.) + hill(p,Vector2(1127,-277),Vector2(346,605),125.)
			range_+=hill(p,Vector2(-484,945),Vector2(430,237),83.) + hill(p,Vector2(332,-900),Vector2(564,285),74.)
			range_+=hill(p,Vector2(-589,-886),Vector2(355,350),118.)
			var y:=shelf + overlap*range_*(1.0-.86*cut)
			surface.add_vertex(Vector3(p.x,y,p.y))
	for j in range(GRID.y-1):
		for i in range(GRID.x-1):
			var a:=j*GRID.x+i
			var b:=a+GRID.x
			for k in [a,a+1,b,a+1,b+1,b]: surface.add_index(k)
	surface.generate_normals()
	root.mesh=surface.commit()
	root.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new()
	material.shader=MAT
	root.material_override=material
	site.add_child(root)

static func hill(p:Vector2,c:Vector2,r:Vector2,h:float)->float:
	return exp(-((p-c)/r).length_squared()*2.0)*h
