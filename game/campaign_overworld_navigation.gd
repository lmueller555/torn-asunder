extends RefCounted
## Transient selection and travel for an authoritative CampaignWorld session.
## The shell can save and resolve dialogue on arrival before handling a briefing.

signal waypoint_arrived(waypoint_id: String)

const World := preload("res://game/campaign_world.gd")

enum Action { NONE, TRAVEL, BRIEFING, CAMP, LOCKED, NO_ROUTE }

var _world: World
var _selected_id := ""
var _completed := PackedStringArray()
var _travel_origin := ""
var _destination := ""
var _elapsed := 0.0
var _duration := 0.0


func _init(world: World, completed_ids: PackedStringArray) -> void:
	_world = world
	set_completed_ids(completed_ids)
	reset()


func reset() -> void:
	cancel_travel()
	_selected_id = _world.current_waypoint_id()


func set_completed_ids(completed_ids: PackedStringArray) -> void:
	_completed = completed_ids.duplicate()


func selected_waypoint_id() -> String:
	return _selected_id


func select(waypoint_id: String) -> bool:
	if is_travelling() or _world.waypoint(waypoint_id).is_empty():
		return false
	_selected_id = waypoint_id
	return true


## Choose in the view's projected coordinates, without coupling navigation to a camera.
func select_in_direction(direction: Vector2, projected: Dictionary[String, Vector2], view_width: float) -> bool:
	if is_travelling() or direction.is_zero_approx() or not projected.has(_selected_id):
		return false
	var origin := projected[_selected_id]
	var heading := direction.normalized()
	var best_score := -INF
	var best_id := ""
	for waypoint in _world.waypoints():
		var id: String = waypoint.id
		if id == _selected_id or not projected.has(id):
			continue
		var offset := projected[id] - origin
		var alignment := offset.normalized().dot(heading)
		if alignment < 0.22:
			continue
		var score := alignment * 2.0 - offset.length() / maxf(view_width, 1.0)
		if score > best_score:
			best_score = score
			best_id = id
	return select(best_id)


## Describes what a fresh confirmation would do. Reading this never opens a screen.
func action() -> Action:
	if is_travelling() or _selected_id.is_empty():
		return Action.NONE
	if _selected_id == _world.current_waypoint_id():
		if not _world.mission_at_current_waypoint().is_empty():
			return Action.BRIEFING
		if _world.waypoint(_selected_id).kind == World.WaypointKind.CAMP:
			return Action.CAMP
		return Action.NONE
	for route in _world.route_options(_completed):
		if route.waypoint_id == _selected_id:
			return Action.TRAVEL if route.is_open else Action.LOCKED
	return Action.NO_ROUTE


func is_travelling() -> bool:
	return not _destination.is_empty()


## Endpoints are available for path sampling while a trip is active.
func travel_origin_id() -> String:
	return _travel_origin if is_travelling() else ""


func travel_target_id() -> String:
	return _destination


## Ranges from 0 to 1 for an active trip and returns 0 when idle.
func travel_progress() -> float:
	return _elapsed / _duration if is_travelling() else 0.0


## Pass the duration in seconds for an authored path. Null uses normalized map timing.
func start_travel(duration_seconds: Variant = null) -> bool:
	if action() != Action.TRAVEL:
		return false
	var origin := _world.current_waypoint_id()
	var duration: float
	if duration_seconds == null:
		duration = clampf(_point(origin).distance_to(_point(_selected_id)) / 0.55, 0.35, 1.4)
	else:
		if typeof(duration_seconds) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		duration = float(duration_seconds)
		if not is_finite(duration) or duration <= 0.0:
			return false
	_travel_origin = origin
	_destination = _selected_id
	_elapsed = 0.0
	_duration = duration
	return true


func cancel_travel() -> bool:
	if not is_travelling():
		return false
	_destination = ""
	return true


## Commits at most one edge. The arrival callback observes the committed world and idle travel.
func advance(delta: float) -> void:
	if not is_travelling() or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = minf(_elapsed + delta, _duration)
	if _elapsed < _duration:
		return
	var destination := _destination
	_destination = ""
	if _world.current_waypoint_id() == _travel_origin \
			and _world.travel_to(destination, _completed) == World.TravelResult.ARRIVED:
		waypoint_arrived.emit(destination)


func token_map_position() -> Vector2:
	if not is_travelling():
		return _point(_world.current_waypoint_id())
	return _point(_travel_origin).lerp(_point(_destination), travel_progress())


func _point(waypoint_id: String) -> Vector2:
	return _world.waypoint(waypoint_id).get("map_position", Vector2.ZERO)
