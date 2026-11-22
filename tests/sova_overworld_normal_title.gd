extends SceneTree
## Exercises the shipped root scene, normal menu buttons and the real mission
## terminal signals. Fixture signals stand in for winning fights, not story logic.
const Main:=preload("res://game/title_screen.tscn")
const Title:=preload("res://game/title_screen.gd")
const Entry:=preload("res://game/overworld/sova_normal_entry.gd")
const Profile:=preload("res://game/profile_store.gd")
const World:=preload("res://game/campaign_world.gd")
const Opening:=preload("res://game/overworld/cairnspine/sova_opener_route.gd")
const Route:=preload("res://game/overworld/cairnspine/sova_vault_routes.gd")
const Camp:=preload("res://game/overworld/cairnspine/sova_opener_map.gd")
const Court:=preload("res://game/overworld/cairnspine/sova_assembly_map.gd")
const Upper:=preload("res://game/overworld/cairnspine/sova_vault_map.gd")
const Flat:=preload("res://game/campaign_map.gd")
const Beats:=preload("res://game/campaign_dialogues.gd")
const Campaigns:=preload("res://game/campaigns.gd")
var path:="user://normal_sova_%d_%d.cfg"%[OS.get_process_id(),Time.get_ticks_usec()]
var n:=0
var fails:=0

func _initialize()->void:
	run.call_deferred()


func run()->void:
	root.size=Vector2i(1280,720)
	check(Entry.requested(),"tracked default enables Sova’s normal 3D overworld")
	ProjectSettings.set_setting(Entry.SWITCH,false)
	var title:=await mount(path)
	check(not Entry.requested() and title._sova_presenter==null,"explicit opt-out retains the shared normal UI")
	check(title._profile.mark_played("sova")==OK and Profile.new(path).saved_campaigns(Campaigns.ALL).size()==1,"stock saves menu can read its written fixture")
	title._show_title()
	press(title,"Continue")
	check(title._stage.get_child(0) is Flat,"stock Continue retains existing chart with explicit opt-out")
	close_title(title)
	await process_frame
	ProjectSettings.set_setting(Entry.SWITCH,true)
	ProjectSettings.set_setting("torn_asunder/mara_3d_overworld",false)
	ProjectSettings.set_setting("torn_asunder/ilyra_3d_overworld",false)
	title=await mount(path)
	check(title.get_script().resource_path.ends_with("mara_sector_title.gd"),
		"Sova-only opt-in still installs normal shared scene without other flags")
	press(title,"Continue")
	var camp:=title._stage.get_child(0) as Camp
	if not check(camp != null,"opt-in real normal Continue resumes old camp with 3D"):
		quit(1)
		return
	await physics()
	check(is_instance_valid(camp._renderer.camp_art) and camp._points.size()==2,"verified exact Camp and shared Mine native geometry")
	check(camp._navigation.selected_waypoint_id()==Opening.CAMP and not camp.confirm_button.disabled,"existing camp action remains available")
	title._show_title()
	press(title,"New Game")
	press(title,"Begin Campaign")
	check(title._page==Title.Page.CAMPAIGN_DIALOGUE and title._stage.get_child(0)._beat_id==Beats.SOVA_MINE_DISPATCH,
		"ordinary New immediately uses exact proper opening dispatch, not a campaign map detour")
	advance(title)
	check(scene_at(title,"sova_mine_evacuation_campaign.tscn") and saved()==Opening.MINE,
		"ordinary New dispatch deploys exact opening mission directly and stores Mine")
	title._return_from_campaign_battle()
	var mine:=title._stage.get_child(0) as Camp
	check(mine!=null and not is_instance_valid(mine._boundary_button),
		"actual battle Return reaches playable Mine and no own-clear gate available yet")
	check(not mine._points.has(Route.ASSEMBLY),"no fake inter-sector route from Mine")
	mine.confirm_selection()
	check(title._page==Title.Page.MISSION_BRIEFING,"actual Mine replay brief from map")
	press(title,"Confirm Deployment")
	check(scene_at(title,"sova_mine_evacuation_campaign.tscn"),"real replay deploy")
	finish_active_mission(title)
	await process_frame
	check(title._page==Title.Page.CAMPAIGN_DIALOGUE and title._stage.get_child(0)._beat_id==Beats.SOVA_MINE_DEBRIEF,
		"real mission signal triggers registered evacuation debrief")
	advance(title)
	mine=title._stage.get_child(0) as Camp
	check(title._profile.completed_missions("sova")==PackedStringArray([Opening.CLEAR])
		and title._profile.completed_missions("mara").is_empty() and is_instance_valid(mine._boundary_button),
		"own exact evacuation clear only opens the explicit boundary")
	var y:=InputEventJoypadButton.new()
	y.button_index=JOY_BUTTON_Y
	y.pressed=true
	mine._unhandled_input(y)
	check(mine._navigation.selected_waypoint_id()==Route.ASSEMBLY and saved()==Opening.MINE,
		"shared controller Y selects boundary but does not commit")
	mine.confirm_button.pressed.emit()
	check(mine._boundary_pending and saved()==Opening.MINE,"confirm stages transfer before save")
	mine.back_button.pressed.emit()
	await create_timer(.4).timeout
	check(not mine._boundary_pending and saved()==Opening.MINE,"cancel prevents commit and stale staged scene")
	mine.confirm_button.pressed.emit()
	await boundary(mine)
	var court:=title._stage.get_child(0) as Court
	if not check(court!=null and not court is Upper and saved()==Route.ASSEMBLY,
			"committed seam normal title opens the real Year Three Assembly without later roads"):
		quit(1)
		return
	check(court._renderer.relief.has_node(^"OpenAssemblyCourt"),"exact reviewed native civic court under normal title")
	court.confirm_selection()
	press(title,"Read Dispatch")
	check(title._stage.get_child(0)._beat_id==Beats.SOVA_PUBLIC_RECORD_DISPATCH,"real Assembly Read Dispatch")
	advance(title)
	press(title,"Confirm Deployment")
	check(scene_at(title,"sova_public_record_playtest.tscn"),"real Assembly battle ordinary entry")
	finish_active_mission(title)
	await process_frame
	check(title._stage.get_child(0)._beat_id==Beats.SOVA_PUBLIC_RECORD_DEBRIEF,"real Assembly signal opens existing debrief")
	advance(title)
	var upper:=title._stage.get_child(0) as Upper
	check(upper!=null and saved()==Route.ASSEMBLY and upper._points.size()==3,
		"own hearing clear opens actual physical late routes, not a new map mode/detour")
	await physics()
	check(upper._renderer.relief.has_node(^"CairnspineVaultThreshold"),"exact legibility-approved closed threshold is mounted")
	walk(upper,Route.ROAD)
	check(saved()==Route.ROAD and title._page==Title.Page.CAMPAIGN_DIALOGUE
		and title._stage.get_child(0)._beat_id==Beats.SOVA_GODBRIDLE_HANDOVER and not seen(),
		"Road commits the real canonical waypoint before unacknowledged actual handover")
	close_title(title)
	await process_frame
	title=await mount(path)
	press(title,"Continue")
	check(title._page==Title.Page.CAMPAIGN_DIALOGUE and title._stage.get_child(0)._beat_id==Beats.SOVA_GODBRIDLE_HANDOVER,
		"cold ordinary Continue reopens only unread actual Road handover")
	advance(title)
	upper=title._stage.get_child(0) as Upper
	check(upper != null and seen() and saved()==Route.ROAD,"acknowledged once and returns to real Road pin")
	title._show_title()
	press(title,"Load")
	var slot:=title._stage.find_child("*Sova Cairn*",true,false) as Button
	if check(slot!=null,"ordinary Load lists Sova's one saved campaign"):
		slot.pressed.emit()
	upper=title._stage.get_child(0) as Upper
	check(upper!=null and saved()==Route.ROAD and seen(),"ordinary Load linked Road no duplicate handover after read")
	walk(upper,Route.VAULT)
	check(saved()==Route.VAULT and title._page==Title.Page.WORLD_MAP and title._campaign_battle==null,
		"actual Vault approach saves separately without auto deployment/auto state")
	upper.confirm_selection()
	press(title,"Read Dispatch")
	check(title._stage.get_child(0)._beat_id==Beats.SOVA_VAULT_RETURN_DISPATCH,"real Year Five dispatch via normal menu")
	advance(title)
	press(title,"Confirm Deployment")
	check(scene_at(title,"sova_vault_return_playtest.tscn"),"actual Vault Return battlefield")
	title._return_from_campaign_battle()
	upper=title._stage.get_child(0) as Upper
	check(upper!=null and saved()==Route.VAULT,"actual Vault mission Return keeps real closed threshold")
	title._show_title()
	press(title,"Continue")
	upper=title._stage.get_child(0) as Upper
	check(upper != null and upper._party.position.distance_to(upper._points[Route.VAULT])<.04,
		"actual Continue resumes the Vault's precise authored position")
	walk(upper,Route.ROAD)
	check(saved()==Route.ROAD and title._page==Title.Page.WORLD_MAP and seen(),"reverse reaches Road without duplicate handover")
	walk(upper,Route.ASSEMBLY)
	check(saved()==Route.ASSEMBLY,"physical reverse arrives at exact same court")
	upper._unhandled_input(y)
	upper.confirm_selection()
	await boundary(upper)
	check(title._stage.get_child(0) is Camp and saved()==Opening.MINE,
		"normal reverse sector transfer reaches true Mine")
	check(title._profile.completed_missions("sova")==PackedStringArray([Opening.CLEAR,Route.HEARING]),
		"no fake finale clear/outcome or additional opening result")
	title._show_title()
	ProjectSettings.set_setting(Entry.SWITCH,false)
	press(title,"Continue")
	check(title._stage.get_child(0) is Flat and saved()==Opening.MINE,
		"flag disabled after use returns stock chart without rewriting saved position")
	DirAccess.remove_absolute(path)
	print("Sova normal shipped title integration: %d/%d."%[n-fails,n])
	quit(1 if fails else 0)


func mount(file:String)->Title:
	var scene:=Main.instantiate() as Title
	root.add_child(scene)
	current_scene=scene
	for i in range(5):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_script().resource_path.ends_with("mara_sector_title.gd"):
			break
	var normal:=current_scene as Title
	normal._profile=Profile.new(file)
	normal._show_title()
	return normal


func close_title(title:Title)->void:
	title._show_title()
	current_scene=null
	root.remove_child(title)
	title.queue_free()


func press(title:Title,name_:String)->void:
	var button:=title._stage.find_child(name_,true,false) as Button
	if button and not button.disabled:
		button.pressed.emit()
	else:
		check(false,"ordinary button available: "+name_)


func advance(title:Title)->void:
	if title._page!=Title.Page.CAMPAIGN_DIALOGUE:
		return
	var stage:=title._stage
	while title._stage==stage and stage.get_child_count()>0 and stage.get_child(0)._active:
		stage.get_child(0).advance()


func finish_active_mission(title:Title)->void:
	if title._campaign_battle:
		title._campaign_battle.emit_signal(&"mission_finished",true)


func scene_at(title:Title,suffix:String)->bool:
	return title._campaign_battle!=null and title._campaign_battle.scene_file_path.ends_with(suffix)


func physics()->void:
	for i in range(6):
		await physics_frame


func boundary(map:Control)->void:
	for i in range(190):
		await physics_frame
		if not is_instance_valid(map) or not map._boundary_pending:
			return


func walk(map:Control,to:String)->void:
	map.select_waypoint(to)
	map.confirm_selection()
	map._process(40.0)


func saved()->String:
	return Profile.new(path).load_campaign_world("sova").current_waypoint_id()


func seen()->bool:
	return Profile.new(path).has_seen_intermission("sova",Beats.SOVA_GODBRIDLE_HANDOVER)


func check(ok:bool,what:String)->bool:
	n+=1
	if not ok:
		fails+=1
		printerr("FAIL: "+what)
	return ok
