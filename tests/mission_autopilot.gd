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
	_command()
	var goal := _goal()
	var interact_here := battle.active_interactable()
	var nearest := _nearest_enemy(hero.position, 30.0)
	var close := 0
	for index in battle._team_alive[1]:
		var other: Battle.Fighter = battle.fighters[index]
		if other.kind != Battle.Kind.STRUCTURE and other.position.distance_to(hero.position) < 6.0:
			close += 1
	var blocked := interact_here >= 0 and not battle.interact_available(battle.interactables[interact_here])
	if blocked and nearest >= 0:
		input.move = (battle.fighters[nearest].position - hero.position).normalized()
		if battle.fighters[nearest].position.distance_to(hero.position) < 2.6:
			input.light = true
	elif interact_here >= 0 and close < 3:
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


## Orders carts forward and squads along, the way a player would from the command view.
func _command() -> void:
	for cart in battle.commandable_structures():
		if not cart.moving or cart.halted:
			battle.command_structure(cart.structure_id, "advance", Vector2.INF)
	for item in battle.objectives:
		if item.status == "active" and item.type == "reach" and item.who != "hero":
			var squad := battle.squad(item.who)
			if squad and squad.commandable and squad.spawned and squad.order.get("kind") == "hold" and not squad.order.get("arrived", false):
				battle.command(squad.index, {"kind": "move", "to": item.zone})
	for item in battle.objectives:
		if item.status == "active" and item.type == "extract":
			for who: String in item.squads:
				var squad := battle.squad(who)
				if squad and squad.order.get("kind") != "move":
					battle.command(squad.index, {"kind": "move", "to": item.zone})


func _steer(from: Vector2, to: Vector2) -> Vector2:
	var path := battle.find_path(from, to)
	if path.is_empty():
		return (to - from).normalized()
	var next := path[0]
	if next.distance_to(from) < 1.0 and path.size() > 1:
		next = path[1]
	return (next - from).normalized()


func _goal() -> Vector2:
	# Defend protected civilians under attack.
	for item in battle.objectives:
		if item.status != "active" or item.type != "protect":
			continue
		for who: String in item.who:
			var squad := battle.squad(who)
			if squad and squad.spawned and not squad.departed and squad.alive_count(battle) > 0:
				var threat := _nearest_enemy(squad.centroid(battle), 10.0)
				if threat >= 0:
					return battle.fighters[threat].position
	# Clear threats that have stopped an escorted group.
	for squad in battle.squads:
		if not squad.spawned or squad.departed or squad.team != Battle.PLAYER_TEAM or squad.order.get("kind") != "path":
			continue
		var guard_radius: float = squad.order.get("pause_if_threatened", 0.0)
		if guard_radius > 0.0 and squad.alive_count(battle) > 0:
			var threat := _nearest_enemy(squad.anchor, guard_radius + 4.0)
			if threat >= 0:
				return battle.fighters[threat].position
	# Escorted civilians only move while the hero is close, so stay with them first.
	for squad in battle.squads:
		if not squad.spawned or squad.departed or squad.team != Battle.PLAYER_TEAM:
			continue
		if squad.order.get("kind") == "path" and squad.order.get("wait_for_hero", 0.0) > 0.0 and squad.alive_count(battle) > 0:
			var at := squad.centroid(battle)
			if squad.path_index < squad.path.size():
				return at + (squad.path[squad.path_index] - at).normalized() * 3.0
	for item in battle.objectives:
		if item.status == "active" and item.type == "interact" and not item.get("optional", false):
			var best := Vector2.INF
			for entry in battle.interactables:
				if entry.active and not entry.done and (item.who is Array and item.who.has(entry.id) or entry.id == item.who):
					if best == Vector2.INF or entry.pos.distance_to(battle.hero.position) < best.distance_to(battle.hero.position):
						best = entry.pos
			if best != Vector2.INF:
				return best
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
			"extract":
				var waiting := false
				for who: String in item.squads:
					var squad := battle.squad(who)
					if squad and squad.alive_count(battle) > 0:
						waiting = true
				if not waiting:
					return battle.zones[item.zone].pos
				return battle.zones[item.zone].pos.lerp(battle.hero.position, 0.0) if battle.hero.position.distance_to(battle.zones[item.zone].pos) > 30.0 else battle.zones[item.zone].pos + Vector2(-12, 0)
			"deliveries":
				for cart_id: String in item.carts:
					var cart: Battle.Fighter = battle.fighters[battle.structures[cart_id]]
					if cart.is_alive() and not cart.delivered and not cart.turned_back:
						return cart.position
			"hold":
				if item.get("seconds", INF) == INF:
					continue
				if item.has("zone"):
					return battle.zones[item.zone].pos
				var guard := _most_threatened()
				if guard != Vector2.INF:
					return guard
	var nearest := Vector2.INF
	for entry in battle.interactables:
		if entry.active and not entry.done:
			if nearest == Vector2.INF or entry.pos.distance_to(battle.hero.position) < nearest.distance_to(battle.hero.position):
				nearest = entry.pos
	if nearest != Vector2.INF:
		return nearest
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
