extends SceneTree
const Main:=preload("res://game/title_screen.tscn")
const Title:=preload("res://game/title_screen.gd")
const Shared:=preload("res://game/overworld/mara_sector_title.gd")
const Entry:=preload("res://game/overworld/sereth_normal_entry.gd")
const Profile:=preload("res://game/profile_store.gd")
const World:=preload("res://game/campaign_world.gd")
const Presenter:=preload("res://game/overworld/sereth/sereth_normal_presenter.gd")
const Flat:=preload("res://game/campaign_map.gd")
const Beats:=preload("res://game/campaign_dialogues.gd")
const Campaigns:=preload("res://game/campaigns.gd")
const SERETH:="sereth"
var path:="user://normal-sereth-%d-%d.cfg"%[OS.get_process_id(),Time.get_ticks_usec()]
var host:Shared
var tests:=0
var failures:=0
var neighbor_flags: Dictionary[String,bool]={}

func _initialize()->void:
	_run.call_deferred()

func check(ok:bool,message:String)->bool:
	tests+=1
	if not ok:
		failures+=1
		push_error(message)
	return ok

func _run()->void:
	_check_defaults()
	var seed:=Profile.new(path)
	seed.mark_played(SERETH)
	for other in ["sova","neris"]:
		seed.record_mission_clear(other,Presenter.Lower.CLEAR)
		seed.record_mission_clear(other,Presenter.Upper.CLEAR)
	ProjectSettings.set_setting(Entry.SWITCH,false)
	host=await _mount()
	check(_press("Continue") and _map() is Flat and not host._sereth_presenter,
		"actual normal Continue is stock only during explicit fallback test")
	await _close()
	ProjectSettings.set_setting(Entry.SWITCH,true)
	for id in ["mara","ilyra","sova","raska","neris"]:
		var key: String="torn_asunder/"+id+"_3d_overworld"
		if ProjectSettings.has_setting(key):
			neighbor_flags[key]=ProjectSettings.get_setting(key)
			ProjectSettings.set_setting(key,false)
	host=await _mount()
	check(host!=null,"Sereth-only setting uses actual deferred normal shared root")
	if not host:
		quit(1)
		return
	check(_press("Continue") and _map() is Presenter.CutView and _saved()==Presenter.CAMP,
		"ordinary Continue can resume old native camp")
	await _settle()
	check(host._sereth_presenter._mounted(_map()),"frozen Cut camp/copse attached")
	host._show_title()
	check(_press("New Game"),"normal New Game opens leader selection")
	for i in Campaigns.ALL.size():
		if Campaigns.ALL[i].id==SERETH:
			host._portraits[i].focus_entered.emit()
			break
	check(_press("Begin Campaign") and _beat(Beats.SERETH_CUT_DISPATCH),
		"Begin first dispatch immediately, no forced map detour")
	_advance()
	check(_battle("sereth_cut_playtest.tscn") and _saved()==Presenter.CUT,"actual first Cut battle and waypoint save")
	host._return_from_campaign_battle()
	check(_map() is Presenter.CutView and not _map()._boundary_button.visible,
		"retreat returns to true Cut, no first gate or false clear")
	check(_open_briefing() and _press("Confirm Deployment") and _battle("sereth_cut_playtest.tscn"),
		"repeat first mission remains reachable")
	host._campaign_battle.emit_signal(&"mission_finished",true)
	await process_frame
	check(_beat(Beats.SERETH_CUT_DEBRIEF),"exact first mission terminal signal triggers original debrief")
	_advance()
	check(_map() is Presenter.CutView and _map()._boundary_button.visible and _saved()==Presenter.CUT,
		"own Cut clear and recorded victory open the existing passage")
	_pick_boundary()
	var cut:=_map()
	check(cut._navigation.selected_waypoint_id()==Presenter.KEEPER and _saved()==Presenter.CUT,
		"controller chooses only the current offsector eligible destination without save")
	cut.confirm_button.pressed.emit()
	cut.back_button.pressed.emit()
	await create_timer(.39).timeout
	check(_map()==cut and not cut._boundary_pending and _saved()==Presenter.CUT,"lower forward cancels atomically")
	host._sereth_presenter._force_unavailable_for_test=true
	await _confirm_transfer()
	check(_map()==cut and _saved()==Presenter.CUT and "could not load" in cut.status_label.text,
		"missing native destination preserves old authorized live view and disk")
	host._sereth_presenter._force_unavailable_for_test=false
	await _fault_once(cut,Presenter.CUT)
	await _confirm_transfer()
	var keeper:=_map()
	if not check(keeper is Presenter.KeeperView and _saved()==Presenter.KEEPER and host._sereth_presenter._mounted(keeper),
		"lower commit shows real grounded Year Four Keeper"):
		quit(1)
		return
	check(keeper._published_exits==[Presenter.CUT],"Writ gate hides Assembly despite active before-Writ region")
	_pick_boundary()
	keeper.confirm_button.pressed.emit()
	keeper.back_button.pressed.emit()
	await create_timer(.39).timeout
	check(_map()==keeper and _saved()==Presenter.KEEPER,"lower reverse cancel retains Keeper")
	await _confirm_transfer()
	check(_map() is Presenter.CutView and _saved()==Presenter.CUT,"lower reverse commits original 3D Cut")
	_pick_boundary()
	await _confirm_transfer()
	check(_open_briefing() and _press("Read Dispatch") and _beat(Beats.SERETH_PASS_WRIT_DISPATCH),
		"stock Year Four briefing and original Read Dispatch remain separate")
	_advance()
	check(_press("Confirm Deployment") and _battle("sereth_pass_writ_playtest.tscn"),"actual Pass Writ battle")
	host._campaign_battle.emit_signal(&"mission_finished",true)
	await process_frame
	check(_beat(Beats.SERETH_PASS_WRIT_DEBRIEF),"own Writ mission terminal opens original result")
	_advance()
	keeper=_map()
	check(keeper is Presenter.KeeperView and keeper._published_exits==[Presenter.CUT,Presenter.ASSEMBLY],
		"after own Writ both contextual edges coexist on one shared controller")
	for i in 2:
		_pick_boundary()
	check(keeper._navigation.selected_waypoint_id()==Presenter.ASSEMBLY and _saved()==Presenter.KEEPER,
		"shared Y cycles to Year Five without moving")
	keeper.confirm_button.pressed.emit()
	keeper.back_button.pressed.emit()
	await create_timer(.4).timeout
	check(_map()==keeper and _saved()==Presenter.KEEPER,"upper forward cancellation retains Keeper")
	await _fault_once(keeper,Presenter.KEEPER)
	await _confirm_transfer()
	var court:=_map()
	if not check(court is Presenter.ValleyView and host._sereth_presenter._mounted(court) and _saved()==Presenter.ASSEMBLY,
		"upper commit shows actual outside west Assembly anchor"):
		quit(1)
		return
	check(court._points.size()==1 and host._campaign_world.waypoint("cairnspine_vault_road").is_empty(),
		"no Sova route, handover or authority appears")
	check(_open_briefing() and _press("Read Dispatch") and _beat(Beats.SERETH_NO_PROXY_DISPATCH),
		"exact Year Five stock briefing/dispatch")
	_advance()
	check(_press("Confirm Deployment") and _battle("sereth_no_proxy_playtest.tscn"),"actual No Proxy scene")
	host._return_from_campaign_battle()
	check(_saved()==Presenter.ASSEMBLY and Presenter.Upper.TARGET_MISSION not in host._profile.completed_missions(SERETH),
		"actual retreat keeps Assembly without inventing finale")
	await _close()
	host=await _mount()
	check(_press("Continue") and _map() is Presenter.ValleyView and _saved()==Presenter.ASSEMBLY,"cold Continue native Assembly")
	await _settle()
	host._show_title()
	check(_press("Load") and _press("*Sereth Vale*") and _map() is Presenter.ValleyView and _saved()==Presenter.ASSEMBLY,
		"ordinary Load lists Sereth and restores same point")
	await _settle()
	court=_map()
	_pick_boundary()
	court.confirm_button.pressed.emit()
	court.back_button.pressed.emit()
	await create_timer(.4).timeout
	check(_map()==court and _saved()==Presenter.ASSEMBLY,"upper reverse cancel retains Assembly")
	await _fault_once(court,Presenter.ASSEMBLY)
	await _confirm_transfer()
	check(_map() is Presenter.KeeperView and _saved()==Presenter.KEEPER,"upper reverse commit reaches real Keeper")
	host._show_title()
	ProjectSettings.set_setting(Entry.SWITCH,false)
	check(_press("Continue") and _map() is Flat and _saved()==Presenter.KEEPER,
		"fallback switch returns stock chart without rewriting save")
	host._show_title()
	for key in neighbor_flags:
		ProjectSettings.set_setting(key,neighbor_flags[key])
	check(ProjectSettings.get_setting("torn_asunder/raska_3d_overworld",false)==true,
		"Raska restored after Sereth-only fixture")
	ProjectSettings.set_setting(Entry.SWITCH,true)
	for campaign in Campaigns.ALL:
		if campaign.id=="sova":
			host._open_campaign(campaign)
			break
	await _settle()
	check(host._sova_presenter!=null and host._sereth_presenter==null and host._campaign_world.campaign_id()=="sova",
		"published Sova presenter still opens after switching campaigns")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Sereth normal title source: %d/%d."%[tests-failures,tests])
	quit(0 if not failures else 1)

func _check_defaults() -> void:
	check(Entry.requested(),"released Sereth is enabled without runtime override")
	for key in ["mara","ilyra","sova","raska"]:
		check(ProjectSettings.get_setting("torn_asunder/"+key+"_3d_overworld",false)==true,
			"published neighboring setting unchanged: "+key)

func _mount()->Shared:
	var initial:=Main.instantiate() as Title
	root.add_child(initial)
	current_scene=initial
	for i in 8:
		await process_frame
		if current_scene is Shared:
			break
	var title:=current_scene as Shared
	if title:
		title._profile=Profile.new(path)
		title._show_title()
	return title

func _close()->void:
	host._show_title()
	current_scene=null
	root.remove_child(host)
	host.queue_free()
	await process_frame

func _map()->Control:
	return host._stage.get_child(0) as Control if host._stage.get_child_count() else null

func _saved()->String:
	return Profile.new(path).load_campaign_world(SERETH).current_waypoint_id()

func _press(label:String)->bool:
	var b:=host._stage.find_child(label,true,false) as Button
	if not b or b.disabled:
		return false
	b.pressed.emit()
	return true

func _beat(id:StringName)->bool:
	return host._page==Title.Page.CAMPAIGN_DIALOGUE and host._stage.get_child(0)._beat_id==id

func _advance()->void:
	if host._page!=Title.Page.CAMPAIGN_DIALOGUE:
		return
	var page:=host._stage
	while host._stage==page and page.get_child_count()>0 and page.get_child(0)._active:
		page.get_child(0).advance()

func _battle(suffix:String)->bool:
	return host._page==Title.Page.CAMPAIGN_BATTLE and host._campaign_battle!=null and host._campaign_battle.scene_file_path.ends_with(suffix)

func _open_briefing()->bool:
	var map:=_map()
	map.select_waypoint(host._campaign_world.current_waypoint_id())
	map.confirm_button.pressed.emit()
	return host._page==Title.Page.MISSION_BRIEFING

func _pick_boundary()->void:
	var y:=InputEventJoypadButton.new()
	y.button_index=JOY_BUTTON_Y
	y.pressed=true
	_map()._unhandled_input(y)

func _settle()->void:
	for i in 6:
		await physics_frame

func _confirm_transfer()->void:
	var original:=_map()
	original.confirm_button.pressed.emit()
	for i in 105:
		await physics_frame
		if not is_instance_valid(original) or not original._boundary_pending:
			break
	await _settle()

func _fault_once(station:Control,where:String)->void:
	var blocked:=ProjectSettings.globalize_path(path+".tmp")
	DirAccess.make_dir_absolute(blocked)
	await _confirm_transfer()
	check(_map()==station and _saved()==where and "could not be saved" in station.status_label.text,
		"forced atomic write rollback: "+where)
	DirAccess.remove_absolute(blocked)
