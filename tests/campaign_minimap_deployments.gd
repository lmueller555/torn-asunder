extends SceneTree
## Exercise the normal title deployment, not editor playtests.
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Campaigns := preload("res://game/campaigns.gd")
const Missions := preload("res://game/campaign_missions.gd")
const World := preload("res://game/campaign_world.gd")
const BattlefieldMap := preload("res://game/battlefield/battlefield_minimap.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")

var failures := 0
var deployed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		printerr("MAP FAIL: ", detail)
	return condition


func _run() -> void:
	for campaign: Dictionary in Campaigns.ALL:
		var id: String = campaign.id
		var save := "user://test-campaign-minimap-%d-%s.cfg" % [OS.get_process_id(), id]
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
					var visible_charts: Array[BattlefieldMap] = []
					for chart: Node in mission.find_children("*", "Control", true, false):
						if chart.get_script() == BattlefieldMap and chart.tactical_style and chart.is_visible_in_tree():
							visible_charts.append(chart as BattlefieldMap)
					if _check(visible_charts.size() == 1, row.id + " one tactical minimap (got %d)" % visible_charts.size()):
						var chart := visible_charts[0]
						var pos := chart.get_global_rect()
						_check(chart.terrain_texture != null and chart.map_rect().has_area(), row.id + " chart uses terrain and valid projection")
						_check(chart.size.is_equal_approx(BattlefieldMap.TACTICAL_COMPACT_SIZE),
							row.id + " compact on entry: %s" % chart.size)
						_press(KEY_SHIFT, true)
						_key(KEY_N)
						await process_frame
						await process_frame
						_check(chart.size.is_equal_approx(BattlefieldMap.TACTICAL_EXPANDED_SIZE),
							row.id + " keyboard opens tactical size: %s" % chart.size)
						_check(is_equal_approx(chart.get_global_rect().end.x, pos.end.x)
							and is_equal_approx(chart.get_global_rect().position.y, pos.position.y),
							row.id + " aligned to same upper-right anchor")
						_key(KEY_N)
						await process_frame
						await process_frame
						_check(chart.size.is_equal_approx(BattlefieldMap.TACTICAL_COMPACT_SIZE),
							row.id + " keyboard returns to compact")
						_press(KEY_SHIFT, false)

					_check(mission._mission_hud != null, row.id + " tactical map shares the approved HUD layout")
					title._pause_game()
					_check(paused and title._pause_menu.layer > 1, row.id + " pause overlays active map")
					title._pause_menu.close()
					_check(not paused, row.id + " resume")
					title._return_from_campaign_battle()
					_check(title._campaign_battle == null and profile.completed_missions(id) == clears,
						row.id + " leaving retains neither an unearned clear nor the map")
			_check(_seed_test_clear(profile, id, row.id) == OK, row.id + " seed only the next test scenario")
			await process_frame
		root.remove_child(title)
		title.queue_free()
		await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	_check(deployed == 18, "all 18 authored campaign missions used the new map")
	print("Campaign minimap: %d ordinary deployments, %d failures." % [deployed, failures])
	quit(1 if failures else 0)


func _seed_test_clear(profile: Profile, campaign: String, mission: String) -> Error:
	match mission:
		"mara_grain_crossing":
			return profile.record_grain_clear(&"both")
		"ilyra_moonwash_rescue":
			return profile.record_ilyra_moonwash_clear(&"crews_only")
		_:
			return profile.record_mission_clear(campaign, mission)


func _key(code: Key) -> void:
	_press(code, true)
	_press(code, false)


func _press(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	root.push_input(event)
