extends RefCounted
## Explicit, save-first two-way sector handoff. No path or animation is implied
## between these independently authored coordinate frames.
const World:=preload("res://game/campaign_world.gd")
const Profile:=preload("res://game/profile_store.gd")
const Basin:=preload("res://game/overworld/raska/basin_camp.tscn")
const Greyhollow:=preload("res://game/overworld/raska/greyhollow_context.tscn")
const RASKA:="raska"
const CAMP:="basin_camp"
const MINE:="year_one_mine"
const OPENER:="orc_mine_witness"

enum Outcome { STALE, PREFLIGHT_FAILED, SAVE_FAILED, COMMITTED }

class Result:
	var outcome:Outcome
	var world:World
	var sector:Node3D
	var local_arrival:=Vector3.INF
	var error:Error
	func _init(status:Outcome,cause:=OK, moved:World=null,ready:Node3D=null)->void:
		outcome=status
		world=moved
		sector=ready
		error=cause

var _serial:=0
var _token:=0
var _origin:World
var _target:=""
var _epoch:=0
var _profile:Profile

static func is_sector_edge(from:String,to:String)->bool:
	return (from==CAMP and to==MINE) or (from==MINE and to==CAMP)

func begin(profile:Profile,origin:World,destination:String,visual_origin:Node3D,party_position:Vector3)->int:
	if _token!=0 or not profile or not origin or origin.get_script()!=World:
		return 0
	if origin.campaign_id()!=RASKA or not is_sector_edge(origin.current_waypoint_id(),destination):
		return 0
	if origin.waypoint(MINE).get("mission_id")!=OPENER:
		return 0
	if not is_instance_valid(visual_origin) or not visual_origin.is_inside_tree() or not visual_origin.is_visible_in_tree() or not party_position.is_finite():
		return 0
	var foot:=Vector3.INF
	if destination==MINE and visual_origin.scene_file_path==Basin.resource_path:
		foot=visual_origin.to_global(visual_origin.world(visual_origin.RIM))
	elif destination==CAMP and visual_origin.scene_file_path==Greyhollow.resource_path:
		foot=visual_origin.to_global(visual_origin.arrival_ground)
	if not foot.is_finite() or foot.distance_to(party_position)>2.5:
		return 0
	var clears:=profile.completed_missions(RASKA)
	for edge in origin.route_options(clears):
		if edge.waypoint_id==destination and edge.is_open and edge.required_clear_id.is_empty():
			_serial+=1
			_token=_serial
			_profile=profile
			_origin=origin
			_target=destination
			_epoch=origin.travel_epoch()
			return _token
	return 0

func is_pending()->bool:
	return _token!=0

func cancel(token:int)->bool:
	if token==0 or token!=_token:
		return false
	_clear()
	return true

## The owner must keep the current view mounted and wait for this detached
## preflight. A live owner can schedule the preparation one frame after the
## confirmation so Back actually has a cancellation window.
func prepare(token:int)->Node3D:
	if token==0 or token!=_token:
		return null
	var sector:Node3D=(Greyhollow if _target==MINE else Basin).instantiate() as Node3D
	if not _valid(sector):
		if sector: sector.free()
		return null
	return sector

## Ownership transfers only on COMMITTED. On failure the owner frees its
## candidate; stale callbacks never destroy a different pending operation.
func finish(token:int,active_world:World,prepared:Node3D)->Result:
	if token==0 or token!=_token:
		return Result.new(Outcome.STALE)
	if active_world!=_origin or active_world.travel_epoch()!=_epoch:
		_clear()
		return Result.new(Outcome.STALE)
	if not _valid(prepared):
		_clear()
		return Result.new(Outcome.PREFLIGHT_FAILED,ERR_CANT_CREATE)
	var committed:=_profile.commit_world_edge(_origin,_target)
	_clear()
	if committed.error!=OK:
		return Result.new(Outcome.SAVE_FAILED,committed.error)
	var result:=Result.new(Outcome.COMMITTED,OK,committed.world,prepared)
	result.local_arrival=prepared.arrival_ground if committed.world.current_waypoint_id()==MINE else Vector3(prepared.RIM.x,prepared.COURSE_LEVELS[-1],prepared.RIM.y)
	return result

func _valid(node:Node3D)->bool:
	if not is_instance_valid(node) or node.is_inside_tree() or node.get_parent()!=null:
		return false
	if not node.get_node_or_null(^"Camera") is Camera3D:
		return false
	if _target==MINE:
		return node.scene_file_path==Greyhollow.resource_path and node.prepare_exact_exterior()
	return node.scene_file_path==Basin.resource_path

func _clear()->void:
	_token=0
	_origin=null
	_target=""
	_profile=null
	_epoch=0
