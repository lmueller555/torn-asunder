extends Node
## CI-only autoload. Not referenced by the normal project.
const Title := preload("res://game/title_screen.gd")
const Entry := preload("res://game/overworld/sereth_normal_entry.gd")
const Neutral := preload("res://game/overworld/sereth_neutral_contract.gd")
const Bindings := preload("res://game/settings/control_bindings.gd")
const Profile := preload("res://game/profile_store.gd")
const Flat := preload("res://game/campaign_map.gd")
const Presenter := preload("res://game/overworld/sereth/sereth_normal_presenter.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const PROMPT := &"Cross / Space: inspect the wheel marks."
const HEROES := &"Square / Space: inspect the wheel marks."
const STATIONS := {
	"cut": [Presenter.CUT,Presenter.Lower.CLEAR,Beats.SERETH_CUT_DISPATCH,"sereth_cut_playtest.tscn"],
	"keeper": [Presenter.KEEPER,Presenter.Upper.CLEAR,Beats.SERETH_PASS_WRIT_DISPATCH,"sereth_pass_writ_playtest.tscn"],
	"year-five": [Presenter.ASSEMBLY,Presenter.Upper.TARGET_MISSION,Beats.SERETH_NO_PROXY_DISPATCH,"sereth_no_proxy_playtest.tscn"],
}
var mode := ""
var tracked_enabled := false
var misses := 0
var checks := 0
var host: Title

func _ready() -> void:
	mode=OS.get_environment("SERETH_NATIVE_MODE")
	if mode!="off" and not STATIONS.has(mode):
		return
	tracked_enabled=Entry.requested()
	if mode=="off":
		ProjectSettings.set_setting(Entry.SWITCH,false)
	_run.call_deferred()

func _run() -> void:
	_check(not OS.is_debug_build() and not OS.has_feature("editor"),"true native nondebug export, not editor")
	_check(tracked_enabled and ProjectSettings.get_setting("application/run/main_scene")=="res://game/title_screen.tscn",
		"normal title and tracked default-on retained")
	_check(Entry.requested()==(mode!="off"),"only isolated fallback mode overrides the stock switch")
	for id in ["mara","ilyra","sova","raska"]:
		_check(ProjectSettings.get_setting("torn_asunder/"+id+"_3d_overworld",false)==true,id+" flag preserved")
	_check(Bindings.layout()==Bindings.Layout.HEROES and TranslationServer.translate(PROMPT)==String(HEROES),
		"actual default Heroes prompt translation, no --script layout bypass")
	if mode!="off":
		_check(Neutral.available() and ResourceLoader.exists("res://game/overworld/sereth/sereth_y5_renderer.tscn","PackedScene"),
			"all pinned typed neutral resources resolve from the package")
	for i in 200:
		host=get_tree().current_scene as Title
		if host and host.get_script().resource_path.ends_with("mara_sector_title.gd") and host._page==Title.Page.TITLE:
			break
		await get_tree().process_frame
	if not _check(host and host._page==Title.Page.TITLE,"actual deferred normal shared host"):
		_fail()
		return
	var entered := false
	if mode=="keeper":
		entered=_press("Load") and _press("*Sereth Vale*")
	else:
		entered=_press("Continue")
	if not _check(entered,"actual cold ordinary Continue or Load"):
		_fail()
		return
	var expected: Array=STATIONS["year-five"] if mode=="off" else STATIONS[mode]
	_check(_saved()==expected[0] and host._campaign_world.mission_at_current_waypoint()==expected[1],
		"exact durable Sereth destination and mission")
	_check(Profile.new().completed_missions("sova").is_empty() and
		not Profile.new().has_seen_intermission("sova",Beats.SOVA_GODBRIDLE_HANDOVER) and
		host._campaign_world.waypoint("cairnspine_vault_road").is_empty(),"no Sova state, event or Vault road")
	if mode=="off":
		_check(host._stage.get_child(0) is Flat,"explicit isolated disable uses canonical chart")
		_quit_button()
		return
	for i in 7:
		await get_tree().physics_frame
	var map := host._stage.get_child(0) as Control
	var presenter: Variant=host.get("_sereth_presenter")
	if not _check(map and presenter and presenter._mounted(map),"grounded actual native sector under normal host"):
		_fail()
		return
	if mode=="year-five":
		var relief: Node3D=map._renderer.relief
		_check(relief.has_node("OpenAssemblyCourt") and not relief.has_node("ForecourtAndClosedVault") and
			not relief.has_node("WitnessTerrace") and map._points.size()==1,"same empty neutral court; no custody props")
	_check(DisplayServer.get_name()!="headless","ordinary native app window")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var frame:=get_viewport().get_texture().get_image()
		_check(frame and frame.get_width()>0 and frame.get_height()>0 and is_instance_valid(map.render_viewport),
			"actual rendered native overworld viewport")
	map.select_waypoint(String(expected[0]))
	map.confirm_selection()
	_check(host._page==Title.Page.MISSION_BRIEFING and _press("Read Dispatch"),"original separate stock briefing")
	_check(host._page==Title.Page.CAMPAIGN_DIALOGUE and host._stage.get_child(0)._beat_id==expected[2],
		"correct canonical dispatch, no borrowed campaign scene")
	_advance()
	_check(_press("Confirm Deployment") and host._campaign_battle and
		host._campaign_battle.scene_file_path.ends_with(String(expected[3])),"actual native mission scene")
	if host._campaign_battle:
		host._return_from_campaign_battle()
	_check(_saved()==expected[0] and not Profile.new().completed_missions("sereth").has(String(expected[1])),
		"retreat preserves saved station but grants no mission victory")
	_quit_button()

func _saved()->String:
	return Profile.new().load_campaign_world("sereth").current_waypoint_id()

func _press(label:String)->bool:
	var item:=host._stage.find_child(label,true,false) as Button
	if not item or item.disabled:
		return false
	item.pressed.emit()
	return true

func _advance()->void:
	if host._page!=Title.Page.CAMPAIGN_DIALOGUE:
		return
	var page:=host._stage
	while host._stage==page and page.get_child_count()>0 and page.get_child(0)._active:
		page.get_child(0).advance()

func _check(valid:bool,label:String)->bool:
	checks+=1
	if not valid:
		misses+=1
		printerr("FAIL: "+label)
	return valid

func _fail()->void:
	print("Native Sereth executable smoke (%s): FAIL %d/%d" % [mode,checks-misses,checks])
	get_tree().quit(1)

func _quit_button()->void:
	host._show_title()
	_check(_press("Quit") and host._page==Title.Page.QUIT,"actual Title Quit opens the stock confirmation")
	var quit_button:=host._stage.find_child("Quit Game",true,false) as Button
	_check(quit_button and quit_button.is_visible_in_tree(),"actual visible Quit Game control")
	if misses:
		_fail()
		return
	print("Native Sereth executable smoke (%s): PASS %d/%d; pressing actual Quit Game" % [mode,checks,checks])
	quit_button.pressed.emit()
