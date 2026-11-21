extends SceneTree

const Setup := preload("res://game/combat/skirmish_setup.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

const REGULAR := Catalog.HUMAN_INFANTRY
const HEAVY := Catalog.HUMAN_HEAVY_INFANTRY
const MELEE := Unit.Damage.MELEE
const HOLY := Unit.Damage.HOLY


func _initialize() -> void:
	var passed := _check_selection()
	passed = _check_mixed_roster() and passed
	quit(0 if passed else 1)


func _check_selection() -> bool:
	var build := Setup.PlatoonBuild.new()
	if build.unit_type != REGULAR or build.can_select_unit_type(HEAVY) or build.set_unit_type(HEAVY):
		return _fail("Untrained Infantry must be the default and cannot select Heavy Infantry.")
	build.set_level(10)
	build.set_points(MELEE, 8)
	build.set_points(HOLY, 1)
	if build.rating(MELEE) != 9 or build.set_unit_type(HEAVY):
		return _fail("Earned level or points in another rating cannot satisfy Melee Power 10.")
	build.set_points(HOLY, 0)
	build.set_points(MELEE, 9)
	if build.unit_type != REGULAR or not build.can_select_unit_type(HEAVY) or not build.set_unit_type(HEAVY):
		return _fail("Heavy Infantry must become selectable, not automatic, at Melee Power 10.")
	if build.set_unit_type(&"unknown") or build.unit_type != HEAVY or build.remaining_points() != 0:
		return _fail("Selecting a type changed the rating budget or accepted an unknown type.")
	var copy := build.copy()
	build.set_points(MELEE, 8)
	if build.unit_type != REGULAR or build.remaining_points() != 1 or copy.unit_type != HEAVY:
		return _fail("A Melee refund did not fall back to Infantry or leaked into a copied build.")
	build.set_points(MELEE, 9)
	if build.unit_type != REGULAR:
		return _fail("Regaining Melee Power 10 silently reselected Heavy Infantry.")
	copy.set_level(9)
	if copy.unit_type != REGULAR or copy.rating(MELEE) != 9 or copy.remaining_points() != 0:
		return _fail("Lowering level did not refund the newest investment and fall back immediately.")

	# A level reduction that refunds only later investments must not cancel a legal selection.
	build.set_level(12)
	build.set_points(HOLY, 2)
	if not build.set_unit_type(HEAVY):
		return _fail("The level-12 fixture could not select Heavy Infantry.")
	build.set_level(10)
	if build.unit_type != HEAVY or build.rating(HOLY) != 1 or build.rating(MELEE) != 10:
		return _fail("The build lost its legal selection or refunded points out of purchase order.")
	if not build.set_unit_type(REGULAR) or build.rating(MELEE) != 10:
		return _fail("Selecting regular Infantry should keep existing investments.")
	print("Verified Heavy Infantry selection, both ineligibility fallbacks, refunds and independent copies.")
	return true


func _check_mixed_roster() -> bool:
	var setup := Setup.new()
	setup.set_count(0, 2)
	var regular_build: Setup.PlatoonBuild = setup.sides[1][0]
	var heavy_build: Setup.PlatoonBuild = setup.sides[0][1]
	for build in [regular_build, heavy_build]:
		build.set_level(12)
		build.set_points(MELEE, 9)
		build.set_points(HOLY, 1)
	if not heavy_build.set_unit_type(HEAVY):
		return _fail("Mixed-roster fixture could not select Heavy Infantry.")
	var battle := Battle.new(17, setup.copy())
	heavy_build.set_points(MELEE, 8)
	var n := Battle.PLATOON_SIZE
	if battle.team_size(0) != 2 * n or battle.team_size(1) != n:
		return _fail("A mixed roster changed the expected troop counts.")
	var ordinary := regular_build.make_unit()
	for idx in range(battle.soldiers.size()):
		var soldier := battle.soldiers[idx]
		var is_heavy := idx >= n and idx < 2 * n
		if soldier.unit_type != (HEAVY if is_heavy else REGULAR):
			return _fail("The selected type leaked across a roster or platoon.")
		if soldier.unit.hp != soldier.unit.max_hp or soldier.platoon_index != floori(float(idx) / n) \
				or soldier.roster_index != idx % n:
			return _fail("A mixed platoon did not own its expected health state.")
		if idx >= n and (soldier.unit.level != 12 or soldier.unit.rating(MELEE) != 10 \
				or soldier.unit.rating(HOLY) != 2 or soldier.unit.stat_points != 1):
			return _fail("Creating a Heavy soldier changed progression or inherited an edited setup.")
		if is_heavy and not is_equal_approx(soldier.unit.max_hp, ordinary.max_hp * 1.10):
			return _fail("A Heavy soldier did not gain its own starting HP under the standard curve.")
		if idx >= 2 * n and not is_equal_approx(soldier.unit.max_hp, ordinary.max_hp):
			return _fail("Regular Infantry acquired the Heavy HP profile.")

	var heavy := battle.soldiers[n]
	var regular := battle.soldiers[2 * n]
	for body in battle.soldiers:
		body.position = Vector2(0, 9)
	heavy.position = Vector2(0, -2)
	regular.position = Vector2(0, 2)
	battle._index_bodies()
	battle._run_toward(heavy, Vector2(7, 0), 1.0)
	battle._run_toward(regular, Vector2(7, 0), 1.0)
	if not is_equal_approx(heavy.position.x, 2.295) or not is_equal_approx(regular.position.x, 2.7):
		return _fail("The actual unconstrained run did not use each soldier's movement profile.")

	heavy.position = Vector2.ZERO
	regular.position = Vector2.RIGHT
	heavy.facing = Vector2.RIGHT
	regular.facing = Vector2.LEFT
	heavy.target = regular.battle_index
	regular.target = heavy.battle_index
	var heavy_loss := heavy.unit.damage_from(regular.unit, {MELEE: 37.0})
	var regular_loss := regular.unit.damage_from(heavy.unit, {MELEE: 32.0})
	battle._resolve_contacts([heavy.battle_index, regular.battle_index])
	if battle.hits != 2 or not is_equal_approx(heavy.unit.max_hp - heavy.unit.hp, heavy_loss) \
			or not is_equal_approx(regular.unit.max_hp - regular.unit.hp, regular_loss) \
			or regular_loss >= heavy_loss or not heavy.unit.is_alive() or not regular.unit.is_alive():
		return _fail("The simultaneous engagement ignored one attacker’s sword profile or one-shot a full-health peer.")
	if battle.platoons[0].health_fractions() != Vector3.RIGHT \
			or not is_equal_approx(battle.platoons[1].health_fractions().y, heavy_loss / (n * heavy.unit.max_hp)) \
			or not is_equal_approx(battle.platoons[2].health_fractions().y, regular_loss / (n * regular.unit.max_hp)):
		return _fail("Mixed-roster damage was assigned to the wrong health bar.")
	print("Verified mixed platoon ownership, independent Heavy HP, 2.295 vs. 2.7 m/s, and both sword hits.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
