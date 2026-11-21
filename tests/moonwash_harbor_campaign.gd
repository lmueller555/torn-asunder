extends SceneTree

const MAP := preload("res://game/battlefields/moonwash_harbor_campaign.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
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
const FORMATION_PATHS := [
	"Human main withdrawal", "Human permanent inland withdrawal", "Human hero reaches bypass",
	"Human advance guard reaches bypass", "Human advance guard", "Levy pushes up from land",
	"Marines screen the sheltered mooring",
]

var _map: Node3D
var _terrain: Terrain
var _spots: Dictionary[String, Vector3] = {}
var _closures: Dictionary[String, AABB] = {}
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_map = MAP.instantiate()
	root.add_child(_map)
	_map.position = Vector3(14, 7, -9)
	_terrain = Terrain.new(_map)
	await physics_frame
	await physics_frame
	_space = _map.get_world_3d().direct_space_state
	var passed := _check_markers() and _check_paths() and _check_phases() and _check_ship_gaps() and _check_arcs()
	if passed:
		print("Campaign Moonwash: %d supported markers, %d real terrain paths, branch closures, two rescue gaps, protected/open LOS, deck picking and topography verified." % [_spots.size(), PATHS.size()])
	quit(0 if passed else 1)


func _check_markers() -> bool:
	for group: String in MARKERS:
		for id: String in MARKERS[group]:
			var marker := _map.get_node_or_null("Markers/%s/%s" % [group, id]) as Marker3D
			if not marker:
				return _fail("Missing compatible marker: %s/%s." % [group, id])
			if group == "PhaseZones":
				var size: Variant = marker.get_meta(&"box_size", Vector3.ZERO)
				if not size is Vector3 or minf(size.x, minf(size.y, size.z)) <= 0.0:
					return _fail("Invalid phase footprint: " + id)
				_closures[id] = AABB(marker.position - size * 0.5, size)
			else:
				var point := _map.to_local(marker.global_position)
				_spots[id] = point
				if absf(_terrain.ground_height(_xz(point)) - point.y) > 0.035:
					return _fail("Unsupported or mislabeled standing height at %s: %s." % [id, point])
				if not _terrain.can_move(_xz(point) + Vector2(0.025, 0.0), _xz(point), false):
					return _fail("An actor cannot stand at " + id)
	return true


func _check_paths() -> bool:
	for label: String in PATHS:
		var ids: Array = PATHS[label]
		for i in range(ids.size() - 1):
			if not _walk(_spots[ids[i]], _spots[ids[i + 1]], label in FORMATION_PATHS):
				return _fail("Terrain path %s is obstructed between %s and %s." % [label, ids[i], ids[i + 1]])
	var main := _distance(PATHS["Human main withdrawal"])
	var bypass := _distance(PATHS["Human permanent inland withdrawal"])
	var rescue := _distance(PATHS["Elven hero approaches the stranded hull"])
	if main < 175.0 or bypass < main + 50.0 or rescue < 125.0:
		return _fail("Full-scale routes no longer preserve separation and the safer route's longer travel.")
	if _spots["UpperQuayExit"].y - _spots["ReceivingDeck"].y < 8.0:
		return _fail("Withdrawal and rescue lack distinct levels.")
	print("Human marked stair: %.1f m, inland bypass from rear guard: %.1f m, Elven approach between decks: %.1f m." % [main, bypass, rescue])
	return true


func _check_phases() -> bool:
	var main: Array = PATHS["Human main withdrawal"]
	for id: String in _closures:
		if not _intersects(main, _closures[id]):
			return _fail("The future closure isn't on its intended Human branch: " + id)
		for label in ["Human permanent inland withdrawal", "Human hero reaches bypass", "Human advance guard reaches bypass", "Elven hero approaches the stranded hull"]:
			if _intersects(PATHS[label], _closures[id].grow(1.7)):
				return _fail("A possible Human closure cuts the bypass or rescue lane: " + label)
	if _closures["FracturedSlab"].intersects(_closures["LowerStairClosure"]):
		return _fail("The fracture and lower stair have merged into one hazard.")
	return true


func _check_ship_gaps() -> bool:
	for pair: Array in [["ForwardTransfer", "ForwardReceiver"], ["AftTransfer", "AftReceiver"]]:
		var source := _spots[pair[0]]
		var receiver := _spots[pair[1]]
		var water := source.lerp(receiver, 0.55)
		if not _ray(water + Vector3.UP * 2.0, water - Vector3.UP * 5.0).is_empty():
			return _fail("A static surface closes the intended rigging gap at " + pair[0])
		# No unsupported vertical command-ray target in water; each deck uses a
		# normal walkable static body (not only a visual CSG hull).
		if _terrain.destination_from_ray(water + Vector3.UP * 12.0, water - Vector3.UP * 6.0) != null:
			return _fail("The command adapter treats the rigging gap as ground.")
		var aim: Variant = _terrain.destination_from_ray(receiver + Vector3.UP * 12.0, receiver - Vector3.UP)
		if aim == null or not aim.is_equal_approx(_xz(receiver)):
			return _fail("The receiving deck is not targetable through the real terrain adapter.")
		var last := _xz(source)
		var crossed_water := false
		for index in range(1, 80):
			var next := _xz(source.lerp(receiver, float(index) / 80.0))
			if not _terrain.can_move(last, next, false):
				crossed_water = true
				break
			last = next
		if not crossed_water:
			return _fail("An unrigged gap is walkable from deck to deck.")
	if _spots["ForwardTransfer"].distance_to(_spots["AftTransfer"]) < 60.0:
		return _fail("The fore and aft rigging stations no longer offer separate approaches.")
	return true


func _check_arcs() -> bool:
	var sheltered_archer := Vector3(-58.3, 6.2, 55.65)
	var sheltered_target := Vector3(-58.3, 4.8, 10.6)
	var exposed_archer := Vector3(55.65, 6.6, 55.65)
	var exposed_target := Vector3(87.45, 4.2, 29.15)
	if _terrain.clear_ranged_lane(sheltered_archer, sheltered_target):
		return _fail("The actual raised wall no longer occludes the sheltered shore.")
	if not _terrain.clear_ranged_lane(exposed_archer, exposed_target):
		return _fail("The open east mooring lost its shipboard archer angle.")
	if _ray(Vector3(-105, 5, 26), Vector3(-159, 5, 26)).is_empty():
		return _fail("The west perimeter headland does not bound the active harbor.")
	if not _walk(_spots["UpperQuayExit"], Vector3(107.4, 10.8, -108), true):
		return _fail("The terrain does not connect the upper exit to the marked inland causeway.")
	if _ray(Vector3(63, 13, -83), Vector3(63, 13, -129)).is_empty():
		return _fail("The north escarpment does not bound the upper quay.")
	return true


func _walk(from: Vector3, to: Vector3, formation: bool) -> bool:
	var count := ceili(_xz(from).distance_to(_xz(to)) / 0.30)
	var previous := _xz(from)
	for index in range(1, count + 1):
		var next := _xz(from.lerp(to, float(index) / count))
		if not _terrain.can_move(previous, next, formation):
			print("Terrain blocked step ", previous, " to ", next, " formation=", formation)
			return false
		previous = next
	return true


func _distance(route: Array) -> float:
	var total := 0.0
	for index in range(route.size() - 1):
		total += _spots[route[index]].distance_to(_spots[route[index + 1]])
	return total


func _intersects(route: Array, box: AABB) -> bool:
	for index in range(route.size() - 1):
		var from := _spots[route[index]] + Vector3.UP * 0.75
		var to := _spots[route[index + 1]] + Vector3.UP * 0.75
		if box.intersects_segment(from, to) != null:
			return true
	return false


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(_map.to_global(from), _map.to_global(to), 1))


func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _fail(message: String) -> bool:
	push_error(message)
	return false
