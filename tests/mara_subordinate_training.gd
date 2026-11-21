extends SceneTree

const Training := preload("res://game/combat/mara_subordinate_training.gd")
const Progress := preload("res://game/combat/campaign_platoon_progress.gd")
const Allocation := preload("res://game/combat/campaign_stat_allocation.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

const SLOT := Training.SHIELD_INFANTRY_SLOT
const OTHER_SLOT := &"mara_archers"
const HEAVY := Catalog.HUMAN_HEAVY_INFANTRY
const REGULAR := Catalog.HUMAN_INFANTRY
const MINE := "mara_mine_escort"
const GRAIN := "mara_grain_crossing"
const QUAY := "mara_moonwash_quay"

var _failures := 0


func _initialize() -> void:
	_check_scope()
	_check_training()
	_check_lead_and_bp()
	_check_skirmish_rule()
	if _failures == 0:
		print("Mara subordinate training: fixed slot, one Mine clear credit, drill rank 1→2, optional Heavy eligibility and unchanged lead/BP passed.")
	quit(0 if _failures == 0 else 1)


func _check_scope() -> void:
	for facts in [[], ["unknown"], ["orc_mine_witness", "sova_mine_tunnels"], [GRAIN, QUAY, GRAIN]]:
		var locked := Training.new("mara", PackedStringArray(facts))
		_check(locked.available_drill_credit(SLOT) == 0 and locked.formation_drill_rank(SLOT) == 1
			and locked.default_unit_type(SLOT) == REGULAR and not locked.train_formation_drill(SLOT)
			and not locked.qualifies_for_branch(SLOT, HEAVY), "No Mine clear must leave an untrained ordinary Shield Infantry slot.")
	for campaign_id in ["raska", "sova", "unknown", ""]:
		var foreign := Training.new(campaign_id, [MINE])
		_check(foreign.available_drill_credit(SLOT) == 0 and foreign.formation_drill_rank(SLOT) == 0
			and foreign.default_unit_type(SLOT) == &"" and not foreign.train_formation_drill(SLOT)
			and not foreign.qualifies_for_branch(SLOT, HEAVY), "Foreign or unknown campaign cannot consume the Human credit.")


func _check_training() -> void:
	var replay := Training.new("mara", [QUAY, GRAIN, MINE, MINE, MINE, "unknown", "orc_mine_witness"])
	_check(replay.available_drill_credit(SLOT) == 1 and replay.formation_drill_rank(SLOT) == 1
		and replay.default_unit_type(SLOT) == REGULAR and not replay.qualifies_for_branch(SLOT, HEAVY),
		"One known clear earns exactly one local credit, with no free rank or promotion.")
	for slot: StringName in [OTHER_SLOT, &"other_shield_infantry", &""]:
		_check(replay.available_drill_credit(slot) == 0 and replay.formation_drill_rank(slot) == 0
			and replay.default_unit_type(slot) == &"" and not replay.train_formation_drill(slot)
			and not replay.qualifies_for_branch(slot, HEAVY), "No credit/qualification can leak to another slot.")
	_check(replay.train_formation_drill(SLOT) and replay.available_drill_credit(SLOT) == 0
		and replay.formation_drill_rank(SLOT) == 2 and replay.qualifies_for_branch(SLOT, HEAVY),
		"The slot's own credit advances Formation Drill from rank 1 to 2 and qualifies for Heavy.")
	_check(not replay.train_formation_drill(SLOT) and replay.available_drill_credit(SLOT) == 0
		and replay.formation_drill_rank(SLOT) == 2 and replay.default_unit_type(SLOT) == REGULAR,
		"Repeat purchase cannot advance another rank and qualification does not equip.")
	for target: StringName in [REGULAR, Catalog.HUMAN_ARCHER, Catalog.ORC_BRACE_INFANTRY, &""]:
		_check(not replay.qualifies_for_branch(SLOT, target), "Only the named Human Heavy branch qualifies.")
	var separate := Training.new("mara", [MINE])
	_check(separate.formation_drill_rank(SLOT) == 1 and separate.available_drill_credit(SLOT) == 1
		and not separate.qualifies_for_branch(SLOT, HEAVY), "The local model cannot change other plans or the catalog.")


func _check_lead_and_bp() -> void:
	var chapters := [[], [MINE], [MINE, GRAIN], [MINE, GRAIN, QUAY]]
	var levels := [1, 2, 2, 3]
	var remaining_xp := [0, 0, 100, 75]
	var next_xp := [100, 125, 125, 150]
	var capacities := [700, 720, 720, 740]
	for stage in range(chapters.size()):
		var clears := PackedStringArray(chapters[stage])
		var draft := Training.new("mara", clears)
		var allocation := Allocation.new("mara", clears)
		_check(draft.available_drill_credit(SLOT) == mini(1, stage), "Exactly one credit at all stages after first clear.")
		_check(draft.train_formation_drill(SLOT) == (stage != 0), "Only the cleared stages can spend the subordinate credit.")
		var lead := Progress.inspect("mara", clears)
		_check(lead.confirmed_chapters == stage and lead.total_xp == stage * 100 and lead.lead_level == levels[stage]
			and lead.xp_in_level == remaining_xp[stage] and lead.next_level_xp == next_xp[stage]
			and lead.next_mission_bp == 400 and lead.next_mission_capacity == capacities[stage]
			and allocation.lead_level == levels[stage] and allocation.budget == levels[stage] - 1
			and allocation.remaining_points == levels[stage] - 1 and allocation.rating(Unit.Damage.MELEE) == Unit.MIN_RATING,
			"Subordinate training must never change any stage's confirmed XP, lead ratings/budget, or projected BP.")
		if allocation.can_invest(Unit.Damage.MELEE):
			allocation.invest(Unit.Damage.MELEE)
			_check(draft.formation_drill_rank(SLOT) == 2 and draft.available_drill_credit(SLOT) == 0
				and draft.qualifies_for_branch(SLOT, HEAVY), "Lead investments also cannot affect the subordinate branch.")


func _check_skirmish_rule() -> void:
	_check(Catalog.TYPES[REGULAR].platoon_training[Platoon.Skill.FORMATION_DRILL] == 1
		and not Catalog.can_promote_with_ratings(REGULAR, HEAVY, func(_type: int) -> int: return 9)
		and Catalog.can_promote_with_ratings(REGULAR, HEAVY, func(_type: int) -> int: return 10),
		"Practice/skirmish still use the unchanged Melee 10 prerequisite and the authored Infantry rank remains 1.")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
