extends SceneTree

const Playtest := preload("res://game/battlefield/mounted_brace_playtest.tscn")
const Drill := preload("res://game/battlefield/mounted_brace_playtest.gd")
const Encounter := preload("res://game/combat/mounted_brace_encounter.gd")
const Result := Encounter.Result
const DT := 1.0 / 60.0

var _scene: Drill


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = Playtest.instantiate()
	root.add_child(_scene)
	_scene.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _front_on_road() and _rear_on_road() and _move_out_of_lane() and _wash_blocks()
	_scene.queue_free()
	await process_frame
	if passed:
		print("Mounted brace playtest: keyboard/mouse frontal Hold, controller rear hit, effective Move, covered wash and reset passed.")
	quit(0 if passed else 1)


func _front_on_road() -> bool:
	var line := _scene.battle.formations[0].position
	var start := _scene.encounter.rider_position
	_step(60)
	if _scene.encounter.brace_ready:
		return _fail("A staged formation braced without an actual Hold order.")
	_key(KEY_SHIFT, true)
	_step(2)
	_aim(line + Vector2(12, 0))
	_key(KEY_H)
	_key(KEY_SHIFT, false)
	_step(55)
	if not _scene.encounter.brace_ready or _scene.battle.formations[0].heading.dot(Vector2.RIGHT) < 0.95:
		return _fail("Mouse aim followed by Hold did not raise a real east-facing brace.")
	_key(KEY_G)
	_step(120)
	var e := _scene.encounter
	if e.result != Result.NONE or e.rider_position.x >= start.x - 15.0 or e.defender_cohesion_lost != 0.0:
		return _fail("The rider must approach on the road before contact, without taking charge effects early.")
	var mounted_actor: Node3D = _scene.get_node("Riders")
	if not is_equal_approx(mounted_actor.position.x, e.rider_position.x):
		return _fail("The existing rider actors did not follow the simulation.")
	_until_result()
	if e.result != Result.REPELLED or e.rider_cohesion_lost <= 0.0 or e.defender_cohesion_lost <= 0.0 \
			or not is_equal_approx(e.rider_position.distance_to(line), Encounter.CONTACT_RADIUS):
		return _fail("The front brace did not stop the riders at physical contact.")
	if not _readout_contains("Repelled"):
		return _fail("A successful brace was not described on screen.")
	var contact := e.rider_position
	var impact := e.defender_cohesion_lost
	_step(240)
	_key(KEY_G)
	_step(60)
	return (e.rider_position == contact and e.defender_cohesion_lost == impact) \
		or _fail("Regroup or rapid launch produced a second impact without a reset.")


func _rear_on_road() -> bool:
	_button(JOY_BUTTON_DPAD_RIGHT)
	if _scene.drill != Drill.Drill.WEST:
		return _fail("The controller could not stage the reverse road approach.")
	var line := _scene.battle.formations[0].position
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.85)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_step(62)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_step(55)
	if not _scene.encounter.brace_ready or _scene.battle.formations[0].heading.x < 0.80:
		return _fail("The controller could not aim and set an east-facing Hold.")
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_until_result()
	var e := _scene.encounter
	if e.result != Result.LANDED or e.rider_cohesion_lost != 0.0 or e.defender_cohesion_lost <= 0.0:
		return _fail("A fully ready brace repelled a rider that actually approached its rear.")
	_step(280)
	return (e.rider_position.x > line.x + Encounter.RUNOUT and _readout_contains("Charge hit")) \
		or _fail("The riders did not visibly continue through the rear impact and out of the line.")


func _move_out_of_lane() -> bool:
	_key(KEY_1)
	var formation := _scene.battle.formations[0]
	var line := formation.position
	_key(KEY_SHIFT, true)
	_step(2)
	_aim(line + Vector2(8, 0))
	_key(KEY_H)
	_step(55)
	_key(KEY_G)
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	for i in range(20):
		if _scene.cursor.y >= line.y + 8.0:
			break
		_step(1)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_button(JOY_BUTTON_X)
	_key(KEY_SHIFT, false)
	_step(60)
	if _scene.encounter.brace_ready or formation.position.distance_to(line) < 2.0:
		return _fail("The Move order did not break brace while physically redeploying under a live approach.")
	_until_result()
	return (_scene.encounter.result == Result.MISSED and _scene.encounter.defender_cohesion_lost == 0.0 \
		and formation.position.distance_to(line) > Encounter.CONTACT_RADIUS and _readout_contains("Miss")) \
		or _fail("The fixed mounted pass tracked or hit infantry that had moved clear.")


func _wash_blocks() -> bool:
	_key(KEY_3)
	var formation := _scene.battle.formations[0]
	var start := _scene.encounter.rider_position
	var line := formation.position
	_key(KEY_G)
	_until_result()
	var e := _scene.encounter
	if e.result != Result.TERRAIN_BLOCKED or e.defender_cohesion_lost != 0.0 or e.rider_cohesion_lost != 0.0 \
			or e.distance_marched <= 0.0 or e.rider_position.distance_to(line) <= Encounter.CONTACT_RADIUS \
			or not _readout_contains("Blocked"):
		return _fail("The real terrain must stop the moving riders before any contact or cohesion loss.")
	_button(JOY_BUTTON_START)
	var readout: Label = _scene.get_node("HUD/Panel/Margin/Readout/Mode")
	return (_scene.drill == Drill.Drill.WASH and _scene.encounter.result == Result.NONE \
		and _scene.encounter.rider_position == start and readout.text.contains("Development playtest")) \
		or _fail("Options did not cleanly reset the same visibly development-only drill.")


func _until_result() -> void:
	for i in range(1500):
		if _scene.encounter.result != Result.NONE:
			return
		_step(1)


func _screen(point: Vector2) -> Vector2:
	return _scene.get_viewport().get_camera_3d().unproject_position(_scene.to_global(_scene._ground(point)))


func _aim(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _screen(point)
	root.push_input(motion, true)


func _key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
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


func _step(frames: int) -> void:
	for i in range(frames):
		_scene._physics_process(DT)


func _readout_contains(phrase: String) -> bool:
	var readout: Label = _scene.get_node("HUD/Panel/Margin/Readout/Controls")
	return readout.text.contains(phrase)


func _fail(message: String) -> bool:
	push_error(message)
	return false
