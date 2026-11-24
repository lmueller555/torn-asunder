extends "res://tests/mara_campaign_flow.gd"
## Exercises the registered rescue from actual New Game, then reopens its save
## from Continue. A second profile represents a pre-version campaign.

func _run() -> void:
	var fresh_path := OS.get_temp_dir().path_join("torn-mara-starts-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var legacy_path := fresh_path + ".legacy"
	var passed := await _fresh_campaign(fresh_path)
	if passed:
		passed = await _legacy_campaign(legacy_path)
	await _close_title()
	for path in [fresh_path, fresh_path + ".tmp", legacy_path, legacy_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara starting platoons: actual New Game/Continue, levels and all points, Dryad release, winnable rescue, 400/920 BP and replay/old-save isolation passed.")
	quit(0 if passed else 1)


func _open_title(path: String) -> void:
	_profile_path = path
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	root.add_child(_title)
	await process_frame


func _close_title() -> void:
	if is_instance_valid(_title):
		root.remove_child(_title)
		_title.queue_free()
		await process_frame


func _begin_mara() -> bool:
	return _press("New Game") and _press("mara") and _press("BackButton") \
		and _title._page == Title.Page.CAMPAIGN_BATTLE


func _fresh_campaign(path: String) -> bool:
	var save := Profile.new(path)
	if save.set_setting("fullscreen", false) != OK or save.set_setting("reduced_motion", true) != OK \
			or save.mark_played("raska") != OK:
		return _fail("Could not prepare settings and a separate existing non-Human campaign.")
	await _open_title(path)
	if not _begin_mara() or not Profile.new(path).mara_uses_starting_platoons():
		return _fail("A genuinely new Mara New Game did not persist its versioned starting build.")
	var mission := _title._campaign_battle as Mission
	if not _is_new_loadout(mission) or not _enemy_hud_level(mission, 12):
		return _fail("Initial live units, displayed enemy level, or owner BP were not leveled/trained.")
	mission.restart_mission()
	if mission.encounter.enemy_phase != Encounter.EnemyPhase.AT_RESERVE or mission._dryad_released:
		return _fail("An authored hostile actor should start reserved without protecting generic miners as combatants.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _winning_rescue_with_combat(mission):
		return false
	await process_frame
	var xp_result := _title._mission_xp_recap
	if not xp_result or xp_result.defeated != 0 or xp_result.total_xp() != 100:
		return _fail("Leaving the Dryad alive incorrectly changed the normal 100 XP first clear.")
	if not _continue_greyhollow_xp_recap():
		return false
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or not _finish_beat(Beats.MARA_MINE_DEBRIEF):
		return _fail("Real success at the new levels did not commit the rescue and mandatory reveal.")
	var profile := Profile.new(path)
	var shield := profile.mara_shield_barracks_state()
	if not profile.mara_uses_starting_platoons() or not shield.reveal_completed or shield.level != 12 \
			or shield.melee_rating != 12 or shield.xp_in_level != 100 or shield.remaining_melee_points != 0:
		return _fail("The saved new build and stock first-clear XP did not remain coherent.")
	await _close_title()
	await _open_title(path)
	if not _press("Continue") or not _on_map(MINE) or not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Continue did not reopen the registered Mine from the saved new campaign.")
	if not _mine_briefing_budget(12, 920) or not _press("Confirm Deployment"):
		return _fail("Briefing did not show the same level and BP as the actual deployment.")
	mission = _title._campaign_battle as Mission
	if not _is_new_loadout(mission) or mission.encounter.hero.experience != 100 \
			or mission.encounter.infantry_attack.attacker.experience != 100 \
			or mission.encounter.archer_attack.attacker.experience != 0:
		return _fail("Continue did not restore the new builds plus their existing scope-specific earned XP.")
	var before := FileAccess.get_file_as_bytes(path)
	var previous := mission.encounter
	mission.encounter.hero.receive_damage(15.0)
	_key(KEY_BACKSPACE)
	if not _is_new_loadout(mission) or mission.encounter == previous \
			or mission.encounter.hero.hp != mission.encounter.hero.max_hp \
			or FileAccess.get_file_as_bytes(path) != before:
		return _fail("Retry re-awarded, lost, or persisted campaign starting allocations.")
	await _close_title()
	return await _later_hud(path)


func _later_hud(path: String) -> bool:
	var save := Profile.new(path)
	var world := save.load_campaign_world("mara")
	var clears := save.completed_missions("mara")
	if world.travel_to(ROAD, clears) != world.TravelResult.ARRIVED \
			or world.travel_to(CROSSING, clears) != world.TravelResult.ARRIVED \
			or save.record_world_waypoint(world) != OK:
		return _fail("Could not place the already-cleared campaign at the actual next deployment.")
	await _open_title(path)
	if not _press("Continue") or not _on_map(CROSSING) or not _press("ConfirmTravel") \
			or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("Could not reopen the real later Human deployment.")
	var grain := _title._campaign_battle as GrainScene
	if not grain or grain.scene_file_path != "res://game/battlefield/mara_grain_crossing_campaign.tscn":
		return _fail("The continuity check did not open the registered Grain Crossing.")
	return (grain._mission_lead_level == 12 and not grain.has_method("team_battle_points_frame")) \
		or _fail("The later shared HUD lost Mara's campaign lead level or gained an unowned BP pool.")

func _legacy_campaign(path: String) -> bool:
	await _close_title()
	var save := Profile.new(path)
	if save.set_setting("fullscreen", false) != OK or save.set_setting("reduced_motion", true) != OK \
			or save.mark_played("mara") != OK:
		return _fail("Could not prepare an existing Mara save without a new-loadout marker.")
	await _open_title(path)
	if not _begin_mara() or Profile.new(path).mara_uses_starting_platoons():
		return _fail("Reopening an existing campaign from its opening would retroactively grant allocations.")
	var mission := _title._campaign_battle as Mission
	if not mission:
		return _fail("The legacy campaign did not reach the real rescue.")
	var encounter := mission.encounter
	var budget := mission.team_battle_points_frame()
	var roster: Array = mission._mission_hud_state().roster
	return (roster.size() == 3 and roster[0].level == 1 and roster[1].level == 1 and roster[2].level == 1 \
		and encounter.hero.level == 1 and encounter.hero.rating(Unit.Damage.MELEE) == 1 \
		and encounter.infantry_attack.attacker.level == 1 and encounter.archer_attack.attacker.level == 1 \
		and encounter.enemy.level == 1 and budget.lead_level == 1 and budget.capacity == 700 \
		and _enemy_hud_level(mission, 1)) \
		or _fail("An existing unmarked save changed legacy combat levels or BP.")


func _is_new_loadout(mission: Mission) -> bool:
	if not mission or not mission.encounter or mission.scene_file_path != Mission.GREYHOLLOW_STARTING_SCENE:
		return false
	var encounter := mission.encounter
	var budget := mission.team_battle_points_frame()
	var roster: Array = mission._mission_hud_state().roster
	if roster.size() != 3 or roster[0].level != 12 or roster[1].level != 12 or roster[2].level != 11:
		return false
	var archers := encounter.archer_attack.attacker
	return _only(encounter.hero, 12, Unit.Damage.MELEE, 12) \
		and _only(encounter.infantry_attack.attacker, 12, Unit.Damage.MELEE, 12) \
		and _only(archers, 11, Unit.Damage.RANGED, 11) \
		and budget.balance == 400 and budget.capacity == 920 and budget.lead_level == encounter.hero.level \
		and encounter.enemy.level == mission.starting_campaign_enemy_level and encounter.enemy.level in [11, 12, 13] \
		and mission.battle.formations.size() == 2 and mission.battle.formations[1].title == "Archers"


func _enemy_hud_level(mission: Mission, expected: int) -> bool:
	# Show the actual encounter combatant through the real, conditional hero
	# HUD payload. Stage only the clear sight/engagement needed to display it.
	var enemy := mission.encounter.enemy_position
	for angle in range(16):
		var facing := Vector2.RIGHT.rotated(TAU * float(angle) / 16.0)
		var near := enemy - facing * 1.2
		if not mission._terrain.clear_melee_contact(near, enemy):
			continue
		mission.battle.hero_position = near
		mission.battle.hero_heading = facing
		mission.battle.lead_engaged = true
		mission.selected_index = Battle.LEAD_INDEX
		mission._hero_yaw = atan2(-facing.x, -facing.y)
		mission._hero_camera.make_current()
		mission._update_cameras()
		mission._refresh_combat_view()
		var entry: Dictionary = mission._mission_hud_state().enemy
		if not entry.is_empty():
			return entry.level == expected and entry.hp == mission.encounter.enemy.hp
	return false


func _only(unit: Unit, level: int, specialty: Unit.Damage, rating: int) -> bool:
	if unit.level != level or unit.stat_points != 0 or unit.rating(specialty) != rating:
		return false
	for type: Unit.Damage in Unit.Damage.values():
		if type != specialty and unit.rating(type) != Unit.MIN_RATING:
			return false
	return true


func _winning_rescue_with_combat(mission: Mission) -> bool:
	var yard := mission.encounter.enemy_position
	var enemy_hp := mission.encounter.enemy.hp
	_key(KEY_SHIFT)
	for index in range(mission.battle.formations.size() + 1):
		if mission.selected_index == 1:
			break
		_key(KEY_X)
	mission.cursor = Vector2(-77, 19)
	_joy(JOY_BUTTON_X)
	_key(KEY_SHIFT, false)
	_tick(1100)
	_key(KEY_SHIFT)
	mission.cursor = yard
	_key(KEY_K)
	_key(KEY_SHIFT, false)
	_tick(85)
	if mission.encounter.enemy.hp >= enemy_hp or not mission.encounter.enemy.is_alive():
		return _fail("At the new settings, real Archer combat did not wound the Dryad without killing it.")
	_key(KEY_SHIFT)
	_joy(JOY_BUTTON_A)
	_key(KEY_SHIFT, false)
	for point in [Vector2(-76, 21), Vector2(-61, 38), Vector2(-60.5, 51), Vector2(-60.5, 56)]:
		if not _drive_rescue(point):
			return false
	if not mission._dryad_released or mission.encounter.enemy.level != mission.starting_campaign_enemy_level:
		return _fail("The triggered hostile spawn did not retain its authored level.")
	_joy(JOY_BUTTON_A)
	_tick()
	if mission.rescue_phase != Mission.Rescue.ESCORT:
		return _fail("The normal rally and escort did not start with the rebalanced combat levels.")
	for point in [Vector2(-63, 69), Vector2(-63, 81), Vector2(-63, 93), Vector2(-63, 102),
			Vector2(-75, 104), Vector2(-87, 105), Vector2(-99, 106), Vector2(-111, 108), Vector2(-124, 108)]:
		if not _drive_rescue(point):
			return false
		_tick(100)
	return (mission.rescue_phase == Mission.Rescue.SUCCEEDED and mission._count(Mission.Miner.SAFE) >= Mission.MIN_SAFE) \
		or _fail("Get Them Out could not be won through actual fight and escort at these levels.")
