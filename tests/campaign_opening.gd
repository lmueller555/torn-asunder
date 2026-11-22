extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Campaigns := preload("res://game/campaigns.gd")
const Missions := preload("res://game/campaign_missions.gd")
const Deployments := preload("res://game/campaign_deployments.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Profile := preload("res://game/profile_store.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const PauseTest := preload("res://tests/pause_test_helpers.gd")

var _title: Title
var _path := "user://test-campaign-opening-%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_path)
	_title._profile.set_setting("fullscreen", false)
	root.add_child(_title)
	var passed := await _verify()
	_title.queue_free()
	await process_frame
	for file in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	if passed:
		print("Verified all six openings, direct deployment, skipping, and returning to a saved campaign.")
	quit(0 if passed else 1)


func _verify() -> bool:
	for index in Campaigns.ALL.size():
		var campaign := Campaigns.ALL[index]
		var mission_id := Missions.first_unplayed_mission_id(campaign.id, PackedStringArray())
		var deployment := Deployments.for_mission(mission_id)
		if not _press("New Game"):
			return _fail("Could not open New Game.")
		if index == 0:
			_title._portraits[index].grab_focus()
			if not _press("Begin Campaign"):
				return _fail("Could not select a campaign from Begin Campaign.")
		elif not _press(campaign.id):
			return _fail("Could not select %s from its portrait." % campaign.id)
		var dialogue := _title._stage.get_child(0) as Dialogue
		if _title._page != Title.Page.CAMPAIGN_DIALOGUE or _title._campaign_battle or not dialogue \
				or dialogue._beat_id != deployment.dispatch:
			return _fail("%s did not start in its opening scene." % campaign.id)
		if index % 2 == 0:
			while _title._page == Title.Page.CAMPAIGN_DIALOGUE:
				dialogue.advance()
		elif not _press("BackButton"):
			return _fail("%s had no Skip Scene button." % campaign.id)
		var saved := Profile.new(_path)
		var expected_scene: PackedScene = deployment.scene
		if _title._page != Title.Page.CAMPAIGN_BATTLE or not _title._campaign_battle \
				or _title._campaign_battle.scene_file_path != expected_scene.resource_path \
				or saved.load_campaign_world(campaign.id).mission_at_current_waypoint() != mission_id \
				or not saved.completed_missions(campaign.id).is_empty():
			return _fail("%s did not deploy at the correct opening waypoint without a clear." % campaign.id)
		var harness := _title._campaign_battle as Harness
		if not harness or harness.selected_index != Battle.LEAD_INDEX:
			return _fail("%s did not start with the hero’s platoon selected." % campaign.id)
		if not PauseTest.leave_battle(_title) or _title._page != Title.Page.WORLD_MAP:
			return _fail("%s did not return to its map after abandoning the opening." % campaign.id)
		_title._show_title()
		await process_frame
	var mara := _title._profile
	if mara.record_mission_clear("mara", "mara_mine_escort") != OK:
		return _fail("Could not seed Mara's earlier clear.")
	var world := mara.load_campaign_world("mara")
	world.travel_to("marches_road", mara.completed_missions("mara"))
	if mara.record_world_waypoint(world) != OK:
		return _fail("Could not seed a later waypoint.")
	if not _press("New Game") or not _press("mara") or not _press("BackButton"):
		return _fail("Mara's opening could not be replayed.")
	if _title._campaign_world.mission_at_current_waypoint() != "mara_mine_escort" \
			or Profile.new(_path).load_campaign_world("mara").current_waypoint_id() != "marches_road":
		return _fail("An opening replay overwrote the saved waypoint.")
	if not PauseTest.leave_battle(_title) or _title._campaign_world.current_waypoint_id() != "marches_road":
		return _fail("Leaving the replay did not restore the saved waypoint.")
	_title._show_title()
	if not _press("New Game") or not _press("mara") or not _press("BackButton"):
		return _fail("Could not reopen the Mine for a completed replay.")
	_title._campaign_battle.emit_signal(&"mission_finished", true)
	await process_frame
	if _title._page != Title.Page.CAMPAIGN_DIALOGUE or not _press("BackButton") \
			or _title._campaign_world.current_waypoint_id() != "marches_road":
		return _fail("The opening debrief did not return to the saved route.")
	_title._show_title()
	if not _press("Continue") or _title._page != Title.Page.WORLD_MAP \
			or _title._campaign_world.current_waypoint_id() != "marches_road":
		return _fail("Continue replayed the opening instead of resuming the save.")
	_title._show_title()
	if not _press("Load"):
		return _fail("Could not open the Load menu.")
	var entry := _title.get_viewport().gui_get_focus_owner() as Button
	if not entry or not entry.text.contains("Mara"):
		return _fail("The Load menu did not offer Mara's active save.")
	entry.pressed.emit()
	return (_title._page == Title.Page.WORLD_MAP \
		and _title._campaign_world.current_waypoint_id() == "marches_road") \
		or _fail("Load replayed the opening instead of resuming the save.")


func _press(name: String) -> bool:
	var button := _title._stage.find_child(name, true, false) as Button
	if not button or button.disabled or not button.is_visible_in_tree():
		return false
	button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
