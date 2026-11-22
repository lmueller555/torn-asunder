extends "res://game/overworld/marches_overworld_view.gd"
## Sova's two-point local sector; the rest of the campaign is not proposed here.

const Campaigns := preload("res://game/campaigns.gd")
const Opening := preload("res://game/overworld/cairnspine/sova_opener_route.gd")
const SovaRenderer := preload("res://game/overworld/cairnspine/sova_opener_renderer.tscn")
const Required := ["marches-corridor.glb","greyhollow-mine.glb"]

func marker_styles() -> Dictionary:
	return {Opening.CAMP: "FIELD CAMP", Opening.MINE: "STORY MISSION"}


func marker_bearing(id: String, width: float) -> Vector2:
	return Vector2(-width-26.0,23.0) if id == Opening.MINE else Vector2(13.0,17.0)


func can_present(world: World) -> bool:
	return world != null and world.campaign_id() == "sova" and super.can_present(world)


func build() -> bool:
	for name: String in Required:
		if not ResourceLoader.exists("res://assets/overworld/marches/"+name, "PackedScene"):
			return false
	var route := Opening.curve()
	var anchors: Dictionary[String,Vector3] = {Opening.CAMP: route.get_point_position(0), Opening.MINE: route.get_point_position(route.point_count-1)}
	var curves: Dictionary[String, Curve3D] = {route_key(Opening.CAMP,Opening.MINE): route}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface = SubViewportContainer.new()
	map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface.stretch = true
	add_child(map_surface)
	render_viewport = SubViewport.new()
	render_viewport.own_world_3d = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if DisplayServer.get_name() != "headless":
		render_viewport.msaa_3d = Viewport.MSAA_2X
	map_surface.add_child(render_viewport)
	_pins = Pins.new()
	_pins.map = self
	_pins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pins)
	_build_header()
	var heading := _header.get_child(0)
	for campaign in Campaigns.ALL:
		if campaign.id == "sova":
			heading.get_child(1).text = campaign.region
			heading.get_child(2).text = "%s  ·  %s" % [campaign.name, campaign.title]
			break
	_build_controls()
	if not configure_renderer(SovaRenderer, ^"Camera", ^"Party", anchors, curves, Opening.PACE):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true


func _refresh() -> void:
	super._refresh()
	if is_node_ready() and _navigation and _world.current_waypoint_id() == _navigation.selected_waypoint_id():
		status_label.text = _world.waypoint(_world.current_waypoint_id()).label
