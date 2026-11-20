extends SceneTree

const Battle := preload("res://game/combat/infantry_skirmish.gd")
const TICK := 1.0 / 60.0
const FIRST_AMBER := Battle.PLATOON_SIZE


func _initialize() -> void:
	var passed := _check_waiting()
	passed = _check_enemy_scan() and passed
	passed = _check_retarget_delay() and passed
	passed = _check_retarget_choice() and passed
	passed = _check_reinforcement_priorities() and passed
	passed = _check_reinforcement_arrival() and passed
	passed = _check_slots() and passed
	passed = _check_passing() and passed
	passed = _check_slash_timing() and passed
	passed = _check_trade() and passed
	passed = _check_reactions() and passed
	passed = _check_knockback() and passed
	passed = _check_knockdown_immunity() and passed
	passed = _check_waiting_cheer() and passed
	passed = _check_victory_cheers() and passed
	passed = _check_full_matches() and passed
	quit(0 if passed else 1)


func _check_waiting() -> bool:
	var battle := _fixture([0, 1, 2, 3, 4, FIRST_AMBER])
	var enemy := battle.soldiers[FIRST_AMBER]
	enemy.position = Vector2.ZERO
	enemy.target = 0
	enemy.scan_in = 10.0
	battle.soldiers[0].position = Vector2(-1.36, 0)
	battle.soldiers[1].position = Vector2(0, -1.36)
	battle.soldiers[2].position = Vector2(-1, 1)
	var runner := battle.soldiers[3]
	runner.position = Vector2(4, 0)
	var nearby := battle.soldiers[4]
	nearby.position = Vector2(0, 2.1)
	battle.step(TICK)
	if battle.engagements[FIRST_AMBER].size() != 3 or battle.waiting_count() != 2:
		return _fail("A fifth soldier entered the already full engagement.")
	if runner.target != -1 or runner.pursuit != FIRST_AMBER or runner.state != Battle.State.RUN or runner.position.x >= 4:
		return _fail("A distant reserve failed to run toward its nearest enemy.")
	if nearby.target != -1 or nearby.pursuit != FIRST_AMBER or nearby.state != Battle.State.IDLE:
		return _fail("A nearby reserve failed to idle outside the full fight.")
	for tick in range(90):
		battle.step(TICK)
	if runner.state != Battle.State.IDLE or runner.position.distance_to(enemy.position) > Battle.WAIT_DISTANCE + 0.07:
		return _fail("A reserve did not idle after reaching the edge of the fight.")
	enemy.position -= (runner.position - enemy.position).normalized() * 0.60
	battle.step(TICK)
	if runner.state != Battle.State.RUN or runner.target != -1:
		return _fail("A reserve did not follow the full engagement when it moved away.")
	battle.soldiers[0].unit.receive_damage(battle.soldiers[0].unit.hp)
	runner.scan_in = 0.0
	nearby.scan_in = 10.0
	battle.step(TICK)
	if runner.approach != FIRST_AMBER or battle.engagements[FIRST_AMBER].has(3):
		return _fail("A reserve failed to approach the open slot before claiming it.")
	for tick in range(90):
		battle.step(TICK)
	if runner.target != FIRST_AMBER or not battle.engagements[FIRST_AMBER].has(3):
		return _fail("The reserve did not fill the casualty's slot.")
	print("Verified the three-opponent cap and the reserve run, idle, and reassignment.")
	return true


func _check_enemy_scan() -> bool:
	var selections := {}
	for seed_value in range(12):
		var battle := _fixture([0, FIRST_AMBER, FIRST_AMBER + 1, FIRST_AMBER + 2], seed_value)
		var scout := battle.soldiers[0]
		scout.position = Vector2.ZERO
		battle.soldiers[FIRST_AMBER].position = Vector2(2.9, 0)
		battle.soldiers[FIRST_AMBER + 1].position = Vector2(-3.8, 0)
		battle.soldiers[FIRST_AMBER + 2].position = Vector2(0, 6)
		scout.scan_in = 0.20
		battle.step(TICK)
		if scout.approach != -1:
			return _fail("The soldier scanned before its timer expired.")
		scout.scan_in = 0
		battle.step(TICK)
		var selected := scout.approach
		if selected not in [FIRST_AMBER, FIRST_AMBER + 1] or scout.target != -1:
			return _fail("The scan selected outside its radius or claimed a slot from a distance.")
		selections[selected] = true
		var start := scout.position.distance_to(battle.soldiers[selected].position)
		scout.scan_in = 0
		battle.step(TICK)
		if scout.approach != selected or scout.position.distance_to(battle.soldiers[selected].position) >= start:
			return _fail("The soldier abandoned a valid approach or ran away from its selection.")
	if selections.size() != 2:
		return _fail("Repeated scans always chose the same enemy despite multiple eligible targets.")
	print("Verified periodic scans, radius filtering, random target selection, and pursuit.")
	return true


func _check_retarget_delay() -> bool:
	var battle := _fixture([0, FIRST_AMBER, FIRST_AMBER + 1])
	var soldier := battle.soldiers[0]
	var defeated := battle.soldiers[FIRST_AMBER]
	var attacker := battle.soldiers[FIRST_AMBER + 1]
	soldier.position = Vector2.ZERO
	soldier.target = FIRST_AMBER
	soldier.cheer_in = 0.0
	attacker.position = Vector2(0, 1.25)
	attacker.scan_in = 100.0
	defeated.unit.receive_damage(defeated.unit.hp)
	battle._assign_targets()
	if soldier.target != -1 or soldier.retarget_at < battle.elapsed or soldier.retarget_at > battle.elapsed + 7.0:
		return _fail("A casualty did not release its opponent and start a 0–7 second retarget delay.")
	soldier.retarget_at = battle.elapsed + 5.0
	var deadline := soldier.retarget_at
	battle.step(TICK)
	if soldier.state != Battle.State.CHEER or soldier.approach != -1 or soldier.reinforce_ally != -1:
		return _fail("A waiting soldier could not cheer or looked for a new target too soon.")
	attacker.target = 0
	attacker.state = Battle.State.ATTACK
	attacker.time = Battle.CONTACT - TICK * 0.5
	battle.step(TICK)
	if soldier.unit.hp >= soldier.unit.max_hp or soldier.retarget_at != deadline:
		return _fail("An attack on a waiting soldier was ignored or restarted the delay.")
	soldier.state = Battle.State.STAGGER
	soldier.time = 0.0
	soldier.retarget_at = battle.elapsed
	battle.step(TICK)
	if soldier.retarget_at < 0.0 or soldier.approach != -1 or soldier.reinforce_ally != -1:
		return _fail("Retargeting ran during a stagger.")
	soldier.state = Battle.State.IDLE
	soldier.target = FIRST_AMBER + 1
	soldier.retarget_at = -1.0
	attacker.position = Vector2(0, Battle.PURSUIT_RANGE + 1.0)
	battle.step(TICK)
	if soldier.target != -1 or soldier.retarget_at < battle.elapsed:
		return _fail("A focused enemy outside pursuit range did not trigger retargeting.")
	print("Verified the delay on target loss, cheering, incoming hits and deferred retargeting during stagger.")
	return true


func _check_retarget_choice() -> bool:
	var battle := _fixture([0, 1, FIRST_AMBER, FIRST_AMBER + 1])
	var soldier := battle.soldiers[0]
	var ally := battle.soldiers[1]
	var nearby := battle.soldiers[FIRST_AMBER]
	var attacker := battle.soldiers[FIRST_AMBER + 1]
	soldier.position = Vector2.ZERO
	ally.position = Vector2(6.0, 0)
	nearby.position = Vector2(0, 2.5)
	attacker.position = Vector2(7.0, 0)
	attacker.target = 1
	for other in [ally, nearby, attacker]:
		other.scan_in = 100.0
	var normal_choices := 0
	for attempt in range(200):
		battle._begin_retarget(soldier)
		soldier.retarget_at = battle.elapsed
		battle._assign_targets()
		if soldier.approach == FIRST_AMBER and soldier.reinforce_ally == -1:
			normal_choices += 1
		elif soldier.reinforce_ally != 1 or soldier.approach != -1:
			return _fail("A retarget roll ran both branches or selected the wrong goal.")
		if soldier.retarget_at != -1.0:
			return _fail("A successful retarget roll left the delay pending.")
	if normal_choices < 80 or normal_choices > 120:
		return _fail("The two targeting branches were not selected with roughly equal frequency.")
	print("Verified both retarget branches in 200 rolls (%d normal, %d reinforce)." % [normal_choices, 200 - normal_choices])
	return true


func _check_reinforcement_priorities() -> bool:
	var living: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	for index in range(FIRST_AMBER, FIRST_AMBER + 16):
		living.append(index)
	var battle := _fixture(living)
	var soldier := battle.soldiers[0]
	soldier.position = Vector2.ZERO
	var rival := FIRST_AMBER
	for index in range(1, 9):
		var ally := battle.soldiers[index]
		ally.position = Vector2(4.0 * index, 0.0)
		var attackers := 2
		if index == 7:
			ally.position.x = 40.0
			attackers = 1
		elif index == 8:
			ally.position.x = 45.8
			attackers = 3
		for incoming in range(attackers):
			battle.soldiers[rival].target = index
			battle._link_engagement(rival, index)
			rival += 1
	# This ally's outgoing target does not count as a second attacker.
	battle.soldiers[7].target = FIRST_AMBER
	battle._link_engagement(7, FIRST_AMBER)
	var choices := {}
	for attempt in range(40):
		var ally := battle._choose_ally_to_reinforce(soldier)
		if ally not in [2, 3, 4, 5, 6]:
			return _fail("Reinforcement ignored the 50-yard radius, incoming attack count, or farthest-five limit.")
		choices[ally] = true
	if choices.size() < 2:
		return _fail("Reinforcement always selected the same equally threatened ally.")
	print("Verified reinforcement range, incoming-only priority and random choice among the five farthest tied allies.")
	return true


func _check_reinforcement_arrival() -> bool:
	var battle := _fixture([0, 1, 2, 3, FIRST_AMBER, FIRST_AMBER + 1, FIRST_AMBER + 2])
	var runner := battle.soldiers[0]
	var ally := battle.soldiers[1]
	var near_enemy := battle.soldiers[FIRST_AMBER]
	var far_enemy := battle.soldiers[FIRST_AMBER + 1]
	runner.position = Vector2.ZERO
	runner.reinforce_ally = 1
	ally.position = Vector2(4.0, 0.0)
	near_enemy.position = Vector2(3.0, -0.9)
	far_enemy.position = Vector2(4.0, 1.2)
	battle.soldiers[FIRST_AMBER + 2].position = Vector2(2.7, 2.5)
	near_enemy.target = 1
	far_enemy.target = 1
	battle.soldiers[2].position = Vector2(4.4, -2.0)
	battle.soldiers[3].position = Vector2(4.8, -1.4)
	for index in [2, 3]:
		battle.soldiers[index].target = FIRST_AMBER
	for index in [1, 2, 3, FIRST_AMBER, FIRST_AMBER + 1, FIRST_AMBER + 2]:
		var other := battle.soldiers[index]
		other.state = Battle.State.LOWER
		other.time = -10.0
	battle.step(TICK)
	if runner.state != Battle.State.RUN or runner.target != -1 or runner.position.x <= 0.0:
		return _fail("The reinforcing soldier did not run toward the ally before selecting an enemy.")
	for tick in range(120):
		battle.step(TICK)
		if runner.target >= 0:
			break
	if runner.target != FIRST_AMBER + 1 or runner.reinforce_ally != -1:
		return _fail("The reinforcing soldier ignored eligibility or chose an enemy attacking somebody else.")
	if runner.position.distance_to(ally.position) > Battle.ATTACK_RANGE + 0.1 or battle.engagements[FIRST_AMBER].size() != 3:
		return _fail("Reinforcement assigned early or bypassed a full engagement.")

	battle._begin_retarget(runner)
	runner.retarget_at = -1.0
	runner.reinforce_ally = 1
	runner.position = Vector2(2.8, 0.0)
	far_enemy.state = Battle.State.DOWN
	battle.step(TICK)
	if runner.target != -1 or runner.reinforce_ally != -1 or runner.retarget_at < battle.elapsed:
		return _fail("Reinforcement with no eligible attacker did not start a fresh delay.")
	print("Verified reinforcement movement, arrival, the engagement cap and failed-attempt retries.")
	return true


func _check_slots() -> bool:
	var battle := _fixture([0, 1, 2, FIRST_AMBER])
	var defender := battle.soldiers[FIRST_AMBER]
	defender.position = Vector2.ZERO
	defender.target = 0
	battle.soldiers[0].position = Vector2(0, -1.29)
	battle.soldiers[1].position = Vector2(-0.64, -1.08)
	battle.soldiers[2].position = Vector2(0.64, -1.08)
	for tick in range(180):
		battle.step(TICK)
	var slots := {}
	var bearings: Array[Vector2] = []
	for index in range(3):
		var attacker := battle.soldiers[index]
		if attacker.target != FIRST_AMBER or attacker.slot < 0 or slots.has(attacker.slot):
			return _fail("Three attackers failed to obtain separate positions.")
		slots[attacker.slot] = true
		bearings.append((attacker.position - defender.position).normalized())
		if attacker.position.distance_to(defender.position) > Battle.ATTACK_RANGE:
			return _fail("An attacker was left outside melee range.")
	for first in range(3):
		for second in range(first + 1, 3):
			if absf(bearings[first].angle_to(bearings[second])) < deg_to_rad(65.0):
				return _fail("Attackers on the same defender did not spread out.")
	defender.slot = 1
	defender.slot_axis = Vector2.RIGHT
	battle.soldiers[0].slot_axis = Vector2.RIGHT
	var prior_position := defender.position
	for tick in range(60):
		battle.step(TICK)
	if defender.position.distance_to(prior_position) > 0.10:
		return _fail("A reciprocal pair tried to circle each other to reach conflicting slots.")
	print("Verified three distinct melee positions and a stable reciprocal engagement.")
	return true


func _check_passing() -> bool:
	var idle_yield := _passing_yield(Battle.State.IDLE)
	var guard_yield := _passing_yield(Battle.State.GUARD)
	if idle_yield < 0.01 or guard_yield < 0.0 or guard_yield >= idle_yield:
		return _fail("A runner did not pass cleanly or the guard yielded as easily as an idle soldier.")
	print("Verified runners steer around blockers and idle soldiers yield more than guards.")
	return true


func _passing_yield(stance: Battle.State) -> float:
	var battle := _fixture([0, 1, FIRST_AMBER])
	var runner := battle.soldiers[0]
	var blocker := battle.soldiers[1]
	var enemy := battle.soldiers[FIRST_AMBER]
	runner.position = Vector2(-2.5, 0)
	runner.approach = FIRST_AMBER
	blocker.position = Vector2.ZERO
	blocker.scan_in = 10.0
	blocker.state = stance
	blocker.time = -10.0
	enemy.position = Vector2(2.0, 0)
	enemy.scan_in = 10.0
	for tick in range(155):
		battle.step(TICK)
		if runner.position.distance_to(blocker.position) < Battle.BODY_CORE - 0.015:
			return -1.0
	if runner.position.x <= blocker.position.x + 0.40:
		return -1.0
	return absf(blocker.position.y)


func _check_slash_timing() -> bool:
	var battle := _fixture([0, FIRST_AMBER])
	var attacker := battle.soldiers[0]
	var defender := battle.soldiers[FIRST_AMBER]
	var start := Vector2(0, -1.45)
	attacker.position = start
	attacker.target = FIRST_AMBER
	attacker.state = Battle.State.ATTACK
	defender.position = Vector2.ZERO
	defender.state = Battle.State.LOWER
	defender.time = -10.0

	var hit_time := -1.0
	var finish_time := -1.0
	for tick in range(1, 70):
		battle.step(TICK)
		var time := tick * TICK
		if time <= 0.22 and not attacker.position.is_equal_approx(start):
			return _fail("The slash moved before the retimed forward step.")
		if time >= 0.64 and not attacker.position.is_equal_approx(start + Vector2(0, 0.52)):
			return _fail("The slash did not finish its forward movement on the retimed advance.")
		if battle.hits == 1 and hit_time < 0.0:
			hit_time = time
		if attacker.state != Battle.State.ATTACK:
			finish_time = time
			break
	if battle.hits != 1 or absf(hit_time - 0.50) > TICK + 0.0001:
		return _fail("The retimed slash did not make exactly one contact at 0.50 seconds.")
	if absf(finish_time - 1.047619) > TICK + 0.0001:
		return _fail("The retimed slash did not finish at about 1.05 seconds.")
	print("Verified the faster slash's contact, forward movement, and finish.")
	return true


func _check_trade() -> bool:
	var battle := _fixture([0, FIRST_AMBER])
	var left := battle.soldiers[0]
	var right := battle.soldiers[FIRST_AMBER]
	left.position = Vector2(0, -0.55)
	right.position = Vector2(0, 0.55)
	left.target = FIRST_AMBER
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
	var battle := _fixture([0, FIRST_AMBER])
	var attacker := battle.soldiers[0]
	var defender := battle.soldiers[FIRST_AMBER]
	attacker.position = Vector2(0, -0.55)
	defender.position = Vector2(0, 0.55)
	attacker.target = FIRST_AMBER
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


func _check_knockback() -> bool:
	# The first heavy-hit roll is a stagger for seed 1 and a knockdown for seed 0.
	var cases := {Battle.State.STAGGER: [1, 0.78], Battle.State.KNOCKDOWN: [0, 1.875]}
	for reaction: int in cases:
		for away: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
			var battle := _fixture([0, FIRST_AMBER])
			var attacker := battle.soldiers[0]
			var defender := battle.soldiers[FIRST_AMBER]
			battle._random.seed = cases[reaction][0]
			attacker.position = -away * 1.25
			attacker.facing = away
			attacker.target = FIRST_AMBER
			attacker.heavy = true
			attacker.state = Battle.State.ATTACK
			attacker.time = Battle.CONTACT - TICK * 0.5
			defender.position = Vector2.ZERO
			defender.facing = Vector2.UP
			defender.scan_in = 100.0
			battle.step(TICK)
			if defender.state != reaction:
				return _fail("The directional knockback fixture did not trigger its expected reaction.")
			# Move the attacker after contact to verify the push uses the original hit direction.
			attacker.position = Vector2(6, 6)
			attacker.scan_in = 100.0
			var duration: float = Battle.DURATIONS[reaction]
			for tick in range(ceili(duration * 0.90 / TICK)):
				battle.step(TICK)
			var distance: float = cases[reaction][1]
			if not defender.position.is_equal_approx(away * distance):
				return _fail("The defender did not move %s meters away from the original hit %s." % [distance, away])

	var simultaneous := _fixture([0, 1, FIRST_AMBER])
	var target := simultaneous.soldiers[FIRST_AMBER]
	target.position = Vector2.ZERO
	for index in range(2):
		var attacker := simultaneous.soldiers[index]
		attacker.facing = Vector2.DOWN if index == 0 else Vector2.RIGHT
		attacker.position = -attacker.facing * 1.25
		attacker.target = FIRST_AMBER
		attacker.heavy = true
	simultaneous._random.seed = 9 # Stagger from the first strike, knockdown from the second.
	simultaneous._resolve_contacts([0, 1])
	if target.state != Battle.State.KNOCKDOWN or target.knockback_direction != Vector2.RIGHT:
		return _fail("The knockback direction did not follow the highest-priority hit.")
	print("Verified tripled stagger and knockdown movement on front, side and rear hits, including simultaneous strikes.")
	return true


func _check_knockdown_immunity() -> bool:
	var battle := _fixture([0, FIRST_AMBER])
	var attacker := battle.soldiers[0]
	var defender := battle.soldiers[FIRST_AMBER]
	battle._random.seed = 0 # The first heavy hit rolls a knockdown.
	defender.position = Vector2.ZERO
	defender.scan_in = 100.0
	attacker.target = FIRST_AMBER
	attacker.heavy = true
	var standing_at := -1.0
	var phases := {}
	var hp_after_knockdown := defender.unit.max_hp
	for tick in range(240):
		attacker.position = defender.position + Vector2.UP * 1.25
		attacker.facing = Vector2.DOWN
		attacker.state = Battle.State.ATTACK
		attacker.time = Battle.CONTACT - TICK * 0.5
		battle.step(TICK)
		if tick == 0:
			hp_after_knockdown = defender.unit.hp
			if defender.state != Battle.State.KNOCKDOWN or hp_after_knockdown >= defender.unit.max_hp:
				return _fail("The triggering knockdown hit did not deal damage.")
			attacker.heavy = false
		elif defender.state == Battle.State.IDLE and standing_at < 0.0:
			standing_at = battle.elapsed
		phases[defender.state] = true
		if standing_at < 0.0 or battle.elapsed < standing_at + 0.5:
			if defender.unit.hp != hp_after_knockdown or battle.hits != 1:
				return _fail("An attack dealt damage during the knockdown, recovery, or grace period.")
		else:
			if defender.unit.hp >= hp_after_knockdown or battle.hits != 2:
				return _fail("The soldier stayed invulnerable after the grace period.")
			if not phases.has_all([Battle.State.KNOCKDOWN, Battle.State.DOWN, Battle.State.GET_UP]):
				return _fail("The immunity test did not cover each phase of recovery.")
			print("Verified immunity through the complete knockdown and 0.5 seconds after Get Up.")
			return true
	return _fail("The defender never finished recovering from a knockdown.")


func _check_waiting_cheer() -> bool:
	var battle := _fixture([0, 1, 2, 3, FIRST_AMBER])
	var enemy := battle.soldiers[FIRST_AMBER]
	enemy.position = Vector2.ZERO
	enemy.target = 0
	for index in range(3):
		battle.soldiers[index].position = Vector2.LEFT.rotated(index * TAU / 3.0) * Battle.SLOT_DISTANCE
	var reserve := battle.soldiers[3]
	reserve.position = Vector2(0, 2.15)
	reserve.cheer_in = 0.0
	battle.step(TICK)
	if reserve.state != Battle.State.CHEER or reserve.target >= 0 or battle.waiting_count() != 1:
		return _fail("A reserve did not cheer when all engagement slots were occupied.")
	for tick in range(15):
		battle.step(TICK)
	if reserve.state != Battle.State.CHEER or battle.hits != 0:
		return _fail("A reserve did not sustain a harmless cheer while waiting.")
	battle.soldiers[0].unit.receive_damage(battle.soldiers[0].unit.hp)
	reserve.scan_in = 0.0
	battle.step(TICK)
	if reserve.state != Battle.State.RUN or reserve.approach != FIRST_AMBER:
		return _fail("A reserve kept cheering when an engagement slot opened.")
	print("Verified reserves cheer at full engagements and break off when a target opens.")
	return true


func _check_victory_cheers() -> bool:
	var battle := _fixture([0, 1, FIRST_AMBER])
	var front := battle.soldiers[0]
	var recovering := battle.soldiers[1]
	var enemy := battle.soldiers[FIRST_AMBER]
	front.position = Vector2(-4, 0)
	recovering.position = Vector2(-4, 2)
	enemy.position = Vector2(4, 0)
	for soldier in [front, recovering, enemy]:
		soldier.scan_in = 100.0
	for tick in range(90):
		battle.step(TICK)
	if front.state != Battle.State.IDLE or front.victory_cheers != 0:
		return _fail("The platoon celebrated before the first engagement.")
	enemy.position = Vector2(-2.7, 0)
	front.approach = FIRST_AMBER
	battle.step(TICK)
	if front.target != FIRST_AMBER:
		return _fail("The victory fixture did not engage.")
	front.target = -1
	front.pursuit = -1
	enemy.position = Vector2(4, 0)
	for tick in range(80):
		battle.step(TICK)
	if front.state != Battle.State.CHEER or battle.winner != Battle.LIVE:
		return _fail("The survivors did not celebrate after all enemies left engagement range.")
	enemy.position = Vector2(-2.7, 0)
	battle.step(TICK)
	if front.state == Battle.State.CHEER or front.victory_cheers != 0:
		return _fail("The survivors continued their victory cheers after the enemy returned.")
	var casualty := battle.soldiers[2]
	casualty.state = Battle.State.DEAD
	enemy.unit.receive_damage(enemy.unit.hp)
	recovering.state = Battle.State.KNOCKDOWN
	recovering.time = 0.0
	var cheers := [0, 0]
	var cheering := [false, false]
	for tick in range(60 * 11):
		battle.step(TICK)
		for index in range(2):
			var soldier := battle.soldiers[index]
			var playing := soldier.state == Battle.State.CHEER
			if playing and not cheering[index]:
				cheers[index] += 1
			cheering[index] = playing
		if casualty.state != Battle.State.DEAD or enemy.state == Battle.State.CHEER:
			return _fail("A casualty joined the celebration.")
	if battle.winner != 0 or cheers != [3, 3] or front.state != Battle.State.IDLE or recovering.state != Battle.State.IDLE:
		return _fail("Survivors did not finish exactly three cheers, including after recovery.")
	print("Verified range-based victory cheers, combat resumption, and three cheers per survivor.")
	return true


func _check_full_matches() -> bool:
	for seed_value in [1, 8, 124]:
		var battle := Battle.new(seed_value)
		var roster_counts := [0, 0]
		for soldier in battle.soldiers:
			roster_counts[soldier.team] += 1
			if soldier.unit.hp != 1200.0 or soldier.unit.max_hp != 1200.0:
				return _fail("The skirmish did not spawn Infantry with 1,200 HP.")
			if soldier.position.abs().x > Battle.ARENA_LIMIT.x or soldier.position.abs().y > Battle.ARENA_LIMIT.y:
				return _fail("An opening rank spawned outside the arena.")
		if roster_counts != [32, 32]:
			return _fail("The skirmish did not spawn 32 soldiers per side.")
		for tick in range(60 * 240):
			battle.step(TICK)
			for engagement in battle.engagements:
				if engagement.size() > Battle.MAX_ENGAGEMENTS:
					return _fail("A soldier exceeded the engagement cap in open combat.")
			if battle.winner != Battle.LIVE:
				break
		if battle.winner == Battle.LIVE or battle.hits == 0 or battle.blocks == 0:
			return _fail("An autonomous skirmish failed to resolve with hits and blocks.")
		print("Verified 32v32 seed %d in %.1fs with %d hits and %d blocks." % [
			seed_value, battle.elapsed, battle.hits, battle.blocks,
		])
	return true


func _fixture(living: Array[int], seed_value: int = 8) -> Battle:
	var battle := Battle.new(seed_value)
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
