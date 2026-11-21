extends SceneTree

const MissionScene := preload("res://game/battlefield/mara_greyhollow_rescue_campaign.tscn")
const Mission := preload("res://game/battlefield/mara_greyhollow_rescue.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const STEP := 1.0 / 60.0
var _mission: Mission
var _results: Array[bool] = []
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = MissionScene.instantiate()
	_mission.configure_campaign_lead_level(4)
	_mission.configure_campaign_lead_melee(true)
	_check(not _mission.configure_replay_heavy_infantry(false, true), "A trained detachment is not granted on the first deployment.")
	_check(_mission.configure_replay_heavy_infantry(true, true), "The candidate keeps authorized Heavy Infantry replay support.")
	root.add_child(_mission)
	_mission.set_physics_process(false)
	_mission.mission_finished.connect(func(won: bool) -> void: _results.append(won))
	await physics_frame
	await physics_frame

	var start := _mission.battle.hero_position
	var rally := _mission._marker_position(_mission._pickup)
	_check(_mission._bridle == null and _mission._custody_case == null and _mission.custody_case_scene == null,
		"No artifact scene, visual, or token mounts before success.")
	_check(_mission.team_battle_points_frame().lead_level == 4 and _mission._heavy_replay_loadout,
		"The rescue inherits the confirmed lead-level BP cap and replay loadout.")
	_check(_mission.encounter.hero.rating(Encounter.Unit.Damage.MELEE) == 2, "The rescue inherits applied Lead Melee training.")
	_check_objective_copy()

	_key(KEY_SPACE)
	_tick(90)
	_check(_mission.rescue_phase == Mission.Rescue.RALLY and _results.is_empty(), "Interact at the spawn neither rallies nor reveals.")
	_check(not _mission._dryad_released, "The crew cannot be wiped out while the player is reading initial orders.")

	# Enter the encounter but leave the waiting crew undefended. The Dryad must
	# physically cross the yard and land multiple committed contact strikes.
	_move_to(Vector2(-76, 21))
	_check(_mission._dryad_released, "Coming within range of the raid releases the real enemy encounter.")
	_move_to(start)
	_tick(2600)
	_check(_mission.rescue_phase == Mission.Rescue.FAILED and _mission._count(Mission.Miner.LOST) >= 2
		and _results == [false], "Abandoning the crew produces genuine attrition and a single failure signal.")
	_tick(10)
	_check(_results == [false], "A terminal failure does not emit repeated results.")
	_check_objective_copy()
	_key(KEY_BACKSPACE)
	_check(_mission.rescue_phase == Mission.Rescue.RALLY and _mission.battle.hero_position == start
		and _mission._count(Mission.Miner.WAITING) == 3 and _mission.encounter.enemy.hp == Encounter.ENEMY_HP,
		"Local retry restores the whole crew, Dryad, and authored Mara spawn.")
	_check(_mission.team_battle_points_frame().lead_level == 4 and _mission._heavy_replay_loadout
		and _mission.encounter.hero.rating(Encounter.Unit.Damage.MELEE) == 2, "Retry preserves the approved campaign training.")

	# Issue actual commands against the Dryad. The archers can be placed in
	# the clear, then from lead view Mara escorts the crew rather than waiting
	# for the guard or the rest of the army to arrive.
	var yard := _mission.encounter.enemy_position
	_key(KEY_SHIFT)
	_key(KEY_X)
	_mission.cursor = Vector2(-77, 19)
	_joy_button(JOY_BUTTON_X)
	_key(KEY_SHIFT, false)
	_tick(1100)
	_key(KEY_SHIFT)
	_mission.cursor = yard
	_key(KEY_K)
	_check(_mission.battle.formations[1].order == Battle.Order.ATTACK, "The existing command input can volley at a Dryad.")
	_key(KEY_SHIFT, false)
	_tick(85)
	_check(_mission.encounter.enemy.hp < Encounter.ENEMY_HP and _mission.encounter.enemy.is_alive(),
		"The formation lands an actual hit without needing to kill the raider.")
	_key(KEY_SHIFT)
	_joy_button(JOY_BUTTON_A)
	_key(KEY_SHIFT, false)
	for point in [Vector2(-76, 21), Vector2(-61, 38), Vector2(-60.5, 51), Vector2(-60.5, 56)]:
		_move_to(point)
	_check(_mission.battle.hero_position.distance_to(rally) <= Mission.RALLY_RADIUS, "Mara can reach the miners through the real yard.")
	_key(KEY_SHIFT)
	_key(KEY_SPACE)
	_joy_button(JOY_BUTTON_A)
	_tick(1)
	_check(_mission.rescue_phase == Mission.Rescue.RALLY, "Command Cross/Square cannot rally the miners.")
	_key(KEY_SHIFT, false)
	_joy_button(JOY_BUTTON_A)
	_tick(1)
	_check(_mission.rescue_phase == Mission.Rescue.ESCORT and _results == [false], "Rally starts the escort but does not signal success or reveal.")
	_check_objective_copy()
	_tick(60)
	_check(_mission._count(Mission.Miner.SAFE) == 0 and _results == [false],
		"Staying where you rallied does not save any miners.")

	for point in [Vector2(-63, 69), Vector2(-63, 81), Vector2(-63, 93), Vector2(-63, 102),
		Vector2(-75, 104), Vector2(-87, 105), Vector2(-99, 106), Vector2(-111, 108), Vector2(-124, 108)]:
		_move_to(point)
		_tick(100)
	_tick(200)
	_check(_mission.rescue_phase == Mission.Rescue.SUCCEEDED and _mission._count(Mission.Miner.SAFE) >= Mission.MIN_SAFE,
		"At least two miners actually reaching the safe hollow is required to succeed.")
	_check(_mission.encounter.enemy.is_alive() and _results == [false, true],
		"The real tunnel escape can succeed with the Dryad alive, after exactly one victory signal.")
	_tick(25)
	_check(_results == [false, true], "Rescue success cannot emit twice.")
	_check_objective_copy()

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Greyhollow: real Dryad contact and failure, trained replay, actual commands, miner rally and protected tunnel exit passed.")
	quit(0 if _failures == 0 else 1)


func _check_objective_copy() -> void:
	var adapter := _mission.get_node("MinimapHUD/Panel")
	adapter.refresh()
	for label in _mission.find_children("*", "Label", true, false) + _mission.find_children("*", "Label3D", true, false):
		_check(not str(label.text).to_lower().contains("godbridle"), "No objective/actor text discloses the artifact.")
	for landmark in _mission.alternate_minimap_objective()["landmarks"]:
		_check(not str(landmark[0]).to_lower().contains("godbridle"), "No minimap pin discloses the artifact.")


func _move_to(target: Vector2) -> void:
	if _mission._finished():
		return
	var command_sent := false
	for tick in range(1000):
		var position := _mission.battle.hero_position
		if position.distance_to(target) < 0.18 or _mission._finished():
			break
		if _mission.battle.direct_hero_control():
			command_sent = false
			var stick := (target - position).normalized().rotated(_mission._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, stick.x)
			_axis(JOY_AXIS_LEFT_Y, stick.y)
		elif not command_sent:
			_axis(JOY_AXIS_LEFT_X, 0.0)
			_axis(JOY_AXIS_LEFT_Y, 0.0)
			_key(KEY_SHIFT)
			if _mission.selected_index == 1:
				_key(KEY_X)
			elif _mission.selected_index == 0:
				_key(KEY_Z)
			_mission.cursor = target
			_joy_button(JOY_BUTTON_X)
			_key(KEY_SHIFT, false)
			command_sent = true
		_tick(1)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if not _mission._finished() and _mission.battle.hero_position.distance_to(target) >= 0.25:
		print("Approach did not reach ", target, ": Mara ", _mission.battle.hero_position,
			" Dryad ", _mission.encounter.enemy_position, " phase ", _mission.rescue_phase,
			" lead order ", _mission.battle.lead.order, " hero HP ", _mission.encounter.hero.hp)


func _tick(count: int) -> void:
	for index in range(count):
		_mission._physics_process(STEP)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event)


func _joy_button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
