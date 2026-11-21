extends SceneTree

const MAP := preload("res://game/battlefields/spanwater_lock_campaign.tscn")
const POCKET := preload("res://game/battlefields/spanwater_lock.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const PATHS := {
	"Orc causeway and wheel": [
		"OrcVanguard", "UpstreamApproach", "ServiceCauseway", "LockApron", "SpillwayWheel",
	],
	"Orc support": ["OrcSupport", "ServiceCauseway", "LockApron"],
	"Lower-company withdrawal": ["SpillwayWheel", "LockApron", "ServiceCauseway", "UpstreamApproach", "OrcWithdrawalExit"],
	"March counterattack": ["MarchDefenders", "MarchCounterattackApproach", "SpillwayWheel"],
	"Covered March reserve": [
		"MarchReserveAssembly", "MarchScreenTurn", "MarchDefenders", "MarchCounterattackApproach",
	],
	"High-bank extraction": ["SpillwayWheel", "MarchCounterattackApproach", "HighBankStaging", "HighBank", "HighBankExit"],
	"Lock stairs": ["LockStairFoot", "LockStairTop", "LockApron"],
	"Pre-release ford": ["HighBankStaging", "LowCrossingNorth", "LowCrossing", "LowCrossingSouth"],
	"Approach to the non-objective sea gate": ["LowCrossingSouth", "SeaGate"],
	"Raised Dryad bypass": [
		"DryadCrew", "FeederPathWest", "FeederInletRack", "FeederMaintenanceBend", "FeederPathEast", "TownGauge",
	],
	"Dryad guard": ["DryadGuard", "FeederPathWest"],
	"Elf marines": ["ElfMarines", "LandingApproach", "LandingFoot", "LowLanding"],
	"Elf near households": ["HouseholdsNear", "LandingApproach", "LandingFoot", "LowLanding"],
	"Elf far households": ["HouseholdsFar", "HouseholdScreenTurn", "LandingApproach", "LandingFoot", "LowLanding"],
}
const BOAT_ROUTE := ["UpstreamHold", "OutflowHold", "BoatBerth", "BoatExit"]

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _foot: Dictionary[String, Vector3] = {}
var _boat: Dictionary[String, Vector3] = {}
var _phase: Dictionary[String, AABB] = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_map = MAP.instantiate() as Node3D
	root.add_child(_map)
	_map.position = Vector3(17, 2, -15)
	var pocket := POCKET.instantiate()
	for old: Node in pocket.find_children("*", "Marker3D"):
		var path := pocket.get_path_to(old)
		if not _map.get_node_or_null(path) is Marker3D:
			pocket.free()
			_fail("Missing inherited Spanwater Marker3D at %s." % path)
			return
	pocket.free()
	await physics_frame
	await physics_frame
	_terrain = Terrain.new(_map)
	_space = _map.get_world_3d().direct_space_state

	for child: Node in _map.find_children("*", "Marker3D"):
		var marker := child as Marker3D
		var local := _map.to_local(marker.global_position)
		match marker.get_parent().name:
			&"BoatRoute": _boat[marker.name] = local
			&"PhaseZones":
				var box: Variant = marker.get_meta(&"box_size", Vector3.ZERO)
				if not box is Vector3 or minf(minf(box.x, box.y), box.z) <= 0.0:
					_fail("Missing a positive phase footprint at %s." % marker.name)
					return
				_phase[marker.name] = AABB(local - box * 0.5, box)
			_:
				_foot[marker.name] = local
				var xz := _xz(local)
				if absf(_terrain.ground_height(xz) - local.y) > 0.04 or not _terrain.can_move(xz, xz + Vector2(0.005, 0.005), false):
					_fail("Foot marker %s is blocked or unsupported." % marker.name)
					return

	var distance: Dictionary[String, float] = {}
	for path: String in PATHS:
		var ids: Array = PATHS[path]
		var total := 0.0
		for id: String in ids:
			if not _foot.has(id):
				_fail("Missing %s from %s." % [id, path])
				return
		for i in range(1, ids.size()):
			var first := _foot[ids[i - 1]]
			var last := _foot[ids[i]]
			total += first.distance_to(last)
			if not _walk(first, last):
				_fail("The %s route is blocked between %s and %s." % [path, ids[i - 1], ids[i]])
				return
		distance[path] = total

	if distance["High-bank extraction"] < 180.0 or distance["Raised Dryad bypass"] < 260.0 \
		or distance["Elf far households"] < 115.0 or distance["Lower-company withdrawal"] < 120.0:
		_fail("The layout lost its campaign separation between decisions.")
		return
	if not _test_boat_and_release() or not _test_landmarks():
		return
	print("Verified %d foot markers and %d terrain-probed paths; 4 boat nodes, 2 inert phase footprints, and a screened reserve. High exit %.0f m, feeder %.0f m." % [
		_foot.size(), PATHS.size(), distance["High-bank extraction"], distance["Raised Dryad bypass"],
	])
	quit()


func _test_boat_and_release() -> bool:
	var hull := CapsuleShape3D.new()
	hull.radius = 1.2
	hull.height = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	query.shape = hull
	for i in range(1, BOAT_ROUTE.size()):
		var a := _boat[BOAT_ROUTE[i - 1]]
		var b := _boat[BOAT_ROUTE[i]]
		var samples := ceili(a.distance_to(b) / 0.35)
		for j in range(samples + 1):
			query.transform = Transform3D(Basis.IDENTITY, _map.to_global(a.lerp(b, float(j) / samples) + Vector3.UP * 1.03))
			if not _space.intersect_shape(query, 1).is_empty():
				_fail("A nominal launch footprint is blocked between %s and %s." % [BOAT_ROUTE[i - 1], BOAT_ROUTE[i]])
				return false

	var low := _phase.LowCrossingClosure
	var landing := _phase.LandingClosure
	if low.intersects(landing) or not low.grow(0.02).has_point(_foot.ReleaseSweepEnd) \
		or not landing.grow(0.02).has_point(_foot.LowLanding):
		_fail("The ford and landing have independent phase footprints centered at their relevant low level.")
		return false
	for z in [-6.0, 0.0, 6.0]:
		var height := Vector3(0, 0.65, z)
		if not _ray(_foot.ReleaseSweepStart + height, _foot.ReleaseSweepEnd + height).is_empty():
			_fail("The 12 m release corridor is obstructed on the dry riverbed.")
			return false
	return true


func _test_landmarks() -> bool:
	for pair: Array in [
		[Vector3(-31.5, 1, 48), Vector3(-31.5, 1, 61)], # closed sea gate, separate from outlet
		[Vector3(-108, 1, -42), Vector3(-108, 6, -42)], # real high causeway deck
		[Vector3(-54, 3, -21), Vector3(-65, 3, -21)], # solid infantry stair screen
		[_foot.MarchReserveAssembly + Vector3.UP * 1.6, _foot.SpillwayWheel + Vector3.UP * 1.6], # blind reserve
	]:
		if _ray(pair[0], pair[1]).is_empty():
			_fail("Missing solid Spanwater cover at %s -> %s." % pair)
			return false
	if not _ray(Vector3(-108, 2, -19.5), Vector3(-108, 2, -70)).is_empty():
		_fail("The raised service bridge should leave the feeder inlet unblocked underneath.")
		return false
	if not _ray(_foot.MarchCounterattackApproach + Vector3.UP * 1.6, _foot.SpillwayWheel + Vector3.UP * 1.6).is_empty():
		_fail("The counterattack must emerge from blind cover onto the exposed apron.")
		return false
	return true


func _walk(a: Vector3, b: Vector3) -> bool:
	var from := _xz(a)
	var to := _xz(b)
	var previous := from
	var samples := maxi(1, ceili(from.distance_to(to) / 0.24))
	for i in range(1, samples + 1):
		var next := from.lerp(to, float(i) / samples)
		if not _terrain.can_move(previous, next, false) or not _terrain.can_move(previous, next, true):
			print("Terrain blocked at local XZ ", next)
			return false
		previous = next
	return true


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(_map.to_global(a), _map.to_global(b), 1))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
