extends SceneTree

const MAP := preload("res://game/battlefields/cairnspine_vault_road.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const SHELF := [
	"SafeStaging", "ShelfDecision", "ShelfFoot", "ShelfClimb", "ShelfHold", "ShelfRejoin", "Forecourt",
]
const SIDE := [
	"SafeStaging", "SideDecision", "SideApproach", "SideTurn", "SideRampFoot", "SideBlindBend",
	"SideRampTurn", "SideNorthToe", "SideHighBend", "SideRejoin", "Forecourt",
]
const TERRACE := ["Forecourt", "TerraceApproach", "TerraceEntry", "WitnessTerrace", "AttestingWitnesses"]
const PATHS := {
	"Carrier staging": ["SovaCarrier", "ValleyAssembly", "SafeStaging"],
	"Dryad refugees staging": ["NerisGuide", "RefugeeStaging", "SafeStaging"],
	"Dryad witnesses staging": ["WitnessStaging", "SafeStaging"],
	"Court and household start": ["SerethHousehold", "ValleyAssembly", "CourtEscort"],
	"Keeper shelf guard": ["KeeperShelfGuard", "ShelfDecision", "ShelfFoot"],
	"Keeper side guard": ["KeeperSideGuard", "SideDecision", "SideApproach"],
	"Short shelf": SHELF,
	"Longer side": SIDE,
	"Forecourt to closure": ["Forecourt", "CustodyLine", "VaultEntrance", "BridleReturn"],
	"Independent witness terrace": TERRACE,
	"Independent refugee hold": ["Forecourt", "TerraceApproach", "TerraceEntry", "RefugeeSafety"],
	"Hidden rival reserve": ["RivalReserve", "RivalReserveCorner", "RivalReserveReveal", "Forecourt"],
	"Open hearing west": ["SovaHearing", "OpenWestApproach", "OpenRingCenter", "OpenLectern", "OpenScribe"],
	"Open hearing north": ["OpenNorthApproach", "OpenRingCenter"],
	"Open hearing public exit": ["OpenRingCenter", "OpenPublicExit"],
	"Recessed hearing approach": [
		"SovaHearing", "RecessedApproach", "RecessedRingCenter", "RecessedLectern", "RecessedScribe",
	],
	"Recessed hearing public exit": ["RecessedRingCenter", "RecessedPublicExit"],
}

var _map: Node3D
var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _points: Dictionary[String, Vector3] = {}
var _zones: Dictionary[String, AABB] = {}


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
		if marker.get_parent().name == &"PhaseZones":
			var box: Variant = marker.get_meta(&"box_size", Vector3.ZERO)
			if not box is Vector3 or minf(minf(box.x, box.y), box.z) <= 0.0:
				_fail("Missing positive box_size for %s." % marker.name)
				return
			_zones[marker.name] = AABB(point - box * 0.5, box)
		else:
			_points[marker.name] = point
			var xz := _xz(point)
			if absf(_terrain.ground_height(xz) - point.y) > 0.04 or not _terrain.can_move(xz, xz + Vector2(0.005, 0.005), false):
				_fail("Foot marker %s is blocked or unsupported." % marker.name)
				return

	var length: Dictionary[String, float] = {}
	for path: String in PATHS:
		var ids: Array = PATHS[path]
		var total := 0.0
		for id: String in ids:
			if not _points.has(id):
				_fail("Missing %s from %s." % [id, path])
				return
		for i in range(1, ids.size()):
			var first := _points[ids[i - 1]]
			var last := _points[ids[i]]
			total += first.distance_to(last)
			if not _walk(first, last):
				_fail("%s is blocked between %s and %s." % [path, ids[i - 1], ids[i]])
				return
		length[path] = total

	if length["Short shelf"] < 195.0 or length["Longer side"] < length["Short shelf"] + 55.0:
		_fail("The protected flank must cost materially more travel than the narrow shelf.")
		return
	if not _check_widths() or not _check_cover() or not _check_zones():
		return
	print("Verified %d foot markers and %d terrain-probed routes; %.0f m shelf vs %.0f m flank, distinct terrace/vault and Year Two hearing venues." % [
		_points.size(), PATHS.size(), length["Short shelf"], length["Longer side"],
	])
	quit()


func _check_widths() -> bool:
	var shelf := _points.ShelfHold
	var side := Vector3(18, 8, 62)
	if not _walk(shelf - Vector3.BACK * 2.0, shelf + Vector3.BACK * 2.0) \
		or not _walk(side - Vector3.BACK * 6.0, side + Vector3.BACK * 6.0):
		_fail("The shelf and flank should have distinct, clear formation widths.")
		return false
	if _terrain.ground_height(_xz(shelf + Vector3.BACK * 5.5)) >= shelf.y - 1.0:
		_fail("The shelf lost its physical outer drop.")
		return false
	return true


func _check_cover() -> bool:
	for pair: Array in [
		["RivalReserve", "Forecourt"], ["SideBlindBend", "Forecourt"],
	]:
		if _sight(pair[0], pair[1]):
			_fail("Required approach cover is missing between %s and %s." % pair)
			return false
	if _ray(Vector3(-96, 1.6, 31), _points.RecessedRingCenter + Vector3.UP * 1.6).is_empty():
		_fail("Recessed hearing lacks its solid rear cover.")
		return false
	for pair: Array in [
		["RivalReserveReveal", "Forecourt"], ["ShelfHold", "ShelfRejoin"],
		["OpenNorthApproach", "OpenRingCenter"], ["OpenWestApproach", "OpenRingCenter"],
		["RecessedApproach", "RecessedRingCenter"], ["AttestingWitnesses", "VaultEntrance"],
	]:
		if not _sight(pair[0], pair[1]):
			_fail("Required sightline is blocked between %s and %s." % pair)
			return false
	return true


func _check_zones() -> bool:
	for id: String in ["VaultClosure", "TerraceSafeZone", "CustodyLineZone", "OpenHearingRing", "RecessedHearingRing"]:
		if not _zones.has(id):
			_fail("Missing inert landmark footprint %s." % id)
			return false
	var custody := _zones.CustodyLineZone
	var closure := _zones.VaultClosure
	var terrace := _zones.TerraceSafeZone
	var eyes := Vector3.UP * 1.6
	if custody.intersects(closure) or terrace.intersects(custody) or terrace.intersects(closure) \
		or not closure.has_point(_points.BridleReturn + eyes) \
		or not terrace.has_point(_points.RefugeeSafety + eyes) \
		or not terrace.has_point(_points.AttestingWitnesses + eyes):
		_fail("Witness safety, court custody, and the vault closure must remain physically distinct.")
		return false
	for i in range(1, TERRACE.size()):
		var from := _points[TERRACE[i - 1]] + eyes
		var to := _points[TERRACE[i]] + eyes
		if closure.intersects_segment(from, to) != null or custody.intersects_segment(from, to) != null:
			_fail("A terrace walk must not need to cross the custody line or closure footprint.")
			return false
	if _zones.OpenHearingRing.intersects(_zones.RecessedHearingRing) \
		or _zones.OpenHearingRing.has_point(_points.OpenPublicExit + eyes) \
		or _zones.RecessedHearingRing.has_point(_points.RecessedPublicExit + eyes):
		_fail("The two hearing geometries have independent, walkable public exits outside their hearing rings.")
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


func _sight(from: String, to: String) -> bool:
	return _ray(_points[from] + Vector3.UP * 1.6, _points[to] + Vector3.UP * 1.6).is_empty()


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(_map.to_global(a), _map.to_global(b), 1))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
