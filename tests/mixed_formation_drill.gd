extends SceneTree

const Scene := preload("res://game/battlefield/mixed_formation_drill.tscn")
const Drill := preload("res://game/battlefield/mixed_formation_drill.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Fight := preload("res://game/battlefield/mara_mine_encounter.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")
const Foot := preload("res://game/battlefield/mara_infantry_attack.gd")
const DT := 1.0 / 60.0

var _scene: Drill


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = Scene.instantiate()
	root.add_child(_scene)
	_scene.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _archers_exposed() and _shield_and_bow()
	_scene.queue_free()
	await process_frame
	if passed:
		print("Mixed formation drill: exposed bow draw denied by melee, actual withdrawal and ranged recovery, shield contact and combined BP passed.")
	quit(0 if passed else 1)


func _archers_exposed() -> bool:
	_key(KEY_SHIFT, true)
	_key(KEY_X)
	_aim(_scene.encounter.enemy_position)
	_key(KEY_K)
	var fight := _scene.encounter
	if fight.archer_attack.volley.phase != Archer.Phase.WINDUP:
		return _fail("An actual archer attack order did not start drawing from legal range.")
	_wait(func() -> bool: return fight.last_contact.contains("pinned"), 75)
	if not fight.last_contact.contains("pinned") or fight.archer_attack.volley.phase != Archer.Phase.RELOAD \
			or fight.points.balance != 400 or fight.enemy.hp != fight.enemy.max_hp:
		return _fail("The guard did not physically close into melee and interrupt the shot with no hit award.")
	_wait(func() -> bool: return fight.windup_target == Fight.Target.ARCHERS, 60)
	if fight.windup_target != Fight.Target.ARCHERS or not _scene._formation_label.text.contains("Pinned"):
		return _fail("HUD did not identify the exposed formation and threat.")
	var archers := _scene.battle.formations[1]
	_move(Vector2(-4, -4))
	_wait(func() -> bool: return archers.order == Battle.Order.HOLD, 210)
	if archers.position.x > -3.8 or not fight.archer_attack.attacker.is_alive():
		return _fail("A live Move order did not withdraw the threatened archers.")
	_aim(fight.enemy_position)
	_key(KEY_K)
	_wait(func() -> bool: return fight.points.balance > 400, 80)
	return (fight.points.balance == 400 + Archer.HIT_BP and fight.enemy.hp < fight.enemy.max_hp) \
		or _fail("The withdrawn bow line did not recover sight/range and resolve a real volley.")


func _shield_and_bow() -> bool:
	_pad(JOY_BUTTON_START)
	var fight := _scene.encounter
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.9)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	var archers := _scene.battle.formations[1]
	_move(Vector2(-3, -4))
	_wait(func() -> bool: return archers.order == Battle.Order.HOLD, 180)
	_pad(JOY_BUTTON_DPAD_LEFT)
	_aim(fight.enemy_position)
	_pad(JOY_BUTTON_Y)
	_wait(func() -> bool: return fight.windup_target == Fight.Target.INFANTRY, 140)
	var infantry := _scene.battle.formations[0]
	if fight.windup_target != Fight.Target.INFANTRY or infantry.position == Drill.FOOT_START:
		return _fail("A controller infantry attack did not physically close and draw enemy contact.")
	_pad(JOY_BUTTON_DPAD_RIGHT)
	_aim(fight.enemy_position)
	_pad(JOY_BUTTON_Y)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var shield_full := fight.infantry_attack.attacker.max_hp
	_wait(func() -> bool: return fight.points.balance >= 400 + Foot.BP_PER_HIT + Archer.HIT_BP \
		and fight.infantry_attack.attacker.hp < shield_full, 160)
	return (fight.points.balance >= 400 + Foot.BP_PER_HIT + Archer.HIT_BP \
		and fight.infantry_attack.attacker.hp < shield_full \
		and fight.archer_attack.attacker.hp == fight.archer_attack.attacker.max_hp \
		and fight.enemy.hp < fight.enemy.max_hp - Foot.BASE_DAMAGE \
		and not _scene.command_view and _scene._mode_label.text.contains("Development playtest")) \
		or _fail("Melee stopped the threat and ranged contact did not resolve together on one shared fight behind the screen.")


func _aim(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _screen(point)
	root.push_input(event, true)


func _move(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = _screen(point)
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)


func _screen(point: Vector2) -> Vector2:
	return root.get_camera_3d().unproject_position(Vector3(point.x, 0, point.y))


func _wait(condition: Callable, frames: int) -> void:
	for i in range(frames):
		if condition.call():
			return
		_scene._physics_process(DT)


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


func _fail(message: String) -> bool:
	push_error(message)
	return false
