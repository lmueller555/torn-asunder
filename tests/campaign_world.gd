extends SceneTree

const World := preload("res://game/campaign_world.gd")
const Missions := preload("res://game/campaign_missions.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const ROAD := "marches_road"
const CROSSING := "marches_crossing"
const MOONWASH := "moonwash_road"
const HARBOR := "moonwash_harbor"
const ESCORT := "mara_mine_escort"


func _initialize() -> void:
	var passed := _check_topology() and _check_travel() and _check_isolation()
	if passed:
		print("Verified waypoint topology, single-edge travel, clear gates, visits, and isolated world state.")
	quit(0 if passed else 1)


func _check_topology() -> bool:
	var map := World.new("mara")
	var nodes := map.waypoints()
	if nodes.size() != 6 or map.routes().size() != 5:
		return _fail("The three Human chapters should have six waypoints and five edges.")
	var drawn_positions := {}
	for node in nodes:
		var point: Vector2 = node.map_position
		if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(point) or drawn_positions.has(point):
			return _fail("Each waypoint needs a distinct normalized map position.")
		drawn_positions[point] = true
	var retained_mission := Missions.mission_for_campaign("mara", map.waypoint(MINE).mission_id)
	if retained_mission.get("id") != ESCORT or retained_mission.get("battlefield_id") != MINE:
		return _fail("The reachable mine must refer to the catalog's actual escort mission.")
	if map.waypoint(CAMP).kind != World.WaypointKind.CAMP \
			or map.waypoint(MINE).kind != World.WaypointKind.BATTLEFIELD \
			or map.waypoint(ROAD).kind != World.WaypointKind.REGION \
			or map.waypoint(CAMP).has("mission_id") or map.waypoint(ROAD).has("mission_id"):
		return _fail("A non-battle waypoint exposed a mission or one of the map kinds was wrong.")
	return true


func _check_travel() -> bool:
	var map := World.new("mara")
	var no_clears := PackedStringArray()
	var real_clear := PackedStringArray([ESCORT])
	if map.current_waypoint_id() != CAMP or map.visited_waypoint_ids() != PackedStringArray([CAMP]) \
			or not map.mission_at_current_waypoint().is_empty():
		return _fail("The token did not start at the visited non-battle camp.")
	if map.route_options(no_clears) != [{"waypoint_id": MINE, "required_clear_id": "", "is_open": true}]:
		return _fail("The mine was not the camp's sole open connection.")
	if map.travel_to(CAMP, no_clears) != World.TravelResult.ALREADY_HERE \
			or map.travel_to("unknown", no_clears) != World.TravelResult.UNKNOWN_WAYPOINT \
			or map.travel_to(ROAD, real_clear) != World.TravelResult.NOT_ADJACENT:
		return _fail("Travel accepted an invalid move or allowed a clear to bypass topology.")
	if map.current_waypoint_id() != CAMP or map.visited_waypoint_ids() != PackedStringArray([CAMP]):
		return _fail("Rejected travel mutated position or visits.")
	if map.travel_to(MINE, no_clears) != World.TravelResult.ARRIVED \
			or map.current_waypoint_id() != MINE or map.mission_at_current_waypoint() != ESCORT:
		return _fail("Arrival at the mine did not make the escort briefing available as a separate action.")
	var expected := [
		{"waypoint_id": CAMP, "required_clear_id": "", "is_open": true},
		{"waypoint_id": ROAD, "required_clear_id": ESCORT, "is_open": false},
	]
	if map.route_options(no_clears) != expected or not no_clears.is_empty():
		return _fail("Visiting the mine changed completion flags or hid the locked road.")
	for invalid in [no_clears, PackedStringArray([MINE]), PackedStringArray(["mara_grain_crossing", "orc_mine_witness"])]:
		if map.travel_to(ROAD, invalid) != World.TravelResult.LOCKED:
			return _fail("A location visit, unknown ID, or unrelated mission cleared the road gate.")
	if map.travel_to(CAMP, no_clears) != World.TravelResult.ARRIVED \
			or map.travel_to(MINE, no_clears) != World.TravelResult.ARRIVED \
			or map.visited_waypoint_ids() != PackedStringArray([CAMP, MINE]):
		return _fail("The free route was not bidirectional or revisits duplicated visit history.")
	if map.travel_to(ROAD, real_clear) != World.TravelResult.ARRIVED \
			or map.current_waypoint_id() != ROAD or not map.mission_at_current_waypoint().is_empty() \
			or map.visited_waypoint_ids() != PackedStringArray([CAMP, MINE, ROAD]):
		return _fail("The real mission clear did not open the route to a non-battle waypoint.")
	var road_options := [
		{"waypoint_id": MINE, "required_clear_id": ESCORT, "is_open": true},
		{"waypoint_id": CROSSING, "required_clear_id": "", "is_open": true},
	]
	if map.route_options(real_clear) != road_options or map.travel_to(MINE, real_clear) != World.TravelResult.ARRIVED:
		return _fail("The road did not link to the Mine and Marches Crossing.")
	if (
		map.travel_to(CROSSING, real_clear) != World.TravelResult.NOT_ADJACENT
		or map.travel_to(ROAD, real_clear) != World.TravelResult.ARRIVED
		or map.travel_to(CROSSING, real_clear) != World.TravelResult.ARRIVED
		or map.mission_at_current_waypoint() != "mara_grain_crossing"
	):
		return _fail("The Grain briefing skipped the Marches Road or did not match the actual mission.")
	if map.travel_to(MOONWASH, real_clear) != World.TravelResult.LOCKED or map.is_waypoint_reachable(HARBOR, real_clear):
		return _fail("The Mine clear alone opened the route beyond Grain.")
	real_clear.append("mara_grain_crossing")
	if map.travel_to(MOONWASH, real_clear) != World.TravelResult.ARRIVED or not map.mission_at_current_waypoint().is_empty():
		return _fail("The Grain clear did not open the non-battle road to Moonwash.")
	if map.travel_to(HARBOR, real_clear) != World.TravelResult.ARRIVED \
		or map.mission_at_current_waypoint() != "mara_moonwash_quay":
		return _fail("The Moonwash Road did not link to the authored High Quay battlefield.")
	return true


func _check_isolation() -> bool:
	var unknown := World.new("ilyra")
	var no_clears := PackedStringArray()
	if not unknown.current_waypoint_id().is_empty() or not unknown.visited_waypoint_ids().is_empty() \
			or not unknown.waypoints().is_empty() or not unknown.routes().is_empty() \
			or not unknown.route_options(no_clears).is_empty() or not unknown.waypoint(MINE).is_empty() \
			or unknown.travel_to(MINE, no_clears) != World.TravelResult.NO_MAP:
		return _fail("A campaign without a map borrowed Mara's waypoints.")
	var map := World.new("mara")
	var nodes := map.waypoints()
	nodes[0].label = "local edit"
	var edges := map.routes()
	edges[0].to_id = ROAD
	var visits := map.visited_waypoint_ids()
	visits.append(ROAD)
	var current := map.waypoint(CAMP)
	current.erase("label")
	if map.waypoint(CAMP).label != "Marches Camp" or map.routes()[0].to_id != MINE \
			or map.visited_waypoint_ids() != PackedStringArray([CAMP]):
		return _fail("A caller mutated the map or history via returned metadata.")
	map.travel_to(MINE, no_clears)
	var fresh := World.new("mara")
	if fresh.current_waypoint_id() != CAMP or fresh.visited_waypoint_ids() != PackedStringArray([CAMP]):
		return _fail("A separate campaign session inherited another session's visits.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
