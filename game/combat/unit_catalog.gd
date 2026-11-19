extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")

const HUMAN_INFANTRY := &"human_infantry"

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
			&"Sword Slash": {"headroom": 0.62, "travel": 0.52},
			&"Sword Recoil": {"headroom": 0.20, "travel": 0.52},
		},
		"equipment": {
			"main_hand": &"sword",
			"off_hand": &"shield",
		},
		"starting_hp": Unit.STARTING_HP,
		"ratings": {
			Unit.Damage.MELEE: 15,
			Unit.Damage.RANGED: 0,
			Unit.Damage.FIRE: 0,
			Unit.Damage.LIGHTNING: 0,
			Unit.Damage.ICE: 0,
			Unit.Damage.NATURE: 0,
			Unit.Damage.HOLY: 0,
			Unit.Damage.CURSE: 0,
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
}
