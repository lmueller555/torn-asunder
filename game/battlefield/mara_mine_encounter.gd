extends RefCounted
## One road guard, sharing the same terrain and fixed step as the command scene.

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

enum EnemyPhase { WATCHING, PURSUING, WINDUP, RECOVERY, DEFEATED }

const HERO_TEAM := 0
const ENEMY_TEAM := 1
const HERO_HP := 360.0
const ENEMY_HP := 260.0
const ENEMY_DAMAGE := 90.0
const CONTACT_RANGE := 1.75
const STOP_RANGE := 1.35
const BODY_CLEARANCE := 0.83
const AGGRO_RANGE := 8.0
const WINDUP_TIME := 0.66
const RECOVERY_TIME := 0.95
const ENEMY_SPEED := 2.9

var points := Points.new()
var hero := Unit.new(HERO_HP)
var enemy := Unit.new(ENEMY_HP)
var defense := Defense.new(hero, HERO_TEAM, points)
var enemy_position: Vector2
var enemy_heading := Vector2.LEFT
var enemy_phase := EnemyPhase.WATCHING
var last_contact := ""
var _enemy_seconds := 0.0
var _feedback_seconds := 0.0


func _init(spawn: Vector2) -> void:
	enemy_position = spawn


func advance(delta: float, battle: Battle, clear_contact: Callable, can_move: Callable) -> void:
	_feedback_seconds -= delta
	var sight := bool(clear_contact.call(battle.hero_position, enemy_position))
	var contact := defense.advance_attack(delta, true, battle.hero_position, battle.hero_heading,
		enemy if sight else null, ENEMY_TEAM, enemy_position)
	if contact:
		if contact.hp_lost > 0.0:
			_feedback("%s hit · +%d BP" % ["Light" if contact.attack == Attack.Attack.LIGHT else "Heavy", contact.bp_credited])
		else:
			_feedback("Attack missed")
	if not enemy.is_alive():
		enemy_phase = EnemyPhase.DEFEATED
		return
	if not hero.is_alive():
		return

	var toward := battle.hero_position - enemy_position
	var distance := toward.length()
	var direction := toward.normalized()
	match enemy_phase:
		EnemyPhase.WATCHING:
			if distance <= AGGRO_RANGE and sight:
				enemy_phase = EnemyPhase.PURSUING
		EnemyPhase.PURSUING:
			enemy_heading = direction
			if distance <= STOP_RANGE and sight:
				enemy_phase = EnemyPhase.WINDUP
				_enemy_seconds = WINDUP_TIME
			elif distance > STOP_RANGE:
				var next := battle.clamp_to_field(enemy_position + direction * minf(ENEMY_SPEED * delta, distance - STOP_RANGE))
				if can_move.call(enemy_position, next, false):
					enemy_position = next
		EnemyPhase.WINDUP:
			_enemy_seconds -= delta
			if _enemy_seconds <= 0.0:
				if sight and distance <= CONTACT_RANGE and direction.dot(enemy_heading) >= Attack.MIN_FORWARD_DOT:
					var hit := defense.resolve_incoming_hit(enemy, ENEMY_TEAM, {Unit.Damage.MELEE: ENEMY_DAMAGE}, true,
						battle.hero_heading, enemy_position - battle.hero_position)
					match hit.outcome:
						Defense.HitOutcome.HIT: _feedback("Mara hit · −%d HP" % roundi(hit.hp_lost))
						Defense.HitOutcome.GUARDED: _feedback("Guarded · −%d HP" % roundi(hit.hp_lost))
						Defense.HitOutcome.EVADED: _feedback("Dodged the swing")
				else:
					_feedback("Road guard missed")
				enemy_phase = EnemyPhase.RECOVERY
				_enemy_seconds = RECOVERY_TIME
		EnemyPhase.RECOVERY:
			_enemy_seconds -= delta
			if _enemy_seconds <= 0.0:
				enemy_phase = EnemyPhase.PURSUING


func active_feedback() -> String:
	return last_contact if _feedback_seconds > 0.0 else ""


func _feedback(text: String) -> void:
	last_contact = text
	_feedback_seconds = 1.6
