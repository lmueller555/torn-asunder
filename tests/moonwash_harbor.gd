extends SceneTree

const MAP := preload("res://game/battlefields/moonwash_harbor.tscn")
const MARKERS := {
	"Spawns": [
		"HumanHero", "RoyalVanguard", "RoyalRearGuard", "LocalLevy", "ElfHero",
		"ShipArchers", "ShoreMarines", "ForwardCrew", "AftCrew", "ShoreSalvagers",
	],
	"Routes": [
		"FracturedQuay", "UpperStairFoot", "UpperStairLanding", "UpperStairTop",
		"QuaySafeTurn", "InlandBypass", "InlandApproach", "InlandStairTop", "UpperQuay", "LandwardRescue",
		"OpenMooring", "ReceivingGangway", "StrandedAccess", "StrandedDeckGangway",
		"PierOuterTurn", "PierInnerTurn",
	],
	"Objectives": [
		"UpperQuayExit", "ForwardTransfer", "AftTransfer", "ForwardReceiver",
		"AftReceiver", "ReceivingDeck", "OptionalCargo",
	],
	"PhaseZones": ["FracturedSlab", "LowerStairClosure"],
}
const PATHS := {
	"Human main withdrawal": [
		"HumanHero", "FracturedQuay", "UpperStairFoot", "UpperStairLanding",
		"UpperStairTop", "UpperQuay", "UpperQuayExit",
	],
	"Human permanent inland withdrawal": [
		"RoyalRearGuard", "QuaySafeTurn", "InlandBypass", "InlandApproach", "InlandStairTop",
		"UpperQuay", "UpperQuayExit",
	],
	"Human hero reaches bypass": ["HumanHero", "QuaySafeTurn"],
	"Human advance guard reaches bypass": ["RoyalVanguard", "InlandBypass"],
	"Human advance guard": ["RoyalVanguard", "UpperStairFoot", "UpperStairLanding"],
	"Levy pushes up from land": ["LocalLevy", "FracturedQuay"],
	"Elven hero approaches the stranded hull": [
		"ElfHero", "ReceivingGangway", "PierOuterTurn", "PierInnerTurn", "OpenMooring",
		"StrandedAccess", "StrandedDeckGangway", "ForwardTransfer",
	],
	"Marines screen the sheltered mooring": ["ShoreMarines", "OpenMooring", "LandwardRescue"],
	"Foredeck crew": ["ForwardCrew", "ForwardTransfer"],
	"Aft crew": ["AftCrew", "AftTransfer"],
	"Clear fore receiver": ["ForwardReceiver", "ReceivingDeck"],
	"Clear aft receiver": ["AftReceiver", "ReceivingDeck"],
	"Salvager reaches optional point": ["ShoreSalvagers", "OptionalCargo"],
}

var _spots: Dictionary[String, Vector3] = {}
var _closures: Array[AABB] = []
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
				_closures.append(AABB(marker.global_position - zone_size * 0.5, zone_size))
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

	# Future scripts can toggle these optional low-quay footprints without cutting
	# the permanent inland path away from any of the Human starting positions.
	for alternate: String in [
		"Human permanent inland withdrawal", "Human hero reaches bypass",
		"Human advance guard reaches bypass",
	]:
		var ids: Array = PATHS[alternate]
		for i in range(1, ids.size()):
			for zone: AABB in _closures:
				var start := _spots[ids[i - 1]] + Vector3.UP * 0.75
				var end := _spots[ids[i]] + Vector3.UP * 0.75
				if zone.grow(0.45).intersects_segment(start, end) != null:
					_fail("The permanent inland route intersects a possible closure.")
					return

	# Each marked transfer crosses open water; there is no static plank or floor
	# to move the crews until later mission logic rigs the line.
	for pair: Array in [["ForwardTransfer", "ForwardReceiver"], ["AftTransfer", "AftReceiver"]]:
		var from: Vector3 = _spots[pair[0]]
		var to: Vector3 = _spots[pair[1]]
		var mid := from.lerp(to, 0.62)
		if not _ray(mid + Vector3.UP * 2.0, mid - Vector3.UP * 3.0).is_empty():
			_fail("Transfer %s to %s should cross an open-water gap." % [pair[0], pair[1]])
			return

	# Old masonry physically occludes the sheltered landward side, but the
	# open mooring has no equally tall wall between it and the ship lane.
	if _ray(map.to_global(Vector3(-22, 3.1, 21)), map.to_global(Vector3(-22, 2.4, 4))).is_empty():
		_fail("The raised harbor wall no longer breaks line of sight into the sheltered quay.")
		return
	if not _ray(map.to_global(Vector3(21, 3.3, 21)), map.to_global(Vector3(33, 2.1, 11))).is_empty():
		_fail("The east mooring should retain a clear shot from the exposed hull.")
		return
	if _spots.UpperQuayExit.y - _spots.ReceivingDeck.y < 4.0:
		_fail("The Human upper exit and Elven receiving deck should occupy distinct levels.")
		return

	print("Verified %d foot markers, %d walks, 2 open transfer gaps, 2 inert phase zones and harbor collision." % [
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
