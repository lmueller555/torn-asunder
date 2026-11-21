class_name HeroDefense
extends RefCounted
## Hero attack admission, held guard, and directional dodge. No scene dependencies.

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Attacks := preload("res://game/combat/hero_attack_sequence.gd")

enum Phase { FREE, GUARD, DODGE_STARTUP, DODGE_ACTIVE, DODGE_RECOVERY }
enum HitOutcome { IGNORED, HIT, GUARDED, EVADED }

# Provisional hero-only tuning. Guard always lets chip damage through.
const GUARD_MIN_FORWARD_DOT := 0.5
const GUARD_DAMAGE_FRACTION := 0.30
const DODGE_STARTUP := 0.08
const DODGE_ACTIVE := 0.20
const DODGE_RECOVERY := 0.27
const DODGE_TRAVEL := 2.20
const DODGE_ACTIVE_END := DODGE_STARTUP + DODGE_ACTIVE
const DODGE_END := DODGE_ACTIVE_END + DODGE_RECOVERY


class IncomingHit:
	var outcome := HitOutcome.IGNORED
	var hp_lost := 0.0


var phase: Phase:
	get:
		return _phase
var attack_phase: Attacks.Phase:
	get:
		return _attacks.phase
var attack_kind: Attacks.Attack:
	get:
		return _attacks.attack

var _hero: Unit
var _team: int
var _attacks: Attacks
var _phase := Phase.FREE
var _dodge_time := 0.0
var _dodge_direction := Vector2.ZERO


func _init(hero: Unit, team: int, shared_points: Points) -> void:
	_hero = hero
	_team = team
	_attacks = Attacks.new(hero, team, shared_points)


func start_attack(kind: Attacks.Attack, battle_live: bool) -> bool:
	return _phase == Phase.FREE and _attacks.start(kind, battle_live)


func attack_progress() -> float:
	return _attacks.phase_progress()


func advance_attack(
	delta: float, battle_live: bool, hero_position: Vector2, hero_facing: Vector2,
	target: Unit = null, target_team: int = -1, target_position: Vector2 = Vector2.ZERO
) -> Attacks.Contact:
	return _attacks.advance(delta, battle_live, hero_position, hero_facing, target, target_team, target_position)


# Sample the guard button state; repeats never restart a dodge or skip recovery.
func set_guard(held: bool, battle_live: bool) -> bool:
	if not _hero_is_active(battle_live):
		_clear_defense()
		return false
	if _phase != Phase.FREE and _phase != Phase.GUARD:
		return false
	if not held or _attacks.phase != Attacks.Phase.IDLE:
		_phase = Phase.FREE
		return false
	_phase = Phase.GUARD
	return true


# The controller supplies a direction, using facing when thumbstick input is neutral.
func start_dodge(direction: Vector2, battle_live: bool) -> bool:
	if not _hero_is_active(battle_live) or _attacks.phase != Attacks.Phase.IDLE:
		return false
	if _phase != Phase.FREE and _phase != Phase.GUARD:
		return false
	if not direction.is_finite() or direction.is_zero_approx():
		return false
	_phase = Phase.DODGE_STARTUP
	_dodge_time = 0.0
	_dodge_direction = direction.normalized()
	return true


# Returns desired ground-plane travel for this tick; the field applies collision/bounds.
func advance_defense(delta: float, battle_live: bool) -> Vector2:
	if not _hero_is_active(battle_live):
		_clear_defense()
		return Vector2.ZERO
	if _phase == Phase.FREE or _phase == Phase.GUARD or not is_finite(delta) or delta <= 0.0:
		return Vector2.ZERO
	var before := clampf(_dodge_time - DODGE_STARTUP, 0.0, DODGE_ACTIVE)
	_dodge_time = minf(_dodge_time + delta, DODGE_END)
	var after := clampf(_dodge_time - DODGE_STARTUP, 0.0, DODGE_ACTIVE)
	var displacement := _dodge_direction * ((after - before) / DODGE_ACTIVE * DODGE_TRAVEL)
	if _dodge_time >= DODGE_END:
		_clear_defense()
	elif _dodge_time >= DODGE_ACTIVE_END:
		_phase = Phase.DODGE_RECOVERY
	elif _dodge_time >= DODGE_STARTUP:
		_phase = Phase.DODGE_ACTIVE
	return displacement


# Call only after the enemy contact has been confirmed by the field. The offset
# points from the hero to the attacker. All damage types retain existing scaling.
func resolve_incoming_hit(
	attacker: Unit, attacker_team: int, components: Dictionary, battle_live: bool,
	hero_facing: Vector2, toward_attacker: Vector2
) -> IncomingHit:
	var result := IncomingHit.new()
	if not _hero_is_active(battle_live) or attacker == null or attacker == _hero:
		return result
	if not attacker.is_alive() or attacker_team < 0 or attacker_team == _team:
		return result
	var damage := _hero.damage_from(attacker, components)
	if not is_finite(damage) or damage <= 0.0:
		return result
	if _phase == Phase.DODGE_ACTIVE:
		result.outcome = HitOutcome.EVADED
		return result
	if _phase == Phase.GUARD and _is_frontal(hero_facing, toward_attacker):
		result.outcome = HitOutcome.GUARDED
		damage *= GUARD_DAMAGE_FRACTION
	else:
		result.outcome = HitOutcome.HIT
	result.hp_lost = _hero.receive_damage(damage)
	return result


func _hero_is_active(battle_live: bool) -> bool:
	return battle_live and _team >= 0 and _hero != null and _hero.is_alive()


func _is_frontal(facing: Vector2, source: Vector2) -> bool:
	if not facing.is_finite() or not source.is_finite() or facing.is_zero_approx() or source.is_zero_approx():
		return false
	return facing.normalized().dot(source.normalized()) >= GUARD_MIN_FORWARD_DOT


func _clear_defense() -> void:
	_phase = Phase.FREE
	_dodge_time = 0.0
	_dodge_direction = Vector2.ZERO
