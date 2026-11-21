extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame

	var fight := _mission.encounter
	var group := _mission.battle.formations[0]
	var start := group.position
	_axis(1.0)
	_button(JOY_BUTTON_Y)
	_check(group.order == Battle.Order.HOLD, "Triangle cannot attack empty ground.")
	_point(fight.enemy_position)
	_tick()
	_check(_mission._enemy_target_ring.visible and _mission._enemy_status.text.begins_with("TARGET"), "A living road guard under the cursor is visibly marked.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_Y)
	_check(_mission.battle.formations[1].order == Battle.Order.HOLD and group.order == Battle.Order.HOLD, "Archers cannot use the prototype melee order.")
	_button(JOY_BUTTON_DPAD_LEFT)
	_button(JOY_BUTTON_Y)
	_check(group.order == Battle.Order.ATTACK and _mission._formation_label.text.contains("Attacking"), "Triangle issues an actual attack to Shield Infantry.")
	_tick(10)
	_axis(0.0)
	_check(not _mission.command_view and group.order == Battle.Order.ATTACK and group.position != start, "Releasing L2 does not cancel the formation attack.")
	for step in range(1400):
		if fight.points.balance > 400:
			break
		_tick()
	var first_hp := fight.enemy.hp
	_check(first_hp > 0.0 and first_hp < fight.enemy.max_hp and fight.points.balance == 406
		and group.position.distance_to(fight.enemy_position) <= InfantryAttack.REACH,
		"The formation traverses the road, deals one reachable contact to the existing guard, and awards exactly 6 BP.")
	_tick(45)
	_check(fight.enemy.hp == first_hp and fight.points.balance == 406, "The contact is not repeated on later frames of recovery.")
	_axis(1.0)
	_button(JOY_BUTTON_A)
	_tick(120)
	_check(group.order == Battle.Order.HOLD and fight.enemy.hp == first_hp, "Hold cancels further attack windups.")
	# With the guard already wounded, two more infantry contacts can finish it.
	fight.enemy.receive_damage(fight.enemy.hp - 70.0)
	_point(fight.enemy_position)
	_key(KEY_K)
	_tick(285)
	_check(not fight.enemy.is_alive() and fight.points.balance == 418 and group.order == Battle.Order.HOLD,
		"Infantry can finish the wounded road guard and automatically stop on the final confirmed hit.")
	_key(KEY_K)
	_check(group.order == Battle.Order.HOLD, "A defeated enemy cannot receive another attack order.")

	_mission.restart_mission()
	fight = _mission.encounter
	group = _mission.battle.formations[0]
	group.position = Vector2(21.0, -2.0)
	fight.enemy_position = Vector2(21.0, -10.0)
	_axis(1.0)
	_point(fight.enemy_position)
	_key(KEY_K)
	_tick(160)
	_check(group.order == Battle.Order.BLOCKED and group.position.y > -6.0 and fight.enemy.hp == fight.enemy.max_hp
		and fight.points.balance == 400 and _mission._formation_label.text.contains("Blocked"),
		"An attack behind a boulder stops at solid cover and awards no damage or BP.")

	_mission.restart_mission()
	fight = _mission.encounter
	group = _mission.battle.formations[0]
	group.position = fight.enemy_position - Vector2(InfantryAttack.STOP_RANGE, 0.0)
	_axis(1.0)
	_point(fight.enemy_position)
	_key(KEY_K)
	_tick()
	_check(fight.infantry_attack.phase == InfantryAttack.Phase.WINDUP, "A reachable target starts one formation windup.")
	fight.enemy_position += Vector2(6.0, 0.0)
	_tick(32)
	_check(fight.enemy.hp == fight.enemy.max_hp and fight.points.balance == 400, "An enemy outside current reach at contact takes no damage.")

	_mission.restart_mission()
	fight = _mission.encounter
	group = _mission.battle.formations[0]
	group.position = fight.enemy_position - Vector2(InfantryAttack.STOP_RANGE, 0.0)
	_mission.battle.hero_position = fight.enemy_position - Vector2(1.2, 0.0)
	fight.enemy.receive_damage(fight.enemy.max_hp - 30.0)
	_axis(1.0)
	_point(fight.enemy_position)
	_key(KEY_K)
	_tick()
	_axis(0.0)
	_key(KEY_J)
	# Advance both pending actions through their contact in the same update.
	_mission._physics_process(0.50)
	_check(not fight.enemy.is_alive() and fight.points.balance == 412 and group.order == Battle.Order.HOLD,
		"When the hero kills the shared target first on a simultaneous contact tick, the formation cannot damage it or earn duplicate BP.")
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP, "Formation combat does not bypass the escort objective.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Infantry attack: target controls, live approach, single BP contact, cancellation, obstruction, reach and shared HP passed.")
	quit(0 if _failures == 0 else 1)


func _tick(count := 1) -> void:
	for step in range(count):
		_mission._physics_process(1.0 / 60.0)


func _point(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_camera_3d().unproject_position(Vector3(point.x, 0.0, point.y))
	root.push_input(event, true)


func _axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = value
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
