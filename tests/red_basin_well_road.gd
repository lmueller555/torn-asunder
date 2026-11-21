extends SceneTree

const MAP := preload("res://game/battlefields/red_basin_well_road.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const SALT := ["SaltRoadWest", "SaltChargeGate", "SaltRoadEast", "HighBankRally", "BasinExit"]
const WASH := [
	"WashEntryTurn", "WashWestBend", "WashReedBend", "WashBlindBend", "WashLongBend",
	"WashEastBend", "WashRampTurn", "WashRampFoot", "WashRampTop", "HighBankRally", "BasinExit",
]
const CARTS := {
	"Upper salt": ["UpperWellCart", "UpperWellStaging"] + SALT,
	"Upper wash": ["UpperWellCart", "UpperWellStaging", "WestApproachFork"] + WASH,
	"Lower salt": [
		"LowerWellCart", "LowerBoarding", "LowerWellStaging", "WashEntryTurn", "WestApproachFork",
	] + SALT,
	"Lower wash": ["LowerWellCart", "LowerBoarding", "LowerWellStaging"] + WASH,
}
const PATHS := {
	"Storehouse and boarding": ["LowerStorehouse", "LowerHouseholds", "LowerBoarding", "LowerWellStaging"],
	"Upper well staging": ["UpperWellHead", "UpperWellCart", "UpperWellStaging"],
	"Lower well staging": ["LowerWellHead", "LowerBoarding"],
	"Archer shoulder": [
		"BasinArchers", "SaltRoadWest", "SaltChargeGate", "SaltRoadEast",
		"ArcherShoulderStart", "ArcherShoulder",
	],
	"Brace line": ["BraceInfantry", "SaltRoadWest", "SaltChargeGate"],
	"Rider reserve and warning": [
		"MountedReserve", "MountedReserveTurn", "MountedScreenCorner", "MountedWarning", "MountedChargeStart",
	],
	"Straight cavalry lane": ["MountedChargeStart", "SaltChargeGate", "MountedRunout"],
	"Exit approach": ["RivalLevy", "HighBankRally", "BasinExit"],
}
const CART_WIDTH := 2.6
const CART_LENGTH := 4.6

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _points: Dictionary[String, Vector3] = {}
var _zones: Dictionary[String, AABB] = {}
var _cart := PhysicsShapeQueryParameters3D.new()


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
	var cart_shape := BoxShape3D.new()
	cart_shape.size = Vector3(CART_WIDTH, 1.5, CART_LENGTH)
	_cart.shape = cart_shape
	_cart.collision_mask = 1
	var floor_rids: Array[RID] = []
	for floor_node: Node in _map.find_children("*", "StaticBody3D"):
		var floor_body := floor_node as StaticBody3D
		if floor_body.collision_layer & Terrain.WALKABLE_MASK:
			floor_rids.append(floor_body.get_rid())
	_cart.exclude = floor_rids

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

	var distances: Dictionary[String, float] = {}
	for path: String in PATHS:
		if _run_path(path, PATHS[path], false) < 0.0:
			return
	for path: String in CARTS:
		var distance := _run_path(path, CARTS[path], true)
		if distance < 0.0:
			return
		distances[path] = distance

	if distances["Upper salt"] < 270.0 or distances["Upper wash"] < distances["Upper salt"] + 45.0 \
		or distances["Lower wash"] < distances["Lower salt"] + 25.0:
		_fail("The salt road and washed-out route lost their length tradeoff.")
		return
	if not _test_tactics():
		return
	print("Verified %d foot markers; both carts fit both routes; 8 patrol/actor paths. Upper %.0f/%.0f m and lower %.0f/%.0f m (salt/wash)." % [
		_points.size(), distances["Upper salt"], distances["Upper wash"], distances["Lower salt"], distances["Lower wash"],
	])
	quit()


func _run_path(name: String, ids: Array, carts: bool) -> float:
	var total := 0.0
	for id: String in ids:
		if not _points.has(id):
			_fail("Missing %s from %s." % [id, name])
			return -1.0
	for i in range(1, ids.size()):
		var a := _points[ids[i - 1]]
		var b := _points[ids[i]]
		total += a.distance_to(b)
		if not _walk(a, b, carts):
			_fail("%s is blocked between %s and %s." % [name, ids[i - 1], ids[i]])
			return -1.0
	return total


func _test_tactics() -> bool:
	for pair: Array in [["MountedReserve", "MountedChargeStart"], ["WashReedBend", "WashEastBend"]]:
		if _visible(pair[0], pair[1]):
			_fail("Required blinds are missing between %s and %s." % pair)
			return false
	for pair: Array in [
		["MountedWarning", "SaltChargeGate"], ["MountedChargeStart", "MountedRunout"],
		["ArcherShoulder", "WashRampFoot"], ["ArcherShoulder", "SaltRoadEast"],
	]:
		if not _visible(pair[0], pair[1]):
			_fail("Required warning/firing sightline is obstructed between %s and %s." % pair)
			return false
	var choke := Vector2(110, 24.5)
	var ramp_height := _terrain.ground_height(choke)
	if ramp_height < -2.3 or ramp_height > -1.7 \
		or _terrain.ground_height(choke + Vector2.RIGHT * 6.5) >= ramp_height - 1.5 \
		or _terrain.ground_height(choke + Vector2.LEFT * 6.5) >= ramp_height - 1.5:
		_fail("The single eastern ramp must remain a raised grade with low terrain on both sides.")
		return false
	for id: String in ["LowerBoardingArea", "SaltChargeLane", "WashRampChoke", "BasinExitZone"]:
		if not _zones.has(id):
			_fail("Missing inert layout footprint %s." % id)
			return false
	if _zones.SaltChargeLane.intersects(_zones.WashRampChoke) \
		or _zones.LowerBoardingArea.intersects(_zones.BasinExitZone) \
		or not _zones.LowerBoardingArea.has_point(_points.LowerBoarding + Vector3.UP) \
		or not _zones.BasinExitZone.has_point(_points.BasinExit + Vector3.UP):
		_fail("Boarding and arrival, and cavalry and ramp footprints should stay distinct.")
		return false
	return true


func _walk(a: Vector3, b: Vector3, cart: bool) -> bool:
	var from := _xz(a)
	var to := _xz(b)
	var previous := from
	var heading := (to - from).normalized()
	var count := maxi(1, ceili(from.distance_to(to) / 0.22))
	for i in range(count + 1):
		var next := from.lerp(to, float(i) / count)
		if not _terrain.can_move(previous, next, false) or not _terrain.can_move(previous, next, true) \
			or cart and not _cart_fits(next, heading):
			print("Terrain blocked near ", next)
			return false
		previous = next
	return true


func _cart_fits(point: Vector2, heading: Vector2) -> bool:
	if heading.is_zero_approx():
		return true
	var floor := _terrain.ground_height(point)
	var lateral := Vector2(-heading.y, heading.x)
	for axle in [-1.8, 1.8]:
		for wheel in [-1.1, 1.1]:
			if absf(_terrain.ground_height(point + heading * axle + lateral * wheel) - floor) > 0.52:
				return false
	var basis := Basis(Vector3.UP, atan2(-heading.x, -heading.y))
	_cart.transform = Transform3D(basis, _map.to_global(Vector3(point.x, floor + 0.93, point.y)))
	return _space.intersect_shape(_cart, 1).is_empty()


func _visible(from: String, to: String) -> bool:
	var start := _map.to_global(_points[from] + Vector3.UP * 1.6)
	var end := _map.to_global(_points[to] + Vector3.UP * 1.6)
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1)).is_empty()


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
