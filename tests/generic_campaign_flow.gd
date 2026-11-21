extends SceneTree
## Plays the Undead campaign's first mission through the title screen, overworld, generic
## mission view and debrief, and checks that the clear opens the next route.

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Campaigns := preload("res://game/campaigns.gd")
const Deployments := preload("res://game/campaign_deployments.gd")
const Missions := preload("res://game/campaign_missions.gd")

var _title: Title
var _path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-generic-flow-%d.cfg" % Time.get_ticks_usec())
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_path)
	_title._profile.set_setting("fullscreen", false)
	_title._profile.set_setting("reduced_motion", true)
	root.add_child(_title)
	await process_frame
	var passed := await _flow()
	_title.queue_free()
	await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("The Undead campaign travels, deploys, clears and opens its next route through the generic mission view.")
	quit(0 if passed else 1)


func _flow() -> bool:
	for campaign in Campaigns.ALL:
		for mission in Missions.missions_for_campaign(campaign.id):
			var deployment := Deployments.for_mission(mission.id)
			if deployment.is_empty() or not deployment.has("scene"):
				return _fail("%s has no deployment." % mission.id)
	var sereth: Dictionary = Campaigns.ALL.filter(func(c: Dictionary) -> bool: return c.id == "sereth")[0]
	_title._open_campaign(sereth)
	if _title._page != Title.Page.WORLD_MAP or _title._campaign_world.current_waypoint_id() != "still_court":
		return _fail("The Undead campaign did not open at the Still Court on the overworld.")
	var clears := _title._profile.completed_missions("sereth")
	if _title._campaign_world.travel_to("still_kingdom_cut", clears) != _title._campaign_world.TravelResult.ARRIVED:
		return _fail("The court could not travel to the cut.")
	_title._show_campaign_mission_briefing("sereth_voices_at_the_cut")
	if _title._page != Title.Page.MISSION_BRIEFING:
		return _fail("The cut did not offer its briefing.")
	_title._deploy_campaign_mission("sereth_voices_at_the_cut")
	await process_frame
	var view = _title._campaign_battle
	if view == null or view.get("mission_id") != "sereth_voices_at_the_cut" or view.battle == null:
		return _fail("Deployment did not start the generic mission view.")
	for i in range(30):
		await physics_frame
	view.battle._finish(view.battle.Outcome.VICTORY, "Test victory")
	view.finish(true)
	await process_frame
	await process_frame
	if not _title._profile.completed_missions("sereth").has("sereth_voices_at_the_cut"):
		return _fail("The victory did not save the mission clear.")
	if _title._page != Title.Page.CAMPAIGN_DIALOGUE:
		return _fail("The victory did not present the debrief.")
	for i in range(20):
		if _title._page != Title.Page.CAMPAIGN_DIALOGUE:
			break
		for child in _title._stage.get_children():
			if child.has_method("advance"):
				child.advance()
		await process_frame
	if _title._page != Title.Page.WORLD_MAP:
		return _fail("The debrief did not return to the overworld.")
	var options: Array[Dictionary] = _title._campaign_world.route_options(_title._profile.completed_missions("sereth"))
	if not options.has({"waypoint_id": "court_chambers", "required_clear_id": "sereth_voices_at_the_cut", "is_open": true}):
		return _fail("The clear did not open the route to the court chambers.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
