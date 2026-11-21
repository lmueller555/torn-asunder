extends SceneTree
## Drives the standalone archive through every scenario. Live Godot campaign deployments have their own full-flow tests.
##
## Usage: godot --headless --script tests/mission_playthrough.gd [mission_id ...]

const Battle := preload("res://game/mission/mission_battle.gd")
const Missions := preload("res://game/mission/missions.gd")
const Campaigns := preload("res://game/campaigns.gd")
const Autopilot := preload("res://tests/mission_autopilot.gd")

const TICK := 1.0 / 30.0
const LIMIT := 900.0


func _initialize() -> void:
	var only := []
	for arg in OS.get_cmdline_user_args():
		only.append(arg)
	var passed := true
	var results := []
	for campaign in Campaigns.ALL:
		var missions := Missions.for_campaign(campaign.id)
		if missions.size() != 3:
			printerr("%s has %d historical scenarios instead of 3." % [campaign.id, missions.size()])
			passed = false
		for mission: Dictionary in missions:
			if not only.is_empty() and not only.has(mission.id):
				continue
			var battle := Battle.new(mission, StringName(campaign.id), mission.hero_level)
			var pilot := Autopilot.new(battle)
			while battle.outcome == Battle.Outcome.LIVE and battle.elapsed < LIMIT:
				pilot.drive()
				battle.step(TICK)
			var won := battle.outcome == Battle.Outcome.VICTORY
			var hero_hp := battle.hero.unit.hp / battle.hero.unit.max_hp
			var line := "%-10s %-34s %-8s %5.0fs  hero %3.0f%%  losses %3d  enemy losses %3d  %s" % [
				mission.id, mission.title, "WON" if won else "LOST", battle.elapsed, hero_hp * 100.0,
				battle.player_losses, battle.enemy_losses, battle.outcome_reason,
			]
			print(line)
			results.append(won)
			if not won:
				passed = false
				for item in battle.objectives:
					print("    %-8s %s" % [item.status, item.text])
	if only.is_empty() and results.size() != 18:
		passed = false
	print("%d of %d archived scenarios won by the autopilot." % [results.count(true), results.size()])
	quit(0 if passed else 1)
