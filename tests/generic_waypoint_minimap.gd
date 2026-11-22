extends SceneTree
## Native archive scenario acceptance: owned orders, real routing, visibility,
## positional mouse dispatch, lifecycle and existing outcome/dialogue handling.

const View := preload("res://game/mission/mission_view.gd")
const Scene := preload("res://game/mission/mission_view.tscn")
const Battle := preload("res://game/mission/mission_battle.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var view := Scene.instantiate() as View
	view.mission_id = "mara_mine_escort"
	root.add_child(view)
	view.set_physics_process(false)
	await process_frame
	var battle := view.battle
	var map := view._hud._map
	var shields := battle.squad("shields")
	var archers := battle.squad("archers")
	var compact := map.size
	var inset_right := map.get_global_rect().end.x
	_check(compact.x > compact.y and map.tactical_style and map.terrain_texture != null,
		"compact replacement uses actual mission terrain")
	_check(map.marker_pixel(&"shields") is Vector2 and map.marker_pixel(&"archers") is Vector2,
		"both real commandable platoons are visible")
	_check(map.marker_pixel(&"redwater") == null and map.marker_pixel(&"slingers") == null,
		"no distant/hidden hostiles on the starting map")
	_check(view._hud._explored_cells.size() > 0, "only real observers contribute exploration")
	_key(view, KEY_N)
	_check(view.minimap_expanded and map.size.x > compact.x and map.size.y > compact.y
		and is_equal_approx(map.get_global_rect().end.x, inset_right), "expanded map uses the same upper-right anchor")
	var leg_one := _free_step(battle, shields.anchor)
	var leg_two := _free_step(battle, leg_one, shields.anchor)
	var archer_leg := _free_step(battle, archers.anchor)
	_mouse(view, leg_one, MOUSE_BUTTON_RIGHT)
	_mouse(view, leg_two, MOUSE_BUTTON_RIGHT, true)
	_check(_matches(battle.waypoint_stops(shields), PackedVector2Array([leg_one, leg_two])),
		"right click issues and Ctrl+right click appends an actual order")
	_mouse(view, archers.anchor, MOUSE_BUTTON_LEFT)
	_mouse(view, archer_leg, MOUSE_BUTTON_RIGHT)
	_check(view.selected_entry().squad == archers and _matches(battle.waypoint_stops(archers), PackedVector2Array([archer_leg])),
		"clicking another pip selects that platoon and gives it its own route")
	_check(battle.waypoint_stops(shields).size() == 2, "other platoon's queue survives changing selection")
	view._hud.refresh()
	_check(map._ally_routes.size() == 2 and map._selected_route_id == &"archers"
		and map._ally_stops.get(&"shields", PackedVector2Array()).size() == 2,
		"the renderer displays both live routes and animates only the selected platoon")
	_check(is_equal_approx(map._attack_range, float(archers.info.range)),
		"range ring uses actual selected archers' weapon range, not aggro distance")
	_check(not view._order_minimap_waypoint(Vector2.INF, true)
		and not view._order_minimap_waypoint(battle.bounds.position - Vector2.ONE, true)
		and battle.waypoint_stops(archers).size() == 1, "invalid positions do not replace the queue")
	_key(view, KEY_P)
	_check(view.paused and not view._order_minimap_waypoint(leg_two, false),
		"existing pause still protects the orders")
	_key(view, KEY_P)
	for i in range(250):
		battle.step(0.05)
		if battle.waypoint_stops(shields).is_empty() and battle.waypoint_stops(archers).is_empty():
			break
	_check(shields.anchor.distance_to(leg_two) < 0.05 and battle.waypoint_stops(shields).is_empty(),
		"simulation moves the first formation to both stops in order")
	_check(archers.anchor.distance_to(archer_leg) < 0.05 and battle.waypoint_stops(archers).is_empty(),
		"simulation moves the second platoon independently")
	view._hud.refresh()
	_check(map._ally_routes.is_empty(), "completed destinations leave no stale route")
	_check(view._hud._current.get("text", "").length() > 0, "scripted dialogue still reaches the HUD")
	battle.command(shields.index, {"kind": "move", "to": leg_one})
	_check(not shields.path.is_empty(), "existing field move dispatcher still routes")
	var expected_queue := PackedVector2Array([leg_one])
	var last_stop := leg_one
	for i in range(1, Battle.WAYPOINT_QUEUE_MAX):
		var point := _free_step(battle, last_stop, leg_two)
		if battle.command_waypoint(shields.index, point, true):
			expected_queue.append(point)
			last_stop = point
	_check(expected_queue.size() == 8 and _matches(battle.waypoint_stops(shields), expected_queue)
		and not battle.command_waypoint(shields.index, _free_step(battle, last_stop), true),
		"map append extends an existing native order and stops at eight destinations")
	battle.command(shields.index, {"kind": "hold"})
	_check(battle.waypoint_stops(shields).is_empty(), "native hold cancels the real waypoint queue")
	_key(view, KEY_N)
	_check(not view.minimap_expanded and map.size.is_equal_approx(compact),
		"toggling returns to compact presentation")
	var outcomes: Array[bool] = []
	view.mission_finished.connect(func(won: bool) -> void: outcomes.append(won))
	view._hud.show_outcome(true, "Victory")
	var result := view._hud._outcome.find_children("*", "Button", true, false)[0] as Button
	_check(result.text == "Continue", "victory retains Continue")
	result.pressed.emit()
	_check(outcomes == [true], "Continue still reports victory")
	view._hud.show_outcome(false, "Defeat")
	result = view._hud._outcome.find_children("*", "Button", true, false)[0] as Button
	_check(result.text == "Retry Mission", "defeat retains Retry Mission")
	result.pressed.emit()
	view.set_physics_process(false)
	_check(view.battle != battle and not view.minimap_expanded and
		view.find_children("BattlefieldMinimap", "Control", true, false).size() == 1,
		"retry starts clean and leaves exactly one map")
	view.queue_free()
	await process_frame
	print("Generic waypoint minimap: %d/%d checks passed." % [checks - failures, checks])
	quit(0 if failures == 0 else 1)


func _free_step(battle: Battle, from: Vector2, exclude := Vector2.INF) -> Vector2:
	for delta: Vector2 in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		var target := from + delta
		if target != exclude and battle.bounds.grow(-0.7).has_point(target) and battle._clear_line(from, target):
			return target
	return Vector2.INF


func _key(view: View, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	view._unhandled_input(event)


func _mouse(view: View, point: Vector2, button: MouseButton, append := false) -> void:
	var map := view._hud._map
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = map.get_global_transform_with_canvas() * map.project(point)
	event.ctrl_pressed = append
	event.pressed = true
	view._unhandled_input(event)


func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + name)


func _matches(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	for i in first.size():
		if not first[i].is_equal_approx(second[i]):
			return false
	return true
