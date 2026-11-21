extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const CampaignMap := preload("res://game/campaign_map.gd")
const Profile := preload("res://game/profile_store.gd")
const Registry := preload("res://game/campaign_deployments.gd")
const Mission := preload("res://game/battlefield/sereth_cut_playtest.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Cut := preload("res://game/battlefield/sereth_voices_at_the_cut.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _map: Minimap
var _orders: Array[int] = []
var _failures := 0
var _capture := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")
	var deployment := Registry.for_mission("sereth_voices_at_the_cut")
	_mission = deployment.scene.instantiate()
	# The baseline uses the exact same battle, field and hero with the opt-in off.
	_mission.enable_command_minimap = false
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	await process_frame
	_map = _mission._command_minimap.map
	_mission.battle.formation_commanded.connect(func(index: int) -> void: _orders.append(index))
	_check(_mission._field.name == &"StillKingdomCut"
		and _mission.battle.bounds.size == Vector2(390, 200), "Test the registered full Cut deployment.")
	var before := await _capture_image("hero-without-map")
	_mission.enable_command_minimap = true
	_tick()
	var after := await _capture_image("hero-with-map-enabled")
	if before and after:
		_check(before.get_data() == after.get_data(), "Opt-in must be pixel-neutral outside command stance.")
	_check(not _map.is_visible_in_tree() and _map.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _map.sector_pixels().is_empty(), "Hero stance has no drawing or interactive map area.")
	_mouse_map(MOUSE_BUTTON_RIGHT, Vector2(34, 34))
	_check(_orders.is_empty(), "The hidden hero map cannot order platoons.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	await process_frame
	_check(_mission.command_view and _map.is_visible_in_tree() and _map.click_to_focus
		and root.get_camera_3d() == _mission._command_camera, "Existing L2 opens the command camera and panel.")
	_check(_hud_fits(), "Panel, map and hint must fit without touching the existing objective HUD.")
	_check(_map._glyphs.size() == 3 and _glyph(&"sereth").position == _mission.battle.hero_position
		and _glyph(&"formation_0").selected and not _glyph(&"formation_1").selected
		and not _mission._raider.visible, "Initial live friendly markers and only one selection, no reserve.")
	_check(not _map.sector_pixels().is_empty() and Geometry2D.is_point_in_polygon(
		_map.project(_mission.battle.hero_position), _map.sector_pixels()[0]),
		"Actual orthographic sector contains the initial hero position.")
	await _capture_image("command-over-hero-sector")

	_button(JOY_BUTTON_DPAD_RIGHT)
	_check(_glyph(&"formation_1").selected and not _glyph(&"formation_0").selected,
		"Existing D-pad changes the real selected platoon and highlight.")
	var before_orbit := _map.sector_pixels()
	_axis(JOY_AXIS_RIGHT_X, 0.8)
	_tick(15)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_check(_map.sector_pixels() != before_orbit, "Right-stick orbit changes the live camera footprint.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_check(_mission._sector.overview, "R3 overview is unchanged.")
	var inspect := _point("Routes/CemeteryStairFoot")
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(inspect))
	_check(_orders.is_empty() and _mission.selected_index == 1 and not _mission._sector.overview
		and _mission._sector.focus.is_equal_approx(inspect) and _mission.cursor.is_equal_approx(inspect),
		"Left map click centers on the authored lower stair without selecting or ordering.")
	await _capture_image("command-sector-recentered")

	_button(JOY_BUTTON_DPAD_LEFT)
	var guard := _mission.battle.formations[0]
	var initial_guard := guard.position
	var route := _point("Routes/ApproachRoadWest")
	_mouse_map(MOUSE_BUTTON_RIGHT, _map.project(route))
	_check(_orders == [0] and guard.order == Battle.Order.MOVE
		and guard.destination.is_equal_approx(route) and _mission._sector.focus.is_equal_approx(route),
		"One map right-click issues the real selected Household Guard move.")
	var roof := _point("Routes/RecordRoomInside")
	_check(_mission._terrain.destination_from_ray(Vector3(roof.x, 64, roof.y), Vector3(roof.x, -16, roof.y)) == null,
		"The actual solid record room roof rejects overhead orders.")
	_mouse_map(MOUSE_BUTTON_RIGHT, _map.project(roof))
	_mouse_map(MOUSE_BUTTON_RIGHT, Vector2(2, 2))
	_click(MOUSE_BUTTON_RIGHT, _mission._command_minimap.get_global_rect().position + Vector2(7, 7))
	_check(_orders == [0] and guard.destination.is_equal_approx(route)
		and _mission._sector.focus.is_equal_approx(route),
		"Roof, letterbox and panel chrome do not issue a ray order through the HUD.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(not _map.is_visible_in_tree() and _map._glyphs.is_empty() and not _map.click_to_focus,
		"Release hides and disables the map immediately.")
	_tick(330)
	_check(guard.position.is_equal_approx(route) and guard.position != initial_guard
		and guard.order == Battle.Order.HOLD, "A map order physically marches and completes after returning to hero.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_check(_glyph(&"formation_0").position.is_equal_approx(guard.position), "Positions refresh from the live platoon.")
	var before_aim := _mission.cursor
	_axis(JOY_AXIS_LEFT_X, 0.75)
	_tick(20)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_check(_mission.cursor.distance_to(before_aim) > 3.0, "Existing left stick still aims without map capture.")
	_button(JOY_BUTTON_X)
	_check(_orders == [0, 0] and guard.destination.is_equal_approx(_mission.cursor),
		"Square issues the ordinary world-cursor Move unchanged.")
	_button(JOY_BUTTON_A)
	_check(_orders == [0, 0, 0] and guard.order == Battle.Order.HOLD and not _mission._interact,
		"Cross remains Hold in command view, not hero interaction.")
	_mission._raider.show()
	_tick()
	_check(_map._glyphs.size() == 3 and _glyph(&"raider") == null, "The map never reveals even an active raider.")
	var ending := Cut.Observation.new()
	ending.sereth_fell = true
	_mission.objective.advance(ending)
	_mission._sync_view()
	_check(not _map.is_visible_in_tree() and not _map.click_to_focus,
		"The map releases the pointer at a terminal objective.")
	_button(JOY_BUTTON_START)
	_check(not _mission.command_view and not _map.is_visible_in_tree() and not _mission._raider.visible
		and _mission.objective.outcome == Cut.Outcome.ACTIVE, "Options restarts cleanly in hero stance.")
	await _controller_draft()
	print("Cut minimap: viewport %s / panel %s / current camera %s / %d failures." %[
		root.get_visible_rect().size, _mission._command_minimap.get_global_rect(), root.get_camera_3d().name, _failures])
	_mission.queue_free()
	await process_frame
	await _campaign_pointer_return()
	quit(0 if _failures == 0 else 1)


func _controller_draft() -> void:
	var hud := _mission._command_minimap
	_orders.clear()
	_mission.battle.formation_commanded.connect(func(index: int) -> void: _orders.append(index))
	_tap(JOY_BUTTON_DPAD_UP)
	_check(hud._draft_battle == null, "D-pad Up in hero never opens an aim.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis(JOY_AXIS_LEFT_X, 0.88)
	var world_cursor := _mission.cursor
	var sector := _mission._sector.focus
	_tap(JOY_BUTTON_DPAD_UP)
	_check(hud._draft_battle == _mission.battle and hud._aim.is_visible_in_tree()
		and hud._draft_point.is_equal_approx(world_cursor), "L2 plus D-pad Up arms the separate cursor.")
	_axis(JOY_AXIS_LEFT_X, 0.88)
	_draft_tick(4)
	_check(hud._draft_point.is_equal_approx(world_cursor) and _mission.cursor.is_equal_approx(world_cursor),
		"Held aim input on opening does not take over either cursor until neutral.")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(hud._draft_point.is_equal_approx(world_cursor + Vector2(3, 0)) and _mission.selected_index == 0,
		"D-pad nudges the map instead of changing platoon selection.")
	_axis(JOY_AXIS_LEFT_X, 0.65)
	_draft_tick(20)
	_check(hud._draft_point.x > world_cursor.x + 10.0 and _mission.cursor.is_equal_approx(world_cursor)
		and _mission._sector.focus.is_equal_approx(sector) and _orders.is_empty(),
		"Stick aims locally without changing the world cursor, sector, or orders.")
	await _capture_image("controller-map-draft")
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_draft_tick(200)
	_check(hud._draft_point.x == _mission.battle.bounds.position.x
		and _map.map_rect().grow(0.01).has_point(hud._aim.pixel), "Draft and reticle clamp to the real field.")
	_tap(JOY_BUTTON_B)
	_axis(JOY_AXIS_LEFT_X, -0.93)
	_tick(10)
	_check(hud._draft_battle == null and not hud._aim.visible and _mission.cursor.is_equal_approx(world_cursor)
		and _orders.is_empty(), "Circle cancels and keeps held input from leaking to the command cursor.")
	_axis(JOY_AXIS_LEFT_X, 0.0)

	var road := _point("Routes/ApproachRoadWest")
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(road))
	_tap(JOY_BUTTON_DPAD_UP)
	_tap(JOY_BUTTON_A)
	var selected := _mission.battle.formations[0]
	_check(_orders == [0] and selected.order == Battle.Order.MOVE and selected.destination.is_equal_approx(road)
		and hud._draft_battle == null and not _mission._interact, "Cross submits one validated Move rather than Hold or hero action.")

	var roof := _point("Routes/RecordRoomInside")
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(roof))
	_tap(JOY_BUTTON_DPAD_UP)
	_tap(JOY_BUTTON_A)
	_tap(JOY_BUTTON_X)
	_check(_orders == [0] and selected.destination.is_equal_approx(road) and hud._draft_blocked
		and hud._draft_battle != null and hud._hint.text.contains("Blocked"), "Roof is rejected without fall-through or losing the draft.")
	await _capture_image("controller-map-roof-blocked")
	_axis(JOY_AXIS_LEFT_X, 0.91)
	_draft_tick(5)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var hero := _mission.battle.hero_position
	_axis(JOY_AXIS_LEFT_X, 0.91)
	_tick(10)
	_check(hud._draft_battle == null and not _map.is_visible_in_tree() and _orders == [0]
		and _mission.battle.hero_position.is_equal_approx(hero), "L2 release discards aim and cannot move the hero on a held stick.")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_X, 0.65)
	_tick(12)
	_check(_mission.battle.hero_position.distance_to(hero) > 0.1, "Neutral followed by new input restores the existing hero stick.")
	_axis(JOY_AXIS_LEFT_X, 0.0)

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tap(JOY_BUTTON_DPAD_UP)
	_axis(JOY_AXIS_RIGHT_Y, 0.8)
	_axis(JOY_AXIS_LEFT_X, 0.8)
	_draft_tick(3)
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var at_unfocus := _mission.battle.hero_position
	var angle := _mission._hero_pitch
	_axis(JOY_AXIS_LEFT_X, 0.83)
	_axis(JOY_AXIS_RIGHT_Y, 0.83)
	_tick(8)
	_check(_orders == [0] and hud._draft_battle == null and not _map.is_visible_in_tree()
		and _mission.battle.hero_position.is_equal_approx(at_unfocus) and is_equal_approx(_mission._hero_pitch, angle),
		"Focus loss clears draft and quarantines held movement and orbit axes.")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	_mission.restart_mission()


func _draft_tick(count: int) -> void:
	for _i in range(count):
		_mission._command_minimap._physics_process(DT)
		_tick()


func _tap(index: JoyButton) -> void:
	_button(index)
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = false
	root.push_input(event, true)


func _campaign_pointer_return() -> void:
	var profile_path := OS.get_temp_dir().path_join("torn-sereth-cut-map-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(profile_path)
	profile.set_setting("fullscreen", false)
	profile.set_setting("reduced_motion", true)
	var title: Title = TitleScene.instantiate()
	title._profile = profile
	root.add_child(title)
	await process_frame
	await _press_at(title, "New Game")
	await _press_at(title, "sereth")
	await _travel_and_return(title, profile)
	title.queue_free()
	await process_frame
	for path in [profile_path, profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _travel_and_return(title: Title, profile: Profile) -> void:
	var overworld: CampaignMap = title._stage.get_node_or_null("CampaignMap")
	_check(title._page == Title.Page.WORLD_MAP and overworld != null
		and title._campaign_world.current_waypoint_id() == "still_kingdom_camp",
		"Pointer selects Sereth and starts at his authored camp.")
	if not overworld:
		return
	var waypoint: Vector2 = title._campaign_world.waypoint("still_kingdom_cut").map_position
	var pin: Vector2 = overworld._board.get_global_transform_with_canvas() * overworld._board.point_at(waypoint)
	_click(MOUSE_BUTTON_LEFT, pin)
	_check(overworld.selected_waypoint_id() == "still_kingdom_cut"
		and title._campaign_world.current_waypoint_id() == "still_kingdom_camp", "Clicking a real pin selects, not travels.")
	await _press_at(title, "ConfirmTravel")
	_check(title._page == Title.Page.MISSION_BRIEFING and title._campaign_battle == null,
		"Travel opens, but does not deploy through, the actual briefing.")
	await _press_at(title, "Confirm Deployment")
	_mission = title._campaign_battle as Mission
	_check(_mission != null and title._page == Title.Page.CAMPAIGN_BATTLE, "Actual briefing deploys the Cut.")
	if not _mission:
		return
	_mission.set_physics_process(false)
	_map = _mission._command_minimap.map
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	await process_frame
	var back := title._stage.get_node_or_null("ReturnToMap") as Button
	_check(_mission.command_view and _map.is_visible_in_tree() and _hud_fits() and back != null,
		"Test button access in active command rather than before opening the map.")
	if not back:
		return
	var button_rect := back.get_global_rect()
	var panel_rect := _mission._command_minimap.get_global_rect()
	_check(not panel_rect.intersects(button_rect) and root.get_visible_rect().encloses(button_rect),
		"The minimap must not cover the shell's Return to Campaign Map button.")
	_tap(JOY_BUTTON_DPAD_UP)
	_check(_mission._command_minimap._aim.is_visible_in_tree(),
		"Return must also be available while an unsent controller draft is open.")
	await _capture_image("campaign-command-return-visible")
	_click(MOUSE_BUTTON_LEFT, button_rect.get_center())
	await process_frame
	_check(title._page == Title.Page.WORLD_MAP and title._campaign_battle == null
		and title._campaign_world.current_waypoint_id() == "still_kingdom_cut"
		and profile.completed_missions("sereth").is_empty(),
		"A real mouse click while L2 remains held returns to the Cut pin without awarding a victory.")
	await _capture_image("campaign-returned-to-cut")
	print("Sereth campaign pointer: panel %s / Return button %s / returned to Cut while L2 held." % [panel_rect, button_rect])


func _press_at(title: Title, name: String) -> void:
	var button := title._stage.find_child(name, true, false) as Button
	_check(button != null and button.is_visible_in_tree() and not button.disabled,
		"Expected live title control: " + name)
	if button:
		_click(MOUSE_BUTTON_LEFT, button.get_global_rect().get_center())
	await process_frame


func _hud_fits() -> bool:
	var panel := _mission._command_minimap.get_global_rect()
	var map_bounds := _map.get_global_rect()
	var objectives: Control = _mission.get_node("ObjectiveHUD/Panel")
	var commands: Control = _mission.get_node("HUD/Panel")
	return (root.get_visible_rect().encloses(panel) and panel.encloses(map_bounds)
		and not panel.intersects(objectives.get_global_rect()) and not panel.intersects(commands.get_global_rect()))


func _glyph(id: StringName) -> Minimap.Glyph:
	for glyph in _map._glyphs:
		if glyph.id == id:
			return glyph
	return null


func _point(path: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/" + path)))


func _mouse_map(button: MouseButton, at: Vector2) -> void:
	_click(button, _map.get_global_rect().position + at)


func _click(button: MouseButton, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.pressed = down
		root.push_input(event, true)


func _button(index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	root.push_input(event, true)


func _axis(index: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	root.push_input(event, true)


func _tick(count := 1) -> void:
	for _i in range(count):
		_mission._physics_process(DT)


func _capture_image(name: String) -> Image:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return null
	for _i in range(6):
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.save_png(_capture.path_join(name + ".png")) == OK, "Cannot save " + name)
	return image


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		push_error(message)
