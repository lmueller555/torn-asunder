extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Roster := preload("res://game/combat/faction_roster.gd")

const HUMAN_INFANTRY := &"human_infantry"
const HUMAN_HEAVY_INFANTRY := &"human_heavy_infantry"
const HUMAN_ARCHER := &"human_archer"
const HUMAN_MARCHES_LONGBOWS := &"human_marches_longbows"
const ORC_BASIN_REGULARS := &"orc_basin_regulars"
const ORC_BRACE_INFANTRY := &"orc_brace_infantry"
const ORC_BASIN_ARCHERS := &"orc_basin_archers"
const ELF_SHORE_DETACHMENT := &"elf_shore_detachment"
const ELF_SHORE_MARINES := &"elf_shore_marines"
const ELF_SHIP_ARCHERS := &"elf_ship_archers"
const DRUID_TUNNEL_GUARD := &"druid_tunnel_guard"
const DRUID_OUTLET_SCREEN := &"druid_outlet_screen"
const DRUID_SHELF_GUARD := &"druid_shelf_guard"
const DRYAD_LOADING_GUARD := &"dryad_loading_guard"
const DRYAD_FEEDER_RESERVE := &"dryad_feeder_reserve"
const DRYAD_SHELF_VOLUNTEERS := &"dryad_shelf_volunteers"
const UNDEAD_HOUSEHOLD_GUARD := &"undead_household_guard"
const UNDEAD_STAIR_GUARD := &"undead_stair_guard"
const UNDEAD_COURT_FOOT := &"undead_court_foot"
const INFANTRY_SWORD_SLASH_SPEED := 1.4

const TYPES: Dictionary[StringName, Dictionary] = {
	HUMAN_INFANTRY: {
		"name": "Infantry",
		"faction": "Humans",
		"role": "Frontline melee",
		"model": preload("res://assets/models/human_infantry.glb"),
		"animation_preview": {
			&"Backward Knockdown": {"travel": -0.625, "floor_scale": 1.55},
			&"Death Fall": {"travel": 0.121, "side_offset": -0.52, "floor_scale": 1.3},
			&"Get Up": {"start_offset": -0.625, "travel": -0.28, "floor_scale": 1.55},
			&"Hit Stagger": {"travel": -0.26},
			&"Sword Slash": {"headroom": 0.62, "travel": 0.52, "speed": INFANTRY_SWORD_SLASH_SPEED},
			&"Sword Recoil": {"headroom": 0.20, "travel": 0.52},
			&"Sword Cheer": {"headroom": 0.68},
		},
		"equipment": {
			"main_hand": &"sword",
			"off_hand": &"shield",
		},
		"starting_hp": Unit.STARTING_HP,
		"movement_scale": 1.0,
		"ratings": {
			Unit.Damage.MELEE: Unit.MIN_RATING,
			Unit.Damage.RANGED: Unit.MIN_RATING,
			Unit.Damage.FIRE: Unit.MIN_RATING,
			Unit.Damage.LIGHTNING: Unit.MIN_RATING,
			Unit.Damage.ICE: Unit.MIN_RATING,
			Unit.Damage.NATURE: Unit.MIN_RATING,
			Unit.Damage.HOLY: Unit.MIN_RATING,
			Unit.Damage.CURSE: Unit.MIN_RATING,
		},
		"basic_attack": {
			Unit.Damage.MELEE: 37.0,
		},
		"platoon_training": {
			Platoon.Skill.CHARGE_BRACE: 1,
			Platoon.Skill.MOUNTED_TRAINING: 0,
			Platoon.Skill.FORMATION_DRILL: 1,
			Platoon.Skill.SCOUTING: 0,
			Platoon.Skill.SIEGECRAFT: 0,
			Platoon.Skill.BEAST_HANDLING: 0,
		},
	},
	HUMAN_HEAVY_INFANTRY: {
		"name": "Heavy Infantry",
		"faction": "Humans",
		"role": "Line holder in heavy mail",
		"model": preload("res://assets/models/human_heavy_infantry.glb"),
		"animation_preview": {
			&"Advancing Diagonal Cut": {"headroom": 0.34, "travel": 0.36},
			&"Run Start": {"travel": 0.429},
			&"Run Stop": {"travel": 0.286},
			&"Shield Walk Start": {"travel": 0.176},
			&"Shield Walk Stop": {"travel": 0.264},
		},
		"preview_clip": &"Shield-Ready Idle",
		"equipment": {
			"main_hand": &"sword",
			"off_hand": &"shield",
		},
		"promotes_from": HUMAN_INFANTRY,
		"promotion_minimum_ratings": {Unit.Damage.MELEE: 10},
		# Provisional profile. Ratings are inherited; movement is used in the skirmish simulation.
		"starting_hp": 1320.0,
		"movement_scale": 0.85,
		"basic_attack": {Unit.Damage.MELEE: 32.0},
	},
}


## Battlefield taxonomy and planning gates. Metadata rows do not imply
## a corresponding entry in the model inventory (TYPES).
static func faction_roster() -> Roster:
	var roster := Roster.new()
	roster.add_unit(HUMAN_INFANTRY, Roster.HUMANS, Roster.MELEE)
	roster.add_unit(HUMAN_HEAVY_INFANTRY, Roster.HUMANS, Roster.MELEE)
	roster.add_unit(HUMAN_ARCHER, Roster.HUMANS, Roster.RANGED, [], false, "Archer")
	roster.add_unit(HUMAN_MARCHES_LONGBOWS, Roster.HUMANS, Roster.RANGED, [], false, "Marches Longbows")
	roster.add_advance(HUMAN_INFANTRY, HUMAN_HEAVY_INFANTRY, TYPES[HUMAN_HEAVY_INFANTRY].promotion_minimum_ratings)
	# Provisional Archer path, not a live promotion or a new volley profile.
	roster.add_advance(HUMAN_ARCHER, HUMAN_MARCHES_LONGBOWS,
		{Unit.Damage.RANGED: 8}, {Platoon.Skill.FORMATION_DRILL: 2})
	roster.add_unit(ORC_BASIN_REGULARS, Roster.ORCS, Roster.MELEE, [], false, "Basin Regulars")
	roster.add_unit(ORC_BRACE_INFANTRY, Roster.ORCS, Roster.ANTI_RIDING, [Roster.MELEE], false, "Brace Infantry")
	roster.add_unit(ORC_BASIN_ARCHERS, Roster.ORCS, Roster.RANGED, [], false, "Basin Archers")
	# Provisional metadata only. These are not runtime promotions or balance changes.
	roster.add_advance(ORC_BASIN_REGULARS, ORC_BRACE_INFANTRY,
		{Unit.Damage.MELEE: 5}, {Platoon.Skill.CHARGE_BRACE: 2})
	roster.add_advance(ORC_BASIN_REGULARS, ORC_BASIN_ARCHERS,
		{Unit.Damage.RANGED: 6}, {Platoon.Skill.SCOUTING: 2})

	roster.add_unit(ELF_SHORE_DETACHMENT, Roster.ELVES, Roster.MELEE, [], false, "Shore Detachment")
	roster.add_unit(ELF_SHORE_MARINES, Roster.ELVES, Roster.MELEE, [], false, "Shore Marines")
	roster.add_unit(ELF_SHIP_ARCHERS, Roster.ELVES, Roster.RANGED, [], false, "Ship Archers")
	# Provisional shore and ship jobs, not a new naval class or mounted branch.
	roster.add_advance(ELF_SHORE_DETACHMENT, ELF_SHORE_MARINES, {},
		{Platoon.Skill.FORMATION_DRILL: 2, Platoon.Skill.SCOUTING: 1})
	roster.add_advance(ELF_SHORE_DETACHMENT, ELF_SHIP_ARCHERS,
		{Unit.Damage.RANGED: 4}, {Platoon.Skill.FORMATION_DRILL: 1})

	roster.add_unit(DRUID_TUNNEL_GUARD, Roster.DRUIDS, Roster.MELEE, [], false, "Tunnel Guard")
	roster.add_unit(DRUID_OUTLET_SCREEN, Roster.DRUIDS, Roster.MELEE, [], false, "Outlet Screen")
	roster.add_unit(DRUID_SHELF_GUARD, Roster.DRUIDS, Roster.MELEE, [], false, "Shelf Guard")
	# Provisional gates: spotting pressure for staged evacuation versus holding a narrow approach.
	roster.add_advance(DRUID_TUNNEL_GUARD, DRUID_OUTLET_SCREEN, {}, {Platoon.Skill.SCOUTING: 3})
	roster.add_advance(DRUID_TUNNEL_GUARD, DRUID_SHELF_GUARD,
		{Unit.Damage.MELEE: 6}, {Platoon.Skill.FORMATION_DRILL: 3})

	roster.add_unit(DRYAD_LOADING_GUARD, Roster.DRYADS, Roster.MELEE, [], false, "Loading Guard")
	roster.add_unit(DRYAD_FEEDER_RESERVE, Roster.DRYADS, Roster.MELEE, [], false, "Feeder Reserve")
	roster.add_unit(DRYAD_SHELF_VOLUNTEERS, Roster.DRYADS, Roster.MELEE, [], false, "Shelf Volunteers")
	# Provisional gates for protecting work sites or moving with escorted groups.
	roster.add_advance(DRYAD_LOADING_GUARD, DRYAD_FEEDER_RESERVE, {},
		{Platoon.Skill.CHARGE_BRACE: 1, Platoon.Skill.FORMATION_DRILL: 2})
	roster.add_advance(DRYAD_LOADING_GUARD, DRYAD_SHELF_VOLUNTEERS,
		{Unit.Damage.MELEE: 3}, {Platoon.Skill.SCOUTING: 2})

	roster.add_unit(UNDEAD_HOUSEHOLD_GUARD, Roster.UNDEAD, Roster.MELEE, [], false, "Household Guard")
	roster.add_unit(UNDEAD_STAIR_GUARD, Roster.UNDEAD, Roster.MELEE, [], false, "Stair Guard")
	roster.add_unit(UNDEAD_COURT_FOOT, Roster.UNDEAD, Roster.MELEE, [], false, "Court Foot")
	# Provisional narrow-lane guard training. Court assignment is not an advancement.
	roster.add_advance(UNDEAD_HOUSEHOLD_GUARD, UNDEAD_STAIR_GUARD, {Unit.Damage.MELEE: 4},
		{Platoon.Skill.CHARGE_BRACE: 1, Platoon.Skill.FORMATION_DRILL: 2})
	return roster


## Checks a roster unit's purchased ratings without spending points or changing its type.
## The caller supplies the unit's current roster type; CombatUnit does not store it.
static func can_promote(source_type: StringName, target_type: StringName, unit: Unit) -> bool:
	return unit != null and can_promote_with_ratings(source_type, target_type, unit.rating)


## Also checks a build's budgeted ratings before any soldiers are instantiated.
static func can_promote_with_ratings(source_type: StringName, target_type: StringName, read_rating: Callable) -> bool:
	var target: Dictionary = TYPES.get(target_type, {})
	if not read_rating.is_valid() or not target.has("promotes_from") or target.promotes_from != source_type:
		return false
	var minimum_ratings: Dictionary = target.promotion_minimum_ratings
	for type: Unit.Damage in minimum_ratings:
		if int(read_rating.call(type)) < minimum_ratings[type]:
			return false
	return true
