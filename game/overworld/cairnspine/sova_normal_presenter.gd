extends RefCounted
## Packaged opt-in adapter. Shared title/3D controls remain in their stock host.
const Title := preload("res://game/title_screen.gd")
const CampaignWorld := preload("res://game/campaign_world.gd")
const SovaMap := preload("res://game/overworld/cairnspine/sova_opener_map.gd")
const NativeView := preload("res://game/overworld/marches_overworld_view.gd")
const Valley := preload("res://game/overworld/cairnspine/sova_assembly_map.gd")
const VaultMap := preload("res://game/overworld/cairnspine/sova_vault_map.gd")
const Routes := preload("res://game/overworld/cairnspine/sova_vault_routes.gd")
const ASSEMBLY := Routes.ASSEMBLY
const HEARING := Routes.HEARING
const Opening := preload("res://game/overworld/cairnspine/sova_opener_route.gd")


var _host: Title

func _init(host: Title) -> void:
	_host=host


func choose_map(world: CampaignWorld) -> NativeView:
	if not world or world.campaign_id() != "sova":
		return null
	var here := world.current_waypoint_id()
	if here not in [Opening.CAMP, Opening.MINE, ASSEMBLY, Routes.ROAD, Routes.VAULT]:
		return null
	if here in [Routes.ROAD, Routes.VAULT] and HEARING not in _host._profile.completed_missions("sova"):
		return null
	if here == ASSEMBLY and Opening.CLEAR not in _host._profile.completed_missions("sova"):
		return null
	if is_instance_valid(_preflight) and _target == here:
		var ready := _preflight
		_preflight = null
		_target = ""
		_host.remove_child(ready)
		return ready
	return _build_sector(here)


func _build_sector(where: String) -> NativeView:
	var candidate: NativeView
	if where in [ASSEMBLY, Routes.ROAD, Routes.VAULT] and HEARING in _host._profile.completed_missions("sova"):
		candidate = VaultMap.new()
	elif where == ASSEMBLY:
		candidate = Valley.new()
	else:
		candidate = SovaMap.new()
	if not candidate.build():
		candidate.free()
		return null
	return candidate


func on_mounted(map: NativeView) -> void:
	map.show()
	map._camera.make_current()
	if Opening.CLEAR in _host._profile.completed_missions("sova"):
		if map is Valley:
			map.install_boundary_selector(ASSEMBLY, Opening.MINE, "Return to Greyhollow")
		else:
			map.install_boundary_selector(Opening.MINE, ASSEMBLY, "Into Cairnspine Valley")
		map.boundary_requested.connect(_request_transfer.bind(map))
		map.boundary_cancel_requested.connect(_cancel_transfer.bind(map))
	_verify_active.call_deferred(weakref(map),4)


func _verify_active(reference: WeakRef, remaining: int) -> void:
	var map := reference.get_ref() as NativeView
	if not is_instance_valid(_host) or not _host.is_inside_tree() or not is_instance_valid(map) or map.get_parent() != _host._stage:
		return
	if remaining > 0:
		_host.get_tree().physics_frame.connect(_verify_active.bind(reference,remaining-1),CONNECT_ONE_SHOT)
		return
	if _mounted(map):
		return
	close()
	_host._development_overworld_factory = Callable()
	_host.set("_sova_presenter",null)
	_host.call("_report_sova_fallback")
	_host._show_world_map()


func _mounted(map: NativeView) -> bool:
	if not is_instance_valid(map._renderer) or not is_instance_valid(map._renderer._ground):
		return false
	if map is VaultMap:
		return map._renderer.validated and map._renderer.relief.has_node(^"CairnspineVaultThreshold")
	return map._renderer.validated if map is Valley else is_instance_valid(map._renderer.camp_art)


var _epoch := 0
var _origin_view: NativeView
var _origin_world: CampaignWorld
var _origin_epoch := 0
var _preflight: NativeView
var _target := ""


func _request_transfer(to: String, map: NativeView) -> void:
	if _host._page != Title.Page.WORLD_MAP or map.get_parent() != _host._stage or is_instance_valid(_origin_view):
		return
	var from := _host._campaign_world.current_waypoint_id()
	if _host._campaign_world.campaign_id() != "sova" or not (
		(from == Opening.MINE and to == ASSEMBLY) or (from == ASSEMBLY and to == Opening.MINE)):
		return
	var eligible := _host._campaign_world.route_options(_host._profile.completed_missions("sova")).any(
		func(edge: Dictionary) -> bool: return edge.waypoint_id == to and edge.is_open and edge.required_clear_id == Opening.CLEAR)
	if not eligible:
		return
	_epoch += 1
	_origin_view = map
	_origin_world = _host._campaign_world
	_origin_epoch = _host._campaign_world.travel_epoch()
	_target = to
	map.set_boundary_pending(true)
	_host.get_tree().create_timer(.25).timeout.connect(_prepare_transfer.bind(_epoch),CONNECT_ONE_SHOT)


func _still_owns_transfer(epoch: int) -> bool:
	return is_instance_valid(_host) and epoch == _epoch and _host._page == Title.Page.WORLD_MAP and is_instance_valid(_origin_view) \
		and _origin_view.get_parent() == _host._stage and _host._campaign_world == _origin_world \
		and _host._campaign_world.travel_epoch() == _origin_epoch


func _prepare_transfer(epoch: int) -> void:
	if not _still_owns_transfer(epoch):
		return
	var clears := _host._profile.completed_missions("sova")
	var preview := _host._campaign_world.fork_for_travel()
	if preview.travel_to(_target,clears) != CampaignWorld.TravelResult.ARRIVED:
		_reset_transfer("Destination could not load. Confirm to retry.")
		return
	var view := _build_sector(_target)
	if not view or not view.can_present(preview):
		if view:
			view.free()
		_reset_transfer("Destination could not load. Confirm to retry.")
		return
	view.hide()
	view.configure(preview,clears,_host._profile.setting("reduced_motion"))
	_preflight = view
	_host.add_child(view)
	_verify_prepared(weakref(view),epoch,4)


func _verify_prepared(reference: WeakRef, epoch: int, remaining: int) -> void:
	var view := reference.get_ref() as NativeView
	if not _still_owns_transfer(epoch) or not is_instance_valid(view):
		return
	if remaining > 0:
		_host.get_tree().physics_frame.connect(_verify_prepared.bind(reference,epoch,remaining-1),CONNECT_ONE_SHOT)
		return
	if not _mounted(view):
		_reset_transfer("Destination ground is not ready. Confirm to retry.")
		return
	_host.get_tree().create_timer(.15).timeout.connect(_finish_transfer.bind(epoch),CONNECT_ONE_SHOT)


func _finish_transfer(epoch: int) -> void:
	if not _still_owns_transfer(epoch):
		return
	var outcome := _host._profile.commit_world_edge(_host._campaign_world,_target)
	if outcome.error != OK:
		_reset_transfer("Arrival could not be saved. Confirm to retry.")
		return
	_origin_view = null
	_origin_world = null
	_host._campaign_world = outcome.world
	# There is no stock Assembly intermission. Its dispatch opens from the
	# actual mission briefing; don't synthesize a completed hearing or result.
	if not _host._show_waypoint_intermission(false):
		_host._show_world_map()
	if is_instance_valid(_preflight):
		_reset_transfer()


func _cancel_transfer(view: NativeView) -> void:
	if view == _origin_view:
		_reset_transfer("Transfer canceled. Confirm to try again.")


func _reset_transfer(message := "") -> void:
	_epoch += 1
	if is_instance_valid(_preflight):
		_host.remove_child(_preflight)
		_preflight.queue_free()
	_preflight = null
	_target = ""
	var local := _origin_view
	_origin_view = null
	_origin_world = null
	if is_instance_valid(local) and not message.is_empty():
		local.set_boundary_pending(false,message)


func close() -> void:
	_reset_transfer()


func on_local_arrival() -> bool:
	if not _host._campaign_world or _host._campaign_world.campaign_id() != "sova" or not is_instance_valid(_host._stage) \
			or _host._stage.get_child_count() == 0 or not (_host._stage.get_child(0) is SovaMap or _host._stage.get_child(0) is VaultMap):
		return false
	if _host._profile.record_world_waypoint(_host._campaign_world) != OK:
		_host._campaign_world = _host._profile.load_campaign_world("sova")
		_host._campaign_warning = "The arrived waypoint could not be saved. The party remains at its previous site."
		_host._show_world_map()
	else:
		_host._show_waypoint_intermission(false)
	return true
