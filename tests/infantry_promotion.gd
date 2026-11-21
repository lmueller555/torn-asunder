extends SceneTree

const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const REGULAR := Catalog.HUMAN_INFANTRY
const HEAVY := Catalog.HUMAN_HEAVY_INFANTRY
const MELEE := Unit.Damage.MELEE


func _initialize() -> void:
	var eligibility_passed := _check_eligibility()
	var profile_passed := _check_profile()
	quit(0 if eligibility_passed and profile_passed else 1)


func _check_eligibility() -> bool:
	var unit := _unit_at(REGULAR, 9, 8)
	if unit.rating(MELEE) != 9 or Catalog.can_promote(REGULAR, HEAVY, unit):
		push_error("Melee rating 9 must not unlock Heavy Infantry.")
		return false
	unit.award_experience(unit.experience_for_next_level())
	if unit.level != 10 or unit.stat_points != 1 or Catalog.can_promote(REGULAR, HEAVY, unit):
		push_error("Gaining the level without spending its point must not unlock Heavy Infantry.")
		return false
	unit.spend_stat_point(MELEE)
	if unit.rating(MELEE) != 10 or not Catalog.can_promote(REGULAR, HEAVY, unit):
		push_error("Melee rating 10 must unlock Heavy Infantry.")
		return false

	var wrong_build := _unit_at(REGULAR, 11, 8)
	wrong_build.spend_stat_point(Unit.Damage.HOLY)
	wrong_build.spend_stat_point(Unit.Damage.RANGED)
	if Catalog.can_promote(REGULAR, HEAVY, wrong_build) or Catalog.can_promote(HEAVY, HEAVY, unit) \
			or Catalog.can_promote(HEAVY, REGULAR, unit) or Catalog.can_promote(&"unknown", HEAVY, unit) \
			or Catalog.can_promote(REGULAR, &"unknown", unit) or Catalog.can_promote(REGULAR, HEAVY, null):
		push_error("An unqualified build or unsupported promotion was accepted.")
		return false
	unit.award_experience(unit.experience_for_next_level())
	unit.spend_stat_point(MELEE)
	var hp := unit.hp
	if not Catalog.can_promote(REGULAR, HEAVY, unit) or unit.hp != hp or unit.level != 11 \
			or unit.stat_points != 0 or unit.rating(MELEE) != 11:
		push_error("Checking Heavy Infantry eligibility changed the source or rejected a higher rating.")
		return false

	print("Verified the melee threshold, alternative investment, and unsupported promotion checks.")
	return true


func _check_profile() -> bool:
	var regular_profile: Dictionary = Catalog.TYPES[REGULAR]
	var heavy_profile: Dictionary = Catalog.TYPES[HEAVY]
	var regular := _unit_at(REGULAR, 10, 9)
	var heavy := _unit_at(HEAVY, 10, 9)
	var regular_output := regular.damage_from(regular, regular_profile.basic_attack)
	var heavy_output := regular.damage_from(heavy, heavy_profile.basic_attack)
	var heavy_incoming := heavy.damage_from(regular, regular_profile.basic_attack)
	if heavy.max_hp <= regular.max_hp or heavy_output >= regular_output \
			or heavy_incoming / heavy.max_hp >= regular_output / regular.max_hp \
			or heavy_profile.movement_scale >= regular_profile.movement_scale:
		push_error("Heavy Infantry must gain staying power at the cost of sword damage and mobility.")
		return false

	# Maximum melee offense vs minimum defense bounds these basic attacks at each level.
	# For Heavy defenders, rating 1 is stricter than the eligible rating 10.
	for level in range(10, Unit.MAX_LEVEL + 1):
		for source_type: StringName in [REGULAR, HEAVY]:
			var attacker := _unit_at(source_type, level, level - 1)
			var attack: Dictionary = Catalog.TYPES[source_type].basic_attack
			for target_type: StringName in [REGULAR, HEAVY]:
				var target := _unit_at(target_type, level, 0)
				var damage := target.receive_hit(attacker, attack)
				if damage <= 0.0 or not target.is_alive():
					push_error("Invalid basic attack at level %d: %s attacking %s." % [level, source_type, target_type])
					return false

	print("Verified the line-holder tradeoff and 360 same-level maximum-offense matchups.")
	return true


func _unit_at(type: StringName, level: int, melee_points: int) -> Unit:
	var definition: Dictionary = Catalog.TYPES[type]
	var unit := Unit.new(definition.starting_hp, Catalog.TYPES[REGULAR].ratings)
	for i in range(1, level):
		unit.award_experience(unit.experience_for_next_level())
	for i in range(melee_points):
		unit.spend_stat_point(MELEE)
	return unit
