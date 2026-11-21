extends SceneTree

const Defense := preload("res://game/combat/hero_defense.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Phase := Defense.Phase
const Outcome := Defense.HitOutcome
const LIGHT := Attack.Attack.LIGHT
const DAMAGE := {Unit.Damage.MELEE: 40.0, Unit.Damage.FIRE: 10.0}


func _initialize() -> void:
	var passed := _check_guard()
	passed = _check_dodge() and passed
	passed = _check_attack_gates() and passed
	passed = _check_cleanup() and passed
	if passed:
		print("Verified frontal guard, dodge timing/travel, attack gates, and battle/death cleanup.")
	quit(0 if passed else 1)


func _check_guard() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var defense := Defense.new(hero, 0, null)
	var full_damage := hero.damage_from(enemy, DAMAGE)
	if not defense.set_guard(true, true) or defense.phase != Phase.GUARD:
		return _fail("A living, free hero could not start guarding.")
	var front := _hit(defense, enemy)
	if front.outcome != Outcome.GUARDED or not is_equal_approx(front.hp_lost, full_damage * Defense.GUARD_DAMAGE_FRACTION):
		return _fail("Frontal guard failed to reduce damage while still taking chip damage.")
	var rear := _hit(defense, enemy, Vector2.LEFT)
	if rear.outcome != Outcome.HIT or not is_equal_approx(rear.hp_lost, full_damage):
		return _fail("Guard incorrectly reduced a rear hit.")
	var side := _hit(defense, enemy, Vector2.UP)
	if side.outcome != Outcome.HIT or not is_equal_approx(side.hp_lost, full_damage):
		return _fail("Guard incorrectly reduced a side hit.")
	defense.set_guard(false, true)
	if defense.phase != Phase.FREE or _hit(defense, enemy).outcome != Outcome.HIT:
		return _fail("Releasing guard continued to reduce attacks.")
	var hp := hero.hp
	if defense.resolve_incoming_hit(enemy, 0, DAMAGE, true, Vector2.RIGHT, Vector2.RIGHT).outcome != Outcome.IGNORED:
		return _fail("A friendly contact counted as an enemy hit.")
	if defense.resolve_incoming_hit(enemy, 1, {}, true, Vector2.RIGHT, Vector2.RIGHT).outcome != Outcome.IGNORED:
		return _fail("Zero damage counted as an incoming hit.")
	if hero.hp != hp:
		return _fail("Ignored contacts altered HP.")
	return true


func _check_dodge() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var defense := Defense.new(hero, 0, null)
	if defense.start_dodge(Vector2.ZERO, true) or not defense.set_guard(true, true):
		return _fail("Zero dodge input began a dodge or locked guard.")
	if not defense.start_dodge(Vector2(2.0, 0.0), true) or defense.phase != Phase.DODGE_STARTUP:
		return _fail("The hero could not leave guard for a directional dodge.")
	if _hit(defense, enemy).outcome != Outcome.HIT:
		return _fail("The hero was invulnerable during dodge startup.")
	if defense.advance_defense(Defense.DODGE_STARTUP, true) != Vector2.ZERO or defense.phase != Phase.DODGE_ACTIVE:
		return _fail("Dodge movement began in startup or missed the active window boundary.")
	var hp := hero.hp
	if _hit(defense, enemy).outcome != Outcome.EVADED or hero.hp != hp:
		return _fail("A confirmed enemy hit leaked through the active evade window.")
	if defense.set_guard(true, true) or defense.start_dodge(Vector2.LEFT, true):
		return _fail("Guard or repeated dodge input reset an evade in progress.")
	var travel := defense.advance_defense(Defense.DODGE_ACTIVE, true)
	if not travel.is_equal_approx(Vector2.RIGHT * Defense.DODGE_TRAVEL) or defense.phase != Phase.DODGE_RECOVERY:
		return _fail("Dodge travel was not bounded to the chosen direction and time.")
	if _hit(defense, enemy).outcome != Outcome.HIT or defense.start_dodge(Vector2.LEFT, true):
		return _fail("Dodge recovery offered immunity or admitted a new dodge.")
	if defense.advance_defense(Defense.DODGE_RECOVERY, true) != Vector2.ZERO or defense.phase != Phase.FREE:
		return _fail("Recovery moved the hero or failed to release the dodge lock.")
	if not defense.start_dodge(Vector2.UP, true):
		return _fail("A fresh dodge was not admitted after recovery.")
	travel = defense.advance_defense(10.0, true)
	if not travel.is_equal_approx(Vector2.UP * Defense.DODGE_TRAVEL) or defense.phase != Phase.FREE:
		return _fail("A large tick skipped or repeated dodge travel.")
	return true


func _check_attack_gates() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var defense := Defense.new(hero, 0, null)
	defense.set_guard(true, true)
	if defense.start_attack(LIGHT, true):
		return _fail("An attack started while guard was held.")
	defense.set_guard(false, true)
	if not defense.start_attack(LIGHT, true):
		return _fail("A basic attack could not start after releasing guard.")
	if defense.set_guard(true, true) or defense.start_dodge(Vector2.RIGHT, true):
		return _fail("Defense interrupted an attack windup.")
	var profile: Dictionary = Attack.PROFILES[LIGHT]
	var hit := defense.advance_attack(profile.windup, true, Vector2.ZERO, Vector2.RIGHT, enemy, 1, Vector2.RIGHT)
	if not hit or hit.hp_lost <= 0.0 or defense.attack_phase != Attack.Phase.RECOVERY:
		return _fail("The wrapped attack did not resolve through existing combat.")
	if defense.set_guard(true, true) or defense.start_dodge(Vector2.RIGHT, true):
		return _fail("Defense skipped attack recovery.")
	defense.advance_attack(profile.recovery, true, Vector2.ZERO, Vector2.RIGHT)
	if not defense.start_dodge(Vector2.RIGHT, true) or defense.start_attack(LIGHT, true):
		return _fail("A dodge did not wait for recovery or allowed an overlapping attack.")
	defense.advance_defense(1.0, true)
	if not defense.start_attack(LIGHT, true):
		return _fail("Attack remained locked after dodge recovery.")
	return true


func _check_cleanup() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var defense := Defense.new(hero, 0, null)
	if not defense.start_dodge(Vector2.RIGHT, true):
		return _fail("Could not start the cleanup fixture's dodge.")
	defense.advance_defense(NAN, true)
	defense.advance_defense(-1.0, true)
	if defense.phase != Phase.DODGE_STARTUP:
		return _fail("Invalid time advanced a dodge.")
	defense.advance_defense(Defense.DODGE_STARTUP, true)
	if defense.advance_defense(1.0, false) != Vector2.ZERO or defense.phase != Phase.FREE:
		return _fail("Ending the battle preserved active dodge or movement.")
	if defense.set_guard(true, false) or defense.start_dodge(Vector2.RIGHT, false):
		return _fail("A new defense action began after the battle ended.")
	if defense.resolve_incoming_hit(enemy, 1, DAMAGE, false, Vector2.RIGHT, Vector2.RIGHT).outcome != Outcome.IGNORED:
		return _fail("A hit resolved after the battle ended.")
	defense.set_guard(true, true)
	hero.receive_damage(hero.hp)
	defense.advance_defense(0.1, true)
	if defense.phase != Phase.FREE or defense.set_guard(true, true) or defense.start_attack(LIGHT, true):
		return _fail("A defeated hero held guard or started another action.")
	if _hit(defense, enemy).outcome != Outcome.IGNORED:
		return _fail("An incoming hit resolved on a defeated hero.")
	return true


func _hit(defense: Defense, enemy: Unit, source: Vector2 = Vector2.RIGHT) -> Defense.IncomingHit:
	return defense.resolve_incoming_hit(enemy, 1, DAMAGE, true, Vector2.RIGHT, source)


func _fail(message: String) -> bool:
	push_error(message)
	return false
