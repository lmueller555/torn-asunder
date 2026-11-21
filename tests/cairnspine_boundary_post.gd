extends SceneTree

const MAP := preload("res://game/battlefields/cairnspine_boundary_post.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const EDGE_ROUTE := [
	"WestMarchEdge", "WestRoadFork", "RoadScreen", "OpenRoadBrace", "RoadCenter",
	"ScoutRoadBypassWest", "ScoutRoadBypassEast", "RoadEastStraight", "LookoutBendRoad",
	"PostRoadFork", "PostEastTurn", "EastMarchEdge",
]
const TRACK := [
	"WestTrackJunction", "WestTrackTurn", "WestRampTop", "WestRampBottom", "SheepTrackBend",
	"SheepPinch", "CoveredTrackHold", "EastRampBottom", "EastRampTop", "EastTrackLanding", "TrackEmergence",
	"TrackWallCorner", "PostTrackTurn", "WritHandover",
]
const RESERVE := [
	"MarchMountedReserve", "ReserveWideTurn", "ReserveScreenTurn", "ReserveReveal",
	"ReserveChargeEntry", "PostEastTurn",
]
const CHARGE := ["PostEastTurn", "LookoutBendRoad", "RoadEastStraight", "ScoutRoadBypassEast",
	"ScoutRoadBypassWest", "RoadCenter", "OpenRoadBrace", "MountedRunout"]
const ROAD := [
	"Sereth", "WestRoadFork", "RoadScreen", "OpenRoadBrace", "RoadCenter", "ScoutRoadBypassWest",
	"ScoutRoadBypassEast", "RoadEastStraight", "LookoutBendRoad", "PostEastTurn",
	"PostRoadApproach", "PostDoorway", "WritHandover",
]
const PATHS := {
	"Courier down the sheep track": ["Sereth", "WestRoadFork"] + TRACK,
	"Courier along the main road": ROAD,
	"Household scouts from the high bank": [
		"HouseholdPlatoon", "RoadScreen", "OpenRoadBrace", "RoadCenter",
		"ScoutRoadBypassWest", "ScoutRampFoot", "ScoutRampTop", "HighBankScout",
	],
	"Court formation screens the road": ["CourtPlatoon", "RoadScreen", "OpenRoadBrace"],
	"Covered track withdrawal": ["RallyTrackReturn", "RallyOpenTurn", "RallyScreenCorner", "WithdrawalRally"],
	"Road withdrawal": ["WestRoadFork", "WestMarchEdge", "RallyOpenTurn", "RallyScreenCorner", "WithdrawalRally"],
	"Mounted reserve reveal": RESERVE,
	"Mounted charge/runout": CHARGE,
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
		if marker.get_parent().name == &"Zones":
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
		var route: Array = PATHS[name]
		if name == "Covered track withdrawal":
			var approach := TRACK.duplicate()
			approach.reverse()
			route = approach + route
		elif name == "Road withdrawal":
			var approach := ROAD.duplicate()
			approach.reverse()
			route = approach + route
		if _run_path(name, route) < 0.0:
			return
	if not _test_geography():
		return
	var edge_distance := _run_path("Normal edge-to-edge movement", EDGE_ROUTE)
	if edge_distance < 0.0:
		return
	var march_seconds := _time_edge_march()
	if march_seconds < 0.0:
		return
	if march_seconds < 85.0 or march_seconds > 100.0:
		_fail("The representative edge route should remain near the 90-second tier.")
		return
	print("Verified %d foot markers, %d battle routes, physical lookout and reserve LOS, and a foot-only pinch. Edge: %.0f m / %.1f s." % [
		_points.size(), PATHS.size(), edge_distance, march_seconds,
	])
	quit()


func _time_edge_march() -> float:
	# Measure movement, not the support-plane width or a scripted objective.
	const DT := 1.0 / 60.0
	var formation := Battle.Formation.new("Measurement", _xz(_points[EDGE_ROUTE[0]]))
	var frames := 0
	for i in range(1, EDGE_ROUTE.size()):
		formation.destination = _xz(_points[EDGE_ROUTE[i]])
		formation.order = Battle.Order.MOVE
		var budget := ceili(formation.position.distance_to(formation.destination) / Battle.FORMATION_SPEED / DT) + 5
		for tick in range(budget):
			if formation.order != Battle.Order.MOVE:
				break
			formation.advance(DT, _terrain.can_move)
			frames += 1
		if formation.order != Battle.Order.HOLD or formation.position != formation.destination:
			_fail("Normal march could not reach the edge-route waypoint %s." % EDGE_ROUTE[i])
			return -1.0
	return frames * DT


func _test_geography() -> bool:
	for pair: Array in [
		["MarchLookout", "CoveredTrackHold"], ["MarchLookout", "SheepPinch"],
		["MarchMountedReserve", "PostRoadFork"], ["RoadScreen", "WithdrawalRally"],
		["ScoutScreenBase", "MarchLookout"],
	]:
		if _visible(pair[0], pair[1]):
			_fail("Missing blocking terrain between %s and %s." % [pair])
			return false
	for pair: Array in [
		["HighBankScout", "MarchLookout"], ["MarchLookout", "TrackEmergence"],
		["MarchLookout", "OpenRoadBrace"], ["ReserveReveal", "PostRoadFork"],
	]:
		if not _visible(pair[0], pair[1]):
			_fail("Required warning or brace sight is blocked: %s." % [pair])
			return false
	if _points.CoveredTrackHold.y > _points.OpenRoadBrace.y - 3.5 or _points.HighBankScout.y < _points.MarchLookout.y + 2.5:
		_fail("The sunken foot route and high lookout must retain physical height differences.")
		return false
	if not _zones.has("KeeperOccupation") or not _zones.KeeperOccupation.has_point(_points.WritHandover + Vector3.UP) 		or not _zones.KeeperOccupation.has_point(_points.Keeper + Vector3.UP) 		or _zones.KeeperOccupation.has_point(_points.WithdrawalRally + Vector3.UP) 		or _points.Keeper.distance_to(_points.WritHandover) < 3.0:
		_fail("Keeper, handover and withdrawal must be distinct; occupation is post-local only.")
		return false

	# Wider mounted proxy is an authoring envelope, not a statement about final roster rules.
	var body := BoxShape3D.new()
	body.size = Vector3(5.6, 2.4, 6.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.collision_mask = 1
	var floors: Array[RID] = []
	for child in _map.find_children("*", "StaticBody3D"):
		var terrain_body := child as StaticBody3D
		if terrain_body.collision_layer & Terrain.WALKABLE_MASK:
			floors.append(terrain_body.get_rid())
	query.exclude = floors
	if _fits_mount(query, _points.SheepPinch, Vector3.RIGHT):
		_fail("The sheep-track pinch now admits a broad mounted formation.")
		return false
	for path: Array in [RESERVE, CHARGE]:
		for i in range(1, path.size()):
			var a := _points[path[i - 1]]
			var b := _points[path[i]]
			var count := maxi(1, ceili(a.distance_to(b) / 0.75))
			var direction := a.direction_to(b)
			for step in range(count + 1):
				var center := a.lerp(b, float(step) / count)
				if not _fits_mount(query, center, direction) or not _mounted_floor(center, direction):
					_fail("Mounted envelope is obstructed between %s and %s at %s." % [path[i - 1], path[i], center])
					return false
			if i + 1 < path.size():
				var next := b.direction_to(_points[path[i + 1]])
				for step in range(1, 6):
					var turn := direction.slerp(next, step / 6.0)
					if not _fits_mount(query, b, turn) or not _mounted_floor(b, turn):
						_fail("Mounted turning footprint is blocked at %s." % path[i])
						return false
	return true


func _mounted_floor(point: Vector3, forward: Vector3) -> bool:
	var side := forward.cross(Vector3.UP)
	for a: float in [-2.7, 2.7]:
		for b: float in [-2.6, 2.6]:
			if absf(_terrain.ground_height(_xz(point + a * forward + b * side)) - point.y) > 0.28:
				return false
	return true


func _fits_mount(query: PhysicsShapeQueryParameters3D, point: Vector3, direction: Vector3) -> bool:
	var yaw := atan2(direction.x, direction.z)
	query.transform = _map.global_transform * Transform3D(Basis(Vector3.UP, yaw), point + Vector3.UP * 1.24)
	return _space.intersect_shape(query, 1).is_empty()


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
