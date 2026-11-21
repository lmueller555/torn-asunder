extends SceneTree
## Every catalog mission resolves to a deployment, and the generic mission view (the
## fallback for missions without a dedicated battlefield script) starts each mission
## and reports a victory through mission_finished.

const Deployments := preload("res://game/campaign_deployments.gd")
const Catalog := preload("res://game/campaign_missions.gd")
const Campaigns := preload("res://game/campaigns.gd")
const View := preload("res://game/mission/mission_view.tscn")

var _won := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed := true
	for campaign in Campaigns.ALL:
		for mission in Catalog.missions_for_campaign(campaign.id):
			if Deployments.for_mission(mission.id).get("scene") == null:
				passed = _fail("%s has no deployment scene." % mission.id)
			var view = View.instantiate()
			view.mission_id = mission.id
			view.campaign_id = campaign.id
			root.add_child(view)
			await physics_frame
			if view.battle == null or view.battle.hero == null:
				passed = _fail("The generic view could not start %s." % mission.id)
			view.queue_free()
			await process_frame
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
		print("Every catalog mission deploys, and the generic view starts all 18 and reports victory.")
	quit(0 if passed else 1)


func _fail(message: String) -> bool:
	push_error(message)
	return false
