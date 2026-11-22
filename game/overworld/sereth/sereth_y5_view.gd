extends "res://game/overworld/marches_overworld_view.gd"
const Render := preload("res://game/overworld/sereth/sereth_y5_renderer.gd")
const LocalScene := preload("res://game/overworld/sereth/sereth_y5_renderer.tscn")
const Assembly := preload("res://game/overworld/sereth/sereth_assembly_passage.gd")

func build() -> bool:
	if not Render.Neutral.available():
		return false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface=SubViewportContainer.new()
	map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface.stretch=true
	add_child(map_surface)
	render_viewport=SubViewport.new()
	render_viewport.own_world_3d=true
	render_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	map_surface.add_child(render_viewport)
	_pins=Pins.new()
	_pins.map=self
	_pins.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pins)
	_build_header()
	var labels := _header.get_child(0)
	labels.get_child(0).text="VARETH   /   YEAR FIVE"
	labels.get_child(1).text="Valley Assembly"
	labels.get_child(2).text="Sereth Vale · High Executor"
	_build_controls()
	var anchors: Dictionary[String,Vector3]={Assembly.TARGET:Render.ARRIVAL}
	var no_new_route: Dictionary[String,Curve3D]={}
	if not configure_renderer(LocalScene,^"Camera",^"Party",anchors,no_new_route,32.):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true

func can_present(world: World) -> bool:
	return world!=null and world.campaign_id()==Assembly.SERETH \
		and world.mission_at_current_waypoint()==Assembly.TARGET_MISSION and super.can_present(world)

func marker_styles() -> Dictionary:
	return {Assembly.TARGET:"STORY MISSION"}

func marker_bearing(_id: String, width: float) -> Vector2:
	return Vector2(-width-37.,28.)

func set_assembly_pending(active: bool,message := "") -> void:
	set_boundary_pending(active,message)
