extends "res://game/overworld/marches_overworld_view.gd"
## Private vertical slice, only Grove Camp and Isolated Grove; never title-enabled.
const Relief := preload("res://game/overworld/neris/grove_relief.gd")
const Scene := preload("res://game/overworld/neris/grove_relief.tscn")
const POST_REGIONAL_PIN_OFFSET:=Vector2(17.0,18.0)
var _detail := false
var _was_travelling := false
const SharedMap := preload("res://game/overworld/marches_overworld_view.gd")
var _overlays:Control
var prepared:Node3D

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
	_pins=SharedMap.Pins.new()
	_pins.hide()
	add_child(_pins)
	_overlays=GrovePins.new()
	_overlays.owner_view=self
	_overlays.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_overlays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlays)
	_make_hud()
	if not _configure_private_renderer():
		return false
	_renderer.zoom_requested.connect(flip_lens)
	return true

func _configure_private_renderer()->bool:
	var probe := Relief.new()
	var path := probe.route_contract().duplicate() as Curve3D
	probe.free()
	var anchors:Dictionary[String,Vector3]={"grove_camp":path.get_point_position(0),
		"isolated_grove_nursery":path.get_point_position(path.point_count-1)}
	var curves:Dictionary[String,Curve3D]={route_key("grove_camp","isolated_grove_nursery"):path}
	if prepared:
		return _adopt_prepared(anchors,curves)
	return configure_renderer(Scene,^"Camera",^"Party",anchors,curves,34.0)

func _adopt_prepared(anchors:Dictionary[String,Vector3], curves:Dictionary[String,Curve3D])->bool:
	_renderer=prepared
	prepared=null
	_camera=_renderer.get_node_or_null(^"Camera") as Camera3D
	_party=_renderer.get_node_or_null(^"Party") as Node3D
	if not _camera or not _party or _renderer.get_parent():
		_renderer.free()
		return false
	_points=anchors
	_curves=curves
	_pace=34.
	render_viewport.add_child(_renderer)
	return true

func flip_lens() -> void:
	_detail=not _detail
	_renderer.view_lens(_detail)
	_overlays.queue_redraw()

func _update_party() -> void:
	super._update_party()
	if _navigation.is_travelling():
		_renderer.travel_lens()
		_was_travelling=true
	elif _was_travelling:
		_was_travelling=false
		_renderer.view_lens(_detail)
	_overlays.queue_redraw()

func _refresh() -> void:
	super._refresh()
	if _navigation and status_label and _world.current_waypoint_id()==_navigation.selected_waypoint_id():
		status_label.text="At %s" % _world.waypoint(_world.current_waypoint_id()).label

func _grove_style() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color("#18221be6")
	box.border_color=Color("#bb9865")
	box.border_width_top=1
	box.border_width_left=2
	box.content_margin_left=14
	box.content_margin_right=14
	box.content_margin_bottom=9
	box.content_margin_top=9
	return box

func _map_strip_title()->String:
	return "VARETH    /    YEAR ONE"

func _make_hud()->void:
	var wrapper:=PanelContainer.new()
	wrapper.position=Vector2(28,24)
	wrapper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_stylebox_override("panel",_grove_style())
	add_child(wrapper)
	var lines:=VBoxContainer.new()
	wrapper.add_child(lines)
	for row:Array in [[_map_strip_title(),14,Color("#cfbd91")],
			["The Grove Road",29,Color("#f2e6cb")],["Neris Alder   ·   Room to Grow",15,Color("#e9dab6")]]:
		var label:=Label.new()
		label.text=row[0]
		label.add_theme_font_size_override("font_size",row[1])
		label.add_theme_color_override("font_color",row[2])
		lines.add_child(label)
	var dock:=PanelContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left=28
	dock.offset_right=-28
	dock.offset_top=-82
	dock.offset_bottom=-24
	dock.add_theme_stylebox_override("panel",_grove_style())
	add_child(dock)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	dock.add_child(row)
	status_label=Label.new()
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	confirm_button=Button.new()
	row.add_child(confirm_button)
	back_button=Button.new()
	row.add_child(back_button)

class GrovePins extends Control:
	var owner_view
	func _draw() -> void:
		if not owner_view or not owner_view._navigation or size.x <= 50.0 or size.y <= 104.0:
			return
		var font:=get_theme_default_font()
		var visible_points:Dictionary=owner_view._projections()
		if owner_view._navigation.is_travelling():
			return
		for id in visible_points:
			var at:Vector2=visible_points[id]
			if not Rect2(Vector2(25,25),size-Vector2(50,104)).has_point(at):
				continue
			var title:String=owner_view._world.waypoint(id).label
			var connector_base:=at
			if not owner_view._detail and id=="cairnspine_boundary_post":
				at+=owner_view.POST_REGIONAL_PIN_OFFSET
			var chosen:bool=owner_view._navigation.selected_waypoint_id()==id
			var ink:=Color("#f0c475") if chosen else Color("#bdcc8a")
			if not at.is_equal_approx(connector_base):
				draw_line(connector_base,at,ink,1.0,true)
				draw_circle(connector_base,2.0,ink,true,-1,true)
			draw_circle(at,11.0,Color("#20261b"),true,-1,true)
			draw_circle(at,7.5,ink,true,-1,true)
			var x:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
			var label_x:=clampf(at.x+28.0,28.0,size.x-x-44.0)
			var label_y:=at.y-11.0
			if id in ["isolated_grove_nursery","cairnspine_boundary_post"]:
				label_x=maxf(28.0,at.x-x*.5-8.0)
				label_y=at.y+27.0
			var bg:=Rect2(Vector2(label_x,label_y),Vector2(x+16,23))
			if label_y>at.y:
				draw_line(at+Vector2(0,10),Vector2(at.x,label_y),ink,1.0,true)
			else:
				draw_line(at+Vector2(10,0),Vector2(label_x,label_y+11),ink,1.0,true)
			draw_rect(bg,Color("#18221bea"))
			draw_string(font,Vector2(label_x+8,label_y+17),title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#f2e6cb"))
