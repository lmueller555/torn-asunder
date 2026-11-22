extends "res://game/campaign_overworld_3d.gd"
## Private two-way opener. The canonical host still owns all command and animation timing.

const Relief := preload("res://game/overworld/sereth/cut_relief.gd")
const Scene := preload("res://game/overworld/sereth/cut_relief.tscn")
const CAMP := "still_kingdom_camp"
const CUT := "still_kingdom_cut"
const CLEAR := "sereth_voices_at_the_cut"
var _detail := false
var _after_travel := false
var _pins: Control

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
	_pins.owner_view=self
	_pins.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pins)
	_hud()
	var curve:=Relief.route_curve()
	var points:Dictionary[String,Vector3]={CAMP:curve.get_point_position(0),
		CUT:curve.get_point_position(curve.point_count-1)}
	var curves:Dictionary[String,Curve3D]={route_key(CAMP,CUT):curve}
	return configure_renderer(Scene,^"Camera",^"Party",points,curves,32.0)

func _update_party() -> void:
	super._update_party()
	var point:=_party_point()
	var moving:=_navigation.is_travelling()
	_renderer.lens(Vector2(point.x,point.z),_detail,moving)
	_pins.queue_redraw()

func _refresh() -> void:
	super._refresh()
	if _navigation and not _navigation.is_travelling() 			and _world.current_waypoint_id()==_navigation.selected_waypoint_id():
		status_label.text="At %s" % _world.waypoint(_world.current_waypoint_id()).label

func flip_lens() -> void:
	if _navigation and _navigation.is_travelling():
		return
	_detail=not _detail
	if _navigation:
		_update_party()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey and event.physical_keycode==KEY_Z or event is InputEventJoypadButton 				and event.button_index==JOY_BUTTON_LEFT_SHOULDER:
			flip_lens()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _style() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color("#182023ef")
	box.border_color=Color("#a89568")
	box.border_width_top=1
	box.border_width_left=2
	box.content_margin_left=12
	box.content_margin_right=12
	box.content_margin_top=7
	box.content_margin_bottom=7
	return box

func _hud() -> void:
	var banner:=PanelContainer.new()
	banner.position=Vector2(29,24)
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel",_style())
	add_child(banner)
	var lines:=VBoxContainer.new()
	banner.add_child(lines)
	for row in [["VARETH   /   YEAR THREE",14],["The Still Kingdom",28],["Sereth Vale · High Executor",15]]:
		var t:=Label.new()
		t.text=row[0]
		t.add_theme_font_size_override("font_size",row[1])
		t.add_theme_color_override("font_color",Color("#f1e5c8"))
		lines.add_child(t)
	var dock:=PanelContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left=28
	dock.offset_right=-28
	dock.offset_top=-78
	dock.offset_bottom=-24
	dock.add_theme_stylebox_override("panel",_style())
	add_child(dock)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	dock.add_child(row)
	status_label=Label.new()
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	var hints:=Label.new()
	hints.text="L stick  Browse · D-pad / arrows  Select · LB / Z  Zoom"
	hints.add_theme_color_override("font_color",Color("#cdbf9e"))
	row.add_child(hints)
	confirm_button=Button.new()
	row.add_child(confirm_button)
	back_button=Button.new()
	row.add_child(back_button)

class Pins extends Control:
	var owner_view
	func _draw() -> void:
		if not owner_view or not owner_view._navigation or owner_view._navigation.is_travelling():
			return
		var font:=get_theme_default_font()
		var points:Dictionary=owner_view._projections()
		for id in points:
			var p:Vector2=points[id]
			if not Rect2(Vector2(21,100),size-Vector2(42,205)).has_point(p):
				continue
			var x:=(-20. if id==owner_view.CAMP else 17.)
			var q:=p+Vector2(x,16.)
			var selected:bool=owner_view._navigation.selected_waypoint_id()==id
			var ink:=Color("#eed39b") if selected else Color("#c4c7b0")
			draw_line(p,q,ink,1.1,true)
			draw_circle(q,8.8,Color("#171b21"),true,-1.,true)
			draw_circle(q,5.8,ink,true,-1.,true)
			var label: String=owner_view._world.waypoint(id).label
			var extent:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			var left:=clampf(q.x-extent*.5-6.,22.,size.x-36.-extent)
			draw_rect(Rect2(Vector2(left,q.y+15.),Vector2(extent+12.,24.)),Color("#15201deb"))
			draw_string(font,Vector2(left+6.,q.y+32.),label,HORIZONTAL_ALIGNMENT_LEFT,-1.,16,Color("#f2e8cc"))
