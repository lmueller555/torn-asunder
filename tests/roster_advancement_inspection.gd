extends SceneTree

const Roster := preload("res://game/combat/faction_roster.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const MELEE := Unit.Damage.MELEE
const RANGED := Unit.Damage.RANGED
const BRACE := Platoon.Skill.CHARGE_BRACE
const DRILL := Platoon.Skill.FORMATION_DRILL
const SCOUT := Platoon.Skill.SCOUTING

var _failures := 0


func _initialize() -> void:
	_check_six_factions()
	_check_missing_reads()
	_check_scope_cache_and_snapshots()
	if _failures == 0:
		print("Roster inspection: six factions, exact separate rating and skill gaps, direct choices, invalid reads and read-only planning passed.")
	quit(0 if _failures == 0 else 1)


func _check_six_factions() -> void:
	var board := Catalog.faction_roster()
	# Each example uses a live CombatUnit rating reader and CombatPlatoon rank reader.
	var fixtures := [
		[Roster.HUMANS, Catalog.HUMAN_INFANTRY, {MELEE: 8}, {}, [
			_row(Catalog.HUMAN_HEAVY_INFANTRY, false, {MELEE: _need(8, 10, 2)}, {}),
		]],
		[Roster.ORCS, Catalog.ORC_BASIN_REGULARS, {MELEE: 5, RANGED: 5}, {BRACE: 1, SCOUT: 2}, [
			_row(Catalog.ORC_BRACE_INFANTRY, false, {MELEE: _need(5, 5, 0)}, {BRACE: _need(1, 2, 1)}),
			_row(Catalog.ORC_BASIN_ARCHERS, false, {RANGED: _need(5, 6, 1)}, {SCOUT: _need(2, 2, 0)}),
		]],
		[Roster.ELVES, Catalog.ELF_SHORE_DETACHMENT, {RANGED: 4}, {DRILL: 2, SCOUT: 0}, [
			_row(Catalog.ELF_SHORE_MARINES, false, {}, {DRILL: _need(2, 2, 0), SCOUT: _need(0, 1, 1)}),
			_row(Catalog.ELF_SHIP_ARCHERS, true, {RANGED: _need(4, 4, 0)}, {DRILL: _need(2, 1, 0)}),
		]],
		[Roster.DRUIDS, Catalog.DRUID_TUNNEL_GUARD, {MELEE: 4}, {SCOUT: 3, DRILL: 2}, [
			_row(Catalog.DRUID_OUTLET_SCREEN, true, {}, {SCOUT: _need(3, 3, 0)}),
			_row(Catalog.DRUID_SHELF_GUARD, false, {MELEE: _need(4, 6, 2)}, {DRILL: _need(2, 3, 1)}),
		]],
		[Roster.DRYADS, Catalog.DRYAD_LOADING_GUARD, {MELEE: 2}, {BRACE: 1, DRILL: 1, SCOUT: 2}, [
			_row(Catalog.DRYAD_FEEDER_RESERVE, false, {}, {BRACE: _need(1, 1, 0), DRILL: _need(1, 2, 1)}),
			_row(Catalog.DRYAD_SHELF_VOLUNTEERS, false, {MELEE: _need(2, 3, 1)}, {SCOUT: _need(2, 2, 0)}),
		]],
		[Roster.UNDEAD, Catalog.UNDEAD_HOUSEHOLD_GUARD, {MELEE: 4}, {BRACE: 1, DRILL: 2}, [
			_row(Catalog.UNDEAD_STAIR_GUARD, true, {MELEE: _need(4, 4, 0)}, {
				BRACE: _need(1, 1, 0), DRILL: _need(2, 2, 0),
			}),
		]],
	]
	for sample: Array in fixtures:
		var unit := Unit.new(Unit.STARTING_HP, sample[2])
		unit.award_experience(100)
		var platoon := Platoon.new([unit], sample[3])
		var report := board.inspect_advances(sample[1], sample[0], unit.rating, platoon.rank)
		_check(report == sample[4], "The faction report must give exact branch-specific gaps: %s." % sample[0])
		var eligible: Array[StringName] = []
		for branch in report:
			if branch.eligible:
				eligible.append(branch.target)
			_check(board.can_advance(sample[1], branch.target, unit.rating, platoon.rank) == branch.eligible,
				"Report eligibility and the existing gate query must agree.")
			_check((branch.target == Catalog.HUMAN_HEAVY_INFANTRY) == Catalog.TYPES.has(branch.target),
				"Planning rows do not add troops to live asset or skirmish inventory.")
		_check(eligible == board.eligible_advances(sample[1], unit.rating, platoon.rank),
			"Filtering the report must return exactly the existing eligible branches.")
		_check(unit.level == 2 and unit.stat_points == 1 and platoon.cohesion == Platoon.FULL_COHESION,
			"Inspection must not spend a stat point or change the platoon.")
	var melee_ten := func(_stat: int) -> int: return 10
	var human := board.inspect_advances(Catalog.HUMAN_INFANTRY, Roster.HUMANS, melee_ten)
	_check(human[0].eligible and Catalog.can_promote_with_ratings(Catalog.HUMAN_INFANTRY,
		Catalog.HUMAN_HEAVY_INFANTRY, melee_ten), "The only live promotion still qualifies at the exact Melee 10 gate.")


func _check_missing_reads() -> void:
	var board := Catalog.faction_roster()
	var source := Catalog.ORC_BASIN_REGULARS
	var valid_training := func(_stat: int) -> int: return 0
	for invalid in [null, -1, 0, 101, true, "5", 5.0, INF, NAN]:
		var bad_rating := func(_stat: int) -> Variant: return invalid
		var rows := board.inspect_advances(source, Roster.ORCS, bad_rating, valid_training)
		_check(not rows[0].eligible and rows[0].ratings[MELEE] == _need(null, 5, null)
			and rows[0].training[BRACE] == _need(0, 2, 2),
			"An invalid rating must not be cast to a number; known training still reports its exact gap.")
	var valid_rating := func(_stat: int) -> int: return 10
	for invalid in [null, -1, 6, false, "2", 2.0, INF, NAN]:
		var bad_training := func(_stat: int) -> Variant: return invalid
		var rows := board.inspect_advances(source, Roster.ORCS, valid_rating, bad_training)
		_check(not rows[0].eligible and rows[0].training[BRACE] == _need(null, 2, null)
			and rows[0].ratings[MELEE] == _need(10, 5, 0),
			"An invalid rank must not count as earned or hide the known rating.")
	var unread := board.inspect_advances(source, Roster.ORCS)
	_check(unread[0] == _row(Catalog.ORC_BRACE_INFANTRY, false, {MELEE: _need(null, 5, null)}, {
		BRACE: _need(null, 2, null),
	}), "Absent readers show unknown requirements, not fabricated zeroes.")
	var druid := board.inspect_advances(Catalog.DRUID_TUNNEL_GUARD, Roster.DRUIDS, Callable(),
		func(_stat: int) -> int: return 3)
	_check(druid[0].eligible and druid[0].ratings.is_empty() and not druid[1].eligible,
		"A training-only branch remains inspectable without a rating reader.")


func _check_scope_cache_and_snapshots() -> void:
	var board := Roster.new()
	for id: StringName in [&"root", &"left", &"right", &"later", &"terminal"]:
		board.add_unit(id, Roster.ORCS, Roster.MELEE)
	board.add_unit(&"foreign", Roster.ELVES, Roster.MELEE)
	board.add_advance(&"root", &"left", {MELEE: 5}, {BRACE: 2})
	board.add_advance(&"root", &"right", {MELEE: 8}, {BRACE: 3})
	board.add_advance(&"left", &"later", {RANGED: 10})
	_check(not board.add_advance(&"root", &"foreign", {MELEE: 1}), "Mixed-faction edges are not admissible.")
	var calls := {"ratings": 0, "training": 0}
	var read_rating := func(_stat: int) -> int:
		calls.ratings += 1
		return 6
	var read_training := func(_stat: int) -> int:
		calls.training += 1
		return 2
	for malformed: Array in [[&"root", Roster.ELVES], [&"foreign", Roster.ORCS], [&"unknown", Roster.ORCS],
			[&"root", &"unknown"], [&"terminal", Roster.ORCS]]:
		_check(board.inspect_advances(malformed[0], malformed[1], read_rating, read_training).is_empty(),
			"Wrong-faction, unknown and terminal unit IDs do not leak branches.")
	_check(calls == {"ratings": 0, "training": 0}, "Invalid or terminal scopes must not call the supplied readers.")
	var rows := board.inspect_advances(&"root", Roster.ORCS, read_rating, read_training)
	_check(rows == [
		_row(&"left", true, {MELEE: _need(6, 5, 0)}, {BRACE: _need(2, 2, 0)}),
		_row(&"right", false, {MELEE: _need(6, 8, 2)}, {BRACE: _need(2, 3, 1)}),
	] and calls == {"ratings": 1, "training": 1},
		"One-step sibling reports share one stat read per enum domain and do not walk to grandchildren.")
	rows[0].ratings[MELEE].minimum = 99
	rows[1].training.clear()
	_check(board.inspect_advances(&"left", Roster.ORCS, read_rating, read_training).size() == 1
		and board.inspect_advances(&"root", Roster.ORCS, read_rating, read_training)[0].ratings[MELEE].minimum == 5,
		"Returned rows cannot change the graph or subsequent inspections.")


func _row(target: StringName, eligible: bool, ratings: Dictionary, training: Dictionary) -> Dictionary:
	return {"target": target, "eligible": eligible, "ratings": ratings, "training": training}


func _need(current: Variant, minimum: int, missing: Variant) -> Dictionary:
	return {"current": current, "minimum": minimum, "missing": missing}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
