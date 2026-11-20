extends SceneTree

const Unit := preload("res://game/combat/combat_unit.gd")

const MELEE := Unit.Damage.MELEE
const BUILDS_PER_LEVEL := 48
const MIXED_TRIALS_PER_STRENGTH := 16_000
const SAMPLE_STRENGTHS: Array[float] = [20.0, 40.0, 80.0, 120.0, 200.0, 300.0, 450.0, 600.0]
const REPORT_LEVELS: Array[int] = [1, 10, 21, 50, 75, 99]

var _random := RandomNumberGenerator.new()
var _xp := PackedInt64Array()
var _hp := PackedFloat64Array()
var _previous_hp := PackedFloat64Array()
var _builds: Array[Array] = []


func _initialize() -> void:
	_random.seed = 82_719
	_prepare_levels()
	var singles_passed := _scan_melee_ratings()
	var boundaries_passed := _check_one_hit_boundaries()
	var mixtures_passed := _sample_mixed_hits()
	_compare_level_fifty()
	quit(0 if singles_passed and boundaries_passed and mixtures_passed else 1)


func _prepare_levels() -> void:
	_xp.resize(Unit.MAX_LEVEL + 1)
	_hp.resize(Unit.MAX_LEVEL + 1)
	_previous_hp.resize(Unit.MAX_LEVEL + 1)
	var unit := Unit.new()
	var total_xp := 0
	for level in range(1, Unit.MAX_LEVEL + 1):
		_xp[level] = total_xp
		_hp[level] = unit.max_hp
		var reference_rating := float(level - 1)
		_previous_hp[level] = Unit.STARTING_HP * Unit.damage_factor(reference_rating, reference_rating)
		var next_cost := unit.experience_for_next_level()
		unit.award_experience(next_cost)
		total_xp += next_cost


func _unit_at(level: int, ratings: Dictionary = {}) -> Unit:
	var unit := Unit.new(Unit.STARTING_HP, ratings)
	unit.award_experience(_xp[level])
	return unit


func _rating_cap(level: int) -> int:
	return mini(Unit.MAX_RATING, Unit.MIN_RATING + level - 1)


func _level_multiplier(attacking_level: int, defending_level: int) -> float:
	var attack := _hp[attacking_level] / _previous_hp[attacking_level]
	var defense := _hp[defending_level] / _previous_hp[defending_level]
	return attack * attack / defense


func _scan_melee_ratings() -> bool:
	var cases := 0
	for level in range(1, Unit.MAX_LEVEL + 1):
		var fewest := 100
		var most := 0
		var cap := _rating_cap(level)
		for attacker_rating in range(Unit.MIN_RATING, cap + 1):
			var attacker := _unit_at(level, {MELEE: attacker_rating})
			for defender_rating in range(Unit.MIN_RATING, cap + 1):
				var target := _unit_at(level, {MELEE: defender_rating})
				var dealt := target.receive_hit(attacker, {MELEE: 40.0})
				if not target.is_alive() or dealt <= 0.0:
					push_error("Unexpected 40-base result at level %d, ratings %d/%d." % [
						level, attacker_rating, defender_rating,
					])
					return false
				var previous_damage := 40.0 * Unit.damage_factor(attacker_rating, defender_rating)
				if not is_equal_approx(dealt / target.max_hp, previous_damage / _previous_hp[level]):
					push_error("The share of HP lost changed for matched level %d, ratings %d/%d." % [
						level, attacker_rating, defender_rating,
					])
					return false
				var hits := ceili(target.max_hp / dealt - 1.0e-10)
				fewest = mini(fewest, hits)
				most = maxi(most, hits)
				cases += 1
		if REPORT_LEVELS.has(level):
			print("Level %d, %.2f HP: %d–%d hits to defeat at 40 base." % [level, _hp[level], fewest, most])
	print("Verified the same share of HP lost in %d equal-level single-type rating matchups." % cases)
	return true


func _check_one_hit_boundaries() -> bool:
	var weakest_same_level := INF
	var weakest_level := 0
	var weakest_cross_level := INF
	var cases := 0
	for attacking_level in range(1, Unit.MAX_LEVEL + 1):
		var rating := _rating_cap(attacking_level)
		var attacker := _unit_at(attacking_level, {MELEE: rating})
		for defending_level in range(1, Unit.MAX_LEVEL + 1):
			# Maximum attainable offense against the minimum rating bounds every damage component.
			var factor := Unit.damage_factor(rating, Unit.MIN_RATING) * _level_multiplier(attacking_level, defending_level)
			var threshold := _hp[defending_level] / factor
			var survivor := _unit_at(defending_level)
			survivor.receive_hit(attacker, {MELEE: threshold - 0.01})
			var casualty := _unit_at(defending_level)
			casualty.receive_hit(attacker, {MELEE: threshold})
			if not survivor.is_alive() or casualty.is_alive():
				push_error("Incorrect one-hit boundary at levels %d/%d." % [attacking_level, defending_level])
				return false
			if attacking_level != defending_level:
				weakest_cross_level = minf(weakest_cross_level, threshold)
			elif threshold < weakest_same_level:
				weakest_same_level = threshold
				weakest_level = defending_level
			cases += 1
	print("Checked %d attacker/defender level pairs immediately below and at their one-hit thresholds." % cases)
	print("Lowest full-health one-hit thresholds: %.4f base across levels, %.4f base at equal level %d." % [
		weakest_cross_level, weakest_same_level, weakest_level,
	])
	return true


func _sample_mixed_hits() -> bool:
	_prepare_builds()
	for base in SAMPLE_STRENGTHS:
		var same_level_trials := 0
		var same_level_one_hits := 0
		var cross_level_one_hits := 0
		for trial in range(MIXED_TRIALS_PER_STRENGTH):
			var attacking_level := _random.randi_range(1, Unit.MAX_LEVEL)
			var defending_level := attacking_level if trial % 2 == 0 else _random.randi_range(1, Unit.MAX_LEVEL)
			var attacking_ratings: Dictionary = _builds[attacking_level][_random.randi_range(0, BUILDS_PER_LEVEL - 1)]
			var defending_ratings: Dictionary = _builds[defending_level][_random.randi_range(0, BUILDS_PER_LEVEL - 1)]
			var attacker := _unit_at(attacking_level, attacking_ratings)
			var target := _unit_at(defending_level, defending_ratings)
			var lost := target.receive_hit(attacker, _mixed_components(base))
			var maximum_damage := 2.0 * base * _level_multiplier(attacking_level, defending_level)
			if lost > maximum_damage + 1.0e-9:
				push_error("Mixed hit exceeded its damage bound at base %.0f." % base)
				return false
			if attacking_level == defending_level:
				same_level_trials += 1
				if not target.is_alive():
					if base < 300.0:
						push_error("A %.0f-base hit defeated a full-health level %d peer." % [base, defending_level])
						return false
					same_level_one_hits += 1
			elif not target.is_alive():
				cross_level_one_hits += 1
		print("Mixed hit at %3.0f total base: %d/%d same-level defeats, %d/%d cross-level defeats." % [
			base, same_level_one_hits, same_level_trials,
			cross_level_one_hits, MIXED_TRIALS_PER_STRENGTH - same_level_trials,
		])
	return true


func _prepare_builds() -> void:
	_builds.resize(Unit.MAX_LEVEL + 1)
	for level in range(1, Unit.MAX_LEVEL + 1):
		var profiles: Array[Dictionary] = []
		for index in range(BUILDS_PER_LEVEL):
			var unit := _unit_at(level)
			var available := Unit.Damage.values()
			for point in range(unit.stat_points if index != 0 else 0):
				var slot := _random.randi_range(0, available.size() - 1)
				if index % 3 == 0:
					# Spend about five out of six points on the current specialty until it reaches its cap.
					slot = slot if point % 6 == 5 else index % available.size()
				elif index % 3 == 1:
					slot = (index + point) % available.size()
				var type: Unit.Damage = available[slot]
				unit.spend_stat_point(type)
				if unit.rating(type) == Unit.MAX_RATING:
					available.remove_at(slot)
			var ratings := {}
			for type in Unit.Damage.values():
				ratings[type] = unit.rating(type)
			profiles.append(ratings)
		_builds[level] = profiles


func _mixed_components(base: float) -> Dictionary:
	var available := Unit.Damage.values()
	var components := {}
	var count := _random.randi_range(2, 4)
	var remaining := base
	for index in range(count):
		var damage := remaining if index == count - 1 else remaining * _random.randf_range(0.25, 0.75)
		var type: Unit.Damage = available.pop_at(_random.randi_range(0, available.size() - 1))
		components[type] = damage
		remaining -= damage
	return components


func _compare_level_fifty() -> void:
	var attacker := _unit_at(50, {MELEE: 50})
	for rating in [10, 40]:
		var target := _unit_at(50, {MELEE: rating})
		var damage := target.receive_hit(attacker, {MELEE: 40.0})
		var hits := ceili(target.max_hp / damage - 1.0e-10)
		print("Level 50, attacker 50 vs defender %d: %.4f damage, %d hits." % [rating, damage, hits])
