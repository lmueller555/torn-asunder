extends SceneTree

const Aggro := preload("res://game/combat/enemy_aggro.gd")
const Battle := preload("res://game/mission/mission_battle.gd")
const Arena := preload("res://game/combat/infantry_skirmish.gd")
const Missions := preload("res://game/mission/missions.gd")

var failures := PackedStringArray()

func _initialize() -> void:
	check(Aggro.RADIUS_METRES==50.0 and Aggro.configured(8.0)==50.0 and Aggro.configured(0.0)==0.0,"exact enabled radius and explicit off")
	check(_try_at(49.9)== "hunt","49.9 m acquires")
	check(_try_at(50.0)== "hunt","50 m acquires")
	check(_try_at(50.1)== "hold","50.1 m does not acquire")
	check(_try_at(32.0,12.0,true)== "hold","terrain occlusion blocks proximity aggression")
	check(_try_at(32.0,12.0,true,"hold","water")== "hunt","water blocks walking, not sight")
	check(_try_at(40.0,0.0)== "hold","disabled group does not acquire")
	check(_try_at(40.0,0.0,false,"hunt")== "hunt","explicit authored hunt is not reset")
	var scenario := Missions.find("mara_mine_escort")
	var scaled := false
	for group: Dictionary in scenario.platoons:
		if group.has("aggro") and group.aggro==50.0:
			scaled=true
	check(scaled,"mission-space geometry scaling never multiplies aggro")
	_check_arena()
	for failure in failures:
		printerr(failure)
	print("Enemy aggro exact distance, occlusion, script opt-out and arena checked; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func _try_at(distance: float, configured := 12.0, cover := false, kind := "hold", obstacle_type := "wall") -> String:
	var terrain: Array[Dictionary] = []
	if cover:
		terrain.append({"kind":obstacle_type,"rect":Rect2(Vector2(15,-6),Vector2(3,12))})
	var rules := {"map":{"size":Vector2(240,240),"obstacles":terrain},
		"hero":{"pos":Vector2(distance,0)},"platoons":[{"id":"sentry","type":&"march_levy","team":1,
			"level":2,"count":32,"columns":8,"pos":Vector2.ZERO,"aggro":configured,"order":{"kind":kind}}]}
	var battle := Battle.new(rules,&"mara",1)
	var squad := battle.squads[0]
	battle.step(1.0/60.0)
	return squad.order.kind

func _check_arena() -> void:
	var arena := Arena.new()
	var seeker := arena.soldiers[0]
	seeker.position=Vector2.ZERO
	for i in range(arena.team_size(0),arena.soldiers.size()):
		arena.soldiers[i].position=Vector2(60.0,0.0)
	var foe := arena.soldiers[arena.team_size(0)]
	foe.position=Vector2(50.1,0.0)
	arena._scan_for_enemy(0)
	check(seeker.pursuit<0,"skirmish does not start pursuit beyond 50 m")
	foe.position=Vector2(50.0,0.0)
	arena._scan_for_enemy(0)
	check(seeker.pursuit==foe.battle_index and seeker.approach<0 and seeker.target<0,
		"skirmish detects at 50 m without immediate assault")
	check(Arena.ATTACK_RANGE<2.0 and Arena.ENGAGEMENT_RANGE==5.0,"melee combat contact distances are unchanged")

func check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
