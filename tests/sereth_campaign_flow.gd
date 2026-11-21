extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Map := preload("res://game/campaign_map.gd")
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/sereth_cut_playtest.gd")
const Cut := preload("res://game/battlefield/sereth_voices_at_the_cut.gd")
const WritScene := preload("res://game/battlefield/sereth_pass_writ_playtest.gd")
const Writ := preload("res://game/battlefield/sereth_pass_writ.gd")
const FinaleScene := preload("res://game/battlefield/sereth_no_proxy_playtest.gd")
const Finale := preload("res://game/battlefield/sereth_no_proxy.gd")
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
const FINALE_CLEAR := "sereth_no_proxy"
const OTHER_SAVES := {
	"mara": ["mara_mine_escort", ["year_one_mine", "marches_road"]],
	"raska": ["orc_mine_witness", ["year_one_mine", "basin_well_road"]],
	"sova": ["sova_mine_tunnels", ["year_one_mine", "cairnspine_assembly"]],
	"ilyra": ["ilyra_moonwash_rescue", ["moonwash_harbor", "moonwash_survey_shore"]],
	"neris": ["neris_failing_grove", ["isolated_grove_nursery", "spanwater_lock"]],
}
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
		passed = await _play_boundary_route()
	if passed:
		passed = await _play_finale_route()
	_title.queue_free()
	await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Sereth campaign: all three actual clears, physical defeats/retry, both finale routes, lamp ending, completion, replay, Continue and five independent saves passed.")
	quit(0 if passed else 1)


func _seed_other_saves(profile: Profile) -> bool:
	for campaign_id: String in OTHER_SAVES:
		var fixture: Array = OTHER_SAVES[campaign_id]
		var result := profile.record_ilyra_moonwash_clear(&"crews_only") if campaign_id == "ilyra" \
			else profile.record_mission_clear(campaign_id, fixture[0])
		if result != OK:
			return _fail("Could not prepare the independent clear for " + campaign_id)
		var world := profile.load_campaign_world(campaign_id)
		for id: String in fixture[1]:
			if world.travel_to(id, profile.completed_missions(campaign_id)) != World.TravelResult.ARRIVED:
				return _fail("Could not seed the independent route for " + campaign_id)
		if profile.record_world_waypoint(world) != OK:
			return _fail("Could not seed the independent waypoint for " + campaign_id)
	return true

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


func _play_boundary_route() -> bool:
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
	if not _map().select_waypoint(ASSEMBLY) or not _press("ConfirmTravel") or not _on_briefing(FINALE_CLEAR):
		return _fail("The writ did not open a distinct briefing at the shared Valley Assembly.")
	return true


func _play_finale_route() -> bool:
	_joy(JOY_BUTTON_B)
	if not _on_map(ASSEMBLY) or _map()._heading.text == "Campaign Complete":
		return _fail("Cancel did not keep the unfinished campaign at the reached assembly.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(ASSEMBLY) or not _press("ConfirmTravel") \
			or not _on_briefing(FINALE_CLEAR) or not _press("Read Dispatch") or not _is_dialogue(Beats.SERETH_NO_PROXY_DISPATCH):
		return _fail("Continue did not restore the assembly or its distinct Year Five dispatch.")
	_finish_dialogue()
	if not _on_briefing(FINALE_CLEAR) or not _press("Confirm Deployment"):
		return _fail("The finale dispatch did not return to an explicit deployment.")
	var finale := _title._campaign_battle as FinaleScene
	if not finale or finale._field.name != &"CairnspineVaultRoad":
		return _fail("The briefing did not deploy Sereth's real finale on the shared Cairnspine.")
	finale.set_physics_process(false)
	await physics_frame
	await physics_frame
	var at_assembly := FileAccess.get_file_as_string(_path)

	if not _finale_refuse(finale) or not _wait_for(finale, func() -> bool:
		return finale.objective.phase == Finale.Phase.FAILED, 10600
	):
		return false
	if finale.objective.failure != Finale.Failure.SPEAKER_CROSSED_CUSTODY_LINE \
			or not finale._inside(finale._custody_zone, finale._speaker.position) \
			or _title._page != Title.Page.CAMPAIGN_BATTLE or FileAccess.get_file_as_string(_path) != at_assembly:
		return _fail("Actual custody crossing did not produce a local defeat without saving.")
	_joy(JOY_BUTTON_START)
	if finale.objective.phase != Finale.Phase.AT_ASSEMBLY or finale._speaker.marker.visible \
			or FileAccess.get_file_as_string(_path) != at_assembly:
		return _fail("Retry did not reset the assembly or preserve its unfinished save.")
	if not _win_finale(finale, Finale.Route.SHELF, at_assembly):
		return false
	await process_frame
	if not _finish_finale_debrief():
		return false
	var complete := PackedStringArray([CLEAR, WRIT_CLEAR, FINALE_CLEAR])
	var profile := Profile.new(_path)
	if not _on_completed_map() or profile.completed_missions("sereth") != complete \
			or profile.load_campaign_world("sereth").current_waypoint_id() != ASSEMBLY:
		return _fail("The actual finale did not save exactly once and mark the campaign complete.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_completed_map():
		return _fail("Continue did not restore the completed Undead campaign at the assembly.")
	var saved := FileAccess.get_file_as_string(_path)
	if not _press("ConfirmTravel") or not _on_briefing(FINALE_CLEAR) or not _press("Confirm Deployment"):
		return _fail("Completing the campaign disabled the finale replay.")
	finale = _title._campaign_battle as FinaleScene
	if not finale or finale.objective.refused_escort:
		return _fail("Finale replay did not begin a fresh scene.")
	finale.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _win_finale(finale, Finale.Route.SIDE, saved):
		return false
	await process_frame
	if not _finish_finale_debrief() or not _on_completed_map() or FileAccess.get_file_as_string(_path) != saved:
		return _fail("The alternate route replay was not idempotent.")
	profile = Profile.new(_path)
	for campaign_id: String in OTHER_SAVES:
		var fixture: Array = OTHER_SAVES[campaign_id]
		if profile.completed_missions(campaign_id) != PackedStringArray([fixture[0]]) \
				or profile.load_campaign_world(campaign_id).current_waypoint_id() != fixture[1][-1]:
			return _fail("Playing Sereth changed the independently saved progress for " + campaign_id)
	return profile.ilyra_moonwash_clear_result() == &"crews_only" \
		or _fail("Playing Sereth overwrote another leader's saved branch.")


func _finale_refuse(finale: FinaleScene) -> bool:
	if not _walk(["Routes/ValleyAssembly"], finale):
		return false
	_joy(JOY_BUTTON_A)
	finale._physics_process(DT)
	if finale.objective.phase != Finale.Phase.RELEASING_COURT_TROOPS or finale._speaker.marker.visible:
		return _fail("The actual assembly refusal did not visibly precede the roster split.")
	return (_wait_for(finale, func() -> bool: return finale.objective.phase == Finale.Phase.INTERCEPTING, 170)
		and finale._speaker.marker.visible and finale.battle.formations[FinaleScene.COURT].order == Battle.Order.EXTRACTED) \
		or _fail("The physical court departure did not leave Sereth with only the Household Guard.")


func _win_finale(finale: FinaleScene, route: Finale.Route, unchanged: String) -> bool:
	var shelf := route == Finale.Route.SHELF
	var initial := ["ValleyAssembly", "SafeStaging", "ShelfDecision"]
	if shelf:
		initial.append("ShelfFoot")
	if not _command_household(finale, initial) or not _finale_refuse(finale):
		return false
	if not _wait_for(finale, func() -> bool: return finale.objective.speaker_route != Finale.Route.NONE, 1900) \
			or finale.objective.speaker_route != route:
		return _fail("The Household's actual fork occupation did not lead to the expected approach.")
	if not shelf and not _command_household(finale, ["SafeStaging"] + FinaleScene.SIDE.slice(0, 5)):
		return false
	var approach := FinaleScene.SHELF.slice(0, 1) if shelf else FinaleScene.SIDE.slice(0, 4)
	if not _wait_for(finale, func() -> bool: return finale._escort_stalled, 2350) \
			or not _walk(_route_markers(["SafeStaging"] + approach), finale) \
			or not _walk_to(finale._speaker.marker.global_position, finale, 0.16):
		return _fail("The Household Hold did not let Sereth physically reach the stalled speaker.")
	_key(KEY_SPACE)
	finale._physics_process(DT)
	if finale.objective.phase != Finale.Phase.CLEARING_TERRACE or not finale.objective.bid_halted \
			or FileAccess.get_file_as_string(_path) != unchanged:
		return _fail("Challenging the speaker alone counted as victory.")
	var onward := FinaleScene.SHELF.slice(2) + ["Forecourt", "TerraceApproach"] \
		if shelf else FinaleScene.SIDE.slice(5) + ["TerraceApproach"]
	if not _command_household(finale, onward):
		return false
	var from_stall := (["ShelfFoot"] if shelf else ["SideBlindBend"]) + onward
	if not _walk(_route_markers(from_stall), finale) or not _wait_for(finale, func() -> bool:
		return finale._rival_cleared, 4300
	):
		return _fail("The physical guard did not drive the rival back from the approach.")
	if finale.objective.phase != Finale.Phase.CLEARING_TERRACE or FileAccess.get_file_as_string(_path) != unchanged:
		return _fail("A guard clearing the approach counted as Sereth's arrival.")
	return (_walk(["Routes/TerraceEntry"], finale, FinaleScene.INTERACTION_RADIUS) \
		and finale.objective.phase == Finale.Phase.SUCCEEDED) or _fail("Sereth's separate actual terrace arrival did not win.")


func _command_household(finale: FinaleScene, ids: Array) -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var guard := finale.battle.formations[FinaleScene.HOUSEHOLD]
	for id: String in ids:
		var target := finale._route(id)
		finale.cursor = target
		_joy(JOY_BUTTON_X)
		var budget := ceili(guard.position.distance_to(target) / Battle.FORMATION_SPEED / DT) + 90
		if not _wait_for(finale, func() -> bool: return guard.order == Battle.Order.HOLD and guard.position == target, budget):
			return _fail("The Household Guard did not physically reach " + id)
		_joy(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return true


func _route_markers(ids: Array) -> Array:
	var markers := []
	for id: String in ids:
		markers.append("Routes/" + id)
	return markers


func _finish_finale_debrief() -> bool:
	if not _is_dialogue(Beats.SERETH_NO_PROXY_DEBRIEF):
		return _fail("The real Year Five clear did not open its own debrief.")
	var dialogue := _title._stage.get_node("CampaignDialogue") as Dialogue
	var lines: Label = dialogue.find_child("DialogueLine", true, false)
	_key(KEY_ENTER)
	if not lines.text.contains("commission is revoked"):
		return _fail("The finale debrief lost the court's response.")
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	if not lines.text.contains("Sereth lights a lamp"):
		return _fail("Sereth's ending did not carry out the letter's request.")
	_key(KEY_ENTER)
	return true


func _on_completed_map() -> bool:
	return _on_map(ASSEMBLY) and _map()._heading.text == "Campaign Complete"


func _play_writ_and_retry(post: WritScene, at_post: String) -> bool:
	if not _walk(UNSCREENED_ROAD, post) or not _wait_for(post, func() -> bool:
		return post.objective.post_occupation_warned, 2300
	):
		return _fail("Taking the exposed road did not cause a real occupation warning.")
	if not post._yard.has_point(post._patrol.global_position + Vector3.UP * 0.8) \
			or not _wait_for(post, func() -> bool: return post.objective.phase == Writ.Phase.FAILED, 450) \
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
			or not _wait_for(post, func() -> bool: return post.objective.audience_granted, 100) \
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


func _wait_for(field: Harness, condition: Callable, attempts: int) -> bool:
	for _attempt in attempts:
		if condition.call():
			return true
		field._physics_process(DT)
	return condition.call()


func _walk(ids: Array, field: Harness = null, tolerance := 0.16) -> bool:
	var active := field if field else _mission
	for id: String in ids:
		if not _walk_to(_point(id, active), active, tolerance):
			return _fail("Actual terrain blocked Sereth before " + id)
	return true


func _walk_to(point: Vector3, active: Harness, tolerance: float) -> bool:
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
	return active.hero_world_position().distance_to(point) <= tolerance


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
