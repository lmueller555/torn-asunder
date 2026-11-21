extends RefCounted

const Aggro := preload("res://game/combat/enemy_aggro.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Points := preload("res://game/combat/battle_points.gd")

# From RECOIL through KNOCKDOWN, states are ordered by contact priority.
enum State { IDLE, RUN, ATTACK, RAISE, GUARD, LOWER, RECOIL, BLOCKED, STAGGER, KNOCKDOWN, DOWN, GET_UP, DEAD, CHEER }
enum AbilityStatus { READY, BATTLE_ENDED, INVALID_CASTER, INVALID_TARGET, UNHURT_TARGET, STAT_REQUIREMENT, INSUFFICIENT_BP }

const PLATOON_SIZE := 32
const FORMATION_COLUMNS := 8
const PLATOON_SPACING := 13.5
const MAX_ENGAGEMENTS := 3
const LIVE := -2
const DRAW := -1
const CONTACT := 0.70 / Catalog.INFANTRY_SWORD_SLASH_SPEED
const ATTACK_ADVANCE_START := 0.33 / Catalog.INFANTRY_SWORD_SLASH_SPEED
const ATTACK_ADVANCE_END := 0.88 / Catalog.INFANTRY_SWORD_SLASH_SPEED
const ATTACK_RANGE := 1.48
const WAIT_DISTANCE := 2.16
const ENGAGEMENT_RANGE := 5.0
const PURSUIT_RANGE := ENGAGEMENT_RANGE * 1.3
const SCAN_MIN_INTERVAL := 0.35
const SCAN_MAX_INTERVAL := 0.70
const RETARGET_MAX_WAIT := 7.0
const REINFORCE_RANGE := 45.72 # 50 yards
const REINFORCE_CHOICES := 5
const RUN_SPEED := 2.7
const BODY_SPACING := 0.82
const BODY_CORE := 0.60
const PASS_LOOKAHEAD := 1.05
# One neighboring cell in every direction covers both passing and body contact.
const CELL_SIZE := 1.5
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const SLOT_DISTANCE := 1.22
const SLOT_TOLERANCE := 0.48
const SLOT_ANGLES := [0.0, -TAU / 3.0, TAU / 3.0]
const ARENA_LIMIT := Vector2(9.0, 10.0)
const VICTORY_CLEAR_TIME := 0.75
const VICTORY_CHEERS := 3
const KNOCKDOWN_RECOVERY_GRACE := 0.5
# Prototype tuning for the first Holy support spell, not a global ability default.
const FIELD_BENEDICTION_HOLY_RATING := 10
const FIELD_BENEDICTION_BP_COST := 100
const FIELD_BENEDICTION_HEAL_FRACTION := 0.15
const DURATIONS := {
	State.ATTACK: (88.0 / 60.0) / Catalog.INFANTRY_SWORD_SLASH_SPEED,
	State.RAISE: 0.32,
	State.GUARD: 0.54,
	State.LOWER: 0.30,
	State.RECOIL: 49.0 / 60.0,
	State.BLOCKED: 44.0 / 60.0,
	State.STAGGER: 0.9,
	State.KNOCKDOWN: 1.15,
	State.DOWN: 0.26,
	State.GET_UP: 94.0 / 60.0,
	State.DEAD: 1.2,
	State.CHEER: 84.0 / 60.0,
}
const DISPLACEMENTS := {
	State.RECOIL: Vector2(0, 0.155),
	State.STAGGER: Vector2(0, 0.78),
	State.KNOCKDOWN: Vector2(0, 1.875),
	State.GET_UP: Vector2(0, 0.345),
	State.DEAD: Vector2(-0.52, 0.121),
}


class Soldier:
	var unit: Unit
	var unit_type: StringName
	var basic_attack: Dictionary
	var run_speed: float
	var team: int
	var platoon_index: int
	var roster_index: int
	var battle_index: int
	var position: Vector2
	var facing: Vector2
	var knockback_direction := Vector2.ZERO
	var recovery_protected_until := 0.0
	var state := State.IDLE
	var time := 0.0
	var ready_in := 0.0
	var think_in := 0.0
	var scan_in := 0.0
	var target := -1
	var slot := -1
	var slot_axis := Vector2.ZERO
	var approach := -1
	var pursuit := -1
	var retarget_at := -1.0
	var reinforce_ally := -1
	var heavy := false
	var cheer_in := 0.0
	var victory_cheers := 0
	var victory_in := 0.0

	func _init(model: Unit, side: int, platoon: int, index: int, spawn: Vector2, type: StringName) -> void:
		unit = model
		unit_type = type
		var definition: Dictionary = Catalog.TYPES[type]
		basic_attack = definition.basic_attack
		run_speed = RUN_SPEED * float(definition.movement_scale)
		team = side
		platoon_index = platoon
		roster_index = index
		battle_index = platoon * PLATOON_SIZE + index
		position = spawn
		facing = Vector2.DOWN if side == 0 else Vector2.UP

	func is_recovering() -> bool:
		return state == State.KNOCKDOWN or state == State.DOWN or state == State.GET_UP


var soldiers: Array[Soldier] = []
var platoons: Array[Platoon] = []
var engagements: Array[Dictionary] = []
var arena_limit := ARENA_LIMIT
var elapsed := 0.0
var winner := LIVE
var hits := 0
var blocks := 0

var _team_battle_points: Array[Points] = []
var _troop_hit_award: int
var _first_amber_platoon: int
var _body_cells: Dictionary[Vector2i, Array] = {}
var _random := RandomNumberGenerator.new()
var _cheer_random := RandomNumberGenerator.new()
var _retarget_random := RandomNumberGenerator.new()
var _battle_engaged := false
var _clear_time := 0.0
var _celebrating := false


func _init(seed_value: int = 8, setup: Setup = null, troop_hit_award: int = 0) -> void:
	_troop_hit_award = maxi(0, troop_hit_award)
	_random.seed = seed_value
	_cheer_random.seed = seed_value ^ 0x494E46
	_retarget_random.seed = seed_value ^ 0x524554
	var infantry: Dictionary = Catalog.TYPES[Catalog.HUMAN_INFANTRY]
	if setup == null:
		setup = Setup.new()
	_first_amber_platoon = setup.sides[0].size()
	var widest := maxi(_first_amber_platoon, setup.sides[1].size())
	arena_limit.x += (widest - 1) * PLATOON_SPACING * 0.5
	for team in range(2):
		var count: int = setup.sides[team].size()
		# AI skirmish has no hero yet; use the lead platoon for capacity.
		var lead_level: int = setup.sides[team][0].level if count > 0 else 1
		_team_battle_points.append(Points.new(lead_level))
		for slot in range(count):
			var build: Setup.PlatoonBuild = setup.sides[team][slot]
			var center := (slot - (count - 1) * 0.5) * PLATOON_SPACING
			_spawn_platoon(team, center, build, infantry.platoon_training)


func _spawn_platoon(team: int, center: float, build: Setup.PlatoonBuild, training: Dictionary) -> void:
	var roster: Array[Unit] = []
	var side := -1.0 if team == 0 else 1.0
	for index in range(PLATOON_SIZE):
		var unit := build.make_unit()
		roster.append(unit)
		var column := index % FORMATION_COLUMNS - (FORMATION_COLUMNS - 1) * 0.5
		var row := floori(float(index) / FORMATION_COLUMNS)
		var rank_offset := -0.23 if row % 2 == 0 else 0.23
		var spawn := Vector2(center + column * 1.55 + rank_offset, side * (4.6 + row * 1.36))
		spawn += Vector2(_random.randf_range(-0.12, 0.12), _random.randf_range(-0.10, 0.10))
		var soldier := Soldier.new(unit, team, platoons.size(), index, spawn, build.unit_type)
		soldier.ready_in = _random.randf_range(0.05, 0.50)
		soldier.cheer_in = _cheer_random.randf_range(2.0, 5.0)
		soldiers.append(soldier)
		engagements.append({})
	platoons.append(Platoon.new(roster, training))


func battle_points_for_team(team: int) -> Points:
	if team < 0 or team >= _team_battle_points.size():
		return null
	return _team_battle_points[team]


# A read-only readiness check for ability previews and order admission.
func field_benediction_status(team: int, caster_index: int, target_index: int) -> AbilityStatus:
	if winner != LIVE:
		return AbilityStatus.BATTLE_ENDED
	var pool := battle_points_for_team(team)
	if pool == null or caster_index < 0 or caster_index >= soldiers.size():
		return AbilityStatus.INVALID_CASTER
	var caster := soldiers[caster_index]
	if caster.team != team or not caster.unit.is_alive():
		return AbilityStatus.INVALID_CASTER
	if target_index < 0 or target_index >= soldiers.size():
		return AbilityStatus.INVALID_TARGET
	var target := soldiers[target_index]
	if target.team != team or not target.unit.is_alive():
		return AbilityStatus.INVALID_TARGET
	if target.unit.hp >= target.unit.max_hp:
		return AbilityStatus.UNHURT_TARGET
	if caster.unit.rating(Unit.Damage.HOLY) < FIELD_BENEDICTION_HOLY_RATING:
		return AbilityStatus.STAT_REQUIREMENT
	if not pool.can_afford(FIELD_BENEDICTION_BP_COST):
		return AbilityStatus.INSUFFICIENT_BP
	return AbilityStatus.READY


# Return HP restored. Reject an invalid order before spending from the team's pool.
func cast_field_benediction(team: int, caster_index: int, target_index: int) -> float:
	if field_benediction_status(team, caster_index, target_index) != AbilityStatus.READY:
		return 0.0
	if not _team_battle_points[team].try_spend(FIELD_BENEDICTION_BP_COST, true):
		return 0.0
	var target := soldiers[target_index].unit
	return target.receive_healing(target.max_hp * FIELD_BENEDICTION_HEAL_FRACTION)


# The caller confirms charge contact before invoking this resolver. An ineffective
# charge does not earn points, and only opposing platoons can be charged.
func resolve_platoon_charge(attacker_index: int, defender_index: int, braced: bool, bp_award: int) -> float:
	if winner != LIVE or attacker_index < 0 or attacker_index >= platoons.size():
		return 0.0
	if defender_index < 0 or defender_index >= platoons.size():
		return 0.0
	var attacker_team := 0 if attacker_index < _first_amber_platoon else 1
	var defender_team := 0 if defender_index < _first_amber_platoon else 1
	if attacker_team == defender_team:
		return 0.0
	var loss := platoons[attacker_index].charge(platoons[defender_index], braced)
	if loss > 0.0:
		_team_battle_points[attacker_team].award_confirmed_hit(bp_award)
	return loss


func team_size(team: int) -> int:
	var count := _first_amber_platoon if team == 0 else platoons.size() - _first_amber_platoon
	return count * PLATOON_SIZE


func survivors(team: int) -> int:
	var start := 0 if team == 0 else team_size(0)
	var alive := 0
	for index in range(start, start + team_size(team)):
		if soldiers[index].unit.is_alive():
			alive += 1
	return alive


func step(delta: float) -> void:
	if winner == LIVE:
		elapsed += delta
		_assign_targets()

	var contacts: Array[int] = []
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		var before := soldier.time
		soldier.time += delta
		soldier.ready_in = maxf(0.0, soldier.ready_in - delta)
		soldier.think_in = maxf(0.0, soldier.think_in - delta)
		soldier.scan_in = maxf(0.0, soldier.scan_in - delta)
		if soldier.state == State.ATTACK and before < CONTACT and soldier.time >= CONTACT:
			contacts.append(index)
		_move_action(soldier, before)
		_finish_action(soldier)

	if winner == LIVE:
		_resolve_contacts(contacts)
		_check_winner()
	_update_celebration(delta)
	if winner == LIVE:
		_index_bodies()
		_update_ai(delta)
		_separate(delta)


func _assign_targets() -> void:
	for group in engagements:
		group.clear()
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive():
			soldier.target = -1
			soldier.slot = -1
			continue
		if soldier.target < 0:
			continue
		if _lost_enemy(soldier, soldiers[soldier.target]):
			_begin_retarget(soldier)
			continue
		_link_engagement(index, soldier.target)
	# Set the first arrival's bearing as the reference. Keep it fixed while the fight turns.
	for index in range(soldiers.size()):
		var enemy := soldiers[index]
		var occupied := false
		for rival: int in engagements[index]:
			if soldiers[rival].target == index and soldiers[rival].slot >= 0:
				occupied = true
				break
		if not occupied:
			enemy.slot_axis = Vector2.ZERO
	# Assignment is shared by both sides. A reciprocal target uses the same slot.
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive() or soldier.victory_cheers > 0 or soldier.target >= 0:
			continue
		if not _is_mobile(soldier) and soldier.state != State.CHEER:
			continue
		if soldier.retarget_at >= 0.0:
			if elapsed < soldier.retarget_at or not _is_mobile(soldier):
				continue
			soldier.retarget_at = -1.0
			if _retarget_random.randf() < 0.5:
				soldier.reinforce_ally = _choose_ally_to_reinforce(soldier)
				if soldier.reinforce_ally < 0:
					_begin_retarget(soldier)
					continue
		if soldier.reinforce_ally >= 0:
			_update_reinforcement(soldier)
			continue
		if soldier.approach < 0 and soldier.scan_in <= 0.0:
			_scan_for_enemy(index)
		if soldier.state == State.CHEER:
			if not _waiting_for_slot(soldier) or soldier.position.distance_to(soldiers[soldier.pursuit].position) > WAIT_DISTANCE + 0.25:
				_set_state(soldier, State.IDLE)
		if soldier.approach < 0:
			continue
		var enemy := soldiers[soldier.approach]
		if _lost_enemy(soldier, enemy):
			_begin_retarget(soldier)
		elif soldier.position.distance_squared_to(enemy.position) <= ATTACK_RANGE * ATTACK_RANGE:
			if _has_slot(index, soldier.approach):
				_engage(soldier, soldier.approach)
			soldier.approach = -1
	_align_reciprocal_slots()


func _lost_enemy(soldier: Soldier, enemy: Soldier) -> bool:
	return not enemy.unit.is_alive() or soldier.position.distance_squared_to(enemy.position) > PURSUIT_RANGE * PURSUIT_RANGE


func _begin_retarget(soldier: Soldier) -> void:
	soldier.target = -1
	soldier.slot = -1
	soldier.approach = -1
	soldier.pursuit = -1
	soldier.reinforce_ally = -1
	soldier.scan_in = 0.0
	soldier.retarget_at = elapsed + _retarget_random.randf_range(0.0, RETARGET_MAX_WAIT)


func _choose_ally_to_reinforce(soldier: Soldier) -> int:
	var candidates: Array[int] = []
	var most_attackers := 0
	var first_amber := team_size(0)
	var first_ally := 0 if soldier.team == 0 else first_amber
	var end_ally := first_amber if soldier.team == 0 else soldiers.size()
	for index in range(first_ally, end_ally):
		var ally := soldiers[index]
		if ally == soldier or not ally.unit.is_alive():
			continue
		if soldier.position.distance_squared_to(ally.position) > REINFORCE_RANGE * REINFORCE_RANGE:
			continue
		var attackers := _incoming_attackers(index).size()
		if attackers == 0 or attackers < most_attackers:
			continue
		if attackers > most_attackers:
			most_attackers = attackers
			candidates.clear()
		candidates.append(index)
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return soldier.position.distance_squared_to(soldiers[a].position) > soldier.position.distance_squared_to(soldiers[b].position)
	)
	return candidates[_retarget_random.randi_range(0, mini(candidates.size(), REINFORCE_CHOICES) - 1)]


func _incoming_attackers(index: int) -> Array[int]:
	var attackers: Array[int] = []
	for rival: int in engagements[index]:
		if soldiers[rival].target == index and soldiers[rival].unit.is_alive():
			attackers.append(rival)
	return attackers


func _update_reinforcement(soldier: Soldier) -> void:
	var ally := soldiers[soldier.reinforce_ally]
	var attackers := _incoming_attackers(soldier.reinforce_ally)
	if not ally.unit.is_alive() or attackers.is_empty():
		_begin_retarget(soldier)
		return
	if soldier.position.distance_squared_to(ally.position) > ATTACK_RANGE * ATTACK_RANGE:
		return
	var nearest := INF
	var selected := -1
	for rival in attackers:
		var enemy := soldiers[rival]
		if _lost_enemy(soldier, enemy) or enemy.is_recovering():
			continue
		if not _has_slot(soldier.battle_index, rival):
			continue
		var distance := soldier.position.distance_squared_to(enemy.position)
		if distance < nearest:
			nearest = distance
			selected = rival
	if selected < 0:
		_begin_retarget(soldier)
		return
	soldier.reinforce_ally = -1
	_engage(soldier, selected)


func _engage(soldier: Soldier, rival: int) -> void:
	soldier.slot = _choose_attack_slot(soldier, rival)
	soldier.target = rival
	_link_engagement(soldier.battle_index, rival)


func _scan_for_enemy(index: int) -> void:
	var soldier := soldiers[index]
	soldier.scan_in = _random.randf_range(SCAN_MIN_INTERVAL, SCAN_MAX_INTERVAL)
	var nearest_distance := INF
	var candidates: Array[int] = []
	soldier.pursuit = -1
	var first_enemy := team_size(0) if soldier.team == 0 else 0
	var end_enemy := soldiers.size() if soldier.team == 0 else team_size(0)
	for rival in range(first_enemy, end_enemy):
		var enemy := soldiers[rival]
		if not enemy.unit.is_alive():
			continue
		var distance := soldier.position.distance_squared_to(enemy.position)
		if distance<=Aggro.RADIUS_METRES*Aggro.RADIUS_METRES and distance < nearest_distance:
			soldier.pursuit = rival
			nearest_distance = distance
		if distance <= ENGAGEMENT_RANGE * ENGAGEMENT_RANGE and _has_slot(index, rival):
			candidates.append(rival)
	if not candidates.is_empty():
		soldier.approach = candidates[_random.randi_range(0, candidates.size() - 1)]


func _has_slot(index: int, rival: int) -> bool:
	return engagements[index].has(rival) or (
		engagements[index].size() < MAX_ENGAGEMENTS and engagements[rival].size() < MAX_ENGAGEMENTS
	)


func _link_engagement(index: int, rival: int) -> void:
	_battle_engaged = true
	engagements[index][rival] = true
	engagements[rival][index] = true


func _choose_attack_slot(soldier: Soldier, rival: int) -> int:
	var enemy := soldiers[rival]
	if enemy.slot_axis == Vector2.ZERO:
		enemy.slot_axis = (soldier.position - enemy.position).normalized()
		if enemy.slot_axis == Vector2.ZERO:
			enemy.slot_axis = -enemy.facing
	var used := 0
	for other: int in engagements[rival]:
		var attacker := soldiers[other]
		if attacker.target == rival and attacker.slot >= 0:
			used |= 1 << attacker.slot
	var best := -1
	var nearest := INF
	for slot in range(SLOT_ANGLES.size()):
		if used & (1 << slot):
			continue
		var position := enemy.position + enemy.slot_axis.rotated(SLOT_ANGLES[slot]) * SLOT_DISTANCE
		var score := soldier.position.distance_squared_to(position)
		if position != position.clamp(-arena_limit, arena_limit):
			score += 8.0
		if score < nearest:
			best = slot
			nearest = score
	return best


func _align_reciprocal_slots() -> void:
	# A pair fighting each other shares an axis. Their other opponents take the flanks.
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if soldier.target < 0 or soldier.slot < 0:
			continue
		var enemy := soldiers[soldier.target]
		if enemy.target != index or enemy.slot < 0:
			continue
		var bearing := enemy.position - soldier.position
		if not bearing.is_zero_approx():
			soldier.slot_axis = bearing.normalized().rotated(-SLOT_ANGLES[enemy.slot])


func _is_mobile(soldier: Soldier) -> bool:
	return soldier.state == State.IDLE or soldier.state == State.RUN


func _set_state(soldier: Soldier, state: State) -> void:
	if soldier.state != state:
		soldier.state = state
		soldier.time = 0.0


func _finish_action(soldier: Soldier) -> void:
	if soldier.time < float(DURATIONS.get(soldier.state, INF)):
		return
	match soldier.state:
		State.RAISE:
			_set_state(soldier, State.GUARD)
		State.GUARD, State.BLOCKED:
			_set_state(soldier, State.LOWER)
		State.KNOCKDOWN:
			_set_state(soldier, State.DOWN)
		State.DOWN:
			_set_state(soldier, State.GET_UP)
		State.DEAD:
			soldier.time = DURATIONS[State.DEAD]
		State.CHEER:
			_set_state(soldier, State.IDLE)
			if soldier.victory_cheers > 0:
				soldier.victory_cheers -= 1
				soldier.victory_in = _cheer_random.randf_range(0.30, 0.75)
		_:
			if soldier.state == State.GET_UP:
				soldier.recovery_protected_until = elapsed + KNOCKDOWN_RECOVERY_GRACE
			_set_state(soldier, State.IDLE)
			soldier.ready_in = _random.randf_range(0.08, 0.36)


func _move_action(soldier: Soldier, before: float) -> void:
	if soldier.state == State.ATTACK and soldier.target >= 0 and before < ATTACK_ADVANCE_END:
		var advance := clampf(inverse_lerp(ATTACK_ADVANCE_START, ATTACK_ADVANCE_END, soldier.time), 0.0, 1.0)
		var previous := clampf(inverse_lerp(ATTACK_ADVANCE_START, ATTACK_ADVANCE_END, before), 0.0, 1.0)
		var enemy := soldiers[soldier.target]
		var space := maxf(0.0, (enemy.position - soldier.position).dot(soldier.facing) - 0.86)
		soldier.position += soldier.facing * minf(space, 0.52 * (advance - previous))
	elif DISPLACEMENTS.has(soldier.state):
		var duration: float = DURATIONS[soldier.state]
		var fraction := smoothstep(0.0, 0.85, soldier.time / duration)
		var previous := smoothstep(0.0, 0.85, before / duration)
		var travel: Vector2 = DISPLACEMENTS[soldier.state]
		var travel_axis := soldier.facing
		if soldier.state == State.STAGGER or soldier.state == State.KNOCKDOWN:
			travel_axis = soldier.knockback_direction
		var right := Vector2(travel_axis.y, -travel_axis.x)
		soldier.position += (right * travel.x + travel_axis * travel.y) * (fraction - previous)


func _update_ai(delta: float) -> void:
	for soldier in soldiers:
		if not _is_mobile(soldier) or not soldier.unit.is_alive() or soldier.victory_cheers > 0:
			continue
		if soldier.retarget_at >= 0.0:
			_wait_to_retarget(soldier, delta)
			continue
		if soldier.reinforce_ally >= 0:
			var ally := soldiers[soldier.reinforce_ally]
			_run_toward(soldier, ally.position - soldier.position, delta)
			continue
		var assigned := soldier.target >= 0
		var pursuing_target := soldier.approach >= 0
		var goal := soldier.target if assigned else (soldier.approach if pursuing_target else soldier.pursuit)
		if goal < 0 or not soldiers[goal].unit.is_alive():
			_set_state(soldier, State.IDLE)
			continue
		var enemy := soldiers[goal]
		var offset := enemy.position - soldier.position
		var distance := offset.length()
		var reach := ATTACK_RANGE - 0.08 if assigned or pursuing_target else WAIT_DISTANCE
		if assigned and soldier.slot >= 0:
			var waypoint := _slot_waypoint(soldier, enemy, distance)
			if waypoint.distance_squared_to(soldier.position) > 0.01:
				_run_toward(soldier, waypoint - soldier.position, delta)
				continue
		if distance > reach + 0.025:
			_run_toward(soldier, offset * (1.0 - reach / distance), delta)
			continue
		_set_state(soldier, State.IDLE)
		if distance > 0.001:
			soldier.facing = offset / distance
		if _waiting_for_slot(soldier):
			_try_cheer(soldier, delta)
			continue
		if not assigned or soldier.ready_in > 0.0:
			continue
		if _incoming_slash(soldier, enemy) and _try_raise_shield(soldier):
			continue
		soldier.heavy = _random.randf() < 0.28
		_set_state(soldier, State.ATTACK)


func _wait_to_retarget(soldier: Soldier, delta: float) -> void:
	_set_state(soldier, State.IDLE)
	for rival in _incoming_attackers(soldier.battle_index):
		var enemy := soldiers[rival]
		var offset := enemy.position - soldier.position
		if offset.length_squared() <= ATTACK_RANGE * ATTACK_RANGE and _incoming_slash(soldier, enemy):
			if _try_raise_shield(soldier) and not offset.is_zero_approx():
				soldier.facing = offset.normalized()
			return
	_try_cheer(soldier, delta)


func _try_cheer(soldier: Soldier, delta: float) -> void:
	soldier.cheer_in -= delta
	if soldier.cheer_in <= 0.0:
		soldier.cheer_in = _cheer_random.randf_range(8.0, 16.0)
		_set_state(soldier, State.CHEER)


func _try_raise_shield(soldier: Soldier) -> bool:
	if soldier.think_in > 0.0:
		return false
	soldier.think_in = _random.randf_range(0.30, 0.48)
	if _random.randf() >= 0.50:
		return false
	_set_state(soldier, State.RAISE)
	return true


func _update_celebration(delta: float) -> void:
	if winner == DRAW or (winner == LIVE and not _battle_engaged):
		return
	if winner == LIVE and _enemies_in_range():
		_clear_time = 0.0
		if _celebrating:
			for soldier in soldiers:
				if soldier.victory_cheers > 0 and soldier.state == State.CHEER:
					_set_state(soldier, State.IDLE)
				soldier.victory_cheers = 0
			_celebrating = false
		return
	if not _celebrating:
		_clear_time += delta
		if _clear_time < VICTORY_CLEAR_TIME:
			return
		_celebrating = true
		for soldier in soldiers:
			if soldier.unit.is_alive():
				soldier.victory_cheers = VICTORY_CHEERS
				soldier.victory_in = _cheer_random.randf_range(0.0, 0.48)
				if soldier.state in [State.RUN, State.CHEER]:
					_set_state(soldier, State.IDLE)
	for soldier in soldiers:
		if soldier.victory_cheers == 0 or soldier.state != State.IDLE or not soldier.unit.is_alive():
			continue
		soldier.victory_in -= delta
		if soldier.victory_in <= 0.0:
			_set_state(soldier, State.CHEER)


func _enemies_in_range() -> bool:
	var first_amber := team_size(0)
	for index in range(first_amber):
		var blue := soldiers[index]
		if not blue.unit.is_alive():
			continue
		for rival in range(first_amber, soldiers.size()):
			var amber := soldiers[rival]
			if amber.unit.is_alive() and blue.position.distance_squared_to(amber.position) <= ENGAGEMENT_RANGE * ENGAGEMENT_RANGE:
				return true
	return false


func _slot_waypoint(soldier: Soldier, enemy: Soldier, distance: float) -> Vector2:
	var direction := enemy.slot_axis.rotated(SLOT_ANGLES[soldier.slot])
	var stand := (enemy.position + direction * SLOT_DISTANCE).clamp(-arena_limit, arena_limit)
	var radial := (soldier.position - enemy.position).normalized()
	var desired := (stand - enemy.position).normalized()
	var turn := radial.angle_to(desired)
	if absf(turn) <= SLOT_TOLERANCE and distance <= ATTACK_RANGE - 0.055:
		return soldier.position
	# Take short waypoints on the outside of the target instead of crossing through them.
	if absf(turn) > SLOT_TOLERANCE:
		var tangent := radial.rotated(clampf(turn, -0.45, 0.45))
		var radius := clampf(distance, SLOT_DISTANCE, ATTACK_RANGE)
		return (enemy.position + tangent * radius).clamp(-arena_limit, arena_limit)
	return stand


func _run_toward(soldier: Soldier, offset: Vector2, delta: float) -> void:
	_set_state(soldier, State.RUN)
	var direction := offset.normalized()
	var sideways := direction.orthogonal()
	var blocker: Soldier
	var nearest := PASS_LOOKAHEAD
	var lateral := 0.0
	for index in _nearby_indices(soldier.position):
		var other := soldiers[index]
		if other == soldier:
			continue
		var ahead := other.position - soldier.position
		var depth := ahead.dot(direction)
		if depth <= 0.0 or depth >= nearest:
			continue
		var across := ahead.dot(sideways)
		if absf(across) < BODY_CORE and depth <= offset.length() + BODY_CORE * 0.5:
			blocker = other
			nearest = depth
			lateral = across
	if blocker:
		var side := -1.0 if lateral >= 0.0 else 1.0
		if absf(lateral) < 0.06 and soldier.roster_index % 2 == 0:
			side = 1.0
		# Turn back from the arena edge if the preferred passing side runs out of room.
		var passing_point := soldier.position + sideways * side * BODY_SPACING
		if passing_point != passing_point.clamp(-arena_limit, arena_limit):
			side = -side
		var squeeze := 1.0 - smoothstep(BODY_CORE * 0.55, PASS_LOOKAHEAD, nearest)
		var yield_speed := 0.42 * _yield_weight(blocker) * squeeze
		var shove := -sideways * side * yield_speed * delta
		_place_body(blocker, blocker.position + shove)
		direction = (direction * (1.0 - 0.7 * squeeze) + sideways * side * squeeze).normalized()
		offset = direction * offset.length() * (1.0 - 0.42 * squeeze)
	_place_body(soldier, soldier.position + direction * minf(soldier.run_speed * delta, offset.length()))
	soldier.facing = soldier.facing.slerp(direction, minf(12.0 * delta, 1.0)).normalized()


func _incoming_slash(soldier: Soldier, enemy: Soldier) -> bool:
	return enemy.target == soldier.battle_index and enemy.state == State.ATTACK and enemy.time < CONTACT - DURATIONS[State.RAISE]


func _resolve_contacts(contacts: Array[int]) -> void:
	# Evaluate every strike against the same pre-impact state so lethal hits can trade.
	var damage := PackedFloat64Array()
	var reactions := PackedInt32Array()
	var knockback_directions: Dictionary[int, Vector2] = {}
	damage.resize(soldiers.size())
	reactions.resize(soldiers.size())
	for index in contacts:
		var attacker := soldiers[index]
		if attacker.target < 0 or not attacker.unit.is_alive():
			continue
		var defender_index := attacker.target
		var defender := soldiers[defender_index]
		if attacker.team == defender.team or not defender.unit.is_alive() or defender.is_recovering() or elapsed < defender.recovery_protected_until:
			continue
		var offset := defender.position - attacker.position
		if offset.length_squared() > ATTACK_RANGE * ATTACK_RANGE:
			continue
		var direction := offset.normalized()
		if attacker.facing.dot(direction) < 0.58:
			continue
		var guarding := defender.state == State.GUARD or (defender.state == State.BLOCKED and defender.time < 0.28)
		if guarding and defender.facing.dot(-direction) >= 0.56:
			blocks += 1
			reactions[index] = maxi(reactions[index], State.RECOIL)
			reactions[defender_index] = maxi(reactions[defender_index], State.BLOCKED)
			continue
		hits += 1
		var hit_damage := defender.unit.damage_from(attacker.unit, attacker.basic_attack)
		damage[defender_index] += hit_damage
		if hit_damage > 0.0:
			_team_battle_points[attacker.team].award_confirmed_hit(_troop_hit_award)
		if attacker.heavy:
			var reaction := State.KNOCKDOWN if _random.randf() < 0.22 else State.STAGGER
			# Push away from the strike that wins reaction priority. Keep the first strike on ties.
			if reaction > reactions[defender_index]:
				reactions[defender_index] = reaction
				knockback_directions[defender_index] = direction

	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive():
			continue
		if damage[index] > 0.0:
			platoons[soldier.platoon_index].apply_damage(soldier.roster_index, damage[index])
		if not soldier.unit.is_alive():
			_set_state(soldier, State.DEAD)
		elif reactions[index] >= State.RECOIL:
			var reaction := reactions[index] as State
			if reaction != soldier.state and knockback_directions.has(index):
				soldier.knockback_direction = knockback_directions[index]
			_set_state(soldier, reaction)


func _yield_weight(soldier: Soldier) -> float:
	match soldier.state:
		State.IDLE:
			return 1.0 if soldier.target < 0 else 0.55
		State.RUN:
			return 0.65
		_:
			return 0.12


func _index_bodies() -> void:
	_body_cells.clear()
	for soldier in soldiers:
		if soldier.unit.is_alive():
			soldier.position = soldier.position.clamp(-arena_limit, arena_limit)
			_insert_body(soldier.battle_index, Vector2i((soldier.position / CELL_SIZE).floor()))


func _insert_body(index: int, cell: Vector2i) -> void:
	if not _body_cells.has(cell):
		_body_cells[cell] = []
	_body_cells[cell].append(index)


func _place_body(soldier: Soldier, position: Vector2) -> void:
	var old_cell := Vector2i((soldier.position / CELL_SIZE).floor())
	soldier.position = position.clamp(-arena_limit, arena_limit)
	var new_cell := Vector2i((soldier.position / CELL_SIZE).floor())
	if old_cell != new_cell:
		_body_cells[old_cell].erase(soldier.battle_index)
		_insert_body(soldier.battle_index, new_cell)


func _nearby_indices(position: Vector2) -> Array[int]:
	var cell := Vector2i((position / CELL_SIZE).floor())
	var indices: Array[int] = []
	for offset in NEIGHBOR_OFFSETS:
		var neighbor := cell + offset
		if _body_cells.has(neighbor):
			indices.append_array(_body_cells[neighbor])
	# Keep the original solver order as soldiers cross cell boundaries.
	indices.sort()
	return indices


func _separate(delta: float) -> void:
	var nearby: Array[Vector2i] = []
	var soft_limit := 0.95 * delta
	for a in soldiers:
		if not a.unit.is_alive():
			continue
		for index in _nearby_indices(a.position):
			if index <= a.battle_index:
				continue
			var b := soldiers[index]
			var offset := b.position - a.position
			if offset.length_squared() >= BODY_SPACING * BODY_SPACING:
				continue
			nearby.append(Vector2i(a.battle_index, index))
			_resolve_spacing(a, b, offset, soft_limit)
	# Resolving one contact can push a soldier into a different neighbor.
	for iteration in range(2):
		for pair in nearby:
			var a := soldiers[pair.x]
			var b := soldiers[pair.y]
			var offset := b.position - a.position
			if offset.length_squared() < BODY_CORE * BODY_CORE:
				_resolve_spacing(a, b, offset, 0.0)


func _resolve_spacing(a: Soldier, b: Soldier, offset: Vector2, soft_limit: float) -> void:
	var distance := offset.length()
	var direction := offset / distance if distance > 0.0001 else Vector2.RIGHT
	var core := maxf(0.0, BODY_CORE - distance)
	var correction := core + minf((BODY_SPACING - maxf(distance, BODY_CORE)) * 0.24, soft_limit)
	var a_weight := _yield_weight(a)
	var b_weight := _yield_weight(b)
	var a_shift := correction * a_weight / (a_weight + b_weight)
	var a_position := (a.position - direction * a_shift).clamp(-arena_limit, arena_limit)
	var b_shift := correction - (a.position - a_position).dot(direction)
	var b_position := (b.position + direction * b_shift).clamp(-arena_limit, arena_limit)
	var remaining := maxf(0.0, core - (b_position - a_position).dot(direction) + distance)
	_place_body(a, a_position - direction * remaining)
	_place_body(b, b_position)


func _check_winner() -> void:
	var blue_alive := _has_living(0, team_size(0))
	var amber_alive := _has_living(team_size(0), soldiers.size())
	if blue_alive and amber_alive:
		return
	winner = DRAW if not blue_alive and not amber_alive else (0 if blue_alive else 1)
	for soldier in soldiers:
		soldier.target = -1
		soldier.slot = -1
		soldier.approach = -1
		soldier.pursuit = -1
		soldier.retarget_at = -1.0
		soldier.reinforce_ally = -1
		if soldier.unit.is_alive() and _is_mobile(soldier):
			_set_state(soldier, State.IDLE)


func _has_living(first: int, end: int) -> bool:
	for index in range(first, end):
		if soldiers[index].unit.is_alive():
			return true
	return false


func waiting_count() -> int:
	var count := 0
	for soldier in soldiers:
		if _waiting_for_slot(soldier):
			count += 1
	return count


func _waiting_for_slot(soldier: Soldier) -> bool:
	return soldier.unit.is_alive() and soldier.target < 0 and soldier.approach < 0 and soldier.pursuit >= 0 and (
		soldiers[soldier.pursuit].unit.is_alive() and engagements[soldier.pursuit].size() >= MAX_ENGAGEMENTS
	)
