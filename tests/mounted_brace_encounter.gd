extends SceneTree

const Encounter := preload("res://game/combat/mounted_brace_encounter.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Roster := preload("res://game/combat/faction_roster.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const WellRoad := preload("res://game/battlefields/red_basin_well_road.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Phase := Encounter.Phase
const Result := Encounter.Result

var _map: Node3D
var _terrain: Terrain


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_map = WellRoad.instantiate()
	root.add_child(_map)
	await physics_frame
	await physics_frame
	_terrain = Terrain.new(_map)
	var passed := _check_real_terrain() and _check_flanks() and _check_prepare_or_move() \
		and _check_runup_runout() and _check_counterplay_and_ordering()
	_map.queue_free()
	await process_frame
	if passed:
		print("Mounted brace: actual Salt Road/blocked wash, facing and flank, settled Hold, live movement, run-up/run-out, single impact and regroup passed.")
	quit(0 if passed else 1)


func _check_real_terrain() -> bool:
	var roster := Catalog.faction_roster()
	var brace_family: StringName = roster.unit(Catalog.ORC_BRACE_INFANTRY).primary_family
	var defender := _platoon(2, 0, 1)
	var riders := _platoon(2, 0, 2)
	var road := Encounter.new(riders, defender, _point("MountedChargeStart"), brace_family,
		_terrain.can_move.bind(true), _terrain.clear_melee_contact)
	var line := _point("SaltChargeGate")
	_arm(road, line, Vector2.RIGHT)
	if not road.brace_ready or not road.order_pass(_point("MountedRunout")):
		return _fail("A real road or roster-classified anti-riding line did not admit the pass.")
	road.advance(6.0)
	if road.result != Result.NONE or road.distance_marched < 47.9 or defender.cohesion != 100.0:
		return _fail("The road charge registered at command time instead of approaching the line.")
	road.advance(50.0) # Deliberately span the contact; stepping must not tunnel through the line.
	var expected_riders := 28.0 / 1.24
	var expected_defender := 20.0 / 1.12
	if road.phase != Phase.REGROUPING or road.result != Result.REPELLED \
			or not is_equal_approx(road.rider_cohesion_lost, expected_riders) \
			or not is_equal_approx(road.defender_cohesion_lost, expected_defender) \
			or absf(road.rider_position.distance_to(line) - Encounter.CONTACT_RADIUS) > 0.04:
		return _fail("The real open-road front brace did not intercept at contact with only reduced impact.")
	var original := road.rider_position
	road.advance(8.0)
	if road.rider_position != original or not is_equal_approx(defender.cohesion, 100.0 - expected_defender):
		return _fail("Repelled riders moved through or hit again before regroup.")

	# Both endpoint markers separately sit on walkable ground. The direct dash
	# from the road to the wash crosses a real elevation/terrain obstruction.
	var wash := _point("WashReedBend")
	var side := _point("SaltRoadWest")
	var covered := Encounter.new(_platoon(), _platoon(), side, brace_family,
		_terrain.can_move.bind(true), _terrain.clear_melee_contact)
	_arm(covered, wash, (side - wash).normalized())
	var beyond := wash + (wash - side).normalized() * 10.0
	if not covered.order_pass(beyond):
		return _fail("The lane order was rejected before testing its physical movement.")
	covered.advance(40.0)
	return (covered.result == Result.TERRAIN_BLOCKED and covered.rider_cohesion_lost == 0.0 \
		and covered.defender_cohesion_lost == 0.0 and covered.rider_position.distance_to(wash) > Encounter.CONTACT_RADIUS) \
		or _fail("A charge hit a separate wash lane through actual terrain.")


func _check_flanks() -> bool:
	for start: Vector2 in [Vector2(-22, 0), Vector2(0, 22)]:
		var rider := _flat(start)
		_arm(rider, Vector2.ZERO, Vector2.RIGHT)
		if not rider.brace_ready or not rider.order_pass(-start):
			return _fail("The flank fixture did not start with a correctly set but misfacing brace.")
		rider.advance(2.5)
		if rider.result != Result.LANDED or rider.phase != Phase.RUNNING_OUT \
				or rider.defender_cohesion_lost != 24.0 or rider.rider_cohesion_lost != 0.0:
			return _fail("A front brace also protected a side or rear contact.")
		if rider.cancel_before_impact() or rider.sync_ready_riders(Vector2.ZERO):
			return _fail("A confirmed hit ignored its run-out commitment.")
		rider.advance(20.0)
		if rider.phase != Phase.REGROUPING or rider.defender_cohesion_lost != 24.0 \
				or rider.rider_position.distance_to(-start) > 0.03:
			return _fail("A landed charge did not continue through its lane or applied a second hit.")
	return true


func _check_prepare_or_move() -> bool:
	var regular := _flat(Vector2(22, 0), Roster.MELEE)
	_arm(regular, Vector2.ZERO, Vector2.RIGHT)
	if regular.brace_ready or not regular.order_pass(Vector2(-22, 0)):
		return _fail("General infantry gained the specialist brace merely by Holding.")
	regular.advance(8.0)
	if regular.result != Result.LANDED:
		return _fail("A non-specialist got the mounted repulse.")

	for change in ["turn", "move", "release"]:
		var rider := _flat(Vector2(22, 0))
		_arm(rider, Vector2.ZERO, Vector2.RIGHT)
		rider.order_pass(Vector2(-22, 0))
		rider.advance(2.0)
		var new_position := Vector2(-1.0, 0.0) if change == "move" else Vector2.ZERO
		var new_facing := Vector2(1.0, 0.2) if change == "turn" else Vector2.RIGHT
		rider.observe_defender(new_position, new_facing, change != "release", Encounter.BRACE_SECONDS)
		if rider.brace_ready:
			return _fail("Brace preparation survived a turn, relocation, or ending the Hold.")
		rider.advance(4.0)
		if rider.result != Result.LANDED:
			return _fail("Turning or moving just before a charge did not create counterplay.")

	var shaken := _platoon()
	var ready := Encounter.new(_platoon(), shaken, Vector2(26, 0), Roster.ANTI_RIDING, _open, _open)
	_arm(ready, Vector2.ZERO, Vector2.RIGHT)
	shaken.lose_cohesion(80.0)
	if ready.brace_ready or not ready.order_pass(Vector2(-25, 0)):
		return _fail("Low cohesion did not disable the front brace independently of Hold.")
	ready.advance(7.0)
	return ready.result == Result.LANDED or _fail("A shaken line still stopped the charge.")


func _check_runup_runout() -> bool:
	var slow := _flat(Vector2(11.7, 0))
	_arm(slow, Vector2.ZERO, Vector2.RIGHT)
	slow.order_pass(Vector2(-20, 0))
	slow.advance(15.0)
	if slow.result != Result.SHORT_RUNUP or slow.defender_cohesion_lost != 0.0:
		return _fail("A nearby rider received full charge momentum without physically marching.")
	var trained_riders := _platoon(0, 5)
	var trained := Encounter.new(trained_riders, _platoon(), Vector2(11.7, 0), Roster.MELEE, _open, _open)
	_arm(trained, Vector2.ZERO, Vector2.RIGHT)
	trained.order_pass(Vector2(-20, 0))
	trained.advance(15.0)
	if trained.result != Result.LANDED or trained.minimum_runup() >= slow.minimum_runup():
		return _fail("Existing Mounted Training did not shorten required preparation distance.")
	var blocked_exit := func(_from: Vector2, to: Vector2) -> bool: return to.x > -1.0
	for end in [Vector2.ZERO, Vector2(-40, 0)]:
		var encounter := Encounter.new(_platoon(), _platoon(), Vector2(30, 0), Roster.ANTI_RIDING, blocked_exit, _open)
		_arm(encounter, Vector2.ZERO, Vector2.RIGHT)
		encounter.order_pass(end)
		encounter.advance(60.0)
		if encounter.result != Result.SHORT_RUNOUT or encounter.defender_cohesion_lost != 0.0:
			return _fail("A short or obstructed run-out resolved effects instead of stopping the pass.")
	return true


func _check_counterplay_and_ordering() -> bool:
	var blocked := Encounter.new(_platoon(), _platoon(), Vector2(22, 0), Roster.ANTI_RIDING, _open,
		func(_from: Vector2, _to: Vector2) -> bool: return false)
	_arm(blocked, Vector2.ZERO, Vector2.RIGHT)
	blocked.order_pass(Vector2(-22, 0))
	blocked.advance(10.0)
	if blocked.result != Result.TERRAIN_BLOCKED or blocked.rider_cohesion_lost != 0.0 \
			or blocked.defender_cohesion_lost != 0.0:
		return _fail("A false contact across a wall or elevation fired an impact.")
	var lane := {"open": true}
	var interrupted := Encounter.new(_platoon(), _platoon(), Vector2(22, 0), Roster.MELEE,
		func(_from: Vector2, to: Vector2) -> bool: return lane.open or to.x > 1.5, _open)
	_arm(interrupted, Vector2.ZERO, Vector2.RIGHT)
	interrupted.order_pass(Vector2(-22, 0))
	interrupted.advance(2.5)
	lane.open = false
	interrupted.advance(10.0)
	if interrupted.phase != Phase.REGROUPING or interrupted.result != Result.LANDED \
			or interrupted.defender_cohesion_lost != 24.0 or interrupted.rider_position.x <= 1.5:
		return _fail("New terrain pressure after impact undid or repeated the hit, or allowed riders to cross.")
	var rider := _flat(Vector2(22, 0))
	_arm(rider, Vector2.ZERO, Vector2.RIGHT)
	if not rider.order_pass(Vector2(-22, 0)) or not rider.cancel_before_impact() or rider.order_pass(Vector2(-22, 0)):
		return _fail("Cancelling a feint did not impose regroup before another attack.")
	rider.advance(Encounter.BASE_REGROUP_SECONDS + 0.05)
	if rider.result != Result.CANCELLED or rider.rider_cohesion_lost != 0.0 \
			or not rider.sync_ready_riders(Vector2(24, 0)) or not rider.order_pass(Vector2(-24, 0)):
		return _fail("Cancelling before impact created damage or prevented a fresh staged pass.")
	rider.advance(2.0)
	# A defender withdrawing past the rider's rear cannot be hit backward.
	rider.observe_defender(rider.rider_position + Vector2.RIGHT, Vector2.RIGHT, false, 0.0)
	rider.advance(12.0)
	return (rider.result == Result.MISSED and rider.defender_cohesion_lost == 0.0) \
		or _fail("A fixed lane homed onto or hit a withdrawing unit behind its heading.")


func _arm(encounter: Encounter, point: Vector2, facing: Vector2) -> void:
	encounter.observe_defender(point, facing, true, 0.0)
	encounter.observe_defender(point, facing, true, Encounter.BRACE_SECONDS)


func _flat(start: Vector2, family := Roster.ANTI_RIDING) -> Encounter:
	return Encounter.new(_platoon(), _platoon(), start, family, _open, _open)


func _platoon(brace := 0, mounted := 0, drill := 0) -> Platoon:
	var units: Array[Unit] = [Unit.new()]
	return Platoon.new(units, {Platoon.Skill.CHARGE_BRACE: brace, Platoon.Skill.MOUNTED_TRAINING: mounted,
		Platoon.Skill.FORMATION_DRILL: drill})


func _point(id: String) -> Vector2:
	var local: Vector3 = _map.get_node("Markers/Routes/" + id).position
	return Vector2(local.x, local.z)


func _open(_from: Vector2, _to: Vector2) -> bool:
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
