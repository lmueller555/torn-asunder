extends SceneTree

const Archer := preload("res://game/combat/human_archer_volley.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const MINE := preload("res://game/battlefields/year_one_mine.tscn")
const CAMPAIGN_MINE := preload("res://game/battlefields/year_one_mine_campaign.tscn")
const RANGED := Unit.Damage.RANGED

var _lane_open := true
var _ray_from := Vector3.ZERO
var _ray_to := Vector3.ZERO
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := _timing_and_rewards()
	passed = _targeting_and_interrupts() and passed
	passed = _longbow_range_and_cover() and passed
	passed = _longbow_reposition() and passed
	passed = (await _ridge_and_tunnel(MINE, "RoadJunction", Vector3(-15.0, 0.0, 21.0))) and passed
	passed = (await _ridge_and_tunnel(CAMPAIGN_MINE, "RoadCut", Vector3(-53.0, 0.0, 54.0))) and passed
	quit(0 if passed else 1)


func _timing_and_rewards() -> bool:
	var base := Archer.make_unit()
	var marksman := Unit.new(base.max_hp, {RANGED: 20, Unit.Damage.MELEE: 99})
	var target := Unit.new(Unit.STARTING_HP, {RANGED: 30})
	var pool := Points.new()
	var volley := Archer.new(marksman, 0, pool, _lane)
	var aim := Archer.Aim.new(Vector3.ZERO, target, 1, Vector3(14, 0, 0))
	var bp_before := pool.balance
	if base.max_hp != 960.0 or base.rating(RANGED) != 1 or volley.start(true, aim) != Archer.Status.READY:
		return _fail("The provisional Archer profile did not prepare a legal shot.")
	if volley.phase != Archer.Phase.WINDUP or volley.status(true, aim) != Archer.Status.BUSY \
			or volley.start(true, aim) != Archer.Status.BUSY:
		return _fail("The draw was replaced or repeated by another command.")
	if volley.advance(NAN, true, aim) != null or volley.advance(-1.0, true, aim) != null \
			or volley.advance(Archer.WINDUP_SECONDS * 0.5, true, aim) != null \
			or not is_equal_approx(volley.phase_progress(), 0.5) or target.hp != target.max_hp or pool.balance != bp_before:
		return _fail("Draw progress, damage or BP changed before release.")
	var expected := 52.0 * Unit.damage_factor(20, 30)
	var shot := volley.advance(Archer.WINDUP_SECONDS * 0.5, true, aim)
	if not shot or shot.status != Archer.Status.HIT or not is_equal_approx(shot.hp_lost, expected) \
			or not is_equal_approx(target.max_hp - target.hp, expected) or shot.bp_credited != 4 \
			or pool.balance != bp_before + 4 or volley.phase != Archer.Phase.RELOAD:
		return _fail("One release did not use the Ranged rating or credit exactly one confirmed hit.")
	if not _ray_from.is_equal_approx(Vector3(0.0, 1.45, 0.0)) \
			or not _ray_to.is_equal_approx(Vector3(14.0, 0.90, 0.0)):
		return _fail("The lane query did not use the release and impact heights.")
	volley.cancel_windup()
	if volley.start(true, aim) != Archer.Status.BUSY or volley.advance(Archer.RELOAD_SECONDS * 0.5, true) != null \
			or not is_equal_approx(volley.phase_progress(), 0.5):
		return _fail("Cancel skipped or replayed the reload window.")
	volley.advance(Archer.RELOAD_SECONDS * 0.5 + 0.001, true)
	if volley.phase != Archer.Phase.IDLE or pool.balance != bp_before + 4:
		return _fail("Reload did not reset normally or awarded duplicate BP.")

	pool.award_confirmed_hit(pool.capacity - pool.balance - 2)
	target.receive_damage(target.hp - 1.0)
	volley.start(true, aim)
	shot = volley.advance(20.0, true, aim)
	if not shot or shot.hp_lost != 1.0 or shot.bp_credited != 2 or pool.balance != pool.capacity \
			or target.is_alive() or volley.phase != Archer.Phase.IDLE or volley.advance(20.0, true, aim) != null:
		return _fail("A lethal shot did not cap damage, cap BP, or resolve once for a large step.")
	print("Verified ranged damage, draw/reload clocks, large steps, and confirmed-hit Battle Points.")
	return true


func _targeting_and_interrupts() -> bool:
	var marksman := Archer.make_unit()
	var foe := Unit.new()
	var pool := Points.new()
	var volley := Archer.new(marksman, 0, pool, _lane)
	var aim := Archer.Aim.new(Vector3.ZERO, foe, 1, Vector3(Archer.MIN_RANGE, 0.0, 0.0))
	if volley.status(true, aim) != Archer.Status.READY or volley.start(false, aim) != Archer.Status.INACTIVE:
		return _fail("The minimum range or inactive battle gate is wrong.")
	aim.target_feet.x -= 0.01
	if volley.start(true, aim) != Archer.Status.TOO_CLOSE:
		return _fail("An enemy inside the close-range dead zone was accepted.")
	aim.target_feet = Vector3(0.0, 0.0, Archer.MAX_RANGE)
	if volley.status(true, aim) != Archer.Status.READY:
		return _fail("A target exactly at maximum range was rejected.")
	aim.target_feet.y = 1.0
	if volley.start(true, aim) != Archer.Status.TOO_FAR:
		return _fail("Distance ignored vertical separation.")
	aim.target_feet = Vector3(0.0, INF, 8.0)
	if volley.start(true, aim) != Archer.Status.INVALID_POSITION:
		return _fail("An invalid position was accepted.")
	aim.target_feet = Vector3(0.0, 0.0, 8.0)
	aim.target_team = 0
	if volley.start(true, aim) != Archer.Status.INVALID_TARGET:
		return _fail("Friendly fire was admitted.")
	aim.target_team = 1
	if Archer.new(marksman, 0, pool, Callable()).start(true, aim) != Archer.Status.BLOCKED:
		return _fail("An absent terrain query opened a firing lane.")
	aim.melee_engaged = true
	if volley.start(true, aim) != Archer.Status.PINNED:
		return _fail("An Archer pinned in melee started drawing.")
	aim.melee_engaged = false

	var bp_before := pool.balance
	volley.start(true, aim)
	aim.melee_engaged = true
	var shot := volley.advance(0.1, true, aim)
	if not shot or shot.status != Archer.Status.PINNED or shot.hp_lost != 0.0 or volley.phase != Archer.Phase.RELOAD:
		return _fail("Melee did not interrupt the windup immediately.")
	aim.melee_engaged = false
	if volley.start(true, aim) != Archer.Status.BUSY:
		return _fail("Shedding melee pressure skipped the interruption reload.")
	volley.advance(20.0, true)
	for reason in [Archer.Status.BLOCKED, Archer.Status.TOO_FAR, Archer.Status.INVALID_TARGET]:
		if volley.start(true, aim) != Archer.Status.READY:
			return _fail("Could not prepare a shot before changing conditions.")
		match reason:
			Archer.Status.BLOCKED:
				_lane_open = false
			Archer.Status.TOO_FAR:
				aim.target_feet.z = Archer.MAX_RANGE + 1.0
			Archer.Status.INVALID_TARGET:
				aim.target = Unit.new()
		shot = volley.advance(Archer.WINDUP_SECONDS, true, aim)
		if not shot or shot.status != reason or shot.hp_lost != 0.0 or pool.balance != bp_before \
				or foe.hp != foe.max_hp or aim.target.hp != aim.target.max_hp:
			return _fail("A moved, screened or swapped target took damage or awarded BP.")
		_lane_open = true
		aim.target_feet.z = 8.0
		aim.target = foe
		volley.advance(20.0, true)
	volley.start(true, aim)
	aim.target_team = 0
	shot = volley.advance(Archer.WINDUP_SECONDS, true, aim)
	if not shot or shot.status != Archer.Status.INVALID_TARGET or foe.hp != foe.max_hp or pool.balance != bp_before:
		return _fail("A target that became friendly was not rechecked at release.")
	aim.target_team = 1
	volley.advance(20.0, true)
	volley.start(true, aim)
	volley.cancel_windup()
	if volley.phase != Archer.Phase.IDLE or volley.advance(20.0, true, aim) != null:
		return _fail("Replacing a pending command left a queued release.")
	volley.start(true, aim)
	if volley.advance(20.0, false, aim) != null or volley.phase != Archer.Phase.IDLE or pool.balance != bp_before:
		return _fail("An ended battle exposed a pending shot.")
	volley.start(true, aim)
	marksman.receive_damage(marksman.hp)
	if volley.advance(20.0, true, aim) != null or volley.phase != Archer.Phase.IDLE or pool.balance != bp_before:
		return _fail("A defeated shooter left a pending shot.")
	print("Verified range boundaries, friendly-fire rejection, cover resampling, target lock and melee interruption.")
	return true


func _longbow_range_and_cover() -> bool:
	var foe := Unit.new()
	var pool := Points.new()
	var bp_before := pool.balance
	var archer := Archer.new(Archer.make_unit(), 0, pool, _lane)
	var longbows := Archer.for_marches_longbows(Archer.make_unit(), 0, pool, _lane)
	var aim := Archer.Aim.new(Vector3.ZERO, foe, 1, Vector3(66.01, 0.0, 0.0))
	if longbows.status(true, aim) != Archer.Status.TOO_FAR:
		return _fail("Marches Longbows should not reach beyond 66 m.")
	aim.target_feet.x = 66.0
	if archer.status(true, aim) != Archer.Status.TOO_FAR or longbows.status(true, aim) != Archer.Status.READY:
		return _fail("Only Marches Longbows should reach the end of the longer lane.")
	aim.target_feet.x = 3.49
	if longbows.status(true, aim) != Archer.Status.TOO_CLOSE:
		return _fail("The longer range removed the Archer's near dead zone.")
	aim.target_feet.x = 3.5
	if longbows.status(true, aim) != Archer.Status.READY:
		return _fail("The longer range changed the Archer's minimum range.")
	aim.target_feet.x = 66.0
	_lane_open = false
	var blocked_start := longbows.start(true, aim)
	_lane_open = true
	if blocked_start != Archer.Status.BLOCKED or longbows.start(true, aim) != Archer.Status.READY:
		return _fail("The longer shot should require a clear lane at admission.")
	_lane_open = false
	var shot := longbows.advance(1.25, true, aim)
	_lane_open = true
	if not shot or shot.status != Archer.Status.BLOCKED or foe.hp != foe.max_hp or pool.balance != bp_before:
		return _fail("Cover at release should stop the longer shot without awarding BP.")
	if longbows.phase != Archer.Phase.RELOAD or longbows.advance(0.95, true) != null \
			or not is_equal_approx(longbows.phase_progress(), 0.5):
		return _fail("Longbow reload must still begin after release and keep the same duration.")
	longbows.advance(0.951, true)
	if longbows.start(true, aim) != Archer.Status.READY:
		return _fail("Marches Longbows could not draw again after a normal reload.")
	aim.melee_engaged = true
	shot = longbows.advance(0.01, true, aim)
	aim.melee_engaged = false
	if not shot or shot.status != Archer.Status.PINNED or longbows.start(true, aim) != Archer.Status.BUSY \
			or foe.hp != foe.max_hp or pool.balance != bp_before:
		return _fail("Melee should interrupt the long draw and force a full reload without a hit.")
	longbows.advance(1.9, true)
	if longbows.start(true, aim) != Archer.Status.READY:
		return _fail("A fresh long-range shot should be available after recovering from the pin.")
	shot = longbows.advance(1.25, true, aim)
	if not shot or shot.status != Archer.Status.HIT or shot.hp_lost <= 0.0 or pool.balance != bp_before + 4:
		return _fail("A clear 66 m shot should land and use the same confirmed-hit reward.")
	return true


func _longbow_reposition() -> bool:
	var foe := Unit.new()
	var archer := Archer.new(Archer.make_unit(), 0, null, _lane)
	var longbows := Archer.for_marches_longbows(Archer.make_unit(), 0, null, _lane)
	var aim := Archer.Aim.new(Vector3.ZERO, foe, 1, Vector3(25.0, 0.0, 0.0))
	for volley: Archer in [archer, longbows]:
		if volley.start(true, aim) != Archer.Status.READY or volley.advance(0.5, true, aim) != null:
			return _fail("Both formations should be able to start a draw before moving.")
		volley.cancel_windup()
		if volley.phase_progress() != 0.0 or volley.advance(5.0, true) != null:
			return _fail("Replacing a draw with movement should discard the queued shot.")
	aim.shooter_feet = Vector3(12.0, 0.0, 0.0)
	for volley: Archer in [archer, longbows]:
		if volley.start(true, aim) != Archer.Status.READY:
			return _fail("Both profiles should be able to start a fresh draw after repositioning.")
	var arrow := archer.advance(0.70, true, aim)
	if not arrow or arrow.status != Archer.Status.HIT or longbows.advance(0.70, true, aim) != null \
			or not is_equal_approx(longbows.phase_progress(), 0.56) \
			or longbows.advance(0.549, true, aim) != null:
		return _fail("The ordinary Archer's draw is quicker after a move; Longbows must draw again from zero.")
	var long_arrow := longbows.advance(0.002, true, aim)
	if not long_arrow or long_arrow.status != Archer.Status.HIT or not is_equal_approx(long_arrow.hp_lost, arrow.hp_lost):
		return _fail("The longer draw should deal standard bow damage when it completes.")
	print("Verified Marches Longbows reach, unchanged cover and melee checks, and slower setup after relocation.")
	return true


func _ridge_and_tunnel(scene: PackedScene, road_marker: String, blocked_from: Vector3) -> bool:
	var map := scene.instantiate() as Node3D
	root.add_child(map)
	map.position = Vector3(14.0, 7.0, -9.0)
	await physics_frame
	await physics_frame
	_space = map.get_world_3d().direct_space_state
	var ridge := map.get_node("Markers/Routes/RidgeOverlook") as Marker3D
	var road := map.get_node("Markers/Routes/" + road_marker) as Marker3D
	var tunnel := map.get_node("Markers/Routes/TunnelMidpoint") as Marker3D
	var foe := Unit.new()
	var volley := Archer.new(Archer.make_unit(), 0, Points.new(), _mine_lane)
	var aim := Archer.Aim.new(ridge.global_position, foe, 1, road.global_position)
	if volley.start(true, aim) != Archer.Status.READY:
		return _fail("The authored ridge could not cover %s in %s." % [road_marker, scene.resource_path])
	var shot := volley.advance(Archer.WINDUP_SECONDS, true, aim)
	if not shot or shot.hp_lost <= 0.0:
		return _fail("The shot from the ridge down to the road did not resolve.")
	volley.advance(20.0, true)
	aim.shooter_feet = map.to_global(blocked_from)
	aim.target_feet = tunnel.global_position
	if volley.status(true, aim) != Archer.Status.BLOCKED:
		return _fail("The archer could shoot through the actual tunnel wall in %s." % scene.resource_path)
	print("Verified the Mine ridge-to-%s lane and blocked tunnel approach." % road_marker)
	map.queue_free()
	return true


func _lane(from: Vector3, to: Vector3) -> bool:
	_ray_from = from
	_ray_to = to
	return _lane_open


func _mine_lane(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return _space.intersect_ray(query).is_empty()


func _fail(message: String) -> bool:
	push_error(message)
	return false
