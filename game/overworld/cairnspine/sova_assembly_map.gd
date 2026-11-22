extends "res://game/overworld/marches_overworld_view.gd"
## One canonical civic location and a deliberately explicit cross-sector return.

const Campaigns := preload("res://game/campaigns.gd")
const Valley := preload("res://game/overworld/cairnspine/sova_assembly_renderer.gd")
const SovaRenderer := preload("res://game/overworld/cairnspine/sova_assembly_renderer.tscn")


func marker_styles() -> Dictionary:
	return {Valley.ASSEMBLY: "STORY MISSION"}


func marker_bearing(_id: String, width: float) -> Vector2:
	return Vector2(-width-37.0,28.0)


func can_present(world: World) -> bool:
	return world != null and world.campaign_id() == "sova" and super.can_present(world)


func build() -> bool:
	var anchors := _anchors_for_sector()
	var curves := _curves_for_sector()
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
	if not configure_renderer(_renderer_scene(), ^"Camera", ^"Party", anchors, curves, _travel_pace()):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true


func _refresh() -> void:
	super._refresh()
	if is_node_ready() and _navigation and _world.current_waypoint_id() == _navigation.selected_waypoint_id():
		status_label.text = _world.waypoint(_world.current_waypoint_id()).label


func _anchors_for_sector() -> Dictionary[String,Vector3]:
	return {Valley.ASSEMBLY: Valley.ARRIVAL}


func _curves_for_sector() -> Dictionary[String,Curve3D]:
	return {}


func _renderer_scene() -> PackedScene:
	return SovaRenderer


func _travel_pace() -> float:
	return 28.0
