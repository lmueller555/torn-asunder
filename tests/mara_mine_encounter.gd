extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	_mission.configure_campaign_lead_melee(true)
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame

	var fight := _mission.encounter
	_check(fight.points.balance == 400 and _mission._combat_hp.text.contains("400")
		and fight.hero.rating(Unit.Damage.MELEE) == 1, "The standalone pocket starts with 400 BP and cannot opt into campaign lead training.")
	_key(KEY_J)
	_tick(38)
	_check(fight.enemy.hp == fight.enemy.max_hp and fight.points.balance == 400, "A distant light attack misses without awarding BP.")

	_walk_to_guard()
	_check(_mission._enemy_warning.visible and _mission._combat_tell.text.contains("winding up"), "The advancing enemy raises a readable windup warning.")
	var health := fight.hero.hp
	_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_tick(43)
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	_check(health - fight.hero.hp > 0 and health - fight.hero.hp < 35.0 and fight.last_contact.begins_with("Guarded"), "L1 applies directional guard chip damage to a real swing.")

	_wait_for_windup()
	var retreat_start := _mission.battle.hero_position
	_tick(29)
	_key(KEY_S, true)
	_button(JOY_BUTTON_B, true)
	_tick(15)
	_key(KEY_S, false)
	_check(_mission.battle.hero_position.x < retreat_start.x - 1.0 and fight.hero.hp > 320.0, "Circle dodges back from the next swing without taking damage.")
	_tick(22)

	# Replay, collect the Godbridle, then fight and deliver in one uninterrupted attempt.
	_key(KEY_BACKSPACE)
	fight = _mission.encounter
	var pickup := _mission.battlefield_marker(^"Markers/Objectives/GodbridlePickup").position
	_drive(KEY_W, pickup.x, true)
	_drive(KEY_D, pickup.z)
	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.ESCORTING, "Combat-enabled mission still supports pickup.")
	_drive(KEY_A, 0.0)
	_walk_to_guard()
	_button(JOY_BUTTON_X, true)
	_tick(15)
	_check(fight.enemy.hp < 205 and fight.points.balance == 412, "Square's confirmed light contact reduces the enemy's HP and awards 12 BP.")
	_tick(20)
	_button(JOY_BUTTON_Y, true)
	_tick(29)
	_check(fight.enemy.hp < 100 and fight.points.balance == 432, "Triangle's confirmed heavy contact awards 20 BP and deals more damage.")
	_tick(30)
	_key(KEY_K)
	_tick(29)
	_check(not fight.enemy.is_alive() and fight.points.balance == 452 and _mission._combat_tell.text == "Road guard defeated", "Defeating the road guard clears it without faking escort success.")
	_check(_mission.objective.phase == Escort.Phase.ESCORTING, "Combat victory cannot complete the escort by itself.")
	var road_exit := _mission.battlefield_marker(^"Markers/Objectives/GodbridleExit").position
	_drive(KEY_W, road_exit.x, true)
	_check(_mission.objective.phase == Escort.Phase.SUCCEEDED, "A living hero can fight through the east pass and actually deliver the Godbridle.")

	_key(KEY_BACKSPACE)
	fight = _mission.encounter
	_walk_to_guard()
	var hp_before := fight.hero.hp
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_X, true)
	_tick(43)
	_check(fight.hero.hp < hp_before and fight.enemy.hp == fight.enemy.max_hp and _mission.battle.formations[0].order != Battle.Order.HOLD,
		"Enemy windup resolves during command view; Square is reserved for formation orders.")
	_tick(450)
	_check(not fight.hero.is_alive() and _mission.objective.phase == Escort.Phase.FAILED and _mission._goal_label.text == "Escort failed",
		"Unguarded enemy strikes can incapacitate Mara and fail the mission.")
	_button(JOY_BUTTON_START, true)
	_check(_mission.encounter != fight and _mission.encounter.enemy.hp == Encounter.ENEMY_HP and _mission.encounter.hero.hp == Encounter.HERO_HP
		and _mission.encounter.points.balance == 400 and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP and not _mission.command_view,
		"Retry restores both combatants, the shared BP pool, the escort and hero view.")

	# The strike crosses the boulder corner, but both actors start outside the collider.
	var corner := Vector3(21.0, 0.0, -6.0)
	var rotation := Basis(Vector3.UP, 0.383972)
	var from := corner + rotation * Vector3(2.22, 0.0, 1.05)
	var to := corner + rotation * Vector3(1.34, 0.0, 1.73)
	var hero_side := Vector2(from.x, from.z)
	var enemy_side := Vector2(to.x, to.z)
	_check(not _mission._terrain.clear_melee_contact(hero_side, enemy_side), "Solid terrain blocks a contact ray.")
	_mission.battle.hero_position = hero_side
	_mission.battle.hero_heading = (enemy_side - hero_side).normalized()
	fight = _mission.encounter
	fight.enemy_position = enemy_side
	_key(KEY_K)
	_tick(30)
	_check(fight.enemy.hp == fight.enemy.max_hp and fight.points.balance == 400, "A close heavy swing cannot connect through the boulder.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Mara road guard: actual attacks, miss/BP, windup, guard, dodge, live command failure and full combat reset passed.")
	quit(0 if _failures == 0 else 1)


func _walk_to_guard() -> void:
	# March the lead platoon toward the guard until contact starts combat, then close in directly.
	var held := false
	for index in range(900):
		if _mission.encounter.enemy_phase == Encounter.EnemyPhase.WINDUP:
			break
		var battle = _mission.battle
		if battle.direct_hero_control():
			if not held:
				_key(KEY_W, true)
				held = true
		else:
			battle.order_move(Battle.LEAD_INDEX, battle.hero_position + Vector2.UP.rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED / 60.0)
		_tick()
	if held:
		_key(KEY_W, false)
	_check(_mission.encounter.enemy_phase == Encounter.EnemyPhase.WINDUP, "The road guard starts a swing when Mara closes to melee.")


func _drive(key: Key, target: float, along_x := false) -> void:
	# Outside combat the leader's platoon marches by Move orders; in combat the key steers.
	var heading: Vector2 = {KEY_W: Vector2.UP, KEY_S: Vector2.DOWN, KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT}[key]
	var held := false
	for index in range(900):
		var point := _mission.hero_world_position()
		if absf((point.x if along_x else point.z) - target) < 0.10 or _mission._finished():
			break
		var battle = _mission.battle
		if battle.direct_hero_control():
			if not held:
				_key(key, true)
				held = true
		else:
			if held:
				_key(key, false)
				held = false
			battle.order_move(Battle.LEAD_INDEX, battle.hero_position + heading.rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED / 60.0)
		_tick()
	if held:
		_key(key, false)


func _wait_for_windup(budget := 150) -> void:
	for index in range(budget):
		if _mission.encounter.enemy_phase == Encounter.EnemyPhase.WINDUP:
			return
		_tick()
	_check(false, "The road guard starts a swing when Mara closes to melee.")


func _tick(count := 1) -> void:
	for i in range(count):
		_mission._physics_process(1.0 / 60.0)


func _key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _button(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
