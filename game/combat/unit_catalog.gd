extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Roster := preload("res://game/combat/faction_roster.gd")

const HUMAN_INFANTRY := &"human_infantry"
const HUMAN_HEAVY_INFANTRY := &"human_heavy_infantry"
const HUMAN_ARCHER := &"human_archer"
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



## The first classified slice uses existing gameplay units only. Archer combat
## is already represented by HumanArcherVolley but has no catalog model yet.
## Consumers that require art still use TYPES as before.
static func faction_roster() -> Roster:
	var roster := Roster.new()
	roster.add_unit(HUMAN_INFANTRY, Roster.HUMANS, Roster.MELEE)
	roster.add_unit(HUMAN_HEAVY_INFANTRY, Roster.HUMANS, Roster.MELEE)
	roster.add_unit(HUMAN_ARCHER, Roster.HUMANS, Roster.RANGED)
	roster.add_advance(HUMAN_INFANTRY, HUMAN_HEAVY_INFANTRY, TYPES[HUMAN_HEAVY_INFANTRY].promotion_minimum_ratings)
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
