extends SceneTree
## All live chapters retain their dedicated scenes. The development-only generic
## player still starts every explicit historical scenario and rejects unknown IDs.

const Deployments := preload("res://game/campaign_deployments.gd")
const Catalog := preload("res://game/campaign_missions.gd")
const Archive := preload("res://game/mission/missions.gd")
const Campaigns := preload("res://game/campaigns.gd")
const View := preload("res://game/mission/mission_view.tscn")

var _won := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed := true
	for invalid_id: String in ["", "unknown_generic_mission"]:
		var invalid = View.instantiate()
		invalid.mission_id = invalid_id
		var outcomes: Array[bool] = []
		invalid.mission_finished.connect(func(won: bool) -> void: outcomes.append(won))
		root.add_child(invalid)
		await physics_frame
		await physics_frame
		if invalid.battle != null or invalid.get_child_count() != 0 or not outcomes.is_empty():
			passed = _fail("An unconfigured generic view started a mission for ID %s." % [invalid_id])
		invalid.queue_free()
		await process_frame

	var registered := 0
	var archived := 0
	for campaign in Campaigns.ALL:
		for mission in Catalog.missions_for_campaign(campaign.id):
			var scene: PackedScene = Deployments.for_mission(mission.id).get("scene")
			if scene == null or scene == View:
				passed = _fail("%s did not keep its dedicated deployment scene." % mission.id)
			else:
				registered += 1
		for mission in Archive.for_campaign(campaign.id):
			var view = View.instantiate()
			view.mission_id = mission.id
			view.campaign_id = campaign.id
			root.add_child(view)
			await physics_frame
			if view.battle == null or view.battle.hero == null:
				passed = _fail("The generic view could not start %s." % mission.id)
			else:
				archived += 1
			view.queue_free()
			await process_frame
	if registered != 18 or archived != 18:
		passed = _fail("Expected 18 active dedicated scenes and 18 separate historical scenarios.")
	var view = View.instantiate()
	view.mission_id = "sereth_voices_at_the_cut"
	root.add_child(view)
	view.mission_finished.connect(func(won: bool) -> void: _won = won)
	await physics_frame
	view.battle._finish(view.battle.Outcome.VICTORY, "Test")
	view.finish(true)
	if not _won:
		passed = _fail("The generic view did not report its victory.")
	if passed:
		print("All 18 dedicated scenes stay registered; the generic view requires a known ID, starts all 18 archived scenarios explicitly, and reports victory.")
	quit(0 if passed else 1)


func _fail(message: String) -> bool:
	push_error(message)
	return false
