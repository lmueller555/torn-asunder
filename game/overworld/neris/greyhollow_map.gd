extends "res://game/overworld/marches_overworld_view.gd"
const Transfer:=preload("res://game/overworld/neris/neris_finale_transfer.gd")
const Scene:=preload("res://game/overworld/neris/neris_greyhollow_sector.tscn")
const SharedMap:=preload("res://game/overworld/marches_overworld_view.gd")
var prepared:Node3D
var caption:Label
var _near:=false

func build()->bool:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface=SubViewportContainer.new()
	map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_surface.stretch=true
	add_child(map_surface)
	render_viewport=SubViewport.new()
	render_viewport.own_world_3d=true
	map_surface.add_child(render_viewport)
	_renderer=prepared if prepared else Scene.instantiate() as Node3D
	prepared=null
	if not _renderer or not _renderer.prepare_exact_exterior():
		if _renderer: _renderer.free()
		return false
	_camera=_renderer.get_node_or_null(^"Camera") as Camera3D
	if not _camera:
		_renderer.free()
		return false
	# No staged soldiers, outcome markers, or invented route at this regional outlook.
	_party=Node3D.new()
	_renderer.add_child(_party)
	_points[Transfer.MINE]=_renderer.arrival_ground
	_pace=1.0
	render_viewport.add_child(_renderer)
	_pins=SharedMap.Pins.new()
	_pins.hide()
	add_child(_pins)
	_renderer.zoom_requested.connect(_flip_lens)
	_hud()
	return true

func _hud()->void:
	var plaque:=PanelContainer.new()
	plaque.position=Vector2(28,24)
	var frame:=StyleBoxFlat.new()
	frame.bg_color=Color("#19211be9")
	frame.border_color=Color("#bda581")
	frame.border_width_top=2
	frame.border_width_left=2
	frame.content_margin_left=14
	frame.content_margin_right=20
	frame.content_margin_top=10
	frame.content_margin_bottom=12
	plaque.add_theme_stylebox_override("panel",frame)
	add_child(plaque)
	var heading:=VBoxContainer.new()
	plaque.add_child(heading)
	for line:Array in [["YEAR THREE  /  SECTOR ARRIVAL",14],["Greyhollow Mine",29],["During the Greyhollow attack",16]]:
		var text:=Label.new()
		text.text=line[0]
		text.add_theme_font_size_override("font_size",line[1])
		heading.add_child(text)
	caption=Label.new()
	caption.text="●  Western outlook"
	caption.add_theme_color_override("font_outline_color",Color("#182519"))
	caption.add_theme_constant_override("outline_size",6)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	var dock:=HBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left=28.0
	dock.offset_right=-28.0
	dock.offset_top=-76.
	dock.offset_bottom=-25.
	dock.add_theme_constant_override("separation",12)
	add_child(dock)
	status_label=Label.new()
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_outline_color",Color("#182519"))
	status_label.add_theme_constant_override("outline_size",5)
	dock.add_child(status_label)
	confirm_button=Button.new()
	dock.add_child(confirm_button)
	back_button=Button.new()
	dock.add_child(back_button)

func _process(delta:float)->void:
	super._process(delta)
	if caption and _camera.is_inside_tree():
		var projected:=_projections()
		if projected.has(Transfer.MINE):
			caption.position=projected[Transfer.MINE]+Vector2(9,13)

func _refresh()->void:
	super._refresh()
	if status_label and _world and not _boundary_pending and _navigation.selected_waypoint_id()==Transfer.MINE:
		status_label.text="At Greyhollow Mine"

func _flip_lens()->void:
	_near=not _near
	_renderer.set_lens(_near)
