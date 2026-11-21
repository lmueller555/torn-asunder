extends SceneTree

const Practice := preload("res://game/battlefield/ice_cast_playtest.gd")
const Scene := preload("res://game/battlefield/ice_cast_playtest.tscn")
const Ice := preload("res://game/combat/targeted_ice_cast.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
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
	var passed := _earned_training_and_range() and _interruption_and_retry() and _retreat_breaks_range()
	_scene.queue_free()
	await process_frame
	if passed:
		print("Ice playtest: real stat allocation, caster movement and range, locked moving target, cover break, shared BP, retry and reset passed.")
	quit(0 if passed else 1)


func _earned_training_and_range() -> bool:
	var earned := Ice.ICE_RATING - Unit.MIN_RATING
	_key(KEY_V)
	_step(1)
	if _scene.pool.balance != Points.STARTING_BALANCE or _scene.caster.stat_points != earned \
			or _scene.caster.rating(Unit.Damage.ICE) != Unit.MIN_RATING or not _feedback("requires Ice"):
		return _fail("Early cast spent BP or skipped the normal stat-point requirement.")
	for i in range(earned - 1):
		_pad(JOY_BUTTON_RIGHT_SHOULDER)
	if _scene.caster.rating(Unit.Damage.ICE) != Ice.ICE_RATING - 1 or _scene.caster.stat_points != 1:
		return _fail("Each controller allocation must spend exactly one earned point.")
	_key(KEY_P)
	_key(KEY_P)
	if _scene.caster.rating(Unit.Damage.ICE) != Ice.ICE_RATING or _scene.caster.stat_points != 0:
		return _fail("Keyboard allocation failed or a sixth point was silently invented.")
	_key(KEY_V)
	_step(1)
	if _scene.pool.balance != Points.STARTING_BALANCE or not _feedback("out of range"):
		return _fail("A trained caster outside real range spent BP.")
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_step(90)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	if _scene.caster_position.distance_to(Practice.CASTER_START) < 5.0 or _scene._distance() >= Ice.RANGE \
			or not _scene._clear_lane():
		return _fail("Stick movement did not physically bring the trained caster into a clear lane.")
	return true


func _interruption_and_retry() -> bool:
	var full := _scene.target.hp
	var pool := _scene.pool
	var reset_position := _scene.target_position
	_trigger()
	_step(1)
	if _scene.spell.locked_target() != _scene.target or pool.balance != Points.STARTING_BALANCE - Ice.COST \
			or _scene.target.hp != full:
		return _fail("The real cast did not lock the target/spend once before the windup.")
	# Begin the target's fallback in the live windup, not before admission.
	_pad(JOY_BUTTON_Y)
	for i in range(45):
		_step(1)
		if _scene.spell.phase == Ice.Phase.INTERRUPTED:
			break
	if _scene.spell.phase != Ice.Phase.INTERRUPTED or _scene.target_position.distance_to(reset_position) <= 1.0 \
			or _scene._distance() >= Ice.RANGE or _scene._clear_lane() or _scene.target.hp != full \
			or pool.balance != Points.STARTING_BALANCE - Ice.COST or not _feedback("committed BP were not refunded"):
		return _fail("Physical movement behind the shed did not break sight before release and retain the committed cost.")
	_trigger()
	_step(1)
	if pool.balance != Points.STARTING_BALANCE - Ice.COST or not _feedback("terrain blocks sight"):
		return _fail("An initial obstruction accepted or charged for a new cast.")

	_key(KEY_T)
	_step(75)
	if not _scene._clear_lane():
		return _fail("The same actor did not physically return from cover.")
	_key(KEY_V)
	_step(19)
	if _scene.target.hp != full or _scene.spell.phase != Ice.Phase.WINDUP \
			or pool.balance != Points.STARTING_BALANCE - 2 * Ice.COST:
		return _fail("A second real cast hit early or did not spend from the same pool.")
	_step(45)
	var expected := _scene.target.damage_from(_scene.caster, {Unit.Damage.ICE: Ice.BASE_ICE_DAMAGE})
	if _scene.spell.phase != Ice.Phase.RELEASED or not is_equal_approx(full - _scene.target.hp, expected) \
			or pool.balance != Points.STARTING_BALANCE - 2 * Ice.COST or not _feedback("No BP earned"):
		return _fail("A clear release did not resolve exactly one standard Ice-rated hit with no BP return.")
	_trigger()
	_step(45)
	var depleted := Points.STARTING_BALANCE - 3 * Ice.COST
	_trigger()
	_step(45)
	if pool.balance != depleted or not is_equal_approx(full - _scene.target.hp, 2.0 * expected) \
			or not _feedback("not enough Battle Points"):
		return _fail("The shared pool paid twice, refunded or regenerated points, or overcommitted a fourth invocation.")
	_pad(JOY_BUTTON_START)
	_step(1)
	return (_scene.pool.balance == Points.STARTING_BALANCE and _scene.target.hp == full \
		and _scene.caster.stat_points == Ice.ICE_RATING - Unit.MIN_RATING \
		and _scene.spell.phase == Ice.Phase.IDLE and _feedback("Development playtest")) \
		or _fail("Explicit reset did not restore the original drill.")


func _retreat_breaks_range() -> bool:
	for i in range(Ice.ICE_RATING - Unit.MIN_RATING):
		_key(KEY_P)
	_key(KEY_A, true)
	_step(51)
	_key(KEY_A, false)
	if _scene._distance() >= Ice.RANGE or not _scene._clear_lane():
		return _fail("Keyboard approach did not reach the clear edge of the spell's actual range.")
	_key(KEY_V)
	_key(KEY_D, true)
	_step(20)
	_key(KEY_D, false)
	return (_scene.spell.phase == Ice.Phase.INTERRUPTED and _scene._distance() > Ice.RANGE \
		and _scene._clear_lane() and _scene.target.hp == _scene.target.max_hp \
		and _scene.pool.balance == Points.STARTING_BALANCE - Ice.COST) \
		or _fail("Retreating outside range during windup did not cancel the paid cast independently of cover.")


func _trigger() -> void:
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.85)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _pad(index: JoyButton) -> void:
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


func _feedback(text: String) -> bool:
	return _scene._readout.text.contains(text)


func _fail(message: String) -> bool:
	push_error(message)
	return false
