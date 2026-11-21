extends "res://game/overworld/marches_overworld_view.gd"

const Coast := preload("res://game/overworld/moonwash/coast_route.gd")
const CoastRenderer := preload("res://game/overworld/moonwash/coast_renderer.gd")
const RENDERER_PATH := "res://game/overworld/moonwash/coast_renderer.tscn"

func marker_styles() -> Dictionary:
	return {Coast.ROAD:"COAST ROAD",Coast.HARBOR:"STORY MISSION"}


func marker_bearing(id: String,_width: float) -> Vector2:
	return Vector2(154.0,-80.0) if id==Coast.HARBOR and is_instance_valid(_renderer) and _renderer._zoomed else Vector2(13.0,-27.0)


func edge_hint_from(id: String) -> bool:
	return id==Coast.HARBOR


func build() -> bool:
	var road := Coast.points()
	if road.is_empty() or not ResourceLoader.exists(RENDERER_PATH, "PackedScene"):
		return false
	# Deferred typed load prevents missing Coast assets from poisoning stock title.
	var scene := ResourceLoader.load(RENDERER_PATH, "PackedScene") as PackedScene
	if not scene or not scene.can_instantiate():
		return false
	var candidate := scene.instantiate() as CoastRenderer
	if not candidate:
		return false
	var canonical_available := candidate.package_available()
	candidate.free()
	if not canonical_available:
		return false
	var anchors: Dictionary[String,Vector3] = {Coast.ROAD:road[0],Coast.HARBOR:road[-1]}
	var curves: Dictionary[String,Curve3D] = {}
	var curve := Curve3D.new()
	curve.bake_interval=1.15
	for p in road:
		curve.add_point(p)
	curves[route_key(Coast.ROAD,Coast.HARBOR)]=curve
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface=SubViewportContainer.new()
	map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface.stretch=true
	add_child(map_surface)
	render_viewport=SubViewport.new()
	render_viewport.own_world_3d=true
	render_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	if DisplayServer.get_name()!="headless":
		render_viewport.msaa_3d=Viewport.MSAA_2X
	map_surface.add_child(render_viewport)
	_pins=Pins.new()
	_pins.map=self
	_pins.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pins)
	_build_header()
	var heading:=_header.get_child(0)
	heading.get_child(1).text="Moonwash Coast"
	_build_controls()
	if not configure_renderer(scene,^"Camera",^"Party",anchors,curves,34.0):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true
