extends SceneTree

const Roster := preload("res://game/combat/faction_roster.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
var _failures := 0


func _initialize() -> void:
	_check_taxonomy()
	_check_branches()
	_check_live_catalog()
	if _failures == 0:
		print("Faction roster: nine labels, hybrid roles, elite standing, six distinct factions, stat-gated branches and live Human parity passed.")
	quit(0 if _failures == 0 else 1)


func _check_taxonomy() -> void:
	var roster := Roster.new()
	_check(Roster.LABELS.values() == [
		"Ranged", "Melee", "Elementals", "Casters", "Riding", "Anti-riding", "Flying", "Siege", "Elite Support",
	], "The public taxonomy has exactly the nine requested labels.")
	var examples := [
		[&"fixture_archer", Roster.HUMANS, Roster.RANGED, [], false],
		[&"fixture_paladin", Roster.HUMANS, Roster.MELEE, [Roster.CASTERS], false],
		[&"fixture_cavalry_archer", Roster.ELVES, Roster.RIDING, [Roster.RANGED], false],
		[&"fixture_sapper", Roster.HUMANS, Roster.MELEE, [Roster.ENGINEERING], false],
		[&"fixture_catapult", Roster.HUMANS, Roster.SIEGE, [], false],
		[&"fixture_mortar", Roster.HUMANS, Roster.SIEGE, [Roster.RANGED], false],
		[&"fixture_scorpion", Roster.ORCS, Roster.SIEGE, [Roster.MELEE], true],
		[&"fixture_mammoth", Roster.ORCS, Roster.MELEE, [Roster.RANGED], true],
		[&"fixture_elemental", Roster.DRYADS, Roster.ELEMENTALS, [Roster.CASTERS], false],
		[&"fixture_caster", Roster.DRUIDS, Roster.CASTERS, [], false],
		[&"fixture_pikes", Roster.HUMANS, Roster.ANTI_RIDING, [Roster.MELEE], false],
		[&"fixture_wing", Roster.UNDEAD, Roster.FLYING, [], false],
	]
	for example in examples:
		var tags: Array[StringName] = []
		tags.assign(example[3])
		_check(roster.add_unit(example[0], example[1], example[2], tags, example[4]), "Fixture admits %s." % example[0])
		_check(roster.unit(example[0]).primary_family == example[2], "The fixture keeps exactly one primary family.")
	for faction in Roster.FACTIONS:
		_check(not roster.units_for_faction(faction).is_empty(), "Faction %s can author a unique, incomplete roster." % faction)
	_check(roster.has_label(&"fixture_scorpion", Roster.SIEGE) and roster.has_label(&"fixture_scorpion", Roster.ELITE_SUPPORT)
		and not roster.has_label(&"fixture_catapult", Roster.ELITE_SUPPORT) and not roster.has_label(&"fixture_mortar", Roster.ELITE_SUPPORT)
		and roster.has_label(&"fixture_mammoth", Roster.ELITE_SUPPORT) and not roster.has_label(&"fixture_mammoth", Roster.SIEGE),
		"Siege battlefield function and elite standing can coincide or exist independently.")
	_check(roster.has_label(&"fixture_cavalry_archer", Roster.RIDING) and roster.has_label(&"fixture_cavalry_archer", Roster.RANGED)
		and roster.has_label(&"fixture_paladin", Roster.MELEE) and roster.has_label(&"fixture_paladin", Roster.CASTERS)
		and not roster.has_label(&"fixture_archer", Roster.CASTERS) and roster.has_label(&"fixture_sapper", Roster.ENGINEERING),
		"Hybrid roles do not turn every user of a ranged or caster ability into that primary family.")
	_check(not roster.add_unit(&"fixture_archer", Roster.ORCS, Roster.RANGED)
		and not roster.add_unit(&"invalid", &"foreign", Roster.MELEE)
		and not roster.add_unit(&"elite_only", Roster.ORCS, Roster.ELITE_SUPPORT)
		and not roster.add_unit(&"engineering_only", Roster.HUMANS, Roster.ENGINEERING)
		and not roster.add_unit(&"bad_duplicate", Roster.HUMANS, Roster.MELEE, [Roster.MELEE]),
		"Duplicate unit IDs, unsupported factions, and invalid primary/duplicate tags are refused.")


func _check_branches() -> void:
	var roster := Roster.new()
	roster.add_unit(&"base", Roster.HUMANS, Roster.MELEE)
	roster.add_unit(&"guard", Roster.HUMANS, Roster.MELEE)
	roster.add_unit(&"holy_guard", Roster.HUMANS, Roster.MELEE, [Roster.CASTERS])
	roster.add_unit(&"mounted", Roster.HUMANS, Roster.RIDING)
	roster.add_unit(&"orc_own_base", Roster.ORCS, Roster.MELEE)
	var basic := {Unit.Damage.MELEE: 10}
	var holy := {Unit.Damage.MELEE: 8, Unit.Damage.HOLY: 6}
	var mounted := {Platoon.Skill.MOUNTED_TRAINING: 3}
	_check(roster.add_advance(&"base", &"guard", basic) and roster.add_advance(&"base", &"holy_guard", holy)
		and roster.add_advance(&"guard", &"mounted", {}, mounted), "A base can branch by purchased ratings, with a lane gated by training later.")
	_check(not roster.add_advance(&"base", &"guard", basic) and not roster.add_advance(&"mounted", &"base", basic)
		and not roster.add_advance(&"base", &"orc_own_base", basic) and not roster.add_advance(&"base", &"mounted", {})
		and not roster.add_advance(&"holy_guard", &"guard", {Unit.Damage.HOLY: 101}),
		"The graph rejects duplicate, cyclic, cross-faction, ungated and invalid edges.")
	var ratings := {Unit.Damage.MELEE: 10, Unit.Damage.HOLY: 5}
	var training := {Platoon.Skill.MOUNTED_TRAINING: 3}
	var read_rating := func(stat: int) -> int: return ratings.get(stat, 1)
	var read_training := func(stat: int) -> int: return training.get(stat, 0)
	_check(roster.eligible_advances(&"base", read_rating) == [&"guard"], "Every holy branch gate must be met independently.")
	ratings[Unit.Damage.HOLY] = 6
	_check(roster.eligible_advances(&"base", read_rating) == [&"guard", &"holy_guard"],
		"Both qualified paths can coexist without a forced choice.")
	_check(roster.can_advance(&"guard", &"mounted", Callable(), read_training)
		and not roster.can_advance(&"base", &"mounted", read_rating, read_training)
		and not roster.can_advance(&"guard", &"mounted"), "Training never substitutes for a missing predecessor or missing verifier.")
	var over_cap := func(_stat: int) -> int: return 101
	_check(not roster.can_advance(&"base", &"guard", over_cap),
		"An out-of-bounds reader result cannot bypass the permitted stat domain.")
	var exported := roster.advancement(&"base", &"guard")
	exported.ratings[Unit.Damage.MELEE] = 100
	basic[Unit.Damage.MELEE] = 90
	_check(roster.can_advance(&"base", &"guard", read_rating), "Source or returned dictionaries cannot mutate already recorded gate values.")


func _check_live_catalog() -> void:
	var roster := Catalog.faction_roster()
	_check(roster.units_for_faction(Roster.HUMANS).size() == 3
		and roster.has_label(Catalog.HUMAN_ARCHER, Roster.RANGED)
		and roster.has_label(Catalog.HUMAN_HEAVY_INFANTRY, Roster.MELEE)
		and not Catalog.TYPES.has(Catalog.HUMAN_ARCHER),
		"The real first slice covers existing Human Infantry, Heavy Infantry and the established Archer without faking an art entry.")
	for rating in [1, 9, 10, 11]:
		var read_rating := func(_stat: int) -> int: return rating
		_check(roster.can_advance(Catalog.HUMAN_INFANTRY, Catalog.HUMAN_HEAVY_INFANTRY, read_rating)
			== Catalog.can_promote_with_ratings(Catalog.HUMAN_INFANTRY, Catalog.HUMAN_HEAVY_INFANTRY, read_rating),
			"New metadata matches the live Heavy Infantry rule at rating %d." % rating)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
