extends Node
## QA-only autoload. Never included in actual ProjectSettings or runtime flow.
const Profile:=preload("res://game/profile_store.gd")
const World:=preload("res://game/campaign_world.gd")
const Entry:=preload("res://game/overworld/raska/raska_normal_entry.gd")
const WELL:="basin_well_road"
const GREY:="year_one_mine"
const OWNER_CLEAR:="orc_mine_witness"
const LOCK:="spanwater_lock"
const NORTH_MISSION:="orc_spanwater_release"
const NORTH_CODA:=&"raska_spanwater_coda"
var _bad:=false

func _ready()->void:
	_run.call_deferred()

func _need(ok:bool,label:String)->bool:
	if not ok:
		_bad=true
		printerr("Native Raska smoke: FAIL ",label)
		get_tree().quit(1)
	return ok

func _title()->Node:
	for attempt in range(120):
		var view:=get_tree().current_scene
		if view and view.scene_file_path=="res://game/title_screen.tscn" and view.get("_stage"):
			return view
		await get_tree().process_frame
	return null

func _find_button(scene:Node,label:String)->Button:
	for item:Button in scene.find_children("*","Button",true,false):
		if label in item.text: return item
	return null

func _load_raska(title:Node)->Control:
	var load_button:=_find_button(title._stage,"Load")
	if not _need(load_button!=null,"real title Load action"): return null
	load_button.pressed.emit()
	var row:=_find_button(title._stage,"Raska")
	if not _need(row!=null,"real Raska slot displayed"): return null
	row.pressed.emit()
	for i in range(5): await get_tree().physics_frame
	return title._stage.get_node_or_null("RaskaOverworld") as Control

func _pad(button:JoyButton)->void:
	# Inject a real engine joy-button InputEvent into ordinary title dispatch.
	for held in [true,false]:
		var e:=InputEventJoypadButton.new()
		e.device=0
		e.button_index=button
		e.pressed=held
		Input.parse_input_event(e)
		await get_tree().process_frame

func _make_cold_mine_fixture(profile:Profile)->bool:
	if profile.mark_played("raska")!=OK: return false
	var session:=profile.load_campaign_world("raska")
	if session.current_waypoint_id()!=GREY and session.travel_to(GREY,profile.completed_missions("raska"))!=World.TravelResult.ARRIVED: return false
	return profile.record_world_waypoint(session)==OK and profile.set_setting("fullscreen",false)==OK

func _make_cold_spanwater_fixture(profile:Profile)->bool:
	# Use only stock save/profile operations. These are recorded progression
	# fixtures, not a scripted victory, debrief or fabricated story outcome.
	if not _make_cold_mine_fixture(profile) or profile.set_setting("reduced_motion",true)!=OK: return false
	var session:=profile.load_campaign_world("raska")
	for step:Array in [[OWNER_CLEAR,WELL],["orc_well_road",LOCK]]:
		if profile.record_mission_clear("raska",step[0])!=OK: return false
		if session.travel_to(step[1],profile.completed_missions("raska"))!=World.TravelResult.ARRIVED: return false
		if profile.record_world_waypoint(session)!=OK: return false
	return profile.record_mission_clear("raska",NORTH_MISSION)==OK

func _check_coda(title:Node, profile:Profile, mode:String)->void:
	var unread:=mode=="coda_unread"
	if unread and not _need(_make_cold_spanwater_fixture(profile),"complete lawful saved North fixture"): return
	var entry:=Profile.new()
	if not _need(entry.load_campaign_world("raska").current_waypoint_id()==LOCK and entry.completed_missions("raska").has(NORTH_MISSION),"cold saved North and true final clear ID"): return
	if not _need(entry.has_seen_intermission("raska",NORTH_CODA)!=unread,"expected cold unread/read state"): return
	title._profile=entry
	var view:=await _load_raska(title)
	if _bad: return
	if unread:
		if not _need(view==null and title._page==title.Page.CAMPAIGN_DIALOGUE and title._stage.get_child_count()>0,"true Load shows coda before any map"): return
		var dialogue:Node=title._stage.get_child(0)
		if not _need(dialogue.get("_beat_id")==NORTH_CODA,"exact canonical Raska Spanwater coda"): return
		for i in range(24):
			if title._page!=title.Page.CAMPAIGN_DIALOGUE: break
			await _pad(JOY_BUTTON_A)
		for i in range(5): await get_tree().physics_frame
		view=title._stage.get_node_or_null("RaskaOverworld") as Control
	if not _need(view!=null and title._page==title.Page.WORLD_MAP and view._world.current_waypoint_id()==LOCK,"real North 3D returns or cold resumes without replay"): return
	if not _need(view._party.position.is_equal_approx(Vector3(-108,5.23,-42)) and "YEAR FOUR" in view._header.text and view._world.mission_at_current_waypoint()==NORTH_MISSION,"physical raised north and correct Year Four mission"): return
	var cold:=Profile.new()
	if not _need(cold.has_seen_intermission("raska",NORTH_CODA) and not cold.has_seen_intermission("ilyra",NORTH_CODA) and not cold.completed_missions("ilyra").has("ilyra_spanwater_evacuation"),"acknowledged only by exact faction without fabricated Ilyra victory"): return
	print("Native Raska launch smoke (",mode,"): PASS")
	get_tree().quit()

func _run()->void:
	var mode:=OS.get_environment("RASKA_SMOKE_MODE")
	if mode.is_empty(): return
	if not _need(not OS.is_debug_build() and not OS.has_feature("editor"),"nondebug exported binary"): return
	if not _need(Entry.requested(),"packaged project normally enables Raska 3D"): return
	for dependency in Entry.SCENES:
		if not _need(ResourceLoader.exists(dependency,"PackedScene"),"packed native resource "+dependency): return
	var title:=await _title()
	if not _need(title!=null,"production main scene"): return
	var profile:=Profile.new()
	if mode in ["coda_unread","coda_read"]:
		await _check_coda(title,profile,mode)
		return
	if mode in ["default_off","travel"]:
		if not _need(_make_cold_mine_fixture(profile),"cold stock Mine fixture on disk"): return
	else:
		if not _need(mode=="rendered" and profile.load_campaign_world("raska").current_waypoint_id()==WELL,"fresh process sees saved real Well travel"): return
	title._profile=Profile.new()
	if mode=="default_off": ProjectSettings.set_setting(Entry.SWITCH,false)
	var view:=await _load_raska(title)
	if _bad:return
	if mode=="default_off":
		if not _need(view==null and title._page==title.Page.WORLD_MAP,"explicit opt-out returns to the canonical 2D chart"):return
	elif mode=="travel":
		if not _need(view!=null and view._world.current_waypoint_id()==GREY,"cold real Greyhollow 3D Load"): return
		await _pad(JOY_BUTTON_Y)
		await _pad(JOY_BUTTON_Y)
		if not _need(view._port=="west_shelf" and view._destination()==WELL and view.confirm_button.disabled,"actual Y selects physical shelf and locked Well"): return
		await _pad(JOY_BUTTON_A)
		if not _need(Profile.new().load_campaign_world("raska").current_waypoint_id()==GREY,"locked A does not travel"): return
		# Explicit save fixture, not a claimed combat win or debrief.
		if not _need(title._profile.record_mission_clear("raska",OWNER_CLEAR)==OK,"own pre-existing clear fixture recorded"):return
		await _pad(JOY_BUTTON_Y)  # return to station selection
		await _pad(JOY_BUTTON_Y)
		await _pad(JOY_BUTTON_Y)  # distinct Well destination at the same exact shelf
		if not _need(view._destination()==WELL and not view.confirm_button.disabled,"own clear opens exact Y/port"): return
		await _pad(JOY_BUTTON_A)
		for i in range(10): await get_tree().process_frame
		if not _need(view._world.current_waypoint_id()==WELL and Profile.new().load_campaign_world("raska").current_waypoint_id()==WELL,"actual save-first crossing survives cold reload data"): return
	else:
		if not _need(DisplayServer.get_name()!="headless" and get_window().mode==Window.MODE_WINDOWED and view!=null,"genuine windowed 3D normal Load"):return
		if not _need(view._world.current_waypoint_id()==WELL and view._world.mission_at_current_waypoint()=="orc_well_road","canonical saved briefing identity"):return
		if not _need(view._renderer.has_node("WellRoadCohesiveContext") and view._party.position.x==-125,"native west anchor and approved art"):return
		for i in range(3): await RenderingServer.frame_post_draw
		var destination:=OS.get_environment("RASKA_SMOKE_SCREEN")
		if not destination.is_empty() and not _need(get_viewport().get_texture().get_image().save_jpg(destination,.9)==OK,"capture real actual viewport"): return
		await _pad(JOY_BUTTON_A)
		if not _need(title._page==title.Page.MISSION_BRIEFING,"actual stock Second Bucket briefing from windowed chart"):return
	print("Native Raska launch smoke (",mode,"): PASS")
	get_tree().quit()
