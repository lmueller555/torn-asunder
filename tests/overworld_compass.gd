extends SceneTree

const Opener := preload("res://game/overworld/moonwash/ilyra_opener_map.gd")
const World := preload("res://game/campaign_world.gd")
const CAMP := "moonwash_camp"
const HARBOR := "moonwash_harbor"
const SHORE := "moonwash_survey_shore"
var failures := 0
var checks := 0
var map: Opener
var arrived := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1120, 630)
	map = Opener.new()
	check(map.build(), "normal Ilyra opener renderer builds")
	if failures:
		map.free()
		quit(1)
		return
	var world := World.new("ilyra")
	map.configure(world, PackedStringArray(), false)
	map.waypoint_arrived.connect(func(id: String): arrived.append(id))
	root.add_child(map)
	await process_frame
	await process_frame
	map.set_process(false)
	map._update_compass()
	var compass := map._compass
	var start := compass.station
	var destination := map._projections()[HARBOR]
	check(compass.has_point and compass.snapped_id == CAMP and compass.point.is_equal_approx(start), "gold cursor starts on the army station")
	check(map.is_reachable_pin(HARBOR) and not map.is_reachable_pin(SHORE), "availability is authored, not all visible markers")
	check(world.current_waypoint_id() == CAMP and not map._march.visible, "idle station and authored party presentation remain")
	await shot("station")
	map._renderer.toggle_zoom(map._points[CAMP])
	map._update_compass()
	var near_station := compass.station
	check(map._renderer._zoomed and not near_station.is_equal_approx(start), "near lens projects the same fixed army to a new screen pixel")
	await shot("near_station")
	map._browse_camera_edge(Vector2(compass.size.x - 13.0, compass.size.y * 0.50), Vector2.RIGHT)
	map._update_compass()
	check(not map._renderer._zoomed and compass.station.is_equal_approx(start), "steering outward at near edge restores authored regional framing and station projection")
	check(Rect2(Vector2.ZERO, compass.size).has_point(map._projections()[HARBOR]), "regional framing restores the available Harbor inside browse bounds")
	var direction := start.direction_to(destination)
	var dx := InputEventJoypadMotion.new()
	dx.axis = JOY_AXIS_LEFT_X
	dx.axis_value = direction.x
	var dy := InputEventJoypadMotion.new()
	dy.axis = JOY_AXIS_LEFT_Y
	dy.axis_value = direction.y
	map._unhandled_input(dx)
	map._unhandled_input(dy)
	map._process(start.distance_to(destination) / compass.SPEED * 0.55)
	dx.axis_value = 0
	dy.axis_value = 0
	map._unhandled_input(dx)
	map._unhandled_input(dy)
	check(compass.snapped_id.is_empty() and compass.point.distance_to(start) > 45.0 and compass.point.distance_to(destination) > 30.0, "left stick puts cursor at a free point between destinations")
	check(compass.station.is_equal_approx(start) and world.current_waypoint_id() == CAMP, "gold tether station and game world stay fixed while browsing")
	await shot("free")
	var mouse := InputEventMouseMotion.new()
	mouse.position = destination
	map._unhandled_input(mouse)
	check(map._has_focus and map._navigation.selected_waypoint_id() == HARBOR and compass.preview.size() == 3, "hover previews actual name, mission and premise")
	check(world.current_waypoint_id() == CAMP and arrived.is_empty(), "preview performs no arrival")
	check(map._projections()[HARBOR].is_equal_approx(destination), "free preview does not reframe the marker away from the cursor")
	await shot("preview")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	mouse.position = Vector2(compass.size.x * 0.50, compass.size.y * 0.85)
	map._unhandled_input(mouse)
	map._unhandled_input(a)
	check(not map._navigation.is_travelling() and not map._has_focus, "A over empty terrain cannot confirm stale destination")
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT if direction.x > 0.0 else KEY_LEFT
	key.pressed = true
	check(map.select_waypoint(CAMP), "programmatic assist snaps to current station")
	map._unhandled_input(key)
	check(compass.snapped_id == HARBOR and map._has_focus, "arrow keys still snap to a reachable marker")
	map.select_waypoint(CAMP)
	dx.axis_value = direction.x
	dy.axis_value = direction.y
	map._unhandled_input(dx)
	map._unhandled_input(dy)
	map._process(start.distance_to(destination) / compass.SPEED)
	dx.axis_value = 0
	dy.axis_value = 0
	map._unhandled_input(dx)
	map._unhandled_input(dy)
	check(compass.snapped_id.is_empty() and map._has_focus and map._navigation.selected_waypoint_id() == HARBOR, "analog can enter and hold live hover on a story marker")
	map._unhandled_input(a)
	check(map._navigation.is_travelling() and map._march.visible and not compass.visible and world.current_waypoint_id() == CAMP, "A starts animated trip without arrival or tether")
	var curve := map._curve_for(CAMP, HARBOR)
	map._process(1.5)
	var point := curve.sample_baked(curve.get_baked_length() * 0.5)
	check(map._navigation.is_travelling() and map._party_point().distance_to(point) < 0.1 and arrived.is_empty(), "half-duration army samples exact route midpoint before arrival")
	check(map._march.global_position.is_equal_approx(map._party.global_position), "miniatures are the moving party, not UI markers")
	check(map._station_geometry.all(func(part: GeometryInstance3D) -> bool: return not part.visible), "old ring and standard are hidden only during travel")
	await shot("march")
	if DisplayServer.get_name() != "headless":
		# Review lens only. The previous capture is actual gameplay framing.
		var camera_state := map._camera.global_transform
		var keep_fov := map._camera.fov
		map._renderer.set_process(false)
		var origin := map._march.global_position
		map._camera.global_position = origin + Vector3(-27, 26, 21)
		map._camera.fov = 48.0
		map._camera.look_at(origin + Vector3.UP * 4.0)
		await shot("march_close_review")
		map._camera.global_transform = camera_state
		map._camera.fov = keep_fov
		map._renderer.set_process(true)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	map._unhandled_input(b)
	check(world.current_waypoint_id() == CAMP and arrived.is_empty() and compass.snapped_id == CAMP, "B cancels with old station and no arrival")
	var click := InputEventMouseButton.new()
	click.position = map._projections()[HARBOR]
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	map._unhandled_input(click)
	check(map._navigation.is_travelling() and world.current_waypoint_id() == CAMP, "double-click confirms the live marker as the mouse travel equivalent")
	map._process(3.02)
	check(world.current_waypoint_id() == HARBOR and arrived == PackedStringArray([HARBOR]) and compass.snapped_id == HARBOR, "arrival fires once and reanchors cursor")
	check(map.select_waypoint(SHORE) and map._has_focus and not map.is_reachable_pin(SHORE), "locked route is selectable for inspection but not reachable")
	check("Requires completion: Hulls on Stone" in compass.preview and map.confirm_button.disabled, "the admission requirement is the real campaign prerequisite")
	map._unhandled_input(a)
	check(not map._navigation.is_travelling() and world.current_waypoint_id() == HARBOR, "locked destination cannot be confirmed by A")
	map.select_waypoint(CAMP)
	map._unhandled_input(a)
	map._process(0.75)
	check(map._party_point().distance_to(curve.sample_baked(curve.get_baked_length() * 0.75)) < 0.1, "reverse movement follows the same authored route in reverse")
	map._unhandled_input(b)
	check(map._station_geometry.all(func(part: GeometryInstance3D) -> bool: return part.visible), "old audited station dressing is restored on return")
	await shot("arrival")
	print("Overworld compass: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var directory := OS.get_environment("TORN_COMPASS_PROOF")
	if not directory.is_empty():
		root.get_texture().get_image().save_jpg(directory.path_join(name + ".jpg"), 0.83)
