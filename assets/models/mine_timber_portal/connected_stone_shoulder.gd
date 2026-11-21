@tool
extends RefCounted
## A continuous mortared relief. Geometry and tangent maps share the same
## offline sculpt, while only the broad forms are sampled into the live mesh.

const X_STEPS := 18
# Bed rows from the offline connected sculpt; sample the relief at the
# mortar itself and just above/below every structural course.
const COURSE_BEDS := [
	[0.0, 0.55, 1.25, 1.94, 2.66, 3.42, 4.11, 4.77, 5.27],
	[0.0, 0.59, 1.36, 1.98, 2.77, 3.39, 4.05, 4.71, 5.27],
]
const BED_X := [0.0, 0.6, 1.16, 1.62, 1.89, 2.26, 2.73, 3.04]
const SHARED_STEPS := [0.0, -0.01, 0.011, -0.084, 0.068, -0.021, 0.065, -0.043]
const EAST_BATTER := [0.0, 0.01, 0.015, 0.015, -0.015, 0.008, 0.0, -0.018]
const ROW_STEPS := [0.0, 0.105, 0.52, 0.895]
const Y_STEPS := 32
const HEIGHT := 5.27
const START := 5.17
const WIDTH := 3.04
const RELIEF_DEPTH := 0.28
const BACK_DEPTH := 0.63


static func make(side: float, source: Image) -> ArrayMesh:
	var clean := SurfaceTool.new()
	clean.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheet := 0 if side < 0.0 else 1
	var local := PackedVector3Array()
	var tex := PackedVector2Array()
	for y in range(Y_STEPS + 1):
		for x in range(X_STEPS + 1):
			var u := float(x) / X_STEPS
			var course := mini(floori(float(y) / ROW_STEPS.size()), COURSE_BEDS[sheet].size() - 2)
			var progress: float = ROW_STEPS[y % ROW_STEPS.size()] if y < Y_STEPS else 1.0
			var v := lerpf(_bed_height(u, sheet, course), _bed_height(u, sheet, course + 1), progress) / HEIGHT
			tex.append(_texture_coordinate(u, v, sheet, source))
			local.append(_stone_position(u, v, side, sheet, source))
	for y in range(Y_STEPS):
		for x in range(X_STEPS):
			var a := y * (X_STEPS + 1) + x
			var b := a + 1
			var c := a + X_STEPS + 1
			var d := c + 1
			_triangle(clean, [local[a], local[b], local[d]], [tex[a], tex[b], tex[d]], Vector3.FORWARD)
			_triangle(clean, [local[a], local[d], local[c]], [tex[a], tex[d], tex[c]], Vector3.FORWARD)
	# The exposed end of the wall is a real return, not a flat billboard.
	for edge in [0, X_STEPS]:
		for y in range(Y_STEPS):
			var a: int = y * (X_STEPS + 1) + edge
			var b := a + X_STEPS + 1
			var outside := Vector3(side * (-1.0 if edge == 0 else 1.0), 0.0, 0.0)
			var new_uv := Vector2(0.027 * (-side if edge == 0 else side), 0.0)
			var outer_a := local[a] + Vector3.BACK * BACK_DEPTH
			var outer_b := local[b] + Vector3.BACK * BACK_DEPTH
			_triangle(clean, [local[a], outer_a, outer_b], [tex[a], tex[a] + new_uv, tex[b] + new_uv], outside)
			_triangle(clean, [local[a], outer_b, local[b]], [tex[a], tex[b] + new_uv, tex[b]], outside)
	clean.generate_normals()
	clean.generate_tangents()
	clean.index()
	return clean.commit()


## Far shoulders sample the same sculpt, material, and UVs, but omit all
## sub-course relief. The 40 triangles per wing retain the battered edge.
static func make_proxy(side: float, source: Image) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheet := 0 if side < 0.0 else 1
	for row in range(4):
		var low := float(row) / 4.0
		var high := float(row + 1) / 4.0
		for column in range(3):
			var left := float(column) / 3.0
			var right := float(column + 1) / 3.0
			var coords := [Vector2(left, low), Vector2(right, low), Vector2(right, high), Vector2(left, high)]
			var p := coords.map(func(at: Vector2) -> Vector3: return _stone_position(at.x, at.y, side, sheet, source))
			var uv := coords.map(func(at: Vector2) -> Vector2: return _texture_coordinate(at.x, at.y, sheet, source))
			_triangle(mesh, [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]], Vector3.FORWARD)
			_triangle(mesh, [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]], Vector3.FORWARD)
		for edge in [0.0, 1.0]:
			var a := _stone_position(edge, low, side, sheet, source)
			var b := _stone_position(edge, high, side, sheet, source)
			var a_uv := _texture_coordinate(edge, low, sheet, source)
			var b_uv := _texture_coordinate(edge, high, sheet, source)
			var inward := 0.027 * (-side if edge == 0.0 else side)
			var outer := Vector3(side * (-1.0 if edge == 0.0 else 1.0), 0.0, 0.0)
			var rear := Vector3.BACK * BACK_DEPTH
			_triangle(mesh, [a, a + rear, b + rear], [a_uv, a_uv + Vector2(inward, 0), b_uv + Vector2(inward, 0)], outer)
			_triangle(mesh, [a, b + rear, b], [a_uv, b_uv + Vector2(inward, 0), b_uv], outer)
	mesh.generate_normals()
	mesh.generate_tangents()
	mesh.index()
	return mesh.commit()


static func _bed_height(u: float, sheet: int, bed: int) -> float:
	var result: float = COURSE_BEDS[sheet][bed]
	if bed == 0 or bed == COURSE_BEDS[sheet].size() - 1:
		return result
	var x := u * WIDTH
	var side := -1.0 if bed % 2 == 1 else 1.0
	for i in range(1, BED_X.size()):
		if x <= BED_X[i]:
			var f := inverse_lerp(BED_X[i - 1], BED_X[i], x)
			var a: float = SHARED_STEPS[i - 1] * side + EAST_BATTER[i - 1] * sheet
			var b: float = SHARED_STEPS[i] * side + EAST_BATTER[i] * sheet
			return result + lerpf(a, b, f)
	return result


static func _stone_position(u: float, v: float, side: float, sheet: int, source: Image) -> Vector3:
	var t := _texture_coordinate(u, v, sheet, source)
	var px := floori(t.x * source.get_width())
	var py := floori(t.y * source.get_height())
	# The shoulders batter slightly toward the top; the passage opening and
	# all collision belong to the original Mine scene, not this visual kit.
	var eased := pow(v, 1.9) * 0.16
	var depth := 0.58 + u * (0.14 + v * 0.06)
	var relief := source.get_pixel(px, py).r * RELIEF_DEPTH
	return Vector3(side * (START + u * (WIDTH - eased)), 0.013 + v * HEIGHT, depth - relief)


static func _texture_coordinate(u: float, v: float, sheet: int, source: Image) -> Vector2:
	var half := float(source.get_width()) * 0.5
	return Vector2((float(sheet) * half + 0.5 + u * (half - 1.0)) / source.get_width(),
		(0.5 + (1.0 - v) * (source.get_height() - 1.0)) / source.get_height())


static func _triangle(mesh: SurfaceTool, p: Array, uv: Array, normal: Vector3) -> void:
	var outside: bool = (p[2] - p[0]).cross(p[1] - p[0]).dot(normal) > 0.0
	for index: int in ([0, 1, 2] if outside else [0, 2, 1]):
		mesh.set_uv(uv[index])
		mesh.add_vertex(p[index])
