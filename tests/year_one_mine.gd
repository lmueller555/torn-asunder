extends SceneTree

const MAP := preload("res://game/battlefields/year_one_mine.tscn")
const MARKERS := {
	"Spawns": [
		"HumanEscort", "HumanInfantry", "HumanArchers", "OrcIntercept",
		"OrcCrewParty", "DruidGuard", "Miners",
	],
	"Routes": [
		"RoadWest", "RoadJunction", "EastPass", "RidgeWestFoot", "RidgeOverlook",
		"RidgeEastFoot", "OrcApproach", "InterceptFork", "MineYard",
		"TunnelEntrance", "TunnelMidpoint", "TunnelExit", "EvacuationTrail",
	],
	"Objectives": ["GodbridlePickup", "GodbridleExit", "MinerAssembly", "MinerEvacuation"],
}
const PATHS := {
	"Human escort": ["HumanEscort", "GodbridlePickup", "RoadWest", "RoadJunction", "EastPass", "GodbridleExit"],
	"Human infantry": ["HumanInfantry", "RoadJunction", "EastPass"],
	"Human archer cover": ["HumanArchers", "RidgeWestFoot", "RidgeOverlook"],
	"Orc road intercept": ["OrcIntercept", "OrcApproach", "InterceptFork", "EastPass"],
	"Orc crew interception": [
		"OrcCrewParty", "RidgeEastFoot", "RidgeOverlook", "RidgeWestFoot",
		"RoadWest", "MineYard", "MinerAssembly",
	],
	"Druid guard": ["DruidGuard", "TunnelEntrance", "TunnelMidpoint"],
	"Miner evacuation": [
		"Miners", "MinerAssembly", "TunnelEntrance", "TunnelMidpoint",
		"TunnelExit", "EvacuationTrail", "MinerEvacuation",
	],
}

var _spots: Dictionary[String, Vector3] = {}
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

	# Verify the map is not just a plane with markers: the tunnel is enclosed,
	# the ridge has cover, and the east pass is a genuine choke.
	for pair: Array in [
		[Vector3(-23, 2, 32), Vector3(-23, 6, 32)],
		[Vector3(-23, 2, 32), Vector3(-17, 2, 32)],
		[Vector3(-23, 2, 32), Vector3(-29, 2, 32)],
		[Vector3(-7, 5, -16), Vector3(-7, 5, -12)],
		[Vector3(42, 1.6, 0), Vector3(42, 1.6, -6)],
		[Vector3(42, 1.6, 0), Vector3(42, 1.6, 6)],
	]:
		if _ray(map.to_global(pair[0]), map.to_global(pair[1])).is_empty():
			_fail("Missing solid geometry between %s and %s." % [pair[0], pair[1]])
			return

	# Four-meter-wide clearance in the tunnel and along the pass centerline.
	for lane_offset in [-2.0, 2.0]:
		var pass_offset := Vector3(0, 0, lane_offset)
		var tunnel_offset := Vector3(lane_offset, 0, 0)
		if not _walkable(_spots.EastPass + pass_offset, _spots.GodbridleExit + pass_offset):
			_fail("The east pass side lane is obstructed.")
			return
		if not _walkable(_spots.TunnelEntrance + tunnel_offset, _spots.TunnelExit + tunnel_offset):
			_fail("The tunnel side lane is obstructed.")
			return

	print("Verified %d mine markers, seven approach paths, tunnel clearance and solid cover." % _spots.size())
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
	# Support can differ from a straight line between markers on the ridge ramps.
	# Keep the query below the tunnel ceiling and tolerate the slope transitions.
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
