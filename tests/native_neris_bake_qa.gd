extends Node
const Title:=preload("res://game/title_screen.gd")
const Shared:=preload("res://game/overworld/mara_sector_title.gd")
const Profile:=preload("res://game/profile_store.gd")
const Cand:=preload("res://game/overworld/neris/loading_panel.gd")
const NERIS:="neris"
const MINE:="year_one_mine"
const POST:="cairnspine_boundary_post"
const CAMP:="grove_camp"
const GROVE:="isolated_grove_nursery"
const CLEAR:="neris_cairnspine_survey"
var title:Shared
var mode:=""
var passed:=0
var failed:=0

func _ready()->void:
	mode=OS.get_environment("NERIS_BAKE_QA")
	if not mode.is_empty():
		seed_fixture(mode)
		run.call_deferred()

func seed_fixture(which:String)->void:
	if which=="legacy":
		return
	# Only disposable profile roots in the runner.
	var stored:=ConfigFile.new()
	stored.set_value(Profile.CAMPAIGNS,"mara",3)
	stored.set_value(Profile.CAMPAIGNS,"sova",2)
	stored.set_value(Profile.CAMPAIGNS,NERIS,4 if which in ["transfer","camp","greyproof"] else 1)
	stored.set_value(Profile.CAMPAIGN_WAYPOINTS,NERIS, MINE if which in ["transfer","greyproof"] else (CAMP if which=="camp" else POST))
	stored.set_value(Profile.MISSION_PROGRESS,NERIS,PackedStringArray([] if which=="camp" else ["neris_failing_grove",CLEAR]))
	stored.set_value(Profile.SETTINGS,"fullscreen",false)
	assert(stored.save(Profile.PATH)==OK)

func check(ok:bool,what:String)->bool:
	if ok:
		passed+=1
	else:
		failed+=1
		printerr("FAIL: ",what)
	return ok

func run()->void:
	if OS.get_environment("NERIS_QA_EXPECT_RETAIL")=="1":
		if not check(not OS.has_feature("editor") and not OS.is_debug_build() and Title.NormalNerisEntry.requested(),"non-debug retail with normal Neris 3D enabled"):
			finish()
			return
		var index:="res://assets/overworld/neris/bake-v1/index.json"
		if not check(FileAccess.file_exists(index) and FileAccess.get_sha256(index)=="4b8a92ec36dc560418cfa1afc7a55c1e62862ed39d8820f239961653fee81875","raw exact bake index exported into retail executable"):
			finish()
			return
	for frame in range(180):
		title=get_tree().current_scene as Shared
		if title and button("Continue"):
			break
		await get_tree().process_frame
	if not check(title!=null and button("Continue")!=null,"actual #293-backed current title"):
		finish()
		return
	if mode=="legacy":
		check(not title.NormalNerisEntry.requested(),"default false in actual project")
		finish()
		return
	if mode in ["camp","greyproof"]:
		await normal_bookmark_proof(mode)
		finish()
		return
	var bytes:=FileAccess.get_file_as_string(Profile.PATH)
	if mode=="transfer":
		if not check(press("Continue"),"ordinary Continue selected"): finish(); return
	else:
		if not check(press("Load") and choose_neris(true),"ordinary Load selected by real list"):
			finish()
			return
	if not check(active_panel()!=null and FileAccess.get_file_as_string(Profile.PATH)==bytes,"visible pending Panel without any profile write"):
		finish()
		return
	var load:=title._neris_presenter
	check(title._add_development_overworld() and load._requests==1,"duplicate same pending request does not queue a second build")
	if not await until(func()->bool:return load._first_frame_ms>=0.):
		finish();return
	await photo(mode+"-first-panel")
	print("First progress frame (",mode,") ms ",load._first_frame_ms)
	if mode=="broken":
		if not check(await until(func()->bool:return map() is Title.CampaignMap),"wrong bake safely returns to existing 2D"):
			finish();return
		check(FileAccess.get_file_as_string(Profile.PATH)==bytes,"pack rejection made no profile write, including played order")
		check(title._campaign_world.current_waypoint_id()==POST and not load._last_pack_reason.is_empty(),"safe chart still represents true saved Boundary")
		check(load._physical_builds==0 and load._terrain_bake.successful_verifications==0,"rejected preflight did not partially opt in")
		finish();return
	if mode=="load":
		if not check(await until(func()->bool:return is_instance_valid(active_panel()) and active_panel().bar.value>=4.0),"load UI progress updates during preparation"):
			finish(); return
		await photo("load-progress")
		active_panel().back.pressed.emit()
		await get_tree().process_frame
		check(title._page==Title.Page.LOAD and choose_neris(false),"cancel restores real Load list")
		var focus:=get_viewport().gui_get_focus_owner()
		check(focus!=null and "Neris" in focus.text,"Neris focus restored")
		check(FileAccess.get_file_as_string(Profile.PATH)==bytes,"cancel retained every save byte incl. played order")
		print("Load cancel UI response ms ",load._cancel_response_ms)
		# Race the cancelled coroutine by opening the same save immediately.
		check(choose_neris(true),"retry immediately uses original Load choice without old callback")
		var retry=title._neris_presenter
		check(load!=retry,"new presenting owner is separate from cancelled actor")
		if not check(await until(func()->bool:return usable(POST)),"retry mounted correctly prepared map"):
			finish(); return
		await print_metrics(retry,"Load retry")
		check(retry._physical_builds==1 and map()._renderer.scenery_ready and map()._renderer.baked_terrain.size()==56,"exactly one adopted indexed renderer, not rebuilt at map attach")
		check(retry._terrain_bake.successful_verifications==1,"preflight all pieces exactly once for this revision")
		check(Profile.new().load_campaign_world(NERIS).current_waypoint_id()==POST,"same durable Boundary on Load")
		await photo("load-usable")
		verify_digest()
		finish()
		return
	if not check(await until(func()->bool:return usable(MINE)),"Continue reached true Greyhollow view after progress"):
		finish(); return
	await print_metrics(load,"Continue")
	bytes=FileAccess.get_file_as_string(Profile.PATH)
	var old_map:=map()
	select_transfer(old_map)
	check(load._token!=0 and old_map._boundary_pending,"shared boundary selector and confirm entered pending state")
	var requests:int=load._requests
	old_map.confirm_button.pressed.emit()
	check(requests==load._requests,"repeat confirm did not create a new request")
	check(old_map.back_button.visible and old_map.back_button.text=="Cancel Transfer","existing shared cancel control while source map is pending")
	await photo("transfer-pending")
	var builds_before_cancel:int=load._physical_builds
	old_map.back_button.pressed.emit()
	await get_tree().process_frame
	check(not old_map._boundary_pending and map()==old_map and FileAccess.get_file_as_string(Profile.PATH)==bytes,"standard Back restored prior map, no save write")
	print("Transfer cancel UI response ms ",load._cancel_response_ms)
	# Real independent ProfileStore update racing the cancelled epoch.
	var concurrent:=Profile.new()
	check(concurrent.record_mission_clear("sova","sova_mine_tunnels")==OK,"independent campaign result saved while old worker retires")
	select_transfer(old_map)
	check(load._token!=0 and old_map._boundary_pending,"real retry created a fresh confirmed pending token")
	if not check(await until(func()->bool:return usable(POST)),"retry committed and attached ready Boundary"):
		finish();return
	await print_metrics(load,"Sector Retry")
	check(load._physical_builds==builds_before_cancel+1 and map()._renderer.scenery_ready and map()._renderer.baked_terrain.size()==56,"retry contributes exactly one additional build; only its ready renderer was mounted")
	check(load._terrain_bake.successful_verifications==1,"already accepted immutable revision reused at transfer")
	var disk:=Profile.new()
	check(disk.load_campaign_world(NERIS).current_waypoint_id()==POST and disk.completed_missions("sova").has("sova_mine_tunnels"),"saved reverse position without losing concurrent result")
	await photo("transfer-usable")
	verify_digest()
	finish()

func normal_bookmark_proof(which:String)->void:
	if not check(press("Continue"),"normal title Continue from isolated existing profile"):
		return
	if not check(await until(func()->bool:return usable(CAMP if which=="camp" else MINE)),"true saved area mounted in ordinary title"):
		return
	await print_metrics(title._neris_presenter,which)
	if which=="greyproof":
		await photo_small("normal-greyhollow")
		return
	var view:=map()
	var length:float=view._curve_for(CAMP,GROVE).get_baked_length()
	check(absf(length-330.54)<.08,"actual 330.54m exact western road available")
	await photo_small("normal-grove-camp")
	check(view.select_waypoint(GROVE),"real Grove waypoint selected")
	view.confirm_button.pressed.emit()
	if not check(await until(func()->bool:return view._navigation.is_travelling() and view._navigation.travel_progress()>=.26),"active stock march visibly reaches a middle road segment"):
		return
	var v:Vector3=view._party_point()
	var ground:float=view._renderer.ground_height(v.x,v.z)
	check(absf(v.y-ground-.38)<.08,"live party remains on measured ground mid-route")
	await photo_small("normal-road-midway")
	if not check(await until(func()->bool:return usable(GROVE)),"Grove arrival persists through exact same scene"):
		return
	check(map()==view and Profile.new().load_campaign_world(NERIS).current_waypoint_id()==GROVE,"no sector seam on the physical nursery road")
	# Existing renderer method used by the verified shared controller's zoom bindings.
	view._renderer.toggle_zoom(view._points[GROVE])
	await photo_small("normal-nursery")

func photo_small(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_jpg("user://neris-bake-"+name+".jpg",.55)==OK,"native normal image "+name)

func verify_digest()->void:
	var renderer=map()._renderer
	var expected:=JSON.parse_string(FileAccess.get_file_as_string("res://assets/overworld/neris/bake-v1/index.json")) as Dictionary
	var hashes:Dictionary={}
	for e:Dictionary in expected["pieces"]: hashes[e["file"]]=e["buffers"]
	for i:int in renderer.baked_terrain.size():
		var x:=i%8
		var z:=i/8
		var name:="%s-%02d-%02d.res"%["b" if z==3 and x in [4,5] else "g",x,z]
		var surface:=RenderingServer.mesh_get_surface(renderer.baked_terrain[i].mesh.get_rid(),0)
		var bytes:=PackedByteArray()
		for key in ["vertex_data","attribute_data","skin_data","index_data"]:
			var buffer:PackedByteArray=surface.get(key,PackedByteArray())
			bytes.append_array(buffer)
		var h:=HashingContext.new()
		assert(h.start(HashingContext.HASH_SHA256)==OK)
		assert(h.update(bytes)==OK)
		if not check(h.finish().hex_encode()==hashes[name],"actual mounted tile buffers SHA "+name):
			return
	var curve:Curve3D=renderer.boundary_contract()
	check(absf(curve.get_baked_length()-294.75)<.05,"actual mounted route still exact measured length")

func print_metrics(presenter,label:String)->void:
	print(label," CPU-ready ms ",presenter._last_ready_ms,", first rendered/headless-frame ms ",presenter._first_frame_ms,", work yields ",presenter._last_yields,", worst traced row batch us ",presenter._last_slice_usec)
	print(label," package check ms ",presenter._terrain_bake.last_check_ms)
	print(label," compute/frame wait/mesh commit/art settle ms ",[presenter._row_compute_usec/1000.,presenter._frame_wait_usec/1000.,presenter._mesh_commit_usec/1000.,presenter._settlement_usec/1000.])
	if DisplayServer.get_name()!="headless":
		var request_start:int=presenter._first_requested_usec
		await RenderingServer.frame_post_draw
		print(label," first usable present ms ",(Time.get_ticks_usec()-request_start)/1000.)

func active_panel()->Cand:
	if title._page!=Title.Page.WORLD_MAP or title._stage.get_child_count()==0:
		return null
	return title._stage.get_child(0) as Cand

func usable(point:String)->bool:
	return title._page==Title.Page.WORLD_MAP and title._campaign_world and title._campaign_world.current_waypoint_id()==point and map() is Title.DevelopmentOverworld and not title._neris_presenter._last_ready_ms<0.

func select_transfer(view)->void:
	view._boundary_button.pressed.emit()
	view.confirm_button.pressed.emit()

func until(test:Callable)->bool:
	var end:=Time.get_ticks_msec()+85000
	while Time.get_ticks_msec()<end:
		if test.call(): return true
		await get_tree().process_frame
	return check(false,"timed out awaiting real title state")

func photo(name:String)->void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_jpg("user://neris-bake-"+name+".jpg",.69)==OK,"native screenshot "+name)

func map()->Node:
	return title._stage.get_child(0) if title._stage.get_child_count()>0 else null

func choose_neris(act:bool)->bool:
	for choice:Button in title._stage.find_children("*","Button",true,false):
		if "Neris" in choice.text:
			if act:
				choice.grab_focus()
				choice.pressed.emit()
			return true
	return false

func button(name:String)->Button:
	return title._stage.get_node_or_null(name) as Button

func press(name:String)->bool:
	var item:=button(name)
	if not item or item.disabled: return false
	item.pressed.emit()
	return true

func finish()->void:
	print("Shared ae6 baked ",mode,": ",passed," passed, ",failed," failed.")
	for frame in range(4):
		await get_tree().process_frame
	get_tree().quit(int(failed!=0))
