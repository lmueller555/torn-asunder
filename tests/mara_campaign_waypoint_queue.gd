extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Pocket := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Adapter := preload("res://game/battlefield/mara_campaign_minimap.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _hud: Adapter


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	_mission.configure_campaign_lead_level(3)
	root.add_child(_mission)
	_mission.set_physics_process(false)
	_hud = _mission.get_node("MinimapHUD/Panel") as Adapter
	_hud.set_physics_process(false)
	await physics_frame
	await physics_frame
	await process_frame
	_hud.refresh()
	var passed := _mixed_march() and _cap_and_replace() and _attack_defeat_and_retry() and _pickup_unchanged()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Mara Mine queue: live command-only route projection, ridge march, click space, Attack/retry and custody/BP passed.")
	quit(0 if passed else 1)


func _mixed_march() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_tick()
	var archers := _mission.battle.formations[1]
	var head := _point("Routes/RidgeWestApproach")
	_focus(head)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	if _mission.selected_index != 1 or not _same_route(1, PackedVector2Array([head])) or not archers.destination.is_equal_approx(head):
		return _fail("Tactical R1 did not assign the real first leg to Archers: %s %s %s %s %s." % [_mission.selected_index, _hud.pending_waypoints(1), archers.destination, head, _hud._route_note])
	if not _projected_route(1, PackedVector2Array([head])) or _hud._reticle.visible:
		return _fail("The regular tactical map did not immediately show its own active queue.")
	_button(JOY_BUTTON_DPAD_UP)
	var world := _mission.cursor
	var roof := Vector2(-63, 94)
	if not _aim(roof):
		return false
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	if not _same_route(1, PackedVector2Array([head])) or not _hud._key.text.contains("Not a walkable"):
		return _fail("Invalid roof append changed the accepted route.")
	var foot := _point("Routes/RidgeWestFoot")
	var crest := _point("Routes/RidgeWestCrest")
	if not _aim(foot):
		return false
	_key(KEY_G)
	if not _aim(crest):
		return false
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	var route := PackedVector2Array([head, foot, crest])
	if not _same_route(1, route) or not archers.destination.is_equal_approx(head) \
			or not _projected_route(1, route) or not _hud._reticle.visible:
		return _fail("Focused R1/G did not append to the same visible route.")
	_button(JOY_BUTTON_B)
	if _hud._draft_battle or _hud._reticle.visible or _mission.cursor != world or not _projected_route(1, route):
		return _fail("Cancel hid an accepted command route or moved the world cursor.")
	# Click the drawn head: the overlay is transparent to the map's input.
	_focus(crest)
	_focus(head)
	if not _mission.cursor.is_equal_approx(head) or not _projected_route(1, route):
		return _fail("The overlay blocked inspection of a displayed point.")
	_button(JOY_BUTTON_DPAD_LEFT)
	_tick()
	if not _overlay_hidden() or not _hud.pending_waypoints(0).is_empty() or not _same_route(1, route):
		return _fail("The Archers' route appeared when Shield Infantry was selected.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_tick()
	if not _projected_route(1, route) or _hud.map.marker_pixel(&"Orc guard") != null:
		return _fail("The selected allied route did not return by itself on reselection.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	if not _overlay_hidden() or not _same_route(1, route):
		return _fail("Hero view exposed or stopped the active plan.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	if not _projected_route(1, route):
		return _fail("Returning to command did not restore the working plan.")
	var initial_height := _mission._ground(archers.position).y
	for leg in route.size():
		var at := route[leg]
		for _frame in 1350:
			if archers.position.is_equal_approx(at) or archers.order == Battle.Order.BLOCKED:
				break
			_tick()
		if not archers.position.is_equal_approx(at):
			return _fail("Archers did not physically reach the queued ground at %s." % at)
		var remaining := route.slice(leg + 1)
		if not (_overlay_hidden() if remaining.is_empty() else _projected_route(1, remaining)):
			return _fail("Numbered projection did not advance on physical waypoint arrival.")
	return (archers.order == Battle.Order.HOLD and _hud.pending_waypoints(1).is_empty() \
		and _mission._ground(archers.position).y - initial_height > 9.8 and _initial_mechanics()) \
		or _fail("The queue did not advance on real arrival, or affected the pickup/BP.")


func _cap_and_replace() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	var head := Vector2(-137, -24)
	_focus(head)
	_key(KEY_G)
	_button(JOY_BUTTON_DPAD_UP)
	_key(KEY_G) # Existing queue head, now via the map.
	if not _hud._key.text.contains("Already on") or not _same_route(1, PackedVector2Array([head])):
		return _fail("Duplicate points were not checked across both input sources.")
	for _step in Queue.MAX_WAYPOINTS - 1:
		_button(JOY_BUTTON_DPAD_RIGHT)
		_button(JOY_BUTTON_RIGHT_SHOULDER)
	var full := _hud.pending_waypoints(1)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	if full.size() != Queue.MAX_WAYPOINTS or not _same_route(1, full) or not _hud._key.text.contains("Route full"):
		return _fail("The live route did not reject its ninth pending point.")
	_button(JOY_BUTTON_B)
	_focus(head)
	# Even Move to the same current head is an explicit replacement.
	_button(JOY_BUTTON_X)
	var archers := _mission.battle.formations[1]
	if not _hud.pending_waypoints(1).is_empty() or not archers.destination.is_equal_approx(head) or archers.order != Battle.Order.MOVE:
		return _fail("Direct Move to the same point did not replace the old route.")
	_key(KEY_G)
	_button(JOY_BUTTON_DPAD_UP)
	var replacement := _hud._draft_point + Vector2(0, Adapter.CURSOR_NUDGE)
	_button(JOY_BUTTON_DPAD_DOWN)
	_button(JOY_BUTTON_A)
	if _hud._draft_battle or not _hud.pending_waypoints(1).is_empty() or not archers.destination.is_equal_approx(replacement):
		return _fail("Direct map Move did not replace the tactical route.")
	_key(KEY_G)
	_map_click(MOUSE_BUTTON_RIGHT, Vector2(2, 2))
	if not _projected_route(1, PackedVector2Array([replacement])):
		return _fail("A letterbox click cleared the displayed route.")
	_map_click(MOUSE_BUTTON_RIGHT, _hud.map.project(replacement))
	if not _overlay_hidden() or not _hud.pending_waypoints(1).is_empty() or not archers.destination.is_equal_approx(replacement):
		return _fail("A right-click at the rendered point failed to replace the route.")
	_key(KEY_G)
	_button(JOY_BUTTON_A)
	if not _overlay_hidden() or not _hud.pending_waypoints(1).is_empty() or archers.order != Battle.Order.HOLD:
		return _fail("Explicit Hold did not clear the queue.")
	return true


func _attack_defeat_and_retry() -> bool:
	_button(JOY_BUTTON_DPAD_LEFT)
	var safe := Vector2(-137, -24)
	_focus(safe)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	var expected := PackedVector2Array([safe])
	_button(JOY_BUTTON_Y) # No target at that point.
	if not _projected_route(0, expected):
		return _fail("A rejected Attack cleared the live plan drawing.")
	_focus(_mission.encounter.enemy_position)
	_button(JOY_BUTTON_Y)
	var infantry := _mission.battle.formations[0]
	if infantry.order != Battle.Order.ATTACK or not _hud.pending_waypoints(0).is_empty() or not _overlay_hidden():
		return _fail("Accepted Attack did not clear its prior route immediately.")
	_focus(safe)
	_key(KEY_G)
	if _hud.pending_waypoints(0).is_empty():
		return _fail("Could not register the pre-defeat route.")
	infantry.defeat() # Same definitive order state that enemy retaliation produces.
	if not _hud.pending_waypoints(0).is_empty() or not _overlay_hidden():
		return _fail("A defeated formation retained its queued points or route drawing.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_key(KEY_G)
	if _hud.pending_waypoints(1).is_empty():
		return _fail("Could not register the pre-retry route.")
	var old_battle := _mission.battle
	_button(JOY_BUTTON_START)
	_tick()
	if _mission.battle == old_battle or not _overlay_hidden() or not _hud.pending_waypoints(0).is_empty() or not _hud.pending_waypoints(1).is_empty() \
			or _mission.battle.formations[0].order != Battle.Order.HOLD or not _initial_mechanics():
		return _fail("Options retained old route listeners, defeat or altered launch level/BP.")
	# The replacement battle still binds actual command notifications.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_focus(safe)
	_key(KEY_G)
	var fresh := _hud.pending_waypoints(0)
	if fresh.is_empty():
		return _fail("The restarted battle no longer accepts a fresh live route.")
	old_battle.order_hold(0)
	if _hud.pending_waypoints(0) != fresh:
		return _fail("A stale order notification cleared the restarted battle's route.")
	return true


func _pickup_unchanged() -> bool:
	_tick()
	var visual := _mission._custody_case
	if not visual or not visual._tactical_case.is_visible_in_tree() or visual._keeper.is_visible_in_tree() \
			or _hud.map.marker_pixel(&"Godbridle") == null:
		return _fail("Retry did not restore the audited ground case and existing map pickup.")
	_mission.battle.hero_position = _point("Objectives/GodbridlePickup")
	_button(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Escort.Phase.AWAITING_PICKUP or not _hud.pending_waypoints(0).is_empty():
		return _fail("Command Cross triggered pickup instead of clearing the queue.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_key(KEY_G)
	var marker_route := _hud.pending_waypoints(0)
	if marker_route.size() != 1 or not marker_route[0].is_equal_approx(_mission.march_marker):
		return _fail("Hero R1 did not add the waypoint marker once, or G duplicated it.")
	_mission.clear_march_route()
	if not _hud.pending_waypoints(0).is_empty():
		return _fail("Clearing the marker route left waypoints behind.")
	_button(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Escort.Phase.ESCORTING or not visual._case.is_visible_in_tree() \
			or not visual._keeper.is_visible_in_tree() or visual._tactical_case.is_visible_in_tree() \
			or _hud.map.marker_pixel(&"Godbridle") != null or _hud.map.marker_pixel(&"East exit") == null:
		return _fail("Hero pickup did not show the audited carry state and existing exit marker.")
	var carry := _mission._hero.global_transform.inverse() * visual.global_transform
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	var route := PackedVector2Array([Vector2(-137, -24)])
	_focus(route[0])
	_key(KEY_G)
	if not _projected_route(0, route) or _hud.map.marker_pixel(&"East exit") == null:
		return _fail("The accepted order and real carry objective did not appear together.")
	if not visual._tactical_case.is_visible_in_tree() or visual._keeper.is_visible_in_tree() \
			or not (_mission._hero.global_transform.inverse() * visual.global_transform).is_equal_approx(carry):
		return _fail("The route camera changed the carry mount or broke the tactical alternate.")
	var pocket := Pocket.instantiate()
	var opt_in := not pocket.has_node("MinimapHUD")
	pocket.free()
	return (opt_in and _mission.encounter.points.balance == 400 and _mission.encounter.points.frame().lead_level == 3) \
		or _fail("Cueing a route changed the Mine-only boundary or the launch level/BP.")


func _projected_route(index: int, expected: PackedVector2Array) -> bool:
	var overlay := _hud._route_overlay
	if expected.is_empty() or not overlay.is_visible_in_tree() or not _same_route(index, expected):
		return false
	var pixels := overlay.waypoint_pixels()
	if pixels.size() != expected.size():
		return false
	for step in pixels.size():
		if not pixels[step].is_equal_approx(_hud.map.project(expected[step])):
			return false
	var marching := _mission.battle.formations[index]
	var leg := overlay.active_leg_pixels()
	return leg.size() == 2 and leg[0].is_equal_approx(_hud.map.project(marching.position)) \
		and leg[1].is_equal_approx(pixels[0])


func _overlay_hidden() -> bool:
	var overlay := _hud._route_overlay
	return not overlay.is_visible_in_tree() and overlay.waypoint_pixels().is_empty() and overlay.active_leg_pixels().is_empty()


func _same_route(index: int, expected: PackedVector2Array) -> bool:
	var actual := _hud.pending_waypoints(index)
	if actual.size() != expected.size():
		return false
	for point in actual.size():
		if not actual[point].is_equal_approx(expected[point]):
			return false
	return true


func _initial_mechanics() -> bool:
	return _mission.objective.phase == Escort.Phase.AWAITING_PICKUP and _mission.encounter.points.balance == 400 \
		and _mission.encounter.points.frame().lead_level == 3 and _mission.encounter.points.capacity == 740


func _point(id: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/" + id)))


func _focus(point: Vector2) -> void:
	_map_click(MOUSE_BUTTON_LEFT, _hud.map.project(point))


func _map_click(button: MouseButton, pixel: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = _hud.map.get_global_rect().position + pixel
	root.push_input(event, true)


func _aim(point: Vector2) -> bool:
	var offset := point - _hud._draft_point
	var nudge := Adapter.CURSOR_NUDGE
	for _step in absi(roundi(offset.x / nudge)):
		_button(JOY_BUTTON_DPAD_RIGHT if offset.x > 0.0 else JOY_BUTTON_DPAD_LEFT)
	for _step in absi(roundi(offset.y / nudge)):
		_button(JOY_BUTTON_DPAD_DOWN if offset.y > 0.0 else JOY_BUTTON_DPAD_UP)
	var remainder := point - _hud._draft_point
	if remainder.length() > 0.01:
		var stick := remainder / (Adapter.CURSOR_SPEED * DT)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		# Advance the scoped aim without stepping the march in the test.
		_hud._physics_process(DT)
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
	return (_hud._draft_battle != null and _hud._draft_point.is_equal_approx(point)) \
		or _fail("The focused controller cursor did not reach an authored waypoint.")


func _tick() -> void:
	_mission._physics_process(DT)
	_hud._physics_process(DT)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)


func _button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
