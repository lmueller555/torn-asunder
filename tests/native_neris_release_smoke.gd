extends Node
## Actual ordinary title New/Continue/Load lifecycle; this can also become a
## QA-only autoload in a disposable non-debug export (ordinary assets required).
const Title:=preload("res://game/title_screen.gd")
const Entry:=preload("res://game/overworld/neris_normal_entry.gd")
const Shared:=preload("res://game/overworld/mara_sector_title.gd")
const GroveMap:="res://game/overworld/neris/grove_opening_view.gd"
const Approach:="res://game/overworld/neris/approach_map.gd"
const FinaleMap:="res://game/overworld/neris/greyhollow_map.gd"
const Profile:=preload("res://game/profile_store.gd")
const Deploy:=preload("res://game/campaign_deployments.gd")
const Catalog:=preload("res://game/campaigns.gd")
const NERIS:="neris"
const OPENING:="neris_failing_grove"
const SURVEY:="neris_cairnspine_survey"
const FINALE:="neris_greyhollow"
const CAMP:="grove_camp"
const GROVE:="isolated_grove_nursery"
const POST:="cairnspine_boundary_post"
const MINE:="year_one_mine"
var title:Shared
var passed:=0
var missed:=0
var mode:=""
var shipping_default:=false

func _ready()->void:
	mode=OS.get_environment("NERIS_PRIVATE_QA")
	if mode!="":
		shipping_default=Entry.requested()
		if mode=="off": ProjectSettings.set_setting(Entry.SWITCH,false)
		run.call_deferred()

func check(value:bool,label:String)->bool:
	if value:
		passed+=1
	else:
		missed+=1
		printerr("FAIL: ",label)
	return value

func run()->void:
	if OS.get_environment("NERIS_QA_EXPECT_RETAIL")=="1":
		if not check(not OS.has_feature("editor") and not OS.is_debug_build() and shipping_default,"non-debug exported executable with normal Neris 3D enabled"):
			finish()
			return
	if not check(ProjectSettings.get_setting("application/run/main_scene")=="res://game/title_screen.tscn","actual normal title entry"):
		finish()
		return
	for frame in range(180):
		title=get_tree().current_scene as Shared
		if title and front("New Game"): break
		await get_tree().process_frame
	if not check(title!=null and front("New Game")!=null,"ordinary title loaded"):
		finish()
		return
	if mode in ["old","invalid-old"]:
		await cold()
		finish()
		return
	if mode=="first-clear":
		if launch_opening() and await mock_clear(OPENING,GROVE):
			check(view_script(Approach) and saved()==GROVE,"direct New dispatch clear returns to authored 3D, not a launch-time map")
		finish()
		return
	if not await opening(GROVE,mode not in ["off","missing"]):
		finish()
		return
	if mode in ["off","missing"]:
		check(map() is Title.CampaignMap and not map() is Title.DevelopmentOverworld,"off or missing pack keeps real 2D map after opening")
		if mode=="missing":
			check(title._stage.get_children().any(func(child):return child is Label and child.text==Title.NormalMaraEntry.FALLBACK_MESSAGE),"missing package reported in ordinary stage")
		finish()
		return
	check(view_script(GroveMap),"first retreat returns to approved 3D Grove")
	check(not map().select_waypoint(POST),"no Boundary before Grove completion")
	check(not Profile.new().completed_missions(NERIS).has(OPENING),"retreat never grants clear")
	if not await deploy(OPENING,GROVE) or not await mock_clear(OPENING,GROVE):
		finish()
		return
	if not check(view_script(Approach),"clear returns to 3D and unlocks extended authored map"):
		finish()
		return
	if not await travel(POST):
		finish()
		return
	var active=map()
	check(active._boundary_button==null,"Year Two gate waits for Neris's own Survey")
	check(title._profile.record_mission_clear("mara","mara_mine_escort")==OK,"seed unrelated Human fixture")
	check(title._profile.record_mission_clear("sova","sova_mine_tunnels")==OK,"seed unrelated Druid fixture")
	active.boundary_requested.emit(MINE)
	check(title._neris_presenter._token==0,"both foreign clears cannot activate transfer")
	if not await deploy(SURVEY,POST) or not await mock_clear(SURVEY,POST):
		finish()
		return
	active=map()
	check(active._boundary_button!=null and not active._boundary_button.disabled,"actual Survey clear enables explicit seam")
	active._boundary_button.pressed.emit()
	active.confirm_button.pressed.emit()
	check(title._neris_presenter._token!=0 and saved()==POST,"no save change before explicit transfer completes")
	var cancel:Button=active.back_button if active.back_button.text=="Cancel Transfer" else null
	check(cancel!=null,"genuine Cancel Transfer action")
	if cancel: cancel.pressed.emit()
	check(title._neris_presenter._token==0 and saved()==POST,"cancel retained active origin and disk")
	active._boundary_button.pressed.emit()
	active.confirm_button.pressed.emit()
	if not check(await map_at(MINE) and saved()==MINE and view_script(FinaleMap),"correct drafted 3D area mounted after transfer commit"):
		finish()
		return
	check(title._campaign_world.mission_at_current_waypoint()==FINALE and map()._renderer.arrival_ground.is_finite(),"correct attack-era scene and grounded prepared arrival")
	if not await deploy(FINALE,MINE) or not await leave(MINE):
		finish()
		return
	check(not Profile.new().completed_missions(NERIS).has(FINALE),"leaving the battlefield did not clear the finale")
	map().back_button.pressed.emit()
	if not await opening(MINE,true):
		finish()
		return
	check(saved()==MINE and view_script(FinaleMap),"New replay preserves advanced position after leaving the opening")
	map().back_button.pressed.emit()
	check(press("Continue") and await map_at(MINE) and view_script(FinaleMap),"Continue uses existing Mine profile and 3D")
	map().back_button.pressed.emit()
	check(load_neris() and await map_at(MINE) and view_script(FinaleMap),"Load uses existing Mine profile and 3D")
	map()._boundary_button.pressed.emit()
	map().confirm_button.pressed.emit()
	check(await map_at(POST) and saved()==POST and view_script(Approach),"real return commits Boundary and restores 3D scene")
	finish()

func cold()->void:
	if not check(press("Continue"),"Continue opens a real cold fixture"):
		return
	if not check(await map_at(MINE if mode=="old" else CAMP),"valid cold Mine resumes; invalid old falls back"):
		return
	if mode=="invalid-old":
		check(view_script(GroveMap) and not Profile.new().completed_missions(NERIS).has(SURVEY),"foreign clear never leaks into malformed Neris slot")
		return
	check(view_script(FinaleMap) and map()._renderer.arrival_ground.is_finite(),"approved 3D greyhollow arrival in actual title")
	check(title._campaign_world.mission_at_current_waypoint()==FINALE,"Neris Mine is her own Year Three finale")
	var profile:=Profile.new()
	check(profile.load_campaign_world("mara").mission_at_current_waypoint()=="mara_mine_escort","Human Mine save kept distinct")
	check(profile.load_campaign_world("sova").mission_at_current_waypoint()=="sova_mine_tunnels","Druid Mine save kept distinct")
	check(not profile.completed_missions(NERIS).has(FINALE),"map arrival never cleared the war mission")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_jpg("user://neris-9c34-continue-greyhollow.jpg",.75)==OK,"native ordinary title pixels")
	map().back_button.pressed.emit()
	check(load_neris() and await map_at(MINE) and view_script(FinaleMap),"cold explicit Load returns to same correct 3D Mine")

func launch_opening()->bool:
	if not check(choose(),"New via the ordinary title/vault"): return false
	if not check(title._page==Title.Page.CAMPAIGN_DIALOGUE and not has_map(),"opening dispatch before any overworld"): return false
	var skip:=find_button("Skip Scene")
	if not check(skip!=null,"canonical opening skip action"): return false
	skip.pressed.emit()
	return check(on_battle(OPENING) and not has_map(),"opening dispatch directly deploys real Grove battlefield")

func opening(return_id:String,expects_3d:bool)->bool:
	if not launch_opening() or not await leave(return_id): return false
	return check((map() is Title.DevelopmentOverworld)==expects_3d,"opening retreat returns to selected presentation")

func mock_clear(id:String,point:String)->bool:
	# Engine still launches the exact mission; fixture signals the result rather
	# than simulating the entire combat, to test actual title/profile ownership.
	if not check(on_battle(id),"clear result belongs to the exact campaign battlefield"): return false
	title._campaign_battle.mission_finished.emit(true)
	if not check(await map_at(point) and Profile.new().completed_missions(NERIS).has(id),"real title persisted the mission result and dispatched its debrief"): return false
	return true

func travel(point:String)->bool:
	var view=map()
	if not check(view.select_waypoint(point),"choose canonical "+point): return false
	view.confirm_button.pressed.emit()
	return check(await map_at(point) and saved()==point,"real frame-time movement persisted "+point)

func deploy(id:String,point:String)->bool:
	var view=map()
	if not check(view.select_waypoint(point),"select briefing waypoint "+id): return false
	view.confirm_button.pressed.emit()
	if not check(title._page==Title.Page.MISSION_BRIEFING and press("Confirm Deployment"),"separate exact briefing "+id): return false
	return check(on_battle(id),"exact deployed mission "+id)

func leave(point:String)->bool:
	title._pause_game()
	var exit:=title._pause_menu.find_child("LeaveGame",true,false) as Button
	if not check(exit!=null,"actual Pause return action"): return false
	exit.pressed.emit()
	var confirm:=title._pause_menu.find_child("ConfirmLeave",true,false) as Button
	if not check(confirm!=null,"actual Pause return confirmation"): return false
	confirm.pressed.emit()
	return check(await map_at(point),"battle return at canonical "+point)

func map_at(point:String)->bool:
	var limit:=Time.get_ticks_msec()+70000
	while Time.get_ticks_msec()<limit:
		if title._page==Title.Page.CAMPAIGN_DIALOGUE:
			# Waive reading the debrief, not its real integration/callback or result write.
			title._stage.get_child(0).completed.emit(&"")
		if title._page==Title.Page.WORLD_MAP and title._campaign_world and title._campaign_world.current_waypoint_id()==point and (map() is Title.DevelopmentOverworld or map() is Title.CampaignMap):
			await get_tree().process_frame
			return true
		await get_tree().process_frame
	return false

func on_battle(id:String)->bool:
	return title._page==Title.Page.CAMPAIGN_BATTLE and is_instance_valid(title._campaign_battle) and title._campaign_battle.scene_file_path==Deploy.for_mission(id).scene.resource_path

func has_map()->bool:
	return title._stage.get_children().any(func(child):return child is Title.CampaignMap or child is Title.DevelopmentOverworld)

func choose()->bool:
	if not press("New Game"): return false
	var hero:=front(NERIS)
	if not hero: return false
	hero.grab_focus()
	return title._portraits[title._selected]==hero and press("Begin Campaign")

func load_neris()->bool:
	if not press("Load"): return false
	for campaign:Dictionary in Catalog.ALL:
		if campaign.id!=NERIS: continue
		var choice:=find_button("%s %s  ·  %s"%[campaign.title,campaign.name,campaign.faction])
		if not choice: return false
		choice.pressed.emit()
		return true
	return false

func front(label:String)->Button:
	return title._stage.get_node_or_null(label) as Button

func find_button(text:String)->Button:
	for item:Button in title._stage.find_children("*","Button",true,false):
		if item.text==text: return item
	return null

func press(label:String)->bool:
	var item:=front(label)
	if not item or item.disabled: return false
	item.pressed.emit()
	return true

func map()->Node:
	return title._stage.get_child(0)

func view_script(path:String)->bool:
	return map().get_script() and map().get_script().resource_path==path

func saved()->String:
	return Profile.new().load_campaign_world(NERIS).current_waypoint_id()

func finish()->void:
	print("True shared ae6 title Neris ",mode,": ",passed," passed, ",missed," failed.")
	get_tree().quit(int(missed!=0))
