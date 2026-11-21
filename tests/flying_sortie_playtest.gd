extends SceneTree

const Practice := preload("res://game/battlefield/flying_sortie_playtest.gd")
const Scene := preload("res://game/battlefield/flying_sortie_playtest.tscn")
const Sortie := preload("res://game/combat/flying_sortie.gd")
const Drill := Practice.Drill
const Result := Sortie.Result
const DT := 1.0 / 60.0

var _scene: Practice


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = Scene.instantiate()
	root.add_child(_scene)
	_scene.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _bomb_and_fall_back() and _hold_ground_response() and _fighter_contact()
	_scene.queue_free()
	await process_frame
	if passed:
		print("Flying playtest: real flight markers, keyboard canopy fallback, controller anti-air Hold, fighter hit/evasion/escort and reset passed.")
	quit(0 if passed else 1)


func _bomb_and_fall_back() -> bool:
	_key(KEY_1)
	var point := _scene._target.position
	_key(KEY_G)
	_step(33)
	if _scene.sortie.result != Result.NONE or not _scene._flyer_marker.position.is_equal_approx(
			_scene.sortie.flight_position + Vector3.UP * 0.7) or _scene.sortie.flight_position.z >= point.z + 18.0:
		return _fail("Launch did not move the actual aircraft marker before any contact.")
	_until_result()
	if _scene.sortie.result != Result.HIT or _scene.sortie.target_hp_lost <= 0.0 or not _readout("Hit"):
		return _fail("The bomber did not land a visible hit over the existing clearing.")

	_button(JOY_BUTTON_START)
	if _scene.sortie.phase != Sortie.Phase.READY or _scene.sortie.target_hp_lost != 0.0 \
			or _scene._target.unit.hp != _scene._target.unit.max_hp:
		return _fail("Options did not reset the ground marker, HP and actual sortie.")
	_key(KEY_G)
	_key(KEY_A, true)
	_step(19)
	_key(KEY_A, false)
	var covered := _scene._target.position
	if covered.x >= point.x - 0.8 or covered.distance_to(point) > Sortie.BOMB_RADIUS \
			or not _scene._ground_covered(covered) or not _readout("Target: Canopy") \
			or not _scene._clear_lane(covered + Vector3.UP * 12.0, covered + Vector3.UP * 0.90):
		return _fail("Keyboard fallback did not really walk into foliage while staying inside the pass footprint.")
	_until_result()
	return (_scene.sortie.result == Result.UNDER_COVER and _scene.sortie.target_hp_lost == 0.0 \
		and _readout("Canopy sheltered")) or _fail("Falling back under real foliage did not protect the target.")


func _hold_ground_response() -> bool:
	_button(JOY_BUTTON_DPAD_RIGHT)
	if _scene.drill != Drill.ANTI_AIR:
		return _fail("D-pad did not select the ground anti-air drill.")
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_step(24)
	if _scene._defender.response_ready or _scene.sortie.result != Result.NONE:
		return _fail("Equipment alone automatically opened fire or the pass failed before approach.")
	_button(JOY_BUTTON_A)
	_step(1)
	if not _scene._defender.response_ready or not _readout("Holding contact") or _scene.sortie.result != Result.NONE:
		return _fail("Cross did not ready the defender, or defense ignored physical range.")
	_until_result()
	if _scene.sortie.result != Result.DRIVEN_OFF or _scene.sortie.flyer_hp_lost <= 0.0 \
			or _scene.sortie.target_hp_lost != 0.0 or _scene.sortie.flight_position.z <= _scene._target.position.z + 2.0:
		return _fail("Held anti-air contact did not drive the bomber off before bomb release.")

	_button(JOY_BUTTON_A, false)
	_button(JOY_BUTTON_START)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_button(JOY_BUTTON_A)
	_step(24)
	# Fall back with the same held response, then let it go under cover.
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_step(19)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_A, false)
	if not _scene._ground_covered(_scene._target.position) or _scene._defender.response_ready:
		return _fail("Moving with the stick didn't break Hold and move the actual anti-air unit into canopy.")
	_until_result()
	return (_scene.sortie.result == Result.UNDER_COVER and _scene.sortie.flyer_hp_lost == 0.0) \
		or _fail("An anti-air unit fired while falling back or took a hit through canopy.")


func _fighter_contact() -> bool:
	_key(KEY_3)
	_key(KEY_G)
	_until_result()
	if _scene.sortie.result != Result.HIT or _scene._target.role != Sortie.Role.BOMBER \
			or not is_equal_approx(_scene.sortie.flight_position.distance_to(_scene._target.position), Sortie.FIGHTER_LEAD):
		return _fail("The fighter failed to hit a real aerial target from its different release gate.")
	_key(KEY_BACKSPACE)
	_key(KEY_G)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_step(65)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_until_result()
	if _scene.sortie.result != Result.TARGET_EVADED or _scene.sortie.target_hp_lost != 0.0:
		return _fail("The fighter homed onto an aerial target that had moved clear.")

	_key(KEY_4)
	_key(KEY_H, true)
	_key(KEY_G)
	_until_result()
	_key(KEY_H, false)
	return (_scene.sortie.result == Result.DRIVEN_OFF and _scene.sortie.flyer_hp_lost > 0.0 \
		and _scene.sortie.target_hp_lost == 0.0 and _scene._escort_marker.visible and _readout("Development playtest")) \
		or _fail("The held fighter escort did not protect the bomber from actual interception.")


func _until_result() -> void:
	for i in range(200):
		if _scene.sortie.result != Result.NONE:
			return
		_step(1)


func _step(frames: int) -> void:
	for i in range(frames):
		_scene._physics_process(DT)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _button(index: JoyButton, down := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = down
	root.push_input(event, true)


func _axis(index: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	root.push_input(event, true)


func _readout(text: String) -> bool:
	return _scene._readout.text.contains(text)


func _fail(message: String) -> bool:
	push_error(message)
	return false
