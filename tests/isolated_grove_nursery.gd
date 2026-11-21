extends SceneTree

const MAP := preload("res://game/battlefields/isolated_grove_nursery.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const EDGE_ROUTE := ["WestMarchEdge", "GroveAssembly", "YardExit", "RaisedRoadWest", "RoadScreenHold",
	"RaisedRoadMiddle", "RaisedRoadEast", "NurseryApproach", "EastMarchEdge"]
const SLED_ROUTE := [
	"RootSled", "RootBallLoad", "LoadingYard", "YardExit", "RaisedRoadWest", "RoadScreenHold",
	"RaisedRoadMiddle", "RaisedRoadEast", "NurseryApproach", "TransplantBed",
]
const LOW_TRACK := [
	"TrackEastFold", "TrackReedBend", "TrackLowTurn", "TrackPinchEast", "TrackPinchWest",
	"TrackWestMouth", "LoadingScreenFoot", "LoadingScreenTop", "LoadingScreenHold",
]
const PATHS := {
	"Grove consultation and loading": ["Neris", "GroveAssembly", "GroveEnvoy", "VolunteerCall", "RootBallLoad"],
	"Volunteer crew to the yard": ["VolunteerCrew", "VolunteerCall", "RootBallLoad", "LoadingYard"],
	"Guard holds road": ["LoadingGuard", "LoadingYard", "YardExit", "RaisedRoadWest", "RoadScreenHold"],
	"Track screen reaches the lookout": ["TrackScreen", "LoadingScreenHold", "TrackOverlook"],
	"First forager approach": ["ForagerVanguard"] + LOW_TRACK,
	"Reserve forager merges under cover": ["ForagerReserve", "TrackEastFold", "TrackReedBend"],
	"Late guard approach to nursery": ["RaisedRoadEast", "NurseryApproach", "TransplantBed"],
}
const SLED_WIDTH := 4.8
const SLED_LENGTH := 7.5

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _points: Dictionary[String, Vector3] = {}
var _zones: Dictionary[String, AABB] = {}
var _sled := PhysicsShapeQueryParameters3D.new()


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
	var sled_shape := BoxShape3D.new()
	sled_shape.size = Vector3(SLED_WIDTH, 1.75, SLED_LENGTH)
	_sled.shape = sled_shape
	_sled.collision_mask = 1
	var floor_rids: Array[RID] = []
	for floor_node: Node in _map.find_children("*", "StaticBody3D"):
		var floor_body := floor_node as StaticBody3D
		if floor_body.collision_layer & Terrain.WALKABLE_MASK:
			floor_rids.append(floor_body.get_rid())
	_sled.exclude = floor_rids

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

	var road := _run_path("Root-ball transport road", SLED_ROUTE, true)
	if road < 0.0:
		return
	var track := 0.0
	for name: String in PATHS:
		var distance := _run_path(name, PATHS[name], false)
		if distance < 0.0:
			return
		if name == "First forager approach":
			track = distance
	if road < 245.0 or track < 212.0:
		_fail("The grove and nursery should remain distinctly spaced tactical sectors.")
		return
	if not _test_geography():
		return
	var edge_distance := _run_path("Edge-to-edge movement", EDGE_ROUTE, false)
	if edge_distance < 0.0:
		return
	var march_seconds := _time_edge_march()
	if march_seconds < 0.0:
		return
	print("Verified %d markers, 7 actor paths, 4.8 × 7.5 m sled over %.0f m, and %.0f m screened track. Edge: %.0f m / %.1f s." % [
		_points.size(), road, track, edge_distance, march_seconds,
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
	var choke := Vector2(-44, 59)
	var ramp := Vector2(-103, 55)
	if _sled_fits(choke, Vector2.RIGHT) or _sled_fits(ramp, Vector2.UP):
		_fail("The low track and grove climb must remain too narrow for the loaded sled.")
		return false
	if _points.RaisedRoadMiddle.y - _points.TrackLowTurn.y < 5.0:
		_fail("The raised road and physically sunken track have lost their separation.")
		return false
	for pair: Array in [["TrackReedBend", "LoadingYard"], ["ForagerVanguard", "RootBallLoad"]]:
		if _visible(pair[0], pair[1]):
			_fail("Missing solid screen along the forager approach: %s." % [pair])
			return false
	for pair: Array in [["LoadingScreenHold", "LoadingScreenFoot"], ["TrackOverlook", "TrackWestMouth"]]:
		if not _visible(pair[0], pair[1]):
			_fail("The defensive lookout has no sight of its approach: %s." % [pair])
			return false
	for id: String in ["LoadingZone", "RaisedRoadScreen", "TrackResponseZone", "NurseryReceiver"]:
		if not _zones.has(id):
			_fail("Missing marker-only footprint %s." % id)
			return false
	if _zones.LoadingZone.intersects(_zones.NurseryReceiver) 		or not _zones.LoadingZone.has_point(_points.RootBallLoad + Vector3.UP) 		or not _zones.NurseryReceiver.has_point(_points.TransplantBed + Vector3.UP) 		or _zones.NurseryReceiver.has_point(_points.ExistingWell + Vector3.UP):
		_fail("Root-ball loading, transplant, and the existing well must be distinct.")
		return false
	if _map.get_node_or_null("Markers/Objectives/ExistingWell") != null:
		_fail("The existing town well is a landmark, not an objective.")
		return false
	return true


func _run_path(name: String, ids: Array, sled: bool) -> float:
	var total := 0.0
	for id: String in ids:
		if not _points.has(id):
			_fail("Missing %s from %s." % [id, name])
			return -1.0
	for i in range(1, ids.size()):
		var a := _points[ids[i - 1]]
		var b := _points[ids[i]]
		total += a.distance_to(b)
		if not _walk(a, b, sled):
			_fail("%s is blocked between %s and %s." % [name, ids[i - 1], ids[i]])
			return -1.0
	return total


func _walk(a: Vector3, b: Vector3, sled: bool) -> bool:
	var from := _xz(a)
	var to := _xz(b)
	var previous := from
	var heading := (to - from).normalized()
	var count := maxi(1, ceili(from.distance_to(to) / 0.22))
	for i in range(count + 1):
		var next := from.lerp(to, float(i) / count)
		if not _terrain.can_move(previous, next, false) or not _terrain.can_move(previous, next, true) \
			or sled and not _sled_fits(next, heading):
			print("Terrain blocked near ", next)
			return false
		previous = next
	return true


func _sled_fits(point: Vector2, heading: Vector2) -> bool:
	if heading.is_zero_approx():
		return true
	var floor := _terrain.ground_height(point)
	var lateral := Vector2(-heading.y, heading.x)
	for axle in [-2.85, 2.85]:
		for wheel in [-2.0, 2.0]:
			if absf(_terrain.ground_height(point + heading * axle + lateral * wheel) - floor) > 0.52:
				return false
	var basis := Basis(Vector3.UP, atan2(-heading.x, -heading.y))
	_sled.transform = Transform3D(basis, _map.to_global(Vector3(point.x, floor + 1.02, point.y)))
	return _space.intersect_shape(_sled, 1).is_empty()


func _visible(from: String, to: String) -> bool:
	var start := _map.to_global(_points[from] + Vector3.UP * 1.6)
	var end := _map.to_global(_points[to] + Vector3.UP * 1.6)
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1)).is_empty()


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
