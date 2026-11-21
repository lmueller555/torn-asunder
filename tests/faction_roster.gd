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
	_check_orc_catalog()
	_check_elf_catalog()
	_check_druid_catalog()
	if _failures == 0:
		print("Faction roster: nine labels, hybrid roles, elite standing, six distinct factions, stat-gated Orc, Elf and Druid branches and live Human parity passed.")
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


func _check_orc_catalog() -> void:
	var roster := Catalog.faction_roster()
	var regulars := Catalog.ORC_BASIN_REGULARS
	var brace := Catalog.ORC_BRACE_INFANTRY
	var archers := Catalog.ORC_BASIN_ARCHERS
	_check(roster.units_for_faction(Roster.ORCS) == [regulars, brace, archers],
		"The Orc slice has only the three initial canon field roles.")
	for fixture: Array in [
		[regulars, "Basin Regulars", Roster.MELEE, []],
		[brace, "Brace Infantry", Roster.ANTI_RIDING, [Roster.MELEE]],
		[archers, "Basin Archers", Roster.RANGED, []],
	]:
		var entry := roster.unit(fixture[0])
		_check(entry.get("display_name") == fixture[1] and entry.get("primary_family") == fixture[2]
			and entry.get("secondary_tags") == fixture[3] and entry.get("elite_support") == false,
			"The Orc entry preserves its campaign name and separate field role: %s." % fixture[0])
		_check(not Catalog.TYPES.has(fixture[0]) and not Catalog.can_promote(Catalog.HUMAN_INFANTRY, fixture[0], Unit.new()),
			"No Orc prototype should become an art entry or a live Human promotion.")
	for faction in [Roster.DRYADS, Roster.UNDEAD]:
		_check(roster.units_for_faction(faction).is_empty(), "An unrelated faction was inadvertently populated.")
	_check(not roster.has_label(regulars, Roster.ANTI_RIDING) and not roster.has_label(brace, Roster.RANGED)
		and not roster.has_label(archers, Roster.ANTI_RIDING),
		"Each specialist has an independent role rather than replacing all the regulars' jobs.")

	# Melee, Ranged, Charge & Brace, Scouting; use the actual rating and training readers.
	var expectations := [
		[[1, 1, 0, 0], []],
		[[5, 6, 0, 0], []],
		[[1, 1, 5, 5], []],
		[[4, 6, 2, 2], [archers]],
		[[5, 5, 2, 2], [brace]],
		[[5, 6, 1, 2], [archers]],
		[[5, 6, 2, 1], [brace]],
		[[5, 6, 2, 2], [brace, archers]],
	]
	for fixture: Array in expectations:
		var values: Array = fixture[0]
		var soldier := Unit.new(Unit.STARTING_HP, {
			Unit.Damage.MELEE: values[0], Unit.Damage.RANGED: values[1],
		})
		var platoon := Platoon.new([soldier], {
			Platoon.Skill.CHARGE_BRACE: values[2], Platoon.Skill.SCOUTING: values[3],
		})
		_check(roster.eligible_advances(regulars, soldier.rating, platoon.rank) == fixture[1],
			"Orc branches must honor their own exact rating and training gate: %s." % str(values))
		_check(not roster.can_advance(brace, archers, soldier.rating, platoon.rank)
			and not roster.can_advance(archers, brace, soldier.rating, platoon.rank)
			and not roster.can_advance(regulars, Catalog.HUMAN_HEAVY_INFANTRY, soldier.rating, platoon.rank),
			"High ratings do not authorize a sibling switch or a foreign faction's edge.")
		_check(soldier.level == 1 and soldier.stat_points == 0 and platoon.cohesion == Platoon.FULL_COHESION,
			"Eligibility is a read-only inquiry.")
	var exported := roster.unit(regulars)
	exported.display_name = "Not a canon name"
	_check(Catalog.faction_roster().unit(regulars).display_name == "Basin Regulars"
		and roster.unit(regulars).display_name == "Basin Regulars", "Roster consumers can't rename the canon entry through a snapshot.")


func _check_elf_catalog() -> void:
	var roster := Catalog.faction_roster()
	var shore := Catalog.ELF_SHORE_DETACHMENT
	var marines := Catalog.ELF_SHORE_MARINES
	var archers := Catalog.ELF_SHIP_ARCHERS
	_check(roster.units_for_faction(Roster.ELVES) == [shore, marines, archers],
		"The Elven tree should contain only the three named field units.")
	for fixture: Array in [
		[shore, "Shore Detachment", Roster.MELEE],
		[marines, "Shore Marines", Roster.MELEE],
		[archers, "Ship Archers", Roster.RANGED],
	]:
		var entry := roster.unit(fixture[0])
		_check(entry.get("display_name") == fixture[1] and entry.get("primary_family") == fixture[2]
			and entry.get("secondary_tags", [Roster.RIDING]).is_empty() and entry.get("elite_support") == false
			and not Catalog.TYPES.has(fixture[0]), "Elven planning rows don't imply models, elite standing, or mounted troops.")
	# Ranged rating, Formation Drill, Scouting. Read actual ratings and ranks.
	for fixture: Array in [
		[[1, 0, 0], []],
		[[4, 0, 1], []],
		[[1, 2, 1], [marines]],
		[[4, 1, 1], [archers]],
		[[4, 2, 0], [archers]],
		[[3, 2, 1], [marines]],
		[[4, 2, 1], [marines, archers]],
	]:
		var values: Array = fixture[0]
		var soldier := Unit.new(Unit.STARTING_HP, {Unit.Damage.RANGED: values[0], Unit.Damage.MELEE: 100})
		var platoon := Platoon.new([soldier], {
			Platoon.Skill.FORMATION_DRILL: values[1], Platoon.Skill.SCOUTING: values[2], Platoon.Skill.CHARGE_BRACE: 5,
		})
		_check(roster.eligible_advances(shore, soldier.rating, platoon.rank) == fixture[1],
			"The coastal branches should accept only their own training and rating minima: %s." % str(values))
		_check(not roster.can_advance(marines, archers, soldier.rating, platoon.rank)
			and not roster.can_advance(archers, marines, soldier.rating, platoon.rank)
			and not roster.can_advance(Catalog.ORC_BASIN_REGULARS, marines, soldier.rating, platoon.rank)
			and not roster.can_advance(shore, Catalog.HUMAN_HEAVY_INFANTRY, soldier.rating, platoon.rank),
			"Neither sibling nor established faction links are opened by the Elven branch.")
	var trained := func(_stat: int) -> int: return 2
	_check(roster.can_advance(shore, marines, Callable(), trained)
		and not roster.can_advance(shore, archers, Callable(), trained),
		"Ship Archers need a rating reader; Shore Marines can qualify through training alone.")


func _check_druid_catalog() -> void:
	var roster := Catalog.faction_roster()
	var tunnel := Catalog.DRUID_TUNNEL_GUARD
	var outlet := Catalog.DRUID_OUTLET_SCREEN
	var shelf := Catalog.DRUID_SHELF_GUARD
	_check(roster.units_for_faction(Roster.DRUIDS) == [tunnel, outlet, shelf],
		"The Druid starter tree contains only the three named guard formations.")
	for fixture: Array in [[tunnel, "Tunnel Guard"], [outlet, "Outlet Screen"], [shelf, "Shelf Guard"]]:
		var id: StringName = fixture[0]
		var entry := roster.unit(id)
		_check(entry.get("display_name") == fixture[1] and entry.get("primary_family") == Roster.MELEE
			and entry.get("secondary_tags", [Roster.CASTERS]).is_empty()
			and not roster.has_label(id, Roster.ELITE_SUPPORT) and not Catalog.TYPES.has(id),
			"Druid guards don't imply spellcasting, elite standing or a model entry.")
	# Melee, Formation Drill, Scouting. Neither Riding nor magic should satisfy these gates.
	for fixture: Array in [
		[[1, 0, 0], []],
		[[6, 2, 2], []],
		[[5, 3, 2], []],
		[[1, 0, 3], [outlet]],
		[[6, 3, 2], [shelf]],
		[[6, 2, 3], [outlet]],
		[[6, 3, 3], [outlet, shelf]],
	]:
		var values: Array = fixture[0]
		var soldier := Unit.new(Unit.STARTING_HP, {Unit.Damage.MELEE: values[0], Unit.Damage.NATURE: 100})
		var platoon := Platoon.new([soldier], {
			Platoon.Skill.FORMATION_DRILL: values[1], Platoon.Skill.SCOUTING: values[2],
			Platoon.Skill.MOUNTED_TRAINING: 5,
		})
		_check(roster.eligible_advances(tunnel, soldier.rating, platoon.rank) == fixture[1],
			"The Druid lanes require separate exact scouting or line-holding gates: %s." % str(values))
		_check(not roster.can_advance(outlet, shelf, soldier.rating, platoon.rank)
			and not roster.can_advance(shelf, outlet, soldier.rating, platoon.rank)
			and not roster.can_advance(Catalog.ELF_SHORE_DETACHMENT, outlet, soldier.rating, platoon.rank)
			and not roster.can_advance(tunnel, Catalog.ORC_BRACE_INFANTRY, soldier.rating, platoon.rank),
			"Both Druid paths must originate at Tunnel Guard and stay within their faction.")
	var trained := func(_stat: int) -> int: return 3
	_check(roster.can_advance(tunnel, outlet, Callable(), trained) and not roster.can_advance(tunnel, shelf, Callable(), trained),
		"The Outlet Screen can qualify without a rating reader; Shelf Guard cannot.")


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
