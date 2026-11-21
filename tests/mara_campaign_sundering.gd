extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Pocket := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const DT := 1.0 / 60.0

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
	var original_frame := _mission.team_battle_points_frame()
	_check(original_frame.balance == 400 and original_frame.capacity == 700 and original_frame.lead_level == fight.hero.level
		and _mission._combat_hp.text.contains("Team 400 / 700 BP (lead Lv 1)"),
		"Live campaign HUD reads the team frame's balance, cap and founding lead level.")
	var hero_camera := root.get_camera_3d()
	_check(_mission._special_status.visible and _mission._special_status.text.contains("150 BP · Ready")
		and fight.points.balance == 400, "Campaign HUD names the input, shared cost, and initial readiness.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key(KEY_V)
	_tick()
	_check(_mission.command_view and root.get_camera_3d() != hero_camera and fight.points.balance == 400
		and fight.defense.attack_phase == Attack.Phase.IDLE and _mission._special_status.text.contains("Hero view only"),
		"R2 and V in command view do not spend or change the current camera.")
	_check(_mission.team_battle_points_frame().balance == original_frame.balance,
		"Denied command-camera input does not spend or award any Battle Points.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.90)
	_tick()
	_check(root.get_camera_3d() == hero_camera and fight.points.balance == 400,
		"Holding R2 through the view switch does not buffer or fire an action.")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.45)
	_check(fight.points.balance == 400, "A partially squeezed trigger does not start the special.")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.85)
	_check(fight.points.balance == 250 and fight.defense.attack_kind == Attack.Attack.SUNDERING_STRIKE
		and fight.defense.attack_phase == Attack.Phase.WINDUP and _mission._special_status.text.contains("Windup")
		and _mission._hero_weapon.rotation.x < -1.3, "An accepted R2 edge charges exactly 150 BP and telegraphs the named special.")
	_tick(39)
	_check(fight.last_contact == "Sundering Strike missed" and fight.points.balance == 250
		and _mission._special_status.text.contains("Recovering"), "A missed swing consumes its BP and enters recovery without refund.")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.41)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.95)
	_tick(50)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.75)
	_check(fight.points.balance == 250 and fight.defense.attack_phase == Attack.Phase.IDLE,
		"Trigger jitter and continuing to hold through recovery never double-charge.")
	_key(KEY_V, true, true)
	_check(fight.points.balance == 250, "Keyboard echo cannot auto-repeat a special.")

	_key(KEY_J)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key(KEY_V)
	_check(fight.defense.attack_kind == Attack.Attack.LIGHT and fight.points.balance == 250,
		"An existing light windup blocks both special inputs without spending.")
	_check(_mission.team_battle_points_frame().balance == 250 and original_frame.balance == 400,
		"Denied busy commands leave the live budget and detached starting frame unchanged.")
	_tick(35)
	_key(KEY_U)
	_key(KEY_V)
	_check(fight.defense.phase == Defense.Phase.GUARD and fight.points.balance == 250, "Guard admission does not spend BP on a denied special.")
	_key(KEY_U, false)
	_key(KEY_V)
	_check(fight.points.balance == 100, "A fresh V press after recovery uses the same shared pool.")
	_tick(86)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key(KEY_V)
	_check(fight.defense.attack_phase == Attack.Phase.IDLE and fight.points.balance == 100
		and _mission._special_status.text.contains("Not enough BP"), "Insufficient BP is shown and denies both input paths.")
	var spent_frame := _mission.team_battle_points_frame()
	_check(spent_frame.spend_status(Mission.SUNDERING_COST) == Points.SpendStatus.INSUFFICIENT
		and spent_frame.balance == 100, "The typed frame agrees with the insufficient HUD and denied attack.")
	_key(KEY_BACKSPACE)
	fight = _mission.encounter
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.86)
	_check(fight.points.balance == 400 and fight.defense.attack_phase == Attack.Phase.IDLE
		and _mission._special_status.text.contains("Ready"), "Retry refills the pool without re-firing a trigger held during restart.")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)

	# Use live movement and controls to release and engage the actual campaign Orc.
	for id: String in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard",
		"Objectives/GodbridlePickup"]:
		_drive_to(id)
	_button(JOY_BUTTON_A)
	_tick()
	for id: String in ["Routes/MineYard", "Routes/RoadWest", "Routes/RoadJunction", "Routes/RoadCut", "Routes/EastPass"]:
		_drive_to(id)
	_drive_to("Routes/InterceptRoadMerge", true)
	_check(_mission.objective.interception_triggered and fight.enemy_phase == Encounter.EnemyPhase.WINDUP,
		"The living carrier faces the real defending Orc after its authored interception.")
	_key(KEY_V)
	_check(fight.points.balance == 250 and _mission._special_status.text.contains("Windup"), "V activates Sundering Strike in live campaign combat.")
	_tick(38)
	_check(fight.enemy.hp > 0.0 and fight.enemy.hp < 55.0 and fight.last_contact == "Sundering Strike hit"
		and fight.points.balance == 250, "A confirmed special uses actual contact damage but earns no BP back.")
	_tick(44)
	_key(KEY_J)
	_tick(18)
	_check(not fight.enemy.is_alive() and fight.points.balance == 262 and _mission.objective.phase == Escort.Phase.ESCORTING,
		"Basic attacks still earn BP after the special and the combat kill does not clear the objective.")
	_check(_mission.team_battle_points_frame().balance == 262 and spent_frame.balance == 100
		and original_frame.balance == 400, "Only confirmed earned BP changes current frames; retry and hits do not rewrite past frames.")

	var pocket := Pocket.instantiate()
	_check(not pocket.sundering_strike_enabled, "The separate pocket stays opt-out.")
	pocket.free()
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Mara campaign Sundering Strike: R2/V, admission, cost, misses, contact, no self-funding, camera and retry passed.")
	quit(0 if _failures == 0 else 1)


func _drive_to(id: String, until_windup := false) -> void:
	var mk := _mission.battlefield_marker(NodePath("Markers/" + id))
	var local := _mission.to_local(mk.global_position)
	var target := Vector2(local.x, local.z)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.LEAD_SPEED / DT) + 120
	var reached := false
	for step in range(budget):
		var remaining := target - _mission.battle.hero_position
		if (until_windup and _mission.encounter.enemy_phase == Encounter.EnemyPhase.WINDUP) \
			or (not until_windup and remaining.length() < 0.14):
			reached = true
			break
		var aim := remaining.normalized().rotated(_mission._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y))
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(reached, "Campaign movement reaches the real route checkpoint %s." % id)


func _tick(count := 1) -> void:
	for i in range(count):
		_mission._physics_process(DT)


func _key(code: Key, down := true, repeating := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	event.echo = repeating
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
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


## Outside combat the leader travels with their platoon by Move orders, as the
## player sets them; in combat the stick steers the leader directly.
func _march_lead(aim: Vector2) -> void:
	var battle = _mission.battle
	if battle.direct_hero_control():
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		return
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if aim.length_squared() > 0.0:
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED * DT)
