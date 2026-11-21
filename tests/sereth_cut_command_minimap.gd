extends SceneTree

const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const CampaignMap := preload("res://game/campaign_map.gd")
const Profile := preload("res://game/profile_store.gd")
const Registry := preload("res://game/campaign_deployments.gd")
const Mission := preload("res://game/battlefield/sereth_cut_playtest.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
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
	# The hero waypoint beam is activated by physics independently of the map.
	_tick()
	var before := await _capture_image("hero-without-map")
	_mission.enable_command_minimap = true
	_mission._sync_view() # Refresh the map without stepping the eased hero camera.
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
	await _hero_waypoints()
	await _waypoint_queue()
	await _blocked_queue()
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
	# Direct stick control belongs to combat; use the free leader to check input recovery.
	_mission.battle.lead_platoon_enabled = false
	_axis(JOY_AXIS_LEFT_X, 0.65)
	_tick(12)
	_mission.battle.lead_platoon_enabled = true
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


func _hero_waypoints() -> void:
	var hud := _mission._command_minimap
	var lead := _mission.battle.lead
	var lead_index := Battle.LEAD_INDEX
	_orders.clear()
	_mission.battle.formation_commanded.connect(func(index: int) -> void: _orders.append(index))
	_tick() # Let the lead model settle at the authored spawn after restart.
	_key(KEY_Z)
	_tick()
	_check(_mission.selected_index == lead_index and _mission.march_mode() and _mission._march_beam.is_visible_in_tree()
		and not _map.is_visible_in_tree(), "Keyboard selects Sereth's lead and the hero-view marker, not the command map.")
	var first := _point("Routes/ApproachRoadWest")
	var before: Vector2 = _mission.march_marker
	var yaw: float = _mission._hero_yaw
	_key_event(KEY_D, true)
	_tick(15)
	_key_event(KEY_D, false)
	_check(_mission.march_marker.distance_to(before) > 1.0 and not is_equal_approx(_mission._hero_yaw, yaw),
		"Keyboard swings the marker round the lead platoon and the camera turns to face it.")
	first = _aim_hero_marker(first)
	_key(KEY_G)
	_check(_route_is(lead_index, [first]) and _orders == [lead_index] and lead.order == Battle.Order.MOVE
		and lead.destination == first, "Hero G sends the lead platoon to the first plotted waypoint.")

	var second := _aim_hero_marker(first + Vector2(16.0, 0.0))
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_route_is(lead_index, [first, second]) and _orders == [lead_index] and lead.destination == first
		and _mission._route_pins[1].visible and not hud._route_overlay.visible,
		"Hero R1 appends without interrupting the first leg or drawing an interactive minimap.")
	await _capture_image("hero-marker-queued-route")
	_mouse_map(MOUSE_BUTTON_RIGHT, _map.get_global_rect().size / 2.0)
	_check(_route_is(lead_index, [first, second]) and _orders == [lead_index], "The hidden map cannot replace a marker route.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_check(_map.is_visible_in_tree() and _route_drawn(lead, first) and _orders == [lead_index],
		"Opening command view shows the same two plotted legs without issuing either again.")
	await _capture_image("hero-marker-route-in-command-view")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	_check(not _map.is_visible_in_tree() and hud._route_overlay.waypoint_pixels().is_empty()
		and _route_is(lead_index, [first, second]), "Returning to the marker hides the map, not the accepted route.")

	_wait_at_waypoint(lead, first)
	_check(lead.destination == second and _orders == [lead_index, lead_index],
		"Only actual arrival promotes the controller's second leg.")
	var third := _aim_hero_marker(_point("Routes/WestLaneRoadJunction"))
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_route_is(lead_index, [second, third]) and lead.destination == second,
		"The marker can extend an already marching route to the authored West Lane junction.")
	_wait_at_waypoint(lead, second)
	_wait_at_waypoint(lead, third, 640)
	_check(_orders == [lead_index, lead_index, lead_index] and _route_is(lead_index, [])
		and lead.order == Battle.Order.HOLD and _mission.battle.hero_position == third,
		"Sereth physically traverses all three legs and holds at the junction with no queued points.")
	_mission.restart_mission()

	# Isolate the late-lane terrain from the long approach and keep the actual
	# selected Household Guard, marker input, and physical Cut collision.
	var guard := _mission.battle.formations[0]
	guard.position = _point("Routes/LaneClerkTurn")
	guard.hold()
	_orders.clear()
	_mission.battle.formation_commanded.connect(func(index: int) -> void: _orders.append(index))
	_tick()
	var narrow := _aim_hero_marker(Vector2(-30.5, 7.0))
	_key(KEY_G)
	_check(hud._walkable_hit(narrow) != null and not _mission._terrain.formation_fits_at(narrow)
		and _route_is(0, []) and _orders.is_empty() and _mission._march_note == "Can't march there",
		"Walkable ground beside the East Inner Baffle still rejects a full formation footprint.")
	var yard := _aim_hero_marker(_point("Routes/ClerkYard"))
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_route_is(0, [yard]) and _orders == [0] and guard.destination == yard,
		"Hero R1 also starts a valid move for the selected Household Guard.")
	var roof := _aim_hero_marker(_point("Routes/RecordRoomInside"))
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(hud._walkable_hit(roof) == null and _route_is(0, [yard]) and _orders == [0]
		and guard.destination == yard and _mission._march_note == "Can't march there",
		"The hero marker cannot plot through the record room roof or replace the valid march.")
	_tap(JOY_BUTTON_DPAD_UP)
	_check(_route_is(0, []) and _orders == [0, 0] and guard.order == Battle.Order.HOLD
		and hud._draft_battle == null and not _map.is_visible_in_tree(),
		"Outside command view D-pad Up clears the accepted route and holds; it never opens minimap aim.")
	_mission.restart_mission()


func _aim_hero_marker(target: Vector2) -> Vector2:
	for _frame in 300:
		var aim := (target - _mission.march_marker).rotated(_mission._hero_yaw)
		if aim.length() < 0.01:
			break
		var strength := clampf(aim.length() / (Harness.MARKER_SPEED * DT), 0.0, 1.0)
		var stick := aim.normalized() * lerpf(Harness.STICK_DEADZONE, 1.0, strength)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_mission.march_marker.distance_to(target) < 0.03, "Controller must reach marker target %s." % target)
	return _mission.march_marker


func _wait_at_waypoint(platoon: Battle.Formation, point: Vector2, limit := 360) -> void:
	for _frame in limit:
		if platoon.position == point or platoon.order == Battle.Order.BLOCKED:
			break
		_tick()
	_check(platoon.position == point, "The platoon physically reaches hero-marker waypoint %s." % point)


func _waypoint_queue() -> void:
	var hud := _mission._command_minimap
	var guard := _mission.battle.formations[0]
	var first := _point("Routes/ApproachRoadWest")
	var second := first + Vector2(3, 0)
	var roof := _point("Routes/RecordRoomInside")
	_orders.clear()
	_mission.battle.formation_commanded.connect(func(index: int) -> void: _orders.append(index))
	_key_event(KEY_SHIFT, true)
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(first))
	_key(KEY_G)
	_key_event(KEY_SHIFT, false)
	_check(_route_is(0, [first]) and _orders == [0] and guard.destination.is_equal_approx(first),
		"Shift + G sends the first tactical waypoint for the selected guard.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(first))
	_tap(JOY_BUTTON_DPAD_UP)
	_tap(JOY_BUTTON_DPAD_RIGHT)
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_route_is(0, [first, second]) and _orders == [0] and guard.destination.is_equal_approx(first)
		and hud._draft_battle != null and _mission.cursor.is_equal_approx(first),
		"Focused R1 appends without replacing the underway leg, moving the world cursor or closing aim.")
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_route_is(0, [first, second]) and hud._hint.text.contains("Already on"), "Duplicate route points do not issue orders.")
	await _capture_image("controller-map-queued-route")
	_tap(JOY_BUTTON_B)
	_check(hud._draft_battle == null and _route_is(0, [first, second]) and _route_drawn(guard, first),
		"Circle discards the reticle, not the accepted route or its active leg.")
	_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(not hud._route_overlay.visible and _route_is(1, []) and _route_is(0, [first, second]),
		"The other guard has its own queue and cannot see the first guard's plan.")
	_tap(JOY_BUTTON_DPAD_LEFT)
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(roof))
	_tap(JOY_BUTTON_DPAD_UP)
	_key(KEY_G)
	_check(_route_is(0, [first, second]) and _orders == [0] and hud._draft_battle != null
		and hud._hint.text.contains("Not a walkable"), "The record room roof cannot append through the map.")
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _mission.command_view and hud._draft_battle == null and _route_is(0, [first, second])
		and not hud._route_overlay.visible and hud._route_overlay.waypoint_pixels().is_empty(),
		"Focus loss cancels the unsent draft and hides the drawing without canceling the accepted march.")

	for leg in [first, second]:
		for _frame in 340:
			if guard.position.is_equal_approx(leg) or guard.order == Battle.Order.BLOCKED:
				break
			_tick()
		_check(guard.position.is_equal_approx(leg), "The selected guard physically navigates to queued road point %s." % leg)
		if leg == first:
			_check(_route_is(0, [second]) and guard.destination.is_equal_approx(second) and _orders == [0, 0],
				"Only arrival at the first point promotes the accepted second leg.")
	_check(guard.order == Battle.Order.HOLD and _route_is(0, []), "After both legs, the selected guard holds.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(first))
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_tap(JOY_BUTTON_DPAD_UP)
	for _step in Queue.MAX_WAYPOINTS - 1:
		_tap(JOY_BUTTON_DPAD_RIGHT)
		_tap(JOY_BUTTON_RIGHT_SHOULDER)
	var full := hud.pending_waypoints(0)
	_tap(JOY_BUTTON_DPAD_RIGHT)
	_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(full.size() == Queue.MAX_WAYPOINTS and hud.pending_waypoints(0) == full
		and hud._hint.text.contains("Route full"), "The live Cut rejects a ninth unvisited point, counting the active leg.")
	_tap(JOY_BUTTON_B)
	_mouse_map(MOUSE_BUTTON_RIGHT, _map.project(roof))
	_mouse_map(MOUSE_BUTTON_RIGHT, Vector2(2, 2))
	_check(hud.pending_waypoints(0) == full, "Rejected single moves do not discard accepted route points.")
	_tap(JOY_BUTTON_X)
	_check(_route_is(0, []) and guard.destination.is_equal_approx(first) and not hud._route_overlay.visible,
		"Ordinary Move to even the same destination replaces the entire route.")
	_key(KEY_G)
	_tap(JOY_BUTTON_DPAD_UP)
	_tap(JOY_BUTTON_DPAD_RIGHT)
	_tap(JOY_BUTTON_A)
	_check(_route_is(0, []) and guard.destination.is_equal_approx(second) and hud._draft_battle == null,
		"Direct Cross in minimap aim also replaces the accepted route with one Move.")
	_key(KEY_G)
	_tap(JOY_BUTTON_A)
	_check(_route_is(0, []) and guard.order == Battle.Order.HOLD and not _mission._interact,
		"Normal command Hold clears the queue without interacting with the mission.")
	_key(KEY_G)
	var ending := Cut.Observation.new()
	ending.sereth_fell = true
	_mission.objective.advance(ending)
	_mission._sync_view()
	_check(_route_is(0, []) and not hud._route_overlay.visible, "Terminal mission cleanup discards queued points.")
	var old_battle := _mission.battle
	_tap(JOY_BUTTON_START)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(first))
	_key(KEY_G)
	old_battle.order_hold(0)
	_check(_mission.battle != old_battle and _route_is(0, [first]), "A restarted Cut has a fresh queue and ignores stale battle signals.")
	_mission.restart_mission()


func _blocked_queue() -> void:
	var hud := _mission._command_minimap
	var guard := _mission.battle.formations[0]
	var start := _point("Routes/LaneSouthTurn")
	var first := _point("Routes/LaneEastTurn")
	var second := _point("Routes/LaneClerkTurn")
	var roof := _point("Routes/RecordRoomInside")
	# Isolate the straight leg across the authored EastInnerBaffle, not the
	# approach from spawn past the west baffle. Only movement itself is stepped.
	guard.position = start
	guard.hold()
	_orders.clear()
	_mission.battle.formation_commanded.connect(func(index: int) -> void: _orders.append(index))
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	for point in [first, second, roof]:
		_mouse_map(MOUSE_BUTTON_LEFT, _map.project(point))
		_key(KEY_G)
	_check(_route_is(0, [first, second]) and _orders == [0] and hud._hint.text.contains("Not a walkable"),
		"Accept the standable endpoints even though the first leg crosses a baffle; reject the roof.")
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(start))
	_check(not hud._hint.text.contains("Not a walkable"), "Invalid append feedback belongs to the cursor point that was tried.")
	for _frame in 500:
		_tick()
		if guard.order == Battle.Order.BLOCKED:
			break
	var stopped := guard.position
	_check(is_equal_approx(stopped.y, start.y) and stopped.x > -32.0 and stopped.x < -31.0
		and guard.destination.is_equal_approx(first) and guard.order == Battle.Order.BLOCKED,
		"The guard physically stops on the west face of EastInnerBaffle, not at the accepted head.")
	_check(hud._hint.text.contains("Route blocked") and _hud_fits(),
		"The command map explains the paused route without colliding with other HUD panels.")
	await _capture_image("blocked-queue-at-east-inner-baffle")
	_key(KEY_G) # This different, valid point joins the tail; it cannot bypass the baffle.
	_tick(90)
	_check(_orders == [0] and guard.position == stopped and guard.order == Battle.Order.BLOCKED
		and _route_is(0, [first, second, start]) and hud._route_overlay.active_leg_pixels().is_empty(),
		"No blocked leg is consumed or skipped, even after another valid point is appended.")
	_mouse_map(MOUSE_BUTTON_RIGHT, _map.project(start))
	_check(_orders == [0, 0] and _route_is(0, []) and guard.order == Battle.Order.MOVE
		and not hud._hint.text.contains("Route blocked"), "A safe direct Move replaces the paused route.")
	_tick(480)
	_check(guard.position.is_equal_approx(start) and guard.order == Battle.Order.HOLD,
		"The guard marches back along the safe side of the baffle instead of promoting the discarded tail.")

	# Hold the cursor still on a failed append across an accepted head's arrival.
	# The old error must not mask the new leg/count.
	var short_leg := start + Vector2.LEFT * 3.0
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(short_leg))
	_key(KEY_G)
	var actual_head := guard.destination
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(start))
	_key(KEY_G)
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(roof))
	_key(KEY_G)
	_check(_route_is(0, [short_leg, start]) and hud._hint.text.contains("Not a walkable"),
		"Keep invalid append feedback while the failed aim and route state are current.")
	for _frame in 70:
		_tick()
		if guard.position == actual_head:
			break
	_check(_route_is(0, [start]) and hud._hint.text.contains("1/8") and not hud._hint.text.contains("Not a walkable"),
		"Head arrival restores the count for the next leg even if the cursor did not move.")
	_mission.restart_mission()


func _route_is(index: int, expected: Array) -> bool:
	var pending := _mission._command_minimap.pending_waypoints(index)
	if pending.size() != expected.size():
		return false
	for i in expected.size():
		if not pending[i].is_equal_approx(expected[i]):
			return false
	return true


func _route_drawn(guard: Battle.Formation, first: Vector2) -> bool:
	var overlay := _mission._command_minimap._route_overlay
	var active := overlay.active_leg_pixels()
	return overlay.is_visible_in_tree() and overlay.waypoint_pixels().size() == 2 and active.size() == 2 \
		and active[0].is_equal_approx(_map.project(guard.position)) and active[1].is_equal_approx(_map.project(first))


func _key(code: Key) -> void:
	_key_event(code, true)
	_key_event(code, false)


func _key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


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
	var back := title._stage.get_node_or_null("PauseBattle") as Button
	_check(_mission.command_view and _map.is_visible_in_tree() and _hud_fits() and back != null,
		"Test button access in active command rather than before opening the map.")
	if not back:
		return
	var button_rect := back.get_global_rect()
	var panel_rect := _mission._command_minimap.get_global_rect()
	_check(not panel_rect.intersects(button_rect) and root.get_visible_rect().encloses(button_rect),
		"The minimap must not cover the shell's Pause button.")
	var road := _point("Routes/ApproachRoadWest")
	_mouse_map(MOUSE_BUTTON_LEFT, _map.project(road))
	_key(KEY_G)
	_tap(JOY_BUTTON_DPAD_UP)
	_tap(JOY_BUTTON_DPAD_RIGHT)
	_check(_mission._command_minimap._aim.is_visible_in_tree() and _route_is(0, [road]),
		"Return must be available even with an accepted route and a separate unsent aim.")
	await _capture_image("campaign-command-pause-visible")
	_click(MOUSE_BUTTON_LEFT, button_rect.get_center())
	await process_frame
	_check(paused and PauseTest.confirm_leave(title._pause_menu), "Pause must freeze the battle and allow leaving after confirmation.")
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
