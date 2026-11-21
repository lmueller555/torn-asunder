extends SceneTree

const Scene := preload("res://game/battlefield/controller_minimap_playtest.tscn")
const Preview := preload("res://game/battlefield/controller_minimap_playtest.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Mode := Preview.Mode
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const DT := 1.0 / 60.0

var _preview: Preview


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_preview = Scene.instantiate()
	root.add_child(_preview)
	_preview.set_physics_process(false)
	await process_frame
	var passed := _cancel_draft() and _confirm_and_walk() and _keyboard_cancel() \
		and _shared_route_walk() and _cap_and_replace_route() and _follow_then_hero()
	_preview.queue_free()
	await process_frame
	if passed:
		print("Controller minimap: bounded draft, no input leak, shared two-leg walk and live overlay projection, route cap/replacement, ally follow and hero handoff passed.")
	quit(0 if passed else 1)


func _cancel_draft() -> bool:
	_button(JOY_BUTTON_DPAD_RIGHT)
	var shields := _preview.battle.formations[Preview.SHIELDS]
	if not _project(Vector2(-8.0, 9.0)):
		return false
	var initial_order := shields.destination
	var world_cursor := _preview.cursor
	var position := shields.position
	_button(JOY_BUTTON_DPAD_UP)
	if not _preview._map_open or not _preview._reticle.visible or _preview._map_cursor != world_cursor:
		return _fail("The controller did not open a reticle on the current world cursor.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_DPAD_UP)
	if _preview._map_cursor != world_cursor + Vector2(1.0, -1.0) \
			or not _preview._reticle.point.is_equal_approx(_preview._map.project(_preview._map_cursor)):
		return _fail("Map directions or reticle projection did not stay north-up.")
	_joy(JOY_BUTTON_X, true)
	if not _project(Vector2(2.0, 1.0), false):
		return false
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_tick(220)
	if not is_equal_approx(_preview._map_cursor.x, _preview.battle.bounds.end.x) \
			or _preview.policy.selected_id() != &"shields" or _preview.cursor != world_cursor \
			or shields.destination != initial_order or shields.position == position:
		return _fail("The scope changed selection/world order, lost a live march, or escaped field bounds.")
	_joy(JOY_BUTTON_X, false)
	_button(JOY_BUTTON_B)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_tick(10)
	if _preview._map_open or _preview._reticle.visible or _preview.cursor != world_cursor \
			or shields.destination != initial_order or not _preview._map_note.contains("No order"):
		return _fail("Cancel issued an order or let the held stick move the world cursor.")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_tick(10)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	return _preview.cursor.x < world_cursor.x or _fail("An explicit neutral/new stick input did not restore world controls.")


func _confirm_and_walk() -> bool:
	var shields := _preview.battle.formations[Preview.SHIELDS]
	if not _project(Vector2(-9.0, 5.0)):
		return false
	var world_cursor := _preview.cursor
	_button(JOY_BUTTON_DPAD_UP)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_DPAD_DOWN)
	var destination := _preview._map_cursor
	_joy(JOY_BUTTON_A, true)
	# Cross normally means Hold in this harness; repeats/releases belonging
	# to the handled confirmation must not cancel that just-issued move.
	_joy(JOY_BUTTON_A, true)
	_joy(JOY_BUTTON_A, false)
	if _preview._map_open or shields.order != Battle.Order.MOVE or shields.destination != destination \
			or _preview.cursor != world_cursor or not _preview._map_note.contains("Move sent"):
		return _fail("Confirmation did not issue exactly the drafted Move independently of the world cursor.")
	return _wait(func() -> bool:
		return shields.order == Battle.Order.HOLD and shields.position.is_equal_approx(destination), 200
	) or _fail("The selected platoon did not physically walk to the map destination.")


func _keyboard_cancel() -> bool:
	var world_cursor := _preview.cursor
	var shields := _preview.battle.formations[Preview.SHIELDS]
	var previous := shields.destination
	_key(KEY_N)
	_key(KEY_LEFT)
	_key(KEY_DOWN)
	if not _preview._map_open or _preview._map_cursor != world_cursor + Vector2(-1.0, 1.0):
		return _fail("Keyboard input did not aim the same scoped minimap reticle.")
	_key(KEY_ESCAPE)
	return (not _preview._map_open and shields.destination == previous and _preview.cursor == world_cursor) \
		or _fail("Keyboard cancel did not preserve the world and prior order.")


func _shared_route_walk() -> bool:
	var shields := _preview.battle.formations[Preview.SHIELDS]
	var original := shields.position
	_aim(Vector2(-10.0, 8.0))
	var first := _preview.cursor
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	if _preview._routes.snapshot(Preview.SHIELDS) != PackedVector2Array([first]) or shields.destination != first:
		return _fail("Tactical R1 did not append to the selected shield platoon's route.")
	_button(JOY_BUTTON_DPAD_UP)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_DPAD_DOWN)
	var second := _preview._map_cursor
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	var expected := PackedVector2Array([first, second])
	if not _preview._map_open or _preview._routes.snapshot(Preview.SHIELDS) != expected \
			or shields.destination != first or _preview._route_overlay.waypoint_pixels().size() != 2 \
			or not _preview._map_title.text.contains("Shield Infantry"):
		return _fail("Map R1 replaced the first leg, hid the combined route, or changed its named receiver.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_B)
	if _preview._map_open or _preview.cursor != first or _preview._routes.snapshot(Preview.SHIELDS) != expected \
			or _preview._route_overlay.visible or not _preview._route_overlay.waypoint_pixels().is_empty():
		return _fail("Cancel did not discard only the unsent draft or restore the tactical cursor.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_DPAD_UP)
	if not _preview._routes.snapshot(Preview.SCOUTS).is_empty() \
			or not _preview._route_overlay.waypoint_pixels().is_empty():
		return _fail("The focused map borrowed the other platoon's waypoints.")
	_button(JOY_BUTTON_B)
	_button(JOY_BUTTON_DPAD_LEFT)
	_button(JOY_BUTTON_DPAD_UP)
	if not _route_projects(expected, shields.position):
		return _fail("Focused map did not project numbers and the initial active leg from the live unit.")
	_tick(8)
	if shields.position == original or not _route_projects(expected, shields.position):
		return _fail("The active route line did not track the live formation while the map was open.")
	if not _wait(func() -> bool: return shields.position.is_equal_approx(first), 240) \
			or shields.destination != second or not _route_projects(PackedVector2Array([second]), first):
		return _fail("Arrival did not renumber the remaining point and highlight the second physical leg.")
	if not _wait(func() -> bool:
		return shields.order == Battle.Order.HOLD and shields.position.is_equal_approx(second), 140
	) or not _route_projects(PackedVector2Array(), null):
		return _fail("Arrival did not clear both the active leg and pending route on the open map.")
	_button(JOY_BUTTON_B)
	return true


func _cap_and_replace_route() -> bool:
	_aim(Vector2(-13.0, 7.0))
	var first := _preview.cursor
	_key(KEY_G)
	_button(JOY_BUTTON_DPAD_UP)
	_key(KEY_G)
	if not _preview._map_note.contains("Already on this route") \
			or _preview._routes.snapshot(Preview.SHIELDS) != PackedVector2Array([first]):
		return _fail("A repeated point from the other input source duplicated the shared route.")
	for _index in Queue.MAX_WAYPOINTS - 1:
		_button(JOY_BUTTON_DPAD_RIGHT)
		_key(KEY_G)
	var full := _preview._routes.snapshot(Preview.SHIELDS)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	if full.size() != Queue.MAX_WAYPOINTS or not _route_projects(full, _preview.battle.formations[Preview.SHIELDS].position) \
			or not _preview._map_note.contains("Route full") or not _preview._map_open:
		return _fail("Controller and keyboard append did not share the same eight-point cap.")
	_button(JOY_BUTTON_B)
	_button(JOY_BUTTON_DPAD_UP)
	_button(JOY_BUTTON_DPAD_DOWN)
	var replacement := _preview._map_cursor
	_button(JOY_BUTTON_A)
	if _preview._map_open or _preview._routes.snapshot(Preview.SHIELDS) != PackedVector2Array([replacement]):
		return _fail("Direct map Move did not replace the accepted queued route.")
	_key(KEY_H)
	_button(JOY_BUTTON_DPAD_UP)
	var cleared := _route_projects(PackedVector2Array(), null) and _preview.battle.formations[Preview.SHIELDS].order == Battle.Order.HOLD
	_button(JOY_BUTTON_B)
	return cleared or _fail("World Hold did not clear the overlay and the map-built route.")


func _follow_then_hero() -> bool:
	var shields := _preview.battle.formations[Preview.SHIELDS]
	if not _project(Vector2(-8.0, -5.0)) or not _wait(func() -> bool:
		return _preview.policy.mode() == Mode.PLATOON_FOLLOW, 260
	):
		return _fail("A real contact did not enter the ally order context.")
	_button(JOY_BUTTON_DPAD_UP)
	_button(JOY_BUTTON_DPAD_DOWN)
	var ally_point := _preview._map_cursor
	_button(JOY_BUTTON_A)
	if shields.order != Battle.Order.MOVE or shields.destination != ally_point:
		return _fail("Ally follow lost the ability to issue a controller minimap order.")
	_button(JOY_BUTTON_DPAD_LEFT)
	if _preview.policy.mode() != Mode.TACTICAL or not _project(Preview.SPAR_POSITION + Vector2(0.0, 1.0)):
		return _fail("The unengaged hero did not accept a real tactical approach order.")
	_button(JOY_BUTTON_DPAD_UP)
	if not _preview._map_open:
		return _fail("Could not draft while a pre-existing hero platoon march was running.")
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_LEFT_SHOULDER, true)
	if not _wait(func() -> bool: return _preview.policy.mode() == Mode.HERO_ACTION, 250):
		return _fail("The open minimap paused the march instead of encountering the practice opponent.")
	var pose := _preview.battle.hero_position
	# Inputs already consumed by the map stay consumed until they release.
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_LEFT_SHOULDER, true)
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_tick(15)
	if _preview._map_open or not _preview._map_note.contains("No minimap order") \
			or not _preview._hero_camera.is_current() or _preview.battle.hero_position != pose \
			or _preview.defense.attack_phase != Attack.Phase.IDLE or _preview.defense.phase != Defense.Phase.FREE:
		return _fail("The draft, held stick, attack or guard leaked into direct hero action.")
	_joy(JOY_BUTTON_X, false)
	_joy(JOY_BUTTON_LEFT_SHOULDER, false)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_DPAD_UP)
	if _preview._map_open or not _preview._map_help.text.contains("Read-only"):
		return _fail("The controller opened a command draft in hero action.")
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_key(KEY_G)
	if not _preview._routes.snapshot(Preview.HERO).is_empty() \
			or _preview.battle.formations[Preview.HERO].order != Battle.Order.HOLD \
			or _preview.defense.attack_phase != Attack.Phase.IDLE:
		return _fail("R1/G edited or triggered a route or attack in direct hero action.")
	_button(JOY_BUTTON_X)
	return _preview.defense.attack_phase == Attack.Phase.WINDUP \
		or _fail("A fresh explicit hero action remained muted after releasing modal input.")


func _route_projects(expected: PackedVector2Array, from: Variant) -> bool:
	if not _preview._route_overlay.visible or _preview._routes.snapshot(_preview.selected_index) != expected:
		return false
	var projected := PackedVector2Array()
	for point in expected:
		projected.append(_preview._map.project(point))
	if _preview._route_overlay.waypoint_pixels() != projected:
		return false
	var active := PackedVector2Array()
	if from != null and not projected.is_empty():
		active = PackedVector2Array([_preview._map.project(from), projected[0]])
	return _preview._route_overlay.active_leg_pixels() == active


func _aim(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _preview._command_camera.unproject_position(_preview._ground(point))
	root.push_input(event, true)


func _project(point: Vector2, check := true) -> bool:
	var event := InputEventMouseButton.new()
	event.position = _preview._command_camera.unproject_position(_preview._ground(point))
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)
	return (not check or _preview.cursor.distance_to(point) < 0.03) \
		or _fail("The world mouse command could not find %s." % point)


func _wait(condition: Callable, max_steps: int) -> bool:
	for _step in max_steps:
		if condition.call():
			return true
		_tick()
	return condition.call()


func _tick(frames := 1) -> void:
	for _frame in frames:
		_preview._physics_process(DT)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)


func _button(button: JoyButton) -> void:
	_joy(button, true)
	_joy(button, false)


func _joy(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
