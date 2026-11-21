@tool
extends Node3D
## Visual-only entrance kit in meters. +Y up, -Z toward the approach.
## Editable dimensions, hewn surfaces, and fittings are generated once per
## instance. Position it over a level opening; the caller retains collision.

const StoneShoulder := preload("res://assets/models/mine_timber_portal/connected_stone_shoulder.gd")
const WallMaterial := preload("res://assets/models/mine_timber_portal/connected_stone_shoulder.gdshader")
const WallColor := preload("res://assets/models/mine_timber_portal/shoulder_diffuse_roughness.png")
const WallNormal := preload("res://assets/models/mine_timber_portal/shoulder_tangent_normal.png")
const WallRelief := preload("res://assets/models/mine_timber_portal/shoulder_relief.png")
const Timber := preload("res://assets/models/mine_timber_portal/weathered_timber.gdshader")
const Stone := preload("res://assets/models/mine_timber_portal/quarried_stone.gdshader")
const Metal := preload("res://assets/models/mine_timber_portal/forged_iron.gdshader")
const IronPores := preload("res://assets/models/mine_timber_portal/iron_normal.png")
const IronMask := preload("res://assets/models/mine_timber_portal/iron_surface.png")
const StonePores := preload("res://assets/models/mine_timber_portal/stone_normal.png")
const StoneMask := preload("res://assets/models/mine_timber_portal/stone_surface.png")
const BAND_Y := [0.73, 3.84]
const SHOULDER_X := 5.0
const DETAIL_RANGE := 52.0
# The renderer uses each instance's AABB center for visibility ranges.
# A lantern must not switch tiers separately from the wall or lintel.
const LOD_BOUNDS := AABB(Vector3(-8.33, -0.02, -0.88), Vector3(16.66, 6.38, 2.93))
const OUTSIDE_FACE := -0.70
const QUARTER_TURN := -PI * 0.5
var _wood: ShaderMaterial
var _iron: ShaderMaterial
var _iron_edge: ShaderMaterial
var _chamfer_iron: ShaderMaterial
var _stone: ShaderMaterial
var _wall: ShaderMaterial
var _wall_relief: Image
var _sill: StandardMaterial3D
var _mortar: StandardMaterial3D
var _glass: StandardMaterial3D
var _fastener: CylinderMesh
var _unbatched: Array[MeshInstance3D] = []


func _ready() -> void:
	_wood = ShaderMaterial.new()
	_wood.shader = Timber
	_iron = ShaderMaterial.new()
	_iron.shader = Metal
	_iron.set_shader_parameter(&"baked_surface", IronMask)
	_iron.set_shader_parameter(&"baked_normal", IronPores)
	# The hewn bevel and primitive box vertex formats differ. Keep them in
	# separate batches so Godot doesn't interpret one layout as the other.
	_chamfer_iron = _iron.duplicate() as ShaderMaterial
	_iron_edge = _iron.duplicate() as ShaderMaterial
	_iron_edge.set_shader_parameter(&"polished", 0.74)
	_iron_edge.set_shader_parameter(&"gunmetal", Color("#727470"))
	_stone = ShaderMaterial.new()
	_stone.shader = Stone
	_stone.set_shader_parameter(&"baked_surface", StoneMask)
	_stone.set_shader_parameter(&"baked_normal", StonePores)
	_wall = ShaderMaterial.new()
	_wall.shader = WallMaterial
	_wall.set_shader_parameter(&"wall_surface", WallColor)
	_wall.set_shader_parameter(&"wall_normal", WallNormal)
	_wall_relief = WallRelief.get_image()
	if _wall_relief.is_compressed():
		_wall_relief.decompress()
	_sill = _material(Color("#60523c"), 0.96)
	_mortar = _material(Color("#645d51"), 0.98)
	_glass = _material(Color("#bd763e"), 0.58)
	_glass.emission_enabled = true
	_glass.emission = Color("#9c592d")
	_glass.emission_energy_multiplier = 0.48
	_fastener = CylinderMesh.new()
	_fastener.top_radius = 0.034
	_fastener.bottom_radius = 0.050
	_fastener.height = 0.044
	_fastener.radial_segments = 6
	_fastener.rings = 0

	for side: float in [-1.0, 1.0]:
		_post(side)
		_revetment(side)
		_brace(side)
	_lintel()
	_lamp(Vector3(-SHOULDER_X, 2.42, -0.63))
	_batch_materials()
	_build_distance_meshes()


func _post(side: float) -> void:
	var x := side * SHOULDER_X
	var post := Vector3(x, 2.30, 0.0)
	_add_mesh("HewnPost", _hewn(Vector2(0.81, 1.21), 4.58, 0.135, 0.3 + side * 0.21), _wood, post)
	_add_mesh("HeelStone", _hewn(Vector2(0.84, 1.47), 0.40, 0.12, 0.4 + side * 0.37),
		_stone, Vector3(x, 0.20, 0.0))
	_box("Seat", Vector3(0.78, 0.10, 1.27), _sill, Vector3(x, 0.43, 0))
	for y: float in BAND_Y:
		for face: float in [-1.0, 1.0]:
			# Each metal skin is a distinct face, not a near-coplanar solid
			# wrapped around the beam. Corners overlap with a visible lap.
			_beveled_iron("PostCollarFace", Vector3(0.84, 0.192, 0.068),
				Vector3(x, y, face * 0.632))
			for edge: float in [-1.0, 1.0]:
				_box("RolledCollarRim", Vector3(0.803, 0.019, 0.028), _iron_edge,
					Vector3(x, y + edge * 0.087, face * 0.674))
			for dx: float in [-0.244, 0.244]:
				_bolt(Vector3(x + dx, y, face * 0.686))
		for lateral: float in [-1.0, 1.0]:
			_box("PostCollarReturn", Vector3(0.056, 0.169, 1.25), _iron,
				Vector3(x + lateral * 0.411, y, 0.0))


func _lintel() -> void:
	# The sill and blocking run into the existing roof above the opening.
	var cap := _add_mesh("RoofSill", _hewn(Vector2(0.41, 0.83), 12.01, 0.11, 1.24),
		_wood, Vector3(0.0, 5.57, 0.51))
	cap.rotation.z = QUARTER_TURN
	var beam := _add_mesh("HewnLintel", _hewn(Vector2(0.79, 1.43), 11.48, 0.15, 1.63), _wood, Vector3(0, 5, 0))
	beam.rotation.z = QUARTER_TURN
	for x: float in [-SHOULDER_X, SHOULDER_X]:
		for face: float in [-1.0, 1.0]:
			_beveled_iron("LintelCollar", Vector3(0.274, 0.79, 0.068), Vector3(x, 5.0, face * 0.725))
			for dy: float in [-0.235, 0.235]:
				_bolt(Vector3(x, 5.0 + dy, face * 0.773))
			_box("LintelCollarReturn", Vector3(0.244, 0.051, 1.48), _iron, Vector3(x, 5.0 + face * 0.404, 0))
		var scarf := _beveled_iron("ScarfPlate", Vector3(0.58, 0.68, 0.048), Vector3(x, 4.46, OUTSIDE_FACE - 0.072))
		scarf.rotation.z = signf(x) * 0.05
		for edge: float in [-1.0, 1.0]:
			var rim := _box("RolledScarfEdge", Vector3(0.036, 0.62, 0.031), _iron_edge,
				Vector3(x + edge * 0.264, 4.46, -0.807))
			rim.rotation.z = scarf.rotation.z
		for dx: float in [-0.186, 0.186]:
			_bolt(Vector3(x + dx, 4.26, -0.812))
			_bolt(Vector3(x + dx, 4.61, -0.812))
	# A low-contrast iron tally plate with punched slots, not an objective marker.
	_box("TallyPlate", Vector3(1.01, 0.234, 0.044), _iron, Vector3(0, 5.04, -0.725))
	for notch in range(4):
		var cut := _box("TallyNotch", Vector3(0.027, 0.084, 0.012), _iron_edge,
			Vector3(-0.15 + 0.09 * notch, 5.04, -0.749))
		cut.rotation.z = -0.20


func _revetment(side: float) -> void:
	# Dress the existing rock shoulders behind the portal; do not move either
	# retaining wall or drop any stones into the old 9.15 m route aperture.
	_add_mesh("ContinuousMortaredShoulder", StoneShoulder.make(side, _wall_relief), _wall, Vector3.ZERO)
	# The narrow cap is seated on the actual sill/roof line, above the lane.
	if side < 0.0:
		_add_mesh("CrownMortar", _hewn(Vector2(10.20, 0.90), 0.58, 0.16, 21.0), _mortar,
			Vector3(0.0, 5.99, 1.68))
	for j in range(3):
		var seed := float(j) + side * 2.87
		var at := Vector3(side * (0.90 + j * 1.68), 5.97 + sin(seed * 13.0) * 0.048, 1.33)
		var capstone := _add_mesh("RoofFacing", _hewn(Vector2(1.68, 1.35), 0.66, 0.13, 30.0 + seed + (100.0 if j == 1 else 0.0), true), _stone, at)
		capstone.rotation.z = sin(seed * 3.0) * 0.026


func _brace(side: float) -> void:
	# Outward knee braces seat the lintel in its shoulders without jutting
	# across the existing track edge or suggesting a narrower opening.
	var base := Vector3(side * 5.32, 3.03, -0.27)
	var head := Vector3(side * 6.41, 5.18, -0.27)
	var line := (head - base).normalized()
	var beam := _add_mesh("OutwardKneeBrace", _hewn(Vector2(0.35, 0.6), base.distance_to(head), 0.059, 2.81 + side),
		_wood, (base + head) * 0.5)
	beam.rotation.z = -atan2(line.x, line.y)
	for t: float in [0.11, 0.88]:
		var at := base.lerp(head, t)
		var clasp := _beveled_iron("BraceClasp", Vector3(0.44, 0.13, 0.64), at)
		clasp.rotation.z = beam.rotation.z
		_bolt(at + Vector3.FORWARD * 0.34)


func _lamp(at: Vector3) -> void:
	_box("LampBack", Vector3(0.35, 0.62, 0.085), _iron, at + Vector3.BACK * 0.015)
	_box("LampGlass", Vector3(0.245, 0.365, 0.092), _glass, at + Vector3.FORWARD * 0.045)
	for x: float in [-0.132, 0.132]:
		_box("LampGuard", Vector3(0.038, 0.422, 0.048), _iron, at + Vector3(x, 0.0, -0.107))
	_box("LampMullion", Vector3(0.022, 0.379, 0.019), _iron_edge, at + Vector3(0.0, -0.014, -0.105))
	_add_mesh("LampHood", _hewn(Vector2(0.355, 0.206), 0.125, 0.072, 17.2),
		_iron, at + Vector3(0.0, 0.258, -0.039))
	_box("LampTray", Vector3(0.349, 0.068, 0.185), _iron_edge, at + Vector3(0.0, -0.233, -0.039))


func _hewn(size: Vector2, length: float, bevel: float, seed_value: float, masonry := false, iron := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = roundi((seed_value + 50.0) * 15739.0)
	var w := size.x * 0.5
	var d := size.y * 0.5
	var outline := PackedVector2Array([
		Vector2(-w + bevel, -d), Vector2(-w, -d + bevel),
		Vector2(-w, d - bevel), Vector2(-w + bevel, d),
		Vector2(w - bevel, d), Vector2(w, d - bevel),
		Vector2(w, -d + bevel), Vector2(w - bevel, -d),
	])
	# Keep a beam's corners continuous along the length; only end cuts and
	# small tool chatter should vary, not the grain silhouette every ring.
	var profiles := PackedVector2Array()
	for profile: Vector2 in outline:
		profiles.append(profile * rng.randf_range(0.978, 1.0))
	var rings: Array[PackedVector3Array] = []
	var levels := [-0.5, -0.473, -0.19, 0.18, 0.474, 0.5] if not masonry else [-0.5, -0.35, 0.33, 0.5]
	if iron:
		levels = [-0.5, -0.43, 0.43, 0.5]
	for height: float in levels:
		var tier := PackedVector3Array()
		for slot in range(profiles.size()):
			var profile := profiles[slot]
			var edge := 0.94 if absf(height) == 0.5 else 1.0
			var irregular := 0.93 if masonry else 0.996
			var split := rng.randf_range(-0.021, 0.021) if masonry else 0.0
			tier.append(Vector3(profile.x * rng.randf_range(irregular, 1.0) * edge,
				length * (height + split), profile.y * rng.randf_range(irregular, 1.0) * edge))
		rings.append(tier)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for i in range(rings.size() - 1):
		var u := 0.0
		for face in range(outline.size()):
			var next := (face + 1) % outline.size()
			var end := u + outline[face].distance_to(outline[next])
			var a := rings[i][face]
			var b := rings[i + 1][face]
			var c := rings[i + 1][next]
			var d_point := rings[i][next]
			var uv_side := Vector2(0.0, seed_value)
			for item in [[a, u], [b, u], [c, end], [a, u], [c, end], [d_point, end]]:
				var point: Vector3 = item[0]
				var contact := smoothstep(0.005, 0.071, length * 0.5 - absf(point.y))
				_vertex(mesh, point, Vector2(item[1], point.y), uv_side, contact)
			u = end
	for top in [false, true]:
		var cap := rings[-1] if top else rings[0]
		var center := Vector3(0.0, cap[0].y, 0.0)
		for face in range(cap.size()):
			var other := (face + 1) % cap.size()
			var indices := [other, face] if top else [face, other]
			_vertex(mesh, center, Vector2.ZERO, Vector2(1.0, seed_value), 0.0)
			for index: int in indices:
				var point := cap[index]
				_vertex(mesh, point, Vector2(point.x, point.z), Vector2(1.0, seed_value), 0.0)
	mesh.generate_normals()
	mesh.generate_tangents()
	return mesh.commit()


func _vertex(builder: SurfaceTool, point: Vector3, uv: Vector2, tag: Vector2, contact: float) -> void:
	builder.set_color(Color(contact, 1.0, 1.0))
	builder.set_uv(uv)
	builder.set_uv2(tag)
	builder.add_vertex(point)


func _bolt(at: Vector3) -> void:
	var mesh := _add_mesh("ForgedPin", _fastener, _iron_edge, at)
	mesh.rotation.x = PI / 2.0


func _beveled_iron(label: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var bevel := minf(size.z * 0.28, 0.023)
	return _add_mesh(label, _hewn(Vector2(size.x, size.z), size.y, bevel, 0.74, false, true), _chamfer_iron, at)


func _box(label: String, dimensions: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return _add_mesh(label, shape, material, at)


func _add_mesh(label: String, shape: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.name = label
	model.mesh = shape
	model.material_override = material
	add_child(model, true)
	model.position = at
	_unbatched.append(model)
	return model


func _batch_materials() -> void:
	# Each material becomes one static mesh, rather than drawing each nail
	# and strap separately in the battle camera and the directional shadows.
	var batches: Dictionary[Material, SurfaceTool] = {}
	var names := {
		_wood: "WeatheredTimber", _iron: "ForgedFittings", _iron_edge: "IronWear",
		_chamfer_iron: "BeveledIron",
		_stone: "QuarriedFacing", _sill: "PostSeats", _glass: "LanternGlass", _mortar: "MortarJoints",
		_wall: "ConnectedShoulder",
	}
	for model in _unbatched:
		var material := model.material_override
		if not batches.has(material):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[material] = builder
		batches[material].append_from(model.mesh, 0, model.transform)
		model.free()
	_unbatched.clear()
	for material in batches:
		batches[material].index()
		var detail := _add_mesh(names[material], batches[material].commit(), material, Vector3.ZERO)
		detail.custom_aabb = LOD_BOUNDS
		detail.visibility_range_end = DETAIL_RANGE
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_unbatched.clear()


func _build_distance_meshes() -> void:
	# Keep the existing 96-triangle caster; the close art receives exactly
	# the same silhouette shadow as V9. Only the far visible meshes change.
	var caster := SurfaceTool.new()
	var timber := SurfaceTool.new()
	var distant_walls := SurfaceTool.new()
	for builder: SurfaceTool in [caster, timber, distant_walls]:
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var oak := Color("#775742")
	# Match the old weathered timber's average under the actual mine light,
	# rather than using the shadow caster's neutral tint for visible wood.
	var far_oak := Color("#775034")
	var iron_at_distance := Color("#424640")
	var ashlar := Color("#716659")
	var caps := Color("#8b7b62")
	for side: float in [-1.0, 1.0]:
		var post := Vector3(side * 5.0, 2.3, 0)
		_lod_box(caster, post, Vector3(0.82, 4.6, 1.23), oak)
		_lod_box(caster, Vector3(side * 6.66, 2.67, 1.22), Vector3(2.89, 5.31, 1.54), ashlar)
		_lod_box(caster, Vector3(side * 6.61, 5.42, 1.29), Vector3(2.42, 0.26, 1.48), caps)
		_lod_box(timber, post, Vector3(0.82, 4.6, 1.23), far_oak)
		var start := Vector3(side * 5.32, 3.03, -0.27)
		var end := Vector3(side * 6.41, 5.18, -0.27)
		var lean := (end - start).normalized()
		var bend := Basis(Vector3.BACK, -atan2(lean.x, lean.y))
		_lod_box(timber, (start + end) * 0.5, Vector3(0.35, start.distance_to(end), 0.6), far_oak, bend)
		_lod_front(timber, Vector3(side * 5.0, 4.77, -0.80), Vector2(0.48, 0.87), iron_at_distance)
		for j in range(3):
			var seed := float(j) + side * 2.87
			var pose := Vector3(side * (0.90 + j * 1.68), 5.97 + sin(seed * 13.0) * 0.048, 1.33)
			_lod_box(timber, pose, Vector3(1.61, 0.60, 1.28), caps)
		distant_walls.append_from(StoneShoulder.make_proxy(side, _wall_relief), 0, Transform3D.IDENTITY)
	_lod_box(caster, Vector3(0, 5.06, 0.12), Vector3(11.51, 0.88, 1.49), oak)
	_lod_box(caster, Vector3(0, 5.95, 1.31), Vector3(10.2, 0.50, 1.3), caps)
	_lod_box(timber, Vector3(0, 5.0, 0), Vector3(11.48, 0.79, 1.43), far_oak)
	_lod_box(timber, Vector3(0, 5.57, 0.51), Vector3(12.01, 0.41, 0.83), far_oak)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.91
	for builder: SurfaceTool in [caster, timber, distant_walls]:
		builder.index()
	_far_mesh("CommandTimber", timber.commit(), material)
	_far_mesh("CommandMortaredShoulders", distant_walls.commit(), _wall)
	var shadow := _add_mesh("PortalShadowCaster", caster.commit(), material, Vector3.ZERO)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_unbatched.clear()


func _far_mesh(label: String, mesh: ArrayMesh, material: Material) -> void:
	var model := _add_mesh(label, mesh, material, Vector3.ZERO)
	model.custom_aabb = LOD_BOUNDS
	model.visibility_range_begin = DETAIL_RANGE
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _lod_box(mesh: SurfaceTool, at: Vector3, size: Vector3, tint: Color, basis := Basis.IDENTITY) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		mesh.set_color(tint)
		mesh.set_normal(basis * normals[index])
		mesh.add_vertex(basis * vertices[index] + at)


func _lod_front(mesh: SurfaceTool, at: Vector3, size: Vector2, tint: Color) -> void:
	# Two triangles preserve the fascia silhouette without adding a fitting
	# draw or restoring the rivets at tactical distance.
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var a := Vector3(-hx, -hy, 0.0)
	var b := Vector3(hx, -hy, 0.0)
	var c := Vector3(hx, hy, 0.0)
	var d := Vector3(-hx, hy, 0.0)
	for v: Vector3 in [a, b, c, a, c, d]:
		mesh.set_color(tint)
		mesh.set_normal(Vector3.FORWARD)
		mesh.add_vertex(v + at)


func _material(tint: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
