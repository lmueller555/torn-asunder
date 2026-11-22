extends "res://game/campaign_overworld_3d.gd"
## Private shared-host adapter. Canonical off-sector IDs are never projected.
signal world_committed(world: World)
const Store:=preload("res://game/profile_store.gd")
const Early:=preload("res://game/overworld/raska/raska_transfer.gd")
const Later:=preload("res://game/overworld/raska/later_transfer.gd")
const Basin:=preload("res://game/overworld/raska/basin_camp.tscn")
const Fonts:=preload("res://assets/fonts/Cinzel.ttf")
const TONE:=Color("#1b2219f0")
var _profile:Store
var _prepared:Node3D
var _ports:Dictionary[String,Vector3]={}
var _choices:Dictionary[String,Array]={}
var _port:=""
var _option:=0
var _busy:=false
var _token:=0
var _gate:RefCounted
var _early:=Early.new()
var _later:=Later.new()
var _post_commit:=Vector3.INF
var _hero_origin:=Vector3.INF
var _course:=Curve3D.new()
var _progress:=0.
var _duration:=0.
var _error:=""
var _near:=false
var _header:Label
var _map_card:Label
var _caption:Label
var _zoom:Button

func build_for_raska(world:World,store:Store)->bool:
	if not world or world.campaign_id()!="raska" or not store: return false
	_profile=store
	var id:=world.current_waypoint_id()
	var packed:PackedScene=Basin if id==Early.CAMP else Later.LAND.get(id)
	if not packed: return false
	_prepared=packed.instantiate()
	if not _preflight(_prepared,id):
		_prepared.free()
		_prepared=null
		return false
	_build_shell()
	configure(world,store.completed_missions("raska"),store.setting("reduced_motion"))
	return true

func _preflight(node:Node3D,id:String)->bool:
	if not node or not node.get_node_or_null("Camera") is Camera3D: return false
	if id==Later.GREY: return node.prepare_exact_exterior()
	if id in [Later.WELL,Later.LOCK]: return node.prepare_exact_land()
	return id==Early.CAMP

func _ready()->void:
	name=&"RaskaOverworld"
	_bind_sector(_prepared)
	_prepared=null
	super._ready()

func _build_shell()->void:
	map_surface=SubViewportContainer.new()
	map_surface.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	map_surface.stretch=true
	add_child(map_surface)
	render_viewport=SubViewport.new()
	render_viewport.own_world_3d=true
	render_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	map_surface.add_child(render_viewport)
	var panel:=PanelContainer.new()
	var skin:=StyleBoxFlat.new()
	skin.bg_color=TONE
	skin.content_margin_left=16; skin.content_margin_right=16
	skin.content_margin_top=10; skin.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",skin)
	add_child(panel)
	panel.position=Vector2(26,22)
	var stack:=VBoxContainer.new()
	panel.add_child(stack)
	_header=Label.new()
	_header.add_theme_color_override("font_color",Color("#dfc699"))
	_header.add_theme_font_size_override("font_size",13)
	stack.add_child(_header)
	_map_card=Label.new()
	_map_card.add_theme_font_override("font",Fonts)
	_map_card.add_theme_font_size_override("font_size",27)
	stack.add_child(_map_card)
	_caption=Label.new()
	_caption.add_theme_font_size_override("font_size",14)
	stack.add_child(_caption)
	var foot:=PanelContainer.new()
	foot.add_theme_stylebox_override("panel",skin)
	add_child(foot)
	foot.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	foot.offset_left=24; foot.offset_right=-24; foot.offset_top=-64; foot.offset_bottom=-18
	var bar:=HBoxContainer.new()
	foot.add_child(bar)
	status_label=Label.new()
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.add_child(status_label)
	_zoom=Button.new()
	_zoom.focus_mode=Control.FOCUS_NONE
	_zoom.text="Zoom [Z / LB]"
	_zoom.pressed.connect(_toggle_lens)
	bar.add_child(_zoom)
	confirm_button=Button.new()
	bar.add_child(confirm_button)
	back_button=Button.new()
	bar.add_child(back_button)

func _retire_sector(old:Node3D)->void:
	var grove_materials:Array[Material]=[]
	if old.scene_file_path==Later.LAND[Later.GREY].resource_path:
		# The imported groves use transient vertex-pigment copies. Keep those RIDs
		# alive through one complete renderer update after freeing the old scene.
		for copse:Node in old.get_children():
			if copse.scene_file_path!="res://assets/overworld/marches/marches-copse-near.glb":
				continue
			for mesh:MeshInstance3D in copse.find_children("*","MeshInstance3D",true,false):
				for slot in mesh.get_surface_override_material_count():
					var pigment:=mesh.get_surface_override_material(slot)
					if pigment is StandardMaterial3D and pigment.resource_path.is_empty():
						grove_materials.append(pigment)
	# Geometry and physics unregister at once; only small materials outlive it.
	render_viewport.remove_child(old)
	old.free()
	if not grove_materials.is_empty():
		for frame in range(2):
			await get_tree().process_frame
		grove_materials.clear()


func _bind_sector(next:Node3D)->void:
	if is_instance_valid(_renderer):
		_retire_sector(_renderer)
	_renderer=next
	render_viewport.add_child(_renderer)
	_camera=_renderer.get_node("Camera")
	_camera.make_current()
	if _world.current_waypoint_id()==Later.GREY:
		for child in _renderer.get_children():
			if child is CanvasLayer: child.hide()
	_party=Node3D.new()
	_party.name="PartyAnchor"
	_renderer.add_child(_party)
	var stand:=MeshInstance3D.new()
	var mantle:=CylinderMesh.new()
	mantle.top_radius=.84; mantle.bottom_radius=1.04; mantle.height=.35
	stand.mesh=mantle
	var gold:=StandardMaterial3D.new()
	gold.albedo_color=Color("#cfac72")
	stand.material_override=gold
	stand.position.y=.24
	_party.add_child(stand)
	if is_instance_valid(_compass):
		# Recreate base's presentation-only march under the new renderer.
		_station_geometry.assign([stand])
		_march=MarchMarker.new()
		_march.build(_world.campaign_id())
		_party.add_child(_march)
		_march.hide()
	_configure_local_ports()
	_apply_lens()

func _configure_local_ports()->void:
	var here:=_world.current_waypoint_id()
	_ports.clear()
	_choices.clear()
	_points.clear()
	_near=false
	match here:
		Early.CAMP:
			_points[here]=_renderer.world(_renderer.CAMP) if not _post_commit.is_finite() else _post_commit
			_ports["northwest_port"]=_renderer.world(_renderer.RIM)
			_choices["northwest_port"]=[Later.GREY]
		Later.GREY:
			_points[here]=_renderer.arrival_ground
			_ports["west_shelf"]=_renderer.arrival_ground
			_choices["west_shelf"]=[Early.CAMP,Later.WELL]
		Later.WELL:
			_points[here]=_renderer.west_ground if not _post_commit.is_finite() else _post_commit
			_ports["west_road"]=_renderer.west_ground
			_ports["east_road"]=_renderer.east_ground
			_choices["west_road"]=[Later.GREY]
			_choices["east_road"]=[Later.LOCK]
		Later.LOCK:
			_points[here]=_renderer.north_ground
			_ports["north_causeway"]=_renderer.north_ground
			_choices["north_causeway"]=[Later.WELL]
	_post_commit=Vector3.INF
	_port=""
	_option=0
	_party.position=_points[here]

func _projections()->Dictionary[String,Vector2]:
	var projected:=super._projections()
	if not _renderer or Vector2(render_viewport.size).x<=0.: return projected
	for id in _ports:
		var pos:=_renderer.to_global(_ports[id])
		if _camera.is_position_behind(pos): continue
		var raw:=_camera.unproject_position(pos)
		projected[id]=raw*map_surface.size/Vector2(render_viewport.size)
	return projected

func select_waypoint(id:String)->bool:
	if _busy: return false
	if _ports.has(id):
		if _port!=id: _option=0
		_port=id
		_has_focus=true
		if is_instance_valid(_compass): _compass.follow(id)
		_refresh()
		return true
	_port=""
	return super.select_waypoint(id)

func _pick_at(point:Vector2)->String:
	var all:=_projections()
	var here:=_world.current_waypoint_id()
	# Coincident port/station honestly share one fixed map position. Their cut
	# choices are browsed with Tab/Y, not a second invented physical marker.
	var closest:=PICK_RADIUS
	var hit:=""
	for id in all:
		if id!=here and _points[here].distance_to(_ports[id])<.15: continue
		var d:=point.distance_to(all[id])
		if d<closest and Rect2(Vector2.ZERO,size).has_point(all[id]):
			closest=d
			hit=id
	return hit

func _preview_at(point:Vector2)->void:
	if _busy: return
	var picked:=_pick_at(point)
	if _ports.has(picked):
		if picked!=_port: _option=0
		_port=picked
		_has_focus=true
		_refresh()
	else:
		var old:=_port
		_port=""
		super._preview_at(point)
		if not old.is_empty(): _refresh()

func _update_compass()->void:
	super._update_compass()
	if not is_instance_valid(_compass): return
	_compass.visible=not _busy
	if _busy: return
	var all:=_projections()
	for id in _ports:
		if all.has(id) and _any_open(id) and _points[_world.current_waypoint_id()].distance_to(_ports[id])>.15:
			_compass.available.append(all[id])
	if _ports.has(_port) and _has_focus:
		var dst:=_destination()
		var lines:=PackedStringArray(["Cross to "+_world.waypoint(dst).label])
		lines.append("At the local port · separate area")
		if not _open(dst):
			var key:=Later.required_clear(_world.current_waypoint_id(),dst)
			lines.append("Requires: "+Missions.mission_for_campaign("raska",key).get("title","Campaign progress"))
		if _choices[_port].size()>1: lines.append("Tab / Y: next crossing")
		_compass.preview=lines
	_compass.queue_redraw()

func _destination()->String:
	return _choices[_port][_option] if _choices.has(_port) else ""

func _open(dst:String)->bool:
	for edge in _world.route_options(_profile.completed_missions("raska")):
		if edge.waypoint_id==dst: return edge.is_open
	return false

func _any_open(id:String)->bool:
	for dst in _choices.get(id,[]):
		if _open(dst): return true
	return false

func _refresh()->void:
	super._refresh()
	if not is_node_ready() or not _renderer or not _world: return
	var here:=_world.current_waypoint_id()
	_header.text="VARETH   /   "+("YEAR FOUR" if here==Later.LOCK else "YEAR THREE")
	_map_card.text="Spanwater · North Causeway" if here==Later.LOCK else _world.waypoint(here).label
	_caption.text="Raska Vennor  ·  "+("After the Greyhollow rescue" if here==Later.GREY else "War Marshal")
	if _busy:
		confirm_button.disabled=true
		confirm_button.text="Crossing…" if _token else "Marching…"
		back_button.text="Cancel Travel"
		status_label.text="Cross to "+_world.waypoint(_destination()).label
	elif _choices.has(_port):
		var dst:=_destination()
		confirm_button.disabled=not _open(dst)
		confirm_button.text="Cross to "+_world.waypoint(dst).label if _open(dst) else "Crossing Locked"
		status_label.text="Local port  ·  Tab / Y: next crossing"
	elif not _error.is_empty():
		status_label.text=_error
	else:
		status_label.text="Arrows / D-pad · Cursor: mouse or left stick · Tab / Y: crossings"

func cycle_crossing()->void:
	if _busy or _ports.is_empty(): return
	var ids:=_ports.keys()
	if _choices.has(_port) and _option+1<_choices[_port].size():
		_option+=1
		_refresh()
		return
	var index:=ids.find(_port)
	if index+1>=ids.size():
		select_waypoint(_world.current_waypoint_id())
	else:
		select_waypoint(ids[index+1])

func confirm_selection()->void:
	if _busy or not _has_focus: return
	if not _choices.has(_port):
		super.confirm_selection()
		return
	var dest:=_destination()
	if not _open(dest): return
	_fill_approach()
	_busy=true
	_error=""
	_progress=0.
	_duration=clampf(_course.get_baked_length()/74.,.69,2.8)
	_refresh()
	if _reduced_motion or _course.get_baked_length()<.16:
		_party.position=_ports[_port]
		_commit_at_port(dest)

func _fill_approach()->void:
	_course.clear_points()
	_hero_origin=_party.position
	_course.add_point(_hero_origin)
	var end:=_ports[_port]
	var here:=_world.current_waypoint_id()
	if here==Early.CAMP and _hero_origin.distance_to(end)>2.4:
		for idx in range(_renderer.COURSE.size()-1):
			var p:Vector2=_renderer.COURSE[idx]
			var q:Vector2=_renderer.COURSE[idx+1]
			for i in range(1,11): _course.add_point(_renderer.world(p.lerp(q,i*.1)))
	elif here==Later.WELL and _hero_origin.distance_to(end)>2.4:
		for i in range(1,41):
			var p:=_hero_origin.lerp(end,i/40.)
			_course.add_point(_renderer.at(Vector2(p.x,p.z)))
	if _course.get_point_position(_course.point_count-1).distance_to(end)>.04: _course.add_point(end)

func _update_party()->void:
	if not _busy: super._update_party()

func _process(dt:float)->void:
	if not _busy:
		super._process(dt)
		return
	if _token: return
	_progress=minf(_duration,_progress+dt)
	var length:=_course.get_baked_length()
	var travelled:=_progress/_duration*length
	_party.position=_course.sample_baked(travelled)
	for part in _station_geometry: part.hide()
	_march.show()
	var ahead:=_renderer.to_global(_course.sample_baked(minf(length,travelled+4.)))
	ahead.y=_march.global_position.y
	if ahead.distance_squared_to(_march.global_position)>.0001: _march.look_at(ahead)
	_march.step(dt)
	if _progress==_duration: _commit_at_port(_destination())

func _commit_at_port(dest:String)->void:
	var here:=_world.current_waypoint_id()
	_gate=_early if Early.is_sector_edge(here,dest) else _later
	_token=_gate.begin(_profile,_world,dest,_renderer,_party.global_position)
	if not _token:
		_cancel_travel("Could not cross from this port.")
		return
	_refresh()
	_finish_crossing(_token,_gate)

func _finish_crossing(serial:int,gate:RefCounted)->void:
	await get_tree().process_frame
	if not is_inside_tree() or not _busy or gate!=_gate or serial!=_token: return
	var candidate:Node3D=gate.prepare(serial)
	var receipt:Variant=gate.finish(serial,_world,candidate)
	if not receipt.world:
		if candidate: candidate.free()
		_cancel_travel("Travel was not saved. You are still here.")
		return
	_token=0
	_gate=null
	_busy=false
	_error=""
	_world=receipt.world
	_post_commit=receipt.local_arrival if gate==_early else receipt.point
	_bind_sector(candidate)
	configure(_world,_profile.completed_missions("raska"),_reduced_motion)
	world_committed.emit(_world)

func _cancel_travel(text:="Travel cancelled.")->void:
	if _token and _gate: _gate.cancel(_token)
	_token=0
	_busy=false
	_gate=null
	_port=""
	_error=text
	_has_focus=true
	_compass.follow(_world.current_waypoint_id())
	_refresh()

func _back_or_cancel()->void:
	if _busy: _cancel_travel()
	elif _choices.has(_port): select_waypoint(_world.current_waypoint_id())
	else: super._back_or_cancel()

func _toggle_lens()->void:
	if _busy: return
	_near=not _near
	_apply_lens()
	_update_compass()

func _apply_lens()->void:
	match _world.current_waypoint_id():
		Later.LOCK: _renderer.set_lens(_near)
		Later.WELL: _renderer.set_camera(_near)
		Early.CAMP: _renderer.set_camera(_near)
		Later.GREY:
			_camera.position=Vector3(55,90,-4) if _near else Vector3(76,169,74)
			_camera.look_at(Vector3(-8,36,-57))

func _unhandled_input(event:InputEvent)->void:
	if event.is_pressed() and not event.is_echo():
		if (event is InputEventKey and event.keycode==KEY_TAB) or (event is InputEventJoypadButton and event.button_index==JOY_BUTTON_Y):
			cycle_crossing()
			get_viewport().set_input_as_handled()
			return
		if (event is InputEventKey and event.keycode==KEY_Z) or (event is InputEventJoypadButton and event.button_index==JOY_BUTTON_LEFT_SHOULDER):
			_toggle_lens()
			get_viewport().set_input_as_handled()
			return
	if _busy:
		if event.is_action_pressed("ui_cancel"): _cancel_travel()
		return
	if event.is_pressed() and not event.is_echo():
		var direction:=Vector2.ZERO
		if event is InputEventKey:
			match event.keycode if event.keycode!=KEY_NONE else event.physical_keycode:
				KEY_LEFT: direction=Vector2.LEFT
				KEY_RIGHT: direction=Vector2.RIGHT
				KEY_UP: direction=Vector2.UP
				KEY_DOWN: direction=Vector2.DOWN
		elif event is InputEventJoypadButton:
			match event.button_index:
				JOY_BUTTON_DPAD_LEFT: direction=Vector2.LEFT
				JOY_BUTTON_DPAD_RIGHT: direction=Vector2.RIGHT
				JOY_BUTTON_DPAD_UP: direction=Vector2.UP
				JOY_BUTTON_DPAD_DOWN: direction=Vector2.DOWN
		if not direction.is_zero_approx() and _select_local_direction(direction):
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _select_local_direction(d:Vector2)->bool:
	var points:=_projections()
	var here:=_world.current_waypoint_id()
	var origin_id:=_port if points.has(_port) else here
	if not points.has(origin_id): return false
	var winner:=""
	var score:=0.22
	for id in points:
		var offset:Vector2=points[id]-points[origin_id]
		if offset.length()<.1: continue
		var alignment:=offset.normalized().dot(d)
		if alignment>score:
			score=alignment
			winner=id
	return select_waypoint(winner) if not winner.is_empty() else false
