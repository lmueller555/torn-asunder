extends Node3D
## Passive stone talus on the existing closed branch. Not flood scenery.
const Placer := preload("res://game/overworld/spanwater/landing_addon.gd")
const StoneShader := preload("res://game/overworld/spanwater/closed_cut_stone.gdshader")
var _pads: Placer
var samples: Array[Vector3] = []

func _ready() -> void:
	_pads = get_parent().get_node("SouthBankStagingDressing") as Placer
	# Work beyond the existing sea-gate prop and north of no route. Centrelines,
	# nodes, rendered flow, physical levels, and the existing banks stay put.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		for shelf in range(4):
			var previous: PackedVector3Array = []
			for i in range(61):
				var u := float(i)/60.0
				var z := 104.0 + u*150.0
				var branch_x := 4.0 + (z-103.0)*14.0/117.0
				var toe := 8.6 + shelf*2.65 + .72*sin(z*.085+shelf*1.2) + .42*sin(z*.31+side)
				var width_ := (.88 + .24*sin(z*.19+shelf) + .14*sin(z*.49)) * smoothstep(0.,.10,u)*(1.-smoothstep(.76,1.,u))
				var w := width_ * (1.0 + shelf*.15)
				var x := branch_x + toe*side
				var entry := _fit(x-side*w,z,.035)
				var nose := _fit(x,z,.36 + .15*sin(z*.23+shelf))
				var back := _fit(x+side*w,z,.018)
				var row := PackedVector3Array([entry,nose,back])
				if not previous.is_empty():
					_strip(st,previous,row,shelf)
				previous = row
	var model := MeshInstance3D.new()
	model.name = "StratifiedSouthGully"
	st.generate_normals()
	model.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = StoneShader
	model.material_override = material
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)

func _fit(x: float, z: float, offset: float) -> Vector3:
	var y := _pads._ground(x,z)
	var p := Vector3(x,y+offset,z)
	samples.append(p)
	return p

func _strip(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array, shelf: int) -> void:
	for i in range(2):
		st.set_color(Color(.8 if i==0 else .48,float(shelf)/4.,0,1))
		for p in [a[i],b[i],a[i+1],a[i+1],b[i],b[i+1]]:
			st.add_vertex(p)
