extends RefCounted
## Starting build for a newly begun Human campaign. This is not an XP grant,
## promotion, or saved discretionary spend; Retry reconstructs the same build.

const Unit := preload("res://game/combat/combat_unit.gd")

const INFANTRY_LEVEL := 12
const ARCHER_LEVEL := 11


static func level_unit(unit: Unit, target: int) -> void:
	while unit.level < mini(target, Unit.MAX_LEVEL):
		unit.award_experience(unit.experience_for_next_level() - unit.experience)


static func allocate_infantry(unit: Unit) -> void:
	level_unit(unit, INFANTRY_LEVEL)
	while unit.spend_stat_point(Unit.Damage.MELEE):
		pass


static func allocate_archer(unit: Unit) -> void:
	level_unit(unit, ARCHER_LEVEL)
	# The fixed Archer assignment has no Melee prerequisite above the
	# ordinary starting rating of 1. All ten banked points go to Ranged.
	while unit.spend_stat_point(Unit.Damage.RANGED):
		pass


static func infantry_progress(earned_xp: int) -> Unit:
	var unit := Unit.new()
	allocate_infantry(unit)
	unit.award_experience(earned_xp)
	return unit
