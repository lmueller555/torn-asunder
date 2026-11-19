extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

# Reaction states are ordered by priority when several contacts resolve together.
enum State { IDLE, RUN, ATTACK, RAISE, GUARD, LOWER, RECOIL, BLOCKED, STAGGER, KNOCKDOWN, DOWN, GET_UP, DEAD }

const PLATOON_SIZE := 10
const MAX_ENGAGEMENTS := 3
const LIVE := -2
const DRAW := -1
const CONTACT := 0.70
const ATTACK_RANGE := 1.48
const WAIT_DISTANCE := 2.16
const ENGAGEMENT_RANGE := 5.0
const RUN_SPEED := 2.7
const SPACING := 0.68
const ARENA_LIMIT := Vector2(9.0, 8.0)
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
	var target := -1
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
			var column := index % 5 - 2
			var row := floori(float(index) / 5.0)
			var spawn := Vector2(column * 1.55 + row * 0.46, side * (4.6 + row * 1.36))
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
		if soldier.state == State.ATTACK and before < CONTACT and soldier.time >= CONTACT:
			contacts.append(index)
		_move_action(soldier, before)
		_finish_action(soldier)

	if winner == LIVE:
		_resolve_contacts(contacts)
		_check_winner()
	if winner == LIVE:
		_update_ai(delta)
		_separate()


func _assign_targets() -> void:
	for group in engagements:
		group.clear()
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive() or (soldier.target >= 0 and not soldiers[soldier.target].unit.is_alive()):
			soldier.target = -1
		if soldier.target >= 0:
			_link_engagement(index, soldier.target)
	# Assignment is shared by both sides. A reciprocal target uses the same slot.
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if not soldier.unit.is_alive() or not _is_mobile(soldier) or soldier.target >= 0:
			continue
		var nearest := -1
		var nearest_distance := INF
		var open_target := -1
		var open_distance := ENGAGEMENT_RANGE * ENGAGEMENT_RANGE
		for rival in range(soldiers.size()):
			var enemy := soldiers[rival]
			if enemy.team == soldier.team or not enemy.unit.is_alive():
				continue
			var distance := soldier.position.distance_squared_to(enemy.position)
			if distance < nearest_distance:
				nearest = rival
				nearest_distance = distance
			if distance < open_distance and _has_slot(index, rival):
				open_target = rival
				open_distance = distance
		soldier.pursuit = nearest
		if open_target >= 0:
			soldier.target = open_target
			_link_engagement(index, open_target)


func _has_slot(index: int, rival: int) -> bool:
	return engagements[index].has(rival) or (
		engagements[index].size() < MAX_ENGAGEMENTS and engagements[rival].size() < MAX_ENGAGEMENTS
	)


func _link_engagement(index: int, rival: int) -> void:
	engagements[index][rival] = true
	engagements[rival][index] = true


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
		var goal := soldier.target if assigned else soldier.pursuit
		if goal < 0 or not soldiers[goal].unit.is_alive():
			_set_state(soldier, State.IDLE)
			continue
		var offset := soldiers[goal].position - soldier.position
		var distance := offset.length()
		if distance > 0.001:
			soldier.facing = offset / distance
		var reach := ATTACK_RANGE - 0.08 if assigned else WAIT_DISTANCE
		if distance > reach + 0.025:
			_set_state(soldier, State.RUN)
			soldier.position += soldier.facing * minf(RUN_SPEED * delta, distance - reach)
			continue
		_set_state(soldier, State.IDLE)
		if not assigned or soldier.ready_in > 0.0:
			continue
		if soldier.think_in <= 0.0 and _threatened(soldier):
			soldier.think_in = _random.randf_range(0.30, 0.48)
			if _random.randf() < 0.50:
				_set_state(soldier, State.RAISE)
				continue
		soldier.heavy = _random.randf() < 0.28
		_set_state(soldier, State.ATTACK)


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


func _separate() -> void:
	for index in range(soldiers.size()):
		var a := soldiers[index]
		if not a.unit.is_alive():
			continue
		for other in range(index + 1, soldiers.size()):
			var b := soldiers[other]
			if not b.unit.is_alive():
				continue
			var offset := b.position - a.position
			var distance := offset.length()
			if distance >= SPACING:
				continue
			var direction := offset / distance if distance > 0.0001 else Vector2.RIGHT
			var move := direction * (SPACING - distance) * 0.5
			a.position -= move
			b.position += move
	for soldier in soldiers:
		if soldier.unit.is_alive():
			soldier.position = soldier.position.clamp(-ARENA_LIMIT, ARENA_LIMIT)


func _check_winner() -> void:
	var blue_alive := platoons[0].health_fractions().x > 0.0
	var amber_alive := platoons[1].health_fractions().x > 0.0
	if blue_alive and amber_alive:
		return
	winner = DRAW if not blue_alive and not amber_alive else (0 if blue_alive else 1)
	for soldier in soldiers:
		soldier.target = -1
		soldier.pursuit = -1
		if soldier.unit.is_alive() and _is_mobile(soldier):
			_set_state(soldier, State.IDLE)


func waiting_count() -> int:
	var count := 0
	for soldier in soldiers:
		if soldier.unit.is_alive() and soldier.target < 0 and soldier.pursuit >= 0:
			if engagements[soldier.pursuit].size() >= MAX_ENGAGEMENTS:
				count += 1
	return count
