extends RefCounted
## Private off-title seam. Confirm the existing edge, preflight the destination
## off-tree, then finish. Only COMMITTED permits replacing the active World.
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const SERETH := "sereth"
const ORIGIN := "still_kingdom_cut"
const TARGET := "cairnspine_boundary_post"
const CLEAR := "sereth_voices_at_the_cut"
const TARGET_MISSION := "sereth_pass_writ"

enum Outcome { STALE, PREFLIGHT_FAILED, SAVE_FAILED, COMMITTED }

## The scene owner supplies its loader's result; this is not a travel or
## graphical audit receipt. An unavailable sector reports an error or null.
class PreparedSector:
	var campaign: String
	var waypoint: String
	var mission: String
	var error: Error

	func _init(id: String, point: String, operation: String, cause: Error) -> void:
		campaign = id
		waypoint = point
		mission = operation
		error = cause

class Result:
	var outcome: Outcome
	var world: World
	var error: Error

	func _init(status: Outcome, moved: World = null, cause := OK) -> void:
		outcome = status
		world = moved
		error = cause

var _serial := 0
var _token := 0
var _profile: Profile
var _origin: World
var _epoch := 0
var _source := ""
var _destination := ""


func begin(profile: Profile, origin: World, destination: String) -> int:
	if _token != 0 or profile == null or origin == null or origin.get_script() != World:
		return 0
	var source := origin.current_waypoint_id()
	if origin.campaign_id() != SERETH or not ((source == ORIGIN and destination == TARGET) \
			or (source == TARGET and destination == ORIGIN)):
		return 0
	if origin.mission_at_current_waypoint() != _mission(source) \
			or origin.waypoint(destination).get("mission_id", "") != _mission(destination):
		return 0
	var clears := profile.completed_missions(SERETH)
	if not clears.has(CLEAR):
		return 0
	for edge in origin.route_options(clears):
		if edge.waypoint_id == destination and edge.is_open and edge.required_clear_id == CLEAR:
			_serial += 1
			_token = _serial
			_profile = profile
			_origin = origin
			_epoch = origin.travel_epoch()
			_source = source
			_destination = destination
			return _token
	return 0


func is_pending() -> bool:
	return _token != 0


func cancel(token: int) -> bool:
	if token == 0 or token != _token:
		return false
	_clear()
	return true


func finish(token: int, active_world: World, prepared: PreparedSector) -> Result:
	if token == 0 or token != _token:
		return Result.new(Outcome.STALE)
	if active_world != _origin or active_world.current_waypoint_id() != _source \
			or active_world.travel_epoch() != _epoch:
		_clear()
		return Result.new(Outcome.STALE)
	if prepared == null or prepared.campaign != SERETH or prepared.waypoint != _destination \
			or prepared.mission != _mission(_destination) or prepared.error != OK:
		var cause := prepared.error if prepared != null and prepared.error != OK else ERR_INVALID_DATA
		_clear()
		return Result.new(Outcome.PREFLIGHT_FAILED, null, cause)
	# ProfileStore rereads the exact disk waypoint and clears, forks the World,
	# and atomically persists just the destination before returning the fork.
	var saved := _profile.commit_world_edge(_origin, _destination)
	_clear()
	if saved.error != OK:
		return Result.new(Outcome.SAVE_FAILED, null, saved.error)
	return Result.new(Outcome.COMMITTED, saved.world)


static func _mission(id: String) -> String:
	return TARGET_MISSION if id == TARGET else CLEAR


func _clear() -> void:
	_token = 0
	_profile = null
	_origin = null
	_epoch = 0
	_source = ""
	_destination = ""
