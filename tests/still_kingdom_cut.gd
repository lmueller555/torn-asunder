extends SceneTree

const DEPLOYMENT := preload("res://game/battlefield/sereth_cut_playtest.tscn")
const Scale := preload("res://game/battlefield/battlefield_march_scale.gd")
const MAP := preload("res://game/battlefields/still_kingdom_cut.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const EDGE_ROUTE := [
	"WestMarchEdge", "ApproachRoadWest", "RoadBrace", "RoadTownGate",
	"RoadRecordFork", "RoadEastReveal", "EastMarchEdge",
]
const FOOT_LANES := [
	"GateOuterTurn", "GateInnerTurn", "LaneWestTurn", "LaneSouthTurn", "LaneSecurityBend",
	"LaneEastTurn", "LaneClerkTurn", "ClerkYard", "RecordRoomDoor", "RecordRoomInside",
]
const PATHS := {
	"Sereth to witness": ["Sereth", "ApproachRoadWest", "WestLaneRoadJunction", "WestLaneEntrance", "GateInnerTurn", "GateOuterTurn", "WitnessAccount", "Iren"],
	"Stair guard": ["StairGuard", "GateInnerTurn", "GateOuterTurn", "CemeteryHold", "CemeteryStairTop"],
	"Foot party up through the cut": ["MarchStairParty", "CemeteryStairFoot", "CemeteryStairTop", "CemeteryHold"],
	"Grave-cut recovery": ["CemeteryStairTop", "CemeteryStairFoot", "GraveCutApproach", "ExposedRecords"],
	"Screened witness to room": ["WitnessAccount"] + FOOT_LANES + ["AccountEntry"],
	"Clerk and recovered bundle": ["RecordRoomInside", "AccountEntry", "VillageClerk", "BundleSecure"],
	"Open road to room": [
		"HouseholdGuard", "RoadBrace", "RoadTownGate", "RoadRecordFork", "OpenRecordApproach", "RecordEntryBend", "RecordRoomDoor", "RecordRoomInside",
	],
	"Retreat with bundle": [
		"BundleSecure", "RecordRoomInside", "RecordRoomDoor", "RecordEntryBend", "DroppedBundleRecovery", "OpenRecordApproach",
		"RoadRecordFork", "RoadEastReveal", "EnemyRetreatExit",
	],
	"Mounted reserve reveals": [
		"MarchMountedReserve", "ReserveTurn", "ReserveScreenCorner", "CavalryWarning", "MountedChargeStart",
	],
	"Straight mounted road": ["MountedChargeStart", "RoadTownGate", "MountedRunout"],
}

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _points: Dictionary[String, Vector3] = {}
var _zones: Dictionary[String, AABB] = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_map = MAP.instantiate() as Node3D
	root.add_child(_map)
	_map.position = Vector3(15, 2, -11)
	await physics_frame
	await physics_frame
	_terrain = Terrain.new(_map)
	_space = _map.get_world_3d().direct_space_state
	for child: Node in _map.find_children("*", "Marker3D"):
		var marker := child as Marker3D
		var point := _map.to_local(marker.global_position)
		if marker.get_parent().name == &"PhaseZones":
			var box: Variant = marker.get_meta(&"box_size", Vector3.ZERO)
			if not box is Vector3 or minf(minf(box.x, box.y), box.z) <= 0.0:
				_fail("Missing a positive marker-only footprint at %s." % marker.name)
				return
			_zones[marker.name] = AABB(point - box * 0.5, box)
		else:
			_points[marker.name] = point
			var xz := _xz(point)
			if absf(_terrain.ground_height(xz) - point.y) > 0.04 or not _terrain.can_move(xz, xz + Vector2(0.005, 0.005), false):
				_fail("Foot marker %s is blocked or unsupported." % marker.name)
				return

	for name: String in PATHS:
		if _run_path(name, PATHS[name]) < 0.0:
			return
	if not _test_geography():
		return
	var edge_distance := _run_path("Normal edge-to-edge movement", EDGE_ROUTE)
	if edge_distance < 0.0:
		return
	if not _check_live_edge_march():
		return
	print("Verified %d markers, 10 hero/formation paths, covered lanes and exposed road. Authored edge road: %.0f m." % [
		_points.size(), edge_distance,
	])
	quit()


func _check_live_edge_march() -> bool:
	# The Cut's road is intentionally open to the east and west. Use the actual
	# deployed command ends, not a claim of physical crags or full terrain width.
	var deployment := DEPLOYMENT.instantiate()
	var battle := Battle.new()
	battle.bounds = deployment.get("field_bounds")
	var deployed_terrain: PackedScene = deployment.get("battlefield_scene")
	deployment.free()
	if deployed_terrain != MAP:
		_fail("The timed Cut terrain is not the actual routed deployment's battlefield.")
		return false
	var origin := Vector2(battle.bounds.position.x, _points["WestMarchEdge"].z)
	var end := Vector2(battle.bounds.end.x, _points["EastMarchEdge"].z)
	var route: Array[Vector2] = [origin]
	for id: String in EDGE_ROUTE:
		route.append(_xz(_points[id]))
	route.append(end)
	var formation := battle.formations[0]
	formation.position = origin
	const DT := 1.0 / 60.0
	var frames := 0
	var distance := 0.0
	for i in range(1, route.size()):
		var target := route[i]
		var before := formation.position
		battle.order_move(0, target)
		var budget := ceili(before.distance_to(target) / Battle.FORMATION_SPEED / DT) + 5
		for tick in range(budget):
			if formation.order != Battle.Order.MOVE:
				break
			battle.step(DT, Vector2.ZERO, _terrain.can_move)
			var point := formation.position
			if _terrain.destination_from_ray(Vector3(point.x, 22.0, point.y),
					Vector3(point.x, -7.0, point.y)) == null:
				_fail("The timed Cut road loses supporting terrain at %s." % point)
				return false
			frames += 1
		if formation.order != Battle.Order.HOLD or formation.position != target:
			_fail("Normal Cut march did not reach the supported road point %s." % target)
			return false
		distance += before.distance_to(formation.position)
	var seconds := frames * DT
	if not Scale.within_baseline_band(seconds) or Scale.classify_baseline(seconds) != Scale.Tier.STANDARD:
		_fail("Expected a Standard march across the playable Cut road; measured %.2f s." % seconds)
		return false
	print("Still Kingdom Cut: %.1f m / %.2f s of real infantry movement between the deployed road limits (Standard)." % [
		distance, seconds,
	])
	return true


func _test_geography() -> bool:
	for pair: Array in [
		["MarchMountedReserve", "RoadEastReveal"], ["RoadBrace", "WitnessAccount"],
		["LaneWestTurn", "LaneEastTurn"],
	]:
		if _visible(pair[0], pair[1]):
			_fail("Missing solid cover between %s and %s." % [pair])
			return false
	for pair: Array in [
		["CavalryWarning", "RoadRecordFork"], ["MountedChargeStart", "MountedRunout"],
		["CemeteryHold", "CemeteryStairFoot"], ["RecordRoomDoor", "AccountEntry"],
	]:
		if not _visible(pair[0], pair[1]):
			_fail("Required firing/approach sightline is blocked: %s." % [pair])
			return false
	# The stair is a physical high/low connector, not a painted road on one plane.
	var choke := Vector2(-83, 50)
	if not _walk(Vector3(-83, 0, 38), Vector3(-83, -5, 64)) 		or _terrain.ground_height(choke) - _terrain.ground_height(choke + Vector2.RIGHT * 3.8) < 2.0:
		_fail("The cemetery stair lost its narrow support and cut-bank drop.")
		return false
	if _ray(Vector3(76, 2.1, 5), Vector3(76, 5.5, 5)).is_empty() 		or _ray(Vector3(76, 2.1, 5), Vector3(76, 2.1, -5)).is_empty():
		_fail("Record room must retain a real roof and walls with a walkable doorway.")
		return false
	for id: String in ["RecordRoomContest", "BundleRetreatZone", "CemeteryStairHold", "OpenRoadCharge"]:
		if not _zones.has(id):
			_fail("Missing marker-only footprint %s." % id)
			return false
	var room := _zones.RecordRoomContest
	var retreat := _zones.BundleRetreatZone
	if room.intersects(retreat) or room.intersects(_zones.CemeteryStairHold) 		or not room.has_point(_points.AccountEntry + Vector3.UP) 		or not room.has_point(_points.BundleSecure + Vector3.UP) 		or not retreat.has_point(_points.EnemyRetreatExit + Vector3.UP) 		or room.has_point(_points.ExposedRecords + Vector3.UP) 		or room.has_point(_points.WitnessAccount + Vector3.UP):
		_fail("Witness, recovery at the cut, room security, and enemy extraction must remain separate.")
		return false
	if _points.VillageClerk.distance_to(_points.BundleSecure) < 6.0 or _points.Iren.distance_to(_points.ExposedRecords) < 30.0:
		_fail("A living witness or clerk must not occupy the record markers.")
		return false
	return true


func _run_path(name: String, ids: Array) -> float:
	var total := 0.0
	for id: String in ids:
		if not _points.has(id):
			_fail("Missing %s from %s." % [id, name])
			return -1.0
	for i in range(1, ids.size()):
		var a := _points[ids[i - 1]]
		var b := _points[ids[i]]
		total += a.distance_to(b)
		if not _walk(a, b):
			_fail("%s is blocked between %s and %s." % [name, ids[i - 1], ids[i]])
			return -1.0
	return total


func _walk(a: Vector3, b: Vector3) -> bool:
	var from := _xz(a)
	var to := _xz(b)
	var previous := from
	var count := maxi(1, ceili(from.distance_to(to) / 0.22))
	for i in range(count + 1):
		var next := from.lerp(to, float(i) / count)
		if not _terrain.can_move(previous, next, false) or not _terrain.can_move(previous, next, true):
			print("Terrain blocked near ", next)
			return false
		previous = next
	return true


func _visible(from: String, to: String) -> bool:
	return _ray(_points[from] + Vector3.UP * 1.6, _points[to] + Vector3.UP * 1.6).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(_map.to_global(from), _map.to_global(to), 1))


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
