extends SceneTree

const PreviewScene := preload("res://game/battlefield/engagement_camera_playtest.tscn")
const StockScene := preload("res://game/battlefield/command_harness.tscn")
const Preview := preload("res://game/battlefield/engagement_camera_playtest.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Mode := Preview.Mode
const DT := 1.0 / 60.0

var _preview: Preview


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_preview = PreviewScene.instantiate()
	root.add_child(_preview)
	_preview.set_physics_process(false)
	await physics_frame
	var passed := _follow_and_keep_orders() and _hero_context()
	_preview.queue_free()
	await process_frame
	passed = _stock_controls() and passed
	if passed:
		print("Engagement preview: projected Move, physical contact and camera follow, retained orders/cursor, direct hero attack/guard/dodge, unchanged stock L2 passed.")
	quit(0 if passed else 1)


func _follow_and_keep_orders() -> bool:
	if not _is_tactical() or _preview.policy.selected_id() != &"hero":
		return _fail("The unengaged hero selection did not start tactical.")
	var sample: Node3D = _preview._formation_members[Preview.SHIELDS][0]
	var source := sample.get_child(0) as MeshInstance3D
	var display := _preview._opponent_actors[0].get_child(0).get_child(0) as MeshInstance3D
	if display.mesh != source.mesh or display.material_override != source.material_override:
		return _fail("The standalone scene did not reuse inherited debug visuals.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _is_tactical():
		return _fail("L2 incorrectly overrode the physical contexts inside the preview.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	var shields := _preview.battle.formations[Preview.SHIELDS]
	var target := Vector2(-8.0, -7.8)
	if not _project(target, MOUSE_BUTTON_RIGHT) or shields.order != Battle.Order.MOVE:
		return _fail("Tactical Move did not project to the flat battlefield.")
	var cursor := _preview.policy.tactical_cursor()
	var start := shields.position
	if not _wait(func() -> bool: return _preview.policy.mode() == Mode.PLATOON_FOLLOW, 300):
		return _fail("Movement never reached the physical opponent or the follow camera did not engage.")
	var patrol := _preview._positions[0]
	if not _preview.command_view or not _preview._command_camera.is_current() \
			or _preview._command_camera.size != Preview.FOLLOW_SPAN \
			or shields.position == start or shields.position.distance_to(patrol) > Preview.CONTACT_RANGE \
			or patrol == Preview.PATROL_START or shields.order != Battle.Order.MOVE:
		return _fail("Follow did not correspond to moving actors, or it lost the prior Move order.")
	var before := shields.position
	var camera_before := _preview._command_camera.position
	_tick(10)
	var displacement := shields.position - before
	var camera_displacement := _preview._command_camera.position - camera_before
	if displacement.is_zero_approx() or not Vector2(camera_displacement.x, camera_displacement.z).is_equal_approx(displacement):
		return _fail("The follow camera did not track the selected ally's actual motion.")
	var follow_move := Vector2(-7.0, -4.5)
	var pointer := InputEventMouseMotion.new()
	pointer.position = _preview._command_camera.unproject_position(_preview._ground(follow_move))
	root.push_input(pointer, true)
	_joy(JOY_BUTTON_X)
	if not shields.destination.is_equal_approx(follow_move):
		return _fail("The following camera rejected a real new Move order.")
	_key(KEY_J)
	_joy(JOY_BUTTON_LEFT_SHOULDER)
	_joy(JOY_BUTTON_B)
	if _preview.defense.attack_phase != Attack.Phase.IDLE or _preview.defense.phase != Defense.Phase.FREE:
		return _fail("Ally follow accepted direct hero actions.")
	if not _wait(func() -> bool: return shields.order == Battle.Order.HOLD, 180) \
			or _preview.policy.mode() != Mode.PLATOON_FOLLOW:
		return _fail("The actual close-range Move failed to arrive without dropping ally follow.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	if not _is_tactical() or _preview.policy.selected_id() != &"scouts" \
			or not _preview.cursor.is_equal_approx(cursor) or not _preview.policy.tactical_cursor().is_equal_approx(cursor):
		return _fail("Cycling to an unengaged ally lost the original tactical cursor or pulled another fight along.")
	if not _project(Vector2(10.0, -10.0), MOUSE_BUTTON_RIGHT):
		return false
	var scouts := _preview.battle.formations[Preview.SCOUTS]
	_joy(JOY_BUTTON_DPAD_LEFT)
	var before_scouts := scouts.position
	_tick(10)
	if _preview.policy.mode() != Mode.PLATOON_FOLLOW or scouts.order != Battle.Order.MOVE \
			or scouts.position == before_scouts:
		return _fail("An independent order stopped while a different ally was followed.")
	return true


func _hero_context() -> bool:
	_joy(JOY_BUTTON_DPAD_LEFT)
	if not _is_tactical() or _preview.policy.selected_id() != &"hero":
		return _fail("Cycling back to an unengaged hero did not return tactical.")
	_key(KEY_J)
	if _preview.defense.attack_phase != Attack.Phase.IDLE:
		return _fail("The tactical camera admitted direct hero action.")
	var escort := _preview.battle.formations[Preview.HERO]
	var destination := Preview.SPAR_POSITION + Vector2(0.0, 1.1)
	var scouts := _preview.battle.formations[Preview.SCOUTS]
	var scout_destination := scouts.destination
	if not _project(destination, MOUSE_BUTTON_RIGHT) or escort.order != Battle.Order.MOVE:
		return _fail("A real tactical order did not start the hero platoon's approach.")
	var tactical_cursor := _preview.policy.tactical_cursor()
	if not _wait(func() -> bool: return _preview.policy.mode() == Mode.HERO_ACTION, 300) \
			or _preview.command_view or not _preview._hero_camera.is_current() or _preview._cursor_marker.visible \
			or _preview.battle.hero_position.distance_to(Preview.SPAR_POSITION) > Preview.CONTACT_RANGE \
			or scouts.destination != scout_destination:
		return _fail("The physical hero contact did not switch to direct controls without editing an ally's order.")
	var approach := _preview.battle.hero_position
	if not _walk_hero(destination) or _preview.battle.hero_position == approach or escort.order != Battle.Order.HOLD:
		return _fail("Direct stick input did not move the hero after handing off from the tactical Move.")
	_joy(JOY_BUTTON_LEFT_SHOULDER)
	_joy(JOY_BUTTON_X)
	if _preview.defense.phase != Defense.Phase.GUARD or _preview.defense.attack_phase != Attack.Phase.IDLE:
		return _fail("Hero guard was not active or admitted a concurrent strike.")
	_joy(JOY_BUTTON_LEFT_SHOULDER, false)
	var hp := _preview._opponents[1].hp
	_joy(JOY_BUTTON_X)
	if _preview.defense.attack_phase != Attack.Phase.WINDUP or not _wait(func() -> bool:
		return _preview._opponents[1].hp < hp, 30
	):
		return _fail("Hero Square was not a real contact-producing attack in action view.")
	if not _wait(func() -> bool: return _preview.defense.attack_phase == Attack.Phase.IDLE, 45):
		return _fail("The practice attack did not finish.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	if _preview.policy.mode() != Mode.PLATOON_FOLLOW or _preview.policy.selected_id() != &"shields":
		return _fail("The hero's fight stole the camera from the selected engaged ally.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	if not _is_tactical() or not _preview.cursor.is_equal_approx(tactical_cursor):
		return _fail("Cycling out of both engagement views lost the prior tactical cursor.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	if _preview.policy.mode() != Mode.HERO_ACTION:
		return _fail("Cycling onto the still-engaged hero did not restore action view.")
	var before := _preview.battle.hero_position
	var away := (before - Preview.SPAR_POSITION).normalized().rotated(_preview._hero_yaw)
	_axis(JOY_AXIS_LEFT_X, away.x)
	_axis(JOY_AXIS_LEFT_Y, away.y)
	_joy(JOY_BUTTON_B)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if _preview.defense.phase != Defense.Phase.DODGE_STARTUP or not _wait(_is_tactical, 70) \
			or _preview.battle.hero_position.distance_to(before) < 1.2 \
			or not _preview.cursor.is_equal_approx(tactical_cursor):
		return _fail("Physical dodge disengagement did not restore the tactical camera and cursor.")
	return true


func _stock_controls() -> bool:
	var stock: Harness = StockScene.instantiate()
	root.add_child(stock)
	stock.set_physics_process(false)
	var starts_live := not stock.command_view and stock._hero_camera.is_current()
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var holds_command := stock.command_view and stock._command_camera.is_current()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var returns_to_hero := not stock.command_view and stock._hero_camera.is_current()
	stock.queue_free()
	return (starts_live and holds_command and returns_to_hero) or _fail("The unmodified live harness no longer holds L2 for command.")


func _project(point: Vector2, button: MouseButton) -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = _preview._command_camera.unproject_position(_preview._ground(point))
	root.push_input(event, true)
	return _preview.cursor.distance_to(point) < 0.02 or _fail("Command camera did not project the cursor to %s." % point)


func _walk_hero(point: Vector2) -> bool:
	for _index in 60:
		var remaining := point - _preview.battle.hero_position
		if remaining.length() <= 0.13:
			break
		var input := remaining.normalized().rotated(_preview._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, input.x)
		_axis(JOY_AXIS_LEFT_Y, input.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _preview.battle.hero_position.distance_to(point) <= 0.13


func _is_tactical() -> bool:
	return _preview.policy.mode() == Mode.TACTICAL and _preview.command_view \
		and _preview._command_camera.is_current() and _preview._cursor_marker.visible


func _wait(check: Callable, limit: int) -> bool:
	for _step in limit:
		if check.call():
			return true
		_tick()
	return check.call()


func _tick(frames := 1) -> void:
	for _frame in frames:
		_preview._physics_process(DT)


func _key(code: Key) -> void:
	var input := InputEventKey.new()
	input.physical_keycode = code
	input.pressed = true
	root.push_input(input, true)


func _joy(button: JoyButton, pressed := true) -> void:
	var input := InputEventJoypadButton.new()
	input.button_index = button
	input.pressed = pressed
	root.push_input(input, true)


func _axis(axis: JoyAxis, value: float) -> void:
	var input := InputEventJoypadMotion.new()
	input.axis = axis
	input.axis_value = value
	root.push_input(input, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
