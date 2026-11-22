extends RefCounted
## Per-campaign normal title attachment. Stock profile is always authoritative.
const Title := preload("res://game/title_screen.gd")
const CampaignWorld := preload("res://game/campaign_world.gd")
const IlyraMap := preload("res://game/overworld/moonwash/ilyra_opener_map.gd")
const Opener := preload("res://game/overworld/moonwash/ilyra_opener_route.gd")
const Survey := preload("res://game/overworld/moonwash/ilyra_survey_route.gd")
const Transfer := preload("res://game/overworld/ilyra_survey_transfer.gd")
const SpanMap := preload("res://game/overworld/spanwater/ilyra_spanwater_map.gd")
const MarchesView := preload("res://game/overworld/marches_overworld_view.gd")
var _transfer := Transfer.new()
var _token := 0
var _source: MarchesView
var _prepared: MarchesView
var _prepared_id := ""
var _host: Title


func _init(host: Title) -> void:
	_host = host


func choose_map(world: CampaignWorld) -> MarchesView:
	if world == null or world.campaign_id() != Transfer.ILYRA:
		return null
	var point := world.current_waypoint_id()
	var clears := _host._profile.completed_missions(Transfer.ILYRA)
	if point in [Transfer.ORIGIN, Transfer.TARGET] and Survey.RESCUE_CLEAR not in clears:
		return null
	if point == Transfer.TARGET and Survey.SURVEY_CLEAR not in clears:
		return null
	if point not in [Opener.CAMP, Opener.HARBOR, Transfer.ORIGIN, Transfer.TARGET]:
		return null
	if is_instance_valid(_prepared) and _prepared_id == point:
		var map := _prepared
		_prepared = null
		_prepared_id = ""
		_host.remove_child(map)
		map.show()
		return map
	return _build_for(point)


func on_mounted(map: MarchesView) -> void:
	map._camera.make_current()
	var where := _host._campaign_world.current_waypoint_id()
	var cleared := _host._profile.completed_missions(Transfer.ILYRA)
	if where == Transfer.ORIGIN and Survey.SURVEY_CLEAR in cleared:
		map.install_boundary_selector(Transfer.ORIGIN, Transfer.TARGET, "Travel to Spanwater Lock")
	elif where == Transfer.TARGET:
		map.install_boundary_selector(Transfer.TARGET, Transfer.ORIGIN, "Return to Survey Shore")
	map.boundary_requested.connect(_begin_transfer.bind(map))
	map.boundary_cancel_requested.connect(_cancel_transfer.bind(map))
	_verify_active.call_deferred(map)


func _verify_active(map: MarchesView) -> void:
	for step in range(2):
		await _host.get_tree().physics_frame
		if not is_instance_valid(map) or _host._page != Title.Page.WORLD_MAP or map.get_parent() != _host._stage:
			return
	var good: bool = map._renderer.probe_south_landing() if map is SpanMap else map._renderer.mounted_for_play()
	if good:
		return
	_host._development_overworld_factory = Callable()
	_host.set("_ilyra_presenter", null)
	_host.call("_report_ilyra_fallback")
	_host._show_world_map()


func on_local_arrival() -> bool:
	if not _host._campaign_world or _host._campaign_world.campaign_id() != Transfer.ILYRA or not _host._stage.get_child(0) is IlyraMap:
		return false
	if _host._profile.record_world_waypoint(_host._campaign_world) != OK:
		_host._campaign_world = _host._profile.load_campaign_world(Transfer.ILYRA)
		_host._campaign_warning = "The arrived waypoint could not be saved. The party remains at its previous site."
		_host._show_world_map()
	else:
		_host._show_waypoint_intermission(false)
	return true


func _build_for(id: String) -> MarchesView:
	var map: MarchesView = SpanMap.new() if id == Transfer.TARGET else IlyraMap.new()
	if map.build():
		return map
	map.free()
	return null

func _begin_transfer(target: String, source: MarchesView) -> void:
	if _host._page != Title.Page.WORLD_MAP or source.get_parent() != _host._stage:
		return
	var token := _transfer.begin(_host._profile,_host._campaign_world,target)
	if token == 0:
		return
	_token = token
	_source = source
	source.set_boundary_pending(true)
	_host.get_tree().create_timer(.15).timeout.connect(_prepare.bind(token,target), CONNECT_ONE_SHOT)

func _valid(token: int) -> bool:
	return token > 0 and token == _token and _host._page == Title.Page.WORLD_MAP and is_instance_valid(_source) and _source.get_parent() == _host._stage

func _prepare(token: int, target: String) -> void:
	if not _valid(token):
		return
	var preview := _host._campaign_world.fork_for_travel() as CampaignWorld
	var clears := _host._profile.completed_missions(Transfer.ILYRA)
	if preview.travel_to(target,clears) != CampaignWorld.TravelResult.ARRIVED:
		_finish_transfer(token,null)
		return
	var map := _build_for(target)
	if not map or not map.can_present(preview):
		if map:
			map.free()
		_finish_transfer(token,null)
		return
	map.hide()
	map.configure(preview,clears,_host._profile.setting("reduced_motion"))
	_host.add_child(map)
	_prepared = map
	_prepared_id = target
	for frame in range(3):
		await _host.get_tree().physics_frame
		if not _valid(token):
			return
	var valid := false
	if target == Transfer.TARGET:
		valid = map._renderer.probe_south_landing()
	else:
		valid = map._curve_for(Opener.HARBOR,Survey.ID) != null and map._renderer.mounted_for_play()
	var prepared := Transfer.PreparedSector.new(Transfer.ILYRA,target,preview.mission_at_current_waypoint(),OK if valid else ERR_CANT_OPEN)
	_host.get_tree().create_timer(.15).timeout.connect(_finish_transfer.bind(token,prepared),CONNECT_ONE_SHOT)

func _finish_transfer(token: int, prepared: Transfer.PreparedSector) -> void:
	if not _valid(token):
		return
	var source := _source
	var result := _transfer.finish(token,_host._campaign_world,prepared)
	_token = 0
	_source = null
	if result.outcome == Transfer.Outcome.COMMITTED:
		_host._campaign_world = result.world
		_host._show_world_map()
		return
	_drop_prepared()
	var warning := "Arrival could not be saved. Confirm to retry." if result.outcome == Transfer.Outcome.SAVE_FAILED else "Destination could not load. Confirm to retry."
	source.set_boundary_pending(false,warning)

func _drop_prepared() -> void:
	if is_instance_valid(_prepared):
		_host.remove_child(_prepared)
		_prepared.queue_free()
	_prepared = null
	_prepared_id = ""

func _cancel_transfer(source: MarchesView) -> void:
	if source != _source or not _transfer.cancel(_token):
		return
	_token = 0
	_source = null
	_drop_prepared()
	source.set_boundary_pending(false,"Transfer canceled. Confirm to try again.")

func close() -> void:
	if _token:
		_transfer.cancel(_token)
	_token = 0
	_source = null
	_drop_prepared()
