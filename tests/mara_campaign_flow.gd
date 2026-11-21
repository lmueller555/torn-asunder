extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const CampaignMap := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const CLEAR_ID := "mara_mine_escort"
const MINE := "year_one_mine"
const CAMP := "marches_camp"
const ROAD := "marches_road"
const DT := 1.0 / 60.0

var _title: Title
var _profile_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-mara-flow-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	var configured := _title._profile.set_setting("fullscreen", false) == OK \
		and _title._profile.set_setting("reduced_motion", true) == OK
	root.add_child(_title)
	var passed := configured and await _flow()
	_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara campaign: camp dispatch, linked map, briefing, cancel, campaign-scale deployment, defeat, retry, real clear, debrief, replay and Continue passed.")
	quit(0 if passed else 1)


func _flow() -> bool:
	if not _press("New Game") or not _press("sova"):
		return false
	if _title._page != Title.Page.BRIEFING or _map() or _button("Confirm Deployment"):
		return _fail("A non-Mara campaign opened a deployable mission.")
	_joy(JOY_BUTTON_B)
	if not _press("New Game") or not _press("mara"):
		return false
	if not _on_map(CAMP) or _button("Confirm Deployment"):
		return _fail("New Game did not start at the camp on the overworld.")
	_joy(JOY_BUTTON_A)
	if _title._page != Title.Page.BRIEFING or not _button("Unit Progression") or not _press("Read Dispatch"):
		return _fail("Camp Operations did not offer practice and the dispatch.")
	if not _is_dialogue(Beats.MARA_MINE_DISPATCH):
		return _fail("Camp Operations did not start the authored mine dispatch.")
	_read_dialogue()
	if not _button("Read Dispatch") or not _press("Back") or not _on_map(CAMP):
		return _fail("Finishing the dispatch did not return through camp to the map.")

	_map().select_waypoint(ROAD)
	_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not _map()._detail.text.contains("Complete the Mine Escort"):
		return _fail("Selecting the gated adjoining road bypassed the opening mission.")
	_map().select_waypoint(MINE)
	if not _on_map(CAMP) or not _press("ConfirmTravel"):
		return _fail("An unconfirmed mine selection moved the party.")
	if not _on_briefing() or _saved_world() != MINE or not _saved_clears().is_empty():
		return _fail("Mine arrival did not persist the waypoint and stop at briefing without awarding a clear.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Cancel did not return to the actual arrived position with a way to reopen briefing.")
	var at_mine := FileAccess.get_file_as_string(_profile_path)

	if not _press("Confirm Deployment") or not _title._mara_mine:
		return _fail("Explicit deployment did not start the actual mission scene.")
	_joy(JOY_BUTTON_B)
	if not _title._mara_mine:
		return _fail("Title intercepted combat Circle as a return.")
	_key(KEY_ESCAPE)
	if not _on_map(MINE) or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Abandoning the battle changed the clear or arrived location.")

	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	var mission := _title._mara_mine
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if mission._field.name != &"YearOneMineCampaign" or mission.encounter == null:
		return _fail("Deployment fell back to the toy map or disabled live combat.")
	mission.report_hero_incapacitated()
	_tick()
	if mission.objective.phase != Escort.Phase.FAILED or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Defeat saved an escort clear or opened the debrief.")
	_key(KEY_BACKSPACE)
	if mission.objective.phase != Escort.Phase.AWAITING_PICKUP or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Retry did not reset only the local attempt.")
	if not _win_escort():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR_ID]) \
			or _saved_world() != MINE:
		return _fail("Real delivery did not persist the clear and waypoint before the debrief.")
	_read_dialogue()
	if not _on_map(MINE):
		return _fail("Finishing debrief did not return to the mine on the campaign map.")
	_map().select_waypoint(ROAD)
	if _map()._confirm_button.disabled:
		return _fail("A persisted victory did not open the onward link.")

	var after_clear := FileAccess.get_file_as_string(_profile_path)
	_map().select_waypoint(MINE)
	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	_title._mara_mine.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_escort():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or FileAccess.get_file_as_string(_profile_path) != after_clear:
		return _fail("Completing the same mission again rewrote the profile.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE):
		return _fail("Skipping debrief did not return to the map.")
	_map().select_waypoint(ROAD)
	if not _press("ConfirmTravel") or not _on_map(ROAD) or _saved_world() != ROAD or _title._mara_mine:
		return _fail("The open road did not persist arrival or started an unimplemented mission.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(ROAD) or _saved_clears() != PackedStringArray([CLEAR_ID]):
		return _fail("Continue did not restore Mara's last arrived point and existing clear.")
	return true


func _win_escort() -> bool:
	for id: String in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard", "Objectives/GodbridlePickup"]:
		if not _drive_to(id):
			return false
	_joy(JOY_BUTTON_A)
	_tick()
	var mission := _title._mara_mine
	if mission.objective.phase != Escort.Phase.ESCORTING:
		return _fail("Cross did not interact with the deployed battlefield's bridle.")
	for id: String in ["Routes/MineYard", "Routes/RoadWest", "Routes/RoadJunction", "Routes/RoadCut"]:
		if not _drive_to(id):
			return false
	if not _drive_to("Routes/EastPass", true):
		return false
	_key(KEY_U)
	_tick(43)
	_key(KEY_U, false)
	_key(KEY_J)
	_tick(35)
	for _attack in range(2):
		_key(KEY_K)
		_tick(58)
	if mission.encounter.enemy.is_alive() or mission.objective.phase != Escort.Phase.ESCORTING:
		return _fail("Fighting the road guard did not preserve the still-incomplete escort.")
	for id: String in ["Routes/EastPass", "Routes/PassRelease", "Objectives/GodbridleExit"]:
		if not _drive_to(id):
			return false
	return mission.objective.phase == Escort.Phase.SUCCEEDED or _fail("Actual east exit delivery did not win.")


func _drive_to(marker_id: String, until_windup := false) -> bool:
	var mission := _title._mara_mine
	var mark := mission.battlefield_marker(NodePath("Markers/" + marker_id))
	var local := mission.to_local(mark.global_position)
	var target := Vector2(local.x, local.z)
	var budget := ceili(target.distance_to(mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 120
	var reached := false
	for _step in range(budget):
		var remaining := target - mission.battle.hero_position
		var radius := Mission.EXIT_RADIUS if mark.name == &"GodbridleExit" else 0.13
		if (until_windup and mission.encounter.enemy_phase == Encounter.EnemyPhase.WINDUP) \
				or (not until_windup and remaining.length() < radius):
			reached = true
			break
		if mission._finished():
			break
		var aim := remaining.normalized().rotated(mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return reached or _fail("The actual route did not reach " + marker_id)


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null and _title._campaign_world.current_waypoint_id() == id


func _on_briefing() -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _button("Confirm Deployment") != null and _title._mara_mine == null


func _map() -> CampaignMap:
	return _title._stage.get_node_or_null("CampaignMap") as CampaignMap


func _is_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	return dialogue != null and dialogue._active and dialogue._beat_id == id


func _read_dialogue() -> void:
	for _line in range(4):
		_key(KEY_ENTER)


func _saved_world() -> String:
	return Profile.new(_profile_path).load_campaign_world("mara").current_waypoint_id()


func _saved_clears() -> PackedStringArray:
	return Profile.new(_profile_path).completed_missions("mara")


func _tick(count := 1) -> void:
	for _step in range(count):
		_title._mara_mine._physics_process(DT)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _button(name: String) -> Button:
	return _title.find_child(name, true, false) as Button


func _press(name: String) -> bool:
	var button := _button(name)
	if not button or button.disabled or not button.is_visible_in_tree():
		return _fail("Missing or unavailable control: " + name)
	button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
