extends "res://game/title_screen.gd"
## Mara sector presenter for the normal title and standalone development preview.

const MarchesView := preload("res://game/overworld/marches_overworld_view.gd")
const CoastView := preload("res://game/overworld/moonwash/coast_map.gd")
const CoastRenderer := preload("res://game/overworld/moonwash/coast_renderer.gd")
const Transfer := preload("res://game/overworld/mara_sector_transfer.gd")
const CROSSING := Transfer.CROSSING
const COAST_ROAD := Transfer.ROAD
const COAST_HARBOR := "moonwash_harbor"

var _sector_transfer := Transfer.new()
var _sector_token := 0
var _origin_view: MarchesView
var _prepared_map: MarchesView
var _prepared_for := ""
var _normal_rollout := false
var _ilyra_presenter: RefCounted
var _sova_presenter: RefCounted


func _prepare_campaign(campaign: Dictionary) -> void:
	if get_tree().current_scene == self and (NormalMaraEntry.requested() or NormalIlyraEntry.requested() or NormalSovaEntry.requested()):
		if _ilyra_presenter:
			_ilyra_presenter.close()
			_ilyra_presenter = null
		if _sova_presenter:
			_sova_presenter.close()
			_sova_presenter = null
		_normal_rollout = campaign.id == "mara" and NormalMaraEntry.requested()
		_development_overworld_factory = Callable()
		_development_mara_water_gate = false
		_normal_mara_fallback = ""
		if _normal_rollout:
			# Do not load the art pack until the Human campaign is entered.
			_normal_mara_fallback = NormalMaraEntry.package_issue()
			if _normal_mara_fallback.is_empty():
				_development_overworld_factory = _choose_map
				_development_mara_water_gate = true
			else:
				push_warning(_normal_mara_fallback)
		if campaign.id == "ilyra" and NormalIlyraEntry.requested():
			var presenter := NormalIlyraEntry.open_presenter(self)
			if presenter:
				_ilyra_presenter = presenter
				_development_overworld_factory = presenter.choose_map
			else:
				push_warning("Ilyra map package could not open.")
		if campaign.id == "sova" and NormalSovaEntry.requested():
			_sova_presenter = NormalSovaEntry.open_presenter(self)
			if _sova_presenter:
				_development_overworld_factory = _sova_presenter.choose_map
	super._prepare_campaign(campaign)
	if get_tree().current_scene == self and campaign.id == "sova" and NormalSovaEntry.requested() and not _sova_presenter:
		_report_sova_fallback()
	if get_tree().current_scene == self and campaign.id == "ilyra" and NormalIlyraEntry.requested() and not _ilyra_presenter \
			and _campaign_warning.is_empty():
		_campaign_warning = NormalMaraEntry.FALLBACK_MESSAGE


func _report_ilyra_fallback() -> void:
	if _campaign_warning.is_empty():
		_campaign_warning = NormalMaraEntry.FALLBACK_MESSAGE
		_show_campaign_warning()


func _report_sova_fallback() -> void:
	if _campaign_warning.is_empty():
		_campaign_warning = NormalMaraEntry.FALLBACK_MESSAGE


func _on_waypoint_arrived(id: String) -> void:
	if _sova_presenter and _sova_presenter.on_local_arrival():
		return
	if _ilyra_presenter and _ilyra_presenter.on_local_arrival():
		return
	super._on_waypoint_arrived(id)


func install_overworld_playtest() -> void:
	set_development_overworld_factory(_choose_map, true)


func _choose_map(world: CampaignWorld) -> MarchesView:
	if world.campaign_id() != "mara":
		return null
	if is_instance_valid(_prepared_map) and _prepared_for == world.current_waypoint_id():
		var prepared := _prepared_map
		_prepared_map = null
		_prepared_for = ""
		remove_child(prepared)
		return prepared
	return _build_sector(world.current_waypoint_id())


func _build_sector(where: String) -> MarchesView:
	var built: MarchesView = CoastView.new() if where in [COAST_ROAD, COAST_HARBOR] else MarchesView.new()
	if built.build():
		return built
	built.free()
	return null


func _add_development_overworld() -> bool:
	if _sova_presenter and _campaign_world.campaign_id() == "sova":
		if not super._add_development_overworld():
			_sova_presenter.close()
			_sova_presenter = null
			_development_overworld_factory = Callable()
			_report_sova_fallback()
			return false
		_sova_presenter.on_mounted(_stage.get_child(0))
		return true
	if _ilyra_presenter and _campaign_world.campaign_id() == "ilyra":
		if not super._add_development_overworld():
			_ilyra_presenter.close()
			_ilyra_presenter = null
			_development_overworld_factory = Callable()
			if _campaign_warning.is_empty():
				_campaign_warning = NormalMaraEntry.FALLBACK_MESSAGE
			return false
		_ilyra_presenter.on_mounted(_stage.get_child(0))
		return true
	if not super._add_development_overworld():
		if _normal_rollout and _campaign_world.campaign_id() == "mara":
			_report_mara_fallback("The current authored sector could not open.")
		return false
	var map := _stage.get_child(0) as MarchesView
	if map == null:
		return true
	if _normal_rollout and not _sector_geometry_present(map):
		_stage.remove_child(map)
		map.queue_free()
		_report_mara_fallback("The authored renderer could not mount its terrain.")
		return false
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	map._camera.make_current()
	if map is CoastView:
		map.install_boundary_selector(COAST_ROAD, CROSSING, "Return to Marches Crossing")
	elif map._points.has(CROSSING):
		map.install_boundary_selector(CROSSING, COAST_ROAD, "Road to Moonwash")
	map.boundary_requested.connect(_start_boundary.bind(map))
	map.boundary_cancel_requested.connect(_cancel_boundary.bind(map))
	if _normal_rollout:
		_verify_active_sector.call_deferred(map)
	return true


func _verify_active_sector(map: MarchesView) -> void:
	# Some renderer mounts run on their children's Ready or deferred foliage
	# passes. Do not leave a half-mounted 3D view accepting travel.
	for step in range(2):
		await get_tree().physics_frame
		if not is_instance_valid(map) or _page != Page.WORLD_MAP or map.get_parent() != _stage:
			return
	if _sector_geometry_present(map) and (not map is CoastView or (map._renderer as CoastRenderer).mounted_for_play()):
		return
	_report_mara_fallback("The current authored sector did not finish loading.")
	_development_overworld_factory = Callable()
	_show_world_map()


func _sector_geometry_present(map: MarchesView) -> bool:
	var renderer := map._renderer
	if not is_instance_valid(renderer) or not is_instance_valid(map._camera) or not is_instance_valid(map._party) \
			or not is_instance_valid(renderer._ground):
		return false
	return not map is CoastView or (renderer.has_node("MoonwashHarbor") and renderer.has_node("MoonwashShoulderReturns"))


func _report_mara_fallback(detail: String) -> void:
	# Preserve save warnings and completed/canonical route state.
	if _normal_mara_fallback.is_empty():
		_normal_mara_fallback = detail
		push_warning(detail)
	if _campaign_warning.is_empty():
		_campaign_warning = NormalMaraEntry.FALLBACK_MESSAGE


func _start_boundary(destination: String, map: MarchesView) -> void:
	if _page != Page.WORLD_MAP or not is_instance_valid(map) or map.get_parent() != _stage:
		return
	if _sector_token != 0 or _maybe_show_required_water_request():
		return
	var token := _sector_transfer.begin(_profile, _campaign_world, destination)
	if token == 0:
		map.set_boundary_pending(false, "The boundary route is still locked.")
		return
	_sector_token = token
	_origin_view = map
	map.set_boundary_pending(true)
	# Keep origin input available while the pending action is visible.
	get_tree().create_timer(0.25).timeout.connect(_prepare_boundary.bind(token, destination), CONNECT_ONE_SHOT)


func _owns_boundary(token: int) -> bool:
	return token != 0 and token == _sector_token and _page == Page.WORLD_MAP 		and is_instance_valid(_origin_view) and _origin_view.get_parent() == _stage


func _boundary_preflight_allowed() -> bool:
	return true


func _prepare_boundary(token: int, destination: String) -> void:
	if not _owns_boundary(token):
		return
	var preview := _campaign_world.fork_for_travel() as CampaignWorld
	var clears := _profile.completed_missions("mara")
	if not _boundary_preflight_allowed() or preview.travel_to(destination, clears) != CampaignWorld.TravelResult.ARRIVED:
		_finish_boundary(token, false)
		return
	var target := _build_sector(destination)
	if target == null or not target.can_present(preview):
		if target:
			target.free()
		_finish_boundary(token, false)
		return
	# Hidden presentation suppresses input and renderer updates, but keep the
	# target's own physics world enabled for grounding/foliage preparation.
	target.hide()
	target.configure_forward_camp(ForwardCamp.available_for("mara", clears, _profile.greyhollow_reveal_completed()))
	target.configure(preview, clears, _profile.setting("reduced_motion"))
	add_child(target) # Different owned 3D world, never the visible map's viewport.
	_prepared_map = target
	_prepared_for = destination
	for frame in range(3):
		await get_tree().physics_frame
		if not _owns_boundary(token):
			return
	var renderer := target._renderer
	var valid := false
	if destination == COAST_ROAD:
		var coast := renderer as CoastRenderer
		valid = coast != null and coast.mounted_for_play() and target._curve_for(COAST_ROAD, COAST_HARBOR) != null
	else:
		valid = renderer.get_node_or_null("MarchesCrossingArt") != null 			and target._curve_for("marches_road", CROSSING) != null
	if not valid:
		_finish_boundary(token, false)
		return
	# Explicit pre-commit cancel window remains after assets have loaded.
	get_tree().create_timer(0.15).timeout.connect(_finish_boundary.bind(token, true), CONNECT_ONE_SHOT)


func _finish_boundary(token: int, valid: bool) -> void:
	if not _owns_boundary(token):
		return
	var result := _sector_transfer.finish(token, _campaign_world, valid)
	var origin := _origin_view
	_sector_token = 0
	_origin_view = null
	if result.outcome == Transfer.Outcome.COMMITTED:
		_campaign_world = result.world
		# The existing protected Water Request can keep the destination hidden.
		_show_world_map()
		return
	_drop_prepared()
	if is_instance_valid(origin):
		var message := "Destination could not load. Confirm to retry."
		if result.outcome == Transfer.Outcome.SAVE_FAILED:
			message = "Arrival could not be saved. Confirm to retry."
		origin.set_boundary_pending(false, message)


func _cancel_boundary(map: MarchesView) -> void:
	if map != _origin_view or not _sector_transfer.cancel(_sector_token):
		return
	_sector_token = 0
	_origin_view = null
	_drop_prepared()
	map.set_boundary_pending(false, "Transfer canceled. Confirm to try again.")


func _drop_prepared() -> void:
	if is_instance_valid(_prepared_map):
		remove_child(_prepared_map)
		_prepared_map.queue_free()
	_prepared_map = null
	_prepared_for = ""


func _show_title() -> void:
	if _sova_presenter:
		_sova_presenter.close()
		_sova_presenter = null
		_development_overworld_factory = Callable()
	if _ilyra_presenter:
		_ilyra_presenter.close()
		_ilyra_presenter = null
		_development_overworld_factory = Callable()
	if _sector_token != 0:
		_sector_transfer.cancel(_sector_token)
	_sector_token = 0
	_origin_view = null
	_drop_prepared()
	super._show_title()
