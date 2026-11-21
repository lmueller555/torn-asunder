extends SceneTree

const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const CASTER := 0
const UNTRAINED := Battle.PLATOON_SIZE
const ALLY_ONE := UNTRAINED + 1
const ALLY_TWO := UNTRAINED + 2
const ENEMY := 2 * Battle.PLATOON_SIZE
const COST := Battle.FIELD_BENEDICTION_BP_COST
const Status := Battle.AbilityStatus


func _initialize() -> void:
	var passed := _check_unit_healing()
	passed = _check_requirements_and_exact_payment() and passed
	passed = _check_invalid_orders() and passed
	if passed:
		print("Verified Field Benediction: Holy threshold, team ownership, BP payment, and bounded healing.")
	quit(0 if passed else 1)


func _check_unit_healing() -> bool:
	var unit := Unit.new(100.0)
	unit.receive_damage(20.5)
	if unit.receive_healing(-10.0) != 0.0 or unit.receive_healing(INF) != 0.0 or not is_equal_approx(unit.hp, 79.5):
		return _fail("Negative or non-finite healing changed a living unit.")
	if not is_equal_approx(unit.receive_healing(2.5), 2.5) or not is_equal_approx(unit.receive_healing(100.0), 18.0):
		return _fail("Healing lost fractional HP or reported more than it restored.")
	if unit.hp != unit.max_hp or unit.receive_healing(10.0) != 0.0:
		return _fail("Healing exceeded the target's max HP.")
	unit.receive_damage(unit.hp)
	if unit.receive_healing(100.0) != 0.0 or unit.is_alive():
		return _fail("Healing revived a defeated unit.")
	return true


func _check_requirements_and_exact_payment() -> bool:
	var battle := _battle()
	var blue := battle.battle_points_for_team(0)
	var amber := battle.battle_points_for_team(1)
	var target := battle.soldiers[ALLY_ONE].unit
	var lightly_wounded := battle.soldiers[ALLY_TWO].unit
	var threshold := Battle.FIELD_BENEDICTION_HOLY_RATING
	var start := blue.balance
	target.receive_damage(target.max_hp * 0.4)
	lightly_wounded.receive_damage(13.5)
	var wounded_hp := target.hp
	if battle.soldiers[UNTRAINED].unit.rating(Unit.Damage.HOLY) != threshold - 1:
		return _fail("Fixture did not build a caster just below the Holy requirement.")
	if battle.field_benediction_status(0, UNTRAINED, ALLY_ONE) != Status.STAT_REQUIREMENT:
		return _fail("The status did not identify the Holy requirement separately from BP.")
	if battle.field_benediction_status(0, CASTER, ALLY_ONE) != Status.READY or blue.balance != start or target.hp != wounded_hp:
		return _fail("The readiness preview was wrong or had side effects.")
	if battle.cast_field_benediction(0, UNTRAINED, ALLY_ONE) != 0.0 or blue.balance != start or target.hp != wounded_hp:
		return _fail("Enough BP bypassed the Holy requirement.")
	var expected := target.max_hp * Battle.FIELD_BENEDICTION_HEAL_FRACTION
	if not is_equal_approx(battle.cast_field_benediction(0, CASTER, ALLY_ONE), expected):
		return _fail("A caster at the exact Holy threshold could not heal another allied platoon.")
	if blue.balance != start - COST or amber.balance != start or not is_equal_approx(target.hp, wounded_hp + expected):
		return _fail("Successful healing did not update HP and only the caster team's pool.")
	blue.try_spend(blue.balance - COST, true)
	if not is_equal_approx(battle.cast_field_benediction(0, CASTER, ALLY_TWO), 13.5) or blue.balance != 0:
		return _fail("An exact-balance payment did not heal a target up to max HP.")
	if lightly_wounded.hp != lightly_wounded.max_hp:
		return _fail("Field Benediction failed to cap healing to missing HP.")
	blue.award_confirmed_hit(COST - 1)
	var still_wounded := target.hp
	if battle.field_benediction_status(0, CASTER, ALLY_ONE) != Status.INSUFFICIENT_BP:
		return _fail("The status did not identify insufficient BP for a qualified caster.")
	if battle.cast_field_benediction(0, CASTER, ALLY_ONE) != 0.0 or blue.balance != COST - 1 or target.hp != still_wounded:
		return _fail("A qualified caster healed without sufficient BP.")
	return true


func _check_invalid_orders() -> bool:
	var battle := _battle()
	var blue := battle.battle_points_for_team(0)
	var amber := battle.battle_points_for_team(1)
	var target := battle.soldiers[ALLY_ONE].unit
	var enemy := battle.soldiers[ENEMY].unit
	target.receive_damage(30.0)
	enemy.receive_damage(50.0)
	var target_hp := target.hp
	var enemy_hp := enemy.hp
	if battle.field_benediction_status(1, CASTER, ENEMY) != Status.INVALID_CASTER:
		return _fail("The status did not distinguish an unowned caster.")
	if battle.field_benediction_status(0, CASTER, ENEMY) != Status.INVALID_TARGET:
		return _fail("The status did not distinguish an enemy target.")
	if battle.field_benediction_status(0, CASTER, ALLY_TWO) != Status.UNHURT_TARGET:
		return _fail("The status did not distinguish an unhurt ally.")
	var rejected := [
		battle.cast_field_benediction(-1, CASTER, ALLY_ONE),
		battle.cast_field_benediction(0, -1, ALLY_ONE),
		battle.cast_field_benediction(0, CASTER, battle.soldiers.size()),
		battle.cast_field_benediction(1, CASTER, ENEMY),
		battle.cast_field_benediction(0, CASTER, ENEMY),
		battle.cast_field_benediction(0, CASTER, ALLY_TWO),
	]
	battle.soldiers[ALLY_TWO].unit.receive_damage(battle.soldiers[ALLY_TWO].unit.hp)
	rejected.append(battle.cast_field_benediction(0, CASTER, ALLY_TWO))
	battle.winner = 0
	if battle.field_benediction_status(0, CASTER, ALLY_ONE) != Status.BATTLE_ENDED:
		return _fail("The status did not identify a finished battle.")
	rejected.append(battle.cast_field_benediction(0, CASTER, ALLY_ONE))
	battle.winner = Battle.LIVE
	battle.soldiers[CASTER].unit.receive_damage(battle.soldiers[CASTER].unit.hp)
	rejected.append(battle.cast_field_benediction(0, CASTER, ALLY_ONE))
	for value: float in rejected:
		if value != 0.0:
			return _fail("An invalid, unauthorized, defeated, or post-battle order restored HP.")
	if blue.balance != 400 or amber.balance != 400 or target.hp != target_hp or enemy.hp != enemy_hp:
		return _fail("A rejected order altered a team's points or target HP.")
	if battle.soldiers[ALLY_TWO].unit.is_alive():
		return _fail("The spell revived a defeated ally.")
	return true


func _battle() -> Battle:
	var setup := Setup.new()
	setup.set_count(0, 2)
	var threshold := Battle.FIELD_BENEDICTION_HOLY_RATING
	var caster_build: Setup.PlatoonBuild = setup.sides[0][0]
	caster_build.level = threshold
	caster_build.set_points(Unit.Damage.HOLY, threshold - Unit.MIN_RATING)
	var untrained_build: Setup.PlatoonBuild = setup.sides[0][1]
	untrained_build.level = threshold
	untrained_build.set_points(Unit.Damage.HOLY, threshold - Unit.MIN_RATING - 1)
	return Battle.new(8, setup)


func _fail(message: String) -> bool:
	push_error(message)
	return false
