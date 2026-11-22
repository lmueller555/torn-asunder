extends RefCounted
## Raska-only explicit inter-sector seam. No world-space interpolation.
const Profile:=preload("res://game/profile_store.gd")
const World:=preload("res://game/campaign_world.gd")
const Catalog:=preload("res://game/campaign_missions.gd")
const GREY:="year_one_mine"
const WELL:="basin_well_road"
const LOCK:="spanwater_lock"
const MINE_CLEAR:="orc_mine_witness"
const WELL_CLEAR:="orc_well_road"
const LOCK_MISSION:="orc_spanwater_release"
const RASKA:="raska"
const LAND:={
	GREY:preload("res://game/overworld/raska/greyhollow_context.tscn"),
	WELL:preload("res://game/overworld/raska/well_road.tscn"),
	LOCK:preload("res://game/overworld/raska/spanwater_north.tscn")}
enum Status {STALE,PREFLIGHT_FAILED,SAVE_FAILED,COMMITTED}
class Result:
	var status:Status
	var error:Error
	var world:World
	var sector:Node3D
	var point:=Vector3.INF
	func _init(s:Status,e:=OK)->void:
		status=s
		error=e
var _serial:=0
var _active:=0
var _target:=""
var _origin:World
var _epoch:=0
var _view:Node3D
var _store:Profile

static func required_clear(src:String,dst:String)->String:
	if (src==GREY and dst==WELL) or (src==WELL and dst==GREY):
		return MINE_CLEAR
	if (src==WELL and dst==LOCK) or (src==LOCK and dst==WELL):
		return WELL_CLEAR
	return ""

func begin(store:Profile,origin:World,dst:String,scene:Node3D,party:Vector3)->int:
	if _active or not store or not origin or origin.get_script()!=World or origin.campaign_id()!=RASKA: return 0
	var src:=origin.current_waypoint_id()
	var clear:=required_clear(src,dst)
	if clear.is_empty() or not _mounted(scene,src) or not party.is_finite(): return 0
	if origin.waypoint(GREY).get("mission_id")!=MINE_CLEAR or origin.waypoint(WELL).get("mission_id")!=WELL_CLEAR or origin.waypoint(LOCK).get("mission_id")!=LOCK_MISSION: return 0
	var end:=_point(scene,src,dst)
	if not end.is_finite() or scene.to_global(end).distance_to(party)>2.5: return 0
	for route in origin.route_options(store.completed_missions(RASKA)):
		if route.waypoint_id==dst and route.is_open and route.required_clear_id==clear:
			_serial+=1
			_active=_serial
			_target=dst
			_origin=origin
			_epoch=origin.travel_epoch()
			_view=scene
			_store=store
			return _active
	return 0

func cancel(token:int)->bool:
	if token<=0 or token!=_active: return false
	_reset()
	return true

func prepare(token:int)->Node3D:
	if token<=0 or token!=_active: return null
	var resource:PackedScene=LAND[_target]
	var candidate:=resource.instantiate() as Node3D
	if not _valid(candidate) or not _point(candidate,_target,_origin.current_waypoint_id()).is_finite():
		if candidate: candidate.free()
		return null
	return candidate

func finish(token:int,world:World,candidate:Node3D)->Result:
	if token<=0 or token!=_active: return Result.new(Status.STALE)
	if world!=_origin or world.travel_epoch()!=_epoch or not _mounted(_view,_origin.current_waypoint_id()):
		_reset()
		return Result.new(Status.STALE)
	var foot:=_point(candidate,_target,_origin.current_waypoint_id()) if _valid(candidate) else Vector3.INF
	if not foot.is_finite():
		_reset()
		return Result.new(Status.PREFLIGHT_FAILED,ERR_CANT_CREATE)
	var transfer:=_store.commit_world_edge(_origin,_target)
	_reset()
	if transfer.error!=OK: return Result.new(Status.SAVE_FAILED,transfer.error)
	var result:=Result.new(Status.COMMITTED)
	result.world=transfer.world
	result.sector=candidate
	result.point=foot
	return result

func _mounted(scene:Node3D,waypoint:String)->bool:
	return is_instance_valid(scene) and LAND.has(waypoint) and scene.scene_file_path==LAND[waypoint].resource_path and scene.is_inside_tree() and scene.is_visible_in_tree()

func _valid(candidate:Node3D)->bool:
	if not is_instance_valid(candidate) or candidate.get_parent() or candidate.scene_file_path!=LAND[_target].resource_path or not candidate.get_node_or_null(^"Camera") is Camera3D: return false
	return candidate.prepare_exact_exterior() if _target==GREY else candidate.prepare_exact_land()

func _point(scene:Node3D,waypoint:String,other:String)->Vector3:
	if waypoint==GREY: return scene.arrival_ground
	if waypoint==LOCK: return scene.north_ground
	return scene.west_ground if other==GREY else scene.east_ground

func _reset()->void:
	_active=0
	_target=""
	_origin=null
	_epoch=0
	_view=null
	_store=null
