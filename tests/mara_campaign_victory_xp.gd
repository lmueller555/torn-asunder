extends "res://tests/mara_campaign_flow.gd"
## Actual title, ordered combat, rescue, resumable recap and no replay payout.

const Progress := preload("res://game/combat/campaign_platoon_progress.gd")


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-mara-victory-xp-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_profile_path)
	var configured := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", true) == OK
	var passed := configured and await _exercise()
	if is_instance_valid(_title):
		_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Greyhollow mission XP: actual defeat pending, no failure/Retry/leave payout, saved 100+10 once, resumable keyboard recap before reveal, replay 0, ordinary progression passed.")
	quit(0 if passed else 1)


func _exercise() -> bool:
	var unchanged := FileAccess.get_file_as_bytes(_profile_path)
	if Profile.new(_profile_path).commit_greyhollow_victory(2).error != ERR_INVALID_DATA:
		return _fail("More defeats than the authoritative scenario holds were accepted.")
	if DirAccess.make_dir_absolute(_profile_path + ".tmp") != OK:
		return _fail("Could not stage a failed write to test atomicity.")
	var failed := Profile.new(_profile_path).commit_greyhollow_victory(1)
	DirAccess.remove_absolute(_profile_path + ".tmp")
	if failed.error == OK or FileAccess.get_file_as_bytes(_profile_path) != unchanged or _lead_total_xp() != 0:
		return _fail("An unsuccessfully saved victory granted XP, reveal, or clear.")
	await _open_title()
	if not _press("New Game") or not _press("mara") or not _press("BackButton"):
		return _fail("Could not open the actual fresh Mara deployment.")
	var mission := _title._campaign_battle as Mission
	if not mission or mission.encounter.hero.experience != 0:
		return _fail("A new battle started with earned mission XP.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var saved_on_arrival := FileAccess.get_file_as_bytes(_profile_path)
	# A forced absent/dead model is not a kill from the authoritative
	# damage step. This staging is only a negative control.
	mission.encounter.enemy.receive_damage(mission.encounter.enemy.hp)
	_tick()
	if mission.encounter.enemy_defeated_in_combat:
		return _fail("An enemy removed before real combat was counted as a defeat.")
	_key(KEY_BACKSPACE)
	var original := mission.encounter
	if not _kill_using_real_orders(mission) or mission.encounter != original:
		return false
	if FileAccess.get_file_as_bytes(_profile_path) != saved_on_arrival or _lead_total_xp() != 0 \
			or mission.encounter.hero.experience != 0 or mission.encounter.points.balance <= 400:
		return _fail("Kill touched XP/save before success, or prevented the existing immediate BP gain.")
	# Preserve a pending kill while the real failure result reaches the shared
	# signal; the subsequent actual Retry must construct a completely new owner.
	mission.mission_finished.emit(false)
	await process_frame
	if _title._page != Title.Page.CAMPAIGN_BATTLE or _lead_total_xp() != 0:
		return _fail("A failure signal with pending combat work granted XP or presented victory.")
	_key(KEY_BACKSPACE)
	if mission.encounter == original or mission.encounter.enemy_defeated_in_combat or _lead_total_xp() != 0:
		return _fail("Actual Retry carried a provisional enemy defeat into the next attempt.")
	if not _kill_using_real_orders(mission) or not PauseTest.leave_battle(_title):
		return _fail("Could not abandon a real second attempt after its pending defeat.")
	if _lead_total_xp() != 0 or not _on_map(MINE) or not _saved_clears().is_empty():
		return _fail("Leaving the mission recorded a pending kill or clear.")
	await process_frame
	if not _reopen_mine():
		return false
	mission = _title._campaign_battle as Mission
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _kill_using_real_orders(mission) or not _escort_crew(mission):
		return false
	# A second success signal arriving before the deferred recap remains one award.
	mission.mission_finished.emit(true)
	await process_frame
	if not _check_recap(1, 110) or _lead_total_xp() != 110:
		return _fail("The real first victory did not report one defeated combat unit and 110 earned XP.")
	var saved := Profile.new(_profile_path)
	if not saved.greyhollow_reveal_pending() or not saved.greyhollow_pending_xp_recap() \
			or saved.campaign_combat_xp("mara").get(CLEAR_ID) != 10:
		return _fail("Clear, bonus, saved recap and reveal are not an atomic readable result.")
	if saved.commit_greyhollow_victory(1).total_xp() != 0 or _lead_total_xp() != 110:
		return _fail("Two stores recording the same campaign first clear awarded the same XP again.")
	await _open_title()
	if not _press("Continue") or not _check_recap(1, 110) or _lead_total_xp() != 110:
		return _fail("Reopening before recap acknowledgement lost or duplicated the award.")
	_key(KEY_ENTER)
	_key(KEY_ENTER, false)
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or Profile.new(_profile_path).greyhollow_pending_xp_recap() \
			or not Profile.new(_profile_path).greyhollow_reveal_pending():
		return _fail("Keyboard Continue bypassed the mandatory reveal or left the recap pending.")
	if not _finish_beat(Beats.MARA_MINE_DEBRIEF) or not _on_map(MINE) or not _reopen_mine():
		return _fail("The normal plot reveal did not return to progression and replay.")
	mission = _title._campaign_battle as Mission
	if mission.encounter.hero.experience != 110:
		return _fail("Awarded combat XP was not consumed by the authoritative marked lead build.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _kill_using_real_orders(mission) or not _escort_crew(mission):
		return false
	await process_frame
	if not _check_recap(1, 0) or _lead_total_xp() != 110 or Profile.new(_profile_path).greyhollow_pending_xp_recap():
		return _fail("Successful replay failed to show the real count and zero additional XP.")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	root.push_input(accept, true)
	accept.pressed = false
	root.push_input(accept, true)
	return _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _fail("Controller could not advance from a real replay recap.")


func _open_title() -> void:
	if is_instance_valid(_title):
		root.remove_child(_title)
		_title.queue_free()
		await process_frame
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	root.add_child(_title)
	await process_frame


func _reopen_mine() -> bool:
	return (_on_map(MINE) and _press("ConfirmTravel") and _on_briefing() and _press("Confirm Deployment")) \
		or _fail("Could not return to the registered Mine briefing from the actual world map.")


func _lead_total_xp() -> int:
	var profile := Profile.new(_profile_path)
	return Progress.inspect("mara", profile.completed_missions("mara"), profile.campaign_combat_xp("mara")).total_xp


func _check_recap(defeated: int, xp: int) -> bool:
	if _title._page != Title.Page.MISSION_XP_RECAP:
		return false
	var text := []
	for label: Label in _title._stage.find_children("*", "Label", true, false):
		text.append(label.text)
	return "Enemy combat units defeated: %d" % defeated in text and "Lead platoon XP awarded: %d" % xp in text


func _kill_using_real_orders(mission: Mission) -> bool:
	var target := mission.encounter.enemy_position
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
	mission.cursor = target
	_key(KEY_K)
	_key(KEY_SHIFT, false)
	for tick in range(1350):
		if not mission.encounter.enemy.is_alive():
			break
		_tick()
	return (mission.encounter.enemy_defeated_in_combat and not mission.encounter.enemy.is_alive() \
		and mission.rescue_phase == Mission.Rescue.RALLY) \
		or _fail("Real movement and Archer Attack did not defeat the registered Dryad before victory.")


func _escort_crew(mission: Mission) -> bool:
	for point in [Vector2(-76, 21), Vector2(-61, 38), Vector2(-60.5, 51), Vector2(-60.5, 56)]:
		if not _drive_rescue(point):
			return false
	_joy(JOY_BUTTON_A)
	_tick()
	if mission.rescue_phase != Mission.Rescue.ESCORT:
		return _fail("The miners could not rally after the confirmed kill.")
	for point in [Vector2(-63, 69), Vector2(-63, 81), Vector2(-63, 93), Vector2(-63, 102),
			Vector2(-75, 104), Vector2(-87, 105), Vector2(-99, 106), Vector2(-111, 108), Vector2(-124, 108)]:
		if not _drive_rescue(point):
			return false
		_tick(100)
	return (mission.rescue_phase == Mission.Rescue.SUCCEEDED and mission._count(Mission.Miner.SAFE) >= Mission.MIN_SAFE) \
		or _fail("Pending combat work did not turn into victory through the real protected exit.")
