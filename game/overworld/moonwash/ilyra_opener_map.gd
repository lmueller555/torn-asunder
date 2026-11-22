extends "res://game/overworld/marches_overworld_view.gd"
## Private two-route preview. Normal Ilyra campaign retains its stock route.

const Campaigns := preload("res://game/campaigns.gd")
const Opener := preload("res://game/overworld/moonwash/ilyra_opener_route.gd")
const Survey := preload("res://game/overworld/moonwash/ilyra_survey_route.gd")
const CoastRenderer := preload("res://game/overworld/moonwash/coast_renderer.gd")
const RENDERER_PATH := "res://game/overworld/moonwash/ilyra_opener_renderer.tscn"


func marker_styles() -> Dictionary:
	return {
		Opener.CAMP: "OPERATIONS", Opener.HARBOR: "STORY MISSION",
		Survey.ID: "STORY MISSION" if Survey.RESCUE_CLEAR in _confirmed else "LOCKED STORY ROUTE",
	}


func marker_bearing(id: String, width: float) -> Vector2:
	if id == Opener.CAMP:
		return Vector2(-width - 88.0, 26.0) if is_instance_valid(_renderer) and _renderer._zoomed else Vector2(-width - 38.0, 22.0)
	if id == Survey.ID:
		return Vector2(-width - 19.0, 15.0) if is_instance_valid(_renderer) and _renderer._zoomed else Vector2(17.0, 28.0)
	return Vector2(13.0, -27.0)


func edge_hint_from(id: String) -> bool:
	return id in [Opener.CAMP, Opener.HARBOR, Survey.ID]


func can_present(world: World) -> bool:
	return world != null and world.campaign_id() == "ilyra" and super.can_present(world)


func build() -> bool:
	var route := Opener.points()
	var survey_curve := Survey.curve()
	if not survey_curve or route.size() < 200 or not ResourceLoader.exists(RENDERER_PATH, "PackedScene"):
		return false
	var scene := ResourceLoader.load(RENDERER_PATH, "PackedScene") as PackedScene
	var check := scene.instantiate() as CoastRenderer if scene and scene.can_instantiate() else null
	if not check:
		return false
	var available := check.package_available()
	check.free()
	if not available:
		return false
	var anchors: Dictionary[String, Vector3] = {Opener.CAMP: route[0], Opener.HARBOR: route[-1], Survey.ID: Survey.ARRIVAL}
	var curve := Curve3D.new()
	curve.bake_interval = 1.15
	for point in route:
		curve.add_point(point)
	var curves: Dictionary[String, Curve3D] = {
		route_key(Opener.CAMP, Opener.HARBOR): curve,
		route_key(Opener.HARBOR, Survey.ID): survey_curve,
	}
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
	_pins = IlyraPins.new()
	_pins.map = self
	_pins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pins)
	_build_header()
	var heading := _header.get_child(0)
	for campaign in Campaigns.ALL:
		if campaign.id == "ilyra":
			heading.get_child(1).text = campaign.region
			heading.get_child(2).text = "%s  ·  %s" % [campaign.name, campaign.title]
			break
	_build_controls()
	if not configure_renderer(scene, ^"Camera", ^"Party", anchors, curves, Opener.PACE):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true



func _refresh() -> void:
	super._refresh()
	if is_node_ready() and _navigation and _world.current_waypoint_id() == _navigation.selected_waypoint_id():
		status_label.text = _world.waypoint(_world.current_waypoint_id()).label


class IlyraPins extends Pins:
	func _draw_offscreen_connections(projected: Dictionary) -> void:
		var here: String = map._world.current_waypoint_id()
		if not map.edge_hint_from(here):
			return
		for row: Dictionary in map._world.route_options(map._confirmed):
			var id: String = row.waypoint_id
			if not row.is_open or not map._curve_for(here, id) or not projected.has(id) or label_regions.has(id):
				continue
			var dest: Dictionary = map._world.waypoint(id)
			var to: Vector2 = projected[id]
			var left := to.x <= size.x * 0.5
			var width := _face.get_string_size(dest.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 34.0
			var pos := Vector2(28.0 if left else size.x - width - 28.0, clampf(to.y, 154.0, size.y - 147.0))
			var edge := Rect2(pos, Vector2(width, 40.0))
			label_regions[id] = edge
			draw_rect(edge, map.PANEL)
			var color := Color("#e3c77f")
			draw_line(pos, pos + Vector2(width, 0), color, 1.0, true)
			var link := "RETURN ROUTE" if id == Opener.CAMP or here == Survey.ID else "STORY MISSION"
			draw_string(_face, pos + Vector2(11, 16), "‹   " + link if left else link + "   ›",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
			draw_string(_face, pos + Vector2(11, 33), dest.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, map.BODY)
