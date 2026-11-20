class_name SkirmishSetup
extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

const MAX_PLATOONS := 4


class PlatoonBuild:
	var level := 1:
		set = set_level

	# Preserve purchase order so reducing the level refunds the latest investments.
	var _investments: Array[Unit.Damage] = []

	func set_level(value: int) -> void:
		level = clampi(value, 1, Unit.MAX_LEVEL)
		if _investments.size() > level - 1:
			_investments.resize(level - 1)

	func points_for(type: Unit.Damage) -> int:
		return _investments.count(type)

	func rating(type: Unit.Damage) -> int:
		return _base_rating(type) + points_for(type)

	func remaining_points() -> int:
		return level - 1 - _investments.size()

	func set_points(type: Unit.Damage, value: int) -> void:
		if not Unit.Damage.values().has(type):
			return
		var current := points_for(type)
		var cap := Unit.MAX_RATING - _base_rating(type)
		var target := clampi(value, 0, mini(cap, current + remaining_points()))
		for i in range(current, target):
			_investments.append(type)
		for i in range(target, current):
			_investments.remove_at(_investments.rfind(type))

	func make_unit() -> Unit:
		var infantry: Dictionary = Catalog.TYPES[Catalog.HUMAN_INFANTRY]
		var unit := Unit.new(infantry.starting_hp, infantry.ratings)
		for gained_level in range(1, level):
			unit.award_experience(unit.experience_for_next_level())
		for type in _investments:
			unit.spend_stat_point(type)
		return unit

	func copy() -> PlatoonBuild:
		var result := PlatoonBuild.new()
		result.level = level
		result._investments.assign(_investments)
		return result

	func _base_rating(type: Unit.Damage) -> int:
		return Catalog.TYPES[Catalog.HUMAN_INFANTRY].ratings.get(type, Unit.MIN_RATING)


var sides: Array[Array] = []


func _init() -> void:
	for side in range(2):
		var roster: Array[PlatoonBuild] = [PlatoonBuild.new()]
		sides.append(roster)


func set_count(side: int, count: int) -> void:
	if side < 0 or side >= sides.size():
		return
	var roster: Array[PlatoonBuild] = sides[side]
	var target := clampi(count, 1, MAX_PLATOONS)
	while roster.size() < target:
		roster.append(PlatoonBuild.new())
	if roster.size() > target:
		roster.resize(target)


func copy() -> SkirmishSetup:
	var result := SkirmishSetup.new()
	for side in range(sides.size()):
		result.sides[side].clear()
		for build: PlatoonBuild in sides[side]:
			result.sides[side].append(build.copy())
	return result
