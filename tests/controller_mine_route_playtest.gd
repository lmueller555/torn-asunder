extends SceneTree

const Scene := preload("res://game/battlefield/controller_mine_route_playtest.tscn")
const Preview := preload("res://game/battlefield/controller_minimap_playtest.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 30.0

var _preview: Preview


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_preview = Scene.instantiate()
	root.add_child(_preview)
	_preview.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _route_over_mine()
	_preview.queue_free()
	await process_frame
	if passed:
		print("Controller Mine route: real roof and cover rejection, whole formation footprint, accepted map legs and actual ridge climb passed.")
	quit(0 if passed else 1)


func _route_over_mine() -> bool:
	if _preview._field.scene_file_path != "res://game/battlefields/year_one_mine_campaign.tscn" \
			or not _preview._opponent_actors.is_empty():
		return _fail("The preview did not use the existing Mine without practice opponents.")
	var scouts := _preview.battle.formations[Preview.SCOUTS]
	if not _preview._ground(scouts.position).is_equal_approx(_preview.battlefield_marker(^"Markers/Spawns/HumanArchers").position):
		return _fail("The scouts did not start on the map's authored ridge-side spawn.")
	_button(JOY_BUTTON_DPAD_LEFT)
	_button(JOY_BUTTON_DPAD_UP)
	var approach := _route_point("RidgeWestApproach")
	if not _aim(approach):
		return false
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	var initial := PackedVector2Array([approach])
	if not _check_route(initial) or scouts.destination != approach:
		return _fail("The actual controller could not append the authored ridge approach.")

	var roof := Vector2(-63, 94)
	var solid_cover := Vector2(-33, -37)
	if _top_collider(roof) != _preview._field.get_node("Geometry/Tunnel/TunnelRoof") \
			or _top_collider(solid_cover) != _preview._field.get_node("Geometry/Ridge/OverlookCoverWest"):
		return _fail("The rejected targets did not hit the existing roof and ridge cover shapes: %s, %s" % [_top_collider(roof), _top_collider(solid_cover)])
	for point in [roof, solid_cover]:
		if not _aim(point):
			return false
		_button(JOY_BUTTON_RIGHT_SHOULDER)
		if not _check_route(initial) or scouts.destination != approach or not _preview._map_note.contains("walkable"):
			return _fail("A solid point was accepted, or its rejection destroyed the original route.")
	var edge := Vector2(-33, -38)
	if _preview._terrain.destination_from_ray(Vector3(edge.x, 128, edge.y), Vector3(edge.x, -32, edge.y)) == null \
			or _preview._terrain.formation_fits_at(edge):
		return _fail("The lip fixture does not represent a valid point with insufficient formation clearance.")
	if not _aim(edge):
		return false
	_button(JOY_BUTTON_A)
	if not _check_route(initial) or scouts.destination != approach or not _preview._map_note.contains("walkable"):
		return _fail("A direct Move aimed just beside cover replaced the prior route despite insufficient clearance.")

	var route := initial.duplicate()
	for id in ["RidgeWestFoot", "RidgeWestCrest"]:
		var point := _route_point(id)
		if not _aim(point):
			return false
		_button(JOY_BUTTON_RIGHT_SHOULDER)
		route.append(point)
		if not _check_route(route):
			return _fail("A walkable authored slope marker was rejected.")
	_button(JOY_BUTTON_B)
	var start_height := _preview._ground(scouts.position).y
	var highest := start_height
	for goal in route:
		for _step in 800:
			if scouts.position == goal or scouts.order == Battle.Order.BLOCKED:
				break
			_preview._physics_process(DT)
			highest = maxf(highest, _preview._ground(scouts.position).y)
		if scouts.position != goal:
			return _fail("Scouts did not walk the actual slope route to %s (at %s)." % [goal, scouts.position])
	return (scouts.order == Battle.Order.HOLD and _preview._routes.snapshot(Preview.SCOUTS).is_empty() \
		and highest - start_height >= 9.8 and is_equal_approx(_preview._ground(scouts.position).y, highest)) \
		or _fail("The real climb did not advance the existing queue through the crest.")


func _check_route(expected: PackedVector2Array) -> bool:
	return _preview._map_open and _preview._routes.snapshot(Preview.SCOUTS) == expected \
		and _preview._route_overlay.waypoint_pixels().size() == expected.size()


func _route_point(id: String) -> Vector2:
	return _preview._marker_position(_preview.battlefield_marker(NodePath("Markers/Routes/" + id)))


func _top_collider(point: Vector2) -> Object:
	var field := _preview._field
	var query := PhysicsRayQueryParameters3D.create(field.to_global(Vector3(point.x, 128, point.y)),
		field.to_global(Vector3(point.x, -32, point.y)), 1)
	return field.get_world_3d().direct_space_state.intersect_ray(query).get("collider")


func _aim(target: Vector2) -> bool:
	var offset := target - _preview._map_cursor
	for _step in absi(roundi(offset.x)):
		_button(JOY_BUTTON_DPAD_RIGHT if offset.x > 0.0 else JOY_BUTTON_DPAD_LEFT)
	for _step in absi(roundi(offset.y)):
		_button(JOY_BUTTON_DPAD_DOWN if offset.y > 0.0 else JOY_BUTTON_DPAD_UP)
	return _preview._map_cursor.is_equal_approx(target) or _fail("Scoped D-pad input did not aim the target.")


func _button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
