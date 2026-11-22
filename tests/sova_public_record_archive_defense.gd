extends SceneTree
## Play the generic legacy archive with real orders; the authored hearing is
## exercised separately by sova_public_record_playtest.gd and is not changed.
const Battle := preload("res://game/mission/mission_battle.gd")
const Missions := preload("res://game/mission/missions.gd")
const Pilot := preload("res://tests/mission_autopilot.gd")
const PlatoonSize := preload("res://game/combat/platoon_size.gd")
const SPOILERS := ["spoilers_shelf", "spoilers_east", "spoilers_exit", "spoilers_last"]
const OTHER := {"callers": 10, "scribes": 6}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var site := "dais" if args.has("dais") else "recess"
	var seed_value := hash("sova_public_record") if args.has("view_seed") else (int(args[1]) if args.size() > 1 else 11)
	var battle := Battle.new(Missions.find("sova_public_record"), &"sova", 9, {}, seed_value)
	var pilot := Pilot.new(battle)
	while battle.outcome == Battle.Outcome.LIVE and battle.elapsed < 320.0:
		pilot.drive()
		if site == "dais" and battle.objective("lectern").status == "active":
			_choose_open_dais(battle, pilot)
		battle.step(1.0 / 30.0)
	var passed: bool = battle.outcome == Battle.Outcome.VICTORY and battle.flags.has(site) \
		and battle.objective("passages").status == "done" and battle.objective("record").status == "done"
	var slain := PackedStringArray()
	for id in SPOILERS:
		var hostile := battle.squad(id)
		passed = passed and hostile.spawned and hostile.members.size() == PlatoonSize.PLATOON_WITH_LEADER
		slain.append("%s:%d/%d" % [id, hostile.members.size() - hostile.alive_count(battle), hostile.members.size()])
	for id in ["wardens", "valley", "keepers"]:
		passed = passed and battle.squad(id).members.size() == PlatoonSize.PLATOON_WITH_LEADER
	# Neutral departing Keepers are individuals, not enemies; the pilot cannot
	# issue orders to them or witness/civilian squads.
	passed = passed and battle.squad("keepers").team == Battle.NEUTRAL_TEAM and battle.squad("keepers").departed
	for id in OTHER:
		passed = passed and battle.squad(id).members.size() == OTHER[id]
	var surviving_scribes := battle.squad("scribes").alive_count(battle)
	passed = passed and surviving_scribes > 0
	print("SOVA ARCHIVE HEARING %s · %s seed %d, %.1fs, scribes=%d/6, losses=%d, waves=%s · %s" %
		["PASS" if passed else "FAIL", site, seed_value, battle.elapsed, surviving_scribes, battle.player_losses, " ".join(slain),
			battle.outcome_reason])
	quit(0 if passed else 1)


func _choose_open_dais(battle: Battle, pilot: Pilot) -> void:
	var entry := battle.active_interactable()
	if entry >= 0 and battle.interactables[entry].id == "choose_dais":
		battle.set_hero_input({"interact": true})
		return
	for point in battle.interactables:
		if point.id == "choose_dais":
			battle.set_hero_input({"move": pilot._steer(battle.hero.position, point.pos)})
			return
