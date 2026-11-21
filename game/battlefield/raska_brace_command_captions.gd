extends RefCounted
## Well Road Brace/Reserve captions only, during the authored mounted pass.
## This envelope covers the stock CommandHarness box and its attached equipment.
const GUTTER := 3.0
const FOOT_HEIGHT := 1.18
const FOOT_W := 0.245
const FOOT_Z := 0.40
const NAME_Y := 2.1
const NAME_CLEARANCE_Y := 5.0
const RESERVE_Y := 3.0
const NAME_PX := 0.020
const RESERVE_PX := 0.035
const TEXT_VISIBLE_MIN := 19.0

static func restore(name_label: Label3D, reserve: Label3D) -> void:
	name_label.position = Vector3(0, NAME_Y, 0)
	reserve.position = Vector3(0, RESERVE_Y, 0)
	name_label.pixel_size = NAME_PX
	reserve.pixel_size = RESERVE_PX


static func place(camera: Camera3D, members: Array, name_label: Label3D, reserve: Label3D) -> void:
	# Compute in camera space: a fixed world height overlaps again when players orbit.
	# Never change the selected, world-label text, camera, or reserve location.
	restore(name_label, reserve)
	var name_parent := name_label.get_parent() as Node3D
	var reserve_parent := reserve.get_parent() as Node3D
	var label_rects: Array[Rect2] = []
	var anchor_px := camera.unproject_position(camera.global_position - camera.global_basis.z * 8.0)
	var up_px := camera.unproject_position(camera.global_position - camera.global_basis.z * 8.0 + camera.global_basis.y)
	var world_per_px := 1.0 / up_px.distance_to(anchor_px)
	var footprint := _footprint(camera, members)
	for label: Label3D in [name_label, reserve]:
		var text_font: Font = label.font if label.font != null else ThemeDB.fallback_font
		var min_size: float = text_font.get_height(label.font_size)
		label.pixel_size = maxf(label.pixel_size, TEXT_VISIBLE_MIN / min_size * world_per_px)
		var visible_size := text_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
		visible_size += Vector2.ONE * label.outline_size
		var screen_size: Vector2 = visible_size * (label.pixel_size / world_per_px)
		var owner := name_parent if label == name_label else reserve_parent
		var world_y: float = NAME_CLEARANCE_Y if label == name_label else label.position.y
		var pos := owner.to_global(Vector3(0, world_y, 0))
		var orig := camera.unproject_position(pos)
		var center := orig
		var rect := Rect2(center - screen_size * 0.5, screen_size)
		var avoid: Array[Rect2] = [footprint.grow(GUTTER)]
		avoid.append_array(label_rects)
		for occupied in avoid:
			if rect.intersects(occupied.grow(GUTTER)):
				center.y = minf(center.y, occupied.position.y - screen_size.y * 0.5 - GUTTER)
				rect.position = center - screen_size * 0.5
		pos += camera.global_basis.y * ((orig.y - center.y) * world_per_px)
		label.global_position = pos
		label_rects.append(rect)


static func _footprint(camera: Camera3D, members: Array) -> Rect2:
	var bounds := Rect2()
	var first := true
	for raw in members:
		var member := raw as Node3D
		for x: float in [-FOOT_W, FOOT_W]:
			for y: float in [0.0, FOOT_HEIGHT]:
				for z: float in [-FOOT_Z, FOOT_Z]:
					var p := camera.unproject_position(member.to_global(Vector3(x, y, z)))
					if first:
						bounds.position = p
						first = false
					else:
						bounds = bounds.expand(p)
	return bounds
