extends SceneTree
## QA enters through the actual shipped root/Continue; no alternate scene script.
const Main:=preload("res://game/title_screen.tscn")
const Title:=preload("res://game/title_screen.gd")
const Entry:=preload("res://game/overworld/sova_normal_entry.gd")
const Profile:=preload("res://game/profile_store.gd")
const World:=preload("res://game/campaign_world.gd")
const Beats:=preload("res://game/campaign_dialogues.gd")
const Route:=preload("res://game/overworld/cairnspine/sova_vault_routes.gd")
const Opening:=preload("res://game/overworld/cairnspine/sova_opener_route.gd")
const View:=preload("res://game/overworld/marches_overworld_view.gd")

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var arg:=OS.get_environment("SOVA_NORMAL_CAPTURE_STATION")
	var stations:Dictionary={"camp":Opening.CAMP,"mine":Opening.MINE,"assembly":Route.ASSEMBLY,"road":Route.ROAD,"vault":Route.VAULT}
	if not stations.has(arg):
		quit(2)
		return
	var where:String=stations[arg]
	ProjectSettings.set_setting(Entry.SWITCH,true)
	var filename:="user://sova_normal_capture_%d_%d.cfg"%[OS.get_process_id(),Time.get_ticks_usec()]
	var profile:=Profile.new(filename)
	var clears:=PackedStringArray()
	if arg in ["assembly","road","vault"]:
		clears.append(Opening.CLEAR)
	if arg in ["road","vault"]:
		clears.append(Route.HEARING)
	for id in clears:
		profile.record_mission_clear("sova",id)
	if arg=="vault":
		profile.record_intermission_seen("sova",Beats.SOVA_GODBRIDLE_HANDOVER)
	if profile.mark_played("sova")!=OK or profile.record_world_waypoint(World.new("sova",where,clears))!=OK:
		quit(3)
		return
	var initial:=Main.instantiate() as Title
	root.add_child(initial)
	current_scene=initial
	for i in range(5):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_script().resource_path.ends_with("mara_sector_title.gd"):
			break
	var title:=current_scene as Title
	title._profile=Profile.new(filename)
	title._show_title()
	var c:=title._stage.find_child("Continue",true,false) as Button
	if not c or c.disabled:
		quit(4)
		return
	c.pressed.emit()
	if title._page==Title.Page.CAMPAIGN_DIALOGUE:
		await frame("normal-"+arg+"-dispatch")
		var layer:=title._stage
		while title._stage==layer and layer.get_child(0)._active:
			layer.get_child(0).advance()
	var map:=title._stage.get_child(0) as View
	if not map or not map._points.has(where):
		quit(5)
		return
	await frame("normal-"+arg+"-regional")
	map._renderer.toggle_zoom(map._points[where])
	await frame("normal-"+arg+"-close")
	print("Sova #293 actual normal Continue native at ",where)
	DirAccess.remove_absolute(filename)
	quit()

func frame(file:String)->void:
	for i in range(14):
		await RenderingServer.frame_post_draw
	var dir:=OS.get_environment("SOVA_NORMAL_CAPTURE_DIR")
	if dir.is_empty():
		dir="user://"
	root.get_texture().get_image().save_jpg(dir.path_join(file+".jpg"),.85)
