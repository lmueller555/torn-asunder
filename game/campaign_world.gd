extends RefCounted
## Overworld position and edge traversal. A visit never records a mission clear.
## Mission availability, briefing confirmation and persistence belong to callers.

enum WaypointKind { CAMP, BATTLEFIELD, REGION }
enum TravelResult { ARRIVED, ALREADY_HERE, NO_MAP, UNKNOWN_WAYPOINT, NOT_ADJACENT, LOCKED }

# Waypoint positions are normalized map coordinates; route edges are bidirectional.
# Author topology and its gates here, independently of the ordered mission catalog.
const _MAPS := {
	"mara": {
		"start": "marches_camp",
		"waypoints": {
			"marches_camp": {
				"id": "marches_camp", "label": "Marches Camp", "kind": WaypointKind.CAMP,
				"map_position": Vector2(0.19, 0.63),
			},
			"year_one_mine": {
				"id": "year_one_mine", "label": "The Mine", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.49, 0.34), "mission_id": "mara_mine_escort",
			},
			"marches_road": {
				"id": "marches_road", "label": "Road into the Marches", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.81, 0.53),
			},
			"marches_crossing": {
				"id": "marches_crossing", "label": "Marches Crossing", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.31, 0.71), "mission_id": "mara_grain_crossing",
			},
			"headwater_council": {
				"id": "headwater_council", "label": "Headwater Council", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.18, 0.80), "beat": "mara_command_interlude",
			},
			"moonwash_harbor": {
				"id": "moonwash_harbor", "label": "Moonwash Harbor", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.07, 0.56), "mission_id": "mara_moonwash_quay",
			},
		},
		"routes": [
			{"from_id": "marches_camp", "to_id": "year_one_mine"},
			{"from_id": "year_one_mine", "to_id": "marches_road", "required_clear_id": "mara_mine_escort"},
			{"from_id": "marches_road", "to_id": "marches_crossing", "required_clear_id": "mara_mine_escort"},
			{"from_id": "marches_crossing", "to_id": "headwater_council", "required_clear_id": "mara_grain_crossing"},
			{"from_id": "headwater_council", "to_id": "moonwash_harbor", "required_clear_id": "mara_grain_crossing"},
		],
	},
	"raska": {
		"start": "basin_camp",
		"waypoints": {
			"basin_camp": {
				"id": "basin_camp", "label": "Basin Camp", "kind": WaypointKind.CAMP,
				"map_position": Vector2(0.78, 0.41),
			},
			"year_one_mine": {
				"id": "year_one_mine", "label": "The Mine", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.49, 0.34), "mission_id": "orc_mine_witness",
			},
			"basin_well_road": {
				"id": "basin_well_road", "label": "Basin Well Road", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.83, 0.65), "mission_id": "orc_well_road",
			},
			"assembly_town": {
				"id": "assembly_town", "label": "Assembly Town", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.90, 0.47), "beat": "raska_assembly_interlude",
			},
			"spanwater_lock": {
				"id": "spanwater_lock", "label": "Spanwater Lock", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.62, 0.63), "mission_id": "orc_spanwater_release",
			},
		},
		"routes": [
			{"from_id": "basin_camp", "to_id": "year_one_mine"},
			{"from_id": "year_one_mine", "to_id": "basin_well_road", "required_clear_id": "orc_mine_witness"},
			{"from_id": "basin_well_road", "to_id": "assembly_town", "required_clear_id": "orc_well_road"},
			{"from_id": "assembly_town", "to_id": "spanwater_lock", "required_clear_id": "orc_well_road"},
		],
	},
	"sova": {
		"start": "cairnspine_camp",
		"waypoints": {
			"cairnspine_camp": {
				"id": "cairnspine_camp", "label": "Cairnspine Camp", "kind": WaypointKind.CAMP,
				"map_position": Vector2(0.2, 0.49),
			},
			"year_one_mine": {
				"id": "year_one_mine", "label": "The Mine", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.49, 0.34), "mission_id": "sova_mine_tunnels",
			},
			"cairnspine_assembly": {
				"id": "cairnspine_assembly", "label": "Cairnspine Assembly", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.78, 0.55), "mission_id": "sova_public_record",
			},
			"spanwater_bank": {
				"id": "spanwater_bank", "label": "Spanwater High Bank", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.62, 0.63), "beat": "sova_handover_interlude",
			},
			"cairnspine_pass": {
				"id": "cairnspine_pass", "label": "Cairnspine Pass", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.52, 0.13), "mission_id": "sova_vault_return",
			},
		},
		"routes": [
			{"from_id": "cairnspine_camp", "to_id": "year_one_mine"},
			{"from_id": "year_one_mine", "to_id": "cairnspine_assembly", "required_clear_id": "sova_mine_tunnels"},
			{"from_id": "cairnspine_assembly", "to_id": "spanwater_bank", "required_clear_id": "sova_public_record"},
			{"from_id": "spanwater_bank", "to_id": "cairnspine_pass", "required_clear_id": "sova_public_record"},
		],
	},
	"ilyra": {
		"start": "moonwash_fleet",
		"waypoints": {
			"moonwash_fleet": {
				"id": "moonwash_fleet", "label": "Moonwash Fleet", "kind": WaypointKind.CAMP,
				"map_position": Vector2(0.05, 0.42),
			},
			"moonwash_harbor": {
				"id": "moonwash_harbor", "label": "Moonwash Harbor", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.07, 0.56), "mission_id": "ilyra_moonwash_rescue",
			},
			"pilot_villages": {
				"id": "pilot_villages", "label": "Pilot Villages", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.06, 0.70), "beat": "ilyra_record_interlude",
			},
			"survey_shore": {
				"id": "survey_shore", "label": "Survey Shore", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.11, 0.80), "mission_id": "ilyra_coast_survey",
			},
			"new_channel": {
				"id": "new_channel", "label": "The New Channel", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.40, 0.72),
			},
			"spanwater_lock": {
				"id": "spanwater_lock", "label": "Spanwater Lock", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.62, 0.63), "mission_id": "ilyra_spanwater_evacuation",
			},
		},
		"routes": [
			{"from_id": "moonwash_fleet", "to_id": "moonwash_harbor"},
			{"from_id": "moonwash_harbor", "to_id": "pilot_villages", "required_clear_id": "ilyra_moonwash_rescue"},
			{"from_id": "pilot_villages", "to_id": "survey_shore", "required_clear_id": "ilyra_moonwash_rescue"},
			{"from_id": "survey_shore", "to_id": "new_channel", "required_clear_id": "ilyra_coast_survey"},
			{"from_id": "new_channel", "to_id": "spanwater_lock", "required_clear_id": "ilyra_coast_survey"},
		],
	},
	"neris": {
		"start": "deepwood_edge",
		"waypoints": {
			"deepwood_edge": {
				"id": "deepwood_edge", "label": "Deepwood Edge", "kind": WaypointKind.CAMP,
				"map_position": Vector2(0.22, 0.90),
			},
			"isolated_grove": {
				"id": "isolated_grove", "label": "The Isolated Grove", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.38, 0.84), "mission_id": "neris_failing_grove",
			},
			"town_nursery": {
				"id": "town_nursery", "label": "Town Nursery", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.47, 0.78), "beat": "neris_nursery_interlude",
			},
			"spanwater_lock": {
				"id": "spanwater_lock", "label": "Spanwater Lock", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.62, 0.63), "mission_id": "neris_spanwater_feeder",
			},
			"cairnspine_pass": {
				"id": "cairnspine_pass", "label": "Cairnspine Pass", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.52, 0.13), "mission_id": "neris_cairnspine_passage",
			},
		},
		"routes": [
			{"from_id": "deepwood_edge", "to_id": "isolated_grove"},
			{"from_id": "isolated_grove", "to_id": "town_nursery", "required_clear_id": "neris_failing_grove"},
			{"from_id": "town_nursery", "to_id": "spanwater_lock", "required_clear_id": "neris_failing_grove"},
			{"from_id": "spanwater_lock", "to_id": "cairnspine_pass", "required_clear_id": "neris_spanwater_feeder"},
		],
	},
	"sereth": {
		"start": "still_court",
		"waypoints": {
			"still_court": {
				"id": "still_court", "label": "The Still Court", "kind": WaypointKind.CAMP,
				"map_position": Vector2(0.94, 0.10),
			},
			"the_cut": {
				"id": "the_cut", "label": "The Cut", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.85, 0.24), "mission_id": "sereth_voices_at_the_cut",
			},
			"court_chambers": {
				"id": "court_chambers", "label": "Court Chambers", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.93, 0.27), "beat": "sereth_writ_interlude",
			},
			"boundary_post": {
				"id": "boundary_post", "label": "Boundary Post", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.68, 0.19), "mission_id": "sereth_pass_writ",
			},
			"cairnspine_pass": {
				"id": "cairnspine_pass", "label": "Cairnspine Pass", "kind": WaypointKind.BATTLEFIELD,
				"map_position": Vector2(0.52, 0.13), "mission_id": "sereth_no_proxy",
			},
		},
		"routes": [
			{"from_id": "still_court", "to_id": "the_cut"},
			{"from_id": "the_cut", "to_id": "court_chambers", "required_clear_id": "sereth_voices_at_the_cut"},
			{"from_id": "court_chambers", "to_id": "boundary_post", "required_clear_id": "sereth_voices_at_the_cut"},
			{"from_id": "boundary_post", "to_id": "cairnspine_pass", "required_clear_id": "sereth_pass_writ"},
		],
	},
}

var _campaign_id: String
var _map: Dictionary
var _current_id := ""
var _visited := PackedStringArray()


func _init(campaign_id: String, saved_waypoint_id := "", completed_ids := PackedStringArray()) -> void:
	_campaign_id = campaign_id
	_map = _MAPS.get(campaign_id, {})
	if not _map.is_empty():
		_current_id = _map.start
		_visited.append(_current_id)
		if saved_waypoint_id != _current_id and is_waypoint_reachable(saved_waypoint_id, completed_ids):
			_current_id = saved_waypoint_id
			# Restoration knows the saved location, not how the party travelled there.
			_visited.append(_current_id)


func campaign_id() -> String:
	return _campaign_id


func current_waypoint_id() -> String:
	return _current_id


func visited_waypoint_ids() -> PackedStringArray:
	return _visited.duplicate()


## Returns an empty dictionary for a waypoint not on this campaign's map.
func waypoint(waypoint_id: String) -> Dictionary:
	var nodes: Dictionary = _map.get("waypoints", {})
	var data: Dictionary = nodes.get(waypoint_id, {})
	return data.duplicate()


func waypoints() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var nodes: Dictionary = _map.get("waypoints", {})
	for data: Dictionary in nodes.values():
		all.append(data.duplicate())
	return all


func routes() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for edge: Dictionary in _map.get("routes", []):
		all.append(edge.duplicate())
	return all


## A battlefield's briefing is a separate action, not an effect of travel.
func mission_at_current_waypoint() -> String:
	return waypoint(_current_id).get("mission_id", "")


## Check a saved destination without travelling or adding intermediate visits.
func is_waypoint_reachable(waypoint_id: String, completed_ids: PackedStringArray) -> bool:
	if _map.is_empty() or not _map.waypoints.has(waypoint_id):
		return false
	var seen := {}
	var pending: Array[String] = [_map.start]
	while not pending.is_empty():
		var point: String = pending.pop_front()
		if point == waypoint_id:
			return true
		if seen.has(point):
			continue
		seen[point] = true
		for option in _routes_from(point, completed_ids):
			if option.is_open and not seen.has(option.waypoint_id):
				pending.append(option.waypoint_id)
	return false


## Includes locked adjacent routes so the map can display the blocked connection.
func route_options(completed_ids: PackedStringArray) -> Array[Dictionary]:
	return _routes_from(_current_id, completed_ids)


func _routes_from(point: String, completed_ids: PackedStringArray) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for edge: Dictionary in _map.get("routes", []):
		var other_id: String
		if edge.from_id == point:
			other_id = edge.to_id
		elif edge.to_id == point:
			other_id = edge.from_id
		else:
			continue
		var required_clear_id: String = edge.get("required_clear_id", "")
		options.append({
			"waypoint_id": other_id,
			"required_clear_id": required_clear_id,
			"is_open": required_clear_id.is_empty() or completed_ids.has(required_clear_id),
		})
	return options


## Move the token by exactly one open edge. Only arrival changes position or visits.
func travel_to(waypoint_id: String, completed_ids: PackedStringArray) -> TravelResult:
	if _map.is_empty():
		return TravelResult.NO_MAP
	if waypoint_id == _current_id:
		return TravelResult.ALREADY_HERE
	if not _map.waypoints.has(waypoint_id):
		return TravelResult.UNKNOWN_WAYPOINT
	for option in route_options(completed_ids):
		if option.waypoint_id == waypoint_id:
			if not option.is_open:
				return TravelResult.LOCKED
			_current_id = waypoint_id
			if not _visited.has(waypoint_id):
				_visited.append(waypoint_id)
			return TravelResult.ARRIVED
	return TravelResult.NOT_ADJACENT
