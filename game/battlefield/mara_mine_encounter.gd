extends RefCounted
## One road guard, sharing the same terrain and fixed step as the command scene.

const EnemyAggro := preload("res://game/combat/enemy_aggro.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")
const ArcherAttack := preload("res://game/battlefield/mara_archer_attack.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")

enum EnemyPhase { WATCHING, PURSUING, WINDUP, RECOVERY, DEFEATED, AT_RESERVE, INTERCEPTING, ALERT }
enum Target { NONE, HERO, INFANTRY, ARCHERS, CIVILIAN }

const HERO_TEAM := 0
const ENEMY_TEAM := 1
const HERO_HP := 360.0
const ENEMY_HP := 260.0
const ENEMY_DAMAGE := 90.0
const CONTACT_RANGE := 1.75
const STOP_RANGE := 1.35
const BODY_CLEARANCE := 0.83
const AGGRO_RANGE := EnemyAggro.RADIUS_METRES
# Story guards may watch a lane without leaving it for distant contacts.
const STORY_PRESSURE_RANGE := 8.0
const WINDUP_TIME := 0.66
const RECOVERY_TIME := 0.95
const ENEMY_SPEED := 2.9
const INTERCEPTION_SPEED := 5.4

var hero: Unit
var points: Points
var infantry_attack: InfantryAttack
var archer_attack: ArcherAttack
var _feet: Callable
var aggro_sight: Callable
var hold_story_lane := false
var enemy := Unit.new(ENEMY_HP)
var defense: Defense
var enemy_title := "Road guard"
var enemy_damage := ENEMY_DAMAGE
var civilian_positions: Callable
var civilian_hit: Callable
var civilian_aggro_radius := 0.0
var _civilian_index := -1
var enemy_position: Vector2
var enemy_heading := Vector2.LEFT
var enemy_phase := EnemyPhase.WATCHING
var enemy_defeated_in_combat := false
var alert_target := Target.NONE
var last_contact := ""
var windup_target: Target:
	get:
		return _windup_target
var _windup_target := Target.NONE
var _enemy_seconds := 0.0
var _feedback_seconds := 0.0
var _interception_route := PackedVector2Array()
var _interception_leg := 0


func _init(spawn: Vector2, feet := Callable(), clear_ranged := Callable(), lead_level := 1,
		infantry: InfantryAttack = null, lead_melee_invested := false, title := "Road guard") -> void:
	enemy_title = title
	infantry_attack = infantry if infantry else InfantryAttack.new()
	enemy_position = spawn
	_feet = feet
	points = Points.new(lead_level)
	# The launch choice affects only Mara's existing combat proxy, not its level or HP.
	hero = Unit.new(HERO_HP, {Unit.Damage.MELEE: Unit.MIN_RATING + int(lead_melee_invested)})
	defense = Defense.new(hero, HERO_TEAM, points)
	archer_attack = ArcherAttack.new(points, HERO_TEAM, ENEMY_TEAM, clear_ranged)


func stage_interception(route: PackedVector2Array) -> void:
	if not route.is_empty():
		_interception_route = route.duplicate()
		enemy_phase = EnemyPhase.AT_RESERVE


func begin_interception() -> bool:
	if enemy_phase != EnemyPhase.AT_RESERVE or not enemy.is_alive():
		return false
	enemy_phase = EnemyPhase.INTERCEPTING
	return true


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
	var enemy_was_alive := enemy.is_alive()
	_feedback_seconds -= delta
	alert_target = Target.NONE
	var sight := bool(clear_contact.call(battle.hero_position, enemy_position))
	var see_target := aggro_sight if aggro_sight.is_valid() else clear_contact
	var contact := defense.advance_attack(delta, true, battle.hero_position, battle.hero_heading,
		enemy if sight else null, ENEMY_TEAM, enemy_position)
	if contact:
		if contact.attack == Attack.Attack.SUNDERING_STRIKE:
			_feedback("Sundering Strike hit" if contact.hp_lost > 0.0 else "Sundering Strike missed")
		elif contact.hp_lost > 0.0:
			_feedback("%s hit · +%d BP" % ["Light" if contact.attack == Attack.Attack.LIGHT else "Heavy", contact.bp_credited])
		else:
			_feedback("Attack missed")
	# The hero and formation share this enemy roster. A fatal hero contact above
	# leaves no eligible infantry contact or BP award in the same physics tick.
	var infantry_damage := infantry_attack.advance(delta, battle, enemy, enemy_position, clear_contact, can_move)
	if infantry_damage > 0.0:
		var credited := points.award_confirmed_hit(InfantryAttack.BP_PER_HIT)
		_feedback("%s hit · +%d BP" % [battle.formations[InfantryAttack.INFANTRY_INDEX].title, credited])
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
		# One actual encounter Unit, not the number of meshes depicting it.
		# Only a transition caused by this owner’s combat above is a defeat.
		if enemy_was_alive:
			enemy_defeated_in_combat = true
		enemy_phase = EnemyPhase.DEFEATED
		_windup_target = Target.NONE
		return
	if not hero.is_alive():
		return

	match enemy_phase:
		EnemyPhase.AT_RESERVE:
			pass
		EnemyPhase.INTERCEPTING:
			_advance_interception(delta, battle, can_move)
		EnemyPhase.WATCHING, EnemyPhase.ALERT:
			var target := _pursuit_target(battle, see_target, clear_contact)
			if target != Target.NONE:
				enemy_phase = EnemyPhase.PURSUING
			else:
				_update_alert(battle, see_target)
		EnemyPhase.PURSUING:
			var target := _pursuit_target(battle, see_target, clear_contact)
			if target == Target.NONE:
				_update_alert(battle, see_target)
				return
			var toward := _target_position(battle, target) - enemy_position
			var distance := toward.length()
			var direction := toward.normalized()
			if not direction.is_zero_approx():
				enemy_heading = direction
			if distance <= STOP_RANGE + 0.02:
				if not clear_contact.call(enemy_position, _target_position(battle, target)):
					return
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


func _advance_interception(delta: float, battle: Battle, can_move: Callable) -> void:
	var destination := battle.clamp_to_field(_interception_route[_interception_leg])
	var next := enemy_position.move_toward(destination, INTERCEPTION_SPEED * delta)
	if next.distance_to(battle.hero_position) < BODY_CLEARANCE \
		or not can_move.call(enemy_position, next, false):
		# The guard can fight where he is, but never warp across a blocked approach.
		enemy_phase = EnemyPhase.PURSUING
		return
	if next != enemy_position:
		enemy_heading = (next - enemy_position).normalized()
		enemy_position = next
	if enemy_position == destination:
		_interception_leg += 1
		if _interception_leg == _interception_route.size():
			enemy_phase = EnemyPhase.WATCHING


func _update_alert(battle: Battle, see_target: Callable) -> void:
	var target := _nearest_visible_combatant(battle, AGGRO_RANGE, see_target)
	if target == Target.NONE:
		enemy_phase = EnemyPhase.WATCHING
		return
	alert_target = target
	var direction := (_target_position(battle, target) - enemy_position).normalized()
	if not direction.is_zero_approx():
		enemy_heading = direction
	enemy_phase = EnemyPhase.ALERT


func _pursuit_target(battle: Battle, see_target: Callable, clear_contact: Callable) -> Target:
	# The reserve/raid steps remain authored orders; this is only ordinary
	# pursuit once released. An alerted story guard still holds its lane,
	# including protecting the rescue's original nearby civilian pressure.
	var radius := STORY_PRESSURE_RANGE if hold_story_lane else AGGRO_RANGE
	var target := _nearest_visible_combatant(battle, radius, clear_contact if hold_story_lane else see_target)
	if target != Target.NONE or not civilian_positions.is_valid():
		return target
	var civilians: PackedVector2Array = civilian_positions.call()
	var nearest_civilian := civilian_aggro_radius
	_civilian_index = -1
	for index in range(civilians.size()):
		var civilian := civilians[index]
		if not civilian.is_finite():
			continue
		var distance := enemy_position.distance_to(civilian)
		if distance < nearest_civilian and clear_contact.call(enemy_position, civilian):
			_civilian_index = index
			nearest_civilian = distance
	return Target.CIVILIAN if _civilian_index >= 0 else Target.NONE


func _nearest_visible_combatant(battle: Battle, radius: float, see_target: Callable) -> Target:
	var nearest := INF
	var target := Target.NONE
	var hero_distance := enemy_position.distance_to(battle.hero_position)
	if hero.is_alive() and hero_distance <= radius and see_target.call(enemy_position, battle.hero_position):
		nearest = hero_distance
		target = Target.HERO
	var infantry := battle.formations[InfantryAttack.INFANTRY_INDEX]
	var infantry_distance := enemy_position.distance_to(infantry.position)
	# Ties preserve Mara's priority, then Shield Infantry. An explicit
	# formation attack remains the condition to retaliate or spot this target.
	if infantry.order == Battle.Order.ATTACK and infantry_attack.attacker.is_alive() \
		and infantry_distance <= radius and infantry_distance < nearest \
		and see_target.call(enemy_position, infantry.position):
		nearest = infantry_distance
		target = Target.INFANTRY
	var archers := battle.formations[ArcherAttack.ARCHER_INDEX]
	var archer_distance := enemy_position.distance_to(archers.position)
	if archers.order == Battle.Order.ATTACK and archer_attack.attacker.is_alive() \
		and archer_distance <= radius and archer_distance < nearest \
		and see_target.call(enemy_position, archers.position):
		target = Target.ARCHERS
	return target


func _target_position(battle: Battle, target: Target) -> Vector2:
	match target:
		Target.INFANTRY: return battle.formations[InfantryAttack.INFANTRY_INDEX].position
		Target.ARCHERS: return battle.formations[ArcherAttack.ARCHER_INDEX].position
		Target.CIVILIAN:
			var civilians: PackedVector2Array = civilian_positions.call()
			return civilians[_civilian_index] if _civilian_index >= 0 and _civilian_index < civilians.size() else Vector2.INF
	return battle.hero_position

func _resolve_enemy_contact(battle: Battle, clear_contact: Callable) -> void:
	var target := _target_position(battle, _windup_target)
	var toward := target - enemy_position
	if not target.is_finite() or toward.length_squared() > CONTACT_RANGE * CONTACT_RANGE \
		or (not toward.is_zero_approx() and toward.normalized().dot(enemy_heading) < Attack.MIN_FORWARD_DOT) \
		or not clear_contact.call(enemy_position, target):
		_feedback("%s missed" % enemy_title)
		return
	var hit_profile := {Unit.Damage.MELEE: enemy_damage}
	if _windup_target == Target.HERO:
		var hit := defense.resolve_incoming_hit(enemy, ENEMY_TEAM, hit_profile, true, battle.hero_heading, -toward)
		match hit.outcome:
			Defense.HitOutcome.HIT: _feedback("Mara hit · −%d HP" % roundi(hit.hp_lost))
			Defense.HitOutcome.GUARDED: _feedback("Guarded · −%d HP" % roundi(hit.hp_lost))
			Defense.HitOutcome.EVADED: _feedback("Dodged the swing")
	elif _windup_target == Target.CIVILIAN and civilian_hit.is_valid():
		if civilian_hit.call(_civilian_index):
			_feedback("%s struck a miner" % enemy_title)
	elif _windup_target == Target.INFANTRY and infantry_attack.attacker.is_alive():
		var infantry := battle.formations[InfantryAttack.INFANTRY_INDEX]
		var lost := infantry_attack.attacker.receive_hit(enemy, hit_profile)
		if not infantry_attack.attacker.is_alive():
			infantry.defeat()
			_feedback("%s defeated" % infantry.title)
		elif lost > 0.0:
			_feedback("%s hit · −%d HP" % [infantry.title, roundi(lost)])
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
