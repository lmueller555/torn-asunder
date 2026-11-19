extends SceneTree

const Battle := preload("res://game/combat/infantry_skirmish.gd")
const TICK := 1.0 / 60.0


func _initialize() -> void:
	var passed := _check_waiting()
	passed = _check_trade() and passed
	passed = _check_reactions() and passed
	passed = _check_full_matches() and passed
	quit(0 if passed else 1)


func _check_waiting() -> bool:
	var battle := _fixture([0, 1, 2, 3, 4, 10])
	var enemy := battle.soldiers[10]
	enemy.position = Vector2.ZERO
	battle.soldiers[0].position = Vector2(-1.36, 0)
	battle.soldiers[1].position = Vector2(0, -1.36)
	battle.soldiers[2].position = Vector2(-1, 1)
	var runner := battle.soldiers[3]
	runner.position = Vector2(4, 0)
	var nearby := battle.soldiers[4]
	nearby.position = Vector2(0, 2.1)
	battle.step(TICK)
	if battle.engagements[10].size() != 3 or battle.waiting_count() != 2:
		return _fail("A fifth soldier entered the already full engagement.")
	if runner.target != -1 or runner.pursuit != 10 or runner.state != Battle.State.RUN or runner.position.x >= 4:
		return _fail("A distant reserve failed to run toward its nearest enemy.")
	if nearby.target != -1 or nearby.pursuit != 10 or nearby.state != Battle.State.IDLE:
		return _fail("A nearby reserve failed to idle outside the full fight.")
	for tick in range(90):
		battle.step(TICK)
	if runner.state != Battle.State.IDLE or runner.position.distance_to(enemy.position) > Battle.WAIT_DISTANCE + 0.07:
		return _fail("A reserve did not idle after reaching the edge of the fight.")
	enemy.position.x -= 0.6
	battle.step(TICK)
	if runner.state != Battle.State.RUN or runner.target != -1:
		return _fail("A reserve did not follow the full engagement when it moved away.")
	battle.soldiers[0].unit.receive_damage(battle.soldiers[0].unit.hp)
	battle.step(TICK)
	if runner.target != 10 or not battle.engagements[10].has(3) or battle.engagements[10].size() != 3:
		return _fail("The reserve did not fill the casualty's slot.")
	print("Verified the three-opponent cap and the reserve run, idle, and reassignment.")
	return true


func _check_trade() -> bool:
	var battle := _fixture([0, 10])
	var left := battle.soldiers[0]
	var right := battle.soldiers[10]
	left.position = Vector2(0, -0.55)
	right.position = Vector2(0, 0.55)
	left.target = 10
	right.target = 0
	for soldier in [left, right]:
		soldier.unit.receive_damage(soldier.unit.hp - 1.0)
		soldier.state = Battle.State.ATTACK
		soldier.time = Battle.CONTACT - TICK * 0.5
	battle.step(TICK)
	if battle.winner != Battle.DRAW or left.state != Battle.State.DEAD or right.state != Battle.State.DEAD:
		return _fail("Simultaneous lethal contacts did not trade.")
	for platoon in battle.platoons:
		if not platoon.health_fractions().is_equal_approx(Vector3(0, 0, 1)):
			return _fail("A defeated platoon did not report a full casualty bar.")
	print("Verified same-tick trades and the casualty health channel.")
	return true


func _check_reactions() -> bool:
	var battle := _fixture([0, 10])
	var attacker := battle.soldiers[0]
	var defender := battle.soldiers[10]
	attacker.position = Vector2(0, -0.55)
	defender.position = Vector2(0, 0.55)
	attacker.target = 10
	defender.target = 0
	attacker.state = Battle.State.ATTACK
	attacker.time = Battle.CONTACT - TICK * 0.5
	defender.state = Battle.State.GUARD
	battle.step(TICK)
	if defender.unit.hp != defender.unit.max_hp or attacker.state != Battle.State.RECOIL or defender.state != Battle.State.BLOCKED:
		return _fail("A blocked contact caused HP loss or played the wrong reactions.")

	attacker.state = Battle.State.ATTACK
	attacker.time = Battle.CONTACT - TICK * 0.5
	attacker.heavy = true
	defender.state = Battle.State.ATTACK
	defender.time = 0.3
	battle.step(TICK)
	if defender.state not in [Battle.State.STAGGER, Battle.State.KNOCKDOWN]:
		return _fail("An unblocked heavy hit did not interrupt the wind-up.")
	for tick in range(32):
		battle.step(TICK)
	if attacker.unit.hp != attacker.unit.max_hp:
		return _fail("An interrupted swing still dealt damage.")
	print("Verified block reactions and heavy-hit interruption before contact.")
	return true


func _check_full_matches() -> bool:
	for seed_value in [1, 8, 124]:
		var battle := Battle.new(seed_value)
		if battle.soldiers.size() != 2 * Battle.PLATOON_SIZE:
			return _fail("The skirmish did not spawn ten soldiers per side.")
		for tick in range(60 * 120):
			battle.step(TICK)
			for engagement in battle.engagements:
				if engagement.size() > Battle.MAX_ENGAGEMENTS:
					return _fail("A soldier exceeded the engagement cap in open combat.")
			if battle.winner != Battle.LIVE:
				break
		if battle.winner == Battle.LIVE or battle.hits == 0 or battle.blocks == 0:
			return _fail("An autonomous skirmish failed to resolve with hits and blocks.")
		print("Verified 10v10 seed %d in %.1fs with %d hits and %d blocks." % [
			seed_value, battle.elapsed, battle.hits, battle.blocks,
		])
	return true


func _fixture(living: Array[int]) -> Battle:
	var battle := Battle.new()
	for index in range(battle.soldiers.size()):
		var soldier := battle.soldiers[index]
		if living.has(index):
			soldier.ready_in = 100.0
		else:
			soldier.unit.receive_damage(soldier.unit.hp)
	return battle


func _fail(reason: String) -> bool:
	push_error(reason)
	return false
