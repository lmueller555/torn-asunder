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
const WritScene := preload("res://game/battlefield/sereth_pass_writ_playtest.gd")
const Writ := preload("res://game/battlefield/sereth_pass_writ.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Account := Cut.AccountStatus
const Bundle := Cut.BundleStatus
const CAMP := "still_kingdom_camp"
const VILLAGE := "still_kingdom_cut"
const POST := "cairnspine_boundary_post"
const ASSEMBLY := "cairnspine_assembly"
const CLEAR := "sereth_voices_at_the_cut"
const WRIT_CLEAR := "sereth_pass_writ"
const DT := 1.0 / 60.0
const TO_WITNESS := ["Routes/ApproachRoadWest", "Routes/WestLaneRoadJunction", "Routes/WestLaneEntrance",
	"Routes/GateInnerTurn", "Routes/GateOuterTurn", "Objectives/WitnessAccount"]
const TO_BUNDLE := ["Routes/CemeteryHold", "Routes/CemeteryStairTop", "Routes/CemeteryStairFoot",
	"Routes/GraveCutApproach", "Objectives/ExposedRecords"]
const TO_CLERK := ["Routes/GraveCutApproach", "Routes/CemeteryStairFoot", "Routes/CemeteryStairTop",
	"Routes/CemeteryHold", "Routes/GateOuterTurn", "Routes/GateInnerTurn", "Routes/LaneWestTurn",
	"Routes/LaneSouthTurn", "Routes/LaneSecurityBend", "Routes/LaneEastTurn", "Routes/LaneClerkTurn",
	"Routes/ClerkYard", "Routes/RecordRoomDoor", "Routes/RecordRoomInside", "Objectives/AccountEntry"]
const TRACK_IN := ["Routes/WestRoadFork", "Routes/WestTrackJunction", "Routes/WestTrackTurn",
	"Routes/WestRampTop", "Routes/WestRampBottom", "Routes/SheepTrackBend", "Routes/SheepPinch", "Routes/CoveredTrackHold"]
const TRACK_OUT := ["Routes/EastRampBottom", "Routes/EastRampTop", "Routes/EastTrackLanding",
	"Routes/TrackEmergence", "Routes/TrackWallCorner", "Routes/PostTrackTurn", "Objectives/WritHandover"]
const UNSCREENED_ROAD := ["Routes/RoadScreen", "Routes/OpenRoadBrace", "Routes/RoadCenter",
	"Routes/ScoutRoadBypassWest", "Routes/ScoutRampFoot", "Routes/ScoutRampTop", "Routes/HighBankScout",
	"Routes/ScoutRampTop", "Routes/ScoutRampFoot", "Routes/ScoutRoadBypassEast", "Routes/RoadEastStraight",
	"Routes/LookoutBendRoad"]
const RALLY_APPROACH := ["Routes/WestRoadFork", "Routes/WestMarchEdge", "Routes/RallyOpenTurn", "Routes/RallyScreenCorner"]


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
		passed = await _check_return_and_saves()
	_title.queue_free()
	await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Sereth campaign: real Cut and writ, physical defeat/retry, hearing-only debrief, independent saves, replay and travel-only Valley Assembly passed.")
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
	if not _press("ConfirmTravel") or not _on_briefing(WRIT_CLEAR):
		return _fail("Securing the records did not open the explicit boundary-post briefing.")
	_joy(JOY_BUTTON_B)
	if not _on_map(POST) or not _map().select_waypoint(ASSEMBLY) or not _button("ConfirmTravel").disabled \
			or not _map()._detail.text.contains("An Audience, Not a Seizure"):
		return _fail("Arrival without the writ clear unlocked the Valley Assembly.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(POST) or not _press("ConfirmTravel") or not _on_briefing(WRIT_CLEAR) \
			or not _press("Read Dispatch") or not _is_dialogue(Beats.SERETH_PASS_WRIT_DISPATCH):
		return _fail("Continue did not restore the post or its distinct Year Four dispatch.")
	_finish_dialogue()
	if not _on_briefing(WRIT_CLEAR) or not _press("Confirm Deployment"):
		return _fail("The dispatch did not return to a separately deployable briefing.")
	var post := _title._campaign_battle as WritScene
	if not post or post._field.name != &"CairnspineBoundaryPost" or post.battle.bounds.size != Vector2(290, 178):
		return _fail("Sereth did not deploy at the real boundary map.")
	post.set_physics_process(false)
	await physics_frame
	await physics_frame
	var at_post := FileAccess.get_file_as_string(_path)
	if not _play_writ_and_retry(post, at_post):
		return false
	await process_frame
	var profile := Profile.new(_path)
	var debrief := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not _is_dialogue(Beats.SERETH_PASS_WRIT_DEBRIEF) \
			or profile.completed_missions("sereth") != PackedStringArray([CLEAR, WRIT_CLEAR]) \
			or profile.load_campaign_world("sereth").current_waypoint_id() != POST:
		return _fail("The withdrawal did not record only the writ clear and play the hearing debrief.")
	_key(KEY_ENTER)
	var line := debrief.find_child("DialogueLine", true, false) as Label
	if not line or not line.text.contains("a hearing only, at the valley assembly"):
		return _fail("The hearing debrief did not retain its limited terms.")
	for _remaining in range(Beats.get_beat(Beats.SERETH_PASS_WRIT_DEBRIEF).lines.size() - 1):
		_key(KEY_ENTER)
	if not _on_map(POST) or _map()._heading.text == "Campaign Complete":
		return _fail("The writ debrief did not return to the still-unfinished campaign.")
	var completed_writ := FileAccess.get_file_as_string(_path)
	if not _press("ConfirmTravel") or not _on_briefing(WRIT_CLEAR) or not _press("Confirm Deployment"):
		return _fail("The cleared writ could not be replayed.")
	var replay := _title._campaign_battle as WritScene
	if not replay or replay.objective.phase != Writ.Phase.CARRYING_WRIT or replay.objective.audience_granted \
			or not _press("ReturnToMap") or not _on_map(POST) or FileAccess.get_file_as_string(_path) != completed_writ:
		return _fail("The replay did not start fresh or changed the existing writ clear.")
	if not _map().select_waypoint(ASSEMBLY) or not _press("ConfirmTravel") or not _on_map(ASSEMBLY) \
			or not _title._campaign_world.mission_at_current_waypoint().is_empty() \
			or not Deployment.for_mission("sereth_no_proxy").is_empty():
		return _fail("The writ did not open the next waypoint as travel only.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(ASSEMBLY) or not _button("ConfirmTravel").disabled:
		return _fail("Continue did not restore the unfinished campaign at the Valley Assembly.")
	profile = Profile.new(_path)
	return (profile.completed_missions("mara") == PackedStringArray(["mara_mine_escort"]) \
		and profile.load_campaign_world("mara").current_waypoint_id() == "marches_road" \
		and profile.completed_missions("neris") == PackedStringArray(["neris_failing_grove"]) \
		and profile.load_campaign_world("neris").current_waypoint_id() == "spanwater_lock" \
		and profile.completed_missions("sova").is_empty() \
		and profile.completed_missions("sereth") == PackedStringArray([CLEAR, WRIT_CLEAR])) \
		or _fail("Sereth's hearing or travel contaminated or needed another campaign's clear.")


func _play_writ_and_retry(post: WritScene, at_post: String) -> bool:
	if not _walk(UNSCREENED_ROAD, post) or not _wait_writ(post, func() -> bool:
		return post.objective.post_occupation_warned, 2300
	):
		return _fail("Taking the exposed road did not cause a real occupation warning.")
	if not post._yard.has_point(post._patrol.global_position + Vector3.UP * 0.8) \
			or not _wait_writ(post, func() -> bool: return post.objective.phase == Writ.Phase.FAILED, 450) \
			or post.objective.failure != Writ.Failure.KEEPER_DRIVEN_AWAY \
			or FileAccess.get_file_as_string(_path) != at_post or _title._page != Title.Page.CAMPAIGN_BATTLE:
		return _fail("A real patrol occupation did not cause a defeat without saving.")
	_joy(JOY_BUTTON_START)
	if post.objective.phase != Writ.Phase.CARRYING_WRIT or not post._keeper.visible \
			or post.objective.reserve != Writ.Reserve.UNALERTED or not _walk(TRACK_IN, post) \
			or post.objective.reserve != Writ.Reserve.UNALERTED or post.hero_world_position().y > -3.9:
		return _fail("Retry did not reset the playtest or the covered approach did not conceal Sereth.")
	if not _walk(TRACK_OUT, post):
		return false
	_joy(JOY_BUTTON_A)
	post._physics_process(DT)
	if post.objective.phase != Writ.Phase.AWAITING_KEEPER or post.objective.audience_granted \
			or not _wait_writ(post, func() -> bool: return post.objective.audience_granted, 100) \
			or not post._keeper.global_position.is_equal_approx(post._keeper_reply_spot) \
			or post.objective.phase != Writ.Phase.WITHDRAWING or FileAccess.get_file_as_string(_path) != at_post:
		return _fail("The physical hearing was not separate from the offer, or wrote a clear before withdrawal.")
	var east := TRACK_OUT.duplicate()
	east.reverse()
	var west := TRACK_IN.duplicate()
	west.reverse()
	if not _walk(east + west + RALLY_APPROACH, post) \
			or not _walk(["Objectives/WithdrawalRally"], post, WritScene.RALLY_RADIUS):
		return false
	return (post.objective.phase == Writ.Phase.SUCCEEDED and post.objective.audience_granted \
		and post.hero_world_position().distance_to(_point("Objectives/WithdrawalRally", post)) <= WritScene.RALLY_RADIUS \
		and post.objective.reserve != Writ.Reserve.UNALERTED) \
		or _fail("The physical west rally did not finish the hearing-only mission with a live reserve.")


func _wait_writ(post: WritScene, condition: Callable, attempts: int) -> bool:
	for _attempt in attempts:
		if condition.call():
			return true
		post._physics_process(DT)
	return condition.call()


func _walk(ids: Array, field: Harness = null, tolerance := 0.16) -> bool:
	var active := field if field else _mission
	for id: String in ids:
		var point := _point(id, active)
		var local := active.to_local(point)
		var target := Vector2(local.x, local.z)
		var budget := ceili(target.distance_to(active.battle.hero_position) / Battle.HERO_SPEED / DT) + 100
		for _step in range(budget):
			var remaining := target - active.battle.hero_position
			if remaining.length() < 0.1 or active.hero_world_position().distance_to(point) <= tolerance:
				break
			var move := remaining.normalized().rotated(active._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, move.x)
			_axis(JOY_AXIS_LEFT_Y, move.y)
			active._physics_process(DT)
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		if active.hero_world_position().distance_to(point) > tolerance:
			return _fail("Actual terrain blocked Sereth before " + id)
	return true


func _point(id: String, field: Harness = null) -> Vector3:
	var active := field if field else _mission
	return active.battlefield_marker(NodePath("Markers/" + id)).global_position


func _tick(count := 1) -> void:
	for _step in range(count):
		_mission._physics_process(DT)


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null \
		and _title._campaign_world.campaign_id() == "sereth" and _title._campaign_world.current_waypoint_id() == id


func _on_briefing(mission_id := CLEAR) -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null \
		and _title._campaign_world.mission_at_current_waypoint() == mission_id


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
