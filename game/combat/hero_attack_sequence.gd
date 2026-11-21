class_name HeroAttackSequence
extends RefCounted
## Timing and contact for one directly controlled basic attack at a time.

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")

enum Attack { LIGHT, HEAVY }
enum Phase { IDLE, WINDUP, RECOVERY }

# Prototype timings (seconds), reach (metres), damage, and BP, not global tuning.
const PROFILES := {
	Attack.LIGHT: {"windup": 0.22, "recovery": 0.30, "reach": 1.65, "damage": 60.0, "bp": 12},
	Attack.HEAVY: {"windup": 0.46, "recovery": 0.48, "reach": 2.10, "damage": 110.0, "bp": 20},
}
const MIN_FORWARD_DOT := 0.5


class Contact:
	var attack: Attack
	var hp_lost := 0.0
	var bp_credited := 0

	func _init(kind: Attack) -> void:
		attack = kind


var phase: Phase:
	get:
		return _phase
var attack: Attack:
	get:
		return _attack

var _hero: Unit
var _team: int
var _points: Points
var _phase := Phase.IDLE
var _attack := Attack.LIGHT
var _time := 0.0


func _init(hero: Unit, team: int, team_points: Points) -> void:
	_hero = hero
	_team = team
	_points = team_points


func start(kind: Attack, battle_live: bool) -> bool:
	if not battle_live or _hero == null or not _hero.is_alive() or _team < 0:
		return false
	if _phase != Phase.IDLE or not PROFILES.has(kind):
		return false
	_attack = kind
	_phase = Phase.WINDUP
	_time = 0.0
	return true


# The controller can read this alongside phase to drive a telegraph or animation.
func phase_progress() -> float:
	var profile: Dictionary = PROFILES[_attack]
	match _phase:
		Phase.WINDUP:
			return _time / profile.windup
		Phase.RECOVERY:
			return (_time - profile.windup) / profile.recovery
	return 0.0


# Positions/facing are on the battlefield's ground plane. Sample the current target
# only at contact. A non-null Contact reports the one attempt, even if it missed.
func advance(
	delta: float, battle_live: bool, hero_position: Vector2, hero_facing: Vector2,
	target: Unit = null, target_team: int = -1, target_position: Vector2 = Vector2.ZERO
) -> Contact:
	if _phase == Phase.IDLE:
		return null
	if not battle_live or not _hero.is_alive():
		_phase = Phase.IDLE
		return null
	if not is_finite(delta) or delta <= 0.0:
		return null

	var profile: Dictionary = PROFILES[_attack]
	_time += delta
	var contact: Contact
	if _phase == Phase.WINDUP and _time >= profile.windup:
		_phase = Phase.RECOVERY
		contact = _resolve_contact(profile, hero_position, hero_facing, target, target_team, target_position)
	if _time >= profile.windup + profile.recovery:
		_phase = Phase.IDLE
	return contact


func _resolve_contact(
	profile: Dictionary, hero_position: Vector2, hero_facing: Vector2,
	target: Unit, target_team: int, target_position: Vector2
) -> Contact:
	var contact := Contact.new(_attack)
	if target == null or target == _hero or not target.is_alive() or target_team < 0 or target_team == _team:
		return contact
	if not hero_position.is_finite() or not target_position.is_finite() or not hero_facing.is_finite():
		return contact
	if hero_facing.is_zero_approx():
		return contact
	var offset := target_position - hero_position
	var distance_squared := offset.length_squared()
	var reach: float = profile.reach
	if distance_squared > reach * reach:
		return contact
	if distance_squared > 0.0 and hero_facing.normalized().dot(offset.normalized()) < MIN_FORWARD_DOT:
		return contact
	contact.hp_lost = target.receive_hit(_hero, {Unit.Damage.MELEE: profile.damage})
	if contact.hp_lost > 0.0 and _points != null:
		contact.bp_credited = _points.award_confirmed_hit(profile.bp)
	return contact
