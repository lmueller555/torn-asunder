extends SceneTree

const Points := preload("res://game/combat/battle_points.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const SECOND_BLUE := Battle.PLATOON_SIZE
const FIRST_AMBER := 2 * Battle.PLATOON_SIZE


func _initialize() -> void:
	var passed := _check_pool()
	passed = _check_status_frame() and passed
	passed = _check_team_pools() and passed
	passed = _check_melee_awards() and passed
	passed = _check_charge_awards() and passed
	if passed:
		print("Verified battle-point capacities, shared team gains, spending, and mission reset.")
	quit(0 if passed else 1)


func _check_pool() -> bool:
	var pool := Points.new()
	if pool.balance != 400 or pool.capacity != 700 or Points.new(2).capacity != 720:
		return _fail("Starting points or level-based capacity were wrong.")
	if Points.new(99).capacity != 2660 or Points.new(1000).capacity != 2660 or Points.new(0).capacity != 700:
		return _fail("Capacity did not respect hero platoon level bounds.")
	if not pool.can_afford(125) or pool.try_spend(125, false) or pool.balance != 400:
		return _fail("Having enough points bypassed the action's independent requirements.")
	if pool.try_spend(401, true) or pool.try_spend(-1, true) or pool.balance != 400:
		return _fail("Invalid or unaffordable spending changed the balance.")
	if not pool.try_spend(400, true) or pool.balance != 0 or pool.try_spend(1, true):
		return _fail("Spending an exact balance did not leave the pool empty.")
	if pool.award_confirmed_hit(-1) != 0 or pool.award_confirmed_hit(0) != 0 or pool.balance != 0:
		return _fail("A nonpositive award changed the pool.")
	if pool.award_confirmed_hit(9223372036854775807) != 700 or pool.balance != 700 or pool.award_confirmed_hit(1) != 0:
		return _fail("A large award exceeded the cap or returned more than it credited.")
	return true


func _check_status_frame() -> bool:
	var pool := Points.new(3)
	var frozen := pool.frame()
	if frozen.balance != 400 or frozen.capacity != 740 or frozen.lead_level != 3 \
			or Points.new(0).frame().lead_level != 1 or Points.new(1000).frame().lead_level != 99:
		return _fail("The detached frame did not expose the actual clamped level, capacity and balance.")
	if frozen.spend_status(-1, false) != Points.SpendStatus.INVALID_COST \
			or frozen.spend_status(401, false) != Points.SpendStatus.REQUIREMENTS_NOT_MET \
			or frozen.spend_status(401) != Points.SpendStatus.INSUFFICIENT \
			or frozen.spend_status(400) != Points.SpendStatus.READY:
		return _fail("The readout did not distinguish invalid cost, unmet requirements, insufficient BP and readiness.")
	if pool.balance != 400 or not pool.try_spend(300, true) or pool.try_spend(120, true) \
			or pool.frame().spend_status(120) != Points.SpendStatus.INSUFFICIENT \
			or frozen.spend_status(120) != Points.SpendStatus.READY or frozen.balance != 400:
		return _fail("Read-only inspection changed the balance, or a stale affordable frame authorized a new spend.")
	if pool.award_confirmed_hit(20) != 20 or pool.frame().balance != 120 \
			or pool.frame().spend_status(120) != Points.SpendStatus.READY or frozen.balance != 400:
		return _fail("A confirmed award failed to refresh a new frame or mutated a detached one.")
	return true


func _check_team_pools() -> bool:
	var setup := _setup()
	setup.sides[0][0].level = 3
	setup.sides[0][1].level = 99
	setup.sides[1][0].level = 2
	var battle := Battle.new(8, setup)
	var blue := battle.battle_points_for_team(0)
	var amber := battle.battle_points_for_team(1)
	if blue == amber or blue.capacity != 740 or amber.capacity != 720 \
			or blue.frame().lead_level != 3 or amber.frame().lead_level != 2:
		return _fail("Teams did not get independent pools capped by their lead platoon.")
	if blue.balance != 400 or amber.balance != 400 or battle.battle_points_for_team(-1) != null or battle.battle_points_for_team(2) != null:
		return _fail("Battle initialization did not create exactly two fresh team pools.")
	if not blue.try_spend(200, true) or amber.balance != 400:
		return _fail("A team's payment affected the opposing pool.")
	var replay := Battle.new(8, setup)
	if replay.battle_points_for_team(0).balance != 400 or blue.balance != 200:
		return _fail("Restarting a battle reused or mutated the previous team's pool.")
	return true


func _check_melee_awards() -> bool:
	var battle := Battle.new(8, _setup(), 7)
	var blue := battle.battle_points_for_team(0)
	var amber := battle.battle_points_for_team(1)
	var front := battle.soldiers[0]
	var support := battle.soldiers[SECOND_BLUE]
	var defender := battle.soldiers[FIRST_AMBER]
	front.position = Vector2.ZERO
	front.facing = Vector2.RIGHT
	front.target = FIRST_AMBER
	defender.position = Vector2(2, 0)
	defender.facing = Vector2.LEFT
	battle._resolve_contacts([0])
	defender.position = Vector2(1, 0)
	defender.state = Battle.State.GUARD
	battle._resolve_contacts([0])
	defender.state = Battle.State.GET_UP
	battle._resolve_contacts([0])
	defender.state = Battle.State.IDLE
	front.facing = Vector2.LEFT
	battle._resolve_contacts([0])
	front.facing = Vector2.RIGHT
	front.target = SECOND_BLUE
	support.position = Vector2(1, 0)
	battle._resolve_contacts([0])
	if blue.balance != 400 or amber.balance != 400 or battle.hits != 0 or battle.blocks != 1:
		return _fail("An out-of-range, blocked, invulnerable, off-angle or allied contact granted points.")

	front.target = FIRST_AMBER
	support.position = Vector2(1, 1)
	support.facing = Vector2.UP
	support.target = FIRST_AMBER
	defender.target = 0
	battle._resolve_contacts([0, SECOND_BLUE, FIRST_AMBER])
	if blue.balance != 414 or amber.balance != 407 or battle.hits != 3:
		return _fail("Confirmed attacks did not contribute to both sides' shared pools.")
	return true


func _check_charge_awards() -> bool:
	var battle := Battle.new(8, _setup())
	var blue := battle.battle_points_for_team(0)
	var amber := battle.battle_points_for_team(1)
	if battle.resolve_platoon_charge(0, 1, false, 19) != 0.0 or battle.resolve_platoon_charge(0, 3, false, 19) != 0.0:
		return _fail("An allied or invalid platoon could be charged.")
	if blue.balance != 400 or amber.balance != 400:
		return _fail("An invalid charge granted BP.")
	if battle.resolve_platoon_charge(1, 2, false, 19) <= 0.0 or blue.balance != 419 or amber.balance != 400:
		return _fail("A charge from an allied platoon did not credit its team's pool.")
	battle.platoons[2].lose_cohesion(1000.0)
	if battle.resolve_platoon_charge(0, 2, true, 19) != 0.0 or blue.balance != 419:
		return _fail("A charge with no effect still awarded BP.")
	battle.winner = 0
	if battle.resolve_platoon_charge(2, 1, false, 19) != 0.0 or amber.balance != 400:
		return _fail("A finished battle still accepted a charge.")
	return true


func _setup() -> Setup:
	var setup := Setup.new()
	setup.set_count(0, 2)
	return setup


func _fail(message: String) -> bool:
	push_error(message)
	return false
