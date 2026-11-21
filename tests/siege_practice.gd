extends SceneTree

const Scene := preload("res://game/battlefield/siege_practice.tscn")
const Drill := preload("res://game/battlefield/siege_practice.gd")
const Prep := preload("res://game/combat/siege_preparation.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _drill: Drill
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_drill = Scene.instantiate() as Drill
	root.add_child(_drill)
	_drill.set_physics_process(false)
	await physics_frame
	await physics_frame
	var title := _drill.get_node("PracticeHUD/Panel/Margin/Rows/Title") as Label
	_check(_drill.battlefield_scene.resource_path.ends_with("/spanwater_lock_campaign.tscn")
		and title.text.contains("DEVELOPMENT PLAYTEST") and title.text.contains("UNAPPROVED GRAYBOX")
		and _drill._impact.mesh == _drill._cursor_marker.mesh,
		"The drill must stay developer-only and reuse the original graybox and command marker.")
	if _deploy_and_settle():
		_fire_and_reload()
		_contact_and_move()
	_drill.queue_free()
	await process_frame
	if _failures == 0:
		print("Siege practice: actual Move/Hold/fire controls, terrain denials, reload after hit and miss, contact, teardown and reset passed.")
	quit(0 if _failures == 0 else 1)


func _deploy_and_settle() -> bool:
	var crew := _drill.battle.formations[Drill.CREW]
	var initial := crew.position
	var deployment := _site(Drill.DEPLOYMENT)
	_key(KEY_C)
	_check(_drill._response.text.contains("command view"), "Hero view should not fire.")
	_key(KEY_SHIFT, true)
	_advance(1.0)
	_check(_drill._setup.phase == Prep.Phase.STOWED, "Initial placeholder Hold does not deploy the crew.")
	_mouse_button(MOUSE_BUTTON_RIGHT, _ground(deployment))
	_advance(0.8)
	_check(crew.order == Battle.Order.MOVE and crew.position.distance_to(initial) > 2.0
		and _drill._setup.phase == Prep.Phase.STOWED, "Real right-click movement should carry the stowed crew along the bank.")
	_advance(4.0)
	if not _check(crew.position.distance_to(deployment) < 0.14 and _drill._setup.phase == Prep.Phase.STOWED,
		"The crew must physically reach the marked practice position; automatic arrival Hold is not deployment: %s." % crew.position):
		return false
	_joy(JOY_BUTTON_A)
	_check(_drill._setup.phase == Prep.Phase.SETTING_UP and _drill._crew_readout.text.contains("Setting up"),
		"Controller Cross should start visible preparation only when deliberately held.")
	var full_setup := _drill._setup.remaining
	_advance(full_setup * 0.65)
	_try_at(_ground(_site(Drill.CLEAR_TARGET)))
	_check(_drill._response.text.contains("setting up") and _drill._accepted_shots == 0,
		"An impatient shot must not shorten setup or begin reload.")
	_advance(full_setup * 0.40)
	return _check(_drill._setup.phase == Prep.Phase.READY and _drill._crew_readout.text.begins_with("Ready"),
		"Simulated elapsed time, not rendered frames, must finish deployment.")


func _fire_and_reload() -> void:
	var source := _drill.battle.formations[Drill.CREW].position
	var clear := _site(Drill.CLEAR_TARGET)
	var shed := _drill._field.get_node("Geometry/Lock/UpstreamSupplyShed") as Node3D
	var sheltered := Vector2(-125.0, -64.0)
	_try_at(_ground(source + Vector2(8.0, 0.0)))
	_check(_drill._response.text.contains("Too close"), "Aim inside the minimum must be denied: " + _drill._response.text)
	_try_at(_ground(Vector2(-96.0, -42.0)))
	_check(_drill._response.text.contains("Out of range"), "Aim outside the maximum must be denied: " + _drill._response.text)
	_try_at(shed.global_position + Vector3.UP * 2.4)
	_check(_drill._response.text.contains("not a roof"), "An actual collider pick on the roof must not reuse the last legal cursor: " + _drill._response.text)
	_try_at(_ground(sheltered))
	_check(_drill.cursor.distance_to(sheltered) < 0.14 and _drill._response.text.contains("Blocked arc"),
		"Walkable ground beyond the real shed should remain sheltered: %s at %s." % [_drill._response.text, _drill.cursor])
	if not _check(_drill._setup.phase == Prep.Phase.READY and _drill._accepted_shots == 0 and not _drill._impact.visible,
		"An invalid range, target or arc must not spend a shot or create an impact marker."):
		return
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_point(_ground(clear))
	_joy(JOY_BUTTON_Y)
	_check(_drill._response.text.contains("Select the Siege crew") and _drill._accepted_shots == 0,
		"The opposing formation cannot fire the crew's shot.")
	_joy(JOY_BUTTON_DPAD_LEFT)
	_joy(JOY_BUTTON_Y)
	if not _check(_drill._setup.phase == Prep.Phase.RELOADING and _drill._last_shot and _drill._last_shot.on_target
		and _drill._last_shot.target.distance_to(clear) < 0.14 and _drill._impact.visible and _drill._accepted_shots == 1,
		"Triangle accepts the actual open in-range aim, locks the verified point and shows the diagnostic hit: " + _drill._response.text):
		return
	var reload := _drill._setup.remaining
	_advance(reload * 0.6)
	_try_at(_ground(clear))
	_check(_drill._accepted_shots == 1 and _drill._response.text.contains("reloading") and _drill._setup.remaining < reload,
		"The crew must reject another shot without resetting the live reload.")
	_advance(reload * 0.45)
	_try_at(_ground(clear))
	_check(_drill._accepted_shots == 2 and _drill._last_shot and not _drill._last_shot.on_target
		and _drill._setup.phase == Prep.Phase.RELOADING and _drill._impact_label.text.contains("MISS"),
		"An accepted diagnostic miss must still cause an entire reload.")


func _contact_and_move() -> void:
	var crew := _drill.battle.formations[Drill.CREW]
	var enemy := _drill.battle.formations[Drill.OPPOSING]
	var enemy_start := enemy.position
	_advance(_drill._setup.remaining + 0.2)
	_check(_drill._setup.phase == Prep.Phase.READY, "Ready again before testing contact.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_point(_ground(crew.position))
	_joy(JOY_BUTTON_X)
	_advance(4.0)
	_check(enemy.position.distance_to(enemy_start) > 3.0 and _drill._in_contact()
		and _drill._setup.phase == Prep.Phase.STOWED and _drill._response.text.contains("contact"),
		"Physically approaching across the ground must stow a ready crew on actual contact.")
	_joy(JOY_BUTTON_DPAD_LEFT)
	_try_at(_ground(_site(Drill.CLEAR_TARGET)))
	_check(_drill._response.text.contains("in contact") and _drill._accepted_shots == 2,
		"A contact-blocked shot must not be accepted.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_mouse_button(MOUSE_BUTTON_RIGHT, _ground(enemy_start))
	_advance(3.5)
	_check(not _drill._in_contact() and _drill._setup.phase == Prep.Phase.SETTING_UP,
		"Breaking contact must start fresh setup, not restore a ready crew.")
	_joy(JOY_BUTTON_DPAD_LEFT)
	var next := crew.position + Vector2(3.0, 0.0)
	_mouse_button(MOUSE_BUTTON_RIGHT, _ground(next))
	_check(_drill._setup.phase == Prep.Phase.STOWED,
		"A real crew Move must break setup before taking the first step.")
	_advance(1.3)
	_check(crew.position.distance_to(next) < 0.14 and _drill._setup.phase == Prep.Phase.STOWED,
		"Arriving after teardown must not silently return the prepared shot.")
	_joy(JOY_BUTTON_START)
	_check(_drill._setup.phase == Prep.Phase.STOWED and not _drill._impact.visible
		and _drill._accepted_shots == 0 and _drill.battle.formations[Drill.OPPOSING].position == enemy_start,
		"Options must reset the exercise and its shot log and restore the enemy spawn.")


func _advance(seconds: float) -> void:
	for _step in range(ceili(seconds / DT)):
		_drill._physics_process(DT)


func _site(path: NodePath) -> Vector2:
	return _drill._marker_position(_drill.battlefield_marker(path))


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


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures += 1
		push_error(message)
	return ok
