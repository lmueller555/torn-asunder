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
		},
		"routes": [
			{"from_id": "marches_camp", "to_id": "year_one_mine"},
			{"from_id": "year_one_mine", "to_id": "marches_road", "required_clear_id": "mara_mine_escort"},
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
				"id": "cairnspine_assembly", "label": "Cairnspine Assembly", "kind": WaypointKind.REGION,
				"map_position": Vector2(0.78, 0.55),
			},
		},
		"routes": [
			{"from_id": "cairnspine_camp", "to_id": "year_one_mine"},
			{"from_id": "year_one_mine", "to_id": "cairnspine_assembly", "required_clear_id": "sova_mine_tunnels"},
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
