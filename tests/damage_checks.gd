extends SceneTree

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")

const BASE_DAMAGE: Array[float] = [0.0, 0.01, 0.5, 1.0, 25.0, 100.0, 2500.0, 100000.0]
const REFERENCE_BUILD: Array[Unit.Damage] = [
	Unit.Damage.MELEE, Unit.Damage.RANGED, Unit.Damage.FIRE, Unit.Damage.LIGHTNING, Unit.Damage.ICE,
]


func _initialize() -> void:
	var matchups_passed := _check_matchups()
	var mixed_hit_passed := _check_mixed_hit()
	var bounds_passed := _check_bounds()
	var lethality_passed := _check_hits_to_defeat()
	var progression_passed := _check_progression()
	var passed := matchups_passed and mixed_hit_passed and bounds_passed and lethality_passed and progression_passed
	quit(0 if passed else 1)


func _check_matchups() -> bool:
	var cases := 0
	for type in Unit.Damage.values():
		for attacker_rating in range(101):
			var attacker := Unit.new(100.0, {type: attacker_rating})
			for defender_rating in range(101):
				var expected_factor := (100.0 + attacker_rating) / (100.0 + 0.2 * defender_rating)
				for base in BASE_DAMAGE:
					var target := Unit.new(4.0 * base + 1.0, {type: defender_rating})
					var actual := target.receive_hit(attacker, {type: base})
					var expected := base * expected_factor
					if not _same_damage(actual, expected):
						push_error("Type %d, base %s, ratings %d/%d: expected %s, got %s." % [
							type, base, attacker_rating, defender_rating, expected, actual,
						])
						return false
					cases += 1
	print("Passed %d damage cases across all eight types, all rating pairs, and eight base values." % cases)
	return true


func _check_mixed_hit() -> bool:
	var attacker := Unit.new(100.0, {Unit.Damage.RANGED: 75, Unit.Damage.FIRE: 20})
	var ratings := {Unit.Damage.RANGED: 25, Unit.Damage.FIRE: 80}
	var flaming_arrow := {Unit.Damage.RANGED: 60.0, Unit.Damage.FIRE: 40.0}

	var healthy := Unit.new(200.0, ratings)
	var resolved := healthy.receive_hit(attacker, flaming_arrow)
	if not _same_damage(resolved, 141.3793103448276):
		push_error("Mixed hit did not resolve to 141.3793 HP. Got %s." % resolved)
		return false

	var wounded := Unit.new(42.0, ratings)
	var platoon := Platoon.new([wounded, Unit.new(200.0)])
	var loss := platoon.hit_unit(0, attacker, flaming_arrow)
	var expected_health := Vector3(200.0, 0.0, 42.0) / 242.0
	if loss != 42.0 or wounded.is_alive() or not platoon.health_fractions().is_equal_approx(expected_health):
		push_error("The overkill cap or casualty share was incorrect.")
		return false
	if platoon.hit_unit(0, attacker, flaming_arrow) != 0.0 or platoon.cohesion != 78.0:
		push_error("A second hit against a casualty changed the platoon's state.")
		return false

	print("Passed mixed damage, actual HP loss, and the platoon casualty check.")
	return true


func _check_bounds() -> bool:
	var low := Unit.new(100.0, {Unit.Damage.CURSE: -25})
	var high := Unit.new(100.0, {Unit.Damage.CURSE: 250})
	var hit := {Unit.Damage.CURSE: 0.5, Unit.Damage.FIRE: -10.0}
	if not _same_damage(high.receive_hit(low, hit), 0.4166666666666667) or low.receive_hit(high, hit) != 1.0:
		push_error("Rating clamps or the fractional HP hit were incorrect.")
		return false
	if not _same_damage(high.hp, 99.58333333333333) or low.hp != 99.0:
		push_error("Fractional HP was not retained.")
		return false
	low.receive_hit(high, {Unit.Damage.CURSE: 100.0})
	if high.receive_hit(low, hit) != 0.0:
		push_error("A defeated unit dealt damage.")
		return false

	print("Passed rating clamps, zero or negative damage, fractional HP, and defeated attacker checks.")
	return true


func _check_hits_to_defeat() -> bool:
	var xp := 0
	for level in range(1, 100):
		var ratings := {}
		for point in range(level - 1):
			var type := REFERENCE_BUILD[point % REFERENCE_BUILD.size()]
			ratings[type] = int(ratings.get(type, 0)) + 5
		var attacker := Unit.new(Unit.STARTING_HP, ratings)
		attacker.award_experience(xp)
		var expected_hp := 1200.0 * (99.0 + level) / (99.8 + 0.2 * level)
		for type in REFERENCE_BUILD:
			var target := Unit.new(Unit.STARTING_HP, ratings)
			target.award_experience(xp)
			if target.level != level or not _same_damage(target.max_hp, expected_hp):
				push_error("The HP curve did not match at level %d." % level)
				return false
			var hits := _hits_to_defeat(attacker, target, type)
			if hits < 30 or hits > 31:
				push_error("Matched level %d units took %d hits for type %d." % [level, hits, type])
				return false
		xp += attacker.experience_for_next_level()

	if xp != 128_625:
		push_error("The XP curve did not reach level 99 at 128,625 XP.")
		return false

	# Check the endpoints, the first level at which specialization can reach 100, and cap-level builds.
	for example in [[0, 100, 0, 36], [50, 50, 0, 22], [100, 0, 0, 15],
			[100, 100, 6_750, 21], [100, 100, 128_625, 30], [0, 0, 128_625, 50]]:
		var attacker := Unit.new(Unit.STARTING_HP, {Unit.Damage.MELEE: example[0]})
		var target := Unit.new(Unit.STARTING_HP, {Unit.Damage.MELEE: example[1]})
		attacker.award_experience(example[2])
		target.award_experience(example[2])
		if _hits_to_defeat(attacker, target, Unit.Damage.MELEE) != example[3]:
			push_error("Incorrect hits to defeat at level %d and ratings %d/%d." % [
				target.level, example[0], example[1],
			])
			return false

	print("Passed 495 equal-level reference-build matchups, plus extreme and specialist builds.")
	return true


func _hits_to_defeat(attacker: Unit, target: Unit, type: Unit.Damage) -> int:
	for hit in range(1, 101):
		target.receive_hit(attacker, {type: 40.0})
		if not target.is_alive():
			return hit
	return 0


func _check_progression() -> bool:
	var unit := Unit.new(Unit.STARTING_HP, {Unit.Damage.FIRE: 98})
	if unit.spend_stat_point(Unit.Damage.MELEE) or unit.award_experience(-10) != 0:
		push_error("A new unit accepted an invalid investment or XP reward.")
		return false
	unit.receive_hit(Unit.new(), {Unit.Damage.MELEE: 40.0})
	if unit.award_experience(99) != 0 or unit.level != 1 or unit.experience != 99:
		push_error("A partial XP reward was handled incorrectly.")
		return false
	if unit.award_experience(151) != 2 or unit.level != 3 or unit.experience != 25:
		push_error("XP did not carry across multiple thresholds.")
		return false
	if not _same_damage(unit.max_hp, 1219.1235059760957) or not _same_damage(unit.hp, 1179.1235059760957) or unit.stat_points != 2:
		push_error("Automatic HP growth, wound preservation, or point awards were incorrect.")
		return false
	if unit.rating(Unit.Damage.MELEE) != 0 or unit.rating(Unit.Damage.FIRE) != 98:
		push_error("Leveling changed combat ratings before points were spent.")
		return false
	if not unit.spend_stat_point(Unit.Damage.FIRE) or unit.rating(Unit.Damage.FIRE) != 100:
		push_error("The Fire rating did not reach its cap when trained.")
		return false
	if unit.spend_stat_point(Unit.Damage.FIRE) or unit.stat_points != 1:
		push_error("A maxed rating consumed a point.")
		return false
	if not unit.spend_stat_point(Unit.Damage.MELEE) or unit.rating(Unit.Damage.MELEE) != 5 or unit.stat_points != 0:
		push_error("An allocated point did not increase the selected rating by 5.")
		return false
	if unit.award_experience(1_000_000) != 96 or unit.level != 99 or unit.experience != 0:
		push_error("The level cap was handled incorrectly.")
		return false
	if not _same_damage(unit.max_hp, 1986.6220735785955) or unit.stat_points != 96 or unit.award_experience(1_000_000) != 0:
		push_error("The unit earned the wrong HP or points at the level cap.")
		return false
	var at_cap := Unit.new()
	at_cap.award_experience(128_624)
	if at_cap.level != 98 or at_cap.experience != 2_524:
		push_error("A unit reached the level cap before earning enough XP.")
		return false
	if at_cap.award_experience(1) != 1 or at_cap.level != 99 or at_cap.stat_points != 98:
		push_error("The final XP threshold did not award level 99 and its point.")
		return false
	var casualty := Unit.new(1.0)
	casualty.receive_hit(Unit.new(), {Unit.Damage.MELEE: 40.0})
	casualty.award_experience(100)
	if casualty.is_alive():
		push_error("Leveling revived a defeated unit.")
		return false
	print("Passed XP thresholds, automatic HP growth, point allocation, and cap checks.")
	return true


func _same_damage(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= maxf(1.0e-10, absf(expected) * 1.0e-10)
