extends SceneTree

const Campaigns := preload("res://game/campaigns.gd")
const Missions := preload("res://game/campaign_missions.gd")
const World := preload("res://game/campaign_world.gd")
const Deployment := preload("res://game/campaign_deployments.gd")
const Beats := preload("res://game/campaign_dialogues.gd")

const EXPECTED := {
	"mara": [
		["mara_mine_escort", 1, "year_one_mine"],
		["mara_grain_crossing", 2, "marches_crossing"],
		["mara_moonwash_quay", 2, "moonwash_harbor"],
	],
	"raska": [
		["orc_mine_witness", 1, "year_one_mine"],
		["orc_well_road", 3, "red_basin_well_road"],
		["orc_spanwater_release", 4, "spanwater_lock"],
	],
	"sova": [
		["sova_mine_tunnels", 1, "year_one_mine"],
		["sova_public_record", 2, "cairnspine_vault_road"],
		["sova_vault_return", 5, "cairnspine_vault_road"],
	],
	"ilyra": [
		["ilyra_moonwash_rescue", 2, "moonwash_harbor"],
		["ilyra_coast_survey", 3, "moonwash_survey_shore"],
		["ilyra_spanwater_evacuation", 4, "spanwater_lock"],
	],
	"neris": [
		["neris_failing_grove", 3, "isolated_grove_nursery"],
		["neris_spanwater_feeder", 4, "spanwater_lock"],
		["neris_cairnspine_passage", 5, "cairnspine_vault_road"],
	],
	"sereth": [
		["sereth_voices_at_the_cut", 3, "still_kingdom_cut"],
		["sereth_pass_writ", 4, "cairnspine_boundary_post"],
		["sereth_no_proxy", 5, "cairnspine_vault_road"],
	],
}


func _initialize() -> void:
	var passed := _check_catalog() and _check_progression() and _check_isolation() and _check_deployed_routes()
	if passed:
		print("Verified all 18 authored missions and reachable deployments, campaign order, gates, replays, and unknown IDs.")
	quit(0 if passed else 1)


func _check_catalog() -> bool:
	var seen: Dictionary = {}
	var campaign_ids: Dictionary = {}
	var battlefields: Dictionary = {}
	for campaign in Campaigns.ALL:
		var campaign_id: String = campaign.id
		if not EXPECTED.has(campaign_id) or campaign_ids.has(campaign_id):
			return _fail("Unexpected or repeated campaign: " + campaign_id)
		campaign_ids[campaign_id] = true
		var expected: Array = EXPECTED[campaign_id]
		var missions := Missions.missions_for_campaign(campaign_id)
		if missions.size() != expected.size():
			return _fail("Incorrect mission count for " + campaign_id)
		for index in missions.size():
			var mission := missions[index]
			if [mission.id, mission.year, mission.battlefield_id] != expected[index]:
				return _fail("Wrong mission, year, or battlefield in " + campaign_id)
			if str(mission.title).strip_edges().is_empty() or seen.has(mission.id):
				return _fail("Blank title or duplicate mission: " + str(mission.id))
			if Missions.mission_for_campaign(campaign_id, mission.id) != mission:
				return _fail("Scoped lookup differed from the ordered catalog: " + str(mission.id))
			seen[mission.id] = true
			battlefields[mission.battlefield_id] = true
	if campaign_ids.size() != 6 or seen.size() != 18 or battlefields.size() != 10:
		return _fail("The design calls for six campaigns, 18 missions and ten layouts.")
	if not Missions.missions_for_campaign("unknown").is_empty():
		return _fail("An unknown campaign returned a mission list.")
	return true


func _check_progression() -> bool:
	for campaign_id: String in EXPECTED:
		var completed := PackedStringArray()
		var missions := Missions.missions_for_campaign(campaign_id)
		for index in missions.size():
			var id: String = missions[index].id
			if Missions.first_unplayed_mission_id(campaign_id, completed) != id:
				return _fail("Expected the first uncleared mission: " + id)
			for other_index in missions.size():
				var other_id: String = missions[other_index].id
				if Missions.is_unlocked(campaign_id, other_id, completed) != (other_index <= index):
					return _fail("Unexpected lock or replay state: " + other_id)
			var expected_successor: String = missions[index + 1].id if index + 1 < missions.size() else ""
			if Missions.successor_id(campaign_id, id) != expected_successor:
				return _fail("Wrong authored successor: " + id)
			completed.append(id)
		if not Missions.first_unplayed_mission_id(campaign_id, completed).is_empty():
			return _fail("A completed campaign suggested another mission: " + campaign_id)
		for mission in missions:
			if not Missions.is_unlocked(campaign_id, mission.id, completed):
				return _fail("A completed campaign no longer allows replay: " + campaign_id)
	return true


func _check_isolation() -> bool:
	var clears := PackedStringArray(["unknown", "orc_mine_witness", "mara_grain_crossing", "mara_grain_crossing"])
	if Missions.first_unplayed_mission_id("mara", clears) != "mara_mine_escort":
		return _fail("Stale, foreign, duplicate or out-of-order clears skipped the opening.")
	if Missions.is_unlocked("mara", "mara_grain_crossing", clears):
		return _fail("An out-of-order clear bypassed the missing opening.")
	clears.append("mara_mine_escort")
	if Missions.first_unplayed_mission_id("mara", clears) != "mara_moonwash_quay":
		return _fail("Accepted clears depended on save-list order.")
	for campaign_id in ["mara", "unknown", ""]:
		for id in ["orc_mine_witness", "unknown", ""]:
			if Missions.is_unlocked(campaign_id, id, clears):
				return _fail("A foreign or unknown mission was unlocked.")
			if not Missions.mission_for_campaign(campaign_id, id).is_empty():
				return _fail("A foreign or unknown mission returned metadata.")
			if not Missions.successor_id(campaign_id, id).is_empty():
				return _fail("A foreign or unknown mission returned a successor.")
	if not Missions.first_unplayed_mission_id("unknown", clears).is_empty():
		return _fail("An unknown campaign suggested a mission.")

	var listed := Missions.missions_for_campaign("mara")
	listed[0].title = "Edited locally"
	listed.clear()
	var looked_up := Missions.mission_for_campaign("mara", "mara_mine_escort")
	looked_up.year = 5
	var fresh := Missions.missions_for_campaign("mara")
	if fresh.size() != 3 or fresh[0].title == "Edited locally" or fresh[0].year != 1:
		return _fail("A caller mutated the authored catalog.")
	return true


func _check_deployed_routes() -> bool:
	var deployed := {}
	for campaign_id: String in EXPECTED:
		var world := World.new(campaign_id)
		var waypoints := {}
		for waypoint in world.waypoints():
			if waypoint.kind != World.WaypointKind.BATTLEFIELD:
				if waypoint.has("mission_id"):
					return _fail("Non-battle waypoint offered a hidden deployment: " + waypoint.id)
				continue
			var id: String = waypoint.mission_id
			if waypoints.has(id) or Missions.mission_for_campaign(campaign_id, id).is_empty():
				return _fail("Battlefield waypoint lacks its own unique campaign mission: " + id)
			waypoints[id] = waypoint.id
		var clears := PackedStringArray()
		for mission in Missions.missions_for_campaign(campaign_id):
			var id: String = mission.id
			var waypoint: String = waypoints.get(id, "")
			if not world.is_waypoint_reachable(waypoint, clears):
				return _fail("No reachable deployment after prerequisite clears: " + id)
			if not clears.is_empty():
				var before_last := clears.slice(0, clears.size() - 1)
				if world.is_waypoint_reachable(waypoint, before_last):
					return _fail("Reached later deployment before its previous mission cleared: " + id)
			var entry := Deployment.for_mission(id)
			var scene := entry.get("scene") as PackedScene
			if not scene or not scene.can_instantiate() or Beats.get_beat(entry.get("dispatch", &"")).is_empty():
				return _fail("Deployment or dispatch is missing for " + id)
			var carries_result: bool = entry.get("result_debrief", false)
			var actor := scene.instantiate()
			var has_outcome := actor.has_signal(&"mission_cleared" if carries_result else &"mission_finished")
			actor.free()
			if not has_outcome or (not carries_result and Beats.get_beat(entry.get("debrief", &"")).is_empty()):
				return _fail("Deployment lacks a clear signal or debrief: " + id)
			clears.append(id)
			deployed[id] = true
	return (deployed.size() == 18 and Deployment._DEPLOYMENTS.size() == deployed.size()) \
		or _fail("Expected exactly 18 reachable registered deployments.")


func _fail(message: String) -> bool:
	push_error(message)
	return false
