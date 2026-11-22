extends "res://game/overworld/marches_overworld_view.gd"
## Shared authored-map controls; one pre-existing canonical station.
const Relief := preload("res://game/overworld/sereth/keeper_relief.gd")
const LocalScene := preload("res://game/overworld/sereth/keeper_relief.tscn")
const Passage := preload("res://game/overworld/sereth/sereth_passage.gd")

func build() -> bool:
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
	labels.get_child(0).text="VARETH   /   YEAR FOUR"
	labels.get_child(1).text="Keeper Boundary Post"
	labels.get_child(2).text="Sereth Vale · High Executor"
	_build_controls()
	var points: Dictionary[String,Vector3] = {Passage.TARGET:Relief.at(Relief.ARRIVAL,.18)}
	var no_curves: Dictionary[String,Curve3D] = {}
	if not configure_renderer(LocalScene,^"Camera",^"Party",points,no_curves,32.0):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true

func can_present(world: World) -> bool:
	return world != null and world.campaign_id()==Passage.SERETH and super.can_present(world)

func _refresh() -> void:
	super._refresh()
	if _navigation and not _navigation.is_travelling() and _navigation.selected_waypoint_id()==_world.current_waypoint_id():
		status_label.text="At %s" % _world.waypoint(_world.current_waypoint_id()).label

func marker_styles() -> Dictionary:
	return {Passage.TARGET:"STORY MISSION"}
