extends RefCounted
## Unit types that fight in campaign missions.
##
## Every type shares the rigged Human Infantry model. Faction tints and body scale tell
## the armies apart until each people has its own model.

const Unit := preload("res://game/combat/combat_unit.gd")

enum Role { MELEE, RANGED, CIVILIAN, HERO, STRUCTURE }

const D := Unit.Damage

const TYPES: Dictionary = {
	# Humans of the Seven Marches.
	&"marcher_infantry": {
		"name": "Marcher Infantry", "faction": "Humans", "role": Role.MELEE,
		"hp_scale": 1.0, "attack": {D.MELEE: 37.0}, "primary": [D.MELEE],
		"tint": Color(1, 1, 1), "scale": 1.0, "speed": 2.7,
	},
	&"marcher_archers": {
		"name": "Marcher Archers", "faction": "Humans", "role": Role.RANGED,
		"hp_scale": 0.8, "attack": {D.RANGED: 30.0}, "melee": {D.MELEE: 18.0},
		"primary": [D.RANGED], "range": 17.0, "reload": 2.6,
		"projectile": Color("#e8dcc0"), "tint": Color(0.86, 0.95, 0.80), "scale": 0.97, "speed": 2.8,
	},
	&"lowmarch_knights": {
		"name": "Lowmarch Knights", "faction": "Humans", "role": Role.MELEE,
		"hp_scale": 1.35, "attack": {D.MELEE: 42.0}, "primary": [D.MELEE],
		"base": {D.MELEE: 10}, "heavy_chance": 0.38,
		"tint": Color(0.62, 0.72, 1.0), "scale": 1.04, "speed": 2.6,
	},
	&"lowmarch_crossbows": {
		"name": "Lowmarch Crossbows", "faction": "Humans", "role": Role.RANGED,
		"hp_scale": 0.85, "attack": {D.RANGED: 34.0}, "melee": {D.MELEE: 18.0},
		"primary": [D.RANGED], "range": 15.0, "reload": 3.1,
		"projectile": Color("#c9d6ff"), "tint": Color(0.55, 0.62, 0.86), "scale": 0.98, "speed": 2.6,
	},
	&"miners": {
		"name": "Greyhollow Miners", "faction": "Humans", "role": Role.CIVILIAN,
		"hp_scale": 0.55, "attack": {}, "primary": [D.MELEE],
		"tint": Color(0.58, 0.52, 0.46), "scale": 0.96, "speed": 2.5,
	},
	&"villagers": {
		"name": "Villagers", "faction": "Humans", "role": Role.CIVILIAN,
		"hp_scale": 0.55, "attack": {}, "primary": [D.MELEE],
		"tint": Color(0.80, 0.70, 0.55), "scale": 0.95, "speed": 2.5,
	},
	# Orcs of the Red Basin.
	&"basin_warriors": {
		"name": "Basin Warriors", "faction": "Orcs", "role": Role.MELEE,
		"hp_scale": 1.25, "attack": {D.MELEE: 41.0}, "primary": [D.MELEE],
		"base": {D.MELEE: 6}, "heavy_chance": 0.34,
		"tint": Color(0.62, 0.82, 0.48), "scale": 1.16, "speed": 2.65,
	},
	&"basin_slingers": {
		"name": "Basin Slingers", "faction": "Orcs", "role": Role.RANGED,
		"hp_scale": 0.95, "attack": {D.RANGED: 31.0}, "melee": {D.MELEE: 22.0},
		"primary": [D.RANGED], "range": 15.0, "reload": 2.5,
		"projectile": Color("#bfa98a"), "tint": Color(0.70, 0.78, 0.52), "scale": 1.10, "speed": 2.7,
	},
	&"saltjaw_raiders": {
		"name": "Saltjaw Raiders", "faction": "Orcs", "role": Role.MELEE,
		"hp_scale": 1.15, "attack": {D.MELEE: 33.0, D.FIRE: 10.0}, "primary": [D.MELEE, D.FIRE],
		"heavy_chance": 0.36,
		"tint": Color(0.92, 0.58, 0.42), "scale": 1.14, "speed": 2.8,
	},
	&"well_keeper": {
		"name": "Well-keeper", "faction": "Orcs", "role": Role.CIVILIAN,
		"hp_scale": 0.9, "attack": {}, "primary": [D.MELEE],
		"tint": Color(0.70, 0.66, 0.50), "scale": 1.0, "speed": 2.5,
	},
	# Druids of the Cairnspine.
	&"cairn_wardens": {
		"name": "Cairn Wardens", "faction": "Druids", "role": Role.MELEE,
		"hp_scale": 1.2, "attack": {D.MELEE: 30.0, D.NATURE: 9.0}, "primary": [D.MELEE, D.NATURE],
		"base": {D.NATURE: 12},
		"tint": Color(0.66, 0.70, 0.66), "scale": 1.02, "speed": 2.6,
	},
	&"stonecallers": {
		"name": "Stonecallers", "faction": "Druids", "role": Role.RANGED,
		"hp_scale": 0.8, "attack": {D.LIGHTNING: 22.0, D.NATURE: 12.0}, "melee": {D.MELEE: 16.0},
		"primary": [D.LIGHTNING, D.NATURE], "range": 16.0, "reload": 2.9,
		"projectile": Color("#d6e9ff"), "tint": Color(0.56, 0.62, 0.70), "scale": 1.0, "speed": 2.6,
	},
	&"dissenting_wardens": {
		"name": "Dissenting Wardens", "faction": "Druids", "role": Role.MELEE,
		"hp_scale": 1.15, "attack": {D.MELEE: 30.0, D.NATURE: 8.0}, "primary": [D.MELEE, D.NATURE],
		"base": {D.NATURE: 12},
		"tint": Color(0.78, 0.66, 0.58), "scale": 1.02, "speed": 2.6,
	},
	# Elves of the Moonwash Coast.
	&"wavecutters": {
		"name": "Wavecutters", "faction": "Elves", "role": Role.MELEE,
		"hp_scale": 0.95, "attack": {D.MELEE: 31.0, D.ICE: 9.0}, "primary": [D.MELEE, D.ICE],
		"base": {D.ICE: 12}, "slash_speed": 1.65,
		"tint": Color(0.76, 0.90, 1.0), "scale": 1.03, "speed": 3.0,
	},
	&"tide_archers": {
		"name": "Tide Archers", "faction": "Elves", "role": Role.RANGED,
		"hp_scale": 0.8, "attack": {D.RANGED: 24.0, D.ICE: 9.0}, "melee": {D.MELEE: 17.0},
		"primary": [D.RANGED, D.ICE], "range": 19.0, "reload": 2.4,
		"projectile": Color("#bff3ff"), "tint": Color(0.66, 0.84, 0.92), "scale": 1.02, "speed": 3.0,
	},
	&"pilots": {
		"name": "Brineholt Pilots", "faction": "Elves", "role": Role.CIVILIAN,
		"hp_scale": 0.6, "attack": {}, "primary": [D.MELEE],
		"tint": Color(0.70, 0.78, 0.74), "scale": 0.98, "speed": 2.7,
	},
	# Dryads of the Deepwood.
	&"thornkin": {
		"name": "Thornkin", "faction": "Dryads", "role": Role.MELEE,
		"hp_scale": 1.4, "attack": {D.MELEE: 24.0, D.NATURE: 15.0}, "primary": [D.NATURE, D.MELEE],
		"base": {D.NATURE: 18}, "slash_speed": 1.25,
		"tint": Color(0.60, 0.74, 0.42), "scale": 1.08, "speed": 2.5,
	},
	&"sporecasters": {
		"name": "Sporecasters", "faction": "Dryads", "role": Role.RANGED,
		"hp_scale": 0.85, "attack": {D.NATURE: 30.0}, "melee": {D.MELEE: 15.0},
		"primary": [D.NATURE], "range": 16.0, "reload": 2.7,
		"projectile": Color("#c7f28b"), "tint": Color(0.74, 0.80, 0.50), "scale": 1.0, "speed": 2.6,
	},
	# Undead of the Still Kingdom.
	&"ossuary_guard": {
		"name": "Ossuary Guard", "faction": "Undead", "role": Role.MELEE,
		"hp_scale": 1.2, "attack": {D.MELEE: 28.0, D.CURSE: 12.0}, "primary": [D.MELEE, D.CURSE],
		"base": {D.CURSE: 20},
		"tint": Color(0.70, 0.64, 0.78), "scale": 1.02, "speed": 2.55,
	},
	&"vigil_casters": {
		"name": "Vigil Casters", "faction": "Undead", "role": Role.RANGED,
		"hp_scale": 0.85, "attack": {D.CURSE: 31.0}, "melee": {D.MELEE: 15.0},
		"primary": [D.CURSE], "range": 16.0, "reload": 2.8,
		"projectile": Color("#c79bff"), "tint": Color(0.55, 0.50, 0.66), "scale": 1.0, "speed": 2.55,
	},
	&"restless_dead": {
		"name": "Restless Dead", "faction": "Undead", "role": Role.MELEE,
		"hp_scale": 0.8, "attack": {D.MELEE: 22.0, D.CURSE: 12.0}, "primary": [D.CURSE, D.MELEE],
		"base": {D.CURSE: 25}, "slash_speed": 1.2,
		"tint": Color(0.46, 0.52, 0.50), "scale": 0.98, "speed": 2.3,
	},
}

## Officers who lead from the front. Player leaders also carry an officer ability.
const HEROES: Dictionary = {
	&"sova": {
		"name": "Sova Cairn", "faction": "Druids", "role": Role.HERO, "hp_scale": 7.0,
		"attack": {D.MELEE: 44.0, D.NATURE: 30.0}, "primary": [D.NATURE, D.MELEE, D.LIGHTNING],
		"base": {D.NATURE: 15}, "tint": Color(0.70, 0.72, 0.66), "scale": 1.12, "speed": 4.4,
		"ability": &"stone_ward", "ability_name": "Stone Ward", "ability_cooldown": 20.0,
	},
	&"ilyra": {
		"name": "Ilyra Venn", "faction": "Elves", "role": Role.HERO, "hp_scale": 6.5,
		"attack": {D.MELEE: 52.0, D.ICE: 24.0}, "primary": [D.MELEE, D.ICE],
		"base": {D.ICE: 15}, "tint": Color(0.82, 0.93, 1.0), "scale": 1.1, "speed": 4.8,
		"slash_speed": 2.2,
		"ability": &"tidal_surge", "ability_name": "Tidal Surge", "ability_cooldown": 18.0,
	},
	&"mara": {
		"name": "Mara Halden", "faction": "Humans", "role": Role.HERO, "hp_scale": 7.0,
		"attack": {D.MELEE: 62.0, D.HOLY: 14.0}, "primary": [D.MELEE, D.HOLY],
		"base": {D.MELEE: 5}, "tint": Color(1.0, 0.86, 0.66), "scale": 1.12, "speed": 4.5,
		"ability": &"royal_rally", "ability_name": "Royal Rally", "ability_cooldown": 24.0,
	},
	&"raska": {
		"name": "Raska Vennor", "faction": "Orcs", "role": Role.HERO, "hp_scale": 8.0,
		"attack": {D.MELEE: 66.0, D.FIRE: 12.0}, "primary": [D.MELEE, D.FIRE],
		"base": {D.MELEE: 8}, "tint": Color(0.66, 0.86, 0.50), "scale": 1.26, "speed": 4.3,
		"ability": &"well_keepers_roar", "ability_name": "Well-keeper's Roar", "ability_cooldown": 18.0,
	},
	&"neris": {
		"name": "Neris Alder", "faction": "Dryads", "role": Role.HERO, "hp_scale": 7.5,
		"attack": {D.MELEE: 40.0, D.NATURE: 34.0}, "primary": [D.NATURE, D.MELEE],
		"base": {D.NATURE: 20}, "tint": Color(0.68, 0.82, 0.50), "scale": 1.12, "speed": 4.4,
		"ability": &"rootbind", "ability_name": "Rootbind", "ability_cooldown": 20.0,
	},
	&"sereth": {
		"name": "Sereth Vale", "faction": "Undead", "role": Role.HERO, "hp_scale": 6.5,
		"attack": {D.MELEE: 42.0, D.CURSE: 34.0}, "primary": [D.CURSE, D.MELEE],
		"base": {D.CURSE: 20}, "tint": Color(0.74, 0.66, 0.84), "scale": 1.12, "speed": 4.4,
		"ability": &"grave_toll", "ability_name": "Grave Toll", "ability_cooldown": 20.0,
	},
	# Enemy and allied officers.
	&"durga": {
		"name": "Durga Ashtusk", "faction": "Orcs", "role": Role.HERO, "hp_scale": 4.0,
		"attack": {D.MELEE: 54.0}, "primary": [D.MELEE], "tint": Color(0.74, 0.86, 0.50), "scale": 1.24, "speed": 3.6,
	},
	&"aldric": {
		"name": "Ser Aldric Thorne", "faction": "Humans", "role": Role.HERO, "hp_scale": 4.0,
		"attack": {D.MELEE: 54.0}, "primary": [D.MELEE], "tint": Color(1.0, 0.92, 0.78), "scale": 1.1, "speed": 3.6,
	},
	&"brannoc": {
		"name": "Ser Brannoc Hale", "faction": "Humans", "role": Role.HERO, "hp_scale": 4.5,
		"attack": {D.MELEE: 56.0}, "primary": [D.MELEE], "base": {D.MELEE: 10},
		"tint": Color(0.58, 0.68, 1.0), "scale": 1.12, "speed": 3.6,
	},
	&"orla": {
		"name": "Keeper Orla Thane", "faction": "Druids", "role": Role.HERO, "hp_scale": 4.2,
		"attack": {D.MELEE: 40.0, D.NATURE: 18.0}, "primary": [D.NATURE, D.MELEE], "base": {D.NATURE: 15},
		"tint": Color(0.86, 0.72, 0.62), "scale": 1.08, "speed": 3.6,
	},
	&"rook": {
		"name": "Captain Wystan Rook", "faction": "Humans", "role": Role.HERO, "hp_scale": 4.2,
		"attack": {D.MELEE: 54.0}, "primary": [D.MELEE], "tint": Color(0.50, 0.56, 0.80), "scale": 1.1, "speed": 3.7,
	},
	&"corvin": {
		"name": "Corvin Ashe", "faction": "Humans", "role": Role.HERO, "hp_scale": 4.5,
		"attack": {D.MELEE: 34.0, D.LIGHTNING: 26.0}, "primary": [D.LIGHTNING, D.MELEE],
		"tint": Color(0.52, 0.46, 0.62), "scale": 1.06, "speed": 3.6,
	},
	&"drowned_choir": {
		"name": "The Drowned Choir", "faction": "Undead", "role": Role.HERO, "hp_scale": 5.0,
		"attack": {D.MELEE: 36.0, D.CURSE: 28.0}, "primary": [D.CURSE, D.MELEE], "base": {D.CURSE: 25},
		"tint": Color(0.40, 0.56, 0.58), "scale": 1.3, "speed": 3.4,
	},
	&"skarn": {
		"name": "Skarn Emberhand", "faction": "Orcs", "role": Role.HERO, "hp_scale": 4.2,
		"attack": {D.MELEE: 46.0, D.FIRE: 18.0}, "primary": [D.MELEE, D.FIRE],
		"tint": Color(0.96, 0.56, 0.38), "scale": 1.2, "speed": 3.7,
	},
	&"gorrum": {
		"name": "Gorrum Saltjaw", "faction": "Orcs", "role": Role.HERO, "hp_scale": 6.0,
		"attack": {D.MELEE: 60.0, D.FIRE: 16.0}, "primary": [D.MELEE, D.FIRE], "base": {D.MELEE: 10},
		"tint": Color(0.98, 0.62, 0.44), "scale": 1.32, "speed": 3.6,
	},
	&"isolde": {
		"name": "Queen Isolde Varr", "faction": "Humans", "role": Role.HERO, "hp_scale": 6.5,
		"attack": {D.MELEE: 58.0, D.HOLY: 16.0}, "primary": [D.MELEE, D.HOLY], "base": {D.MELEE: 12},
		"tint": Color(0.70, 0.78, 1.0), "scale": 1.14, "speed": 3.8,
	},
	&"edrin": {
		"name": "Edrin Coll", "faction": "Humans", "role": Role.CIVILIAN, "hp_scale": 6.0,
		"attack": {}, "primary": [D.MELEE], "tint": Color(0.72, 0.62, 0.52), "scale": 1.0, "speed": 2.6,
	},
}

## Destructible and escorted objects on the battlefield.
const STRUCTURES: Dictionary = {
	&"wagon": {"name": "Bridle wagon", "hp": 26000.0, "radius": 1.5},
	&"pavilion": {"name": "Pavilion", "hp": 22000.0, "radius": 2.6},
	&"stone": {"name": "Listening stone", "hp": 26000.0, "radius": 1.1},
	&"ship": {"name": "Stranded ship", "hp": 30000.0, "radius": 3.0},
	&"heart_tree": {"name": "Heart tree", "hp": 30000.0, "radius": 1.9},
	&"signal_fire": {"name": "Signal fire", "hp": 24000.0, "radius": 1.3},
	&"root_bridge": {"name": "Bridge root", "hp": 32000.0, "radius": 1.8},
	&"gate": {"name": "Vault door", "hp": 50000.0, "radius": 3.2},
}


static func definition(type_id: StringName) -> Dictionary:
	if TYPES.has(type_id):
		return TYPES[type_id]
	return HEROES.get(type_id, {})


## Builds one unit at a level. Earned points go to the type's primary ratings in turn.
static func make_unit(type_id: StringName, level: int, hp_override: float = 0.0) -> Unit:
	var info := definition(type_id)
	var ratings := {}
	for type in Unit.Damage.values():
		ratings[type] = Unit.MIN_RATING
	var base: Dictionary = info.get("base", {})
	for type in base:
		ratings[type] = Unit.MIN_RATING + int(base[type])
	var hp := hp_override if hp_override > 0.0 else Unit.STARTING_HP * float(info.get("hp_scale", 1.0))
	var unit := Unit.new(hp, ratings)
	award_levels(unit, level, info.get("primary", [D.MELEE]))
	return unit


static func award_levels(unit: Unit, level: int, primary: Array) -> void:
	level = clampi(level, 1, Unit.MAX_LEVEL)
	while unit.level < level:
		unit.award_experience(unit.experience_for_next_level() - unit.experience)
	var turn := 0
	var attempts := 0
	while unit.stat_points > 0 and attempts < 400:
		unit.spend_stat_point(primary[turn % primary.size()])
		turn += 1
		attempts += 1


## Total XP needed to reach a level from level 1.
static func xp_for_level(level: int) -> int:
	var total := 0
	for l in range(1, clampi(level, 1, Unit.MAX_LEVEL)):
		total += Unit.FIRST_LEVEL_XP + Unit.LEVEL_XP_STEP * (l - 1)
	return total


static func level_for_xp(total_xp: int) -> int:
	var level := 1
	while level < Unit.MAX_LEVEL and total_xp >= xp_for_level(level + 1):
		level += 1
	return level
