extends RefCounted
## Build a one-sided, rail-free north deck collider in Crossing tile coordinates.
## Mount the returned body directly under the same transform as CrossingGround.
## The caller owns gameplay collision layers and any separate accessibility constraints.

static func v3(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))

static func deck_y(bridge: Dictionary, tile_x: float) -> float:
	var a := v3(bridge.west_attachment)
	var b := v3(bridge.east_attachment)
	var c := v3(bridge.crown)
	var t := (tile_x - c.x) / ((b.x - a.x) * .5)
	return c.y + (a.y - c.y) * t * t

static func make_deck(bridge: Dictionary, layer: int = 1, chord_m: float = 0.5) -> StaticBody3D:
	assert(layer > 0 and chord_m > 0.0)
	var a := v3(bridge.west_attachment)
	var b := v3(bridge.east_attachment)
	var c := v3(bridge.crown)
	var half_w := float(bridge.width) * .5
	assert(b.x > a.x and is_equal_approx(c.x, (a.x + b.x)*.5))
	assert(is_equal_approx(a.y, b.y) and c.y >= a.y)
	assert(is_equal_approx(a.z, b.z) and is_equal_approx(a.z, c.z) and half_w > 0.0)
	var span := ceili((b.x - a.x) / chord_m)
	var faces := PackedVector3Array()
	faces.resize(span * 6)
	for i in range(span):
		var x0 := lerpf(a.x, b.x, float(i) / span)
		var x1 := lerpf(a.x, b.x, float(i+1) / span)
		var h0 := deck_y(bridge, x0)
		var h1 := deck_y(bridge, x1)
		var p0 := Vector3(x0, h0, c.z-half_w)
		var p1 := Vector3(x1, h1, c.z-half_w)
		var p2 := Vector3(x1, h1, c.z+half_w)
		var p3 := Vector3(x0, h0, c.z+half_w)
		# Godot clockwise front face, up-facing. At neighboring chords the
		# two vertices on the seam are identical; no thickness or rail boxes.
		faces[i*6] = p0
		faces[i*6+1] = p1
		faces[i*6+2] = p2
		faces[i*6+3] = p0
		faces[i*6+4] = p2
		faces[i*6+5] = p3
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = false
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.name = "NorthernBridgeWalkProxy"
	body.collision_layer = layer
	body.collision_mask = 0
	body.add_child(collider)
	body.set_meta("chords", span)
	return body
