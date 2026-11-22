extends SceneTree
const Store:=preload("res://game/profile_store.gd")
const L:=preload("res://game/overworld/raska/later_transfer.gd")
const F:="user://raska-shared-ux-test.cfg"
var passed:=0
func _initialize()->void: run.call_deferred()
func ck(ok:bool,label:String)->void:
	if not ok:
		printerr("FAIL ",label)
		quit(1)
		assert(ok,label)
	passed+=1
func host(title:Node)->Control: return title._stage.get_node_or_null("RaskaOverworld")
func button(view:Node,label:String)->Button:
	for b:Button in view.find_children("*","Button",true,false):
		if b.text==label: return b
	return null
func cap(id:String)->void:
	if OS.get_environment("RASKA_CHAIN_NATIVE")!="1": return
	for i in range(3): await RenderingServer.frame_post_draw
	ck(root.get_texture().get_image().save_jpg(ProjectSettings.globalize_path("res://")+id+".jpg",.87)==OK,"native "+id)
func drain()->void:
	for i in range(5): await process_frame
func move(map:Control,port:String,target:String,expected_option:=0)->void:
	map.select_waypoint(map._world.current_waypoint_id())
	ck(map.select_waypoint(port),"physical local port "+port)
	if expected_option: map.cycle_crossing()
	ck(map._destination()==target and not map.confirm_button.disabled,"correct canonical choice available")
	var old:Variant=weakref(map._renderer)
	map.confirm_selection()
	await drain()
	ck(map._world.current_waypoint_id()==target and old.get_ref()==null,"world committed and old collision tree destroyed")
	ck(Store.new(F).load_campaign_world("raska").current_waypoint_id()==target,"arrival real on disk")
func run()->void:
	DirAccess.remove_absolute(F)
	var title:Node=load("res://game/title_screen.tscn").instantiate()
	var p:=Store.new(F)
	p.set_setting("reduced_motion",true)
	p.set_setting("fullscreen",false)
	title._profile=p
	root.add_child(title)
	await process_frame
	ck(ProjectSettings.get_setting("torn_asunder/raska_3d_overworld",false)==true,"released project normally enables Raska 3D")
	ProjectSettings.set_setting("torn_asunder/raska_3d_overworld",false)
	ProjectSettings.set_setting("torn_asunder/raska_3d_overworld",true)
	button(title._stage,"New Game").pressed.emit()
	title._stage.get_node("raska").pressed.emit()
	ck(title._page==title.Page.CAMPAIGN_DIALOGUE and not host(title),"exact New Game opens dialogue")
	var dialog:Node=title._stage.get_child(0)
	for i in range(12):
		if title._page!=title.Page.CAMPAIGN_DIALOGUE: break
		dialog.advance()
		await process_frame
	ck(title._page==title.Page.CAMPAIGN_BATTLE and title._campaign_battle.scene_file_path.ends_with("raska_mine_witness_campaign.tscn"),"New then plays stock real opener directly")
	title._return_from_campaign_battle()
	await drain()
	var map:=host(title)
	ck(map!=null and map._world.current_waypoint_id()==L.GREY and map.get_script().get_base_script().resource_path.ends_with("campaign_overworld_3d.gd"),"real return uses actual shared host")
	ck(not map._projections().has(L.WELL) and map._ports.has("west_shelf"),"no projected point in wrong sector")
	ck(map.confirm_button.text=="Open Battlefield Briefing","real station distinct from cut selection")
	map.select_waypoint("west_shelf"); map.cycle_crossing()
	ck(map._destination()==L.WELL and map.confirm_button.disabled and "One Person to Ask" in " ".join(map._compass.preview),"actual locked requirement")
	await cap("greyhollow-shared-regional")
	map._toggle_lens()
	await cap("greyhollow-shared-near")
	await move(map,"west_shelf","basin_camp")
	ck(p.record_mission_clear("mara","mara_mine_escort")==OK,"foreign fixture")
	ck(map.select_waypoint("northwest_port") and not map.confirm_button.disabled,"real Basin northwest exit")
	await move(map,"northwest_port",L.GREY)
	map.select_waypoint("west_shelf"); map.cycle_crossing()
	ck(map.confirm_button.disabled,"Mara clear did not unlock")
	ck(p.record_mission_clear("raska",L.MINE_CLEAR)==OK,"own true Mine clear fixture")
	await move(map,"west_shelf",L.WELL,1)
	var points:Dictionary=map._projections()
	ck(points.has("east_road") and points.has("west_road") and not points.has(L.LOCK),"only visible authored Well ports")
	var old_disk:=FileAccess.get_file_as_string(F)
	if points.has("east_road"):
		var motion:=InputEventMouseMotion.new()
		motion.position=points["east_road"]
		map._compass.move_pointer(motion.position)
		map._preview_at(motion.position)
		ck(map._port=="east_road" and map._compass.has_point and "The Second Bucket" in " ".join(map._compass.preview),"local mouse hover reuses shared compass and gate copy")
	ck(FileAccess.get_file_as_string(F)==old_disk,"hover read-only")
	map.select_waypoint(L.WELL)
	map.confirm_selection()
	ck(title._page==title.Page.MISSION_BRIEFING,"stock Well Road briefing unchanged")
	title._show_world_map()
	await drain()
	map=host(title)
	ck(p.record_mission_clear("raska",L.WELL_CLEAR)==OK,"own true Well clear fixture")
	map.select_waypoint("east_road")
	map._reduced_motion=false
	map.confirm_selection()
	map._process(.25)
	ck(map._march.visible and map._party.position.distance_to(map._hero_origin)>.05 and map._world.current_waypoint_id()==L.WELL,"reuses actual shared visible fast march, no early persistence")
	map._back_or_cancel()
	ck(not map._busy and not map._march.visible and Store.new(F).load_campaign_world("raska").current_waypoint_id()==L.WELL,"cancel before committed handoff")
	map._reduced_motion=true
	var failed:=F+".tmp"
	DirAccess.remove_absolute(failed)
	ck(DirAccess.make_dir_absolute(failed)==OK,"temporary failure fixture")
	map.select_waypoint("east_road")
	map.confirm_selection()
	await drain()
	ck(map._world.current_waypoint_id()==L.WELL and "not saved" in map.status_label.text,"failed disk remains source, explicit status")
	DirAccess.remove_absolute(failed)
	await move(map,"east_road",L.LOCK)
	ck(map._party.position.z<0 and map._map_card.text.contains("North Causeway") and "YEAR FOUR" in map._header.text,"exact south-free north campaign arrival")
	await cap("north-shared-regional")
	map._toggle_lens()
	await cap("north-shared-near")
	map._back_or_cancel()
	button(title._stage,"Continue").pressed.emit()
	await drain()
	map=host(title)
	ck(map and map._world.current_waypoint_id()==L.LOCK,"Continue actual north saved title")
	map.confirm_selection()
	ck(title._page==title.Page.MISSION_BRIEFING,"canonical River Not Sea briefing")
	title._show_title()
	button(title._stage,"Load").pressed.emit()
	var row:Button
	for item:Button in title._stage.find_children("*","Button",true,false):
		if "Raska" in item.text:
			row=item
			break
	ck(row!=null,"real Load has Raska slot")
	row.pressed.emit()
	await drain()
	ck(host(title)!=null and host(title)._world.current_waypoint_id()==L.LOCK,"true Load resumes saved north")
	ProjectSettings.set_setting("torn_asunder/raska_3d_overworld",false)
	title._show_world_map()
	ck(not host(title),"normal Raska overlay off falls back to stock chart")
	DirAccess.remove_absolute(F)
	title.queue_free()
	await process_frame
	print("Raska shared host: ",passed," checks")
	quit(0)
