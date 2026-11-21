extends RefCounted
## A development overworld destination and its existing campaign services.

const World := preload("res://game/campaign_world.gd")
const ROAD_CAMP := "marches_road_camp"
const ROAD := "marches_road"
const MINE_CLEAR := "mara_mine_escort"

enum Service { COMBAT_DRILLS, UNIT_PROGRESSION }

class Definition:
	var id: String
	var junction_id: String
	var label: String
	var services: Array[Service]

	func _init(camp_id: String, junction: String, display_name: String, offered: Array[Service]) -> void:
		id = camp_id
		junction_id = junction
		label = display_name
		services = offered.duplicate()


static func available_for(campaign_id: String, confirmed_clears: PackedStringArray,
		greyhollow_reveal_completed: bool) -> Definition:
	if campaign_id != "mara" or not confirmed_clears.has(MINE_CLEAR) or not greyhollow_reveal_completed:
		return null
	return Definition.new(ROAD_CAMP, ROAD, "Marches Road Camp", [Service.COMBAT_DRILLS, Service.UNIT_PROGRESSION])


## Projects one dead end for 3D navigation. The canonical world stays at the junction
## while inside the camp and remains the sole source for title-screen persistence.
class MapWorld extends World:
	var _world: World
	var _camp: Definition
	var _inside := false

	func _init(world: World, camp: Definition, resume_camp: bool) -> void:
		super("")
		_world = world
		_camp = camp
		_inside = resume_camp and world.current_waypoint_id() == camp.junction_id

	func campaign_id() -> String:
		return _world.campaign_id()

	func current_waypoint_id() -> String:
		return _camp.id if _inside else _world.current_waypoint_id()

	func visited_waypoint_ids() -> PackedStringArray:
		return _world.visited_waypoint_ids()

	func waypoint(id: String) -> Dictionary:
		if id != _camp.id:
			return _world.waypoint(id)
		return {"id": _camp.id, "label": _camp.label, "kind": WaypointKind.CAMP,
			"map_position": _world.waypoint(_camp.junction_id).map_position}

	func waypoints() -> Array[Dictionary]:
		var result := _world.waypoints()
		result.append(waypoint(_camp.id))
		return result

	func routes() -> Array[Dictionary]:
		var result := _world.routes()
		result.append({"from_id": _camp.junction_id, "to_id": _camp.id})
		return result

	func mission_at_current_waypoint() -> String:
		return "" if _inside else _world.mission_at_current_waypoint()

	func is_waypoint_reachable(id: String, completed_ids: PackedStringArray) -> bool:
		return _world.is_waypoint_reachable(_camp.junction_id if id == _camp.id else id, completed_ids)

	func route_options(completed_ids: PackedStringArray) -> Array[Dictionary]:
		if _inside:
			return [_spur_option(_camp.junction_id)]
		var result := _world.route_options(completed_ids)
		if _world.current_waypoint_id() == _camp.junction_id:
			result.append(_spur_option(_camp.id))
		return result

	func travel_to(id: String, completed_ids: PackedStringArray) -> TravelResult:
		if _inside:
			if id == _camp.id:
				return TravelResult.ALREADY_HERE
			if id != _camp.junction_id:
				return TravelResult.UNKNOWN_WAYPOINT if _world.waypoint(id).is_empty() else TravelResult.NOT_ADJACENT
			_inside = false
			return TravelResult.ARRIVED
		if id != _camp.id:
			return _world.travel_to(id, completed_ids)
		if _world.current_waypoint_id() != _camp.junction_id:
			return TravelResult.NOT_ADJACENT
		_inside = true
		return TravelResult.ARRIVED

	func _spur_option(id: String) -> Dictionary:
		return {"waypoint_id": id, "is_open": true, "required_clear_id": ""}
