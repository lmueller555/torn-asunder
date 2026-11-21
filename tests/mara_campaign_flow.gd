extends SceneTree

const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const CampaignMap := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/mara_greyhollow_rescue.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const BP := preload("res://game/combat/battle_points.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const GrainScene := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Rival := preload("res://game/battlefield/marches_rival_reserve.gd")
const HighQuay := preload("res://game/battlefield/mara_moonwash_playtest.gd")
const Quay := preload("res://game/battlefield/mara_moonwash_quay.gd")
const CLEAR_ID := "mara_mine_escort"
const MINE := "year_one_mine"
const CAMP := "marches_camp"
const ROAD := "marches_road"
const CROSSING := "marches_crossing"
const MOONWASH := "moonwash_road"
const HARBOR := "moonwash_harbor"
const QUAY_ID := "mara_moonwash_quay"
const GRAIN_ID := "mara_grain_crossing"
const DT := 1.0 / 60.0

var _title: Title
var _profile_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-mara-flow-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	var configured := _title._profile.set_setting("fullscreen", false) == OK \
		and _title._profile.set_setting("reduced_motion", true) == OK
	root.add_child(_title)
	var main_path := _profile_path
	var passed := configured and await _flow()
	if passed:
		passed = await _fresh_bread_flow(main_path + ".bread")
	_title.queue_free()
	await process_frame
	for path in [main_path, main_path + ".tmp", main_path + ".bread", main_path + ".bread.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara campaign: Greyhollow rescue and success-only reveal, all three missions, Water Request, immutable first Grain result, training, replay, completion and Continue passed.")
	quit(0 if passed else 1)


func _flow() -> bool:
	if _has_playtest_notice():
		return _fail("The campaign playtest notice leaked onto the title menu.")
	if not _press("New Game") or _title._page != Title.Page.VAULT or not _has_playtest_notice():
		return _fail("The Campaign Vault did not visibly identify its development playtests.")
	if not _press("neris"):
		return false
	if _title._page != Title.Page.WORLD_MAP or not _map() or _button("Confirm Deployment") \
			or _title._campaign_world.campaign_id() != "neris":
		return _fail("Selecting the Dryads borrowed Mara's map or deployed a battle prematurely.")
	_joy(JOY_BUTTON_B)
	if not _press("New Game") or not _press("mara"):
		return false
	if not _on_map(CAMP) or _button("Confirm Deployment"):
		return _fail("New Game did not start at the camp on the overworld.")
	_joy(JOY_BUTTON_A)
	if _title._page != Title.Page.BRIEFING or _mine_briefing_label() or not _button("Unit Progression") or not _press("Read Dispatch"):
		return _fail("Camp Operations did not offer practice and the dispatch.")
	if not _is_dialogue(Beats.MARA_MINE_DISPATCH) or not _no_pre_rescue_reveal(_title._stage):
		return _fail("Camp Operations did not start the rescue dispatch without disclosing the artifact.")
	if not _read_rescue_dispatch():
		return false
	if not _button("Read Dispatch") or not _press("Back") or not _on_map(CAMP):
		return _fail("Finishing the dispatch did not return through camp to the map.")

	_map().select_waypoint(ROAD)
	_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not _map()._detail.text.contains("road into the Marches"):
		return _fail("Selecting the gated adjoining road bypassed the opening mission.")
	_map().select_waypoint(MINE)
	if not _on_map(CAMP) or not _press("ConfirmTravel"):
		return _fail("An unconfirmed mine selection moved the party.")
	if not _on_briefing() or _saved_world() != MINE or not _saved_clears().is_empty():
		return _fail("Mine arrival did not persist the waypoint and stop at briefing without awarding a clear.")
	if not _has_playtest_notice():
		return _fail("The deployment briefing did not identify the placeholder art before confirmation.")
	if not _no_pre_rescue_reveal(_title._stage) or not _mine_briefing_budget(1, 700) or _title._campaign_battle:
		return _fail("The initial Mine briefing mentioned the artifact, lacked the level-one budget, or deployed without confirmation.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or _mine_briefing_label() or not _press("ConfirmTravel") or not _on_briefing() \
			or not _mine_briefing_budget(1, 700):
		return _fail("Cancel and reopening did not preserve the fresh budget on the Mine briefing alone.")
	var at_mine := FileAccess.get_file_as_string(_profile_path)

	if not _press("Confirm Deployment") or not _title._campaign_battle:
		return _fail("Explicit deployment did not start the actual mission scene.")
	var tutorial_labels := _title._campaign_battle.find_children("*", "Label", true, false)
	var tutorial_count := 0
	for label in tutorial_labels:
		if label.is_in_group("gameplay_tutorial"):
			tutorial_count += 1
			if label.is_visible_in_tree():
				return _fail("Deployment left a gameplay tutorial visible.")
	if tutorial_count == 0:
		return _fail("Deployment did not exercise the tutorial HUD filter.")
	_joy(JOY_BUTTON_B)
	if not _title._campaign_battle:
		return _fail("Title intercepted combat Circle as a return.")
	_key(KEY_ESCAPE)
	if not PauseTest.confirm_leave(_title._pause_menu):
		return _fail("Escape did not open the battle pause menu.")
	if not _on_map(MINE) or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Abandoning the battle changed the clear or arrived location.")

	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	var mission := _title._campaign_battle as Mission
	if not mission:
		return _fail("Mara did not deploy the Greyhollow rescue.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if mission._field.name != &"YearOneMineCampaign" or mission.encounter == null:
		return _fail("Deployment fell back to the toy map or disabled live combat.")
	if not _mine_budget(mission, 1, 700) or mission.encounter.hero.rating(Unit.Damage.MELEE) != 1:
		return _fail("A fresh Mine deployment did not show 400 / 700 BP and untrained Mara.")
	_key(KEY_V)
	if mission.team_battle_points_frame().balance != BP.STARTING_BALANCE - Mission.SUNDERING_COST:
		return _fail("The fresh attempt did not spend on the existing special.")
	_tick() # Sync the authored lead spawn before its first march.
	var spawn := mission.battle.hero_position
	if not _drive_rescue(Vector2(-76, 21)) or not _drive_rescue(spawn):
		return false
	_tick(2600)
	await process_frame
	if mission.rescue_phase != Mission.Rescue.FAILED or mission._count(Mission.Miner.LOST) < 2 \
			or _title._page != Title.Page.CAMPAIGN_BATTLE or _button("Advance") \
			or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Losing the crew saved a rescue clear or opened the reveal.")
	_key(KEY_BACKSPACE)
	if mission.rescue_phase != Mission.Rescue.RALLY or FileAccess.get_file_as_string(_profile_path) != at_mine \
			or not _mine_budget(mission, 1, 700):
		return _fail("Retry did not refill 400 BP at the same launch cap or changed the saved profile.")
	if not _win_rescue():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR_ID]) \
			or _saved_world() != MINE:
		return _fail("The physical rescue did not persist the stable clear and waypoint before the reveal.")
	if not _reveal_names_artifact():
		return false
	if not _on_map(MINE):
		return _fail("Finishing the reveal did not return to the mine on the campaign map.")
	_map().select_waypoint(CROSSING)
	_joy(JOY_BUTTON_A)
	if not _on_map(MINE) or not _map()._confirm_button.disabled:
		return _fail("The first clear let the party skip the linked Marches Road.")
	_map().select_waypoint(ROAD)
	if _map()._confirm_button.disabled:
		return _fail("A persisted victory did not open the onward link.")

	var after_clear := FileAccess.get_file_as_string(_profile_path)
	_map().select_waypoint(MINE)
	if not _press("ConfirmTravel") or not _mine_briefing_budget(2, 720) or _title._campaign_battle \
			or FileAccess.get_file_as_string(_profile_path) != after_clear or not _press("Confirm Deployment"):
		return _fail("The replay briefing must show 400 / 720 without deploying or changing the saved clear.")
	mission = _title._campaign_battle as Mission
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _mine_budget(mission, 2, 720) or mission.encounter.hero.rating(Unit.Damage.MELEE) != 1:
		return _fail("The first saved clear raises the BP cap but must not spend the earned Melee point.")
	_key(KEY_V)
	if mission.team_battle_points_frame().balance != BP.STARTING_BALANCE - Mission.SUNDERING_COST:
		return _fail("The existing special did not spend from the higher-cap launch pool.")
	_key(KEY_BACKSPACE)
	if not _mine_budget(mission, 2, 720) or FileAccess.get_file_as_string(_profile_path) != after_clear:
		return _fail("Retry must refill without reverting the higher launch cap or touching the profile.")
	if not _win_rescue():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or FileAccess.get_file_as_string(_profile_path) != after_clear:
		return _fail("Completing the same mission again rewrote the profile.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE):
		return _fail("Skipping debrief did not return to the map.")
	if not await _check_earned_mine_melee():
		return false
	_map().select_waypoint(ROAD)
	if not _press("ConfirmTravel") or not _on_map(ROAD) or _saved_world() != ROAD or _title._campaign_battle:
		return _fail("The open road did not persist arrival or started an unimplemented mission.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(ROAD) or _saved_clears() != PackedStringArray([CLEAR_ID]):
		return _fail("Continue did not restore Mara's last arrived point and existing clear.")
	return await _grain_flow()


func _check_earned_mine_melee() -> bool:
	if _saved_clears() != PackedStringArray([CLEAR_ID]) or _title._profile.invest_mara_lead_melee_point() != OK \
			or _title._profile.purchase_mara_shield_infantry_drill() != OK:
		return _fail("The actual first clear did not support two separate explicit training choices.")
	var trained := FileAccess.get_file_as_string(_profile_path)
	if not _press("ConfirmTravel") or not _button("Replay with Heavy Infantry") or not _press("Confirm Deployment"):
		return false
	var mission := _title._campaign_battle as Mission
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _mine_lead_melee_build(mission, 2, false) or not _mine_melee_contact(mission, 2):
		return false
	if FileAccess.get_file_as_string(_profile_path) != trained:
		return _fail("Deploying and fighting with the saved point rewrote the profile.")

	# Replace the on-disk marker mid-attempt. Retry must keep the launch snapshot;
	# the next launch must reject the invalid saved choice, even with a warm store.
	var invalid := ConfigFile.new()
	if invalid.load(_profile_path) != OK:
		return _fail("Could not read the completed profile to prepare an invalid marker.")
	invalid.set_value(Profile.LEAD_TRAINING, Profile.MARA_LEAD_MELEE, "true")
	if invalid.save(_profile_path) != OK:
		return _fail("Could not write the isolated invalid marker fixture.")
	var bad_save := FileAccess.get_file_as_string(_profile_path)
	mission.configure_campaign_lead_melee(false) # Running scenes cannot change the launch choice.
	_key(KEY_BACKSPACE)
	if not _mine_lead_melee_build(mission, 2, false) or FileAccess.get_file_as_string(_profile_path) != bad_save:
		return _fail("Retry changed the launch build, troop choice, BP or saved file.")
	_key(KEY_ESCAPE)
	if not PauseTest.confirm_leave(_title._pause_menu):
		return _fail("Escape did not open the battle pause menu.")
	if not _on_map(MINE) or not _press("ConfirmTravel") or not _press("Replay with Heavy Infantry"):
		return false
	mission = _title._campaign_battle as Mission
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _mine_lead_melee_build(mission, 1, true) or not _mine_melee_contact(mission, 1) \
			or FileAccess.get_file_as_string(_profile_path) != bad_save:
		return _fail("An invalid lead marker must not affect the independently trained Heavy deployment.")
	_key(KEY_ESCAPE)
	if not PauseTest.confirm_leave(_title._pause_menu):
		return _fail("Escape did not open the battle pause menu.")
	var restored := FileAccess.open(_profile_path, FileAccess.WRITE)
	if not restored:
		return _fail("Could not restore the genuine campaign profile.")
	restored.store_string(trained)
	restored.close()
	_title._profile = Profile.new(_profile_path)
	return _on_map(MINE) or _fail("Leaving the equipped attempt did not return to the Mine map.")


func _mine_lead_melee_build(mission: Mission, melee: int, heavy: bool) -> bool:
	var fight := mission.encounter
	return (_mine_budget(mission, 2, 720) and fight.hero.hp == Encounter.HERO_HP
		and fight.hero.rating(Unit.Damage.MELEE) == melee and fight.hero.stat_points == 0
		and fight.hero.rating(Unit.Damage.RANGED) == 1 and fight.hero.rating(Unit.Damage.HOLY) == 1
		and fight.infantry_attack.attacker.rating(Unit.Damage.MELEE) == 1
		and fight.archer_attack.attacker.rating(Unit.Damage.RANGED) == 1
		and fight.archer_attack.attacker.max_hp == 248.0
		and fight.infantry_attack.attacker.max_hp == (380.0 if heavy else 310.0)
		and mission.battle.formations[0].title == ("Heavy Infantry" if heavy else "Shield Infantry")) \
		or _fail("The launch did not keep the chosen Hero point isolated from BP and both subordinate slots.")


func _mine_melee_contact(mission: Mission, melee: int) -> bool:
	# Use the same valid road lane in both trials, then drive the real attack and enemy step.
	var start := mission._marker_position(mission.battlefield_marker(^"Markers/Routes/RoadCut"))
	var end := mission._marker_position(mission.battlefield_marker(^"Markers/Routes/EastPass"))
	var toward := (end - start).normalized()
	var enemy := start + toward * 1.20
	if not mission._terrain.clear_melee_contact(start, enemy):
		return _fail("The paired contact fixture needs a clear lane.")
	var fight := mission.encounter
	mission.battle.hero_position = start
	mission.battle.hero_heading = toward
	fight.enemy_position = enemy
	fight.enemy_phase = Encounter.EnemyPhase.WATCHING
	_key(KEY_J)
	_tick(16)
	var outgoing := Encounter.ENEMY_HP - fight.enemy.hp
	if not is_equal_approx(outgoing, 60.0 * Unit.damage_factor(melee, 1)) or fight.points.balance != 412:
		return _fail("The actual light contact did not use Mara's launch rating or preserve the fixed BP award.")
	_tick(32)
	var incoming := Encounter.HERO_HP - fight.hero.hp
	if not is_equal_approx(incoming, Mission.DRYAD_DAMAGE * Unit.damage_factor(1, melee)):
		return _fail("The Dryad raider's confirmed melee contact did not use the same defensive rating.")
	print("Mine lead melee %d: light dealt %.3f HP · Dryad dealt %.3f HP · +12 BP." % [melee, outgoing, incoming])
	return true


func _grain_flow() -> bool:
	_map().select_waypoint(CROSSING)
	if not _press("ConfirmTravel") or not _on_briefing() or _mine_briefing_label() or _saved_world() != CROSSING:
		return _fail("The Crossing must offer its own briefing and save arrival without the Mine budget.")
	if not _press("Read Dispatch") or not _finish_beat(Beats.MARA_GRAIN_DISPATCH) or not _on_briefing():
		return _fail("Grain dispatch did not return to the battlefield briefing without deploying.")
	_joy(JOY_BUTTON_B)
	if not _on_map(CROSSING):
		return _fail("Cancel did not keep the party at the Crossing.")
	_map().select_waypoint(MOONWASH)
	_joy(JOY_BUTTON_A)
	if not _on_map(CROSSING) or not _map()._detail.text.contains("Grain on Credit"):
		return _fail("The old Mine clear unlocked Moonwash without a Grain victory.")
	_map().select_waypoint(CROSSING)
	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	var grain := _title._campaign_battle as GrainScene
	if not grain:
		return _fail("The Crossing deployed the wrong scene.")
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	var before := FileAccess.get_file_as_string(_profile_path)
	_key(KEY_T)
	_key(KEY_C)
	_key(KEY_T)
	grain._physics_process(0.07)
	if grain.objective.outcome != Grain.Outcome.FAILED or FileAccess.get_file_as_string(_profile_path) != before:
		return _fail("Turning back both carts did not fail without saving.")
	_key(KEY_BACKSPACE)
	if not _win_single_grain(grain, Grain.Cart.BREAD):
		return false
	await process_frame
	if (
		_saved_clears() != PackedStringArray([CLEAR_ID, GRAIN_ID])
		or _saved_grain() != Grain.SEED_ONLY
		or not _finish_beat(Beats.MARA_GRAIN_SEED_DEBRIEF)
		or not _on_map(CROSSING)
	):
		return _fail("The first seed-only win did not save its actual result and debrief.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(CROSSING) or _saved_grain() != Grain.SEED_ONLY:
		return _fail("Continue did not preserve the first delivery result and Crossing waypoint.")
	before = FileAccess.get_file_as_string(_profile_path)
	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	grain = _title._campaign_battle as GrainScene
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_both_grain(grain):
		return false
	await process_frame
	if (
		FileAccess.get_file_as_string(_profile_path) != before
		or _saved_grain() != Grain.SEED_ONLY
		or not _finish_beat(Beats.MARA_GRAIN_BOTH_DEBRIEF)
		or not _on_map(CROSSING)
	):
		return _fail("A two-cart replay did not get its own debrief or overwrote the saved seed-only result.")
	return await _high_quay_flow()


func _high_quay_flow() -> bool:
	_map().select_waypoint(HARBOR)
	_joy(JOY_BUTTON_A)
	if not _on_map(CROSSING) or not _map()._confirm_button.disabled:
		return _fail("Moonwash deployment skipped its linked road.")
	_map().select_waypoint(MOONWASH)
	if not _press("ConfirmTravel") or not _is_dialogue(Beats.MARA_WATER_REQUEST) or _saved_world() != MOONWASH:
		return _fail("The first arrival on Road to Moonwash did not stage and save the authentic intermission.")
	if Profile.new(_profile_path).has_seen_intermission("mara", Beats.MARA_WATER_REQUEST):
		return _fail("Presenting the intermission prematurely marked it seen.")
	# Simulate leaving the game during the new intermission and reopening the
	# saved waypoint. The beat remains pending until closed on this profile.
	_title._show_title()
	_title._profile = Profile.new(_profile_path)
	if not _press("Continue") or not _is_dialogue(Beats.MARA_WATER_REQUEST):
		return _fail("Continue did not recover the pending Water Request at the arrived road.")
	if not _finish_beat(Beats.MARA_WATER_REQUEST) or not _on_map(MOONWASH) \
		or not Profile.new(_profile_path).has_seen_intermission("mara", Beats.MARA_WATER_REQUEST) \
		or _saved_clears() != PackedStringArray([CLEAR_ID, GRAIN_ID]) or _saved_grain() != Grain.SEED_ONLY:
		return _fail("The finished intermission should be durable without changing clears or the first Grain result.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(MOONWASH):
		return _fail("A completed Water Request repeated on Continue.")

	_map().select_waypoint(HARBOR)
	if not _press("ConfirmTravel") or not _on_briefing() or _saved_world() != HARBOR:
		return _fail("The linked harbor did not save arrival and offer its briefing.")
	if not _press("Read Dispatch") or not _finish_beat(Beats.MARA_HIGH_QUAY_DISPATCH) or not _on_briefing():
		return _fail("The authentic High Quay dispatch did not return to its briefing.")
	_joy(JOY_BUTTON_B)
	var before := FileAccess.get_file_as_string(_profile_path)
	if not _on_map(HARBOR) or _map()._heading.text == "Campaign Complete" or not _press("ConfirmTravel") \
		or not _press("Confirm Deployment"):
		return _fail("High Quay still needs explicit deployment and does not pre-complete the campaign.")
	var quay := _title._campaign_battle as HighQuay
	if not quay or quay._field.name != &"MoonwashHarborCampaign":
		return _fail("High Quay deployed the wrong battlefield.")
	quay.set_physics_process(false)
	await physics_frame
	await physics_frame
	quay.report_platoon_wiped(Quay.Platoon.SECOND)
	quay._physics_process(DT)
	if quay.objective.phase != Quay.Phase.FAILED or FileAccess.get_file_as_string(_profile_path) != before:
		return _fail("Defeat did not leave the unfinished campaign profile alone.")
	_key(KEY_BACKSPACE)
	if quay.objective.phase != Quay.Phase.WITHDRAWING or FileAccess.get_file_as_string(_profile_path) != before:
		return _fail("Retry did not reset only the attempt.")
	if not _win_high_quay(quay):
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_HIGH_QUAY_DEBRIEF) or _saved_world() != HARBOR \
		or _saved_clears() != PackedStringArray([CLEAR_ID, GRAIN_ID, QUAY_ID]) or _saved_grain() != Grain.SEED_ONLY:
		return _fail("Only physical upper-quay withdrawal should persist the exact third clear and authentic debrief.")
	if not _finish_beat(Beats.MARA_HIGH_QUAY_DEBRIEF) or not _on_map(HARBOR) or _map()._heading.text != "Campaign Complete":
		return _fail("The overworld did not report the finished Human campaign.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(HARBOR) or _map()._heading.text != "Campaign Complete":
		return _fail("Continue did not restore the completed map and current harbor.")
	_map().select_waypoint(MOONWASH)
	if not _press("ConfirmTravel") or not _on_map(MOONWASH):
		return _fail("A posted intermission repeated when revisiting the road.")
	_map().select_waypoint(HARBOR)
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("A completed final mission cannot be replayed.")
	var replay_before := FileAccess.get_file_as_string(_profile_path)
	quay = _title._campaign_battle as HighQuay
	quay.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_high_quay(quay):
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_HIGH_QUAY_DEBRIEF) or FileAccess.get_file_as_string(_profile_path) != replay_before \
			or _saved_grain() != Grain.SEED_ONLY:
		return _fail("Final replay duplicated a clear or rewrote the saved first result.")
	return await _completed_mine_replay()


func _completed_mine_replay() -> bool:
	if not _finish_beat(Beats.MARA_HIGH_QUAY_DEBRIEF):
		return false
	for waypoint in [MOONWASH, CROSSING, ROAD, MINE]:
		_map().select_waypoint(waypoint)
		if not _press("ConfirmTravel"):
			return _fail("Returning to the Mine must follow the existing map links.")
		if waypoint == CROSSING and _on_briefing():
			_joy(JOY_BUTTON_B)
		if waypoint != MINE and not _on_map(waypoint):
			return _fail("Revisiting the clear waypoints triggered the wrong screen.")
	var mine_profile := FileAccess.get_file_as_string(_profile_path)
	if not _on_briefing() or not _mine_briefing_budget(3, 740) or not _press("Confirm Deployment") \
			or FileAccess.get_file_as_string(_profile_path) != mine_profile:
		return _fail("The completed campaign must preview 400 / 740 at the Mine without changing the save.")
	var mission := _title._campaign_battle as Mission
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _mine_budget(mission, 3, 740):
		return _fail("A completed campaign should reopen the Mine at lead level three with 400 / 740 BP.")
	if not _win_rescue():
		return false
	await process_frame
	return (_is_dialogue(Beats.MARA_MINE_DEBRIEF) and FileAccess.get_file_as_string(_profile_path) == mine_profile
		and _saved_clears() == PackedStringArray([CLEAR_ID, GRAIN_ID, QUAY_ID]) and _saved_grain() == Grain.SEED_ONLY) \
		or _fail("A boosted Mine replay rewrote the completed profile or original Grain result.")


func _mine_briefing_label() -> Label:
	return _title._stage.get_node_or_null("MineDeploymentBudget") as Label


func _mine_briefing_budget(level: int, capacity: int) -> bool:
	var line := _mine_briefing_label()
	var deploy := _button("Confirm Deployment")
	return line != null and line.is_visible_in_tree() and deploy != null \
		and line.get_rect().end.y <= deploy.get_rect().position.y \
		and line.text.contains("400 starting BP") and line.text.contains("Lead platoon Lv %d" % level) \
		and line.text.contains("%d BP cap" % capacity) and line.text.contains("Each Mine attempt starts fresh") \
		and line.text.contains("Confirmed Human chapter clears")


func _mine_budget(mission: Mission, level: int, capacity: int) -> bool:
	var bp := mission.team_battle_points_frame()
	# The derived lead level only sets the budget, not the combat proxy's level.
	return bp.balance == BP.STARTING_BALANCE and bp.capacity == capacity and bp.lead_level == level \
		and mission.encounter.hero.level == 1 \
		and mission._combat_hp.text.contains("Team 400 / %d BP (lead Lv %d)" % [capacity, level])


func _win_high_quay(quay: HighQuay) -> bool:
	for id: String in ["Routes/FracturedQuay", "Routes/UpperStairFoot"]:
		if not _drive_quay(quay, id):
			return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_RIGHT_STICK)
	var front := quay.battle.formations[0]
	for id: String in ["Routes/UpperStairFoot", "Routes/UpperStairLanding"]:
		if not _march_quay(quay, front, id):
			return false
	_joy(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _drive_quay(quay, "Routes/UpperStairLanding"):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_RIGHT_STICK)
	for id: String in ["Routes/UpperStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		if not _march_quay(quay, front, id):
			return false
	_joy(JOY_BUTTON_DPAD_RIGHT)
	var rear := quay.battle.formations[1]
	for id: String in ["Routes/QuaySafeTurn", "Routes/InlandBypass", "Routes/InlandApproach",
		"Routes/InlandStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		if not _march_quay(quay, rear, id):
			return false
	if front.order != Battle.Order.EXTRACTED or rear.order != Battle.Order.EXTRACTED or quay.objective.phase != Quay.Phase.WITHDRAWING:
		return _fail("Both real formations must be safe, but cannot win without the hero.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	for id: String in ["Routes/UpperStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		if not _drive_quay(quay, id):
			return false
	return quay.objective.phase == Quay.Phase.SUCCEEDED or _fail("Live upper-quay extraction never reached its final result.")


func _drive_quay(quay: HighQuay, id: String) -> bool:
	var target := _quay_target(quay, id)
	var budget := ceili(target.distance_to(quay.battle.hero_position) / Battle.LEAD_SPEED / DT) + 120
	var reached := false
	for step in range(budget):
		var remaining := target - quay.battle.hero_position
		if remaining.length() < 0.14 or (id == "Objectives/UpperQuayExit" and quay.objective.hero_extracted):
			reached = true
			break
		var aim := remaining.normalized().rotated(quay._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y), quay)
		quay._physics_process(DT)
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_LEFT_Y, 0)
	return reached or _fail("Hero could not reach High Quay marker " + id)


func _march_quay(quay: HighQuay, group: Battle.Formation, id: String) -> bool:
	var marker := quay.battlefield_marker(NodePath("Markers/" + id))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = root.get_camera_3d().unproject_position(marker.global_position)
	root.push_input(event, true)
	var target := _quay_target(quay, id)
	var budget := ceili(group.position.distance_to(target) / Battle.FORMATION_SPEED / DT) + 95
	for step in range(budget):
		if group.order != Battle.Order.MOVE:
			break
		quay._physics_process(DT)
	return ((group.order == Battle.Order.HOLD and group.position.distance_to(target) < 0.05)
		or (id == "Objectives/UpperQuayExit" and group.order == Battle.Order.EXTRACTED)) \
		or _fail("Formation could not reach High Quay marker " + id)


func _quay_target(quay: HighQuay, id: String) -> Vector2:
	var point := quay.to_local(quay.battlefield_marker(NodePath("Markers/" + id)).global_position)
	return Vector2(point.x, point.z)


func _fresh_bread_flow(path: String) -> bool:
	_profile_path = path
	var profile := Profile.new(path)
	_title._profile = profile
	if profile.set_setting("reduced_motion", true) != OK or profile.record_mission_clear("mara", CLEAR_ID) != OK:
		return _fail("Could not seed the alternate profile with only the Mine clear.")
	var world := profile.load_campaign_world("mara")
	var clears := profile.completed_missions("mara")
	world.travel_to(MINE, clears)
	world.travel_to(ROAD, clears)
	if profile.record_world_waypoint(world) != OK:
		return _fail("Could not seed an independent arrival on Marches Road.")
	_title._show_title()
	if not _press("New Game") or not _press("mara") or not _on_map(ROAD):
		return _fail("Alternate profile did not open on its independently saved road.")
	_map().select_waypoint(CROSSING)
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return false
	var grain := _title._campaign_battle as GrainScene
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_single_grain(grain, Grain.Cart.SEED):
		return false
	await process_frame
	return (_saved_grain() == Grain.BREAD_ONLY and _finish_beat(Beats.MARA_GRAIN_BREAD_DEBRIEF)
		and _on_map(CROSSING)) or _fail("The independent first bread-only clear did not save its own outcome and dialogue.")


func _win_single_grain(grain: GrainScene, blocked: Grain.Cart) -> bool:
	_grain_dispatch(grain, blocked)
	if (
		not _grain_wait(grain, func() -> bool: return grain._blocked_cart == blocked)
		or grain.committed_cart != blocked or grain.rival.status != Rival.Status.BLOCKING
	):
		return _fail("The physically first committed cart was not blocked by the enemy reserve.")
	var delivered := Grain.Cart.SEED if blocked == Grain.Cart.BREAD else Grain.Cart.BREAD
	_grain_dispatch(grain, delivered)
	if (
		not _grain_wait(grain, func() -> bool: return grain.objective.cart_state(delivered) == Grain.CartState.SECURED)
		or grain._blocked_cart != blocked
	):
		return _fail("The other cart did not reach its yard while the first stayed blocked.")
	if grain.objective.outcome != Grain.Outcome.ACTIVE:
		return _fail("Delivery alone completed before the other cart was resolved.")
	_key(KEY_C)
	_key(KEY_T)
	grain._physics_process(0.07)
	var result := Grain.SEED_ONLY if delivered == Grain.Cart.SEED else Grain.BREAD_ONLY
	return grain.objective.clear_result == result or _fail("Actual cart arrival plus turn-back gave the wrong result.")


func _win_both_grain(grain: GrainScene) -> bool:
	_grain_dispatch(grain, Grain.Cart.BREAD)
	if not _grain_wait(grain, func() -> bool: return grain._blocked_cart == Grain.Cart.BREAD):
		return false
	_grain_dispatch(grain, Grain.Cart.SEED)
	_key(KEY_SHIFT)
	var formation: Battle.Formation = grain.battle.formations[0]
	for id: String in ["ReserveFork", "ShelteredTurn", "FordApproachWest", "FordWestBank", "FordShallows", "FordEastBank", "StoreApproach"]:
		var point := grain.battlefield_marker(NodePath("Markers/Routes/" + id)).global_position
		grain.cursor = Vector2(point.x, point.z)
		_joy(JOY_BUTTON_X)
		if id == "StoreApproach":
			if not _grain_wait(grain, func() -> bool: return formation.position.distance_to(grain.cursor) < Rival.SCREEN_RADIUS - 0.6):
				return false
		elif not _grain_wait(grain, func() -> bool: return formation.order != Battle.Order.MOVE):
			return false
	_joy(JOY_BUTTON_A)
	grain._physics_process(0.07)
	_key(KEY_SHIFT, false)
	if formation.order != Battle.Order.HOLD or grain.rival.status != Rival.Status.SCREENED:
		return _fail("The real Hold at the blockade did not reopen the ford for replay.")
	return (_grain_wait(grain, func() -> bool: return grain.objective.outcome == Grain.Outcome.SUCCEEDED)
		and grain.objective.clear_result == Grain.BOTH) or _fail("The screened replay never delivered both carts.")


func _grain_dispatch(grain: GrainScene, cart: Grain.Cart) -> void:
	if grain.selected_cart != cart:
		_key(KEY_C)
	_key(KEY_G)
	grain._physics_process(0.07)


func _grain_wait(grain: GrainScene, condition: Callable) -> bool:
	for _step in range(1100):
		if condition.call():
			return true
		grain._physics_process(0.07)
	return _fail("A Grain route event did not occur within the fixed simulation steps.")


func _finish_beat(id: StringName) -> bool:
	if not _is_dialogue(id):
		return false
	for _line in Beats.get_beat(id).lines:
		_key(KEY_ENTER)
	return _title._page != Title.Page.CAMPAIGN_DIALOGUE


func _saved_grain() -> StringName:
	return Profile.new(_profile_path).grain_clear_result()


func _win_rescue() -> bool:
	var mission := _title._campaign_battle as Mission
	var before := FileAccess.get_file_as_string(_profile_path)
	var dryad_start := mission.encounter.enemy_position
	# Place the Archers, use their real attack order, and stop after the first
	# contact. The living Dryad pursues Mara while she gets the crew out.
	_key(KEY_SHIFT)
	_key(KEY_X)
	mission.cursor = Vector2(-77, 19)
	_joy(JOY_BUTTON_X)
	_key(KEY_SHIFT, false)
	_tick(1100)
	_key(KEY_SHIFT)
	mission.cursor = dryad_start
	_key(KEY_K)
	_key(KEY_SHIFT, false)
	_tick(85)
	if mission.encounter.enemy.hp >= Encounter.ENEMY_HP or not mission.encounter.enemy.is_alive():
		return _fail("A real archer attack did not wound the Dryad in the yard.")
	_key(KEY_SHIFT)
	_joy(JOY_BUTTON_A)
	_key(KEY_SHIFT, false)
	for point in [Vector2(-76, 21), Vector2(-61, 38), Vector2(-60.5, 51), Vector2(-60.5, 56)]:
		if not _drive_rescue(point):
			return false
	if not _no_pre_rescue_reveal(mission) or mission.custody_case_scene != null or mission._bridle:
		return _fail("The battlefield showed the discovery before the miners were safe.")
	_joy(JOY_BUTTON_A)
	_tick()
	if mission.rescue_phase != Mission.Rescue.ESCORT or mission._count(Mission.Miner.SAFE) != 0 \
			or _title._page != Title.Page.CAMPAIGN_BATTLE or FileAccess.get_file_as_string(_profile_path) != before:
		return _fail("Rallying the miners either failed or prematurely saved/revealed the outcome.")
	for point in [Vector2(-63, 69), Vector2(-63, 81), Vector2(-63, 93), Vector2(-63, 102),
		Vector2(-75, 104), Vector2(-87, 105), Vector2(-99, 106), Vector2(-111, 108), Vector2(-124, 108)]:
		if not _drive_rescue(point):
			return false
		_tick(100)
	return (mission.rescue_phase == Mission.Rescue.SUCCEEDED
		and mission._count(Mission.Miner.SAFE) >= Mission.MIN_SAFE and mission.encounter.enemy.is_alive()) \
		or _fail("Too few miners reached the safe hollow, or the route required killing the raider.")


func _drive_rescue(target: Vector2) -> bool:
	var mission := _title._campaign_battle as Mission
	var command_sent := false
	for step in range(1000):
		var offset := target - mission.battle.hero_position
		if offset.length() < 0.18 or mission._finished():
			break
		if mission.battle.direct_hero_control():
			command_sent = false
			var stick := offset.normalized().rotated(mission._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, stick.x)
			_axis(JOY_AXIS_LEFT_Y, stick.y)
		elif not command_sent:
			_axis(JOY_AXIS_LEFT_X, 0.0)
			_axis(JOY_AXIS_LEFT_Y, 0.0)
			_key(KEY_SHIFT)
			if mission.selected_index == 1:
				_key(KEY_X)
			elif mission.selected_index == 0:
				_key(KEY_Z)
			mission.cursor = target
			_joy(JOY_BUTTON_X)
			_key(KEY_SHIFT, false)
			command_sent = true
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return (mission.battle.hero_position.distance_to(target) < 0.18
		or mission.rescue_phase == Mission.Rescue.SUCCEEDED) \
		or _fail("Mara could not reach the Greyhollow point %s." % [target])


func _no_pre_rescue_reveal(page: Node) -> bool:
	for label in page.find_children("*", "Label", true, false) + page.find_children("*", "Label3D", true, false):
		if label.is_visible_in_tree() and label.text.to_lower().contains("godbridle"):
			return false
	return true


func _reveal_names_artifact() -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not dialogue or not dialogue._cinematic:
		return _fail("The successful rescue did not activate the shelter cinematic.")
	var named := false
	for _line in Beats.get_beat(Beats.MARA_MINE_DEBRIEF).lines:
		named = named or dialogue._body.text.contains("Godbridle")
		_key(KEY_ENTER)
	return named or _fail("The shelter cinematic never names what the miners found.")


func _has_playtest_notice() -> bool:
	for child in _title._stage.get_children():
		if child is Label and child.is_visible_in_tree() and child.text.begins_with("Development playtest: includes placeholder art."):
			return true
	return false


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null and _title._campaign_world.current_waypoint_id() == id


func _on_briefing() -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _button("Confirm Deployment") != null and _title._campaign_battle == null


func _map() -> CampaignMap:
	return _title._stage.get_node_or_null("CampaignMap") as CampaignMap


func _is_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	return dialogue != null and dialogue._active and dialogue._beat_id == id


func _read_rescue_dispatch() -> bool:
	for _line in Beats.get_beat(Beats.MARA_MINE_DISPATCH).lines:
		if not _no_pre_rescue_reveal(_title._stage):
			return _fail("The rescue dispatch named the artifact before anyone was safe.")
		_key(KEY_ENTER)
	return true


func _saved_world() -> String:
	return Profile.new(_profile_path).load_campaign_world("mara").current_waypoint_id()


func _saved_clears() -> PackedStringArray:
	return Profile.new(_profile_path).completed_missions("mara")


func _tick(count := 1) -> void:
	for _step in range(count):
		(_title._campaign_battle as Mission)._physics_process(DT)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _button(name: String) -> Button:
	return _title.find_child(name, true, false) as Button


func _press(name: String) -> bool:
	var button := _button(name)
	if not button or button.disabled or not button.is_visible_in_tree():
		return _fail("Missing or unavailable control: " + name)
	button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false


## Outside combat the leader travels with their platoon by Move orders, as the
## player sets them; in combat the stick steers the leader directly.
func _march_lead(aim: Vector2, mission: Node) -> void:
	var battle = mission.battle
	if battle.direct_hero_control():
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		return
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if aim.length_squared() > 0.0:
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-mission._hero_yaw) * Battle.LEAD_SPEED * DT)
