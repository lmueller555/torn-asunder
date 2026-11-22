extends "res://game/overworld/marches_overworld_view.gd"
const Renderer := preload("res://game/overworld/spanwater/ilyra_spanwater_renderer.gd")
const Scene := preload("res://game/overworld/spanwater/ilyra_spanwater_renderer.tscn")
const Transfer := preload("res://game/overworld/ilyra_survey_transfer.gd")

func build() -> bool:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface = SubViewportContainer.new()
	map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface.stretch = true
	add_child(map_surface)
	render_viewport = SubViewport.new()
	render_viewport.own_world_3d = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	map_surface.add_child(render_viewport)
	_pins = SouthBankPins.new()
	_pins.map = self
	_pins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pins)
	_build_header()
	var heading := _header.get_child(0)
	heading.get_child(0).text = "VARETH   /   YEAR FOUR"
	heading.get_child(1).text = "Spanwater · South landing"
	heading.get_child(2).text = "Ilyra Venn · Tide Speaker"
	_build_controls()
	var points: Dictionary[String, Vector3] = {Transfer.TARGET: Renderer.LANDING_POINT}
	var paths: Dictionary[String, Curve3D] = {}
	if not configure_renderer(Scene,^"Camera",^"Party",points,paths,34.0):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true

func marker_styles() -> Dictionary:
	return {Transfer.TARGET: "STORY MISSION"}

func can_present(world: World) -> bool:
	return world != null and world.campaign_id() == Transfer.ILYRA and super.can_present(world)

func _refresh() -> void:
	super._refresh()
	if is_node_ready() and _navigation and _navigation.selected_waypoint_id() == Transfer.TARGET:
		status_label.text = "Spanwater Lock · South landing"


## Draw only this landmark differently. The projected pin, world anchor and
## actual pick ID stay exactly the same; the card moves away from the berth.
class SouthBankPins extends Pins:
	var _anchor_pixel := Vector2.ZERO
	var _card := Rect2()

	func berth_card(anchor: Vector2, viewport: Vector2, label_width: float, near: bool) -> Rect2:
		var bump := Vector2(79,50) if near else Vector2(62,48)
		var dims := Vector2(maxf(label_width,101.)+21.0,42.0)
		var top_left := anchor+bump
		top_left.x = minf(top_left.x,viewport.x-22.0-dims.x)
		if top_left.x < anchor.x+26.0:
			top_left.x = maxf(22.,anchor.x-dims.x-54.0)
		top_left.y = clampf(top_left.y,130.0,maxf(130.0,viewport.y-93.0-dims.y))
		return Rect2(top_left,dims)

	func _draw() -> void:
		label_regions.clear()
		_card = Rect2()
		if not is_instance_valid(map) or not is_instance_valid(map._camera) or not map._world:
			return
		var point: Variant = map._projections().get(Transfer.TARGET)
		if point == null or point.x<24.0 or point.x>size.x-24.0 or point.y<109.0 or point.y>size.y-84.0:
			return
		_anchor_pixel = point
		var dest: Dictionary = map._world.waypoint(Transfer.TARGET)
		var label: String = dest.get("label", "Spanwater Lock")
		var text_width := _face.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		_card = berth_card(point,size,text_width,map._renderer._zoomed)
		label_regions[Transfer.TARGET] = _card
		var gold := Color("#e3c77f")
		var join := Vector2(_card.position.x,_card.position.y+17.0)
		if _card.end.x < point.x:
			join.x = _card.end.x
		var direction := 1.0 if join.x > point.x else -1.0
		var elbow: Vector2 = join-Vector2(direction*18,0)
		var pin_edge: Vector2 = point.lerp(elbow,6.0/maxf(6.0,point.distance_to(elbow)))
		var leader := PackedVector2Array([pin_edge,elbow,join])
		draw_polyline(leader,map.PANEL,3.6,true)
		draw_polyline(leader,Color(gold,.85),1.1,true)
		draw_circle(point,6.0,map.PANEL,true)
		draw_arc(point,4.6,0.0,TAU,24,gold,1.25,true)
		draw_circle(point,1.4,gold,true)
		draw_rect(_card,map.PANEL)
		draw_line(_card.position,_card.position+Vector2(_card.size.x,0),Color(gold,.75),1.0,true)
		draw_string(_face,_card.position+Vector2(9,16),"STORY MISSION",HORIZONTAL_ALIGNMENT_LEFT,-1,11,gold)
		draw_string(_face,_card.position+Vector2(9,34),label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,map.BODY)
