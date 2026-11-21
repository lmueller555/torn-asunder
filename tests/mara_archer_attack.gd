extends SceneTree

const Pocket := preload("res://game/battlefield/mara_mine_escort.tscn")
const Valley := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _exercise(Pocket, "RoadJunction", Vector2(-15.0, 21.0))
	await _exercise(Valley, "RoadCut", Vector2(-53.0, 54.0))
	if _failed == 0:
		print("Verified Mara’s Archers in both Mine sizes: real inputs, ridge fire, terrain cover, reload, melee counterplay and restart.")
	quit(0 if _failed == 0 else 1)


func _exercise(scene: PackedScene, road: String, tunnel_wall_flank: Vector2) -> void:
	_mission = scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var fight := _mission.encounter
	var group := _mission.battle.formations[1]
	var initial_guard := fight.enemy_position
	var base_bp := fight.points.balance
	_command_archers()
	_point(initial_guard)
	_button(JOY_BUTTON_Y)
	_check(group.order == Battle.Order.HOLD and fight.last_contact.contains("out of range"),
		"Archers cannot fire at the authored pass guard from their spawn.")

	# Stage the same road guard on the authored road tile watched by this ridge;
	# the long-range order and terrain come from the running mission, not a mock.
	var ridge := _marker("Routes/RidgeOverlook")
	group.position = ridge
	fight.enemy_position = _marker("Routes/" + road)
	_point(fight.enemy_position)
	_tick()
	_check(_mission._enemy_target_ring.visible and _mission._combat_tell.text.contains("out of range"),
		"The target is selectable from the ridge.")
	_button(JOY_BUTTON_Y)
	_check(group.order == Battle.Order.ATTACK and fight.archer_attack.volley.phase == Archer.Phase.WINDUP \
			and _mission._archer_status.text.contains("Drawing") and group.position == ridge,
		"Triangle starts a visible draw from real ridge elevation without moving the formation.")
	_axis(0.0)
	_tick(25)
	_check(not _mission.command_view and fight.enemy.hp == fight.enemy.max_hp and fight.points.balance == base_bp,
		"Returning to Mara leaves the draw running and earns no early BP.")
	_tick(20)
	var hp_after_shot := fight.enemy.hp
	_check(hp_after_shot < fight.enemy.max_hp and hp_after_shot > 0.0 \
			and fight.points.balance == base_bp + Archer.HIT_BP and group.position == ridge \
			and _mission._archer_status.text.contains("Reloading") and _mission._combat_tell.text.contains("volley hit"),
		"The released volley damages the shared guard, stays on the ridge, and awards the lower ranged BP.")
	_tick(40)
	_check(fight.enemy.hp == hp_after_shot and fight.points.balance == base_bp + Archer.HIT_BP,
		"Reload neither double-hits nor generates more BP.")
	_axis(1.0)
	_button(JOY_BUTTON_A)
	_tick(170)
	_check(group.order == Battle.Order.HOLD and fight.enemy.hp == hp_after_shot,
		"Hold cancels the order even while a volley is reloading.")

	# The command camera may not see a target under the roof. Invoke its order
	# validation directly here to prove a known opponent through solid cover
	# still cannot be shot, even if identified by a later targeting adapter.
	group.position = tunnel_wall_flank
	fight.enemy_position = _marker("Routes/TunnelMidpoint")
	var accepted := fight.order_archer_attack(_mission.battle, 1, fight.enemy_position, _mission._terrain.clear_melee_contact)
	_check(not accepted and group.order == Battle.Order.HOLD and fight.last_contact.contains("line of sight blocked"),
		"The real tunnel wall rejects a known, in-range target.")
	_tick(60)
	_check(fight.enemy.hp == hp_after_shot and fight.points.balance == base_bp + Archer.HIT_BP,
		"A blocked shot deals no damage and awards no BP.")

	_mission.restart_mission()
	fight = _mission.encounter
	group = _mission.battle.formations[1]
	_check(group.order == Battle.Order.HOLD and fight.archer_attack.volley.phase == Archer.Phase.IDLE \
			and fight.points.balance == base_bp and fight.enemy_position == initial_guard,
		"Restart restores the authored and initially idle encounter.")
	_command_archers()
	fight.enemy_position = _marker("Routes/" + road)
	group.position = fight.enemy_position - Vector2(4.05, 0.0)
	_point(fight.enemy_position)
	_key(KEY_K)
	_check(fight.archer_attack.volley.phase == Archer.Phase.WINDUP, "K starts a draw from a legal but dangerously close road position.")
	_tick(100)
	_check(fight.points.balance == base_bp and fight.enemy.hp == fight.enemy.max_hp \
			and fight.archer_attack.attacker.hp < fight.archer_attack.attacker.max_hp \
			and fight.hero.hp == fight.hero.max_hp and group.order == Battle.Order.ATTACK,
		"The real guard closes, pins and hits Archers, not Mara, before the shot.")
	for i in range(360):
		if group.order == Battle.Order.DEFEATED:
			break
		_tick()
	_check(group.order == Battle.Order.DEFEATED and not _mission._formation_models[1].visible \
			and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP,
		"Defeated Archers disappear and their loss alone does not fail the escort.")

	# Also attack the guard at the original authored placement. The ridge
	# fixture above samples a different legal road pocket, not a new spawn.
	_mission.restart_mission()
	fight = _mission.encounter
	group = _mission.battle.formations[1]
	group.position = initial_guard - Vector2(12.0, 0.0)
	fight.enemy.receive_damage(fight.enemy.max_hp - 25.0)
	_command_archers()
	_point(initial_guard)
	_button(JOY_BUTTON_Y)
	_tick(50)
	_check(not fight.enemy.is_alive() and group.order == Battle.Order.HOLD \
			and fight.points.balance == base_bp + Archer.HIT_BP and group.position == initial_guard - Vector2(12.0, 0.0) \
			and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP,
		"Archers can finish the guard at his real spawn without leaving position or completing the escort.")

	_mission.queue_free()
	await process_frame


func _command_archers() -> void:
	_axis(1.0)
	if _mission._sector:
		_button(JOY_BUTTON_RIGHT_STICK)
	_button(JOY_BUTTON_DPAD_RIGHT)


func _marker(path: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/" + path)))


func _point(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_camera_3d().unproject_position(_mission.to_global(_mission._ground(point)))
	root.push_input(event, true)


func _tick(count := 1) -> void:
	for i in range(count):
		_mission._physics_process(DT)


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


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed += 1
		push_error(message)
