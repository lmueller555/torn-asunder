extends RefCounted
## A simple player stand-in that pursues the current objective, fights what is near
## and uses the officer ability. Tests use it to confirm that missions can be won.

const Battle := preload("res://game/mission/mission_battle.gd")

var battle: Battle
var _swing := 0
var _goal_index := -1


func _init(target: Battle) -> void:
	battle = target


func drive() -> void:
	var hero := battle.hero
	var input := {"move": Vector2.ZERO}
	if not hero.is_alive():
		battle.set_hero_input(input)
		return
	var goal := _goal()
	var interact_here := battle.active_interactable()
	var nearest := _nearest_enemy(hero.position, 30.0)
	var close := 0
	for index in battle._team_alive[1]:
		var other: Battle.Fighter = battle.fighters[index]
		if other.kind != Battle.Kind.STRUCTURE and other.position.distance_to(hero.position) < 6.0:
			close += 1
	if interact_here >= 0 and close < 3:
		input.interact = true
	elif nearest >= 0 and battle.fighters[nearest].position.distance_to(hero.position) < 2.6:
		var offset: Vector2 = battle.fighters[nearest].position - hero.position
		input.move = offset.normalized() * 0.1
		hero.facing = offset.normalized()
		if close >= 3 and battle.ability_remaining() <= 0.0:
			input.ability = true
		else:
			_swing += 1
			input.heavy = _swing % 4 == 0
			input.light = not input.heavy
	elif nearest >= 0 and (goal == Vector2.INF or battle.fighters[nearest].position.distance_to(hero.position) < 9.0):
		input.move = (battle.fighters[nearest].position - hero.position).normalized()
	elif goal != Vector2.INF and goal.distance_to(hero.position) > 2.0:
		input.move = _steer(hero.position, goal)
	battle.set_hero_input(input)


func _steer(from: Vector2, to: Vector2) -> Vector2:
	var path := battle.find_path(from, to)
	if path.is_empty():
		return (to - from).normalized()
	var next := path[0]
	if next.distance_to(from) < 1.0 and path.size() > 1:
		next = path[1]
	return (next - from).normalized()


func _goal() -> Vector2:
	for item in battle.objectives:
		if item.status != "active":
			continue
		match item.type:
			"reach":
				if item.who == "hero":
					return battle.zones[item.zone].pos
				var at := battle._entity_position(item.who)
				if at == Vector2.INF:
					continue
				var escort := battle.squad(item.who)
				if escort and escort.order.get("kind") == "follow":
					return battle.zones[item.zone].pos
				var toward: Vector2 = battle.zones[item.zone].pos
				return at + (toward - at).normalized() * 4.0
			"interact":
				var best := Vector2.INF
				for entry in battle.interactables:
					if entry.active and not entry.done:
						if best == Vector2.INF or entry.pos.distance_to(battle.hero.position) < best.distance_to(battle.hero.position):
							best = entry.pos
				if best != Vector2.INF:
					return best
			"defeat":
				for who: String in item.who:
					var squad := battle.squad(who)
					if squad and squad.spawned and squad.alive_count(battle) > 0:
						return squad.centroid(battle)
			"hold":
				if item.has("zone"):
					return battle.zones[item.zone].pos
				var guard := _most_threatened()
				if guard != Vector2.INF:
					return guard
	return _most_threatened()


func _most_threatened() -> Vector2:
	var best := Vector2.INF
	var lowest := INF
	for item in battle.objectives:
		if item.status != "active" or item.type != "protect":
			continue
		for who: String in item.who:
			var at := battle._entity_position(who)
			if at == Vector2.INF:
				continue
			var health := 1.0
			if battle.structures.has(who):
				var fighter: Battle.Fighter = battle.fighters[battle.structures[who]]
				health = fighter.unit.hp / fighter.unit.max_hp
			if battle.structure_threatened(who):
				health -= 0.5
			if health < lowest:
				lowest = health
				best = at
	return best


func _nearest_enemy(from: Vector2, limit: float) -> int:
	var best := -1
	var best_distance := limit
	for index in battle._team_alive[1]:
		var other: Battle.Fighter = battle.fighters[index]
		if other.kind == Battle.Kind.STRUCTURE:
			continue
		var distance := other.position.distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best
