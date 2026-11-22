extends "res://tests/mara_campaign_flow.gd"
## An actual rescue uses the live title/save path. Only the legacy fixture seeds
## a clear directly, because it represents a pre-Greyhollow profile.


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-greyhollow-reveal-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	var rescue_path := _profile_path
	var profile := Profile.new(rescue_path)
	var configured := profile.set_setting("fullscreen", false) == OK \
		and profile.set_setting("reduced_motion", true) == OK
	var passed := configured and await _interrupt_real_rescue_reveal()
	if passed:
		passed = await _legacy_escort_clear_does_not_start_reveal(rescue_path + ".legacy")
	if _title:
		_title.queue_free()
	await process_frame
	for path: String in [rescue_path, rescue_path + ".tmp", rescue_path + ".legacy", rescue_path + ".legacy.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Greyhollow reveal: real rescue, interrupted cinematic, stored Continue, explicit Skip, and compatible legacy clear passed.")
	quit(0 if passed else 1)


func _interrupt_real_rescue_reveal() -> bool:
	await _reopen_title()
	CampaignFlow.resume_at_map(_title, "mara")
	if not _on_map(CAMP):
		return _fail("Could not start Mara with a fresh profile.")
	_map().select_waypoint(MINE)
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("Could not deploy the real Greyhollow rescue.")
	var mission := _title._campaign_battle as Mission
	if not mission:
		return _fail("The Human campaign did not deploy the rescue.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_rescue():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR_ID]) \
			or _saved_world() != MINE:
		return _fail("The actual rescue did not persist the stable clear and start the shelter reveal.")
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not dialogue or dialogue._line_index != 2 or not _no_pre_rescue_reveal(dialogue):
		return _fail("Could not interrupt the real cinematic before the Godbridle is named.")
	# Tear down the title (without emitting dialogue completed/cancelled) and
	# reload with a distinct store to reproduce closing and reopening the game.
	await _reopen_title()
	if not _press("Continue") or not _is_dialogue(Beats.MARA_MINE_DEBRIEF):
		return _fail("Continue bypassed the interrupted Greyhollow reveal even though the rescue clear persisted.")
	dialogue = _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not dialogue or not dialogue._cinematic or dialogue._back_button.text != "Skip Scene":
		return _fail("Continue did not restore the actual skippable shelter cinematic.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or _saved_clears() != PackedStringArray([CLEAR_ID]) or _saved_world() != MINE:
		return _fail("Explicit Skip did not return to the arrived Mine with the original clear intact.")
	await _reopen_title()
	return (_press("Continue") and _on_map(MINE) and not _is_dialogue(Beats.MARA_MINE_DEBRIEF) \
		and _saved_clears() == PackedStringArray([CLEAR_ID])) \
		or _fail("Explicit Skip did not resolve the pending reveal on disk.")


func _legacy_escort_clear_does_not_start_reveal(path: String) -> bool:
	_profile_path = path
	var legacy := Profile.new(path)
	if legacy.set_setting("fullscreen", false) != OK or legacy.set_setting("reduced_motion", true) != OK \
			or legacy.mark_played("mara") != OK or legacy.record_mission_clear("mara", CLEAR_ID) != OK:
		return _fail("Could not create the old escort progress fixture.")
	var world := legacy.load_campaign_world("mara")
	world.travel_to(MINE, legacy.completed_missions("mara"))
	if legacy.record_world_waypoint(world) != OK:
		return _fail("Could not place the old escort profile at the Mine.")
	await _reopen_title()
	return (_press("Continue") and _on_map(MINE) and not _is_dialogue(Beats.MARA_MINE_DEBRIEF) \
		and _saved_clears() == PackedStringArray([CLEAR_ID])) \
		or _fail("A legacy escort clear incorrectly queues the new rescue reveal.")


func _reopen_title() -> void:
	if _title:
		root.remove_child(_title)
		_title.queue_free()
		await process_frame
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	root.add_child(_title)
	await process_frame
