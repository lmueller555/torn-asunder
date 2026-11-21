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
const GrainScene := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Rival := preload("res://game/battlefield/marches_rival_reserve.gd")
const CLEAR_ID := "mara_mine_escort"
const MINE := "year_one_mine"
const CAMP := "marches_camp"
const ROAD := "marches_road"
const CROSSING := "marches_crossing"
const MOONWASH := "moonwash_road"
const GRAIN_ID := "mara_grain_crossing"
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
	var main_path := _profile_path
	var passed := configured and await _flow()
	if passed:
		passed = await _fresh_bread_flow(main_path + ".bread")
	_title.queue_free()
	await process_frame
	for path in [main_path, main_path + ".tmp", main_path + ".bread", main_path + ".bread.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara campaign: real Mine escort, linked Grain briefing, both blockade lanes, all debriefs, defeat, immutable first result, replay and Continue passed.")
	quit(0 if passed else 1)


func _flow() -> bool:
	if not _press("New Game") or not _press("ilyra"):
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

	if not _press("Confirm Deployment") or not _title._campaign_battle:
		return _fail("Explicit deployment did not start the actual mission scene.")
	_joy(JOY_BUTTON_B)
	if not _title._campaign_battle:
		return _fail("Title intercepted combat Circle as a return.")
	_key(KEY_ESCAPE)
	if not _on_map(MINE) or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Abandoning the battle changed the clear or arrived location.")

	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	var mission := _title._campaign_battle as Mission
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
	_map().select_waypoint(CROSSING)
	_joy(JOY_BUTTON_A)
	if not _on_map(MINE) or not _map()._confirm_button.disabled:
		return _fail("The first clear let the party skip the linked Marches Road.")
	_map().select_waypoint(ROAD)
	if _map()._confirm_button.disabled:
		return _fail("A persisted victory did not open the onward link.")

	var after_clear := FileAccess.get_file_as_string(_profile_path)
	_map().select_waypoint(MINE)
	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	_title._campaign_battle.set_physics_process(false)
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
	if not _press("ConfirmTravel") or not _on_map(ROAD) or _saved_world() != ROAD or _title._campaign_battle:
		return _fail("The open road did not persist arrival or started an unimplemented mission.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(ROAD) or _saved_clears() != PackedStringArray([CLEAR_ID]):
		return _fail("Continue did not restore Mara's last arrived point and existing clear.")
	return await _grain_flow()


func _grain_flow() -> bool:
	_map().select_waypoint(CROSSING)
	if not _press("ConfirmTravel") or not _on_briefing() or _saved_world() != CROSSING:
		return _fail("The new linked Crossing did not stop at its briefing and save its own waypoint.")
	if not _press("Read Dispatch") or not _finish_grain_beat(Beats.MARA_GRAIN_DISPATCH) or not _on_briefing():
		return _fail("Grain dispatch did not return to the battlefield briefing without deploying.")
	_joy(JOY_BUTTON_B)
	if not _on_map(CROSSING):
		return _fail("Cancel did not keep the party at the Crossing.")
	_map().select_waypoint(MOONWASH)
	_joy(JOY_BUTTON_A)
	if not _on_map(CROSSING) or not _map()._detail.text.contains("Grain on Credit"):
		return _fail("The old Mine clear unlocked Moonwash without a Grain victory.")
	_map().select_waypoint(CROSSING)
	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	var grain := _title._campaign_battle as GrainScene
	if not grain:
		return _fail("The Crossing deployed the wrong scene.")
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	var before := FileAccess.get_file_as_string(_profile_path)
	_key(KEY_T)
	_key(KEY_C)
	_key(KEY_T)
	grain._physics_process(0.07)
	if grain.objective.outcome != Grain.Outcome.FAILED or FileAccess.get_file_as_string(_profile_path) != before:
		return _fail("Turning back both carts did not fail without saving.")
	_key(KEY_BACKSPACE)
	if not _win_single_grain(grain, Grain.Cart.BREAD):
		return false
	await process_frame
	if (
		_saved_clears() != PackedStringArray([CLEAR_ID, GRAIN_ID])
		or _saved_grain() != Grain.SEED_ONLY
		or not _finish_grain_beat(Beats.MARA_GRAIN_SEED_DEBRIEF)
		or not _on_map(CROSSING)
	):
		return _fail("The first seed-only win did not save its actual result and debrief.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(CROSSING) or _saved_grain() != Grain.SEED_ONLY:
		return _fail("Continue did not preserve the first delivery result and Crossing waypoint.")
	before = FileAccess.get_file_as_string(_profile_path)
	if not _press("ConfirmTravel") or not _press("Confirm Deployment"):
		return false
	grain = _title._campaign_battle as GrainScene
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_both_grain(grain):
		return false
	await process_frame
	if (
		FileAccess.get_file_as_string(_profile_path) != before
		or _saved_grain() != Grain.SEED_ONLY
		or not _finish_grain_beat(Beats.MARA_GRAIN_BOTH_DEBRIEF)
		or not _on_map(CROSSING)
	):
		return _fail("A two-cart replay did not get its own debrief or overwrote the saved seed-only result.")
	_map().select_waypoint(MOONWASH)
	return (_press("ConfirmTravel") and _on_map(MOONWASH) and _saved_world() == MOONWASH
		and _title._campaign_battle == null and _button("Confirm Deployment") == null) or _fail("The new road was not saved, or exposed an unbuilt Moonwash battle.")


func _fresh_bread_flow(path: String) -> bool:
	_profile_path = path
	var profile := Profile.new(path)
	_title._profile = profile
	if profile.set_setting("reduced_motion", true) != OK or profile.record_mission_clear("mara", CLEAR_ID) != OK:
		return _fail("Could not seed the alternate profile with only the Mine clear.")
	var world := profile.load_campaign_world("mara")
	var clears := profile.completed_missions("mara")
	world.travel_to(MINE, clears)
	world.travel_to(ROAD, clears)
	if profile.record_world_waypoint(world) != OK:
		return _fail("Could not seed an independent arrival on Marches Road.")
	_title._show_title()
	if not _press("New Game") or not _press("mara") or not _on_map(ROAD):
		return _fail("Alternate profile did not open on its independently saved road.")
	_map().select_waypoint(CROSSING)
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return false
	var grain := _title._campaign_battle as GrainScene
	grain.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_single_grain(grain, Grain.Cart.SEED):
		return false
	await process_frame
	return (_saved_grain() == Grain.BREAD_ONLY and _finish_grain_beat(Beats.MARA_GRAIN_BREAD_DEBRIEF)
		and _on_map(CROSSING)) or _fail("The independent first bread-only clear did not save its own outcome and dialogue.")


func _win_single_grain(grain: GrainScene, blocked: Grain.Cart) -> bool:
	_grain_dispatch(grain, blocked)
	if (
		not _grain_wait(grain, func() -> bool: return grain._blocked_cart == blocked)
		or grain.committed_cart != blocked or grain.rival.status != Rival.Status.BLOCKING
	):
		return _fail("The physically first committed cart was not blocked by the enemy reserve.")
	var delivered := Grain.Cart.SEED if blocked == Grain.Cart.BREAD else Grain.Cart.BREAD
	_grain_dispatch(grain, delivered)
	if (
		not _grain_wait(grain, func() -> bool: return grain.objective.cart_state(delivered) == Grain.CartState.SECURED)
		or grain._blocked_cart != blocked
	):
		return _fail("The other cart did not reach its yard while the first stayed blocked.")
	if grain.objective.outcome != Grain.Outcome.ACTIVE:
		return _fail("Delivery alone completed before the other cart was resolved.")
	_key(KEY_C)
	_key(KEY_T)
	grain._physics_process(0.07)
	var result := Grain.SEED_ONLY if delivered == Grain.Cart.SEED else Grain.BREAD_ONLY
	return grain.objective.clear_result == result or _fail("Actual cart arrival plus turn-back gave the wrong result.")


func _win_both_grain(grain: GrainScene) -> bool:
	_grain_dispatch(grain, Grain.Cart.BREAD)
	if not _grain_wait(grain, func() -> bool: return grain._blocked_cart == Grain.Cart.BREAD):
		return false
	_grain_dispatch(grain, Grain.Cart.SEED)
	_key(KEY_SHIFT)
	var formation: Battle.Formation = grain.battle.formations[0]
	for id: String in ["ReserveFork", "ShelteredTurn", "FordApproachWest", "FordWestBank", "FordShallows", "FordEastBank", "StoreApproach"]:
		var point := grain.battlefield_marker(NodePath("Markers/Routes/" + id)).global_position
		grain.cursor = Vector2(point.x, point.z)
		_joy(JOY_BUTTON_X)
		if id == "StoreApproach":
			if not _grain_wait(grain, func() -> bool: return formation.position.distance_to(grain.cursor) < Rival.SCREEN_RADIUS - 0.6):
				return false
		elif not _grain_wait(grain, func() -> bool: return formation.order != Battle.Order.MOVE):
			return false
	_joy(JOY_BUTTON_A)
	grain._physics_process(0.07)
	_key(KEY_SHIFT, false)
	if formation.order != Battle.Order.HOLD or grain.rival.status != Rival.Status.SCREENED:
		return _fail("The real Hold at the blockade did not reopen the ford for replay.")
	return (_grain_wait(grain, func() -> bool: return grain.objective.outcome == Grain.Outcome.SUCCEEDED)
		and grain.objective.clear_result == Grain.BOTH) or _fail("The screened replay never delivered both carts.")


func _grain_dispatch(grain: GrainScene, cart: Grain.Cart) -> void:
	if grain.selected_cart != cart:
		_key(KEY_C)
	_key(KEY_G)
	grain._physics_process(0.07)


func _grain_wait(grain: GrainScene, condition: Callable) -> bool:
	for _step in range(1100):
		if condition.call():
			return true
		grain._physics_process(0.07)
	return _fail("A Grain route event did not occur within the fixed simulation steps.")


func _finish_grain_beat(id: StringName) -> bool:
	if not _is_dialogue(id):
		return false
	for _line in Beats.get_beat(id).lines:
		_key(KEY_ENTER)
	return _title._page != Title.Page.CAMPAIGN_DIALOGUE


func _saved_grain() -> StringName:
	return Profile.new(_profile_path).grain_clear_result()


func _win_escort() -> bool:
	for id: String in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard", "Objectives/GodbridlePickup"]:
		if not _drive_to(id):
			return false
	_joy(JOY_BUTTON_A)
	_tick()
	var mission := _title._campaign_battle as Mission
	if mission.objective.phase != Escort.Phase.ESCORTING:
		return _fail("Cross did not interact with the deployed battlefield's bridle.")
	for id: String in ["Routes/MineYard", "Routes/RoadWest", "Routes/RoadJunction", "Routes/RoadCut"]:
		if not _drive_to(id):
			return false
	if not _drive_to("Routes/EastPass") or not _drive_to("Routes/InterceptRoadMerge", true):
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
	for id: String in ["Routes/PassRelease", "Objectives/GodbridleExit"]:
		if not _drive_to(id):
			return false
	return mission.objective.phase == Escort.Phase.SUCCEEDED or _fail("Actual east exit delivery did not win.")


func _drive_to(marker_id: String, until_windup := false) -> bool:
	var mission := _title._campaign_battle as Mission
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
	return _title._page == Title.Page.MISSION_BRIEFING and _button("Confirm Deployment") != null and _title._campaign_battle == null


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
		(_title._campaign_battle as Mission)._physics_process(DT)


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
