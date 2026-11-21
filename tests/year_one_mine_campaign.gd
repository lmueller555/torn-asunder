extends SceneTree

const MAP := preload("res://game/battlefields/year_one_mine_campaign.tscn")
const POCKET := preload("res://game/battlefields/year_one_mine.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const MarchScale := preload("res://game/battlefield/battlefield_march_scale.gd")

const CAMPAIGN_BOUNDS := Rect2(-160, -108, 320, 224)
const MARCH_DT := 1.0 / 60.0
const MARCH_MAX_TICKS := 180 * 60
# Supported feet of the valley crags, not the road exit or playable-window clamp.
const WEST_RIM := Vector2(-152, -17)
const EAST_RIM := Vector2(157, -30)
const MARCH_KNOTS := [
	"WestAssembly", "QuarryTurn", "RoadWest", "RoadJunction", "RoadCut", "EastPass", "PassRelease",
]

const PATHS := {
	"Escort approach": ["HumanEscort", "WestAssembly", "QuarryTurn", "RoadWest", "MineYard", "GodbridlePickup"],
	"Godbridle delivery": [
		"GodbridlePickup", "MineYard", "RoadWest", "RoadJunction", "RoadCut",
		"EastPass", "PassRelease", "GodbridleExit",
	],
	"Escorting infantry": ["HumanInfantry", "WestAssembly", "QuarryTurn", "RoadWest", "RoadJunction"],
	"Human ridge approach": ["HumanArchers", "RidgeWestApproach", "RidgeWestFoot", "RidgeWestCrest", "RidgeOverlook"],
	"Orc intercept": [
		"OrcIntercept", "InterceptFork", "InterceptMouth", "InterceptRoadMerge", "EastPass",
	],
	"Orc reserve": ["OrcIntercept", "EastReserve", "InterceptMouth"],
	"Road guard approach": ["RoadCut", "MaraRoadGuard", "EastPass"],
	"Orc reach to the mine yard": [
		"OrcCrewParty", "OrcApproach", "RidgeEastFoot", "RidgeEastCrest", "RidgeOverlook",
		"RidgeWestCrest", "RidgeWestFoot", "RidgeWestApproach", "WestAssembly", "QuarryTurn", "RoadWest", "MineYard",
	],
	"South flank": [
		"RoadJunction", "SouthReserve", "SouthTraverse", "SouthFlankCut", "PassFallback", "PassRelease",
	],
	"Druid guard": ["DruidGuard", "TunnelEntrance", "TunnelMidpoint"],
	"Miner evacuation": [
		"Miners", "MinerAssembly", "TunnelEntrance", "TunnelMidpoint",
		"TunnelExit", "EvacuationTurn", "EvacuationTrail", "MinerEvacuation",
	],
}
const VITAL_WIDTHS := {
	"RoadCut": 7.0, "EastPass": 6.0, "TunnelMidpoint": 6.0,
	"RidgeWestCrest": 6.0, "WestAssembly": 7.0, "SouthReserve": 7.0,
}

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _markers: Dictionary[String, Vector3] = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_map = MAP.instantiate() as Node3D
	root.add_child(_map)
	_map.position = Vector3(11, 3, -15)
	var pocket := POCKET.instantiate()
	for old: Node in pocket.find_children("*", "Marker3D"):
		var path := pocket.get_path_to(old)
		if not _map.get_node_or_null(path) is Marker3D:
			pocket.free()
			_fail("Missing inherited pocket Marker3D at %s." % path)
			return
	pocket.free()

	await physics_frame
	await physics_frame
	_terrain = Terrain.new(_map)
	_space = _map.get_world_3d().direct_space_state
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for child: Node in _map.find_children("*", "Marker3D"):
		var marker := child as Marker3D
		var point := _map.to_local(marker.global_position)
		_markers[marker.name] = point
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
		var xz := Vector2(point.x, point.z)
		if absf(_terrain.ground_height(xz) - point.y) > 0.04:
			_fail("Marker %s is not on its walkable layer." % marker.name)
			return
		if not _terrain.can_move(xz, xz + Vector2(0.005, 0.005), false):
			_fail("Marker %s is not clear for a hero." % marker.name)
			return
	if max_x - min_x < 290.0 or max_z - min_z < 160.0:
		_fail("The campaign layout lost the distance between its decision points.")
		return

	var distances: Dictionary[String, float] = {}
	for path: String in PATHS:
		var ids: Array = PATHS[path]
		var distance := 0.0
		for id: String in ids:
			if not _markers.has(id):
				_fail("Missing %s marker on %s." % [id, path])
				return
		for i in range(1, ids.size()):
			var a := _markers[ids[i - 1]]
			var b := _markers[ids[i]]
			distance += a.distance_to(b)
			if not _check_segment(a, b):
				_fail("%s is blocked between %s and %s." % [path, ids[i - 1], ids[i]])
				return
		distances[path] = distance
	if distances["Godbridle delivery"] < 220.0 or distances["Miner evacuation"] < 100.0:
		_fail("Escort or evacuation is no longer a multi-stage campaign route.")
		return

	# Sample across each local route pocket, perpendicular to typical movement.
	for id: String in VITAL_WIDTHS:
		var axis := Vector3.RIGHT if id == "TunnelMidpoint" else Vector3.BACK
		var half := axis * float(VITAL_WIDTHS[id]) / 2.0
		if not _check_segment(_markers[id] - half, _markers[id] + half):
			_fail("The advertised formation lane at %s is blocked." % id)
			return

	for pair: Array in [
		[Vector3(-63, 2, 75), Vector3(-63, 8, 75)],  # real tunnel roof
		[Vector3(-63, 2, 75), Vector3(-56, 2, 75)],  # real tunnel side
		[Vector3(96, 2, -15), Vector3(96, 2, -35)],  # north pass crag
		[Vector3(96, 2, -15), Vector3(96, 2, 12)],  # south pass crag
		[Vector3(-63, 1.7, 101), Vector3(-86, 1.7, 48)],  # evac hollow screened
	]:
		if _ray(pair[0], pair[1]).is_empty():
			_fail("Missing solid geometry at %s to %s." % pair)
			return
	if not _ray(Vector3(14, 11.7, -40), Vector3(43, 1.7, -2)).is_empty():
		_fail("The clear gap at RidgeOverlook should see the road.")
		return

	if not _measure_edge_march():
		return

	print("Verified %d markers, %d hero/formation routes, and solid terrain. Delivery %.0f m, evacuation %.0f m." % [
		_markers.size(), PATHS.size(), distances["Godbridle delivery"], distances["Miner evacuation"],
	])
	quit()


func _measure_edge_march() -> bool:
	for edge: Array in [
		[WEST_RIM, Vector2(-157, -17), Vector2(-157, -17)],
		[EAST_RIM, Vector2(159.5, -30), Vector2(163, -30)],
	]:
		var rim: Vector2 = edge[0]
		var outside: Vector2 = edge[1]
		var ray_end: Vector2 = edge[2]
		var hit: Dictionary = _ray(Vector3(rim.x, 0.7, rim.y), Vector3(ray_end.x, 0.7, ray_end.y))
		var crag := hit.get("collider") as StaticBody3D
		# The blocked destination is still inside the move clamp. A center-floor
		# hit at the east crag is insufficient: the formation footprint clips it.
		if not _supports_formation(rim) or _supports_formation(outside) \
				or not CAMPAIGN_BOUNDS.has_point(outside) or crag == null \
				or not String(crag.name).begins_with("ValleyEdge"):
			_fail("Measured Mine rim no longer meets the valley crag at %s." % rim)
			return false
		var probe := _march_battle(rim)
		probe.order_move(0, outside)
		for tick in range(ceili(rim.distance_to(outside) / Battle.FORMATION_SPEED / MARCH_DT) + 2):
			if probe.formations[0].order != Battle.Order.MOVE:
				break
			probe.step(MARCH_DT, Vector2.ZERO, _terrain.can_move)
		if probe.formations[0].order != Battle.Order.BLOCKED:
			_fail("Infantry can march through the Mine rim from %s toward %s." % [rim, outside])
			return false

	var route: Array[Vector2] = [WEST_RIM]
	for id: String in MARCH_KNOTS:
		var point := _markers[id]
		route.append(Vector2(point.x, point.z))
	route.append(EAST_RIM)
	if not _march_route(route, "west → east"):
		return false
	route.reverse()
	return _march_route(route, "east → west")


func _march_route(route: Array[Vector2], direction: String) -> bool:
	var battle := _march_battle(route[0])
	var infantry := battle.formations[0]
	var ticks := 0
	var distance := 0.0
	for i in range(1, route.size()):
		var destination := route[i]
		battle.order_move(0, destination)
		while infantry.order == Battle.Order.MOVE and ticks < MARCH_MAX_TICKS:
			var before := infantry.position
			battle.step(MARCH_DT, Vector2.ZERO, _terrain.can_move)
			distance += before.distance_to(infantry.position)
			ticks += 1
			if not _supports_formation(infantry.position):
				_fail("Mine march lost walkable formation clearance at %s." % infantry.position)
				return false
		if infantry.order != Battle.Order.HOLD or infantry.position != destination:
			_fail("Mine march %s could not reach %s; stopped at %s." % [direction, destination, infantry.position])
			return false
	var seconds := ticks * MARCH_DT
	if not MarchScale.within_target_band(seconds) or MarchScale.classify(seconds) != MarchScale.Tier.SMALL:
		_fail("Expected a Small Mine march %s; marched %.3f m in %.2f s." % [direction, distance, seconds])
		return false
	print("Year One Mine (%s): infantry marched %.3f m from %s to %s in %.2f s (%d ticks, Small)." % [
		direction, distance, route.front(), route.back(), seconds, ticks,
	])
	return true


func _march_battle(start: Vector2) -> Battle:
	var battle := Battle.new()
	battle.bounds = CAMPAIGN_BOUNDS
	battle.formations[0].position = start
	battle.formations[0].hold()
	return battle


func _supports_formation(point: Vector2) -> bool:
	var surface: Variant = _terrain.destination_from_ray(
		Vector3(point.x, 32.0, point.y), Vector3(point.x, -8.0, point.y)
	)
	return surface != null and _terrain.formation_fits_at(point)


func _check_segment(from: Vector3, to: Vector3) -> bool:
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var previous := start
	var steps := maxi(1, ceili(start.distance_to(end) / 0.25))
	for i in range(1, steps + 1):
		var sample := start.lerp(end, float(i) / steps)
		if not _terrain.can_move(previous, sample, false) or not _terrain.can_move(previous, sample, true):
			print("Blocked at local XZ ", sample, " height ", _terrain.ground_height(sample))
			return false
		previous = sample
	return true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_map.to_global(from), _map.to_global(to), 1)
	return _space.intersect_ray(query)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
