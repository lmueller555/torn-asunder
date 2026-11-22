extends Node
## CI-only autoload in the actual exported Linux release executable. Never
## referenced by stock project.godot. No editor/debug bypass.
const Title := preload("res://game/title_screen.gd")
const Entry := preload("res://game/overworld/sova_normal_entry.gd")
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const Flat := preload("res://game/campaign_map.gd")
const Map := preload("res://game/overworld/cairnspine/sova_vault_map.gd")
const Routes := preload("res://game/overworld/cairnspine/sova_vault_routes.gd")
const Dialogue := preload("res://game/campaign_dialogues.gd")
var mode := ""
var shipped_on := false
var title: Title
var misses := 0
var began := 0


func _ready() -> void:
	mode = OS.get_environment("SOVA_NATIVE_MODE")
	if mode not in ["off","arrival","unread","vault","rendered"]:
		return
	began = Time.get_ticks_msec()
	shipped_on = Entry.requested()
	if mode == "off":
		ProjectSettings.set_setting(Entry.SWITCH,false)
	run.call_deferred()


func run() -> void:
	check(not OS.is_debug_build() and not OS.has_feature("editor"),"nondebug exported executable; not Godot editor loading a pack")
	check(shipped_on,"exported project normally enables the 3D campaign")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/title_screen.tscn","actual stock entry point")
	check(ResourceLoader.exists("res://assets/overworld/marches/marches-corridor.glb","PackedScene")
		and ResourceLoader.exists("res://assets/overworld/marches/greyhollow-mine.glb","PackedScene")
		and ResourceLoader.exists("res://game/overworld/cairnspine/sova_vault_stone.gdshader","Shader")
		and ResourceLoader.exists("res://game/overworld/cairnspine/sova_vault_renderer.tscn","PackedScene"),"real typed terrain, mine and audited closed threshold packaged")
	for i in range(180):
		title=get_tree().current_scene as Title
		if title and title.get_script().resource_path.ends_with("mara_sector_title.gd") and title._page==Title.Page.TITLE:
			break
		await get_tree().process_frame
	if not check(title!=null and title.get_script().resource_path.ends_with("mara_sector_title.gd") and button("New Game")!=null,
		"actual main deferred boot installs shared normal title"):
		finish()
		return
	if mode=="unread":
		if not check(press("Load") and press("*Sova Cairn*"),"real ordinary Load menu selects Sova"):
			finish()
			return
	elif not check(press("Continue"),"real ordinary Continue"):
		finish()
		return
	if mode=="off":
		check(saved()==Routes.ASSEMBLY and title._stage.get_child(0) is Flat,"explicit opt-out preserves old Assembly profile on stock chart")
	elif mode=="arrival":
		var map:=title._stage.get_child(0) as Map
		if check(map!=null and saved()==Routes.ASSEMBLY,"legal cold Assembly starts exact upper native sector"):
			await settle()
			check(native_ready(map),"actual assembled terrain and closed threshold exist inside exported package")
			await walk(map,Routes.ROAD)
			check(saved()==Routes.ROAD and pending(Dialogue.SOVA_GODBRIDLE_HANDOVER) and not seen(),"durable Road arrival presents canonical unread handover")
	elif mode=="unread":
		if check(saved()==Routes.ROAD and pending(Dialogue.SOVA_GODBRIDLE_HANDOVER) and not seen(),"cold process reopens same unread canonical handover"):
			advance()
			var map:=title._stage.get_child(0) as Map
			if check(map!=null and saved()==Routes.ROAD and seen(),"real dialogue acknowledges once and returns to legal Road"):
				await walk(map,Routes.VAULT)
				check(saved()==Routes.VAULT and title._page==Title.Page.WORLD_MAP and seen(),"physical route saves Vault without fabricated outcome")
	elif mode=="rendered":
		var map:=title._stage.get_child(0) as Map
		if check(map!=null and saved()==Routes.VAULT and seen(),"rendered normal cold Vault mount"):
			await settle()
			check(DisplayServer.get_name()!="headless" and native_ready(map),"real window mounts actual validated threshold")
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			check(image!=null and image.get_width()>0,"rendered player view has a frame")
	else:
		var map:=title._stage.get_child(0) as Map
		if check(map!=null and title._page==Title.Page.WORLD_MAP and saved()==Routes.VAULT and seen(),"cold Vault continues without replaying acknowledged handover"):
			await settle()
			check(native_ready(map) and map._party.position.distance_to(map._points[Routes.VAULT])<.04,"native packaged threshold and exact pinned saved position")
			map.confirm_button.pressed.emit()
			check(title._page==Title.Page.MISSION_BRIEFING and press("Read Dispatch"),"separate official Vault briefing and Dispatch")
			check(pending(Dialogue.SOVA_VAULT_RETURN_DISPATCH),"real Year Five registered beat, not the Road handover")
			advance()
			check(press("Confirm Deployment") and title._campaign_battle!=null and title._campaign_battle.scene_file_path.ends_with("sova_vault_return_playtest.tscn"),"actual registered Year Five battlefield")
			title._return_from_campaign_battle()
			check(saved()==Routes.VAULT and title._stage.get_child(0) is Map,"retreat stays at same canonical Vault pin")
	check(not Profile.new().completed_missions("sova").has(Routes.FINALE),"no final victory fabricated")
	finish()


func native_ready(map:Map) -> bool:
	return is_instance_valid(map._renderer._ground) and map._renderer.validated 		and map._renderer.relief.has_node(^"CairnspineVaultThreshold")


func settle() -> void:
	for i in range(6):
		await get_tree().physics_frame


func saved() -> String:
	return Profile.new().load_campaign_world("sova").current_waypoint_id()


func seen() -> bool:
	return Profile.new().has_seen_intermission("sova",Dialogue.SOVA_GODBRIDLE_HANDOVER)


func pending(id:StringName) -> bool:
	return title._page==Title.Page.CAMPAIGN_DIALOGUE and title._stage.get_child(0)._beat_id==id


func button(label:String) -> Button:
	return title._stage.find_child(label,true,false) as Button


func press(label:String) -> bool:
	var item:=button(label)
	if not item or item.disabled:
		return false
	item.pressed.emit()
	return true


func advance() -> void:
	if title._page!=Title.Page.CAMPAIGN_DIALOGUE:
		return
	var page:=title._stage
	while title._stage==page and page.get_child_count()>0 and page.get_child(0)._active:
		page.get_child(0).advance()


func walk(map:Map,to:String) -> void:
	if not check(map.select_waypoint(to),"select an actual reachable point"):
		return
	map.confirm_button.pressed.emit()
	if not check(map._navigation.is_travelling(),"starts real animated route"):
		return
	var before := saved()
	await get_tree().physics_frame
	check(saved()==before and before!=to,"not saved before physical arrival")
	for tick in range(360):
		if not is_instance_valid(map) or not map._navigation.is_travelling():
			return
		await get_tree().physics_frame
	check(false,"real travel completed within six seconds")


func check(ok:bool,label:String) -> bool:
	if not ok:
		misses+=1
		printerr("FAIL: "+label)
	return ok


func finish() -> void:
	print("Native Sova executable smoke (%s): %s [%d ms]"%[mode,"PASS" if not misses else "FAIL",Time.get_ticks_msec()-began])
	get_tree().quit(0 if not misses else 1)
