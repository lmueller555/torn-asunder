extends SceneTree

const MAP := preload("res://game/battlefields/year_one_mine_campaign.tscn")
const POCKET := preload("res://game/battlefields/year_one_mine.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")

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
		var current := _map.get_node_or_null(pocket.get_path_to(old))
		if not current is Marker3D:
			pocket.free()
			_fail("Missing inherited pocket marker %s." % old.name)
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

	print("Verified %d markers, %d hero/formation routes, and solid terrain. Delivery %.0f m, evacuation %.0f m." % [
		_markers.size(), PATHS.size(), distances["Godbridle delivery"], distances["Miner evacuation"],
	])
	quit()


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
