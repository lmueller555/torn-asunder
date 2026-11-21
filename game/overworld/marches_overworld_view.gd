extends "res://game/campaign_overworld_3d.gd"
## Concrete composition for the authored three-waypoint Marches review slice.
## The title screen's private factory controls whether this scene is mounted.

const Crossing := preload("res://game/overworld/marches_crossing_site.gd")
const CampSite := preload("res://game/overworld/marches_camp_site.gd")
const RendererScene := preload("res://game/overworld/marches_overworld_renderer.tscn")
const DisplayFont := preload("res://assets/fonts/Cinzel.ttf")
const BODY := Color("#f2e6cb")
const SECONDARY := Color("#cfbd91")
const PANEL := Color(0.067,0.092,0.078,0.91)
const ACCENT := Color("#bb925e")
const DATA := "res://assets/overworld/marches/anchors.json"
const MARKERS := {
	"marches_camp": "FIELD CAMP", "year_one_mine": "STORY MISSION", "marches_road": "ROAD LINK", "marches_road_camp": "FORWARD CAMP", "marches_crossing": "STORY MISSION",
}

var _pins: Pins
var _header: Control


func build() -> bool:
	if not Crossing.available():
		return false
	var route_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not route_data is Dictionary:
		return false
	var points: Dictionary[String,Vector3] = {}
	for id: String in route_data.anchors:
		var data: Array = route_data.anchors[id]
		points[id]=Vector3(data[0],data[1],data[2])
	var curves: Dictionary[String,Curve3D] = {}
	for row: Dictionary in route_data.routes:
		var curve := Curve3D.new()
		curve.bake_interval = 1.15
		for data: Array in row.points:
			curve.add_point(Vector3(data[0],data[1],data[2]))
		curves[route_key(row.start,row.end)]=curve
	var crossing_curve := Crossing.route()
	if not crossing_curve or crossing_curve.point_count!=265 or not points.has(Crossing.ROAD) 			or not crossing_curve.get_point_position(0).is_equal_approx(points[Crossing.ROAD]):
		return false
	points[Crossing.ID]=crossing_curve.get_point_position(crossing_curve.point_count-1)
	curves[route_key(Crossing.ROAD,Crossing.ID)]=crossing_curve
	var spur := CampSite.route()
	if spur.size()>1 and points.has(CampSite.ROAD_ID) and spur[0].is_equal_approx(points[CampSite.ROAD_ID]) \
			and ResourceLoader.exists(CampSite.ASSETS+"marches-road-camp-fit.glb","PackedScene") \
			and ResourceLoader.exists(CampSite.ASSETS+"marches-road-camp-fit-regional.glb","PackedScene"):
		var camp_curve:=Curve3D.new()
		camp_curve.bake_interval=1.15
		for point in spur:
			camp_curve.add_point(point)
		points[CampSite.CAMP_ID]=spur[-1]
		curves[route_key(CampSite.ROAD_ID,CampSite.CAMP_ID)]=camp_curve
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface = SubViewportContainer.new()
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
	_build_controls()
	if not configure_renderer(RendererScene,^"Camera",^"Party",points,curves,34.0):
		return false
	_renderer.presentation_camera_changed.connect(_pins.queue_redraw)
	return true


func configure(world: World, completed_ids: PackedStringArray, reduced_motion: bool) -> void:
	super.configure(world,completed_ids,reduced_motion)
	if is_instance_valid(_renderer):
		_renderer.configure_overworld_art(_world,completed_ids,reduced_motion)


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_pins):
		_pins.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _navigation==null:
		return
	var zoom := false
	if event is InputEventKey and event.pressed and not event.echo:
		zoom=event.keycode==KEY_Z
	elif event is InputEventMouseButton and event.pressed:
		zoom=event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]
	elif event is InputEventJoypadButton and event.pressed:
		zoom=event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]
	if zoom and _points.has(_navigation.selected_waypoint_id()):
		_renderer.toggle_zoom(_points[_navigation.selected_waypoint_id()])
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)


func _update_party() -> void:
	super._update_party()
	if is_instance_valid(_renderer):
		_renderer.show_party_state(_navigation.is_travelling(),_navigation.selected_waypoint_id())
	if is_instance_valid(_pins):
		_pins.queue_redraw()


func _style(left_border: int) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color=PANEL
	skin.border_color=ACCENT
	skin.border_width_left=left_border
	skin.border_width_top=1
	skin.content_margin_left=14
	skin.content_margin_right=14
	skin.content_margin_top=9
	skin.content_margin_bottom=9
	return skin


func _line(parent: Control, value: String, size: int, tint: Color, title := false) -> Label:
	var line := Label.new()
	line.text=value
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size",size)
	line.add_theme_color_override("font_color",tint)
	if title:
		line.add_theme_font_override("font",DisplayFont)
	parent.add_child(line)
	return line


func _build_header() -> void:
	var box := PanelContainer.new()
	box.position=Vector2(28,24)
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size.x=370
	box.add_theme_stylebox_override("panel",_style(2))
	add_child(box)
	var lines := VBoxContainer.new()
	lines.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(lines)
	_line(lines,"VARETH   /   YEAR THREE",13,SECONDARY)
	_line(lines,"The Seven Marches",29,BODY,true)
	_line(lines,"Mara Halden  ·  The King’s Water",15,SECONDARY)
	_header=box


func _build_controls() -> void:
	var dock := PanelContainer.new()
	dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left=28
	dock.offset_right=-28
	dock.offset_top=-69
	dock.offset_bottom=-25
	dock.add_theme_stylebox_override("panel",_style(0))
	add_child(dock)
	var controls := HBoxContainer.new()
	controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	controls.add_theme_constant_override("separation",18)
	dock.add_child(controls)
	status_label=_line(controls,"",16,BODY)
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var legend:=_line(controls,"D-pad / arrows   Select    ·    Z / shoulder   Zoom",14,SECONDARY)
	legend.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	confirm_button=Button.new()
	confirm_button.custom_minimum_size.x=175
	controls.add_child(confirm_button)
	back_button=Button.new()
	back_button.custom_minimum_size.x=93
	controls.add_child(back_button)


func _select_at(point: Vector2) -> bool:
	for id: String in _pins.label_regions:
		if _pins.label_regions[id].has_point(point):
			return select_waypoint(id)
	return super._select_at(point)


class Pins extends Control:
	var map: Control
	var _face := ThemeDB.fallback_font
	var label_regions: Dictionary[String, Rect2] = {}

	func _draw() -> void:
		label_regions.clear()
		if not is_instance_valid(map) or map._world==null or not is_instance_valid(map._camera):
			return
		var projected: Dictionary = map._projections()
		for id: String in map.MARKERS:
			if not projected.has(id): continue
			var point: Vector2 = projected[id]
			if point.y<120 or point.y>size.y-110 or point.x<45 or point.x>size.x-200: continue
			var site: Dictionary = map._world.waypoint(id)
			if site.is_empty(): continue
			var kind: String = map.MARKERS[id]
			var locked: bool = id=="marches_road" and map._renderer._link_locked("year_one_mine",id)
			var color:=Color("#c5b8a9") if locked else Color("#e3c77f")
			draw_circle(point,10,map.PANEL)
			if locked:
				draw_polyline(PackedVector2Array([point+Vector2(0,-9),point+Vector2(9,0),point+Vector2(0,9),point+Vector2(-9,0),point+Vector2(0,-9)]),color,2,true)
				draw_line(point+Vector2(-3,0),point+Vector2(3,0),color,2,true)
				kind="LOCKED ROAD"
			else:
				draw_arc(point,9 if map._navigation.selected_waypoint_id()==id else 7,0,TAU,20,color,2,true)
				draw_circle(point,2,color)
			var width:=_face.get_string_size(site.label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			var y_offset := 17.0 if id in [CampSite.CAMP_ID,"marches_crossing"] else -27.0
			var x_offset := -width-28.0 if id==CampSite.ROAD_ID and projected.has(CampSite.CAMP_ID) else 13.0
			var pos:=Vector2(clampf(point.x+x_offset,12.0,size.x-width-29.0),point.y+y_offset)
			if id in [CampSite.CAMP_ID,"marches_crossing"]:
				draw_line(point+Vector2(4,6),Vector2(pos.x+5,pos.y),color,1.3,true)
			var bounds := Rect2(pos,Vector2(width+16,40))
			label_regions[id] = bounds
			draw_rect(bounds,map.PANEL)
			draw_string(_face,pos+Vector2(8,15),kind,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
			draw_string(_face,pos+Vector2(8,32),site.label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,map.BODY)
		if not map._navigation.is_travelling():
			_draw_offscreen_connections(projected)
		if map._navigation.is_travelling():
			var vp := Vector2(map.render_viewport.size)
			var party_world: Vector3 = map._party.global_position+Vector3.UP*5.0
			if vp.x>0 and vp.y>0 and not map._camera.is_position_behind(party_world):
				var point: Vector2 = map._camera.unproject_position(party_world)*size/vp
				draw_colored_polygon(PackedVector2Array([point+Vector2(0,4),point+Vector2(-8,-13),point+Vector2(8,-13)]),map.PANEL)
				draw_colored_polygon(PackedVector2Array([point,point+Vector2(-5,-10),point+Vector2(5,-10)]),Color("#e8c780"))

	func _draw_offscreen_connections(projected: Dictionary) -> void:
		var here: String = map._world.current_waypoint_id()
		if here != "marches_crossing":
			return
		for row: Dictionary in map._world.route_options(map._confirmed):
			var id: String = row.waypoint_id
			if not row.is_open or not map._curve_for(here,id) or not projected.has(id) or label_regions.has(id):
				continue
			var dest: Dictionary = map._world.waypoint(id)
			var to: Vector2 = projected[id]
			var left := to.x <= size.x*0.50
			var width := _face.get_string_size(dest.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+34.0
			var pos := Vector2(28.0 if left else size.x-width-28.0,clampf(to.y,154.0,size.y-147.0))
			var edge := Rect2(pos,Vector2(width,40.0))
			label_regions[id] = edge
			draw_rect(edge,map.PANEL)
			var color := Color("#e3c77f")
			draw_line(pos+Vector2(0.0,0.0),pos+Vector2(width,0.0),color,1.0,true)
			draw_string(_face,pos+Vector2(11,16),"‹   RETURN ROUTE" if left else "RETURN ROUTE   ›",HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
			draw_string(_face,pos+Vector2(11,33),dest.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,map.BODY)
