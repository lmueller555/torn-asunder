extends "res://game/title_screen.gd"
## Separate development playtest title. Ordinary launch still uses the campaign title.

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
	if not super._add_development_overworld():
		return false
	var map := _stage.get_child(0) as MarchesView
	if map == null:
		return true
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	map._camera.make_current()
	if map is CoastView:
		map.install_boundary_selector(COAST_ROAD, CROSSING, "Return to Marches Crossing")
	elif map._points.has(CROSSING):
		map.install_boundary_selector(CROSSING, COAST_ROAD, "Road to Moonwash")
	map.boundary_requested.connect(_start_boundary.bind(map))
	map.boundary_cancel_requested.connect(_cancel_boundary.bind(map))
	return true


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
	if _sector_token != 0:
		_sector_transfer.cancel(_sector_token)
	_sector_token = 0
	_origin_view = null
	_drop_prepared()
	super._show_title()
