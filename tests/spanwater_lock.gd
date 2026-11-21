extends SceneTree

const MAP := preload("res://game/battlefields/spanwater_lock.tscn")
const MARKERS := {
	"Spawns": [
		"OrcVanguard", "OrcSupport", "MarchDefenders", "DryadCrew", "DryadGuard",
		"ElfMarines", "HouseholdsNear", "HouseholdsFar",
	],
	"Routes": [
		"UpstreamApproach", "ServiceCauseway", "LockApron", "LockStairFoot", "LockStairTop",
		"HighBank", "LowCrossingNorth", "LowCrossing", "LowCrossingSouth",
		"FeederPathWest", "FeederPathEast", "LandingApproach", "LandingFoot",
	],
	"Objectives": [
		"SpillwayWheel", "SeaGate", "HighBankExit", "FeederInletRack", "TownGauge", "LowLanding",
	],
	"BoatRoute": ["UpstreamHold", "OutflowHold", "BoatBerth", "BoatExit"],
	"PhaseZones": ["LowCrossingClosure", "LandingClosure"],
}
const PATHS := {
	"Orc high-bank approach and exit": [
		"OrcVanguard", "UpstreamApproach", "ServiceCauseway", "LockApron", "SpillwayWheel",
		"LockApron", "HighBank", "HighBankExit",
	],
	"Orc support": ["OrcSupport", "ServiceCauseway", "LockApron"],
	"March counterattack": ["MarchDefenders", "LockApron", "SpillwayWheel"],
	"Infantry stair": ["LockStairFoot", "LockStairTop", "LockApron"],
	"Low crossing before release": ["HighBank", "LowCrossingNorth", "LowCrossing", "LowCrossingSouth"],
	"Dryad raised feeder path": [
		"DryadCrew", "FeederPathWest", "FeederInletRack", "FeederPathEast", "TownGauge",
	],
	"Dryad guard": ["DryadGuard", "FeederPathWest"],
	"Elf marines": ["ElfMarines", "HouseholdsNear", "LandingApproach", "LandingFoot"],
	"Sea gate landmark": ["LowCrossingSouth", "SeaGate"],
	"Elf near households": ["HouseholdsNear", "LandingApproach", "LandingFoot", "LowLanding"],
	"Elf far households": ["HouseholdsFar", "LandingApproach", "LandingFoot", "LowLanding"],
}

var _spots: Dictionary[String, Vector3] = {}
var _boat: Dictionary[String, Vector3] = {}
var _space: PhysicsDirectSpaceState3D
var _probe := PhysicsShapeQueryParameters3D.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := MAP.instantiate() as Node3D
	root.add_child(map)
	# Validate local marker paths even when the mission translates the map instance.
	map.position = Vector3(14, 7, -9)
	for group: String in MARKERS:
		for id: String in MARKERS[group]:
			var marker := map.get_node_or_null("Markers/%s/%s" % [group, id]) as Marker3D
			if marker == null:
				_fail("Missing Marker3D: %s/%s" % [group, id])
				return
			if group == "PhaseZones":
				var zone_size: Variant = marker.get_meta(&"box_size", Vector3.ZERO)
				if not zone_size is Vector3 or zone_size.x <= 0.0 or zone_size.y <= 0.0 or zone_size.z <= 0.0:
					_fail("Phase-zone marker %s is missing a positive box_size." % id)
					return
			elif group == "BoatRoute":
				_boat[id] = marker.global_position
			else:
				_spots[id] = marker.global_position

	var body := CapsuleShape3D.new()
	body.radius = 0.45
	body.height = 1.8
	_probe.shape = body
	_probe.collision_mask = 1
	await physics_frame
	await physics_frame
	_space = map.get_world_3d().direct_space_state

	for id: String in _spots:
		var feet := _spots[id]
		var floor_hit := _floor_at(feet)
		if floor_hit.is_empty() or absf(floor_hit.position.y - feet.y) > 0.025:
			_fail("Marker %s is not placed at foot level." % id)
			return
		if not _clear(feet):
			_fail("Standing capsule overlaps geometry at marker %s." % id)
			return

	for path: String in PATHS:
		var ids: Array = PATHS[path]
		for i in range(1, ids.size()):
			if not _walkable(_spots[ids[i - 1]], _spots[ids[i]]):
				_fail("%s is blocked between %s and %s." % [path, ids[i - 1], ids[i]])
				return

	# Waterline paths are for authored launch positions, not simulated water.
	var boat_ids: Array = MARKERS.BoatRoute
	for i in range(1, boat_ids.size()):
		for offset in [-0.75, 0.0, 0.75]:
			var beam := Vector3(0, 0, offset)
			if not _ray(_boat[boat_ids[i - 1]] + beam, _boat[boat_ids[i]] + beam).is_empty():
				_fail("The boat lane is obstructed between %s and %s." % [boat_ids[i - 1], boat_ids[i]])
				return

	# Physical gate, lock wall, and the narrower stair must not turn into drawn-only dressing.
	for pair: Array in [
		[Vector3(2, 1, 14), Vector3(2, 1, 25)],
		[Vector3(-9, 2, 1), Vector3(-9, 2, -10)],
		[Vector3(-38, 1, -14), Vector3(-38, 3.25, -14)],
		[Vector3(-3, 2.2, -10), Vector3(-6, 2.2, -10)],
		[Vector3(36, 1, 15), Vector3(27, 1, 15)],
	]:
		if _ray(map.to_global(pair[0]), map.to_global(pair[1])).is_empty():
			_fail("Missing solid lock geometry between %s and %s." % [pair[0], pair[1]])
			return

	if not _ray(map.to_global(Vector3(-38, 1, -7.5)), map.to_global(Vector3(-38, 1, -24))).is_empty():
		_fail("The service bridge should cross over, not fill, the feeder's inlet.")
		return

	# Spawns and foot markers are intentionally separate from boat and phase metadata.
	if not (_spots.FeederInletRack.z < _spots.SpillwayWheel.z and _spots.LowLanding.z > _spots.SpillwayWheel.z):
		_fail("The feeder and landing should occupy different banks from the spillway control.")
		return
	if absf(_spots.LowCrossing.y - _spots.HighBank.y) < 2.5:
		_fail("The deck and old riverbed crossing no longer read as separate levels.")
		return

	print("Verified %d foot markers, %d walks, four boat markers, two inert phase zones and lock collision." % [
		_spots.size(), PATHS.size(),
	])
	quit()


func _walkable(from: Vector3, to: Vector3) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / 0.3))
	var previous_y := from.y
	for i in range(samples + 1):
		var feet := from.lerp(to, float(i) / samples)
		var hit := _floor_at(feet)
		if hit.is_empty():
			return false
		feet.y = hit.position.y
		var normal: Vector3 = hit.normal
		if normal.dot(Vector3.UP) < cos(deg_to_rad(24)) or absf(feet.y - previous_y) > 0.16:
			return false
		if not _clear(feet):
			return false
		previous_y = feet.y
	return is_equal_approx(previous_y, to.y) or absf(previous_y - to.y) <= 0.025


func _floor_at(feet: Vector3) -> Dictionary:
	# Support may curve away from the segment joining two markers at a ramp toe.
	return _ray(feet + Vector3.UP * 2.1, feet - Vector3.UP * 2.5)


func _clear(feet: Vector3) -> bool:
	# Leave a small contact tolerance for the curved capsule base on a slope.
	_probe.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.96)
	return _space.intersect_shape(_probe, 1).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	return _space.intersect_ray(ray)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
