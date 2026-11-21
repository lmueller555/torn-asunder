extends RefCounted
## Campaign mission simulation: a player hero, commandable platoons, AI armies,
## destructible objectives, scripted events and win or loss conditions.
##
## The simulation owns every rule and runs without a scene, so tests can play
## missions headlessly. MissionView renders it and feeds it player input.

const Unit := preload("res://game/combat/combat_unit.gd")
const CombatPlatoon := preload("res://game/combat/platoon.gd")
const Units := preload("res://game/mission/mission_units.gd")

enum State { IDLE, WALK, RUN, ATTACK, RAISE, GUARD, LOWER, RECOIL, BLOCKED, STAGGER, KNOCKDOWN, DOWN, GET_UP, DEAD, CHEER, DODGE, CAST }
enum Kind { SOLDIER, HERO, STRUCTURE }
enum Attack { LIGHT, HEAVY, RANGED, ABILITY }
enum Outcome { LIVE, VICTORY, DEFEAT }

const PLAYER_TEAM := 0
const ENEMY_TEAM := 1
## Missions resolve hits faster than drills so a battle plays out in minutes.
const DAMAGE_SCALE := 2.6
const MELEE_REACH := 1.42
const BODY_RADIUS := 0.4
const SLOT_SPACING := 1.6
const WALK_SPEED := 1.2
const ANCHOR_SPEED_FACTOR := 0.82
const SOLDIER_CAP := 3
const HERO_CAP := 6
const STRUCTURE_CAP := 10
const PATH_CELL := 2.0
const CELL_SIZE := 1.5
const HERO_REGEN_DELAY := 6.0
const HERO_REGEN_RATE := 0.015
const DODGE_TIME := 0.38
const DODGE_DISTANCE := 4.4
const INTERACT_RADIUS := 3.2
const REFORM_DELAY := 4.0
const OVERRUN_TIME := 10.0
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const DURATIONS := {
	State.RAISE: 0.32,
	State.LOWER: 0.30,
	State.RECOIL: 49.0 / 60.0,
	State.BLOCKED: 44.0 / 60.0,
	State.STAGGER: 0.9,
	State.KNOCKDOWN: 1.15,
	State.DOWN: 0.4,
	State.GET_UP: 94.0 / 60.0,
	State.DEAD: 1.2,
	State.CHEER: 84.0 / 60.0,
	State.DODGE: DODGE_TIME,
}
const DISPLACEMENTS := {
	State.STAGGER: 0.78,
	State.KNOCKDOWN: 1.875,
	State.RECOIL: -0.15,
}


class Fighter:
	var index: int
	var kind: int
	var type_id: StringName
	var info: Dictionary
	var unit: Unit
	var team: int
	var platoon := -1
	var slot := Vector2.ZERO
	var position: Vector2
	var facing := Vector2.UP
	var radius := BODY_RADIUS
	var speed := 2.7
	var state := State.IDLE
	var time := 0.0
	var action_duration := 0.0
	var contact_time := 0.0
	var attack_kind := Attack.LIGHT
	var heavy := false
	var resolved := false
	var ready_in := 0.0
	var scan_in := 0.0
	var think_in := 0.0
	var target := -1
	var knockback := Vector2.ZERO
	var protected_until := 0.0
	var rooted_until := 0.0
	var damage_buff_until := 0.0
	var guard_buff_until := 0.0
	var last_hurt := -100.0
	var name := ""
	var controlled := false
	var combo := 0
	var queued_light := false
	var kills := 0
	var removed := false
	var spread := 0.0
	# Structures that travel on their own, such as an escorted wagon.
	var structure_id := ""
	var structure_kind: StringName
	var route := PackedVector2Array()
	var route_index := 0
	var escort_radius := 12.0
	var moving := false

	func is_alive() -> bool:
		return not removed and unit.is_alive()

	func is_recovering() -> bool:
		return state == State.KNOCKDOWN or state == State.DOWN or state == State.GET_UP

	func is_mobile() -> bool:
		return state == State.IDLE or state == State.WALK or state == State.RUN

	func role() -> int:
		return int(info.get("role", Units.Role.MELEE))


class Squad:
	var index: int
	var id: String
	var name: String
	var team: int
	var type_id: StringName
	var info: Dictionary
	var level := 1
	var members: Array[int] = []
	var combat: CombatPlatoon
	var anchor := Vector2.ZERO
	var facing := Vector2.UP
	var order: Dictionary = {"kind": "hold"}
	var path := PackedVector2Array()
	var path_index := 0
	var goal := Vector2.INF
	var commandable := false
	var spawned := false
	var aggro := 0.0
	var leash := 16.0
	var think_in := 0.0
	var last_engaged := -100.0
	var kills := 0
	var persist := ""
	var follow_slot := 0
	var definition: Dictionary

	func alive_count(battle) -> int:
		var count := 0
		for member in members:
			if battle.fighters[member].is_alive():
				count += 1
		return count

	func centroid(battle) -> Vector2:
		var sum := Vector2.ZERO
		var count := 0
		for member in members:
			var fighter = battle.fighters[member]
			if fighter.is_alive():
				sum += fighter.position
				count += 1
		return sum / count if count > 0 else anchor


var mission: Dictionary
var fighters: Array[Fighter] = []
var squads: Array[Squad] = []
var squad_ids: Dictionary = {}
var structures: Dictionary = {}
var zones: Dictionary = {}
var interactables: Array[Dictionary] = []
var objectives: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var messages: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var raised: Array[String] = []
var bounds := Rect2(-50, -50, 100, 100)
var hero: Fighter
var hero_ability: StringName
var hero_ability_name := ""
var ability_cooldown := 20.0
var ability_ready_at := 0.0
var interact_progress := 0.0
var interact_target := -1
var elapsed := 0.0
var outcome := Outcome.LIVE
var outcome_reason := ""
var player_losses := 0
var enemy_losses := 0

var _input := {}
var _random := RandomNumberGenerator.new()
var _astar := AStarGrid2D.new()
var _events: Array[Dictionary] = []
var _fired: Dictionary = {}
var _pending: Array[Dictionary] = []
var _done_at: Dictionary = {}
var _cells: Dictionary = {}
var _attackers := PackedInt32Array()
var _team_alive: Array = [[], []]
var _overrun: Dictionary = {}


func _init(definition: Dictionary, hero_id: StringName, hero_level: int, levels: Dictionary = {}, seed_value: int = 11) -> void:
	mission = definition
	_random.seed = seed_value
	var map: Dictionary = definition.get("map", {})
	var size: Vector2 = map.get("size", Vector2(100, 100))
	bounds = Rect2(-size * 0.5, size)
	for obstacle: Dictionary in map.get("obstacles", []):
		obstacles.append(obstacle)
	for zone_id in map.get("zones", {}):
		zones[zone_id] = map.zones[zone_id]
	_build_navigation()

	var hero_info := Units.definition(hero_id)
	var hero_start: Dictionary = definition.get("hero", {})
	hero = _add_fighter(hero_id, hero_info, PLAYER_TEAM, hero_level, _point(hero_start.get("pos", Vector2.ZERO)))
	hero.kind = Kind.HERO
	hero.controlled = true
	hero.name = hero_info.get("name", "")
	hero.facing = hero_start.get("facing", Vector2.UP)
	hero_ability = hero_info.get("ability", &"")
	hero_ability_name = hero_info.get("ability_name", "")
	ability_cooldown = hero_info.get("ability_cooldown", 20.0)

	for entry: Dictionary in definition.get("structures", []):
		_add_structure(entry)
	for entry: Dictionary in definition.get("platoons", []):
		var squad := _create_squad(entry, levels)
		if not entry.get("hidden", false):
			_spawn_squad(squad)
	for entry: Dictionary in definition.get("interactables", []):
		var item := entry.duplicate()
		item.pos = _point(item.pos)
		item.progress = 0.0
		item.done = false
		item.active = not entry.get("hidden", false)
		interactables.append(item)
	for entry: Dictionary in definition.get("objectives", []):
		var objective := entry.duplicate()
		objective.status = "hidden" if entry.get("hidden", false) else "active"
		objective.started = 0.0
		objectives.append(objective)
	for entry: Dictionary in definition.get("events", []):
		_events.append(entry)


# ---------------------------------------------------------------- setup


func _add_fighter(type_id: StringName, info: Dictionary, team: int, level: int, spawn: Vector2) -> Fighter:
	var fighter := Fighter.new()
	fighter.index = fighters.size()
	fighter.type_id = type_id
	fighter.info = info
	fighter.team = team
	fighter.unit = Units.make_unit(type_id, level)
	fighter.position = spawn
	fighter.speed = info.get("speed", 2.7)
	fighter.radius = BODY_RADIUS * float(info.get("scale", 1.0))
	fighter.spread = _random.randf_range(-0.9, 0.9)
	fighter.ready_in = _random.randf_range(0.1, 0.8)
	fighters.append(fighter)
	_attackers.append(0)
	return fighter


func _add_structure(entry: Dictionary) -> void:
	var info: Dictionary = Units.STRUCTURES.get(entry.kind, {})
	var fighter := Fighter.new()
	fighter.index = fighters.size()
	fighter.kind = Kind.STRUCTURE
	fighter.type_id = entry.kind
	fighter.info = {"role": Units.Role.STRUCTURE}
	fighter.team = entry.get("team", PLAYER_TEAM)
	fighter.unit = Unit.new(entry.get("hp", info.get("hp", 20000.0)))
	fighter.position = _point(entry.pos)
	fighter.facing = entry.get("facing", Vector2.UP)
	fighter.radius = entry.get("radius", info.get("radius", 1.5))
	fighter.name = entry.get("name", info.get("name", ""))
	fighter.structure_id = entry.id
	fighter.structure_kind = entry.kind
	fighter.speed = entry.get("speed", 1.7)
	fighter.escort_radius = entry.get("escort_radius", 12.0)
	fighter.moving = entry.get("moving", false)
	for point in entry.get("path", []):
		fighter.route.append(_point(point))
	fighters.append(fighter)
	_attackers.append(0)
	structures[entry.id] = fighter.index


func _create_squad(entry: Dictionary, levels: Dictionary) -> Squad:
	var squad := Squad.new()
	squad.index = squads.size()
	squad.id = entry.id
	squad.definition = entry
	squad.team = entry.get("team", ENEMY_TEAM)
	squad.type_id = entry.type
	squad.info = Units.definition(entry.type)
	squad.name = entry.get("name", squad.info.get("name", entry.id))
	squad.persist = entry.get("persist", "")
	squad.level = maxi(int(entry.get("level", 1)), int(levels.get(squad.persist, 0)))
	squad.commandable = entry.get("commandable", squad.team == PLAYER_TEAM)
	squad.aggro = entry.get("aggro", 0.0)
	squad.order = entry.get("order", {"kind": "hold"}).duplicate()
	squad.anchor = _point(entry.pos)
	squad.facing = entry.get("facing", Vector2.DOWN if squad.team == ENEMY_TEAM else Vector2.UP).normalized()
	squads.append(squad)
	squad_ids[squad.id] = squad.index
	var follow_index := 0
	for other in squads:
		if other != squad and other.team == PLAYER_TEAM and other.commandable:
			follow_index += 1
	squad.follow_slot = follow_index
	return squad


func _spawn_squad(squad: Squad) -> void:
	if squad.spawned:
		return
	squad.spawned = true
	var entry := squad.definition
	var count: int = entry.get("count", 1 if squad.info.get("role") == Units.Role.HERO else 16)
	var columns: int = entry.get("columns", clampi(ceili(sqrt(count * 1.4)), 1, 8))
	var roster: Array[Unit] = []
	var right := Vector2(-squad.facing.y, squad.facing.x)
	for i in range(count):
		var column := i % columns
		var row := floori(float(i) / columns)
		var slot := Vector2((column - (columns - 1) * 0.5) * SLOT_SPACING, -row * SLOT_SPACING)
		var spawn := squad.anchor + right * slot.x + squad.facing * slot.y
		spawn += Vector2(_random.randf_range(-0.2, 0.2), _random.randf_range(-0.2, 0.2))
		var fighter := _add_fighter(squad.type_id, squad.info, squad.team, squad.level, _free_point(spawn))
		fighter.platoon = squad.index
		fighter.slot = slot
		fighter.facing = squad.facing
		if squad.info.get("role") == Units.Role.HERO:
			fighter.kind = Kind.HERO
			fighter.name = squad.info.get("name", "")
		squad.members.append(fighter.index)
		roster.append(fighter.unit)
	squad.combat = CombatPlatoon.new(roster, {CombatPlatoon.Skill.FORMATION_DRILL: entry.get("drill", 1)})
	_apply_order(squad, squad.order)


func _point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is String or value is StringName:
		var zone: Dictionary = zones.get(String(value), {})
		return zone.get("pos", Vector2.ZERO)
	return Vector2.ZERO


# ---------------------------------------------------------------- navigation


func _build_navigation() -> void:
	_astar.region = Rect2i(
		floori(bounds.position.x / PATH_CELL), floori(bounds.position.y / PATH_CELL),
		ceili(bounds.size.x / PATH_CELL) + 1, ceili(bounds.size.y / PATH_CELL) + 1
	)
	_astar.cell_size = Vector2(PATH_CELL, PATH_CELL)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for x in range(_astar.region.position.x, _astar.region.end.x):
		for y in range(_astar.region.position.y, _astar.region.end.y):
			var center := Vector2(x, y) * PATH_CELL
			if _blocked(center, 0.9) or not bounds.grow(-0.5).has_point(center):
				_astar.set_point_solid(Vector2i(x, y))


func _blocked(point: Vector2, margin: float = 0.0) -> bool:
	for obstacle in obstacles:
		if obstacle.has("rect"):
			if (obstacle.rect as Rect2).grow(margin).has_point(point):
				return true
		elif obstacle.has("circle"):
			var circle: Vector3 = obstacle.circle
			if point.distance_to(Vector2(circle.x, circle.y)) < circle.z + margin:
				return true
	return false


func _cell(point: Vector2) -> Vector2i:
	var cell := Vector2i((point / PATH_CELL).round())
	return cell.clamp(_astar.region.position, _astar.region.end - Vector2i.ONE)


func _free_cell(cell: Vector2i) -> Vector2i:
	if not _astar.is_point_solid(cell):
		return cell
	for radius in range(1, 12):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var candidate := (cell + Vector2i(dx, dy)).clamp(_astar.region.position, _astar.region.end - Vector2i.ONE)
				if not _astar.is_point_solid(candidate):
					return candidate
	return cell


func _free_point(point: Vector2) -> Vector2:
	if not _blocked(point, BODY_RADIUS):
		return point
	return Vector2(_free_cell(_cell(point))) * PATH_CELL


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _clear_line(from, to):
		return PackedVector2Array([to])
	var start := _free_cell(_cell(from))
	var finish := _free_cell(_cell(to))
	var raw := _astar.get_point_path(start, finish)
	var result := PackedVector2Array()
	if raw.is_empty():
		result.append(to)
		return result
	# Skip waypoints that have a clear straight line from the last kept point.
	var current := from
	var index := 0
	while index < raw.size():
		var furthest := index
		for look in range(raw.size() - 1, index, -1):
			if _clear_line(current, raw[look]):
				furthest = look
				break
		current = raw[furthest]
		result.append(current)
		index = furthest + 1
	if _clear_line(current, to):
		result.append(to)
	return result


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var distance := a.distance_to(b)
	var steps := maxi(1, ceili(distance / 0.8))
	for i in range(1, steps + 1):
		if _blocked(a.lerp(b, float(i) / steps), 0.7):
			return false
	return true


# ---------------------------------------------------------------- public API


func set_hero_input(input: Dictionary) -> void:
	_input = input


func squad(id: String) -> Squad:
	return squads[squad_ids[id]] if squad_ids.has(id) else null


func command(squad_index: int, order: Dictionary) -> void:
	if squad_index < 0 or squad_index >= squads.size():
		return
	var target := squads[squad_index]
	if not target.commandable or target.team != PLAYER_TEAM:
		return
	_apply_order(target, order)


func commandable_squads() -> Array[Squad]:
	var result: Array[Squad] = []
	for item in squads:
		if item.commandable and item.spawned and item.team == PLAYER_TEAM:
			result.append(item)
	return result


func ability_remaining() -> float:
	return maxf(0.0, ability_ready_at - elapsed)


func active_interactable() -> int:
	for i in range(interactables.size()):
		var item := interactables[i]
		if item.active and not item.done and hero.position.distance_to(item.pos) <= INTERACT_RADIUS:
			return i
	return -1


func step(delta: float) -> void:
	if outcome != Outcome.LIVE:
		_advance_animation_clocks(delta)
		_update_effects(delta)
		return
	elapsed += delta
	_refresh_team_lists()
	_count_attackers()
	_update_hero_input(delta)
	_update_squads(delta)
	_update_structures(delta)
	for fighter in fighters:
		_advance(fighter, delta)
	for fighter in fighters:
		if fighter.kind != Kind.STRUCTURE and not fighter.controlled and fighter.is_alive() and fighter.is_mobile():
			_think(fighter, delta)
	_update_projectiles(delta)
	_update_effects(delta)
	_index_bodies()
	_separate(delta)
	_regenerate(delta)
	_update_interaction(delta)
	_update_objectives(delta)
	_run_events()


func _advance_animation_clocks(delta: float) -> void:
	for fighter in fighters:
		fighter.time += delta
		if fighter.state == State.DEAD:
			fighter.time = minf(fighter.time, DURATIONS[State.DEAD])
		elif fighter.state in [State.RUN, State.WALK]:
			_set_state(fighter, State.IDLE)
		elif fighter.time >= _duration(fighter) and fighter.state != State.IDLE and fighter.state != State.CHEER:
			_set_state(fighter, State.IDLE)
	# Survivors celebrate the result.
	if outcome == Outcome.VICTORY:
		for fighter in fighters:
			if fighter.team == PLAYER_TEAM and fighter.is_alive() and fighter.kind != Kind.STRUCTURE and fighter.state == State.IDLE:
				if _random.randf() < delta * 0.5:
					_set_state(fighter, State.CHEER)


# ---------------------------------------------------------------- per-tick helpers


func _refresh_team_lists() -> void:
	_team_alive = [[], []]
	for fighter in fighters:
		if fighter.is_alive():
			_team_alive[fighter.team].append(fighter.index)


func _count_attackers() -> void:
	_attackers.fill(0)
	for fighter in fighters:
		if fighter.target >= 0 and fighter.is_alive() and fighter.role() != Units.Role.RANGED:
			_attackers[fighter.target] += 1


func _cap(fighter: Fighter) -> int:
	match fighter.kind:
		Kind.HERO:
			return HERO_CAP
		Kind.STRUCTURE:
			return STRUCTURE_CAP
	return SOLDIER_CAP


func _set_state(fighter: Fighter, state: State) -> void:
	if fighter.state != state:
		fighter.state = state
		fighter.time = 0.0


func _duration(fighter: Fighter) -> float:
	if fighter.state == State.ATTACK or fighter.state == State.CAST:
		return fighter.action_duration
	if fighter.state == State.GUARD:
		return INF if fighter.controlled else 0.6
	return DURATIONS.get(fighter.state, INF)


func _advance(fighter: Fighter, delta: float) -> void:
	if fighter.kind == Kind.STRUCTURE:
		return
	var before := fighter.time
	fighter.time += delta
	fighter.ready_in = maxf(0.0, fighter.ready_in - delta)
	fighter.scan_in = maxf(0.0, fighter.scan_in - delta)
	fighter.think_in = maxf(0.0, fighter.think_in - delta)
	if not fighter.is_alive():
		if fighter.state != State.DEAD and not fighter.removed:
			_set_state(fighter, State.DEAD)
		if fighter.state == State.DEAD:
			fighter.time = minf(fighter.time, DURATIONS[State.DEAD])
		return
	if (fighter.state == State.ATTACK or fighter.state == State.CAST) and not fighter.resolved and fighter.time >= fighter.contact_time:
		fighter.resolved = true
		_resolve_action(fighter)
	_move_action(fighter, before, delta)
	if fighter.time >= _duration(fighter):
		_finish_action(fighter)


func _finish_action(fighter: Fighter) -> void:
	match fighter.state:
		State.RAISE:
			_set_state(fighter, State.GUARD)
		State.GUARD, State.BLOCKED:
			_set_state(fighter, State.LOWER)
		State.KNOCKDOWN:
			_set_state(fighter, State.DOWN)
		State.DOWN:
			_set_state(fighter, State.GET_UP)
		State.GET_UP:
			fighter.protected_until = elapsed + 0.5
			_set_state(fighter, State.IDLE)
		State.ATTACK:
			if fighter.controlled and fighter.queued_light:
				fighter.queued_light = false
				fighter.combo = (fighter.combo + 1) % 3
				_start_attack(fighter, Attack.LIGHT)
				return
			fighter.combo = 0
			_set_state(fighter, State.IDLE)
			fighter.ready_in = _random.randf_range(0.15, 0.45) if not fighter.controlled else 0.0
		_:
			_set_state(fighter, State.IDLE)
			if not fighter.controlled:
				fighter.ready_in = maxf(fighter.ready_in, _random.randf_range(0.08, 0.36))


func _move_action(fighter: Fighter, before: float, delta: float) -> void:
	if fighter.state == State.DODGE:
		var step_distance := DODGE_DISTANCE * delta / DODGE_TIME
		_place(fighter, fighter.position + fighter.knockback * step_distance)
		return
	if fighter.state == State.ATTACK and fighter.attack_kind != Attack.RANGED:
		# Step into the swing, but stop short of the target's body.
		var advance := 0.45 if fighter.kind == Kind.HERO else 0.38
		var window := fighter.action_duration * 0.55
		if fighter.time < window:
			var space := INF
			if fighter.target >= 0:
				var target := fighter_at(fighter.target)
				space = maxf(0.0, fighter.position.distance_to(target.position) - target.radius - fighter.radius - 0.25)
			_place(fighter, fighter.position + fighter.facing * minf(space, advance * delta / window))
		return
	if DISPLACEMENTS.has(fighter.state):
		var duration: float = DURATIONS[fighter.state]
		var fraction := smoothstep(0.0, 0.85, fighter.time / duration)
		var previous := smoothstep(0.0, 0.85, before / duration)
		var axis := fighter.knockback if fighter.state != State.RECOIL else fighter.facing
		_place(fighter, fighter.position + axis * DISPLACEMENTS[fighter.state] * (fraction - previous))


func fighter_at(index: int) -> Fighter:
	return fighters[index]


# ---------------------------------------------------------------- hero control


func _update_hero_input(delta: float) -> void:
	if not hero.is_alive():
		return
	var move: Vector2 = _input.get("move", Vector2.ZERO)
	if move.length() > 1.0:
		move = move.normalized()
	var guard: bool = _input.get("guard", false)
	match hero.state:
		State.IDLE, State.WALK, State.RUN:
			if guard:
				_set_state(hero, State.RAISE)
			elif _input.get("dodge", false):
				hero.knockback = move.normalized() if move.length() > 0.2 else -hero.facing
				hero.facing = hero.knockback if move.length() > 0.2 else hero.facing
				hero.protected_until = elapsed + DODGE_TIME + 0.05
				_set_state(hero, State.DODGE)
			elif _input.get("ability", false) and ability_remaining() <= 0.0 and hero_ability != &"":
				_start_ability(hero)
			elif _input.get("light", false):
				hero.combo = 0
				_start_attack(hero, Attack.LIGHT)
			elif _input.get("heavy", false):
				_start_attack(hero, Attack.HEAVY)
			elif move.length() > 0.15:
				_set_state(hero, State.RUN if move.length() > 0.55 else State.WALK)
				var speed := hero.speed if hero.state == State.RUN else hero.speed * 0.45
				_place(hero, hero.position + move * speed * delta)
				hero.facing = hero.facing.slerp(move.normalized(), minf(1.0, 14.0 * delta)).normalized()
			else:
				_set_state(hero, State.IDLE)
		State.GUARD:
			if not guard:
				_set_state(hero, State.LOWER)
			elif move.length() > 0.15:
				_place(hero, hero.position + move * 1.3 * delta)
		State.ATTACK:
			if _input.get("light", false) and hero.time > hero.action_duration * 0.35 and hero.attack_kind == Attack.LIGHT:
				hero.queued_light = true
	# Consume one-shot buttons once per step.
	for key in ["light", "heavy", "dodge", "ability"]:
		_input[key] = false


func _start_attack(fighter: Fighter, kind: Attack) -> void:
	fighter.attack_kind = kind
	fighter.resolved = false
	var speed := float(fighter.info.get("slash_speed", 1.4))
	if fighter.kind == Kind.HERO:
		speed = float(fighter.info.get("slash_speed", 2.05)) if kind == Attack.LIGHT else 1.25
		if not fighter.controlled:
			speed *= 0.85
	fighter.action_duration = (88.0 / 60.0) / speed
	fighter.contact_time = 0.70 / speed
	fighter.heavy = kind == Attack.HEAVY or (fighter.kind == Kind.SOLDIER and _random.randf() < float(fighter.info.get("heavy_chance", 0.28)))
	if fighter.kind == Kind.HERO:
		var lock := _soft_lock(fighter, 4.0)
		if lock >= 0:
			var offset := fighters[lock].position - fighter.position
			if not offset.is_zero_approx():
				fighter.facing = offset.normalized()
	_set_state(fighter, State.ATTACK)


func _start_ranged(fighter: Fighter) -> void:
	fighter.attack_kind = Attack.RANGED
	fighter.resolved = false
	fighter.action_duration = 1.05
	fighter.contact_time = 0.55
	_set_state(fighter, State.CAST)


func _start_ability(fighter: Fighter) -> void:
	fighter.attack_kind = Attack.ABILITY
	fighter.resolved = false
	fighter.action_duration = 1.0
	fighter.contact_time = 0.45
	ability_ready_at = elapsed + ability_cooldown
	_set_state(fighter, State.CAST)


func _soft_lock(fighter: Fighter, reach: float) -> int:
	var best := -1
	var best_score := INF
	for index in _team_alive[1 - fighter.team]:
		var other := fighters[index]
		var offset := other.position - fighter.position
		var distance := offset.length()
		if distance > reach + other.radius:
			continue
		var alignment := fighter.facing.dot(offset / maxf(distance, 0.001))
		if alignment < -0.2:
			continue
		var score := distance - alignment * 1.5 + (2.0 if other.kind == Kind.STRUCTURE else 0.0)
		if score < best_score:
			best_score = score
			best = index
	return best


# ---------------------------------------------------------------- attacks


func _resolve_action(fighter: Fighter) -> void:
	match fighter.attack_kind:
		Attack.RANGED:
			if fighter.target >= 0 and fighters[fighter.target].is_alive():
				_fire(fighter, fighters[fighter.target])
		Attack.ABILITY:
			_use_ability(fighter)
		_:
			if fighter.kind == Kind.HERO:
				_hero_cleave(fighter)
			else:
				_soldier_strike(fighter)


func _components(fighter: Fighter, key: String = "attack") -> Dictionary:
	if key == "attack" and fighter.role() == Units.Role.RANGED:
		return fighter.info.get("melee", {Unit.Damage.MELEE: 16.0})
	return fighter.info.get(key, {})


func _damage(attacker: Fighter, defender: Fighter, components: Dictionary, multiplier: float = 1.0) -> float:
	var amount := defender.unit.damage_from(attacker.unit, components) * DAMAGE_SCALE * multiplier
	if attacker.platoon >= 0:
		var cohesion := squads[attacker.platoon].combat.cohesion
		amount *= 0.7 + 0.3 * cohesion / 100.0
	if attacker.damage_buff_until > elapsed:
		amount *= 1.35
	if defender.guard_buff_until > elapsed:
		amount *= 0.6
	if defender.kind == Kind.STRUCTURE:
		amount *= 0.55
	return amount


func _apply_damage(attacker: Fighter, defender: Fighter, amount: float) -> void:
	if not defender.is_alive() or amount <= 0.0:
		return
	if defender.platoon >= 0:
		var squad := squads[defender.platoon]
		squad.combat.apply_damage(squad.members.find(defender.index), amount)
		squad.last_engaged = elapsed
	else:
		defender.unit.receive_damage(amount)
	defender.last_hurt = elapsed
	if attacker.platoon >= 0:
		squads[attacker.platoon].last_engaged = elapsed
	if not defender.unit.is_alive():
		_set_state(defender, State.DEAD)
		defender.target = -1
		attacker.kills += 1
		if attacker.platoon >= 0:
			squads[attacker.platoon].kills += 1
		if defender.kind != Kind.STRUCTURE:
			if defender.team == PLAYER_TEAM:
				player_losses += 1
			else:
				enemy_losses += 1


func _react(defender: Fighter, attacker: Fighter, reaction: State) -> void:
	if not defender.is_alive() or defender.kind == Kind.STRUCTURE:
		return
	if defender.is_recovering() or defender.state == State.DODGE:
		return
	if defender.kind == Kind.HERO:
		# Officers keep their footing against all but the heaviest blows.
		if reaction == State.KNOCKDOWN:
			reaction = State.STAGGER
		if defender.controlled and (defender.state == State.ATTACK or defender.state == State.CAST):
			return
	var direction := (defender.position - attacker.position).normalized()
	if direction.is_zero_approx():
		direction = -defender.facing
	defender.knockback = direction
	defender.queued_light = false
	_set_state(defender, reaction)


func _can_hit(defender: Fighter) -> bool:
	return defender.is_alive() and not (defender.is_recovering() or elapsed < defender.protected_until)


func _blocks(defender: Fighter, attacker: Fighter) -> bool:
	if defender.kind == Kind.STRUCTURE:
		return false
	var guarding := defender.state == State.GUARD or (defender.state == State.BLOCKED and defender.time < 0.3) or defender.state == State.RAISE
	if not guarding:
		return false
	var toward := (attacker.position - defender.position).normalized()
	return defender.facing.dot(toward) >= 0.45


func _soldier_strike(fighter: Fighter) -> void:
	if fighter.target < 0:
		return
	var defender := fighters[fighter.target]
	if not _can_hit(defender):
		return
	var offset := defender.position - fighter.position
	if offset.length() > MELEE_REACH + defender.radius - BODY_RADIUS + 0.3:
		return
	if fighter.facing.dot(offset.normalized()) < 0.5:
		return
	if _blocks(defender, fighter):
		_set_state(fighter, State.RECOIL)
		if defender.controlled:
			defender.time = minf(defender.time, 0.1)
		else:
			_set_state(defender, State.BLOCKED)
		return
	var multiplier := 1.0
	if fighter.kind == Kind.HERO:
		multiplier = 1.8 if fighter.heavy else 1.0
	_apply_damage(fighter, defender, _damage(fighter, defender, _components(fighter), multiplier))
	if fighter.heavy and defender.is_alive():
		_react(defender, fighter, State.KNOCKDOWN if _random.randf() < 0.22 else State.STAGGER)


func _hero_cleave(fighter: Fighter) -> void:
	var heavy := fighter.attack_kind == Attack.HEAVY
	var reach := 2.5 if heavy else 2.15
	var arc := -0.2 if heavy else 0.25
	var multiplier := 2.1 if heavy else (1.4 if fighter.combo == 2 else 1.0)
	if not fighter.controlled:
		multiplier *= 0.85
	var limit := 6 if heavy else 4
	var struck: Array[Fighter] = []
	for index in _team_alive[1 - fighter.team]:
		var defender := fighters[index]
		if not _can_hit(defender):
			continue
		var offset := defender.position - fighter.position
		var distance := offset.length()
		if distance > reach + defender.radius:
			continue
		if distance > 0.3 and fighter.facing.dot(offset / distance) < arc:
			continue
		struck.append(defender)
	struck.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.position.distance_squared_to(fighter.position) < b.position.distance_squared_to(fighter.position)
	)
	for i in range(mini(limit, struck.size())):
		var defender := struck[i]
		if _blocks(defender, fighter) and not heavy:
			if not defender.controlled:
				_set_state(defender, State.BLOCKED)
			continue
		_apply_damage(fighter, defender, _damage(fighter, defender, _components(fighter), multiplier))
		if not defender.is_alive():
			continue
		if heavy:
			_react(defender, fighter, State.KNOCKDOWN if _random.randf() < 0.55 else State.STAGGER)
		elif _random.randf() < (0.4 if fighter.combo == 2 else 0.18):
			_react(defender, fighter, State.STAGGER)


func _fire(fighter: Fighter, target: Fighter) -> void:
	var start := Vector3(fighter.position.x, 1.55, fighter.position.y)
	projectiles.append({
		"pos": start,
		"start": start,
		"from": fighter.index,
		"target": target.index,
		"team": fighter.team,
		"color": fighter.info.get("projectile", Color.WHITE),
		"age": 0.0,
		"speed": 17.0,
		"aim": Vector2(_random.randf_range(-0.25, 0.25), _random.randf_range(-0.25, 0.25)),
	})


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot := projectiles[i]
		shot.age += delta
		var target := fighters[shot.target]
		var attacker := fighters[shot.from]
		var goal := Vector3(target.position.x + shot.aim.x, 1.1, target.position.y + shot.aim.y)
		var pos: Vector3 = shot.pos
		var offset := goal - pos
		var travel: float = shot.speed * delta
		if offset.length() <= maxf(travel, 0.45) or shot.age > 3.0:
			projectiles.remove_at(i)
			if not target.is_alive() or not attacker.unit.is_alive() or shot.age > 3.0:
				continue
			if not _can_hit(target):
				continue
			if _blocks(target, attacker):
				if not target.controlled:
					_set_state(target, State.BLOCKED)
				continue
			_apply_damage(attacker, target, _damage(attacker, target, attacker.info.get("attack", {})))
			continue
		# A shallow arc reads clearly from the command view.
		var flat := Vector2(goal.x - shot.start.x, goal.z - shot.start.z).length()
		var progress := clampf(Vector2(pos.x - shot.start.x, pos.z - shot.start.z).length() / maxf(flat, 0.01), 0.0, 1.0)
		pos += offset.normalized() * travel
		pos.y = lerpf(shot.start.y, goal.y, progress) + sin(progress * PI) * minf(flat * 0.12, 3.0)
		shot.pos = pos


func _effect(kind: String, position: Vector2, radius: float, color: Color, facing: Vector2 = Vector2.ZERO) -> void:
	effects.append({"kind": kind, "pos": position, "radius": radius, "color": color, "age": 0.0, "life": 0.9, "facing": facing})


func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].age += delta
		if effects[i].age >= effects[i].life:
			effects.remove_at(i)


func _use_ability(fighter: Fighter) -> void:
	var attack := _components(fighter)
	match hero_ability:
		&"royal_rally":
			_effect("ring", fighter.position, 14.0, Color("#f2c46d"))
			fighter.damage_buff_until = elapsed + 10.0
			for index in _team_alive[fighter.team]:
				var ally := fighters[index]
				if ally.kind == Kind.STRUCTURE or ally.position.distance_to(fighter.position) > 14.0:
					continue
				_heal(ally, ally.unit.max_hp * 0.2)
				if ally.platoon >= 0:
					squads[ally.platoon].combat.reform(20.0)
		&"well_keepers_roar":
			_effect("ring", fighter.position, 6.5, Color("#e2683c"))
			for defender in _enemies_near(fighter, 6.5):
				_apply_damage(fighter, defender, _damage(fighter, defender, attack, 1.3))
				_react(defender, fighter, State.KNOCKDOWN)
		&"stone_ward":
			_effect("ring", fighter.position, 8.0, Color("#a9c9a0"))
			for defender in _enemies_near(fighter, 8.0):
				_apply_damage(fighter, defender, _damage(fighter, defender, {Unit.Damage.NATURE: 40.0, Unit.Damage.LIGHTNING: 30.0}, 1.0))
				_react(defender, fighter, State.STAGGER)
			for index in _team_alive[fighter.team]:
				var ally := fighters[index]
				if ally.kind != Kind.STRUCTURE and ally.position.distance_to(fighter.position) <= 10.0:
					ally.guard_buff_until = elapsed + 10.0
		&"tidal_surge":
			_effect("cone", fighter.position, 11.0, Color("#8fe3ff"), fighter.facing)
			for defender in _enemies_near(fighter, 11.0):
				var offset := (defender.position - fighter.position).normalized()
				if fighter.facing.dot(offset) < 0.55:
					continue
				_apply_damage(fighter, defender, _damage(fighter, defender, {Unit.Damage.ICE: 70.0, Unit.Damage.MELEE: 30.0}, 1.0))
				_react(defender, fighter, State.KNOCKDOWN)
		&"rootbind":
			_effect("ring", fighter.position, 9.0, Color("#93d36a"))
			for defender in _enemies_near(fighter, 9.0):
				_apply_damage(fighter, defender, _damage(fighter, defender, {Unit.Damage.NATURE: 50.0}, 1.0))
				defender.rooted_until = elapsed + 5.0
				defender.ready_in = maxf(defender.ready_in, 5.0)
				_set_state(defender, State.IDLE)
		&"grave_toll":
			_effect("ring", fighter.position, 8.0, Color("#b98cff"))
			var drained := 0.0
			for defender in _enemies_near(fighter, 8.0):
				var amount := _damage(fighter, defender, {Unit.Damage.CURSE: 70.0}, 1.0)
				drained += minf(amount, defender.unit.hp)
				_apply_damage(fighter, defender, amount)
			_heal(fighter, drained * 0.4)


func _heal(fighter: Fighter, amount: float) -> void:
	fighter.unit.heal(amount)


func _enemies_near(fighter: Fighter, radius: float) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for index in _team_alive[1 - fighter.team]:
		var other := fighters[index]
		if other.kind != Kind.STRUCTURE and _can_hit(other) and other.position.distance_to(fighter.position) <= radius + other.radius:
			result.append(other)
	return result


# ---------------------------------------------------------------- squads


func _apply_order(squad: Squad, order: Dictionary) -> void:
	squad.order = order.duplicate()
	squad.path = PackedVector2Array()
	squad.path_index = 0
	squad.goal = Vector2.INF
	squad.think_in = 0.0
	if order.kind == "move" or order.kind == "assault":
		squad.goal = _point(order.get("to", squad.anchor))
		squad.path = find_path(squad.anchor, squad.goal)
	elif order.kind == "path":
		for point in order.get("points", []):
			squad.path.append(_point(point))
	elif order.kind == "hold" and order.has("at"):
		squad.goal = _point(order.at)
		squad.path = find_path(squad.anchor, squad.goal)
	for member in squad.members:
		var fighter := fighters[member]
		if order.kind in ["move", "path", "follow"] and fighter.is_alive():
			fighter.target = -1


func order_label(squad: Squad) -> String:
	match squad.order.get("kind", "hold"):
		"follow":
			return "Following"
		"move":
			return "Moving"
		"attack":
			var target: String = squad.order.get("target", "")
			if target == "hero":
				return "Attacking"
			var other := self.squad(target)
			return "Attacking %s" % other.name if other else "Attacking"
		"hunt":
			return "Engaging"
		"assault":
			return "Assaulting"
		"path":
			return "Travelling"
		"guard":
			return "Guarding"
	return "Holding"


func _update_squads(delta: float) -> void:
	for squad in squads:
		if not squad.spawned or squad.alive_count(self) == 0:
			continue
		squad.think_in -= delta
		if squad.think_in <= 0.0:
			squad.think_in = 0.5
			_plan_squad(squad)
		_move_anchor(squad, delta)
		if elapsed - squad.last_engaged > REFORM_DELAY:
			squad.combat.reform(delta)


func _plan_squad(squad: Squad) -> void:
	var kind: String = squad.order.get("kind", "hold")
	if squad.aggro > 0.0 and kind in ["hold", "path", "move"] and squad.team == ENEMY_TEAM:
		var near := _nearest_enemy(squad.team, squad.anchor, false)
		if near >= 0 and fighters[near].position.distance_to(squad.anchor) <= squad.aggro:
			_apply_order(squad, {"kind": "hunt"})
			kind = "hunt"
	match kind:
		"follow":
			if hero.is_alive():
				var behind := -hero.facing
				var right := Vector2(-behind.y, behind.x)
				var lane: Vector2 = [Vector2(-4.5, 6.0), Vector2(4.5, 6.0), Vector2(0.0, 10.0), Vector2(-8.0, 9.0), Vector2(8.0, 9.0)][squad.follow_slot % 5]
				if squad.members.size() == 1:
					lane = Vector2(2.2, 2.8)
				_route_to(squad, _free_point(hero.position + right * lane.x + behind * lane.y), 3.5)
		"attack":
			var target_id: String = squad.order.get("target", "")
			var goal := Vector2.INF
			if target_id == "hero":
				goal = hero.position if hero.is_alive() else Vector2.INF
			else:
				var other := self.squad(target_id)
				if other and other.spawned and other.alive_count(self) > 0:
					goal = other.centroid(self)
			if goal == Vector2.INF:
				_apply_order(squad, {"kind": "hold"} if squad.team == PLAYER_TEAM else {"kind": "hunt"})
			else:
				_route_to(squad, goal, 4.0)
		"hunt":
			var near := _nearest_enemy(squad.team, squad.centroid(self), true)
			if near >= 0:
				_route_to(squad, fighters[near].position, 4.0)
		"assault":
			var at: Vector2 = squad.goal
			if squad.anchor.distance_to(at) < 6.0:
				var near := _nearest_enemy(squad.team, at, true, 26.0)
				if near >= 0:
					_route_to(squad, fighters[near].position, 4.0)
			elif squad.path.is_empty() or squad.path_index >= squad.path.size():
				squad.path = find_path(squad.anchor, at)
				squad.path_index = 0
		"guard":
			var who := _entity_position(squad.order.get("who", ""))
			if who != Vector2.INF:
				_route_to(squad, who, 5.0)


func _route_to(squad: Squad, goal: Vector2, tolerance: float) -> void:
	if squad.goal != Vector2.INF and squad.goal.distance_to(goal) < tolerance and squad.path_index < squad.path.size():
		return
	squad.goal = goal
	squad.path = find_path(squad.anchor, goal)
	squad.path_index = 0


func _move_anchor(squad: Squad, delta: float) -> void:
	if squad.path_index >= squad.path.size():
		return
	if squad.order.kind == "path":
		var wait: float = squad.order.get("wait_for_hero", 0.0)
		if wait > 0.0 and hero.is_alive() and hero.position.distance_to(squad.anchor) > wait:
			return
	# Wait for stragglers so the formation arrives together.
	var lag := 0.0
	var counted := 0
	var right := Vector2(-squad.facing.y, squad.facing.x)
	for member in squad.members:
		var fighter := fighters[member]
		if not fighter.is_alive() or fighter.target >= 0:
			continue
		lag += fighter.position.distance_to(squad.anchor + right * fighter.slot.x + squad.facing * fighter.slot.y)
		counted += 1
	if counted > 0 and lag / counted > 5.0:
		return
	var waypoint := squad.path[squad.path_index]
	var offset := waypoint - squad.anchor
	var speed := float(squad.info.get("speed", 2.7)) * ANCHOR_SPEED_FACTOR
	if squad.info.get("role") == Units.Role.HERO:
		speed = 2.6
	var travel := speed * delta
	if offset.length() <= travel:
		squad.anchor = waypoint
		squad.path_index += 1
		if squad.path_index >= squad.path.size() and squad.order.kind == "move":
			squad.order = {"kind": "hold"}
		elif squad.path_index >= squad.path.size() and squad.order.kind == "path":
			squad.order = {"kind": "hold", "arrived": true}
	else:
		squad.anchor += offset / offset.length() * travel
	if offset.length() > 0.2:
		squad.facing = squad.facing.slerp(offset.normalized(), minf(1.0, 4.0 * delta)).normalized()


func _entity_position(who: String) -> Vector2:
	if who == "hero":
		return hero.position if hero.is_alive() else Vector2.INF
	if structures.has(who):
		return fighters[structures[who]].position
	var other := squad(who)
	if other and other.spawned and other.alive_count(self) > 0:
		return other.centroid(self)
	return Vector2.INF


func _nearest_enemy(team: int, from: Vector2, include_structures: bool, limit: float = INF) -> int:
	var best := -1
	var best_distance := limit
	for index in _team_alive[1 - team]:
		var other := fighters[index]
		var distance := other.position.distance_to(from)
		if other.kind == Kind.STRUCTURE:
			if not include_structures:
				continue
			distance += 8.0
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


# ---------------------------------------------------------------- soldier AI


func _think(fighter: Fighter, delta: float) -> void:
	if fighter.rooted_until > elapsed:
		_set_state(fighter, State.IDLE)
		return
	var squad: Squad = squads[fighter.platoon] if fighter.platoon >= 0 else null
	if squad == null:
		return
	var role := fighter.role()
	if role == Units.Role.CIVILIAN:
		_follow_slot(fighter, squad, delta)
		return
	if fighter.target >= 0:
		var current := fighters[fighter.target]
		var leash := _leash(squad)
		if not current.is_alive() or fighter.position.distance_to(squad.anchor) > leash:
			fighter.target = -1
	if fighter.scan_in <= 0.0:
		fighter.scan_in = _random.randf_range(0.4, 0.7)
		_scan(fighter, squad)
	if fighter.target < 0:
		_follow_slot(fighter, squad, delta)
		return
	var enemy := fighters[fighter.target]
	var offset := enemy.position - fighter.position
	var distance := offset.length()
	if role == Units.Role.RANGED and distance > 3.0:
		var range_limit: float = fighter.info.get("range", 15.0)
		if distance > range_limit:
			_run(fighter, offset * (1.0 - (range_limit - 1.0) / distance), delta)
			return
		_set_state(fighter, State.IDLE)
		fighter.facing = offset / distance
		if fighter.ready_in <= 0.0:
			fighter.ready_in = float(fighter.info.get("reload", 2.6)) * _random.randf_range(0.85, 1.2)
			_start_ranged(fighter)
		return
	var reach := MELEE_REACH + enemy.radius - BODY_RADIUS
	if distance > reach:
		# Spread attackers around the target instead of queuing behind each other.
		var around := (fighter.position - enemy.position).normalized().rotated(fighter.spread * 0.6)
		var stand := enemy.position + around * (reach - 0.12)
		if distance > reach + 2.5:
			stand = enemy.position
		_run(fighter, stand - fighter.position, delta)
		return
	_set_state(fighter, State.IDLE)
	if distance > 0.01:
		fighter.facing = fighter.facing.slerp(offset / distance, minf(1.0, 16.0 * delta)).normalized()
	if fighter.ready_in > 0.0:
		return
	if _incoming(fighter, enemy) and fighter.think_in <= 0.0:
		fighter.think_in = _random.randf_range(0.3, 0.5)
		if _random.randf() < 0.45:
			_set_state(fighter, State.RAISE)
			return
	if fighter.kind == Kind.HERO:
		_start_attack(fighter, Attack.HEAVY if _random.randf() < 0.3 else Attack.LIGHT)
		fighter.ready_in = _random.randf_range(0.4, 1.0)
	else:
		_start_attack(fighter, Attack.LIGHT)


func _incoming(fighter: Fighter, enemy: Fighter) -> bool:
	return enemy.target == fighter.index and enemy.state == State.ATTACK and enemy.time < enemy.contact_time - DURATIONS[State.RAISE]


func _leash(squad: Squad) -> float:
	match squad.order.get("kind", "hold"):
		"attack", "hunt", "assault":
			return 60.0
		"follow":
			return 18.0
		"move", "path":
			return 8.0
	return maxf(16.0, squad.aggro)


func _scan(fighter: Fighter, squad: Squad) -> void:
	var kind: String = squad.order.get("kind", "hold")
	var radius := 9.0
	var ranged := fighter.role() == Units.Role.RANGED
	if kind == "move" or kind == "path":
		radius = 3.5
	elif kind == "hunt" or kind == "assault" or kind == "attack":
		radius = 11.0
	if ranged and kind != "move":
		radius = maxf(radius, float(fighter.info.get("range", 15.0)))
	var preferred := -1
	if kind == "attack":
		var other := self.squad(squad.order.get("target", ""))
		if other:
			preferred = other.index
	var structures_allowed := kind in ["hunt", "assault", "attack"] or squad.team == ENEMY_TEAM
	var best := -1
	var best_score := INF
	var leash := _leash(squad)
	for index in _team_alive[1 - fighter.team]:
		var other := fighters[index]
		var distance := other.position.distance_to(fighter.position) - other.radius
		var preferred_target := preferred >= 0 and other.platoon == preferred
		if distance > radius and not (preferred_target and distance < 60.0):
			continue
		if other.position.distance_to(squad.anchor) > leash + 4.0 and not preferred_target:
			continue
		var score := distance
		if other.kind == Kind.STRUCTURE:
			if not structures_allowed:
				continue
			score += 7.0
		if not ranged:
			var load := _attackers[index] - (1 if fighter.target == index else 0)
			if load >= _cap(other):
				continue
			score += load * 1.4
		if preferred_target:
			score -= 6.0
		if other.controlled:
			score -= 1.0
		score += _random.randf_range(0.0, 1.2)
		if score < best_score:
			best_score = score
			best = index
	if best != fighter.target:
		if fighter.target >= 0:
			_attackers[fighter.target] -= 1
		fighter.target = best
		if best >= 0 and not ranged:
			_attackers[best] += 1


func _follow_slot(fighter: Fighter, squad: Squad, delta: float) -> void:
	var right := Vector2(-squad.facing.y, squad.facing.x)
	var goal := squad.anchor + right * fighter.slot.x + squad.facing * fighter.slot.y
	if _blocked(goal, BODY_RADIUS):
		goal = squad.anchor
	var offset := goal - fighter.position
	var distance := offset.length()
	if distance > 1.6:
		_run(fighter, offset, delta)
	elif distance > 0.3:
		_set_state(fighter, State.WALK)
		_place(fighter, fighter.position + offset.normalized() * minf(WALK_SPEED * delta, distance))
		fighter.facing = fighter.facing.slerp(offset.normalized(), minf(1.0, 6.0 * delta)).normalized()
	else:
		_set_state(fighter, State.IDLE)
		fighter.facing = fighter.facing.slerp(squad.facing, minf(1.0, 3.0 * delta)).normalized()


func _run(fighter: Fighter, offset: Vector2, delta: float) -> void:
	_set_state(fighter, State.RUN)
	var distance := offset.length()
	if distance < 0.001:
		return
	var direction := offset / distance
	# Slide around obstacles in the way.
	var probe := fighter.position + direction * 1.2
	if _blocked(probe, fighter.radius):
		var left := direction.rotated(0.9)
		var right := direction.rotated(-0.9)
		var turn := left if not _blocked(fighter.position + left * 1.2, fighter.radius) else right
		if fighter.spread < 0.0 and not _blocked(fighter.position + right * 1.2, fighter.radius):
			turn = right
		direction = turn
	_place(fighter, fighter.position + direction * minf(fighter.speed * delta, distance))
	fighter.facing = fighter.facing.slerp(direction, minf(1.0, 12.0 * delta)).normalized()


func _place(fighter: Fighter, position: Vector2) -> void:
	fighter.position = _push_out(position, fighter.radius)


func _push_out(position: Vector2, radius: float) -> Vector2:
	for obstacle in obstacles:
		if obstacle.has("rect"):
			var rect: Rect2 = (obstacle.rect as Rect2).grow(radius)
			if rect.has_point(position):
				var left := position.x - rect.position.x
				var right := rect.end.x - position.x
				var top := position.y - rect.position.y
				var bottom := rect.end.y - position.y
				var least := minf(minf(left, right), minf(top, bottom))
				if least == left:
					position.x = rect.position.x
				elif least == right:
					position.x = rect.end.x
				elif least == top:
					position.y = rect.position.y
				else:
					position.y = rect.end.y
		elif obstacle.has("circle"):
			var circle: Vector3 = obstacle.circle
			var center := Vector2(circle.x, circle.y)
			var offset := position - center
			var limit := circle.z + radius
			if offset.length() < limit:
				position = center + (offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT) * limit
	return position.clamp(bounds.position + Vector2.ONE, bounds.end - Vector2.ONE)


# ---------------------------------------------------------------- bodies


func _index_bodies() -> void:
	_cells.clear()
	for fighter in fighters:
		if fighter.is_alive():
			var cell := Vector2i((fighter.position / CELL_SIZE).floor())
			if not _cells.has(cell):
				_cells[cell] = []
			_cells[cell].append(fighter.index)


func _weight(fighter: Fighter) -> float:
	if fighter.kind == Kind.STRUCTURE:
		return 0.0
	if fighter.kind == Kind.HERO:
		return 0.15
	match fighter.state:
		State.IDLE, State.WALK:
			return 1.0
		State.RUN:
			return 0.7
	return 0.25


func _separate(_delta: float) -> void:
	for a in fighters:
		if not a.is_alive():
			continue
		var cell := Vector2i((a.position / CELL_SIZE).floor())
		var reach := 1 if a.radius < 1.0 else ceili(a.radius / CELL_SIZE) + 1
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var bucket: Array = _cells.get(cell + Vector2i(dx, dy), [])
				for index in bucket:
					if index <= a.index:
						continue
					var b := fighters[index]
					var offset := b.position - a.position
					var spacing := a.radius + b.radius + 0.02
					var distance := offset.length()
					if distance >= spacing:
						continue
					var wa := _weight(a)
					var wb := _weight(b)
					if wa + wb <= 0.0:
						continue
					var direction := offset / distance if distance > 0.0001 else Vector2.RIGHT.rotated(index)
					var overlap := (spacing - distance) * 0.6
					a.position = _push_out(a.position - direction * overlap * wa / (wa + wb), a.radius)
					b.position = _push_out(b.position + direction * overlap * wb / (wa + wb), b.radius)


func _regenerate(delta: float) -> void:
	if hero.is_alive() and elapsed - hero.last_hurt > HERO_REGEN_DELAY:
		_heal(hero, hero.unit.max_hp * HERO_REGEN_RATE * delta)


# ---------------------------------------------------------------- structures


func _update_structures(delta: float) -> void:
	for id in structures:
		var fighter := fighters[structures[id]]
		if not fighter.is_alive() or not fighter.moving or fighter.route_index >= fighter.route.size():
			continue
		if not hero.is_alive() or hero.position.distance_to(fighter.position) > fighter.escort_radius:
			continue
		var threatened := false
		for index in _team_alive[ENEMY_TEAM]:
			var enemy := fighters[index]
			if enemy.kind != Kind.STRUCTURE and enemy.position.distance_to(fighter.position) < 5.5:
				threatened = true
				break
		if threatened:
			continue
		var waypoint := fighter.route[fighter.route_index]
		var offset := waypoint - fighter.position
		var travel := fighter.speed * delta
		if offset.length() <= travel:
			fighter.position = waypoint
			fighter.route_index += 1
		else:
			fighter.facing = fighter.facing.slerp(offset.normalized(), minf(1.0, 3.0 * delta)).normalized()
			fighter.position += offset.normalized() * travel


func structure_threatened(id: String) -> bool:
	if not structures.has(id):
		return false
	var fighter := fighters[structures[id]]
	for index in _team_alive[ENEMY_TEAM]:
		var enemy := fighters[index]
		if enemy.kind != Kind.STRUCTURE and enemy.position.distance_to(fighter.position) < 5.5:
			return true
	return false


# ---------------------------------------------------------------- objectives and events


func _update_interaction(delta: float) -> void:
	interact_target = active_interactable()
	if interact_target < 0 or not hero.is_alive():
		interact_progress = 0.0
		return
	var item := interactables[interact_target]
	var holding: bool = _input.get("interact", false) and hero.state in [State.IDLE, State.WALK, State.CHEER]
	if holding:
		item.progress += delta
		if item.progress >= item.get("duration", 3.0):
			item.done = true
			item.active = false
			_effect("ring", item.pos, 4.0, Color("#f4e8d5"))
	interact_progress = item.progress / float(item.get("duration", 3.0))


func _in_zone(who: String, zone_id: String) -> bool:
	var zone: Dictionary = zones.get(zone_id, {})
	if zone.is_empty():
		return false
	var at: Vector2 = zone.pos
	var radius: float = zone.get("radius", 8.0)
	if who == "hero":
		return hero.is_alive() and hero.position.distance_to(at) <= radius
	if structures.has(who):
		var fighter := fighters[structures[who]]
		return fighter.is_alive() and fighter.position.distance_to(at) <= radius
	var other := squad(who)
	if other == null or not other.spawned or other.alive_count(self) == 0:
		return false
	return other.centroid(self).distance_to(at) <= radius


func _entity_dead(who: String) -> bool:
	if who == "hero":
		return not hero.is_alive()
	if structures.has(who):
		return not fighters[structures[who]].is_alive()
	var other := squad(who)
	return other != null and other.spawned and other.alive_count(self) == 0


func _team_in_zone(team: int, zone_id: String) -> int:
	var zone: Dictionary = zones.get(zone_id, {})
	var count := 0
	for index in _team_alive[team]:
		var fighter := fighters[index]
		if fighter.kind != Kind.STRUCTURE and fighter.role() != Units.Role.CIVILIAN and fighter.position.distance_to(zone.pos) <= zone.get("radius", 8.0):
			count += 1
	return count


func objective(id: String) -> Dictionary:
	for item in objectives:
		if item.id == id:
			return item
	return {}


func _set_objective(id: String, status: String) -> void:
	var item := objective(id)
	if item.is_empty() or item.status == status:
		return
	if item.status == "done" or item.status == "failed":
		return
	if status == "active":
		item.started = elapsed
	item.status = status
	if status == "done":
		_done_at[id] = elapsed
	elif status == "failed" and not item.get("optional", false):
		_finish(Outcome.DEFEAT, item.get("fail_text", "Objective failed: %s." % item.text))


func _update_objectives(delta: float) -> void:
	if not hero.is_alive():
		_finish(Outcome.DEFEAT, "%s has fallen." % hero.name)
		return
	for item in objectives:
		if item.status != "active":
			continue
		match item.type:
			"reach":
				if _in_zone(item.who, item.zone):
					_set_objective(item.id, "done")
			"defeat":
				var all_dead := true
				for who: String in item.who:
					var other := squad(who)
					if other == null or not other.spawned or other.alive_count(self) > 0:
						all_dead = false
						break
				if all_dead:
					_set_objective(item.id, "done")
			"protect":
				for who: String in item.who:
					if _entity_dead(who):
						_set_objective(item.id, "failed")
						break
			"interact":
				var all_done := true
				for id: String in (item.who if item.who is Array else [item.who]):
					for entry in interactables:
						if entry.id == id and not entry.done:
							all_done = false
				if all_done:
					_set_objective(item.id, "done")
			"hold":
				if elapsed - item.started >= item.seconds:
					_set_objective(item.id, "done")
				elif item.has("zone"):
					var enemies := _team_in_zone(ENEMY_TEAM, item.zone)
					var allies := _team_in_zone(PLAYER_TEAM, item.zone)
					if enemies >= int(item.get("overrun", 10)) and allies == 0:
						_overrun[item.id] = _overrun.get(item.id, 0.0) + delta
						if _overrun[item.id] >= OVERRUN_TIME:
							_set_objective(item.id, "failed")
					else:
						_overrun[item.id] = 0.0


func objective_progress(item: Dictionary) -> String:
	match item.type:
		"hold":
			var remaining := maxf(0.0, item.seconds - (elapsed - item.started))
			if item.status != "active":
				return ""
			return "%d:%02d" % [floori(remaining / 60.0), int(remaining) % 60]
		"interact":
			var total := 0
			var done := 0
			for id: String in (item.who if item.who is Array else [item.who]):
				for entry in interactables:
					if entry.id == id:
						total += 1
						done += 1 if entry.done else 0
			return "%d/%d" % [done, total] if total > 1 else ""
		"defeat":
			var alive := 0
			for who: String in item.who:
				var other := squad(who)
				if other and other.spawned:
					alive += other.alive_count(self)
			return "%d left" % alive if item.who.size() > 1 or alive > 1 else ""
	return ""


func overrun_seconds(id: String) -> float:
	return _overrun.get(id, 0.0)


func _check(condition: Dictionary) -> bool:
	for key in condition:
		var value = condition[key]
		match key:
			"time":
				if elapsed < float(value):
					return false
			"done":
				for id: String in (value if value is Array else [value]):
					if objective(id).get("status", "") != "done":
						return false
			"after":
				if not _done_at.has(value[0]) or elapsed - _done_at[value[0]] < float(value[1]):
					return false
			"zone":
				if not _in_zone(value[0], value[1]):
					return false
			"dead":
				for id: String in (value if value is Array else [value]):
					if not _entity_dead(id):
						return false
			"hp_below":
				var who: String = value[0]
				var fraction: float = value[1]
				if who == "hero":
					if hero.unit.hp / hero.unit.max_hp >= fraction:
						return false
				elif structures.has(who):
					var fighter := fighters[structures[who]]
					if fighter.unit.hp / fighter.unit.max_hp >= fraction:
						return false
				else:
					var other := squad(who)
					if other == null or not other.spawned or other.combat.health_fractions().x >= fraction:
						return false
			"interact":
				for id: String in (value if value is Array else [value]):
					var finished := false
					for entry in interactables:
						if entry.id == id and entry.done:
							finished = true
					if not finished:
						return false
			"event":
				if not _fired.has(value):
					return false
			"near":
				# Any enemy of the player within a radius of a point or entity.
				var at := _entity_position(value[0]) if not zones.has(value[0]) else _point(value[0])
				if at == Vector2.INF:
					return false
				var radius: float = value[1]
				var found := false
				for index in _team_alive[ENEMY_TEAM]:
					var enemy := fighters[index]
					if enemy.kind != Kind.STRUCTURE and enemy.position.distance_to(at) <= radius:
						found = true
						break
				if not found:
					return false
			"alive_below":
				var total := 0
				for id: String in value[0]:
					var other := squad(id)
					if other and other.spawned:
						total += other.alive_count(self)
					elif other:
						total += 999
				if total > int(value[1]):
					return false
			"all":
				for sub: Dictionary in value:
					if not _check(sub):
						return false
			"any":
				var any := false
				for sub: Dictionary in value:
					if _check(sub):
						any = true
						break
				if not any:
					return false
	return true


func _run_events() -> void:
	for i in range(_events.size()):
		if _fired.has(i):
			continue
		var event := _events[i]
		if not _check(event.get("if", {})):
			continue
		_fired[i] = true
		if event.has("id"):
			_fired[event.id] = true
		if event.has("delay"):
			_pending.append({"at": elapsed + float(event.delay), "do": event.do})
		else:
			_perform(event.get("do", []))
	for i in range(_pending.size() - 1, -1, -1):
		if elapsed >= _pending[i].at:
			var actions: Array = _pending[i].do
			_pending.remove_at(i)
			_perform(actions)


func _perform(actions: Array) -> void:
	for action: Array in actions:
		if outcome != Outcome.LIVE and action[0] != "say":
			continue
		match action[0]:
			"say":
				messages.append({"speaker": action[1], "text": action[2], "time": elapsed})
			"spawn":
				var target := squad(action[1])
				if target:
					_spawn_squad(target)
			"order":
				var target := squad(action[1])
				if target and target.spawned:
					_apply_order(target, action[2])
			"objective":
				_set_objective(action[1], "active")
			"complete":
				_set_objective(action[1], "done")
			"fail":
				_set_objective(action[1], "failed")
			"victory":
				_finish(Outcome.VICTORY, action[1] if action.size() > 1 else "")
			"defeat":
				_finish(Outcome.DEFEAT, action[1])
			"reveal":
				for entry in interactables:
					if entry.id == action[1] and not entry.done:
						entry.active = true
			"defect":
				var target := squad(action[1])
				if target:
					_defect(target, action.size() > 2 and action[2])
			"kill":
				var target := squad(action[1])
				if target and target.spawned:
					for member in target.members:
						var fighter := fighters[member]
						if fighter.is_alive():
							fighter.unit.receive_damage(fighter.unit.hp)
							_set_state(fighter, State.DEAD)
					_effect("ring", target.centroid(self), 6.0, Color("#e9e2ff"))
			"despawn":
				var target := squad(action[1])
				if target and target.spawned:
					for member in target.members:
						fighters[member].removed = true
						fighters[member].target = -1
			"raise":
				var dynamic: Dictionary = mission.get("map", {}).get("dynamic_obstacles", {})
				if dynamic.has(action[1]) and not raised.has(action[1]):
					raised.append(action[1])
					obstacles.append(dynamic[action[1]])
					_build_navigation()
					for fighter in fighters:
						if fighter.is_alive() and fighter.kind != Kind.STRUCTURE:
							fighter.position = _push_out(fighter.position, fighter.radius)
			"move_structure":
				if structures.has(action[1]):
					fighters[structures[action[1]]].moving = action[2]
			"heal_hero":
				_heal(hero, hero.unit.max_hp * float(action[1]))


func _defect(target: Squad, commandable: bool) -> void:
	target.team = PLAYER_TEAM
	target.commandable = commandable
	target.aggro = 0.0
	for member in target.members:
		var fighter := fighters[member]
		fighter.team = PLAYER_TEAM
		fighter.target = -1
	_apply_order(target, {"kind": "follow"} if commandable else {"kind": "hunt"})
	for other in fighters:
		if other.target >= 0 and fighters[other.target].team == other.team:
			other.target = -1
	_effect("ring", target.centroid(self), 7.0, Color("#f4e8d5"))


func _finish(result: Outcome, reason: String) -> void:
	if outcome != Outcome.LIVE:
		return
	outcome = result
	outcome_reason = reason
	projectiles.clear()
	for fighter in fighters:
		fighter.target = -1
