extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

# Reaction states are ordered by priority when several contacts resolve together.
enum State { IDLE, RUN, ATTACK, RAISE, GUARD, LOWER, RECOIL, BLOCKED, STAGGER, KNOCKDOWN, DOWN, GET_UP, DEAD }

const PLATOON_SIZE := 32
const FORMATION_COLUMNS := 8
const MAX_ENGAGEMENTS := 3
const LIVE := -2
const DRAW := -1
const CONTACT := 0.70
const ATTACK_RANGE := 1.48
const WAIT_DISTANCE := 2.16
const ENGAGEMENT_RANGE := 5.0
const PURSUIT_RANGE := ENGAGEMENT_RANGE * 1.3
const SCAN_MIN_INTERVAL := 0.35
const SCAN_MAX_INTERVAL := 0.70
const RUN_SPEED := 2.7
const BODY_SPACING := 0.82
const BODY_CORE := 0.60
const PASS_LOOKAHEAD := 1.05
const SLOT_DISTANCE := 1.22
const SLOT_TOLERANCE := 0.48
const SLOT_ANGLES := [0.0, -TAU / 3.0, TAU / 3.0]
const ARENA_LIMIT := Vector2(9.0, 10.0)
const DURATIONS := {
	State.ATTACK: 88.0 / 60.0,
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
}
const DISPLACEMENTS := {
	State.RECOIL: Vector2(0, 0.155),
	State.STAGGER: Vector2(0, -0.26),
	State.KNOCKDOWN: Vector2(0, -0.625),
	State.GET_UP: Vector2(0, 0.345),
	State.DEAD: Vector2(-0.52, 0.121),
}


class Soldier:
	var unit: Unit
	var team: int
	var roster_index: int
	var position: Vector2
	var facing: Vector2
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
	var heavy := false

	func _init(model: Unit, side: int, index: int, spawn: Vector2) -> void:
		unit = model
		team = side
		roster_index = index
		position = spawn
		facing = Vector2.DOWN if side == 0 else Vector2.UP


var soldiers: Array[Soldier] = []
var platoons: Array[Platoon] = []
var engagements: Array[Dictionary] = []
var elapsed := 0.0
var winner := LIVE
var hits := 0
var blocks := 0

var _random := RandomNumberGenerator.new()
var _attack: Dictionary


func _init(seed_value: int = 8) -> void:
	_random.seed = seed_value
	var infantry: Dictionary = Catalog.TYPES[Catalog.HUMAN_INFANTRY]
	_attack = infantry.basic_attack
	for team in range(2):
		var roster: Array[Unit] = []
		for index in range(PLATOON_SIZE):
			var unit := Unit.new(infantry.starting_hp, infantry.ratings)
			roster.append(unit)
			var side := -1.0 if team == 0 else 1.0
			var column := index % FORMATION_COLUMNS - (FORMATION_COLUMNS - 1) * 0.5
			var row := floori(float(index) / FORMATION_COLUMNS)
			var rank_offset := -0.23 if row % 2 == 0 else 0.23
			var spawn := Vector2(column * 1.55 + rank_offset, side * (4.6 + row * 1.36))
			spawn += Vector2(_random.randf_range(-0.12, 0.12), _random.randf_range(-0.10, 0.10))
			var soldier := Soldier.new(unit, team, index, spawn)
			soldier.ready_in = _random.randf_range(0.05, 0.50)
			soldiers.append(soldier)
			engagements.append({})
		platoons.append(Platoon.new(roster, infantry.platoon_training))


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
	if winner == LIVE:
		_update_ai(delta)
		_separate(delta)


func _assign_targets() -> void:
	for group in engagements:
		group.clear()
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive() or (soldier.target >= 0 and not soldiers[soldier.target].unit.is_alive()):
			soldier.target = -1
			soldier.slot = -1
		if soldier.target >= 0:
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
		if not soldier.unit.is_alive() or not _is_mobile(soldier) or soldier.target >= 0:
			continue
		if soldier.approach < 0 and soldier.scan_in <= 0.0:
			_scan_for_enemy(index)
		if soldier.approach < 0:
			continue
		var enemy := soldiers[soldier.approach]
		var distance := soldier.position.distance_squared_to(enemy.position)
		if not enemy.unit.is_alive() or distance > PURSUIT_RANGE * PURSUIT_RANGE:
			soldier.approach = -1
			soldier.scan_in = 0.0
		elif distance <= ATTACK_RANGE * ATTACK_RANGE:
			if _has_slot(index, soldier.approach):
				soldier.slot = _choose_attack_slot(soldier, soldier.approach)
				soldier.target = soldier.approach
				_link_engagement(index, soldier.target)
			soldier.approach = -1
	_align_reciprocal_slots()


func _scan_for_enemy(index: int) -> void:
	var soldier := soldiers[index]
	soldier.scan_in = _random.randf_range(SCAN_MIN_INTERVAL, SCAN_MAX_INTERVAL)
	var nearest_distance := INF
	var candidates: Array[int] = []
	soldier.pursuit = -1
	for rival in range(soldiers.size()):
		var enemy := soldiers[rival]
		if enemy.team == soldier.team or not enemy.unit.is_alive():
			continue
		var distance := soldier.position.distance_squared_to(enemy.position)
		if distance < nearest_distance:
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
		if position != position.clamp(-ARENA_LIMIT, ARENA_LIMIT):
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
		_:
			_set_state(soldier, State.IDLE)
			soldier.ready_in = _random.randf_range(0.08, 0.36)


func _move_action(soldier: Soldier, before: float) -> void:
	if soldier.state == State.ATTACK and soldier.target >= 0 and soldier.time <= 0.88:
		var advance := clampf((soldier.time - 0.33) / 0.55, 0.0, 1.0)
		var previous := clampf((before - 0.33) / 0.55, 0.0, 1.0)
		var enemy := soldiers[soldier.target]
		var space := maxf(0.0, (enemy.position - soldier.position).dot(soldier.facing) - 0.86)
		soldier.position += soldier.facing * minf(space, 0.52 * (advance - previous))
	elif DISPLACEMENTS.has(soldier.state):
		var duration: float = DURATIONS[soldier.state]
		var fraction := smoothstep(0.0, 0.85, soldier.time / duration)
		var previous := smoothstep(0.0, 0.85, before / duration)
		var travel: Vector2 = DISPLACEMENTS[soldier.state]
		var right := Vector2(soldier.facing.y, -soldier.facing.x)
		soldier.position += (right * travel.x + soldier.facing * travel.y) * (fraction - previous)


func _update_ai(delta: float) -> void:
	for soldier in soldiers:
		if not _is_mobile(soldier) or not soldier.unit.is_alive():
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
		if not assigned or soldier.ready_in > 0.0:
			continue
		if soldier.think_in <= 0.0 and _threatened(soldier):
			soldier.think_in = _random.randf_range(0.30, 0.48)
			if _random.randf() < 0.50:
				_set_state(soldier, State.RAISE)
				continue
		soldier.heavy = _random.randf() < 0.28
		_set_state(soldier, State.ATTACK)


func _slot_waypoint(soldier: Soldier, enemy: Soldier, distance: float) -> Vector2:
	var direction := enemy.slot_axis.rotated(SLOT_ANGLES[soldier.slot])
	var stand := (enemy.position + direction * SLOT_DISTANCE).clamp(-ARENA_LIMIT, ARENA_LIMIT)
	var radial := (soldier.position - enemy.position).normalized()
	var desired := (stand - enemy.position).normalized()
	var turn := radial.angle_to(desired)
	if absf(turn) <= SLOT_TOLERANCE and distance <= ATTACK_RANGE - 0.055:
		return soldier.position
	# Take short waypoints on the outside of the target instead of crossing through them.
	if absf(turn) > SLOT_TOLERANCE:
		var tangent := radial.rotated(clampf(turn, -0.45, 0.45))
		var radius := clampf(distance, SLOT_DISTANCE, ATTACK_RANGE)
		return (enemy.position + tangent * radius).clamp(-ARENA_LIMIT, ARENA_LIMIT)
	return stand


func _run_toward(soldier: Soldier, offset: Vector2, delta: float) -> void:
	_set_state(soldier, State.RUN)
	var direction := offset.normalized()
	var sideways := direction.orthogonal()
	var blocker: Soldier
	var nearest := PASS_LOOKAHEAD
	var lateral := 0.0
	for other in soldiers:
		if other == soldier or not other.unit.is_alive():
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
		if passing_point != passing_point.clamp(-ARENA_LIMIT, ARENA_LIMIT):
			side = -side
		var squeeze := 1.0 - smoothstep(BODY_CORE * 0.55, PASS_LOOKAHEAD, nearest)
		var yield_speed := 0.42 * _yield_weight(blocker) * squeeze
		var shove := -sideways * side * yield_speed * delta
		blocker.position = (blocker.position + shove).clamp(-ARENA_LIMIT, ARENA_LIMIT)
		direction = (direction * (1.0 - 0.7 * squeeze) + sideways * side * squeeze).normalized()
		offset = direction * offset.length() * (1.0 - 0.42 * squeeze)
	soldier.position += direction * minf(RUN_SPEED * delta, offset.length())
	soldier.facing = soldier.facing.slerp(direction, minf(12.0 * delta, 1.0)).normalized()


func _threatened(soldier: Soldier) -> bool:
	var enemy := soldiers[soldier.target]
	return enemy.target >= 0 and soldiers[enemy.target] == soldier and enemy.state == State.ATTACK and enemy.time < CONTACT - DURATIONS[State.RAISE]


func _resolve_contacts(contacts: Array[int]) -> void:
	# Evaluate every strike against the same pre-impact state so lethal hits can trade.
	var damage := PackedFloat64Array()
	var reactions := PackedInt32Array()
	damage.resize(soldiers.size())
	reactions.resize(soldiers.size())
	for index in contacts:
		var attacker := soldiers[index]
		if attacker.target < 0 or not attacker.unit.is_alive():
			continue
		var defender := soldiers[attacker.target]
		var offset := defender.position - attacker.position
		if not defender.unit.is_alive() or offset.length_squared() > ATTACK_RANGE * ATTACK_RANGE:
			continue
		var direction := offset.normalized()
		if attacker.facing.dot(direction) < 0.58:
			continue
		var guarding := defender.state == State.GUARD or (defender.state == State.BLOCKED and defender.time < 0.28)
		if guarding and defender.facing.dot(-direction) >= 0.56:
			blocks += 1
			reactions[index] = maxi(reactions[index], State.RECOIL)
			reactions[attacker.target] = maxi(reactions[attacker.target], State.BLOCKED)
			continue
		hits += 1
		damage[attacker.target] += defender.unit.damage_from(attacker.unit, _attack)
		if attacker.heavy:
			var reaction := State.KNOCKDOWN if _random.randf() < 0.22 else State.STAGGER
			reactions[attacker.target] = maxi(reactions[attacker.target], reaction)

	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive():
			continue
		if damage[index] > 0.0:
			platoons[soldier.team].apply_damage(soldier.roster_index, damage[index])
		if not soldier.unit.is_alive():
			_set_state(soldier, State.DEAD)
		elif reactions[index] >= State.RECOIL:
			if soldier.state not in [State.KNOCKDOWN, State.DOWN, State.GET_UP]:
				_set_state(soldier, reactions[index] as State)


func _yield_weight(soldier: Soldier) -> float:
	match soldier.state:
		State.IDLE:
			return 1.0 if soldier.target < 0 else 0.55
		State.RUN:
			return 0.65
		_:
			return 0.12


func _separate(delta: float) -> void:
	var living: Array[Soldier] = []
	for soldier in soldiers:
		if soldier.unit.is_alive():
			soldier.position = soldier.position.clamp(-ARENA_LIMIT, ARENA_LIMIT)
			living.append(soldier)
	var nearby: Array[Vector2i] = []
	var soft_limit := 0.95 * delta
	for index in range(living.size()):
		var a := living[index]
		for other in range(index + 1, living.size()):
			var b := living[other]
			var offset := b.position - a.position
			if offset.length_squared() >= BODY_SPACING * BODY_SPACING:
				continue
			nearby.append(Vector2i(index, other))
			_resolve_spacing(a, b, offset, soft_limit)
	# Resolving one contact can push a soldier into a different neighbor.
	for iteration in range(2):
		for pair in nearby:
			var a := living[pair.x]
			var b := living[pair.y]
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
	var a_position := (a.position - direction * a_shift).clamp(-ARENA_LIMIT, ARENA_LIMIT)
	var b_shift := correction - (a.position - a_position).dot(direction)
	var b_position := (b.position + direction * b_shift).clamp(-ARENA_LIMIT, ARENA_LIMIT)
	var remaining := maxf(0.0, core - (b_position - a_position).dot(direction) + distance)
	a.position = (a_position - direction * remaining).clamp(-ARENA_LIMIT, ARENA_LIMIT)
	b.position = b_position


func _check_winner() -> void:
	var blue_alive := platoons[0].health_fractions().x > 0.0
	var amber_alive := platoons[1].health_fractions().x > 0.0
	if blue_alive and amber_alive:
		return
	winner = DRAW if not blue_alive and not amber_alive else (0 if blue_alive else 1)
	for soldier in soldiers:
		soldier.target = -1
		soldier.slot = -1
		soldier.approach = -1
		soldier.pursuit = -1
		if soldier.unit.is_alive() and _is_mobile(soldier):
			_set_state(soldier, State.IDLE)


func waiting_count() -> int:
	var count := 0
	for soldier in soldiers:
		if soldier.unit.is_alive() and soldier.target < 0 and soldier.approach < 0 and soldier.pursuit >= 0:
			if soldiers[soldier.pursuit].unit.is_alive() and engagements[soldier.pursuit].size() >= MAX_ENGAGEMENTS:
				count += 1
	return count
