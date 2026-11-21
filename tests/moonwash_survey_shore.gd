extends SceneTree

const MAP := preload("res://game/battlefields/moonwash_survey_shore.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const EDGE_ROUTE := [
	"WestMarchEdge", "WestCoastLane", "InlandJunction", "MidCoastLane",
	"HeadlandRoadFork", "WestRampBypass", "EastRampBypass", "FarCoastLane", "EastMarchEdge",
]
const BEACH_ROUTE := ["FishingInlet", "InletBeachTurn", "BeachSignal"]
const HEADLAND_ROUTE := [
	"FishingInlet", "InletBacktrack", "HeadlandInlandCut", "HeadlandLandwardTurn",
	"HeadlandRampFoot", "HeadlandRampTop", "HeadlandApron", "HighGuard", "HeadlandSignal",
]
const BOAT_LOOP := [
	"WestBlindPass", "WestRound", "BeachApproach", "BeachHold", "EastBlindPass", "ShoalReturnBend",
	"HeadlandApproach", "HeadlandHold", "EastOuterTurn", "OuterEast", "OuterWest", "WestBlindPass",
]
const PATHS := {
	"Ilyra to the coast": ["Ilyra", "StoneTrailTurn", "AncestralStone", "StoneExit", "InletTrailTurn", "FishingInlet"],
	"Short beach signal": BEACH_ROUTE,
	"Long headland signal": HEADLAND_ROUTE,
	"Beach detachment": ["ShoreDetachment", "InlandJunction", "MidCoastLane", "InletFork", "InletBacktrack", "BeachGuard", "BeachSignal"],
	"High guard": ["ShoreDetachment", "InlandJunction", "MidCoastLane", "HeadlandRoadFork", "HeadlandLandwardTurn", "HeadlandRampFoot", "HeadlandRampTop", "HeadlandApron", "HighGuard"],
	"Beach landing crews": ["LandingCrew", "LandingLine", "LandingWarning", "BeachSignal"],
	"Landward pressure": ["HeadlandPressure", "HeadlandReserveTurn", "HeadlandGuard", "HeadlandRampFoot", "HeadlandRampTop"],
}

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _points: Dictionary[String, Vector3] = {}
var _boat_points: Dictionary[String, Vector3] = {}


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
		if marker.get_parent().name == &"BoatRoute":
			_boat_points[marker.name] = point
		else:
			_points[marker.name] = point
			var xz := _xz(point)
			if absf(_terrain.ground_height(xz) - point.y) > 0.04 or not _terrain.can_move(xz, xz + Vector2(0.005, 0.005), false):
				_fail("Foot marker %s is blocked or unsupported." % marker.name)
				return

	for label: String in PATHS:
		if _run_path(label, PATHS[label]) < 0.0:
			return
	var beach_meters := _run_path("Beach options", BEACH_ROUTE)
	var headland_meters := _run_path("Headland options", HEADLAND_ROUTE)
	var water_meters := _test_cutter()
	if beach_meters < 0.0 or headland_meters < beach_meters + 55.0 or water_meters < 0.0:
		_fail("Signal options lost distinct physical distances or the cutter loop is invalid.")
		return
	if not _test_geography():
		return
	var edge_distance := _run_path("Normal edge-to-edge movement", EDGE_ROUTE)
	if edge_distance < 0.0:
		return
	var march_seconds := _time_edge_march()
	if march_seconds < 100.0 or march_seconds > 120.0:
		_fail("Representative formation march must stay near the provisional 110 s class.")
		return
	print("Verified %d foot markers, 7 hero/formation routes, 2 distinct occlusions and %d cutter markers. Signal approaches %.0f/%.0f m; loop %.0f m. Edge: %.0f m / %.1f s." % [
		_points.size(), _boat_points.size(), beach_meters, headland_meters, water_meters, edge_distance, march_seconds,
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


func _test_cutter() -> float:
	# Swept 5 x 12 m proxy at 1.25 m draft; no boat controller or water simulation.
	for label: String in BOAT_LOOP:
		if not _boat_points.has(label) or not is_zero_approx(_boat_points[label].y):
			_fail("Missing or off waterline cutter marker: %s." % label)
			return -1.0
	# The proxy occupies all space from 1.25 m below water to 1 m above it.
	var hull := BoxShape3D.new()
	hull.size = Vector3(5.0, 2.25, 12.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	query.shape = hull
	var total := 0.0
	for i in range(1, BOAT_LOOP.size()):
		var start := _boat_points[BOAT_LOOP[i - 1]]
		var finish := _boat_points[BOAT_LOOP[i]]
		var distance := start.distance_to(finish)
		total += distance
		var forward := start.direction_to(finish)
		var heading := atan2(forward.x, forward.z)
		var count := ceili(distance / 1.5)
		for step in range(count + 1):
			var center := start.lerp(finish, float(step) / count)
			if not _hull_clear(query, center, heading):
				_fail("Cutter draft clearance blocked on %s to %s near %s." % [BOAT_LOOP[i - 1], BOAT_LOOP[i], center])
				return -1.0
		var next := _boat_points[BOAT_LOOP[(i % (BOAT_LOOP.size() - 1)) + 1]]
		var next_heading := atan2(next.x - finish.x, next.z - finish.z)
		for step in range(1, 8):
			if not _hull_clear(query, finish, lerp_angle(heading, next_heading, step / 8.0)):
				_fail("Cutter cannot swing its nominal hull at %s." % BOAT_LOOP[i])
				return -1.0
	if _ray(Vector3(-20, -1.0, 50), Vector3(29, -1.0, 50)).is_empty():
		_fail("Shoal is no longer a physical obstacle to a straight cutter shortcut.")
		return -1.0
	return total


func _hull_clear(query: PhysicsShapeQueryParameters3D, point: Vector3, heading: float) -> bool:
	query.transform = _map.global_transform * Transform3D(Basis(Vector3.UP, heading), point - Vector3.UP * 0.125)
	return _space.intersect_shape(query, 1).is_empty()


func _test_geography() -> bool:
	for pair: Array in [["BeachSignal", "BeachApproach"], ["BeachSignal", "BeachHold"],
		["HeadlandSignal", "HeadlandApproach"], ["HeadlandSignal", "HeadlandHold"],
	]:
		if not _signal_ray(pair[0], pair[1]).is_empty():
			_fail("Required cutter hold is not visible from the matching site: %s." % [pair])
			return false
	for pair: Array in [
		["BeachSignal", "WestBlindPass", "WestHeadland"],
		["HeadlandSignal", "EastBlindPass", "EastHeadland"],
	]:
		var cast := _signal_ray(pair[0], pair[1])
		var blocker := cast.get("collider") as StaticBody3D
		if blocker == null or blocker.name != pair[2]:
			_fail("Signal requires a physical headland occlusion: %s; saw %s." % [pair, blocker.name if blocker != null else "open water"])
			return false
	var landing_ray := _ray(_points.LandingWarning + Vector3.UP * 1.6, _points.BeachSignal + Vector3.UP * 1.6)
	var high_ray := _ray(_points.LandingWarning + Vector3.UP * 1.6, _points.HighGuard + Vector3.UP * 1.6)
	if not landing_ray.is_empty() or high_ray.is_empty():
		_fail("Landing pressure needs a direct beach lane without equivalent exposure on the high apron.")
		return false
	if _points.HeadlandSignal.y - _points.BeachSignal.y < 5.0 or _terrain.can_move(Vector2(64, 9), Vector2(67, 9), false):
		_fail("The safer headland needs its own raised access and no walk-up from the beach side.")
		return false
	if _terrain.can_move(Vector2(0, 13), Vector2(0, 16), true):
		_fail("Foot formations must not walk into the cutter's ocean domain.")
		return false
	return true


func _signal_ray(site: String, cutter_point: String) -> Dictionary:
	return _ray(_points[site] + Vector3.UP * 2.6, _boat_points[cutter_point] + Vector3.UP * 2.5)


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


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(_map.to_global(from), _map.to_global(to), 1))


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
