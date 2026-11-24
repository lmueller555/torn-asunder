extends "res://tests/mara_campaign_flow.gd"
## Real title and objective success. Grain uses ordinary deliveries. The
## Quay test stages actors at real exit geometry to isolate its final handoff.

const Progress := preload("res://game/combat/campaign_platoon_progress.gd")
const World := preload("res://game/campaign_world.gd")


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-mara-recaps-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var store := Profile.new(_profile_path)
	var ready := store.set_setting("fullscreen", false) == OK and store.mark_played("mara") == OK \
		and store.record_greyhollow_rescue_clear() == OK and store.finish_greyhollow_reveal() == OK
	var path := World.new("mara", CROSSING, store.completed_missions("mara"))
	ready = ready and store.record_world_waypoint(path) == OK
	var passed := ready and await _exercise()
	if is_instance_valid(_title):
		_title.queue_free()
	await process_frame
	for file in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	if passed:
		print("Mara recaps: actual Grain deliveries and Quay extraction, zero kills, first-clear/replay XP, save/resume, skip/reduced motion and narrative order passed.")
	quit(0 if passed else 1)


func _exercise() -> bool:
	if Profile.new(_profile_path).commit_mara_noncombat_victory(QUAY_ID).error != ERR_UNAUTHORIZED:
		return _fail("An uncleared intervening chapter allowed High Quay XP.")
	await _open_title()
	if not _press("Continue") or not _on_map(CROSSING) or not _deploy_current():
		return _fail("The actual Grain deployment could not be opened.")
	var grain := _title._campaign_battle as GrainScene
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_single_grain(grain, Grain.Cart.BREAD):
		return false
	await process_frame
	if not _result(GRAIN_ID, 100) or _saved_grain() != Grain.SEED_ONLY or _lead_xp() != 200:
		return _fail("The first actual seed delivery did not save its result and 100 XP with zero kills.")
	if not _title._xp_recap_reveal:
		return _fail("Regular motion did not start the presentation.")
	_tap(KEY_ENTER)
	if not _result(GRAIN_ID, 100) or _title._xp_recap_reveal or not _numbers(100):
		return _fail("Immediate confirm failed to show final numbers without leaving them.")
	await _open_title()
	if not _press("Continue") or not _result(GRAIN_ID, 100) or _lead_xp() != 200:
		return _fail("Continue did not reopen the same pending Grain result.")
	await create_timer(0.95).timeout
	if _title._xp_recap_reveal or not _numbers(100) or not _press("Continue") or not _finish_beat(Beats.MARA_GRAIN_SEED_DEBRIEF) or not _on_map(CROSSING):
		return _fail("Acknowledging resumed Grain did not preserve the saved seed outcome/debrief.")
	if Profile.new(_profile_path).set_setting("reduced_motion", true) != OK:
		return _fail("Could not enable Reduced Motion in the temporary profile.")
	await _open_title()
	if not _press("Continue") or not _on_map(CROSSING) or not _deploy_current():
		return _fail("Could not replay the actual Grain mission.")
	grain = _title._campaign_battle as GrainScene
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_both_grain(grain):
		return false
	await process_frame
	if not _result(GRAIN_ID, 0) or not _numbers(0) or _title._xp_recap_reveal or _saved_grain() != Grain.SEED_ONLY \
			or _lead_xp() != 200 or not _press("Continue") or not _finish_beat(Beats.MARA_GRAIN_BOTH_DEBRIEF):
		return _fail("Reduced Motion skipped numbers, or Grain replay overwrote the first result/XP.")
	_map().select_waypoint(MOONWASH)
	if not _press("ConfirmTravel") or not _finish_beat(Beats.MARA_WATER_REQUEST):
		return _fail("The authored Water Request did not precede High Quay.")
	_map().select_waypoint(HARBOR)
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("Could not enter High Quay from its briefing.")
	var quay := _title._campaign_battle as HighQuay
	if not quay:
		return _fail("The High Quay registered scene did not launch.")
	quay.set_physics_process(false)
	await physics_frame
	await physics_frame
	quay.report_platoon_wiped(Quay.Platoon.SECOND)
	quay._physics_process(DT)
	if quay.objective.phase != Quay.Phase.FAILED or _title._page != Title.Page.CAMPAIGN_BATTLE or _lead_xp() != 200:
		return _fail("A High Quay loss awarded XP or showed a recap.")
	_key(KEY_BACKSPACE)
	if not _win_from_exit(quay):
		return false
	await process_frame
	if not _result(QUAY_ID, 100) or not _numbers(100) or _lead_xp() != 300:
		return _fail("The High Quay extraction did not award a first-clear 100 XP with zero kills.")
	await _open_title()
	if not _press("Continue") or not _result(QUAY_ID, 100) or not _press("Continue") \
			or not _finish_beat(Beats.MARA_HIGH_QUAY_DEBRIEF) or not _on_map(HARBOR):
		return _fail("Continue skipped the High Quay debrief or arrived at the wrong map.")
	if not _deploy_current():
		return _fail("Could not start High Quay replay.")
	quay = _title._campaign_battle as HighQuay
	quay.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_from_exit(quay):
		return false
	await process_frame
	return (_result(QUAY_ID, 0) and _numbers(0) and _lead_xp() == 300 and _press("Continue") \
		and _finish_beat(Beats.MARA_HIGH_QUAY_DEBRIEF) and _on_map(HARBOR)) \
		or _fail("A High Quay replay re-awarded XP or lost its debrief.")


func _win_from_exit(quay: HighQuay) -> bool:
	var exit := quay._marker_position(quay.battlefield_marker(^"Markers/Objectives/UpperQuayExit"))
	quay.battle.hero_position = exit
	for group in quay.battle.formations:
		for step in range(-6, 7):
			if group.order == Battle.Order.EXTRACTED:
				break
			group.position = exit + Vector2(0, step * 0.5)
			group.destination = group.position
			group.order = Battle.Order.HOLD
			quay._sync_view()
			quay._physics_process(DT)
	return (quay.objective.phase == Quay.Phase.SUCCEEDED and quay.objective.hero_extracted \
		and quay.objective.is_platoon_extracted(Quay.Platoon.FIRST) and quay.objective.is_platoon_extracted(Quay.Platoon.SECOND)) \
		or _fail("Actual High Quay exit observation did not extract the hero and both full platoons.")


func _result(id: String, xp: int) -> bool:
	var receipt := _title._mission_xp_recap
	return _title._page == Title.Page.MISSION_XP_RECAP and _title._xp_recap_mission == id and receipt != null \
		and receipt.defeated == 0 and receipt.total_xp() == xp and receipt.combat_xp == 0


func _numbers(xp: int) -> bool:
	return _title._xp_recap_defeats.text == "Enemy combat units defeated: 0" \
		and _title._xp_recap_award.text == "Lead platoon XP awarded: %d" % xp


func _lead_xp() -> int:
	var profile := Profile.new(_profile_path)
	return Progress.inspect("mara", profile.completed_missions("mara"), profile.campaign_combat_xp("mara")).total_xp


func _deploy_current() -> bool:
	return _press("ConfirmTravel") and _on_briefing() and _press("Confirm Deployment")


func _open_title() -> void:
	if is_instance_valid(_title):
		root.remove_child(_title)
		_title.queue_free()
		await process_frame
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	root.add_child(_title)
	await process_frame


func _tap(code: Key) -> void:
	_key(code)
	_key(code, false)
