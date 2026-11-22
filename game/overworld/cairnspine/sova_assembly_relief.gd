extends "res://game/overworld/cairnspine/pass_relief.gd"
## The Year Three connector ends at the common civic court.
## Leave other provisional architecture unmounted; no hearing dressing.

func _forecourt() -> void:
	pass


func _witness_wall() -> void:
	pass


func _anchors() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "SurveyAnchors"
	add_child(landmarks)
	for item in [["ValleyApproach",VALLEY_ENTRY[0]],["Assembly",ASSEMBLY],["SafeStaging",STAGING]]:
		var pin := Marker3D.new()
		pin.name = item[0]
		pin.position = at(item[1])
		landmarks.add_child(pin)


func _assembly() -> void:
	var marker := preload("res://game/overworld/cairnspine/sova_assembly_court.gd")
	add_child(marker.make(at,ASSEMBLY))


func _pine(height: float,width: float,seed_: float) -> ArrayMesh:
	return _tree_mesh(height,width,seed_,8,12)


func _tree_mesh(height: float,width: float,seed_: float,strata_count: int,faces: int) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	_crown(st,0,8.7*height,.20,.037,8,Color("#6b5840"),0.0,.06,0.0)
	# Rounded normal bands form uneven shelves instead of nested black cones.
	for band_index in range(strata_count):
		var band:=float(band_index)*7.0/(strata_count-1)
		var y:=(1.0+band*.96)*height
		var tip:=y+(2.37-band*.08)*height
		var span:=(2.39-band*.24)*width
		var color:=Color("#385041").lerp(Color("#63734a"),band*.12)
		_needles(st,y,tip,span,band*.62+seed_,color,faces)
	return st.commit()


func _needles(st: SurfaceTool, lower: float,upper: float,span: float,phase: float,tone: Color,faces: int) -> void:
	var rings: Array[PackedVector3Array]=[]
	var widths: Array[float] = [.71,1.0,.66,.16]
	var strata: Array[float] = [0.0,.19,.58,1.0]
	for r in range(4):
		var ring:=PackedVector3Array()
		for i in range(faces):
			var a:=float(i)*TAU/float(faces)+phase
			var reach:=span*widths[r]*(1.0+.22*sin(a*3.0+phase)+.14*cos(a*5.0-phase))
			var y:=lerpf(lower,upper,strata[r])+sin(i*3.44+phase)*.19
			ring.append(Vector3(cos(a)*reach + strata[r]*.24*sin(phase),y,sin(a)*reach))
		rings.append(ring)
	for r in range(3):
		for i in range(faces):
			var j:=(i+1)%faces
			for item: Vector3 in [rings[r][i],rings[r+1][j],rings[r+1][i],rings[r][i],rings[r][j],rings[r+1][j]]:
				var direction := Vector3(item.x,.45*span,item.z).normalized()
				st.set_normal(direction)
				st.set_color(tone.lightened(.12*absf(cos(i*1.44+r+phase))).srgb_to_linear())
				st.add_vertex(item)


func _batch(name_: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if name_ not in ["ClosedPineCrowns","OpenSpurCrowns"]:
		super._batch(name_,mesh,material,transforms)
		return
	var close: Array[Transform3D] = []
	var far: Array[Transform3D] = []
	for placement in transforms:
		var xz:=Vector2(placement.origin.x,placement.origin.z)
		if xz.distance_to(ASSEMBLY)<103.0:
			close.append(placement)
		else:
			far.append(placement)
	var wide:=name_=="OpenSpurCrowns"
	super._batch(name_,mesh,material,close)
	super._batch(name_+"Regional",_tree_mesh(.83 if wide else 1.0,1.24 if wide else 1.0,1.88 if wide else .31,5,7),material,far)
	var regional := get_node(NodePath(name_+"Regional")) as MultiMeshInstance3D
	regional.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _draw_terrain() -> void:
	# Sample this preview's same geological function once per vertex. Use
	# neighboring verified samples for normals instead of five whole relief
	# solves per vertex during the cancellable preflight.
	var dims := Vector2i(159,151)
	var spacing := (HI-LO)/Vector2(dims-Vector2i.ONE)
	var samples := PackedVector3Array()
	samples.resize(dims.x*dims.y)
	for row in range(dims.y):
		for col in range(dims.x):
			var p := LO+Vector2(col,row)*spacing
			samples[row*dims.x+col]=Vector3(p.x,ground(p),p.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(dims.y):
		for col in range(dims.x):
			var index := row*dims.x+col
			var pos := samples[index]
			var tangent := samples[row*dims.x+mini(col+1,dims.x-1)] - samples[row*dims.x+maxi(0,col-1)]
			var bitangent := samples[mini(row+1,dims.y-1)*dims.x+col] - samples[maxi(row-1,0)*dims.x+col]
			st.set_normal(bitangent.cross(tangent).normalized())
			st.set_color(Color(_paint_track(Vector2(pos.x,pos.z)),0,0,1))
			st.add_vertex(pos)
	for row in range(dims.y-1):
		for col in range(dims.x-1):
			var top := row*dims.x+col
			var below := top+dims.x
			for index in [top,top+1,below,top+1,below+1,below]:
				st.add_index(index)
	var field := MeshInstance3D.new()
	field.name="SurveyRelief"
	field.mesh=st.commit()
	var pigment := ShaderMaterial.new()
	pigment.shader=GROUND
	field.material_override=pigment
	add_child(field)
