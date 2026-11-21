extends SceneTree

const Deployments := preload("res://game/campaign_deployments.gd")
const Mission := preload("res://game/battlefield/raska_well_road_playtest.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Scale := preload("res://game/battlefield/battlefield_march_scale.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")

const DT := 1.0 / 60.0
const WEST := Vector2(-150.25, -35.0)
const EAST := Vector2(162.0, -13.0)
const LAST_SUPPORTED_EAST := Vector2(168.25, -13.0)
const START := ["Routes/UpperWellHead", "Spawns/UpperWellCart", "Routes/UpperWellStaging"]
const SALT := [
	"Routes/SaltRoadWest", "Routes/SaltChargeGate", "Routes/SaltRoadEast",
]
const WASH := [
	"Routes/WestApproachFork", "Routes/WashEntryTurn", "Routes/WashWestBend",
	"Routes/WashReedBend", "Routes/WashBlindBend", "Routes/WashLongBend",
	"Routes/WashEastBend", "Routes/WashRampTurn", "Routes/WashRampFoot", "Routes/WashRampTop",
]
const FINISH := ["Routes/HighBankRally", "Objectives/BasinExit"]

var _mission: Mission
var _platoon: Battle.Formation
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var deployment := Deployments.for_mission("orc_well_road")
	_mission = deployment.scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_platoon = _mission.battle.formations[0]
	var exit := _point("Objectives/BasinExit")
	if not _check(_platoon.title == "Brace Infantry", "Benchmark must use the deployed infantry platoon.") \
			or not _check(exit != Vector2.INF and _check_endpoints(exit), "Playable endpoint evidence changed."):
		quit(1)
		return

	# Vector2 stores planar meters and reference movement seconds.
	var salt := _march(START + SALT + FINISH, EAST)
	var covered := _march(START + WASH + FINISH, EAST)
	var extraction := _march(START + WASH + FINISH, exit)
	_check(_near(salt, Vector2(321.8, 107.3)) and Scale.classify_baseline(salt.y) == Scale.Tier.SMALL,
		"The live salt road no longer matches the short benchmark: %s." % salt)
	_check(_near(covered, Vector2(443.1, 147.8)) and Scale.classify_baseline(covered.y) == Scale.Tier.LARGE,
		"The live covered route no longer matches the near-Large benchmark: %s." % covered)
	_check(_near(extraction, Vector2(438.1, 146.2)) and Scale.classify_baseline(extraction.y) == Scale.Tier.LARGE,
		"The original extraction must remain distinct from the clamp: %s." % extraction)
	_check(covered.y < Scale.BASELINE_TARGET_SECONDS[Scale.Tier.LARGE] and Scale.within_baseline_band(covered.y),
		"Nearest tier must not be mistaken for the nominal 155-second target.")
	_mission.queue_free()
	await process_frame
	if not _failed:
		print("Red Basin live infantry march: salt %.1f m / %.1f s; wash %.1f m / %.1f s; wash to extraction %.1f m / %.1f s. East playable stop precedes the physical shelf edge." %
			[salt.x, salt.y, covered.x, covered.y, extraction.x, extraction.y])
	quit(1 if _failed else 0)


func _check_endpoints(exit: Vector2) -> bool:
	var bounds := _mission.battle.bounds
	if not _check(bounds.has_point(WEST) and is_equal_approx(bounds.end.x, EAST.x)
			and exit.is_equal_approx(Vector2(157.0, EAST.y)), "Command bounds or extraction marker changed."):
		return false
	for point in [WEST, exit, EAST]:
		if not _check(_supported_footprint(point) and _mission._terrain.formation_fits_at(point),
				"Formation endpoint lacks real ground/clearance: %s." % point):
			return false

	var beyond_west := WEST + Vector2.LEFT * 0.25
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-145.0, 0.85, WEST.y), Vector3(-164.0, 0.85, WEST.y), 1)
	var hit := _mission.get_world_3d().direct_space_state.intersect_ray(ray)
	if not _check(not _mission._terrain.can_move(WEST, beyond_west, true)
			and not hit.is_empty() and hit.collider.name == &"BasinWall10",
			"West playable endpoint is no longer the supported approach to the physical wall."):
		return false

	# Probe between the extraction posts: support extends beyond live orders.
	# Check vertical hits explicitly because ground_height can fall back to zero.
	for z in [-22.0, -18.0, EAST.y, -8.0, -4.0]:
		var lip := Vector2(LAST_SUPPORTED_EAST.x, z)
		if not _check(_supported_footprint(lip) and not _supported_footprint(lip + Vector2.RIGHT * 0.25),
				"East shelf support/cutline changed at z=%s." % z):
			return false
	_platoon.position = exit
	_platoon.hold()
	_mission.battle.order_move(0, LAST_SUPPORTED_EAST)
	var clamped := _platoon.destination.is_equal_approx(EAST)
	var final_leg := _advance_order()
	return _check(clamped and _platoon.position.is_equal_approx(EAST) and final_leg.y > 0.0,
		"A real order to the supported east extension must stop at the playable clamp.")


func _supported_footprint(point: Vector2) -> bool:
	for direction in [Vector2.ZERO, Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		var foot: Vector2 = point + direction * Terrain.FORMATION_RADIUS
		if _mission._terrain.destination_from_ray(Vector3(foot.x, 20.0, foot.y), Vector3(foot.x, -8.0, foot.y)) == null:
			return false
	return true


func _march(ids: Array, end: Vector2) -> Vector2:
	_platoon.position = WEST
	_platoon.hold()
	var points := PackedVector2Array()
	for id: String in ids:
		points.append(_point(id))
	if not points[-1].is_equal_approx(end):
		points.append(end)
	var result := Vector2.ZERO
	for point in points:
		if point == Vector2.INF:
			return Vector2.ZERO
		_mission.battle.order_move(0, point)
		var measured := _advance_order()
		if not _check(_platoon.position.is_equal_approx(point) and _platoon.order == Battle.Order.HOLD,
				"Infantry was blocked or clamped before %s: %s." % [point, _platoon.position]):
			return Vector2.ZERO
		result += measured
	return result


func _advance_order() -> Vector2:
	var result := Vector2.ZERO
	var steps := ceili(_platoon.position.distance_to(_platoon.destination) / Battle.FORMATION_SPEED / DT)
	for _step in steps + 2:
		if _platoon.order != Battle.Order.MOVE:
			break
		var before := _platoon.position
		# Same order and footprint adapters as the mission; no scenario ticks,
		# cart movement, combat, or waits count toward the reference.
		_mission.battle.step(DT, Vector2.ZERO, _mission._movement_check())
		result += Vector2(before.distance_to(_platoon.position), DT)
	return result


func _point(path: String) -> Vector2:
	var marker := _mission.battlefield_marker(NodePath("Markers/" + path))
	if not _check(marker != null, "Missing deployed waypoint %s." % path):
		return Vector2.INF
	return _mission._marker_position(marker)


func _near(actual: Vector2, expected: Vector2) -> bool:
	return absf(actual.x - expected.x) <= 0.5 and absf(actual.y - expected.y) <= 0.2


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failed = true
		push_error(message)
	return ok
