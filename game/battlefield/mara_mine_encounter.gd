extends RefCounted
## One road guard, sharing the same terrain and fixed step as the command scene.

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")
const ArcherAttack := preload("res://game/battlefield/mara_archer_attack.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")

enum EnemyPhase { WATCHING, PURSUING, WINDUP, RECOVERY, DEFEATED }
enum Target { NONE, HERO, INFANTRY, ARCHERS }

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
var infantry_attack := InfantryAttack.new()
var archer_attack: ArcherAttack
var _feet: Callable
var hero := Unit.new(HERO_HP)
var enemy := Unit.new(ENEMY_HP)
var defense := Defense.new(hero, HERO_TEAM, points)
var enemy_position: Vector2
var enemy_heading := Vector2.LEFT
var enemy_phase := EnemyPhase.WATCHING
var last_contact := ""
var windup_target: Target:
	get:
		return _windup_target
var _windup_target := Target.NONE
var _enemy_seconds := 0.0
var _feedback_seconds := 0.0


func _init(spawn: Vector2, feet := Callable(), clear_ranged := Callable()) -> void:
	enemy_position = spawn
	_feet = feet
	archer_attack = ArcherAttack.new(points, HERO_TEAM, ENEMY_TEAM, clear_ranged)


func target_at(point: Vector2) -> bool:
	return enemy.is_alive() and point.distance_to(enemy_position) <= InfantryAttack.TARGET_RADIUS


func order_infantry_attack(battle: Battle, selected: int, point: Vector2) -> bool:
	return selected == InfantryAttack.INFANTRY_INDEX and target_at(point) \
		and infantry_attack.issue(battle.formations[selected], enemy, enemy_position)


func order_archer_attack(battle: Battle, selected: int, point: Vector2, clear_contact: Callable) -> bool:
	if not _feet.is_valid() or selected != ArcherAttack.ARCHER_INDEX or not target_at(point):
		return false
	var status := archer_attack.issue(battle.formations[selected], enemy, enemy_position, _feet, clear_contact)
	if status != Archer.Status.READY:
		_feedback(_archer_denial(status))
		return false
	# A new, legal draw supersedes stale range or cover feedback.
	_feedback_seconds = 0.0
	return true


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
	# The hero and formation share this enemy roster. A fatal hero contact above
	# leaves no eligible infantry contact or BP award in the same physics tick.
	var infantry_damage := infantry_attack.advance(delta, battle, enemy, enemy_position, clear_contact, can_move)
	if infantry_damage > 0.0:
		var credited := points.award_confirmed_hit(InfantryAttack.BP_PER_HIT)
		_feedback("Shield Infantry hit · +%d BP" % credited)
	# Archers share the same HP target and pool, and do not claim killing blows twice.
	if _feet.is_valid():
		var shot := archer_attack.advance(delta, hero.is_alive(), battle.formations[ArcherAttack.ARCHER_INDEX],
			enemy, enemy_position, _feet, clear_contact)
		if shot:
			if shot.hp_lost > 0.0:
				_feedback("Archers volley hit · −%d HP · +%d BP" % [roundi(shot.hp_lost), shot.bp_credited])
			else:
				_feedback(_archer_denial(shot.status))
	if not enemy.is_alive():
		enemy_phase = EnemyPhase.DEFEATED
		_windup_target = Target.NONE
		return
	if not hero.is_alive():
		return

	match enemy_phase:
		EnemyPhase.WATCHING:
			if _nearest_visible_target(battle, sight, clear_contact) != Target.NONE:
				enemy_phase = EnemyPhase.PURSUING
		EnemyPhase.PURSUING:
			var target := _nearest_visible_target(battle, sight, clear_contact)
			if target == Target.NONE:
				enemy_phase = EnemyPhase.WATCHING
				return
			var toward := _target_position(battle, target) - enemy_position
			var distance := toward.length()
			var direction := toward.normalized()
			if not direction.is_zero_approx():
				enemy_heading = direction
			if distance <= STOP_RANGE + 0.02:
				enemy_phase = EnemyPhase.WINDUP
				_enemy_seconds = WINDUP_TIME
				_windup_target = target
			else:
				var next := battle.clamp_to_field(enemy_position + direction * minf(ENEMY_SPEED * delta, distance - STOP_RANGE))
				if can_move.call(enemy_position, next, false):
					enemy_position = next
		EnemyPhase.WINDUP:
			_enemy_seconds -= delta
			if _enemy_seconds <= 0.0:
				_resolve_enemy_contact(battle, clear_contact)
				enemy_phase = EnemyPhase.RECOVERY
				_enemy_seconds = RECOVERY_TIME
				_windup_target = Target.NONE
		EnemyPhase.RECOVERY:
			_enemy_seconds -= delta
			if _enemy_seconds <= 0.0:
				enemy_phase = EnemyPhase.PURSUING


func _nearest_visible_target(battle: Battle, hero_visible: bool, clear_contact: Callable) -> Target:
	var nearest := enemy_position.distance_to(battle.hero_position) if hero_visible and hero.is_alive() else INF
	var target := Target.HERO if nearest <= AGGRO_RANGE else Target.NONE
	var infantry := battle.formations[InfantryAttack.INFANTRY_INDEX]
	var infantry_distance := enemy_position.distance_to(infantry.position)
	# Ties preserve Mara's priority, then Shield Infantry. Ranged pressure
	# attracts the guard only locally, when he can really reach the archers.
	if infantry.order == Battle.Order.ATTACK and infantry_attack.attacker.is_alive() \
		and infantry_distance <= AGGRO_RANGE and infantry_distance < nearest \
		and clear_contact.call(enemy_position, infantry.position):
		nearest = infantry_distance
		target = Target.INFANTRY
	var archers := battle.formations[ArcherAttack.ARCHER_INDEX]
	var archer_distance := enemy_position.distance_to(archers.position)
	if archers.order == Battle.Order.ATTACK and archer_attack.attacker.is_alive() \
		and archer_distance <= AGGRO_RANGE and archer_distance < nearest \
		and clear_contact.call(enemy_position, archers.position):
		return Target.ARCHERS
	return target


func _target_position(battle: Battle, target: Target) -> Vector2:
	match target:
		Target.INFANTRY: return battle.formations[InfantryAttack.INFANTRY_INDEX].position
		Target.ARCHERS: return battle.formations[ArcherAttack.ARCHER_INDEX].position
	return battle.hero_position

func _resolve_enemy_contact(battle: Battle, clear_contact: Callable) -> void:
	var target := _target_position(battle, _windup_target)
	var toward := target - enemy_position
	if toward.length_squared() > CONTACT_RANGE * CONTACT_RANGE \
		or (not toward.is_zero_approx() and toward.normalized().dot(enemy_heading) < Attack.MIN_FORWARD_DOT) \
		or not clear_contact.call(enemy_position, target):
		_feedback("Road guard missed")
		return
	var hit_profile := {Unit.Damage.MELEE: ENEMY_DAMAGE}
	if _windup_target == Target.HERO:
		var hit := defense.resolve_incoming_hit(enemy, ENEMY_TEAM, hit_profile, true, battle.hero_heading, -toward)
		match hit.outcome:
			Defense.HitOutcome.HIT: _feedback("Mara hit · −%d HP" % roundi(hit.hp_lost))
			Defense.HitOutcome.GUARDED: _feedback("Guarded · −%d HP" % roundi(hit.hp_lost))
			Defense.HitOutcome.EVADED: _feedback("Dodged the swing")
	elif _windup_target == Target.INFANTRY and infantry_attack.attacker.is_alive():
		var lost := infantry_attack.attacker.receive_hit(enemy, hit_profile)
		if not infantry_attack.attacker.is_alive():
			battle.formations[InfantryAttack.INFANTRY_INDEX].defeat()
			_feedback("Shield Infantry defeated")
		elif lost > 0.0:
			_feedback("Shield Infantry hit · −%d HP" % roundi(lost))
	elif _windup_target == Target.ARCHERS and archer_attack.attacker.is_alive():
		var lost := archer_attack.attacker.receive_hit(enemy, hit_profile)
		if not archer_attack.attacker.is_alive():
			battle.formations[ArcherAttack.ARCHER_INDEX].defeat()
			_feedback("Archers defeated")
		elif lost > 0.0:
			_feedback("Archers struck · −%d HP" % roundi(lost))


func _archer_denial(status: Archer.Status) -> String:
	match status:
		Archer.Status.BLOCKED: return "Archers: line of sight blocked"
		Archer.Status.TOO_FAR: return "Archers: out of range"
		Archer.Status.TOO_CLOSE: return "Archers: target too close"
		Archer.Status.PINNED: return "Archers pinned in melee"
		Archer.Status.BUSY: return "Archers reloading"
		Archer.Status.INACTIVE: return "Archers unavailable"
		_: return "Archers: no valid target"


func active_feedback() -> String:
	return last_contact if _feedback_seconds > 0.0 else ""


func _feedback(text: String) -> void:
	last_contact = text
	_feedback_seconds = 1.6
