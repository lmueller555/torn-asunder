extends SceneTree

const Setup := preload("res://game/combat/skirmish_setup.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const TICK := 1.0 / 60.0


func _initialize() -> void:
	var passed := _check_setup()
	passed = _check_factory() and passed
	passed = _check_battle() and passed
	passed = _check_largest_roster() and passed
	quit(0 if passed else 1)


func _check_setup() -> bool:
	var setup := Setup.new()
	if setup.sides[0].size() != 1 or setup.sides[1].size() != 1:
		return _fail("The default match should have one platoon on each side.")
	setup.set_count(0, 999)
	if setup.sides[0].size() != Setup.MAX_PLATOONS or setup.sides[1].size() != 1:
		return _fail("Changing Blue platoon count failed to clamp or changed Amber.")
	var build: Setup.PlatoonBuild = setup.sides[0][0]
	build.set_points(Unit.Damage.MELEE, 1)
	if build.points_for(Unit.Damage.MELEE) != 0 or build.rating(Unit.Damage.MELEE) != 15:
		return _fail("Level-1 infantry could spend a point it had not earned.")
	build.set_level(9)
	build.set_points(Unit.Damage.FIRE, 3)
	build.set_points(Unit.Damage.ICE, 4)
	build.set_points(Unit.Damage.FIRE, 100)
	if build.points_for(Unit.Damage.FIRE) != 4 or build.remaining_points() != 0:
		return _fail("An allocation exceeded the total shared budget.")
	build.set_level(5)
	if build.points_for(Unit.Damage.FIRE) != 3 or build.points_for(Unit.Damage.ICE) != 1:
		return _fail("Lowering level failed to refund the newest investments first.")
	build.set_points(Unit.Damage.FIRE, -1)
	build.set_points(Unit.Damage.HOLY, 1)
	if build.remaining_points() != 2 or build.rating(Unit.Damage.HOLY) != 5:
		return _fail("Removing an investment failed to make its points spendable elsewhere.")
	var saved := setup.copy()
	build.set_level(-10)
	setup.set_count(0, -1)
	if build.level != 1 or build.remaining_points() != 0 or setup.sides[0].size() != 1:
		return _fail("Level or count fell outside the supported lower limit.")
	if saved.sides[0].size() != Setup.MAX_PLATOONS or saved.sides[0][0].rating(Unit.Damage.HOLY) != 5:
		return _fail("A later edit leaked into the saved scenario.")
	setup.set_count(0, 2)
	if setup.sides[0][1].level != 1 or setup.sides[1][0].level != 1:
		return _fail("Added platoons and opposing platoons must own separate default builds.")
	print("Setup clamps levels and counts, budgets and refunds points, and snapshots independent platoons.")
	return true


func _check_factory() -> bool:
	var setup := Setup.new()
	var build: Setup.PlatoonBuild = setup.sides[1][0]
	build.set_level(999)
	if build.level != Unit.MAX_LEVEL or build.remaining_points() != Unit.MAX_LEVEL - 1:
		return _fail("Level cap and earned budget differ from CombatUnit.")
	build.set_points(Unit.Damage.MELEE, 100)
	build.set_points(Unit.Damage.CURSE, 6)
	if build.rating(Unit.Damage.MELEE) != 100 or build.points_for(Unit.Damage.MELEE) != 17:
		return _fail("A unit with innate melee 15 should reach 100 after 17 points.")
	var definition: Dictionary = Catalog.TYPES[Catalog.HUMAN_INFANTRY]
	var trained := Unit.new(definition.starting_hp, definition.ratings)
	for target_level in range(2, Unit.MAX_LEVEL + 1):
		trained.award_experience(trained.experience_for_next_level())
	var from_setup := build.make_unit()
	for rating: Unit.Damage in Unit.Damage.values():
		for point in range(build.points_for(rating)):
			if not trained.spend_stat_point(rating):
				return _fail("Setup allowed points normal progression would reject.")
		if from_setup.rating(rating) != trained.rating(rating):
			return _fail("Factory and progression disagree on a combat rating.")
	var recruit := Unit.new(definition.starting_hp, definition.ratings)
	if from_setup.level != trained.level or from_setup.stat_points != trained.stat_points or from_setup.experience != trained.experience:
		return _fail("The instantiated soldier has a different progression state.")
	if not is_equal_approx(from_setup.max_hp, trained.max_hp) or from_setup.hp != from_setup.max_hp:
		return _fail("The factory failed to grant the level's full health pool.")
	if not is_equal_approx(recruit.damage_from(from_setup, definition.basic_attack), recruit.damage_from(trained, definition.basic_attack)):
		return _fail("The factory's unit has the wrong outgoing level scaling.")
	if not is_equal_approx(from_setup.damage_from(recruit, definition.basic_attack), trained.damage_from(recruit, definition.basic_attack)):
		return _fail("The factory's unit has the wrong incoming level scaling.")
	from_setup.receive_damage(from_setup.hp)
	if not build.make_unit().is_alive():
		return _fail("Instantiating the same build twice shared a soldier's health.")
	print("The configured factory matches earned XP, ratings, unspent points, HP and damage scaling.")
	return true


func _check_battle() -> bool:
	var setup := Setup.new()
	setup.set_count(0, 2)
	setup.set_count(1, 3)
	setup.sides[0][1].set_level(5)
	setup.sides[0][1].set_points(Unit.Damage.FIRE, 3)
	setup.sides[1][2].set_level(18)
	setup.sides[1][2].set_points(Unit.Damage.MELEE, 17)
	var battle := Battle.new(42, setup)
	var n := Battle.PLATOON_SIZE
	if battle.soldiers.size() != 5 * n or battle.team_size(0) != 2 * n or battle.team_size(1) != 3 * n:
		return _fail("The simulator ignored an asymmetric roster.")
	for index in range(battle.soldiers.size()):
		var soldier := battle.soldiers[index]
		var team := 0 if index < 2 * n else 1
		var platoon := floori(float(index) / n)
		var slot := platoon if team == 0 else platoon - 2
		var build: Setup.PlatoonBuild = setup.sides[team][slot]
		if soldier.team != team or soldier.platoon_index != platoon or soldier.roster_index != index % n:
			return _fail("A soldier's force, platoon or local roster index is wrong.")
		if soldier.unit.level != build.level or soldier.unit.stat_points != build.remaining_points():
			return _fail("A soldier did not inherit its own platoon's level and budget.")
		for rating: Unit.Damage in Unit.Damage.values():
			if soldier.unit.rating(rating) != build.rating(rating):
				return _fail("A soldier inherited a rating from the wrong platoon.")
	# Trade lethal hits at the same local roster index in two non-leading platoons.
	var blue_index := n + 3
	var amber_index := 4 * n + 3
	var blue := battle.soldiers[blue_index]
	var amber := battle.soldiers[amber_index]
	blue.position = Vector2.ZERO
	amber.position = Vector2.RIGHT
	blue.facing = Vector2.RIGHT
	amber.facing = Vector2.LEFT
	blue.target = amber_index
	amber.target = blue_index
	for soldier in [blue, amber]:
		soldier.unit.receive_damage(soldier.unit.hp - 1.0)
		battle._set_state(soldier, Battle.State.ATTACK)
		soldier.time = Battle.CONTACT - TICK * 0.5
	var wounded := battle.soldiers[0].unit
	wounded.receive_damage(wounded.max_hp * 0.5)
	battle.step(TICK)
	if blue.unit.is_alive() or amber.unit.is_alive() or battle.survivors(0) != 2 * n - 1 or battle.survivors(1) != 3 * n - 1:
		return _fail("A strike injured the wrong platoon when local roster indices repeated.")
	var first_platoon_wounds := 0.5 / n
	if not is_equal_approx(battle.platoons[0].health_fractions().y, first_platoon_wounds):
		return _fail("The wounded soldier was recorded against the wrong health bar.")
	for index in [1, 4]:
		if not is_equal_approx(battle.platoons[index].health_fractions().z, 1.0 / n):
			return _fail("A casualty was recorded against the wrong platoon health bar.")
	if battle.platoons[2].health_fractions() != Vector3.RIGHT or battle.platoons[3].health_fractions() != Vector3.RIGHT:
		return _fail("Damage spilled into a platoon with no injuries.")
	for soldier in battle.soldiers:
		if soldier.platoon_index == 0 or soldier.platoon_index == 2:
			soldier.unit.receive_damage(soldier.unit.hp)
	battle.step(TICK)
	if battle.winner != Battle.LIVE:
		return _fail("Losing the first platoon incorrectly eliminated an entire force.")
	for soldier in battle.soldiers:
		if soldier.team == 1:
			soldier.unit.receive_damage(soldier.unit.hp)
	battle.step(TICK)
	if battle.winner != 0 or battle.survivors(1) != 0:
		return _fail("The battle did not end after the last enemy platoon fell.")
	print("An asymmetric battle preserves builds, routes damage to local rosters, and wins across all platoons.")
	return true


func _check_largest_roster() -> bool:
	var setup := Setup.new()
	for team in range(2):
		setup.set_count(team, Setup.MAX_PLATOONS)
	var battle := Battle.new(14, setup)
	if battle.soldiers.size() != 2 * Setup.MAX_PLATOONS * Battle.PLATOON_SIZE:
		return _fail("The largest supported battle lost soldiers.")
	for soldier in battle.soldiers:
		if absf(soldier.position.x) > battle.arena_limit.x or absf(soldier.position.y) > battle.arena_limit.y:
			return _fail("The largest formation spawned a soldier outside the arena.")
		soldier.unit.receive_damage(soldier.unit.hp)
	battle.step(TICK)
	if battle.winner != Battle.DRAW:
		return _fail("Simultaneous defeat of both forces should result in a draw.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
