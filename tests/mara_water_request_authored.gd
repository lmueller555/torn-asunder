extends SceneTree

const TitleScript := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const ActualCoast := preload("res://game/overworld/moonwash/coast_map.gd")
const Pilot := preload("res://game/campaign_overworld_3d.gd")
const CampaignMap := preload("res://game/campaign_map.gd")
const Campaigns := preload("res://game/campaigns.gd")
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const ROAD := "moonwash_road"
const HARBOR := "moonwash_harbor"
const QUAY := "mara_moonwash_quay"
const WATER := Beats.MARA_WATER_REQUEST


class FaultableTitle extends TitleScript:
	var break_content := false

	func _water_request_content() -> Dictionary:
		return {} if break_content else super._water_request_content()


var _title: FaultableTitle
var _path := ""
var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> bool:
	_checks += 1
	if not ok:
		_fails += 1
		printerr("FAIL " + what)
	return ok


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_path = OS.get_temp_dir().path_join("mara-water-title-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	await _exercise()
	await _close_title()
	if DirAccess.dir_exists_absolute(_path + ".tmp"):
		DirAccess.remove_absolute(_path + ".tmp")
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	print("Moonwash scenic real route and Water Request actual title: %d/%d checks passed." % [_checks - _fails, _checks])
	quit(0 if _fails == 0 else 1)


func _fresh_save(where: String, with_pending_reveal: bool) -> bool:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	var profile := Profile.new(_path)
	if profile.mark_played("raska") != OK or profile.record_mission_clear("raska", "orc_mine_witness") != OK \
			or profile.mark_played("mara") != OK or profile.set_setting("fullscreen", false) != OK \
			or profile.record_greyhollow_rescue_clear() != OK or profile.record_grain_clear(Grain.BOTH) != OK:
		return false
	if not with_pending_reveal and profile.finish_greyhollow_reveal() != OK:
		return false
	var valid_world := World.new("mara", where, profile.completed_missions("mara"))
	return valid_world.current_waypoint_id() == where and profile.record_world_waypoint(valid_world) == OK


func _make_title(opt_in: bool, invalid_content := false, inject_factory := true) -> void:
	var instance := TitleScene.instantiate()
	instance.set_script(FaultableTitle)
	_title = instance as FaultableTitle
	_title._profile = Profile.new(_path)
	_title.break_content = invalid_content
	if inject_factory:
		_title.set_development_overworld_factory(_coast_factory, opt_in)
	root.add_child(_title)
	await process_frame


func _close_title() -> void:
	if is_instance_valid(_title):
		_title.queue_free()
		_title = null
	await process_frame


func _coast_factory(world: World) -> Pilot:
	if world.campaign_id() != "mara" or world.current_waypoint_id() not in [ROAD, HARBOR]:
		return null
	var view := ActualCoast.new()
	if view.build():
		return view
	view.free()
	return null


func _button(label: String) -> Button:
	for node in _title._stage.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == label:
			return button
	return null



func _press(label: String) -> bool:
	var button := _button(label)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


func _dialogue() -> Dialogue:
	for node in _title._stage.get_children():
		if node is Dialogue:
			return node
	return null


func _beat() -> StringName:
	var dialogue := _dialogue()
	return dialogue._beat_id if dialogue else &""


func _pilot() -> Pilot:
	for node in _title._stage.get_children():
		if node is Pilot:
			return node
	return null


func _seen() -> bool:
	return Profile.new(_path).has_seen_intermission("mara", WATER)


func _saved() -> String:
	return Profile.new(_path).load_campaign_world("mara").current_waypoint_id()


func _disk() -> String:
	return FileAccess.get_file_as_string(_path)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func _click_marker_region(view: ActualCoast, id: String) -> bool:
	if not view._pins.label_regions.has(id):
		return false
	var mouse := InputEventMouseButton.new()
	mouse.position = view.get_global_transform_with_canvas()*view._pins.label_regions[id].get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse,true)
	mouse.pressed = false
	root.push_input(mouse,true)
	return view._navigation.selected_waypoint_id()==id and not view._navigation.is_travelling()


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _exercise() -> void:
	if not _check(_fresh_save(HARBOR, false), "valid prior Harbor save"):
		return
	await _make_title(false, false, false)
	_check(_press("Continue") and _title._stage.get_child(0) is CampaignMap and not _seen(), "normal/default legacy Harbor stays on stock entry; gate off")
	await _close_title()
	if not _check(_fresh_save(ROAD, false), "valid Water Request pending on Road"):
		return
	await _make_title(true, true)
	_check(_press("Continue") and _button("Retry Water Request") != null and _button("Skip Water Request") == null \
		and _pilot() == null and not _seen(), "bad authored content recovery never marks seen or mounts map")
	var recovery := _title._stage
	_title._show_campaign_mission_briefing(QUAY)
	_title._deploy_campaign_mission(QUAY)
	_check(_title._stage == recovery and _button("Confirm Deployment") == null and _saved() == ROAD, "stale briefing/deploy paths cannot bypass failed content")
	_title.break_content = false
	if not _check(_press("Retry Water Request") and _beat() == WATER, "actual canonical content opens on retry"):
		return
	var old_dialogue := _dialogue()
	var before_cancel := _disk()
	_key(KEY_ESCAPE)
	_check(_button("Skip Water Request") != null and not _seen() and _disk() == before_cancel, "Esc cancels without acknowledging; retry and explicit skip available")
	old_dialogue.completed.emit(WATER)
	_check(_button("Skip Water Request") != null and not _seen() and _disk() == before_cancel, "canceled stale completion cannot acknowledge")
	_check(_press("Retry Water Request") and _beat() == WATER, "canceled scene can be reopened")
	# The title shell must also reject a stale arrival notification if the live
	# world had been moved before an unsent road confirmation was dismissed.
	_title._campaign_world.travel_to(HARBOR, _title._profile.completed_missions("mara"))
	_title._on_waypoint_arrived(HARBOR)
	_check(_saved() == ROAD and _title._campaign_world.current_waypoint_id() == ROAD and _beat() == WATER and not _seen(), "new Harbor arrival before acknowledgment is rolled back; valid legacy Harbor handled separately")
	_joy(JOY_BUTTON_B)
	var before_save := _disk()
	if not _check(DirAccess.make_dir_absolute(_path + ".tmp") == OK, "install actual temp-path write failure"):
		return
	_check(_press("Skip Water Request") and _button("Retry Save") != null and not _seen() and _disk() == before_save, "intentional skip still requires durable acknowledgment")
	_check(_press("Retry Save") and _button("Retry Save") != null and not _seen() and _saved() == ROAD, "failed retry does not advance or consume the gate")
	_title._show_world_map()
	_check(_button("Retry Save") != null and _pilot() == null, "map restoration cannot skip the failed-ack screen")
	DirAccess.remove_absolute(_path + ".tmp")
	_check(_press("Retry Save") and _seen() and _saved() == ROAD and _pilot() != null and _button("Confirm Deployment") == null, "repaired retry durably marks canonical beat before returning to Road")
	var view := _pilot()
	if not _check(view != null and view._renderer.terrain and view._renderer.has_node("MoonwashHarbor") 		and view._curve_for(ROAD,HARBOR).get_baked_length() > 484.8, "actual coast asset/harbor and original 485m route after acknowledgment"):
		return
	await process_frame
	view.set_process(false)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(view._renderer._groves.size()==9,"all eight thickets seated independently on MoonwashGround and Harbor LOD scope retained")
	_key(KEY_RIGHT)
	_joy(JOY_BUTTON_A)
	if not _check(view._navigation.is_travelling() and _saved() == ROAD, "normal directional select and confirm start Harbor travel separately"):
		return
	view._process(6.0)
	for i in range(18):
		view._renderer._process(1.0/30.0)
	if not _check(view._party.global_position.distance_to(Vector3(1060,32.9719,-57))>120.0 and _saved()==ROAD,
			"party follows real coast road with no early save or deployment"):
		return
	view._process(20.0)
	_check(_saved() == HARBOR and _pilot() == view and _button("Confirm Deployment") == null, "actual arrival stores Harbor without opening briefing")
	_check(view._party.global_position.distance_to(Vector3(1477,8.6,130))<0.002,
			"canonical Harbor arrival at the high gate instead of dock")
	_key(KEY_Z)
	_check(view._renderer._zoomed and view._renderer._groves[0][1].visible and not view._renderer._groves[0][2].visible,
			"intentional close zoom uses only already baked near Harbor")
	_joy(JOY_BUTTON_A)
	_check(_button("Confirm Deployment") != null and _title._page == TitleScript.Page.MISSION_BRIEFING and _title._campaign_battle == null, "explicit confirm opens stock Harbor briefing without deploying")
	_check(_press("Confirm Deployment") and _title._page == TitleScript.Page.CAMPAIGN_BATTLE and _title._campaign_battle != null, "explicit stock deployment allowed after seen")
	_title._return_from_campaign_battle()
	view = _pilot()
	if not _check(view != null and _saved() == HARBOR and _dialogue() == null, "retreat restores Harbor map without replay"):
		return
	await process_frame
	view.set_process(false)
	if DisplayServer.get_name()!="headless":
		_check(_click_marker_region(view,ROAD),"offscreen return sign is clickable and does not start travel before confirm")
	else:
		_key(KEY_LEFT)
	_joy(JOY_BUTTON_A)
	view._process(20.0)
	_check(_saved() == ROAD and _pilot() == view and _dialogue() == null and _seen(), "return Road with seen flag never repeats dialogue")

	await _close_title()
	await _make_title(true)
	_check(_press("Continue") and _pilot() != null and _dialogue() == null and _saved() == ROAD and _seen(), "cold reload after acknowledgment resumes Road without replay")
	await _close_title()
	if not _check(_fresh_save(HARBOR, true), "older legitimate Harbor with pending Greyhollow fixture"):
		return
	await _make_title(true)
	_check(_press("Load") and _press("King Mara Halden  ·  Humans"), "Load selects Mara from actual title")
	if not _check(_beat() == Beats.MARA_MINE_DEBRIEF and _saved() == HARBOR and not _seen(), "pending Greyhollow takes precedence over Harbor Water Request"):
		return
	_dialogue().cancel()
	if not _check(_beat() == WATER and _saved() == HARBOR and not _seen(), "legacy Harbor remains saved and resumes its unseen Water Request after Greyhollow"):
		return
	await _close_title()
	await _make_title(true)
	if not _check(_press("Continue") and _beat() == WATER and _saved() == HARBOR and not _seen(), "exiting during the Water Request leaves pending on reload"):
		return
	while _beat() == WATER:
		_joy(JOY_BUTTON_A)
	_check(_pilot() != null and _saved() == HARBOR and _seen(), "advancing authored dialogue to completion unlocks legacy Harbor without relocation")
	var contents := ConfigFile.new()
	_check(contents.load(_path) == OK and contents.get_value(Profile.CAMPAIGN_INTERMISSIONS, "mara", PackedStringArray()) == PackedStringArray([String(WATER)]), "canonical Water Request persisted exactly once")
	var read := Profile.new(_path)
	_check(read.grain_clear_result() == Grain.BOTH and read.completed_missions("raska") == PackedStringArray(["orc_mine_witness"]) \
		and not read.has_seen_intermission("raska", WATER), "durable acknowledgment preserves first Grain result and isolated Raska progress")
