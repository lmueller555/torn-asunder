extends SceneTree
## godot --headless --path . --script res://tests/minimap_waypoint_renderer.gd

const Map := preload("res://game/battlefield/battlefield_minimap.gd")

var checks := 0
var failures := 0
var moved: Array[Vector2] = []
var appended: Array[Vector2] = []
var focused: Array[Vector2] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := Map.new()
	root.add_child(map)
	map.tactical_style = true
	map.click_to_focus = true
	map.right_click_to_move = true
	map.place_tactical_overlay(false)
	map.set_field_bounds(Rect2(10.0, 20.0, 400.0, 100.0))
	_check(map.size.is_equal_approx(Map.TACTICAL_COMPACT_SIZE), "compact uses proposed landscape footprint")
	_check(map.map_rect().size.is_equal_approx(map.size - Vector2(8.0, 8.0)),
		"tactical terrain fills its frame without letterboxing")
	_check((map.unproject(map.project(Vector2(335.0, 40.0))) as Vector2).is_equal_approx(Vector2(335.0, 40.0)),
		"route and mouse positions use inverse world transform")
	_check(map.unproject(Vector2.ZERO) == null, "padding remains non-clickable")

	var sample := Map.Frame.new()
	sample.hero = Map.Marker.new(&"lead", Vector2(35.0, 55.0))
	sample.allies.append(Map.Marker.new(&"scout", Vector2(45.0, 72.0)))
	sample.selected_hero = true
	sample.visible_enemies.append(Map.Marker.new(&"hostile", Vector2(65.0, 85.0)))
	sample.platoon_routes[&"lead"] = PackedVector2Array([Vector2(-1.0, -1.0), Vector2(205.0, 55.0),
		Vector2(205.0, 100.0), Vector2(290.0, 100.0), Vector2(INF, 100.0), Vector2(400.0, 100.0)])
	sample.platoon_stops[&"lead"] = PackedVector2Array([Vector2(205.0, 100.0), Vector2(290.0, 100.0)])
	sample.platoon_routes[&"scout"] = PackedVector2Array([Vector2(45.0, 72.0), Vector2(136.0, 91.0)])
	sample.platoon_routes[&"hostile"] = PackedVector2Array([Vector2(65.0, 85.0), Vector2(120.0, 72.0)])
	sample.platoon_routes[&"unknown"] = PackedVector2Array([Vector2(160.0, 85.0), Vector2(190.0, 72.0)])
	sample.attack_range = 37.0
	sample.command_cursor = Vector2(205.0, 60.0)
	sample.explored_areas.append(Rect2(17.0, 24.0, 150.0, 70.0))
	map.show_frame(sample)
	_check(map._ally_routes.size() == 2, "both player routes visible; no hostile or unknown route")
	_check(map._selected_route_id == &"lead", "selected hero route is the animated route")
	_check(map._ally_routes[&"lead"][0] == sample.hero.position, "route origin follows actual unit")
	_check(map._ally_routes[&"lead"].size() == 4, "invalid interior route stop never bridges to a later point")
	_check(map._ally_stops[&"lead"].size() == 2 and map._ally_stops[&"scout"].size() == 1,
		"explicit queue dots exclude navigation bends; omitted dots fall back to route vertices")
	_check(map._command_cursor == sample.command_cursor and map._attack_range == sample.attack_range,
		"caller supplies genuine cursor and attack range separately from movement orders")
	_check(map._fog_texture != null, "real explored areas enable fog shading")
	var fog := map._fog_texture.get_image()
	_check(fog.get_pixel(13, 12).a < 0.05 and fog.get_pixel(94, 65).a > 0.6,
		"exploration texture opens real reveal area and shades the rest")

	map._process(0.125)
	_check(is_equal_approx(map._route_phase, 0.25), "quarter of the half-second loop")
	map.show_frame(sample)
	_check(is_equal_approx(map._route_phase, 0.25), "consistent per-frame snap preserves animation")
	map._process(0.375)
	_check(is_zero_approx(map._route_phase), "full loop wraps at 0.5 seconds")
	map.animate_waypoint_chevron = false
	_check(not map.is_processing() and map._ally_routes.has(map._selected_route_id),
		"reduced motion retains the selected route without processing an animation")
	map.animate_waypoint_chevron = true
	_check(map.is_processing(), "normal motion restores the selected route loop")
	map.set_tactical_expanded(true)
	_check(map.size.is_equal_approx(Map.TACTICAL_EXPANDED_SIZE) and map._ally_routes.size() == 2,
		"expansion retains both current routes")
	map.set_tactical_expanded(false)
	_check(map.size.is_equal_approx(Map.TACTICAL_COMPACT_SIZE), "collapse preserves approved size")

	var bend := Curve2D.new()
	bend.add_point(Vector2.ZERO)
	bend.add_point(Vector2(100.0, 0.0))
	bend.add_point(Vector2(100.0, 100.0))
	var east := Map.route_chevron(bend, 0.13, 1.0)
	var south := Map.route_chevron(bend, 0.82, 1.0)
	_check(east.size() == 4 and east[0].x > east[2].x, "arrow follows eastward first segment")
	_check(south.size() == 4 and south[0].y > south[2].y and is_equal_approx(south[0].x, 100.0),
		"arrow rotates toward the destination on the next segment")
	_check(Map.route_chevron(bend, 1.13, 1.0)[0].is_equal_approx(east[0]), "chevron repeats without accumulating error")
	_check(Map.route_chevron(Curve2D.new(), 0.6, 1.0).is_empty(), "empty route has no chevron")

	sample.selected_hero = false
	sample.selected_ally = &"scout"
	sample.explored_areas.clear()
	map.show_frame(sample)
	_check(map._selected_route_id == &"scout" and map._ally_routes.size() == 2,
		"selection switches animated route without erasing original platoon orders")
	_check(map._fog_texture == null, "no exploration data does not invent fog")
	map.hide()
	_check(not map.is_processing(), "hidden route does not redraw its animation")
	map.show()
	_check(map.is_processing(), "visible selected route resumes animation")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	_check(not Map.is_tactical_toggle(back), "map never consumes a pause-bound Back button")

	map.move_requested.connect(func(point: Vector2): moved.append(point))
	map.append_requested.connect(func(point: Vector2): appended.append(point))
	map.point_requested.connect(func(point: Vector2): focused.append(point))
	var target := Vector2(92.0, 82.0)
	_click(map, map.project(target), MOUSE_BUTTON_RIGHT)
	_click(map, map.project(target), MOUSE_BUTTON_RIGHT, true)
	_click(map, map.project(target), MOUSE_BUTTON_LEFT)
	_click(map, Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	_check(moved.size() == 1 and moved[0].is_equal_approx(target), "right-click routes one replacement")
	_check(appended.size() == 1 and appended[0].is_equal_approx(target), "Ctrl-right-click routes one append")
	_check(focused.size() == 1 and focused[0].is_equal_approx(target), "left-click retains focus action")
	map.show_frame(null)
	_check(map._ally_routes.is_empty() and not map.is_processing(), "no route survives frame reset")
	map.tactical_style = false
	_check(map.map_rect().size.aspect() == 4.0, "legacy map projection remains letterboxed")

	print("Waypoint minimap renderer: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)


func _click(map: Control, where: Vector2, button: MouseButton, ctrl := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = where
	event.ctrl_pressed = ctrl
	map._gui_input(event)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
