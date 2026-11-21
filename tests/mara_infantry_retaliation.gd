extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Fight := preload("res://game/battlefield/mara_mine_encounter.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const FormationAttack := preload("res://game/battlefield/mara_infantry_attack.gd")

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

	var battle := _mission.battle
	var fight := _mission.encounter
	var infantry := battle.formations[0]
	var spawn := battle.hero_position
	_check(_mission._infantry_hp.text.contains("310 / 310 prototype HP"), "Formation group health is shown and labeled provisional.")
	_issue_attack()
	_axis(0.0)
	_wait_for_windup(Fight.Target.INFANTRY, 1500)
	_check(_mission._enemy_warning.visible and _mission._combat_tell.text.contains("at Shield Infantry")
		and _mission._enemy_status.text.contains("INFANTRY"), "The road guard telegraphs its formation target with the existing windup.")

	# Introduce a closer hero during the current windup. The attack must not switch.
	var hp_before := fight.hero.hp
	var troops_before := fight.infantry_attack.attacker.hp
	battle.hero_position = fight.enemy_position + fight.enemy_heading * 0.87
	_tick(42)
	_check(fight.hero.hp == hp_before and fight.infantry_attack.attacker.hp < troops_before
		and fight.last_contact.begins_with("Shield Infantry hit"), "A swing keeps its locked infantry target even after Mara becomes closer.")
	_wait_for_windup(Fight.Target.HERO, 100)
	_check(fight.windup_target == Fight.Target.HERO, "On its next windup, the guard chooses the nearer eligible hero.")
	battle.hero_position = spawn
	_tick(42)
	_check(fight.hero.hp == hp_before and fight.last_contact == "Road guard missed", "Stepping out of reach does not redirect the locked hero swing into infantry.")

	var bp_before := fight.points.balance
	for i in range(500):
		if infantry.order == Battle.Order.DEFEATED:
			break
		_tick()
	_check(infantry.order == Battle.Order.DEFEATED and not fight.infantry_attack.attacker.is_alive()
		and not _mission._formation_models[0].visible and _mission._infantry_hp.text.contains("Defeated"),
		"Retaliation can defeat infantry instead of letting a lone order trivialize the fight.")
	_check(fight.enemy.is_alive() and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP
		and fight.hero.is_alive(), "Losing the formation neither clears nor fails Mara's escort.")
	_check(fight.points.balance >= bp_before and (fight.points.balance - 400) % FormationAttack.BP_PER_HIT == 0,
		"Only confirmed friendly formation hits added BP; incoming damage did not.")

	var dead_position := infantry.position
	var dead_bp := fight.points.balance
	var remaining_hp := fight.enemy.hp
	_axis(1.0)
	_point(fight.enemy_position)
	_button(JOY_BUTTON_X)
	_button(JOY_BUTTON_A)
	_button(JOY_BUTTON_Y)
	_tick(170)
	_check(infantry.order == Battle.Order.DEFEATED and infantry.position == dead_position and not _mission._selection.visible
		and not _mission._enemy_target_ring.visible and fight.points.balance == dead_bp and fight.enemy.hp == remaining_hp,
		"Defeated infantry cannot Move, Hold, or Attack, and cannot deal hidden damage or earn BP.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_X)
	_check(battle.formations[1].order == Battle.Order.MOVE, "Defeated infantry do not disable living allied formations.")

	_mission.restart_mission()
	fight = _mission.encounter
	_check(_mission.battle.formations[0].order == Battle.Order.HOLD and _mission._formation_models[0].visible
		and fight.infantry_attack.attacker.hp == FormationAttack.PROTOTYPE_HP and fight.points.balance == 400,
		"Restart restores the infantry, its orders, and the initial BP pool.")

	# Set up the formation at a visible, reachable windup, then place stone
	# between it and the locked guard, with both centers still in range.
	battle = _mission.battle
	infantry = battle.formations[0]
	infantry.position = fight.enemy_position + Vector2(-1.15, 0.0)
	_issue_attack()
	_wait_for_windup(Fight.Target.INFANTRY, 30)
	var corner := Vector3(21.0, 0.0, -6.0)
	var rotation := Basis(Vector3.UP, 0.383972)
	var from := corner + rotation * Vector3(2.22, 0.0, 1.05)
	var to := corner + rotation * Vector3(1.34, 0.0, 1.73)
	infantry.position = Vector2(to.x, to.z)
	fight.enemy_position = Vector2(from.x, from.z)
	fight.enemy_heading = (infantry.position - fight.enemy_position).normalized()
	_tick(42)
	_check(fight.infantry_attack.attacker.hp == FormationAttack.PROTOTYPE_HP and fight.last_contact == "Road guard missed",
		"Locked infantry targets in range but behind solid cover cannot take contact damage.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Mara infantry retaliation: nearest target, locked windup, LOS, defeat, command ineligibility, BP and restart passed.")
	quit(0 if _failures == 0 else 1)


func _issue_attack() -> void:
	_axis(1.0)
	_point(_mission.encounter.enemy_position)
	_button(JOY_BUTTON_Y)


func _wait_for_windup(target: Fight.Target, budget: int) -> void:
	for i in range(budget):
		if _mission.encounter.windup_target == target:
			return
		_tick()
	_check(false, "The guard should begin a windup against target %d." % target)


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


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
