extends SceneTree
## Exercise the normal title deployment, not editor playtests.
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Campaigns := preload("res://game/campaigns.gd")
const Missions := preload("res://game/campaign_missions.gd")
const World := preload("res://game/campaign_world.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")

var failures := 0
var deployed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		printerr("HUD FAIL: ", detail)
	return condition


func _run() -> void:
	for campaign: Dictionary in Campaigns.ALL:
		var id: String = campaign.id
		var save := "user://test-campaign-hud-%d-%s.cfg" % [OS.get_process_id(), id]
		var profile := Profile.new(save)
		profile.set_setting("fullscreen", false)
		profile.set_setting("reduced_motion", true)
		profile.mark_played(id)
		var title := TitleScene.instantiate() as Title
		title._profile = profile
		root.add_child(title)
		await process_frame
		var catalog := World.new(id)
		for row: Dictionary in Missions.missions_for_campaign(id):
			var waypoint := ""
			for point: Dictionary in catalog.waypoints():
				if point.get("mission_id") == row.id:
					waypoint = point.id
					break
			var clears := profile.completed_missions(id)
			title._active_campaign = campaign
			title._campaign_world = World.new(id, waypoint, clears)
			title._show_campaign_mission_briefing(row.id)
			var confirmation: Button
			for button: Node in title._stage.find_children("*", "Button", true, false):
				if button.text == "Confirm Deployment":
					confirmation = button
					break
			if _check(is_instance_valid(confirmation), row.id + " briefing deploy button"):
				confirmation.pressed.emit()
				var mission := title._campaign_battle as Harness
				if _check(is_instance_valid(mission), row.id + " actual registered launch"):
					deployed += 1
					await physics_frame
					await process_frame
					_check(is_instance_valid(mission._mission_hud) and mission._mission_hud.is_visible_in_tree(), row.id + " shared HUD mounted")
					_check(not mission.get_node("HUD/Panel").is_visible_in_tree(), row.id + " old command panel hidden")
					var data := mission._mission_hud_state()
					_check(data.roster.size() >= 1 and data.roster[0].name == campaign.name, row.id + " lead roster name")
					_check(data.roster.size() >= 1 and data.roster[0].selected,
						row.id + " hero selected at deployment")
					if mission.battle.lead_platoon_enabled:
						_check(mission.selected_index == Battle.LEAD_INDEX and mission._marker_owner == Battle.LEAD_INDEX,
							row.id + " initial march marker belongs to the hero’s platoon")
					else:
						_check(row.id == "neris_cairnspine_survey" and mission.hero_combat_active(),
							row.id + " solo scout starts under direct control")
					_check(String(data.get("objective", "")).strip_edges() != "", row.id + " live objective text")
					_check(title._stage.get_node_or_null("PauseBattle") == null, row.id + " old pause card removed")
					if row.id == "mara_mine_escort":
						_check(data.bp == 400 and data.bp_max == 700 and data.hero_hp > 0, "Greyhollow live resource and hero values")
					title._pause_game()
					_check(paused and title._pause_menu.layer > 1, row.id + " pause overlays active HUD")
					title._pause_menu.close()
					_check(not paused, row.id + " resume")
					title._return_from_campaign_battle()
					_check(title._campaign_battle == null and profile.completed_missions(id) == clears,
						row.id + " leaving retains neither an unearned clear nor the HUD")
			_check(_seed_test_clear(profile, id, row.id) == OK, row.id + " seed only the next test scenario")
			await process_frame
		root.remove_child(title)
		title.queue_free()
		await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	_check(deployed == 18, "all 18 authored campaign missions used the new HUD")
	print("Campaign HUD: %d ordinary deployments, %d failures." % [deployed, failures])
	quit(1 if failures else 0)


func _seed_test_clear(profile: Profile, campaign: String, mission: String) -> Error:
	match mission:
		"mara_grain_crossing":
			return profile.record_grain_clear(&"both")
		"ilyra_moonwash_rescue":
			return profile.record_ilyra_moonwash_clear(&"crews_only")
		_:
			return profile.record_mission_clear(campaign, mission)
