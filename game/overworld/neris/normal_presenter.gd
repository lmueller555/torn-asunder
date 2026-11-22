extends RefCounted
## Optional local presenter behind the existing ordinary title factory.
const Title:=preload("res://game/title_screen.gd")
const World:=preload("res://game/campaign_world.gd")
const View:=preload("res://game/overworld/marches_overworld_view.gd")
const Transfer:=preload("res://game/overworld/neris/neris_finale_transfer.gd")
const Grove:=preload("res://game/overworld/neris/grove_opening_view.gd")
const Approach:=preload("res://game/overworld/neris/approach_map.gd")
const Finale:=preload("res://game/overworld/neris/greyhollow_map.gd")
const Bake:=preload("res://game/overworld/neris/bake_loader.gd")
const PendingPanel:=preload("res://game/overworld/neris/loading_panel.gd")
const START:=preload("res://game/overworld/neris/grove_relief.tscn")
const BOUNDARY:=preload("res://game/overworld/neris/cairnspine_relief.tscn")
const MINE:=preload("res://game/overworld/neris/neris_greyhollow_sector.tscn")
const GROVE:="isolated_grove_nursery"
const GROVE_CLEAR:="neris_failing_grove"
var _host:Title
var _transfer:=Transfer.new()
var _terrain_bake:=Bake.new()
var _token:=0
var _epoch:=0
var _source:View
var _source_update_mode:=SubViewport.UPDATE_WHEN_VISIBLE
var _prepared:Node3D
var _prepared_id:=""
var _worker:Node3D
var _panel:PendingPanel
var _first_requested_usec:=0
var _first_frame_ms:=-1.
var _last_ready_ms:=-1.
var _last_pack_reason:=""
var _cancel_response_ms:=-1.
var _cancel_requested_usec:=0
var _requests:=0
var _physical_builds:=0
var _last_slice_usec:=0
var _last_yields:=0
var _row_compute_usec:=0
var _frame_wait_usec:=0
var _mesh_commit_usec:=0
var _settlement_usec:=0
var _return_page:=Title.Page.TITLE
var _return_focus:=""

func _init(host:Title)->void:
	_host=host
	_return_page=host._page
	var focus:=host.get_viewport().gui_get_focus_owner()
	_return_focus=String(focus.name) if focus else ""

func _is_boundary_view(id:String)->bool:
	return id==Transfer.POST or (id==GROVE and GROVE_CLEAR in _host._profile.completed_missions(Transfer.NERIS))

func is_prepared()->bool:
	return is_instance_valid(_prepared) and _prepared_id==_host._campaign_world.current_waypoint_id()

func choose_map(world:World)->View:
	if not world or world.campaign_id()!=Transfer.NERIS or not is_prepared():
		return null
	var id:=world.current_waypoint_id()
	var candidate:=_prepared
	_prepared=null
	_prepared_id=""
	var map:View
	if id==Transfer.MINE:
		map=Finale.new()
	elif _is_boundary_view(id):
		map=Approach.new()
	elif id in ["grove_camp",GROVE]:
		map=Grove.new()
	else:
		candidate.free()
		return null
	map.prepared=candidate
	if not map.build():
		map.free()
		return null
	return map

func schedule_local_mount()->bool:
	if is_instance_valid(_panel):
		# Duplicate request for this exact pending operation is idempotent.
		return true
	var state:=_host._campaign_world
	if not state or state.campaign_id()!=Transfer.NERIS:
		return false
	_epoch+=1
	_requests+=1
	_first_requested_usec=Time.get_ticks_usec()
	_first_frame_ms=-1.
	var tag:=_epoch
	var stage:=_host._stage
	_panel=PendingPanel.new()
	stage.add_child(_panel)
	var id:=state.current_waypoint_id()
	_panel.build(state.waypoint(id).label,state.waypoint(id).label)
	_panel.cancelled.connect(_cancel_local.bind(tag))
	_prepare_local.call_deferred(tag,state.get_instance_id(),state.travel_epoch(),stage.get_instance_id(),id)
	return true

func _prepare_local(tag:int,state_id:int,travel_epoch:int,stage_id:int,id:String)->void:
	# Cancel releases the host's presenter reference before the first frame.
	# Retain this coroutine owner until its epoch checks and cleanup finish.
	var pending:=self
	# Do not allocate heavy scenery before the ordinary loading frame exists.
	if DisplayServer.get_name()=="headless":
		await _host.get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	_first_frame_ms=(Time.get_ticks_usec()-_first_requested_usec)/1000.
	if not pending._valid_local(tag,state_id,travel_epoch,stage_id):
		_resume_after_stale(tag,stage_id)
		return
	var scene:PackedScene=MINE if id==Transfer.MINE else (BOUNDARY if _is_boundary_view(id) else START)
	var candidate:=scene.instantiate() as Node3D
	var staged:Node3D=await _stage_candidate(candidate,tag)
	if not pending._valid_local(tag,state_id,travel_epoch,stage_id):
		if is_instance_valid(staged): staged.free()
		_resume_after_stale(tag,stage_id)
		return
	_drop_panel()
	if not staged:
		_host.call("_neris_map_failed")
		return
	_prepared=staged
	_prepared_id=id
	_host.call("_complete_neris_map")
	_last_ready_ms=(Time.get_ticks_usec()-_first_requested_usec)/1000.

func _resume_after_stale(tag:int,stage_id:int)->void:
	if tag==_epoch and is_instance_valid(_host) and stage_id==_host._stage.get_instance_id() and _host._page==Title.Page.WORLD_MAP:
		_drop_panel()
		_host.call("_show_world_map")

func _valid_local(tag:int,state_id:int,travel_epoch:int,stage_id:int)->bool:
	if tag!=_epoch or not is_instance_valid(_host) or _host._page!=Title.Page.WORLD_MAP or stage_id!=_host._stage.get_instance_id():
		return false
	var current:=_host._campaign_world
	return current!=null and current.get_instance_id()==state_id and current.travel_epoch()==travel_epoch

func _cancel_local(tag:int)->void:
	if tag!=_epoch:
		return
	_cancel_requested_usec=Time.get_ticks_usec()
	_epoch+=1
	_cancel_worker()
	_drop_panel()
	_host.call("_cancel_neris_resume_played")
	if _return_page==Title.Page.LOAD:
		_host._show_load()
	else:
		_host._show_title()
	if not _return_focus.is_empty():
		var target:=_host._stage.find_child(_return_focus,true,false) as Control
		if target: target.grab_focus()
	_cancel_response_ms=(Time.get_ticks_usec()-_cancel_requested_usec)/1000.

func on_mounted(map:View)->void:
	var world:=_host._campaign_world
	var here:=world.current_waypoint_id()
	var clears:=_host._profile.completed_missions(Transfer.NERIS)
	if here==Transfer.POST and Transfer.CLEAR in clears:
		map.install_boundary_selector(Transfer.POST,Transfer.MINE,"Travel to Greyhollow")
	elif here==Transfer.MINE:
		map.install_boundary_selector(Transfer.MINE,Transfer.POST,"Return to Boundary Post")
	map.boundary_requested.connect(_begin.bind(map))
	map.boundary_cancel_requested.connect(_cancel_transfer)

func on_local_arrival()->bool:
	var world:=_host._campaign_world
	if not world or world.campaign_id()!=Transfer.NERIS:
		return false
	if _host._profile.record_world_waypoint(world)!=OK:
		_host._campaign_world=_host._profile.load_campaign_world(Transfer.NERIS)
		_host._campaign_warning="The arrived waypoint could not be saved. The party remains at its previous site."
		_host._show_world_map()
	elif not _host._show_waypoint_intermission(false) and world.current_waypoint_id()==GROVE and _host._stage.get_child(0).get_script()==Grove and GROVE_CLEAR in _host._profile.completed_missions(Transfer.NERIS):
		_host._show_world_map()
	return true

func _begin(destination:String,map:View)->void:
	if _token!=0 or _host._page!=Title.Page.WORLD_MAP or map.get_parent()!=_host._stage:
		return
	var token:=_transfer.begin(_host._profile,_host._campaign_world,destination)
	if token==0:
		return
	_token=token
	_source=map
	_epoch+=1
	_requests+=1
	_first_requested_usec=Time.get_ticks_usec()
	_first_frame_ms=-1.
	_source_update_mode=map.render_viewport.render_target_update_mode
	# The already presented origin remains on screen. Do not repeatedly
	# rerasterize the exact same 3D view while the visible HUD updates.
	map.render_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	map.set_boundary_pending(true)
	_observe_transfer_frame.call_deferred(token,_epoch)
	_host.get_tree().create_timer(.15,false).timeout.connect(_finish.bind(token,_epoch,destination),CONNECT_ONE_SHOT)

func _observe_transfer_frame(token:int,epoch:int)->void:
	if DisplayServer.get_name()=="headless":
		await _host.get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if _valid_transfer(token,epoch):
		_first_frame_ms=(Time.get_ticks_usec()-_first_requested_usec)/1000.

func _finish(token:int,epoch:int,destination:String)->void:
	if not _valid_transfer(token,epoch):
		return
	var staged:Node3D=await _stage_candidate(_transfer.prepare(token),epoch)
	if not _valid_transfer(token,epoch):
		if is_instance_valid(staged): staged.free()
		return
	var committed:=_transfer.finish(token,_host._campaign_world,staged)
	if committed.outcome!=Transfer.Outcome.COMMITTED:
		if is_instance_valid(staged): staged.free()
		_source.render_viewport.render_target_update_mode=_source_update_mode
		_source.set_boundary_pending(false,"Sector unavailable. Your location is unchanged.")
		_source=null
		_token=0
		return
	_prepared=committed.sector
	_prepared_id=destination
	_host._campaign_world=committed.world
	_source=null
	_token=0
	if not _host._show_waypoint_intermission(false):
		_host._show_world_map()
	_last_ready_ms=(Time.get_ticks_usec()-_first_requested_usec)/1000.

func _valid_transfer(token:int,epoch:int)->bool:
	return _token==token and epoch==_epoch and _host._page==Title.Page.WORLD_MAP and is_instance_valid(_source) and _source.get_parent()==_host._stage

func _stage_candidate(candidate:Node3D,epoch:int)->Node3D:
	if not is_instance_valid(candidate):
		return null
	if not await _terrain_bake.preload_verified(_host.get_tree(),_owns_epoch.bind(epoch),_bake_progress.bind(epoch)):
		candidate.free()
		_last_pack_reason=_terrain_bake.last_reason
		return null
	if not _owns_epoch(epoch):
		candidate.free()
		return null
	_physical_builds+=1
	if not candidate.has_method("prepare_cooperatively"):
		if candidate.has_method("prepare_exact_exterior") and candidate.prepare_exact_exterior():
			return candidate
		candidate.free()
		return null
	candidate.defer_preparation=true
	_worker=candidate
	var room:=SubViewport.new()
	room.own_world_3d=true
	room.render_target_update_mode=SubViewport.UPDATE_DISABLED
	_host.add_child(room)
	room.add_child(candidate)
	var report:=_progress.bind(epoch)
	candidate.preparation_progress.connect(report)
	var east:=candidate.scene_file_path==BOUNDARY.resource_path
	var ready:bool=await candidate.prepare_from_bake(_terrain_bake.chunk_set(east))
	_last_slice_usec=candidate.max_slice_usec
	_last_yields=candidate.build_slices
	_row_compute_usec=candidate.actual_row_compute_usec
	_frame_wait_usec=candidate.actual_frame_wait_usec
	_mesh_commit_usec=candidate.mesh_commit_usec
	_settlement_usec=candidate.settlement_usec
	candidate.preparation_progress.disconnect(report)
	room.remove_child(candidate)
	room.queue_free()
	if _worker==candidate:
		_worker=null
	if not ready or epoch!=_epoch:
		candidate.free()
		return null
	return candidate

func _owns_epoch(tag:int)->bool:
	return tag==_epoch and _host._page==Title.Page.WORLD_MAP

func _bake_progress(done:int,total:int,tag:int)->void:
	if not _owns_epoch(tag):
		return
	if is_instance_valid(_panel):
		_panel.update_progress(done,total)
		_panel.detail.text="Checking map assets · %d%%"%int(100.0*done/total)
	if is_instance_valid(_source):
		_source.status_label.text="Checking map assets · %d%%. Your party is still here."%int(100.0*done/total)

func _progress(done:int,total:int,epoch:int)->void:
	if epoch!=_epoch:
		return
	if is_instance_valid(_panel):
		_panel.update_progress(done,total)
	if is_instance_valid(_source):
		_source.status_label.text="Preparing destination (%d%%). Your party is still here."%int(100.0*done/total)

func _cancel_worker()->void:
	if is_instance_valid(_worker):
		_worker.preparation_cancelled=true

func _cancel_transfer()->void:
	if _token!=0: _transfer.cancel(_token)
	_cancel_requested_usec=Time.get_ticks_usec()
	_epoch+=1
	_token=0
	_cancel_worker()
	if is_instance_valid(_source):
		_source.set_boundary_pending(false)
	_source=null
	_cancel_response_ms=(Time.get_ticks_usec()-_cancel_requested_usec)/1000.

func _drop_panel()->void:
	if is_instance_valid(_panel):
		if _panel.get_parent(): _panel.get_parent().remove_child(_panel)
		_panel.queue_free()
	_panel=null

func close()->void:
	_cancel_transfer()
	_drop_panel()
	if is_instance_valid(_prepared): _prepared.free()
	_prepared=null
	_prepared_id=""
