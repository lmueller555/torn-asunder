extends SceneTree
## Exercises the station's saved progression through the real title and battlefield.

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const World := preload("res://game/campaign_world.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Mission := preload("res://game/battlefield/mara_greyhollow_rescue.gd")
const Infantry := preload("res://game/battlefield/mara_infantry_attack.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Pause := preload("res://tests/pause_test_helpers.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const JOB_HEAVY := "JobHeavyInfantry"
const JOB_ACTION := "BarracksJobAction"
const TRAIN_HEAVY := "Confirm Training (1 drill credit)"
const REVIEW_DRILL := "Review Formation Drill"
const ALLOCATE_MELEE := "Allocate 1 point to Melee Power"
const MELEE_CONFIRM := "Confirm Melee Power (1 point)"
const DEFAULT_DEPLOY := "Confirm Deployment"
const HEAVY_DEPLOY := "Replay with Heavy Infantry"
const HEAVY_MODEL := "res://assets/models/human_heavy_infantry.glb"

var _path: String
var _title: Title


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-barracks-campaign-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_path)
	var passed := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", true) == OK \
		and profile.mark_played(Profile.MARA) == OK
	if passed:
		passed = await _exercise()
	if is_instance_valid(_title):
		_title.queue_free()
		await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara Barracks: locked actions, explicit independent spends, save/reload, stale replay guard, live Shield and Heavy stats, and Heavy Retry passed.")
	quit(0 if passed else 1)


func _exercise() -> bool:
	_open_title()
	if not _press("Continue") or not _open_barracks():
		return _fail("Continue did not open the fresh Mara camp and station Barracks.")
	var locked_save := FileAccess.get_file_as_bytes(_path)
	if not _press(JOB_HEAVY) or _available(JOB_ACTION):
		return _fail("A fresh profile offered a purchase or investment in Barracks.")
	# Hidden controls cannot authorize an action even if their signals are emitted.
	var train := _button(JOB_ACTION)
	if train:
		train.pressed.emit()
	if not _press("SelectShieldInfantry") or _available(JOB_ACTION):
		return _fail("The fresh Shield slot must not offer a Melee investment.")
	var invest := _button(JOB_ACTION)
	if invest:
		invest.pressed.emit()
	if not _unchanged(locked_save) or not _status(false, Unit.MIN_RATING, Profile.MaraShieldMeleeStatus.LOCKED):
		return _fail("Inspecting or activating a locked action changed the profile.")
	if not _press("Back") or not _press("Main Gate") or not _open_mine_briefing() or _available(HEAVY_DEPLOY):
		return _fail("The fresh campaign did not preserve the original Shield-only briefing.")
	var fresh_briefing := FileAccess.get_file_as_bytes(_path)
	_title._deploy_campaign_mission(Profile.MARA_MINE, true)
	if _title._page != Title.Page.MISSION_BRIEFING or _title._campaign_battle or not _unchanged(fresh_briefing) \
			or not _press(DEFAULT_DEPLOY):
		return _fail("Fresh Heavy authorization was bypassable or the normal launch was unavailable.")
	var mission := _title._campaign_battle as Mission
	if not _live_loadout(mission, false, Unit.MIN_RATING):
		return _fail("The original Mine did not launch with the original Shield Infantry stats.")

	# Seed the typed victory transaction; reopening the actual title must still
	# present the required reveal before the camp and then unlock its services.
	var seeded := Profile.new(_path)
	if seeded.record_greyhollow_rescue_clear() != OK \
			or seeded.record_world_waypoint(World.new(Profile.MARA, CAMP, seeded.completed_missions(Profile.MARA))) != OK:
		return _fail("Could not seed a first rescue without granting either spend.")
	await _reopen_title()
	if not _press("Continue") or _title._page != Title.Page.CAMPAIGN_DIALOGUE:
		return _fail("Continue bypassed the pending mandatory reveal.")
	var dialogue := _title._stage.get_child(0) as Dialogue
	if not dialogue:
		return _fail("Expected the existing reveal dialogue scene.")
	dialogue.cancel()
	if not _open_barracks() or not _status(false, Unit.MIN_RATING, Profile.MaraShieldMeleeStatus.AVAILABLE):
		return _fail("Acknowledging the reveal did not unlock only the earned Shield point.")
	var earned := FileAccess.get_file_as_bytes(_path)
	if not _press(JOB_HEAVY) or not _available(JOB_ACTION) or _button(JOB_ACTION).text != REVIEW_DRILL \
			or not _unchanged(earned):
		return _fail("Inspecting eligible Heavy Infantry did not expose a separate, optional drill CTA.")
	if not _press(JOB_ACTION) or not _available(TRAIN_HEAVY) or not _unchanged(earned):
		return _fail("The advancement CTA must open the existing drill confirmation without spending.")
	if not _press(TRAIN_HEAVY) or _unchanged(earned) \
			or not _status(true, Unit.MIN_RATING, Profile.MaraShieldMeleeStatus.AVAILABLE):
		return _fail("Confirming drill must unlock the Heavy alternative without spending the Melee point.")
	if _title._page != Title.Page.BARRACKS and (not _press("Back") or _title._page != Title.Page.BARRACKS):
		return _fail("Drill confirmation must return to the same Barracks.")
	var trained := FileAccess.get_file_as_bytes(_path)
	if not _press("SelectShieldInfantry") or not _available(JOB_ACTION) or _button(JOB_ACTION).text != ALLOCATE_MELEE \
			or not _press(JOB_ACTION) or not _available(MELEE_CONFIRM) or not _unchanged(trained):
		return _fail("Melee allocation did not show an explicit second confirmation without writing.")
	if not _press("Back") or _title._page != Title.Page.BARRACKS or not _unchanged(trained):
		return _fail("Backing out of Melee confirmation spent the point or lost its Barracks.")
	if not _press("SelectShieldInfantry") or not _press(JOB_ACTION) or not _press(MELEE_CONFIRM) \
			or _unchanged(trained) or not _status(true, 2, Profile.MaraShieldMeleeStatus.INVESTED):
		return _fail("Confirming Melee did not spend precisely the earned Shield point.")
	if _title._page != Title.Page.BARRACKS and (not _press("Back") or _title._page != Title.Page.BARRACKS):
		return _fail("Melee confirmation must lead back to the same Barracks.")
	var invested := FileAccess.get_file_as_bytes(_path)
	invest = _button(JOB_ACTION)
	if invest:
		invest.pressed.emit()
	if _available(JOB_ACTION) or not _unchanged(invested) or Profile.new(_path).mara_lead_melee_invested():
		return _fail("The Melee point can be spent twice or leaked to the separate lead investment.")

	await _reopen_title()
	if not _press("Continue") or not _open_barracks() or not _status(true, 2, Profile.MaraShieldMeleeStatus.INVESTED):
		return _fail("Reload did not retain both independent Barracks spends.")
	if _text("StatValue0") != "2" or not _press("SelectArchers") or _text("StatValue0") != "1" or _available(JOB_ACTION):
		return _fail("The live Ratings view must show the confirmed point only on Shield Infantry.")
	if not _press(JOB_HEAVY) or _available(JOB_ACTION) or not _press("Back") or not _press("Main Gate") \
			or not _open_mine_briefing() or not _available(HEAVY_DEPLOY):
		return _fail("The trained job must stay optional until explicitly chosen in the Mine briefing.")
	var before_replay := FileAccess.get_file_as_bytes(_path)
	var stale := ConfigFile.new()
	if stale.load(_path) != OK:
		return _fail("Could not make a stale briefing fixture.")
	stale.erase_section_key(Profile.SUBORDINATE_TRAINING, Profile.MARA_SHIELD_DRILL)
	if stale.save(_path) != OK:
		return _fail("Could not replace the currently saved qualification.")
	var unqualified := FileAccess.get_file_as_bytes(_path)
	if not _press(HEAVY_DEPLOY) or _title._page != Title.Page.MISSION_BRIEFING \
			or _title._campaign_battle or not _unchanged(unqualified):
		return _fail("A stale on-screen Heavy option bypassed the current on-disk profile.")
	var restore := FileAccess.open(_path, FileAccess.WRITE)
	if not restore:
		return _fail("Could not restore the qualified profile fixture.")
	restore.store_buffer(before_replay)
	restore.close()

	if not _press(DEFAULT_DEPLOY):
		return _fail("Stock default deployment did not remain available.")
	mission = _title._campaign_battle as Mission
	if not _live_loadout(mission, false, 2) or not _unchanged(before_replay):
		return _fail("Default launch must stay regular Shield Infantry and apply its saved Melee point.")
	await process_frame
	if not Pause.leave_battle(_title) or not _open_mine_briefing() or not _press(HEAVY_DEPLOY):
		return _fail("The replay did not accept the explicit Heavy choice after leaving the stock attempt.")
	mission = _title._campaign_battle as Mission
	if not _live_loadout(mission, true, 2) or not _unchanged(before_replay):
		return _fail("The explicit Heavy replay did not inherit the frontline slot's saved Melee rating.")
	mission.set_physics_process(false)
	await process_frame
	var wounded := mission.encounter.infantry_attack.attacker
	wounded.receive_damage(10.0)
	if wounded.hp >= wounded.max_hp:
		return _fail("The live Heavy proxy was not damaged before Retry.")
	_key(KEY_BACKSPACE)
	if not _live_loadout(mission, true, 2) or not _unchanged(before_replay):
		return _fail("Retry must preserve both the explicit Heavy choice and its Melee rating and restore its HP.")
	await process_frame
	if not Pause.leave_battle(_title) or not _open_mine_briefing() or not _press(DEFAULT_DEPLOY) \
			or not _live_loadout(_title._campaign_battle as Mission, false, 2):
		return _fail("Leaving that replay must not equip Heavy Infantry for the next normal deployment.")
	return _unchanged(before_replay) or _fail("Choosing or retrying a deployment rewrote the saved profile.")


func _status(heavy: bool, melee: int, status: Profile.MaraShieldMeleeStatus) -> bool:
	var state := Profile.new(_path).mara_shield_barracks_state()
	return state.heavy_authorized == heavy and state.melee_rating == melee and state.melee_status == status


func _live_loadout(mission: Mission, heavy: bool, melee: int) -> bool:
	if not mission or _title._page != Title.Page.CAMPAIGN_BATTLE:
		return false
	var proxy := mission.encounter.infantry_attack.attacker
	var formation := mission.battle.formations[0]
	var model := mission._formation_members[0][0].get_node_or_null("HeavyInfantryModel") as Node3D
	var hp := Mission.HEAVY_HP if heavy else Infantry.PROTOTYPE_HP
	return proxy.rating(Unit.Damage.MELEE) == melee and is_equal_approx(proxy.max_hp, hp) and is_equal_approx(proxy.hp, hp) \
		and formation.title == ("Heavy Infantry" if heavy else "Shield Infantry") \
		and ((model != null and model.scene_file_path == HEAVY_MODEL) if heavy else (model == null)) \
		and mission.encounter.archer_attack.attacker.rating(Unit.Damage.MELEE) == Unit.MIN_RATING \
		and mission.encounter.hero.rating(Unit.Damage.MELEE) == Unit.MIN_RATING and mission.rescue_phase == Mission.Rescue.RALLY


func _open_barracks() -> bool:
	return _title._page == Title.Page.WORLD_MAP and _title._campaign_world.current_waypoint_id() == CAMP \
		and _press("ConfirmTravel") and _title._page == Title.Page.STATION \
		and _press("Barracks") and _title._page == Title.Page.BARRACKS


func _open_mine_briefing() -> bool:
	if _title._page != Title.Page.WORLD_MAP:
		return false
	var chart := _title._stage.get_child(0) as Map
	return chart != null and chart.select_waypoint(MINE) and _press("ConfirmTravel") \
		and _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null


func _open_title() -> void:
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_path)
	# Hosted scene, not the project's root: uses the canonical 2D chart while
	# exercising the same title, station, briefing, and battlefield scripts.
	root.add_child(_title)


func _reopen_title() -> void:
	_title.queue_free()
	await process_frame
	_open_title()


func _unchanged(bytes: PackedByteArray) -> bool:
	return FileAccess.get_file_as_bytes(_path) == bytes


func _button(name: String) -> Button:
	return _title._stage.find_child(name, true, false) as Button


func _text(name: String) -> String:
	var label := _title._stage.find_child(name, true, false) as Label
	return label.text if label else ""


func _available(name: String) -> bool:
	var button := _button(name)
	return button != null and button.is_visible_in_tree() and not button.disabled


func _press(name: String) -> bool:
	if not _available(name):
		return false
	_button(name).pressed.emit()
	return true


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
