extends SceneTree

const Deployment := preload("res://game/campaign_deployments.gd")
const Stock := preload("res://game/battlefield/mara_grain_crossing_playtest.tscn")
const Mission := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const Binding := preload("res://game/battlefield/mara_grain_bridge_visual.gd")
const ROOT := "res://assets/models/environment/marches_north_timber_bridge"
const BASE := ROOT + ".glb"
const FAR := ROOT + "_sector.glb"
const DT := 1.0 / 60.0

var _mission: Mission
var _binding: Binding


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var deployed: PackedScene = Deployment.for_mission("mara_grain_crossing").scene
	_mission = deployed.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await process_frame
	_binding = _mission.get_node("NorthBridgeVisual") as Binding
	var passed := _binding._near != null and _binding._sector != null and _binding._shadow != null
	if passed:
		passed = _asset_matches(_binding._near, BASE, 10696, 384) \
			and _asset_matches(_binding._sector, FAR, 876, 0) \
			and _stock_collision_preserved(_mission) and await _handoff()
	_mission.queue_free()
	await process_frame
	if passed:
		var stock := Stock.instantiate() as Mission
		root.add_child(stock)
		stock.set_physics_process(false)
		await physics_frame
		passed = stock._field.get_node("Crossings/BridgeDeck/Mesh").visible \
			and not stock.has_node(^"NorthBridgeVisual") and not stock._field.has_node(^"Crossings/NorthBridgeNear") \
			and _stock_collision_preserved(stock)
		stock.queue_free()
		await process_frame
	if passed:
		print("Registered Grain bridge: imported/runtime reviewed mesh and material parity, Shift/L2 handoff, original stock collision and standalone isolation passed.")
	else:
		push_error("Registered Grain bridge was not mounted, differed from reviewed content or touched the old standalone.")
	quit(0 if passed else 1)


func _asset_matches(imported: Node3D, source: String, visible_count: int, shadow_count: int) -> bool:
	if not imported.find_children("*", "CollisionObject3D", true, false).is_empty():
		return _fail("Imported visuals added collision.")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(source), state) != OK:
		return _fail("The exact GLB could not be loaded through the reviewed runtime parser.")
	var reviewed := document.generate_scene(state)
	var parts := _mesh_parts(imported)
	var raw := _mesh_parts(reviewed)
	var shapes := 0
	var shadows := 0
	if parts.size() != raw.size() or parts.size() != (3 if shadow_count == 0 else 4):
		reviewed.free()
		return _fail("Imported surface split changed.")
	for name in raw:
		var a: MeshInstance3D = parts.get(name)
		var b: MeshInstance3D = raw[name]
		if not a or a.transform != b.transform or a.mesh.get_surface_count() != 1 or b.mesh.get_surface_count() != 1:
			reviewed.free()
			return _fail("Mesh identity or local transform changed: " + name)
		var a_arrays := a.mesh.surface_get_arrays(0)
		var b_arrays := b.mesh.surface_get_arrays(0)
		# The editor can change vertex-table ordering; compare the rendered
		# triangle corners, their orientation, normals, and UVs instead.
		if _triangle_signatures(a_arrays) != _triangle_signatures(b_arrays):
			reviewed.free()
			return _fail("Imported triangle positions, normals or UVs differed from the reviewed parser: " + name)
		if not _same_material(a.mesh.surface_get_material(0), b.mesh.surface_get_material(0)):
			reviewed.free()
			return _fail("Imported material or albedo differed from the review: " + name)
		var indices: PackedInt32Array = a_arrays[Mesh.ARRAY_INDEX]
		var triangles := indices.size() / 3
		if name == "ShadowProxy":
			if a.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				reviewed.free()
				return _fail("The shared installer must not render opaque proxy geometry.")
			shadows += triangles
		else:
			if a.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				reviewed.free()
				return _fail("A visual mesh unexpectedly added shadow submissions.")
			shapes += triangles
	reviewed.free()
	print("%s: imported mesh arrays, material settings and albedo texels match runtime parse; %d visible + %d shadow triangles." % [
		source.get_file(), shapes, shadows,
	])
	return shapes == visible_count and shadows == shadow_count


func _triangle_signatures(data: Array) -> Array[String]:
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = data[Mesh.ARRAY_TEX_UV] if data[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var output: Array[String] = []
	for i in range(0, indices.size(), 3):
		var corners: Array[String] = []
		for j in range(3):
			var ix := indices[i + j]
			var vert := vertices[ix]
			var normal := normals[ix]
			var tex := uv[ix] if not uv.is_empty() else Vector2.ZERO
			corners.append("%.6f,%.6f,%.6f/%.6f,%.6f,%.6f/%.6f,%.6f" % [
				vert.x, vert.y, vert.z, normal.x, normal.y, normal.z, tex.x, tex.y,
			])
		var order: Array[String] = [corners[0] + ";" + corners[1] + ";" + corners[2],
			corners[1] + ";" + corners[2] + ";" + corners[0], corners[2] + ";" + corners[0] + ";" + corners[1]]
		order.sort()
		output.append(order[0])
	output.sort()
	return output


func _mesh_parts(art: Node) -> Dictionary[String, MeshInstance3D]:
	var output: Dictionary[String, MeshInstance3D] = {}
	for item in art.find_children("*", "MeshInstance3D", true, false):
		output[String(item.name)] = item as MeshInstance3D
	return output


func _same_material(imported: StandardMaterial3D, raw: StandardMaterial3D) -> bool:
	if not imported or not raw or imported.albedo_color != raw.albedo_color \
		or imported.roughness != raw.roughness or imported.metallic != raw.metallic \
		or imported.texture_filter != raw.texture_filter or imported.cull_mode != raw.cull_mode:
		return false
	var a := imported.albedo_texture
	var b := raw.albedo_texture
	if not a or not b:
		return a == b
	var ia := a.get_image()
	var ib := b.get_image()
	if ia.is_compressed() and ia.decompress() != OK or ib.is_compressed() and ib.decompress() != OK:
		return false
	ia.convert(Image.FORMAT_RGBA8)
	ib.convert(Image.FORMAT_RGBA8)
	var region := Rect2i(Vector2i.ZERO, ia.get_size())
	return ia.get_size() == ib.get_size() and ia.get_mipmap_count() == ib.get_mipmap_count() \
		and ia.get_region(region).get_data() == ib.get_region(region).get_data() and ia.get_data() == ib.get_data()


func _handoff() -> bool:
	var position := _mission.battle.hero_position
	var wagon := _mission._carts[0].global_transform
	var phase := _mission.committed_cart
	if not _view(false):
		return false
	_trigger(1.0)
	await process_frame
	await process_frame
	if not _view(true):
		return false
	_shift(true)
	_trigger(0.0)
	await process_frame
	await process_frame
	if not _view(true):
		return false
	_shift(false)
	await process_frame
	await process_frame
	if not _view(false):
		return false
	_shift(true)
	_trigger(1.0)
	_shift(false)
	await process_frame
	await process_frame
	if not _view(true):
		return false
	_trigger(0.0)
	await process_frame
	await process_frame
	return _view(false) and position == _mission.battle.hero_position \
		and wagon == _mission._carts[0].global_transform and phase == _mission.committed_cart


func _view(sector: bool) -> bool:
	if _mission._command_camera.is_current() != sector or _binding._sector.visible != sector \
			or not _binding._shadow.is_visible_in_tree():
		return _fail("Mixed Shift/L2 handoff changed the wrong render layers.")
	for mesh in _binding._near_meshes:
		if mesh.is_visible_in_tree() == sector:
			return _fail("A visible near batch leaked into sector or failed to return to hero.")
	return true


func _stock_collision_preserved(mission: Mission) -> bool:
	var field := mission._field
	for entry in [
		[^"Crossings/BridgeDeck", Vector3(29, 0.6, 10.6), 3],
		[^"Crossings/NorthRail", Vector3(27, 1.1, 0.3), 1],
		[^"Crossings/SouthRail", Vector3(27, 1.1, 0.3), 1],
	]:
		var body := field.get_node(entry[0]) as StaticBody3D
		var shape := body.get_node(^"Collision") as CollisionShape3D
		if body.collision_layer != entry[2] or shape.disabled or (shape.shape as BoxShape3D).size != entry[1]:
			return _fail("Original stock deck/rail physics did not survive mounting.")
	return mission._terrain.clear_ranged_lane(Vector3(39, 1.6, -45), Vector3(0, 1.6, -65))


func _shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	root.push_input(event, true)


func _trigger(axis: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = axis
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
