extends SceneTree

const Sortie := preload("res://game/combat/flying_sortie.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Crossing := preload("res://game/battlefields/marches_crossing.tscn")
const Role := Sortie.Role
const Result := Sortie.Result
const Admission := Sortie.Admission
const START := Vector3(-30, 11, 0)
const GROUND := Vector3.ZERO
const AIR := Vector3(0, 11, 0)

var _canopies: Array[Node3D] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed := _role_and_rating() and _live_sight_and_movement() and _counter_protection() \
		and await _actual_canopy()
	if passed:
		print("Flying sortie: separate roles, committed movement, actual forest canopy and sight, fighter/equipped ground responses, single rated hit passed.")
	quit(0 if passed else 1)


func _role_and_rating() -> bool:
	var bomber := _actor(Role.BOMBER, START, 0)
	var fighter := _actor(Role.FIGHTER, START, 0)
	var ground := _actor(Role.GROUND, GROUND)
	var enemy_air := _actor(Role.BOMBER, AIR)
	var sortie := Sortie.new(_open, _no_cover)
	if sortie.order(fighter, ground) != Admission.INVALID_TARGET or sortie.order(bomber, enemy_air) != Admission.INVALID_TARGET:
		return _fail("Ground bombardment and aerial interception were treated as interchangeable.")
	if sortie.order(bomber, _actor(Role.GROUND, GROUND, 0)) != Admission.INVALID_TARGET \
			or sortie.order(ground, enemy_air) != Admission.INVALID_ROLE \
			or Sortie.new(Callable(), _no_cover).order(fighter, enemy_air) != Admission.NO_TERRAIN \
			or Sortie.new(_open, Callable()).order(bomber, ground) != Admission.NO_TERRAIN:
		return _fail("Friendly targets, a non-flyer or a missing terrain contract escaped validation.")
	for invalid_gate in [Vector3(31, 0, 0), Vector3(-29.5, 0, 0)]:
		if sortie.order(bomber, _actor(Role.GROUND, invalid_gate)) != Admission.BAD_APPROACH:
			return _fail("A run without a viable approach was staged.")
	if sortie.order(bomber, _actor(Role.GROUND, Vector3(INF, 0, 0))) != Admission.INVALID_POSITION:
		return _fail("An invalid target position was staged.")
	if sortie.order(bomber, ground) != Admission.READY or sortie.order(fighter, enemy_air) != Admission.ALREADY_ORDERED:
		return _fail("The committed bomber order was denied or overwritten by a different actor.")
	sortie.advance(0.5)
	if sortie.advance(NAN) != Result.NONE or sortie.flight_position != START + Vector3(6, 0, 0) or ground.unit.hp != 1200:
		return _fail("The bomber hit before approaching or advanced through an invalid timestep.")
	if sortie.advance(6.0) != Result.HIT or sortie.flight_position != AIR \
			or not is_equal_approx(sortie.target_hp_lost, Sortie.BOMB_DAMAGE * Unit.damage_factor(40, 28)):
		return _fail("The successful pass did not physically reach the ground target or use combat ratings.")
	var post := ground.unit.hp
	sortie.advance(6.0)
	if ground.unit.hp != post or sortie.flyer_hp_lost != 0.0:
		return _fail("Finishing a sortie repeated or invented damage.")
	var intercept := Sortie.new(_open, Callable())
	intercept.order(fighter, enemy_air)
	enemy_air.unit.receive_damage(enemy_air.unit.hp - 15.0)
	return (intercept.advance(9.0) == Result.HIT and intercept.flight_position == Vector3(-7, 11, 0) \
		and intercept.target_hp_lost == 15.0 and not enemy_air.alive()) \
		or _fail("A fighter did not intercept at its aerial gate or cap damage to remaining HP.")


func _live_sight_and_movement() -> bool:
	var flyer := _actor(Role.BOMBER, START, 0)
	var victim := _actor(Role.GROUND, GROUND)
	var wooded := Sortie.new(_open, func(pos: Vector3) -> bool: return pos.x > 0.25)
	wooded.order(flyer, victim)
	wooded.advance(0.4)
	victim.position.x += 1.0
	if wooded.advance(8.0) != Result.UNDER_COVER or wooded.target_hp_lost != 0.0:
		return _fail("Moving under overhead cover during the approach did not protect the ground target.")
	var sight := Sortie.new(func(from: Vector3, to: Vector3) -> bool: return absf(from.y - to.y) < 0.5, _no_cover)
	victim.position = GROUND
	sight.order(flyer, victim)
	if sight.advance(8.0) != Result.NO_CLEAR_LANE:
		return _fail("The release ignored its actual downward terrain sight lane.")
	var obstruction := Sortie.new(func(_from: Vector3, to: Vector3) -> bool: return to.x < -10.0, _no_cover)
	obstruction.order(flyer, victim)
	if obstruction.advance(8.0) != Result.FLIGHT_OBSTRUCTED or obstruction.flight_position.x >= -10.0:
		return _fail("The flyer crossed solid intervening terrain instead of stopping the pass.")
	for moved in [Vector3(3, 0, 0), Vector3(0, 8, 0), Vector3(0, -8, 0)]:
		victim.position = GROUND
		var evade := Sortie.new(_open, _no_cover)
		evade.order(flyer, victim)
		victim.position = moved
		if evade.advance(8.0) != Result.TARGET_EVADED or evade.target_hp_lost != 0.0:
			return _fail("A pass followed a withdrawing target or released outside the vertical window.")
	victim.position = GROUND
	var lost := Sortie.new(_open, _no_cover)
	lost.order(flyer, victim)
	victim.unit.receive_damage(2000)
	return (lost.advance(8.0) == Result.TARGET_LOST and lost.target_hp_lost == 0.0) \
		or _fail("A defeated target was struck or silently replaced.")


func _counter_protection() -> bool:
	for kind in [Role.FIGHTER, Role.GROUND, Role.BOMBER]:
		for equipped in [false, true]:
			var flyer := _actor(Role.BOMBER, START, 0)
			var victim := _actor(Role.GROUND, GROUND)
			var counter := _actor(kind, GROUND if kind == Role.GROUND else AIR)
			counter.anti_air_equipped = equipped
			var sortie := Sortie.new(_open, _no_cover)
			sortie.order(flyer, victim, counter)
			var should_counter: bool = kind == Role.FIGHTER or (kind == Role.GROUND and equipped)
			if sortie.advance(8.0) != (Result.DRIVEN_OFF if should_counter else Result.HIT):
				return _fail("The air attack was not driven off exclusively by fighters or equipped ground troops.")
			if should_counter:
				var base := Sortie.FIGHTER_DAMAGE if kind == Role.FIGHTER else Sortie.GROUND_COUNTER_DAMAGE
				if sortie.target_hp_lost != 0.0 or sortie.flight_position.x >= 0.0 \
						or not is_equal_approx(sortie.flyer_hp_lost, base * Unit.damage_factor(28, 40)):
					return _fail("Counterplay didn't resolve before the release or use ordinary Ranged ratings.")
	for constraint in ["friendly", "too far", "not ready", "blocked"]:
		var flyer := _actor(Role.BOMBER, START, 0)
		var enemy := _actor(Role.GROUND, GROUND)
		var gunner := _actor(Role.GROUND, Vector3(0, 0, 4))
		gunner.anti_air_equipped = true
		var lane := _open
		match constraint:
			"friendly": gunner.team = 0
			"too far": gunner.position.z = 30.0
			"not ready": gunner.response_ready = false
			"blocked": lane = func(from: Vector3, to: Vector3) -> bool: return from.z < 2.0 or to.z > 2.0
		var sortie := Sortie.new(lane, _no_cover)
		sortie.order(flyer, enemy, gunner)
		if sortie.advance(6.0) != Result.HIT or sortie.flyer_hp_lost != 0.0:
			return _fail("A %s defender illegally drove off the sortie." % constraint)
	# At the last gate, the now-ready defender can fire only once the flyer
	# physically enters its clear shooting lane. The response still wins ties.
	var last_shot := _actor(Role.FIGHTER, AIR)
	last_shot.response_ready = false
	var finish_line := Sortie.new(func(from: Vector3, to: Vector3) -> bool:
		return from.x < 0.0 or to.x == 0.0, _no_cover)
	finish_line.order(_actor(Role.BOMBER, START, 0), _actor(Role.GROUND, GROUND), last_shot)
	finish_line.advance(2.0)
	last_shot.response_ready = true
	if finish_line.advance(0.5) != Result.DRIVEN_OFF or finish_line.flight_position != AIR 			or finish_line.target_hp_lost != 0.0:
		return _fail("The bomber released on the same step as a clear defensive interception.")
	var fragile := _actor(Role.BOMBER, START, 0)
	fragile.unit.receive_damage(fragile.unit.hp - 1)
	var lethal := Sortie.new(_open, _no_cover)
	lethal.order(fragile, _actor(Role.GROUND, GROUND), _actor(Role.FIGHTER, AIR))
	return (lethal.advance(8.0) == Result.FLYER_LOST and lethal.flyer_hp_lost == 1.0 and lethal.target_hp_lost == 0.0) \
		or _fail("Defeating a flyer failed to cancel the pending strike.")


func _actual_canopy() -> bool:
	var battlefield: Node3D = Crossing.instantiate()
	root.add_child(battlefield)
	await physics_frame
	await physics_frame
	var terrain := Terrain.new(battlefield)
	var canopy: MeshInstance3D = battlefield.get_node("Cover/Canopy00")
	_canopies.assign(battlefield.get_node("Cover").find_children("Canopy*", "MeshInstance3D", false, false))
	# Stand under the silhouette but beside the trunk. This lane is really
	# clear in physics; the overhead veto must come from existing foliage.
	var covered := Vector3(canopy.position.x + 0.94, 0, canopy.position.z)
	var clear := covered + Vector3(0, 0, -16)
	var passed := true
	for point in [covered, clear]:
		point.y = terrain.ground_height(Vector2(point.x, point.z))
		var altitude: Vector3 = point + Vector3.UP * 12.0
		var flyer := _actor(Role.BOMBER, altitude + Vector3.BACK * 24, 0)
		var target := _actor(Role.GROUND, point)
		var sortie := Sortie.new(terrain.clear_ranged_lane, _actual_cover)
		if not terrain.clear_ranged_lane(altitude, point + Vector3.UP * 0.9) \
				or sortie.order(flyer, target) != Admission.READY \
				or sortie.advance(8.0) != (Result.UNDER_COVER if point.z == covered.z else Result.HIT):
			passed = _fail("Existing Marches foliage did not distinguish a covered target from the open field.")
	_canopies.clear()
	battlefield.queue_free()
	await process_frame
	return passed


func _actual_cover(point: Vector3) -> bool:
	for mesh: MeshInstance3D in _canopies:
		var bounds: AABB = mesh.get_aabb()
		var local := mesh.to_local(point)
		if bounds.end.y >= local.y and local.x >= bounds.position.x and local.x <= bounds.end.x \
				and local.z >= bounds.position.z and local.z <= bounds.end.z:
			return true
	return false


func _actor(kind: Role, pos: Vector3, team := 1) -> Sortie.Actor:
	return Sortie.Actor.new(Unit.new(1200.0, {Unit.Damage.RANGED: 40 if team == 0 else 28}), team, kind, pos)


func _open(_from: Vector3, _to: Vector3) -> bool:
	return true


func _no_cover(_point: Vector3) -> bool:
	return false


func _fail(message: String) -> bool:
	push_error(message)
	return false
