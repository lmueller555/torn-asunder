extends SceneTree

const Progress := preload("res://game/combat/campaign_platoon_progress.gd")
const Missions := preload("res://game/campaign_missions.gd")

var _failures := 0


func _initialize() -> void:
	for faction in ["mara", "raska", "sova", "ilyra", "neris", "sereth"]:
		var chapters := Missions.missions_for_campaign(faction)
		var start := Progress.inspect(faction, [])
		_check(start.campaign_id == faction and start.confirmed_chapters == 0 and start.lead_level == 1
				and start.next_mission_bp == 400 and start.next_mission_capacity == 700,
				"Each of the six campaigns starts its own 400/700 Level 1 pool.")
		var first: String = chapters[0].id
		var second: String = chapters[1].id
		var last: String = chapters[2].id
		var foreign_only := Progress.inspect(faction, ["unknown", last])
		_check(foreign_only.total_xp == 0 and foreign_only.lead_level == 1,
				"An unknown or out-of-order clear cannot skip prerequisites.")
		var first_clear := Progress.inspect(faction, [last, first, first, "unknown"])
		_check(first_clear.confirmed_chapters == 1 and first_clear.total_xp == 100
				and first_clear.lead_level == 2 and first_clear.next_mission_bp == 400
				and first_clear.next_mission_capacity == 720,
				"First clear advances once; duplicate replay or a later clear cannot farm points.")
		var full := Progress.inspect(faction, [last, first, second, first, last])
		_check(full.confirmed_chapters == 3 and full.total_xp == 300 and full.lead_level == 3
				and full.xp_in_level == 75 and full.next_level_xp == 150 and full.next_mission_capacity == 740,
				"Three confirmed chapters reuse the existing XP and Battle Points curves.")
		full.lead_level = 47
		_check(Progress.inspect(faction, [first, second, last]).lead_level == 3,
				"Caller changes to an inspection detach from the saved facts.")
	_check(Progress.inspect("not_a_campaign", []) == null, "Unknown campaigns return no progression plan.")
	if _failures == 0:
		print("Campaign platoon progression: all six sets, first-clear XP, replay/gaps, level growth and 400/700 +20 BP passed.")
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
