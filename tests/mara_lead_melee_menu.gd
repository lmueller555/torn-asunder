extends "res://tests/mara_campaign_flow.gd"
## Uses the real Greyhollow rescue; no training or confirmed clear is seeded.

const TRAINING := "Lead Melee Training"
const INVEST := "Confirm Investment (1 lead point)"


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-mara-lead-menu-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	var configured := _title._profile.set_setting("fullscreen", false) == OK \
		and _title._profile.set_setting("reduced_motion", true) == OK
	root.add_child(_title)
	await process_frame
	var passed := configured and await _exercise_training_menu()
	_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara lead Melee menu: real first clear, focus, locked and optional spend, failed save, reopen, Mine replay and campaign isolation passed.")
	quit(0 if passed else 1)


func _exercise_training_menu() -> bool:
	if _title._profile.mark_played("mara") != OK:
		return _fail("Could not seed an unplayed Mine at camp.")
	_title._show_title()
	_tap_key(KEY_DOWN)
	_tap_key(KEY_ENTER) # Continue the camp save.
	if not _on_map(CAMP) or not await _open_training():
		return _fail("Keyboard and D-pad did not reach Mara's training from the real Camp Operations.")
	var locked_save := FileAccess.get_file_as_bytes(_profile_path)
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	if not _training_state(1, "Locked: Clear Get Them Out", false) or not _focused("Back") \
			or FileAccess.get_file_as_bytes(_profile_path) != locked_save:
		return _fail("Locked status must be read-only and must not focus a phantom confirmation.")
	await _capture("locked")
	_tap_joy(JOY_BUTTON_B)
	if not _focused(TRAINING):
		return _fail("Controller Back must restore the Camp entry focus.")
	_tap_joy(JOY_BUTTON_DPAD_LEFT)
	if not _focused("Shield Infantry Drill"):
		return _fail("The separate Shield Drill lost its position in the focus chain.")
	_tap_key(KEY_ESCAPE)
	if not await _deploy_mine_at_rating(1, 700) or not _win_rescue():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR_ID]) \
			or Profile.new(_profile_path).mara_lead_melee_invested():
		return _fail("A genuine clear must grant eligibility without spending the point.")
	_tap_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or not _map().select_waypoint(CAMP):
		return _fail("The completed Mine did not return to the adjacent camp route.")
	_tap_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not await _open_training():
		return false
	var eligible := FileAccess.get_file_as_bytes(_profile_path)
	if not _training_state(1, "raise Melee Power from 1 to 2", true) or not _focused("Back"):
		return _fail("Eligible but unspent must show Melee 1 and leave focus on Back.")
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	if not _focused(INVEST) or FileAccess.get_file_as_bytes(_profile_path) != eligible:
		return _fail("Viewing or focusing the eligible action must not write the save.")
	await _capture("eligible")
	_tap_key(KEY_ESCAPE)
	if not _focused(TRAINING) or FileAccess.get_file_as_bytes(_profile_path) != eligible:
		return _fail("Closing the eligible summary spent the point.")
	_tap_key(KEY_ENTER)
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	if DirAccess.make_dir_absolute(_profile_path + ".tmp") != OK:
		return _fail("Could not prepare a failed-save confirmation.")
	_tap_joy(JOY_BUTTON_A)
	DirAccess.remove_absolute(_profile_path + ".tmp")
	if not _training_state(1, "Available", true) or not _title._notice.visible \
			or not _title._notice.text.contains("No point was spent") or FileAccess.get_file_as_bytes(_profile_path) != eligible:
		return _fail("A refused write must leave the summary eligible and explain that nothing was spent.")
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	_tap_joy(JOY_BUTTON_A)
	var invested := FileAccess.get_file_as_bytes(_profile_path)
	_title._profile = Profile.new(_profile_path)
	var shield := _title._profile.mara_shield_infantry_training()
	if not _training_state(2, "one-time training is complete", false) or not _focused("Back") \
			or not _title._profile.mara_lead_melee_invested() or invested == eligible \
			or shield.available_drill_credit(Title.MaraTraining.SHIELD_INFANTRY_SLOT) != 1:
		return _fail("Explicit confirmation did not persist Melee 2 or incorrectly spent the separate Shield credit.")
	await _capture("invested")
	_tap_key(KEY_ESCAPE)
	if not _focused(TRAINING):
		return _fail("Keyboard Back must restore focus to the separate Lead Melee entry.")
	_tap_key(KEY_ENTER)
	if not _training_state(2, "one-time", false) or FileAccess.get_file_as_bytes(_profile_path) != invested:
		return _fail("Reopening after a profile reload must not spend again.")
	_tap_key(KEY_ESCAPE)
	_tap_key(KEY_ESCAPE)
	if not await _deploy_mine_at_rating(2, 720):
		return false
	var before_retry := FileAccess.get_file_as_bytes(_profile_path)
	_tap_key(KEY_BACKSPACE)
	var retry := _title._campaign_battle as Mission
	if not retry or not _mine_lead_melee_build(retry, 2, false) \
			or retry.rescue_phase != Mission.Rescue.RALLY \
			or FileAccess.get_file_as_bytes(_profile_path) != before_retry:
		return _fail("Retry did not retain Mara's rating, normal Shield loadout, fresh objective, and invested save.")
	_tap_key(KEY_ESCAPE)
	_tap_joy(JOY_BUTTON_B)
	CampaignFlow.resume_at_map(_title, "raska")
	if not _map():
		return _fail("Could not open a neighboring campaign to check isolation.")
	_tap_joy(JOY_BUTTON_A)
	_title._invest_mara_lead_melee()
	return (_title._page == Title.Page.BRIEFING and not _button(TRAINING) and not _button(INVEST)
		and _button("Unit Progression") and _button("Combat Drills") and _button("Read Dispatch")) \
		or _fail("The Mara-only entry or action leaked into the Orc camp.")


func _open_training() -> bool:
	_tap_joy(JOY_BUTTON_A)
	if not _focused("Back"):
		return false
	await _capture("camp")
	for input: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT]:
		_tap_joy(input)
	if not _focused(TRAINING):
		return false
	_tap_key(KEY_ENTER)
	return _title._page == Title.Page.MARA_LEAD_MELEE


func _deploy_mine_at_rating(melee: int, cap: int) -> bool:
	if not _map() or not _map().select_waypoint(MINE):
		return false
	_tap_joy(JOY_BUTTON_A)
	if not _on_briefing() or _button(TRAINING) or _button("Replay with Heavy Infantry"):
		return _fail("The Mine briefing leaked training controls or enabled the untrained Shield branch.")
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	if not _focused("Confirm Deployment"):
		return false
	_tap_joy(JOY_BUTTON_A)
	var mission := _title._campaign_battle as Mission
	if not mission:
		return false
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	return (_mine_budget(mission, 1 if cap == 700 else 2, cap)
		and mission.encounter.hero.rating(Unit.Damage.MELEE) == melee
		and mission.encounter.hero.hp == Encounter.HERO_HP
		and mission.rescue_phase == Mission.Rescue.RALLY
		and mission._custody_case == null
		and mission.battle.formations[0].title == "Shield Infantry") \
		or _fail("Deployment did not apply the saved choice to Mara alone.")


func _training_state(melee: int, expected: String, can_confirm: bool) -> bool:
	var rating := _title._stage.get_node_or_null("LeadMeleeRating") as Label
	var status := _title._stage.get_node_or_null("LeadMeleeStatus") as Label
	var scope := _title._stage.get_node_or_null("LeadMeleeScope") as Label
	var viewport := root.get_visible_rect().grow(0.01)
	for node: Control in [rating, status, scope, _button("Back")]:
		if not node or not viewport.encloses(node.get_global_rect()) or node.size.x < node.get_minimum_size().x:
			return false
	return _title._page == Title.Page.MARA_LEAD_MELEE and rating.text == "Melee Power: %d" % melee \
		and status.text.contains(expected) and (_button(INVEST) != null) == can_confirm \
		and scope.text.contains("Mine replays") and scope.text.contains("level, HP, Battle Points, and mission rewards") \
		and scope.text.contains("separate from Shield Infantry Drill and Unit Progression practice")


func _focused(caption: String) -> bool:
	var owner := root.gui_get_focus_owner()
	return owner != null and owner.name == caption


func _tap_key(code: Key) -> void:
	_key(code)
	_key(code, false)


func _tap_joy(code: JoyButton) -> void:
	_joy(code)
	var release := InputEventJoypadButton.new()
	release.button_index = code
	release.pressed = false
	root.push_input(release, true)


func _capture(state: String) -> void:
	var folder := OS.get_environment("TA_LEAD_MELEE_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	for i in range(2):
		await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	var path := folder.path_join("lead-melee-%d-%s.png" % [pixels.get_width(), state])
	if pixels.save_png(path) != OK:
		push_error("Could not save " + path)
