extends RefCounted
## Original provisional Moonwash Scout Camp mesh. All built elements have
## individually surveyed footing; this never modifies the coast collision.

const SURFACES := preload("res://game/overworld/moonwash/ilyra_camp_surfaces.gdshader")
const PAD := preload("res://game/overworld/moonwash/ilyra_camp_pad.gdshader")
const PALETTE := {
	&"cloth": Color("#cbc09a"), &"stripe": Color("#4a6767"), &"trim": Color("#344b4d"),
	&"wood": Color("#65523e"), &"endgrain": Color("#997752"), &"stone": Color("#837965"),
	&"stone_dark": Color("#5c594f"), &"metal": Color("#a59364"),
}

var _faces: Dictionary = {}
var _probe: Callable
var _feet := PackedVector3Array()
var _sinks := PackedFloat32Array()
var _failed := false


func build(probe: Callable, is_regional := false) -> MeshInstance3D:
	_probe = probe
	if is_regional:
		# Same physical place/footprint, fewer surfaces and bolder canvas/rig,
		# so the map silhouette resolves under regional distance fog.
		_shelter(Vector2(-5.6, -3.5), 5.9, 4.35, 2.9, 0.15, true)
		_shelter(Vector2(-4.0, 5.15), 4.35, 3.55, 2.4, -0.37, true)
		_shelter(Vector2(4.0, 6.8), 3.9, 3.15, 2.25, 0.29, true)
		_signal_mast(Vector2(-.7, -4.7), true)
		return _finish("IlyraScoutCampRegional", true)
	# Wide approach opens toward the dotted route. The working deck and two
	# canvas shelters sit on staggered terraces rather than a flat foundation.
	_shelter(Vector2(-5.6, -3.5), 5.9, 4.35, 2.9, 0.15)
	_shelter(Vector2(-4.0, 5.15), 4.35, 3.55, 2.4, -0.37)
	_shelter(Vector2(4.0, 6.8), 3.9, 3.15, 2.25, 0.29)
	_signal_mast(Vector2(-.7, -4.7))
	_workbench(Vector2(2.4, 2.1))
	for i in range(11):
		var t := float(i) / 10.0
		var angle := deg_to_rad(12.0 + 140.0 * t)
		var point := Vector2(1.2, 2.6) + Vector2(cos(angle), sin(angle)) * Vector2(8.2, 6.9)
		var base := _foot(point, 0.08)
		var twist := angle + 0.98 + sin(float(i) * 2.3) * 0.17
		var rise := 0.31 + absf(sin(float(i) * 1.6)) * 0.13
		_block(base, Vector3(1.46 + cos(float(i)) * 0.21, rise, 0.89), twist, &"stone" if i % 3 else &"stone_dark")
		if i < 3 or i > 7:
			_block(base + Vector3(0.07, rise - .06, -0.04), Vector3(1.15 + cos(float(i) * 1.3) * .15, 0.31, 0.64), twist + 0.08, &"stone")
	return _finish("IlyraScoutCamp", false)


func _finish(node_name: String, is_regional: bool) -> MeshInstance3D:
	if _failed:
		return null
	var mesh := ArrayMesh.new()
	for key: StringName in _faces:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point: Vector3 in _faces[key]:
			surface.add_vertex(point)
		surface.generate_normals()
		var material := ShaderMaterial.new()
		material.shader = SURFACES
		material.resource_name = "Ilyra campsite " + key
		var material_index := 0
		if key in [&"wood",&"endgrain"]:
			material_index = 1
		elif key in [&"stone",&"stone_dark"]:
			material_index = 2
		elif key == &"metal":
			material_index = 3
		material.set_shader_parameter(&"base_tint", PALETTE[key])
		material.set_shader_parameter(&"stock", material_index)
		material.set_shader_parameter(&"regional", is_regional)
		surface.set_material(material)
		surface.commit(mesh)
	var art := MeshInstance3D.new()
	art.name = node_name
	art.mesh = mesh
	art.set_meta(&"surveyed_feet", _feet)
	art.set_meta(&"foot_inset_metres", _sinks)
	return art


func _shelter(center: Vector2, length: float, width: float, peak: float, yaw: float, is_regional := false) -> void:
	var beds: Array[Vector3] = []
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.5, 0.5]:
			beds.append(_foot(center + Vector2(x * length, z * width).rotated(yaw), 0.07))
	var start := (_foot(center + Vector2(-length * 0.43, 0).rotated(yaw), 0.06)
		+ Vector3.UP * peak)
	var finish := (_foot(center + Vector2(length * 0.43, 0).rotated(yaw), 0.06)
		+ Vector3.UP * peak)
	if not is_regional:
		for i in range(4):
			_beam(beds[i], beds[i] + Vector3.UP * 0.66, .12)
			_block(beds[i], Vector3(.34,.13,.31), yaw, &"stone")
		_beam(start - Vector3.UP * peak, start, .16)
		_beam(finish - Vector3.UP * peak, finish, .16)
		_beam(start, finish, .13)
	for side in range(2):
		var left := beds[side] + Vector3.UP * 0.52
		var right := beds[side + 2] + Vector3.UP * 0.52
		if is_regional:
			_quad(left.lerp(right,.21), start.lerp(finish,.21), finish, right, &"cloth")
			_quad(left, start, start.lerp(finish,.21), left.lerp(right,.21), &"stripe")
		else:
			for stripe in range(9):
				var a := float(stripe) / 9.0
				var b := float(stripe + 1) / 9.0
				var outer_a := _sag_edge(left, right, a)
				var outer_b := _sag_edge(left, right, b)
				var ridge_a := start.lerp(finish, a)
				var ridge_b := start.lerp(finish, b)
				var fold_a := outer_a.lerp(ridge_a, .48) + Vector3.DOWN * (.16 + .08 * sin(PI * a))
				var fold_b := outer_b.lerp(ridge_b, .48) + Vector3.DOWN * (.16 + .08 * sin(PI * b))
				var color := &"stripe" if stripe in [0, 4, 8] else &"cloth"
				_quad(outer_a, fold_a, fold_b, outer_b, color)
				_quad(fold_a, ridge_a, ridge_b, fold_b, color)
				_beam(outer_a, outer_b, .032, &"trim")
				if stripe in [1, 4, 7]:
					_beam(fold_a, ridge_a, .018, &"trim")
		if is_regional:
			_quad(beds[side], left, right, beds[side + 2], &"trim")
	if is_regional:
		_tri(beds[0], start, beds[1], &"stripe")
		return
	# Dark back seam and a front tie-up read differently at near camera.
	var back_l := beds[0] + Vector3.UP * .57
	var back_r := beds[1] + Vector3.UP * .57
	_tri(back_l, start, back_r, &"stripe")
	_quad(back_l, back_r, beds[1] + Vector3.UP * .12, beds[0] + Vector3.UP * .12, &"trim")
	_beam(beds[2] + Vector3.UP * .60, beds[3] + Vector3.UP * .60, .06, &"trim")
	for side in range(2,4):
		var delta := Vector2(beds[side].x, beds[side].z) - center
		var stake := _foot(center + delta * 1.19, 0.055)
		_beam(stake, stake + Vector3.UP * .28, .065)
		_beam(stake + Vector3.UP * .16, beds[side] + Vector3.UP * .73, .025, &"trim")


func _sag_edge(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * (.13 * sin(PI * t))


func _signal_mast(point: Vector2, is_regional := false) -> void:
	var anchor := _foot(point, 0.15)
	var top := anchor + Vector3.UP * 7.6
	_beam(anchor, top, .39 if is_regional else .27)
	_block(anchor + Vector3.UP * .24, Vector3(1.55, .6, 1.5), .17, &"stone_dark")
	if not is_regional:
		for i in range(3):
			var angle := TAU * float(i) / 3.0 + .35
			var pad := _foot(point + Vector2(cos(angle), sin(angle)) * 1.35, .09)
			_beam(pad, anchor + Vector3.UP * 2.0, .17)
			_block(pad, Vector3(.52,.23,.43), angle, &"stone")
	var pole := top - Vector3.UP * .44
	var arm := Vector3(2.72, 0, .54)
	if not is_regional:
		var stay := _foot(point + Vector2(-1.4, 1.7), .065)
		_beam(stay, pole - arm * .31, .045, &"trim")
		_beam(stay + Vector3.UP * .18, stay, .11)
	_beam(pole - arm * .53, pole + arm * .53, .13, &"endgrain")
	for i in range(3):
		var a := float(i) / 3.0 - .47
		var b := float(i + 1) / 3.0 - .47
		var p := pole + arm * a
		var q := pole + arm * b
		_quad(p, q, q + Vector3(0,-1.88,.38), p + Vector3(0,-2.12,.38),
			&"stripe" if i != 1 else &"cloth")
	# Burnished raised signal cup and cross-finial, not a navigation light effect.
	_block(top, Vector3(.47,.35,.47), .18, &"metal")


func _workbench(point: Vector2) -> void:
	var max_top := -INF
	var legs := PackedVector3Array()
	for p: Vector2 in [Vector2(-1.4,-.72),Vector2(1.4,-.72),Vector2(-1.4,.72),Vector2(1.4,.72)]:
		var at := _foot(point + p, .05)
		legs.append(at)
		max_top = maxf(max_top, at.y)
	var top := max_top + 0.94
	for corner in legs:
		_beam(corner, Vector3(corner.x,top,corner.z), .14)
	for plank in range(5):
		_block(Vector3(point.x, top, point.y + (plank - 2) * .33), Vector3(3.26,.17,.30), 0.0, &"endgrain")
	for marker in range(4):
		var at := _foot(point + Vector2(1.85 + (marker % 2) * .56, (marker / 2.0 - 1.0) * .68), .06)
		_block(at, Vector3(.60,.49,.57), marker * .22, &"wood")
		_block(at + Vector3.UP * .46, Vector3(.65,.08,.62), marker * .22, &"endgrain")
	_block(Vector3(point.x + .10,top + .10,point.y), Vector3(1.16,.04,.68), .13, &"cloth")


## Surveyed conforming overlay, rendered only where the weathered footprint
## has nonzero coverage. It follows real terrain and never adds solid collision.
func build_pad(probe: Callable) -> MeshInstance3D:
	var pad := SurfaceTool.new()
	pad.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := {}
	var fades := {}
	const STEP := .65
	const APPROACH := [Vector2(0,0), Vector2(4,-3), Vector2(10,-6), Vector2(15,-9),
		Vector2(20,-14), Vector2(23,-20),Vector2(27,-24),Vector2(28.581,-25.37849)]
	for x in range(-24, 53):
		for z in range(-45, 25):
			var at := Vector2(x, z) * STEP
			var body := ((at - Vector2(0, 2.0)) / Vector2(11.8, 10.0)).length()
			var approach := INF
			for i in range(1, APPROACH.size()):
				approach = minf(approach, at.distance_to(
					Geometry2D.get_closest_point_to_segment(at, APPROACH[i - 1], APPROACH[i])))
			var softness := .08 * sin(at.x * 1.3 + sin(at.y * 3.1)) * cos(at.y * .97)
			var dirt := maxf(1.0 - smoothstep(.71, 1.14, body + softness), .67 * (1.0 - smoothstep(.85, 2.15, approach)))
			if dirt <= .008:
				continue
			var hit: Variant = probe.call(at)
			if hit is Vector3:
				samples[Vector2i(x,z)] = hit + Vector3.UP * .035
				fades[Vector2i(x,z)] = dirt
	for cell: Vector2i in samples:
		var east := cell + Vector2i.RIGHT
		var south := cell + Vector2i.DOWN
		var corner := cell + Vector2i.ONE
		if not samples.has(east) or not samples.has(south) or not samples.has(corner):
			continue
		for point in [cell,east,corner,cell,corner,south]:
			pad.set_color(Color(1.0,1.0,1.0,fades[point]))
			pad.add_vertex(samples[point])
	pad.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = PAD
	pad.set_material(mat)
	var art := MeshInstance3D.new()
	art.name = "IlyraSurveyedCampGround"
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.mesh = pad.commit()
	art.set_meta(&"native_samples", samples.size())
	return art


func _foot(point: Vector2, inset: float) -> Vector3:
	var result: Variant = _probe.call(point)
	if result is not Vector3 or not result.is_finite():
		_failed = true
		return Vector3(point.x, 0, point.y)
	var local := (result as Vector3) - Vector3.UP * inset
	_feet.append(local)
	_sinks.append(inset)
	return local


func _block(base: Vector3, extent: Vector3, yaw: float, key: StringName) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var u := basis.x * extent.x * .5
	var v := basis.z * extent.z * .5
	_prism(base - u - v, base + u - v, base + u + v, base - u + v, Vector3.UP * extent.y, key)


func _beam(start: Vector3, finish: Vector3, thickness: float, key: StringName = &"wood") -> void:
	var long := finish - start
	if long.length_squared() < 0.000001:
		return
	var d := long.normalized()
	var selected_axis := Vector3.FORWARD if absf(d.dot(Vector3.UP)) > .92 else Vector3.UP
	var u := d.cross(selected_axis).normalized() * thickness * .5
	var v := d.cross(u).normalized() * thickness * .5
	_prism(start - u - v, start + u - v, start + u + v, start - u + v, long, key)


func _prism(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, key: StringName) -> void:
	_quad(a,d,c,b,key)
	_quad(a+n,b+n,c+n,d+n,key)
	_quad(a,b,b+n,a+n,key)
	_quad(b,c,c+n,b+n,key)
	_quad(c,d,d+n,c+n,key)
	_quad(d,a,a+n,d+n,key)


func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,key: StringName) -> void:
	_tri(a,b,c,key)
	_tri(a,c,d,key)


func _tri(a: Vector3,b: Vector3,c: Vector3,key: StringName) -> void:
	if not _faces.has(key):
		_faces[key] = PackedVector3Array()
	var points := _faces[key] as PackedVector3Array
	points.append_array(PackedVector3Array([a,b,c]))
	_faces[key] = points
