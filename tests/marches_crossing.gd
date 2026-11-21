extends SceneTree

const Crossing := preload("res://game/battlefields/marches_crossing.tscn")
const Preview := preload("res://tests/marches_crossing_preview.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const MarchScale := preload("res://game/battlefield/battlefield_march_scale.gd")
const MARCH_DT := 1.0 / 60.0

const SPAWNS := [
	"RoyalHero", "InfantryReserve", "EscortArchers", "SeedGrainCart", "BreadGrainCart",
	"RivalLancers", "FarBankArchers",
]
const BRIDGE_ROUTE := [
	"SeedGrainCart", "ReserveFork", "BridgeApproachWest", "BridgeWestBank",
	"BridgeDeck", "BridgeEastBank", "MillApproach", "SeedGrainMillYard",
]
const FORD_ROUTE := [
	"BreadGrainCart", "ReserveFork", "ShelteredTurn", "FordApproachWest", "FordWestBank",
	"FordShallows", "FordEastBank", "StoreApproach", "BreadGrainStoreYard",
]
const CHARGE_ROUTE := ["RivalLancers", "CavalryFormUp", "CavalryChargeLane", "CavalryIntercept"]
const OBJECTIVES := ["SeedGrainMillYard", "BreadGrainStoreYard"]
const CART_CLEARANCE := Vector3(2.75, 1.75, 4.2)

var _map: Node3D
var _terrain: Terrain
var _spots: Dictionary[String, Vector3] = {}
var _world: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_map = Crossing.instantiate()
	root.add_child(_map)
	_map.position = Vector3(13.0, 5.0, -21.0)
	_terrain = Terrain.new(_map)
	await physics_frame
	await physics_frame
	_world = _map.get_world_3d().direct_space_state
	var passed := _check_markers() and _check_lanes() and _check_sightlines() \
		and _check_boundaries() and _measure_edge_march()
	if passed:
		print("Marches Crossing: support, two cart-width deliveries, slower screened ford, reserve, open charge lane, LOS and valley limits verified.")
	quit(0 if passed else 1)


func _check_markers() -> bool:
	var paths := {
		"Spawns": SPAWNS,
		"Objectives": OBJECTIVES,
		"Routes": [
			"ReserveFork", "BridgeApproachWest", "BridgeWestBank", "BridgeDeck", "BridgeEastBank",
			"MillApproach", "ShelteredTurn", "FordApproachWest", "FordWestBank", "FordShallows",
			"FordEastBank", "StoreApproach", "CavalryFormUp", "CavalryChargeLane", "CavalryIntercept",
		],
	}
	for prefix: String in paths:
		for id: String in paths[prefix]:
			var marker := _map.get_node_or_null("Markers/%s/%s" % [prefix, id]) as Marker3D
			if not marker:
				return _fail("Missing marker: %s/%s." % [prefix, id])
			_spots[id] = _map.to_local(marker.global_position)
			var feet := _spots[id]
			if absf(_terrain.ground_height(Vector2(feet.x, feet.z)) - feet.y) > 0.035:
				return _fail("Marker isn't supported at standing height: %s." % id)
			if _ray(feet + Vector3.UP * 1.75, feet + Vector3.UP * 0.05):
				return _fail("Marker is obstructed: %s." % id)
	var ford := _map.get_node("Markers/Routes/FordShallows")
	return ford.get_meta(&"route_surface") == "shallows" or _fail("The physical ford lacks its shallow-lane marker.")


func _check_lanes() -> bool:
	var bridge := _check_path(BRIDGE_ROUTE, true)
	var ford := _check_path(FORD_ROUTE, true)
	if bridge <= 0.0 or ford <= 0.0:
		return false
	if bridge < 185.0 or ford < bridge * 1.35:
		return _fail("The field is too compressed or the covered ford is not a meaningful detour (%s m vs %s m)." % [bridge, ford])
	# Crossing centerline and bank runs are wide enough for the harness's current formation footprint.
	if _check_path(CHARGE_ROUTE, false) < 100.0:
		return _fail("The eastern charge approach lacks a continuous 100 m run.")
	for offset in [Vector2(-8, -6), Vector2(8, -6), Vector2(-8, 6), Vector2(8, 6)]:
		var fork := _spots["ReserveFork"]
		var point := Vector2(fork.x, fork.z)
		if not _terrain.can_move(point, point + offset, true):
			return _fail("A formation could not hold or redeploy in the reserve fork.")
	print("Seed-grain bridge route: %.1f m; bread-grain sheltered ford: %.1f m." % [bridge, ford])
	return true


func _check_path(ids: Array, cart: bool) -> float:
	var length := 0.0
	for index in range(ids.size() - 1):
		var from := _spots[ids[index]]
		var to := _spots[ids[index + 1]]
		var span := from.distance_to(to)
		length += span
		var direction := Vector2(to.x - from.x, to.z - from.z).normalized()
		var yaw := atan2(direction.x, direction.y)
		var samples := ceili(span / 0.30)
		var previous := Vector2(from.x, from.z)
		for sample in range(samples + 1):
			var position := from.lerp(to, float(sample) / samples)
			var point := Vector2(position.x, position.z)
			var feet := Vector3(point.x, _terrain.ground_height(point), point.y)
			if not _terrain.can_move(previous, point, true) or (cart and not _cart_clear(feet, yaw)):
				_fail("No continuous cart/formation clearance between %s and %s at %s." % [ids[index], ids[index + 1], feet])
				return -1.0
			previous = point
	return length


func _cart_clear(feet: Vector3, yaw: float) -> bool:
	var shape := BoxShape3D.new()
	shape.size = CART_CLEARANCE
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.collision_mask = 1
	probe.shape = shape
	var anchor := Basis(Vector3.UP, yaw)
	var center := feet + Vector3.UP * (CART_CLEARANCE.y * 0.5 + 0.10)
	probe.transform = _map.global_transform * Transform3D(anchor, center)
	return _world.intersect_shape(probe, 1).is_empty()


func _check_sightlines() -> bool:
	var eyes := _spots["FarBankArchers"] + Vector3.UP * 1.75
	for offset in [-8.0, 0.0, 8.0]:
		var bridge := _spots["BridgeDeck"] + Vector3(offset, 1.6, 0)
		var ford := _spots["FordShallows"] + Vector3(offset, 1.6, 0)
		if _ray(eyes, bridge):
			return _fail("The bridge is unexpectedly screened from far-bank archers.")
		if not _ray(eyes, ford):
			return _fail("The southern ford lacks a solid sight break from far-bank archers (offset %s)." % offset)
	return true


func _check_boundaries() -> bool:
	for z in [-104.0, -71.5, -20.0, 68.0, 82.0, 106.0]:
		var west := Vector2(-15.0, z)
		if _terrain.can_move(west, Vector2(0, z), false):
			return _fail("A hero can walk across the deep river outside either crossing.")
		if not _ray(Vector3(-16.0, 0.20, z), Vector3(16.0, 0.20, z)):
			return _fail("The deep channel is not solid to terrain queries outside the marked lanes.")
	for boundary in [
		[Vector3(-135, 1.1, 40), Vector3(-178, 1.1, 40)],
		[Vector3(135, 1.1, 35), Vector3(178, 1.1, 35)],
		[Vector3(66, 1.1, -117), Vector3(66, 1.1, -154)],
		[Vector3(-66, 1.1, 117), Vector3(-66, 1.1, 154)],
	]:
		if not _ray(boundary[0], boundary[1]):
			return _fail("A perimeter ridge did not bound the valley.")
	return true


func _measure_edge_march() -> bool:
	# Use the playable feet of the west/east ridges, not the bounding box or cart exits.
	var bridge: Vector3 = _spots["BridgeDeck"]
	var start := Vector2(-145.0, bridge.z)
	var destination := Vector2(145.0, bridge.z)
	for point: Vector2 in [start, destination]:
		if not _supports_formation(point):
			return _fail("Bridge traverse does not reach supported valley edges.")
		var outside := point + Vector2(signf(point.x) * 4.0, 0.0)
		if _supports_formation(outside):
			return _fail("Measured edge no longer borders the perimeter ridge.")
	var battle := Battle.new()
	battle.bounds = Rect2(-171.0, -146.0, 342.0, 292.0)
	battle.formations[0].position = start
	battle.formations[0].hold()
	battle.order_move(0, destination)
	var platoon := battle.formations[0]
	var ticks := 0
	while platoon.order == Battle.Order.MOVE and ticks < 180 * 60:
		battle.step(MARCH_DT, Vector2.ZERO, _terrain.can_move)
		ticks += 1
		if not _supports_formation(platoon.position):
			return _fail("The measured formation left supported terrain at %s." % platoon.position)
	var seconds := ticks * MARCH_DT
	if not platoon.position.is_equal_approx(destination) or platoon.order != Battle.Order.HOLD \
			or not MarchScale.within_baseline_band(seconds) or MarchScale.classify_baseline(seconds) != MarchScale.Tier.COMPACT:
		return _fail("Expected an unopposed Compact edge march; reached %s in %.2f s." % [platoon.position, seconds])
	print("Marches Crossing: infantry marched %.1f m edge to edge in %.2f s (Compact)." % [
		start.distance_to(destination), seconds,
	])
	return true


func _supports_formation(point: Vector2) -> bool:
	var surface: Variant = _terrain.destination_from_ray(
		Vector3(point.x, 30.0, point.y), Vector3(point.x, -4.0, point.y)
	)
	return surface != null and _terrain.formation_fits_at(point)


func _ray(from: Vector3, to: Vector3) -> bool:
	return not _world.intersect_ray(PhysicsRayQueryParameters3D.create(_map.to_global(from), _map.to_global(to), 1)).is_empty()


func _fail(message: String) -> bool:
	push_error(message)
	return false
