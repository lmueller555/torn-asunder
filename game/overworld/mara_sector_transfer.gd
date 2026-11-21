extends RefCounted
## Private seam: confirmed 3D sector handoff only. No art, dialogue, or UI.
## Call begin from explicit map confirm, preflight the target sector, then finish.
## Only finish returning COMMITTED may replace the title's canonical World.

const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const CROSSING := "marches_crossing"
const ROAD := "moonwash_road"
const CLEAR := "mara_grain_crossing"

enum Outcome { STALE, PREFLIGHT_FAILED, SAVE_FAILED, COMMITTED }

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
var _origin_id := ""
var _destination := ""
var _origin_epoch := 0


## Returns 0 for a rejected request, including a repeated confirm.
func begin(profile: Profile, origin: World, destination: String) -> int:
	if _token != 0 or profile == null or origin == null or origin.get_script() != World:
		return 0
	if origin.campaign_id() != "mara":
		return 0
	var from := origin.current_waypoint_id()
	if not ((from == CROSSING and destination == ROAD) or (from == ROAD and destination == CROSSING)):
		return 0
	var clears := profile.completed_missions("mara")
	if not clears.has(CLEAR):
		return 0
	var valid := false
	for edge in origin.route_options(clears):
		if edge.waypoint_id == destination and edge.is_open and edge.required_clear_id == CLEAR:
			valid = true
			break
	if not valid:
		return 0
	_serial += 1
	_token = _serial
	_profile = profile
	_origin = origin
	_origin_id = from
	_destination = destination
	_origin_epoch = origin.travel_epoch()
	return _token


func is_pending() -> bool:
	return _token != 0


func cancel(token: int) -> bool:
	if token == 0 or token != _token:
		return false
	_clear()
	return true


## A stale callback must not consume the current pending operation.
## The caller owns the ready destination scene and keeps the origin view until OK.
func finish(token: int, active_world: World, preflight_ok: bool) -> Result:
	if token == 0 or token != _token:
		return Result.new(Outcome.STALE)
	if active_world != _origin or active_world.current_waypoint_id() != _origin_id \
			or active_world.travel_epoch() != _origin_epoch:
		_clear()
		return Result.new(Outcome.STALE)
	if not preflight_ok:
		_clear()
		return Result.new(Outcome.PREFLIGHT_FAILED)
	var saved := _profile.commit_world_edge(_origin, _destination)
	_clear()
	if saved.error != OK:
		return Result.new(Outcome.SAVE_FAILED, null, saved.error)
	return Result.new(Outcome.COMMITTED, saved.world)


func _clear() -> void:
	_token = 0
	_profile = null
	_origin = null
	_origin_id = ""
	_destination = ""
	_origin_epoch = 0
