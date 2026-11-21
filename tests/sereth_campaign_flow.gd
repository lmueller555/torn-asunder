extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Map := preload("res://game/campaign_map.gd")
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Deployment := preload("res://game/campaign_deployments.gd")
const Mission := preload("res://game/battlefield/sereth_cut_playtest.gd")
const Cut := preload("res://game/battlefield/sereth_voices_at_the_cut.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Account := Cut.AccountStatus
const Bundle := Cut.BundleStatus
const CAMP := "still_kingdom_camp"
const VILLAGE := "still_kingdom_cut"
const POST := "cairnspine_boundary_post"
const CLEAR := "sereth_voices_at_the_cut"
const DT := 1.0 / 60.0
const TO_WITNESS := ["Routes/ApproachRoadWest", "Routes/WestLaneRoadJunction", "Routes/WestLaneEntrance",
	"Routes/GateInnerTurn", "Routes/GateOuterTurn", "Objectives/WitnessAccount"]
const TO_BUNDLE := ["Routes/CemeteryHold", "Routes/CemeteryStairTop", "Routes/CemeteryStairFoot",
	"Routes/GraveCutApproach", "Objectives/ExposedRecords"]
const TO_CLERK := ["Routes/GraveCutApproach", "Routes/CemeteryStairFoot", "Routes/CemeteryStairTop",
	"Routes/CemeteryHold", "Routes/GateOuterTurn", "Routes/GateInnerTurn", "Routes/LaneWestTurn",
	"Routes/LaneSouthTurn", "Routes/LaneSecurityBend", "Routes/LaneEastTurn", "Routes/LaneClerkTurn",
	"Routes/ClerkYard", "Routes/RecordRoomDoor", "Routes/RecordRoomInside", "Objectives/AccountEntry"]

var _title: Title
var _mission: Mission
var _path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-sereth-flow-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_path)
	var seeded := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", true) == OK \
		and _seed_other_saves(profile)
	_title = TitleScene.instantiate()
	_title._profile = profile
	root.add_child(_title)
	var passed := seeded and _begin_route()
	if passed:
		passed = await _play_and_retry()
	if passed:
		passed = _check_return_and_saves()
	_title.queue_free()
	await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Sereth campaign: own camp and briefing, physical Cut defeat/retry and clear, independent saves, debrief and travel-only Boundary Post passed.")
	quit(0 if passed else 1)


func _seed_other_saves(profile: Profile) -> bool:
	if profile.record_mission_clear("mara", "mara_mine_escort") != OK \
			or profile.record_mission_clear("neris", "neris_failing_grove") != OK:
		return _fail("Could not prepare independent saved campaigns.")
	var mara := profile.load_campaign_world("mara")
	var neris := profile.load_campaign_world("neris")
	for id in ["year_one_mine", "marches_road"]:
		if mara.travel_to(id, profile.completed_missions("mara")) != World.TravelResult.ARRIVED:
			return _fail("Could not seed Mara's separate route.")
	for id in ["isolated_grove_nursery", "spanwater_lock"]:
		if neris.travel_to(id, profile.completed_missions("neris")) != World.TravelResult.ARRIVED:
			return _fail("Could not seed Neris's separate route.")
	return profile.record_world_waypoint(mara) == OK and profile.record_world_waypoint(neris) == OK


func _begin_route() -> bool:
	if not _press("New Game") or not _press("sereth") or not _on_map(CAMP) or _button("Confirm Deployment"):
		return _fail("Selecting Sereth did not open his own camp on the overworld.")
	if not _press("ConfirmTravel") or not _press("Read Dispatch") or not _is_dialogue(Beats.SERETH_CUT_DISPATCH):
		return _fail("Camp Operations did not show Sereth's authored orders.")
	_finish_dialogue()
	if not _press("Back") or not _on_map(CAMP):
		return _fail("Sereth's dispatch did not return through camp.")
	if _map().select_waypoint("year_one_mine") or not _map().select_waypoint(POST):
		return _fail("Sereth's map borrowed a foreign waypoint or omitted the post.")
	_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not _map()._detail.text.contains("The Names at the Cut"):
		return _fail("An uncleared Cut allowed the post route or hid its lock reason.")
	_map().select_waypoint(VILLAGE)
	if not _on_map(CAMP) or not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Selection did not wait for travel confirmation or arrival deployed without a choice.")
	if not _press("Read Dispatch") or not _is_dialogue(Beats.SERETH_CUT_DISPATCH):
		return _fail("Sereth's battlefield briefing lost its dispatch.")
	_finish_dialogue()
	_joy(JOY_BUTTON_B)
	if not _on_map(VILLAGE) or not _press("ConfirmTravel") or not _on_briefing():
		return _fail("The arrived Cut could not cancel and reopen its own briefing.")
	_title._deploy_campaign_mission("neris_failing_grove")
	if not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("The Cut authorized a foreign mission or did not deploy after confirmation.")
	return true


func _play_and_retry() -> bool:
	_mission = _title._campaign_battle as Mission
	if not _mission or _mission._field.name != &"StillKingdomCut" or _mission.battle.bounds.size != Vector2(390, 200):
		return _fail("Sereth did not deploy the actual Cut graybox.")
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var before := FileAccess.get_file_as_string(_path)
	if not _walk(TO_WITNESS):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	for _step in range(8500):
		if _mission.objective.outcome != Cut.Outcome.ACTIVE:
			break
		_tick()
	if _mission.objective.failure != Cut.Failure.BUNDLE_EXTRACTED \
			or not _mission._raider.global_position.is_equal_approx(_point("Objectives/EnemyRetreatExit")) \
			or _title._page != Title.Page.CAMPAIGN_BATTLE or FileAccess.get_file_as_string(_path) != before:
		return _fail("A real enemy extraction advanced Sereth or wrote a clear.")
	_joy(JOY_BUTTON_START)
	if _mission.objective.outcome != Cut.Outcome.ACTIVE or _mission.objective.account_status != Account.UNHEARD \
			or _mission.objective.bundle_status != Bundle.EXPOSED or FileAccess.get_file_as_string(_path) != before:
		return _fail("Retry retained or saved a lost attempt.")
	if not _walk(TO_WITNESS):
		return false
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.account_status != Account.HEARD or not _walk(TO_BUNDLE):
		return _fail("Retry did not allow a real Iren interaction and approach to the exposed bundle.")
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.bundle_status != Bundle.WITH_SERETH or not _walk(TO_CLERK):
		return _fail("The timely pickup did not carry the actual bundle back to the room.")
	_joy(JOY_BUTTON_A)
	_tick(2)
	if _mission.objective.account_status != Account.FILED or _mission.objective.outcome != Cut.Outcome.ACTIVE \
			or FileAccess.get_file_as_string(_path) != before:
		return _fail("Filing without securing the records counted as a clear.")
	if not _walk(["Spawns/VillageClerk", "Objectives/BundleSecure"]):
		return false
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.outcome != Cut.Outcome.SUCCEEDED \
			or not _mission._bundle.global_position.is_equal_approx(_point("Objectives/BundleSecure")):
		return _fail("Securing the actual records did not win after filing.")
	await process_frame
	var profile := Profile.new(_path)
	return (_is_dialogue(Beats.SERETH_CUT_DEBRIEF) and profile.completed_missions("sereth") == PackedStringArray([CLEAR]) \
		and profile.load_campaign_world("sereth").current_waypoint_id() == VILLAGE) \
		or _fail("Reality-based victory did not persist its own mission and reached waypoint before debrief.")


func _check_return_and_saves() -> bool:
	_finish_dialogue()
	if not _on_map(VILLAGE):
		return _fail("The authored debrief did not return to the Cut.")
	var saved := FileAccess.get_file_as_string(_path)
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("A cleared Cut was not replayable from its own waypoint.")
	_joy(JOY_BUTTON_BACK)
	if not _on_map(VILLAGE) or FileAccess.get_file_as_string(_path) != saved:
		return _fail("Abandoning a replay changed the saved clear.")
	_map().select_waypoint(POST)
	if not _press("ConfirmTravel") or not _on_map(POST) or _button("Confirm Deployment") \
			or not Deployment.for_mission("sereth_pass_writ").is_empty():
		return _fail("A win did not unlock the post as travel only.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(POST):
		return _fail("Continue did not restore Sereth's last arrived post.")
	var profile := Profile.new(_path)
	return (profile.completed_missions("mara") == PackedStringArray(["mara_mine_escort"]) \
		and profile.load_campaign_world("mara").current_waypoint_id() == "marches_road" \
		and profile.completed_missions("neris") == PackedStringArray(["neris_failing_grove"]) \
		and profile.load_campaign_world("neris").current_waypoint_id() == "spanwater_lock" \
		and profile.completed_missions("sereth") == PackedStringArray([CLEAR])) \
		or _fail("Sereth's clear or travel contaminated one of the other campaigns.")


func _walk(ids: Array) -> bool:
	for id: String in ids:
		var point := _point(id)
		var local := _mission.to_local(point)
		var target := Vector2(local.x, local.z)
		var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 100
		for _step in range(budget):
			var remaining := target - _mission.battle.hero_position
			if remaining.length() < 0.1:
				break
			var move := remaining.normalized().rotated(_mission._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, move.x)
			_axis(JOY_AXIS_LEFT_Y, move.y)
			_tick()
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		if _mission.hero_world_position().distance_to(point) >= 0.16:
			return _fail("Actual terrain blocked Sereth before " + id)
	return true


func _point(id: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + id)).global_position


func _tick(count := 1) -> void:
	for _step in range(count):
		_mission._physics_process(DT)


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null \
		and _title._campaign_world.campaign_id() == "sereth" and _title._campaign_world.current_waypoint_id() == id


func _on_briefing() -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null \
		and _title._campaign_world.mission_at_current_waypoint() == CLEAR


func _is_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	return dialogue != null and dialogue._active and dialogue._beat_id == id


func _finish_dialogue() -> void:
	for _line in range(5):
		_key(KEY_ENTER)


func _button(name: String) -> Button:
	return _title.find_child(name, true, false) as Button


func _press(name: String) -> bool:
	var button := _button(name)
	if not button or button.disabled or not button.is_visible_in_tree():
		return _fail("Missing or unavailable control: " + name)
	button.pressed.emit()
	return true


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
