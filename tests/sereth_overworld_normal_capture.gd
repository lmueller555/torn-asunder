extends SceneTree
const Main:=preload("res://game/title_screen.tscn")
const Title:=preload("res://game/title_screen.gd")
const Shared:=preload("res://game/overworld/mara_sector_title.gd")
const Entry:=preload("res://game/overworld/sereth_normal_entry.gd")
const Profile:=preload("res://game/profile_store.gd")
const World:=preload("res://game/campaign_world.gd")
const Presenter:=preload("res://game/overworld/sereth/sereth_normal_presenter.gd")

func _initialize()->void:
	_go.call_deferred()

func _go()->void:
	var options:=OS.get_cmdline_user_args()
	var out:=options[0]
	var station:=options[1]
	var waypoint: String={ "camp":Presenter.CAMP, "cut":Presenter.CUT, "keeper":Presenter.KEEPER, "assembly":Presenter.ASSEMBLY }[station]
	var path:="user://native-sereth-normal-%s-%d.cfg"%[station,Time.get_ticks_usec()]
	var profile:=Profile.new(path)
	assert(Entry.requested(), "use the normal Sereth release configuration")
	assert(profile.mark_played("sereth")==OK)
	ProjectSettings.set_setting(Entry.SWITCH,true)
	if waypoint in [Presenter.KEEPER,Presenter.ASSEMBLY]:
		assert(profile.record_mission_clear("sereth",Presenter.Lower.CLEAR)==OK)
	if waypoint==Presenter.ASSEMBLY:
		assert(profile.record_mission_clear("sereth",Presenter.Upper.CLEAR)==OK)
	assert(profile.record_world_waypoint(World.new("sereth",waypoint,profile.completed_missions("sereth")))==OK)
	var scene:=Main.instantiate() as Title
	root.add_child(scene)
	current_scene=scene
	for i in range(8):
		await process_frame
		if current_scene is Shared:
			break
	var host:=current_scene as Shared
	assert(host)
	host._profile=Profile.new(path)
	host._show_title()
	var resume:=host._stage.find_child("Continue",true,false) as Button
	assert(resume and not resume.disabled)
	resume.pressed.emit()
	for i in 6:
		await physics_frame
	var view:=host._stage.get_child(0)
	assert(host._sereth_presenter and host._sereth_presenter._mounted(view))
	assert(host._profile.load_campaign_world("sereth").current_waypoint_id()==waypoint)
	await _record(out,"normal-sereth-"+station+"-regional")
	if view is Presenter.CutView:
		view.flip_lens()
	else:
		view._renderer.toggle_zoom(view._points[waypoint])
	await _record(out,"normal-sereth-"+station+"-near")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Sereth normal windowed "+station+": 2/2 exact native title frames.")
	quit()

func _record(out:String,name_:String)->void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	assert(img.get_size()==Vector2i(1120,630))
	assert(img.save_jpg(out.path_join(name_+".jpg"),.89)==OK)
