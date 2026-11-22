extends RefCounted
## One authority for both authored handoffs, attached only to Sereth's host.
const Title := preload("res://game/title_screen.gd")
const World := preload("res://game/campaign_world.gd")
const CutView := preload("res://game/overworld/sereth/cut_passage_map.gd")
const KeeperView := preload("res://game/overworld/sereth/keeper_sector_map.gd")
const ValleyView := preload("res://game/overworld/sereth/sereth_y5_view.gd")
const Lower := preload("res://game/overworld/sereth/sereth_passage.gd")
const Upper := preload("res://game/overworld/sereth/sereth_assembly_passage.gd")
const CAMPAIGN := "sereth"
const CAMP := CutView.CAMP
const CUT := Lower.ORIGIN
const KEEPER := Lower.TARGET
const ASSEMBLY := Upper.TARGET

var _host: Title
var _lower := Lower.new()
var _upper := Upper.new()
var _tx: RefCounted
var _sequence := 0
var _token := 0
var _source: Control
var _destination := ""
var _prepared: Control
var _force_unavailable_for_test := false

func _init(host: Title) -> void:
	_host=host

func choose_map(world: World) -> Control:
	if not world or world.campaign_id()!=CAMPAIGN:
		return null
	var here := world.current_waypoint_id()
	var clears := _host._profile.completed_missions(CAMPAIGN)
	if (here==KEEPER and Lower.CLEAR not in clears) or (here==ASSEMBLY and Upper.CLEAR not in clears):
		return null
	if here==_destination and is_instance_valid(_prepared):
		var staged := _prepared
		_prepared=null
		_destination=""
		_host.remove_child(staged)
		return staged
	return _build(here)

func _build(here: String) -> Control:
	var node: Control
	match here:
		CAMP,CUT: node=CutView.new()
		KEEPER: node=KeeperView.new()
		ASSEMBLY: node=ValleyView.new()
	if node and node.build():
		return node
	if node:
		node.free()
	return null

func on_mounted(view: Control) -> void:
	view.show()
	view._camera.make_current()
	var here := _host._campaign_world.current_waypoint_id()
	var gate := _host._profile.completed_missions(CAMPAIGN)
	if view is KeeperView:
		var exits: Array[String]=[]
		for edge in _host._campaign_world.route_options(gate):
			if edge.is_open and edge.waypoint_id in [CUT,ASSEMBLY]:
				exits.append(edge.waypoint_id)
		view.install_exits(exits)
	elif view is ValleyView:
		view.install_boundary_selector(ASSEMBLY,KEEPER,"Return to Keeper Boundary Post")
	if here!=CAMP or view is CutView:
		view.boundary_requested.connect(_start.bind(view))
		view.boundary_cancel_requested.connect(_cancel.bind(view))
	_check_active.call_deferred(weakref(view),4)

func _check_active(ref: WeakRef,frames: int) -> void:
	var view:=ref.get_ref() as Control
	if not is_instance_valid(_host) or not is_instance_valid(view) or view.get_parent()!=_host._stage:
		return
	if frames>0:
		_host.get_tree().physics_frame.connect(_check_active.bind(ref,frames-1),CONNECT_ONE_SHOT)
		return
	if not _mounted(view):
		_host.call("_disable_sereth_fallback")
		_host._show_world_map()

func _mounted(view: Control) -> bool:
	if not is_instance_valid(view) or not is_instance_valid(view._renderer):
		return false
	if view is CutView:
		return view._renderer.has_node("SlateRelief") and view._renderer.has_node("PrivateMoorCopses/PineCrown0") \
			and view._curve_for(CAMP,CUT)!=null
	if view is KeeperView:
		return view._renderer.mount_ready() and view._renderer.has_node("KeeperContext/LayeredCairnspineHaze")
	return view is ValleyView and view._renderer.arrival_verified()

func on_local_arrival() -> bool:
	var view := _host._stage.get_child(0) if _host._stage.get_child_count() else null
	if not view is CutView or _host._campaign_world.campaign_id()!=CAMPAIGN:
		return false
	if _host._profile.record_world_waypoint(_host._campaign_world)!=OK:
		_host._campaign_world=_host._profile.load_campaign_world(CAMPAIGN)
		_host._campaign_warning="The arrived waypoint could not be saved. The party remains at its previous site."
		_host._show_world_map()
		return true
	_host._show_waypoint_intermission(false)
	return true

func _start(destination: String,view: Control) -> void:
	if _host._page!=Title.Page.WORLD_MAP or view.get_parent()!=_host._stage or _token!=0:
		return
	var from := _host._campaign_world.current_waypoint_id()
	if from in [CUT,KEEPER] and destination in [CUT,KEEPER]:
		_tx=_lower
	elif from in [KEEPER,ASSEMBLY] and destination in [KEEPER,ASSEMBLY]:
		_tx=_upper
	else:
		return
	var ticket: int=_tx.begin(_host._profile,_host._campaign_world,destination)
	if ticket==0:
		_tx=null
		return
	_sequence+=1
	_token=ticket
	_source=view
	_destination=destination
	view.set_boundary_pending(true)
	_host.get_tree().create_timer(.18).timeout.connect(_prepare.bind(_sequence),CONNECT_ONE_SHOT)

func _owns(serial: int) -> bool:
	return is_instance_valid(_host) and serial==_sequence and _token!=0 and _host._page==Title.Page.WORLD_MAP \
		and is_instance_valid(_source) and _source.get_parent()==_host._stage

func _prepare(serial: int) -> void:
	if not _owns(serial):
		return
	var origin := _host._campaign_world
	var candidate := origin.fork_for_travel() as World
	var clears := _host._profile.completed_missions(CAMPAIGN)
	if _force_unavailable_for_test or candidate.travel_to(_destination,clears)!=World.TravelResult.ARRIVED:
		_finish(serial,"",false)
		return
	var view := _build(_destination)
	if not view or not view.can_present(candidate):
		if view:
			view.free()
		_finish(serial,"",false)
		return
	view.hide()
	view.configure(candidate,clears,_host._profile.setting("reduced_motion"))
	_prepared=view
	_host.add_child(view)
	_check_prepared(weakref(view),serial,candidate.mission_at_current_waypoint(),4)

func _check_prepared(ref: WeakRef,serial: int,mission: String,frames: int) -> void:
	var view := ref.get_ref() as Control
	if not _owns(serial) or not is_instance_valid(view):
		return
	if frames>0:
		_host.get_tree().physics_frame.connect(_check_prepared.bind(ref,serial,mission,frames-1),CONNECT_ONE_SHOT)
	else:
		_host.get_tree().create_timer(.15).timeout.connect(_finish.bind(serial,mission,_mounted(view)),CONNECT_ONE_SHOT)

func _finish(serial: int,mission: String,valid: bool) -> void:
	if not _owns(serial):
		return
	var result: Variant
	var ready := OK if valid else ERR_CANT_OPEN
	if _tx==_lower:
		result=_lower.finish(_token,_host._campaign_world,Lower.PreparedSector.new(CAMPAIGN,_destination,mission,ready))
	else:
		result=_upper.finish(_token,_host._campaign_world,Upper.PreparedSector.new(CAMPAIGN,_destination,mission,ready))
	_token=0
	_tx=null
	var old := _source
	_source=null
	if result.outcome==Lower.Outcome.COMMITTED:
		_host._campaign_world=result.world
		_host._show_world_map()
		return
	_discard()
	old.set_boundary_pending(false,"Arrival could not be saved. Confirm to retry." if result.outcome==Lower.Outcome.SAVE_FAILED \
		else "Destination could not load. Confirm to retry.")

func _cancel(view: Control) -> void:
	if view!=_source or not _tx or not _tx.cancel(_token):
		return
	_token=0
	_tx=null
	_source=null
	_discard()
	view.set_boundary_pending(false,"Transfer canceled. Confirm to try again.")

func _discard() -> void:
	if is_instance_valid(_prepared):
		_host.remove_child(_prepared)
		_prepared.queue_free()
	_prepared=null
	_destination=""

func close() -> void:
	if _tx and _token:
		_tx.cancel(_token)
	_sequence+=1
	_token=0
	_tx=null
	_source=null
	_discard()
