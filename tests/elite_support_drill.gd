extends SceneTree

const Scene := preload("res://game/battlefield/elite_support_drill.tscn")
const Drill := preload("res://game/battlefield/elite_support_drill.gd")
const Pulse := preload("res://game/combat/elite_support_pulse.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _drill: Drill
var _origin: Vector2
var _enemy_start: Vector2
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_drill = Scene.instantiate() as Drill
	root.add_child(_drill)
	_drill.set_physics_process(false)
	await physics_frame
	await physics_frame
	_origin = _drill.battle.formations[Drill.SOURCE].position
	_enemy_start = _drill.battle.formations[Drill.OPPOSING].position
	var title := _drill.get_node("DrillHUD/Panel/Margin/Rows/Title") as Label
	_check(_drill.battlefield_scene.resource_path.ends_with("/spanwater_lock_campaign.tscn")
		and title.text.contains("DEVELOPMENT PLAYTEST") and title.text.contains("UNAPPROVED GRAYBOX")
		and _drill._tell.mesh == _drill._cursor_marker.mesh and _drill._tell.material_override == _drill._cursor_marker.material_override,
		"The drill must reuse existing graybox terrain and harness graphics with a clear development label.")
	if _check_placement_and_resolve():
		_check_physical_evasion_and_contact()
	_drill.queue_free()
	await process_frame
	if _failures == 0:
		print("Elite support drill: actual keyboard/controller placement, Hold/role, shared BP, physical evasion and contact, and reset passed.")
	quit(0 if _failures == 0 else 1)


func _check_placement_and_resolve() -> bool:
	var start := Points.STARTING_BALANCE
	var pool := _drill._pool
	_key(KEY_C)
	if not _check(_drill._response.text.contains("command view") and pool.balance == start,
			"Hero-mode pulse input should be refused."):
		return false
	_key(KEY_SHIFT, true)
	_try_at(_ground(_origin + Vector2(9.0, 0.0)))
	if not _check(_drill._response.text.contains("within") and pool.balance == start,
			"A real cursor placement beyond 8 m must be refused without spending: %s at %s." % [_drill._response.text, _drill.cursor]):
		return false
	var pier := _drill._field.get_node("Geometry/Lock/UpstreamSupplyShed") as Node3D
	_try_at(pier.global_position + Vector3.UP * 1.2)
	if not _check(_drill._response.text.contains("walkable ground") and pool.balance == start,
			"A pointer over real non-walkable geometry must not use the last legal cursor."):
		return false
	_point(_ground(_origin + Vector2(1.7, 0.0)))
	_mouse_button(MOUSE_BUTTON_RIGHT, _ground(_origin + Vector2(1.7, 0.0)))
	if not _check(_drill.battle.formations[0].order == Battle.Order.MOVE, "The actual Move input must produce the source-not-Hold trial."):
		return false
	_key(KEY_C)
	if not _check(_drill._response.text.contains("must Hold") and pool.balance == start,
			"A moving support proxy may not start a tell."):
		return false
	_key(KEY_H)
	_try_at(_ground(_enemy_start))
	if not _check(_drill._pulse.phase == Pulse.Phase.ANNOUNCED and _drill._tell.visible and _drill._tell_text.visible
			and _drill._pulse.center.distance_to(_enemy_start) < 0.12 and pool.balance == start - Pulse.COST,
			"A legal keyboard order must reserve the exact point, show the actual tell and spend shared BP once."):
		return false
	_key(KEY_C)
	for _step in range(28):
		_tick()
	if not _check(_drill._tell.visible and _drill._opponent.cohesion == 100.0 and pool.balance == start - Pulse.COST,
			"An already announced order cannot spend twice; the visible tell precedes impact."):
		return false
	_tick_through_tell()
	return _check(not _drill._tell.visible and _drill._opponent.cohesion == 100.0 - Pulse.COHESION_PRESSURE
		and _drill._response.text.contains("Landed") and pool.balance == start - Pulse.COST,
		"A stationary exposed opposing group should take actual cohesion loss without a BP award.")


func _check_physical_evasion_and_contact() -> void:
	var pool := _drill._pool
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_joy(JOY_BUTTON_Y)
	if not _check(_drill._role_status.text.contains("Opposing foot") and _drill._response.text.contains("select Support")
			and pool.balance == Points.STARTING_BALANCE - Pulse.COST,
			"Only the selected support role can spend the shared BP."):
		return
	_joy(JOY_BUTTON_DPAD_LEFT)
	var center := _enemy_start + Vector2(-1.5, 0.0)
	_point(_ground(center))
	_joy(JOY_BUTTON_Y)
	if not _check(_drill._pulse.phase == Pulse.Phase.ANNOUNCED, "Controller Triangle should announce the second legal attempt."):
		return
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_point(_ground(_enemy_start + Vector2(6.0, 0.0)))
	_joy(JOY_BUTTON_X)
	_tick_through_tell()
	var enemy := _drill.battle.formations[1]
	if not _check(enemy.position.distance_to(_drill._pulse.center) > Pulse.RADIUS and _drill._response.text.contains("Evaded")
			and _drill._opponent.cohesion == 100.0 - Pulse.COHESION_PRESSURE and pool.balance == Points.STARTING_BALANCE - 2 * Pulse.COST,
			"A real Square Move across terrain must leave the measured ring by release; a miss still costs BP."):
		return
	_joy(JOY_BUTTON_DPAD_LEFT)
	_try_at(_ground(_enemy_start))
	if not _check(_drill._response.text.contains("insufficient shared BP") and pool == _drill._pool,
			"Both attempts must debit the same finite team pool, including a miss."):
		return
	_joy(JOY_BUTTON_START)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	if not _check(_drill._pool.balance == Points.STARTING_BALANCE and _drill._pulse.phase == Pulse.Phase.IDLE
			and _drill.battle.formations[1].position == _enemy_start and _drill._opponent.cohesion == 100.0,
			"Options restarts the drill, restoring the original team pool and physical formations."):
		return
	var shed := _drill._field.get_node("Geometry/Lock/UpstreamSupplyShed") as Node3D
	_point(shed.global_position + Vector3.UP * 1.2) # Leave an invalid mouse pick before using the stick.
	_axis(JOY_AXIS_LEFT_X, 1.0)
	for _step in range(50):
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_joy(JOY_BUTTON_Y)
	if not _check(_drill._pulse.phase == Pulse.Phase.ANNOUNCED and _drill._pulse.center.distance_to(_origin) < 1.5,
			"The controller stick must aim at its own ground point, not reuse an invalid mouse pick."):
		return
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_point(_ground(_origin))
	_joy(JOY_BUTTON_X)
	_tick_through_tell()
	_check(_drill._in_contact() and _drill._pulse.phase == Pulse.Phase.INTERRUPTED and not _drill._tell.visible
		and _drill._response.text.contains("opposing contact") and _drill._opponent.cohesion == 100.0
		and _drill._pool.balance == Points.STARTING_BALANCE - Pulse.COST,
		"Closing in with real commander movement and clear melee contact interrupts before impact without a refund.")


func _tick_through_tell() -> void:
	for _step in range(ceili(Pulse.TELL_SECONDS / DT) + 6):
		if _drill._pulse.phase != Pulse.Phase.ANNOUNCED:
			break
		_tick()


func _tick() -> void:
	_drill._physics_process(DT)


func _ground(point: Vector2) -> Vector3:
	return _drill.to_global(_drill._ground(point))


func _try_at(point: Vector3) -> void:
	_point(point)
	_key(KEY_C)


func _point(point: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_camera_3d().unproject_position(point)
	root.push_input(event, true)


func _mouse_button(button: MouseButton, point: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_camera_3d().unproject_position(point)
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)


func _key(code: Key, held := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	if not held:
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		root.push_input(release, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures += 1
		push_error(message)
	return ok
