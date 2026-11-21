extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const World := preload("res://game/campaign_world.gd")
const Mission := preload("res://game/battlefield/ilyra_moonwash_rescue_campaign.gd")
const Rescue := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const SurveyBattle := preload("res://game/battlefield/ilyra_coast_survey_campaign.gd")
const Survey := preload("res://game/battlefield/ilyra_coast_survey.gd")
const Evacuation := preload("res://game/battlefield/ilyra_spanwater_playtest.gd")
const BoatRescue := preload("res://game/battlefield/ilyra_spanwater_evacuation.gd")
const CAMP := "moonwash_camp"
const HARBOR := "moonwash_harbor"
const SHORE := "moonwash_survey_shore"
const CLEAR := "ilyra_moonwash_rescue"
const SURVEY_CLEAR := "ilyra_coast_survey"
const EVACUATION := "ilyra_spanwater_evacuation"
const SPANWATER := "spanwater_lock"
const DT := 1.0 / 60.0
const PIER := ["Routes/ReceivingGangway", "Routes/PierOuterTurn", "Routes/PierInnerTurn", "Routes/OpenMooring"]
const STRANDED := ["Routes/StrandedAccess", "Routes/StrandedDeckGangway"]
const STONE := ["Routes/StoneTrailTurn", "Objectives/AncestralStone"]
const INLET := ["Routes/StoneExit", "Routes/InletTrailTurn", "Objectives/FishingInlet"]
const INLAND := ["Routes/InlandJunction", "Routes/MidCoastLane"]
const RAMP := ["Routes/HeadlandLandwardTurn", "Routes/HeadlandRampFoot", "Routes/HeadlandRampTop",
	"Routes/HeadlandApron", "Routes/HighGuard"]
const OTHER_SAVES := {
	"mara": [["mara_mine_escort", "mara_grain_crossing", "mara_moonwash_quay"],
		["year_one_mine", "marches_road", "marches_crossing", "moonwash_road", HARBOR]],
	"raska": [["orc_mine_witness", "orc_well_road", "orc_spanwater_release"],
		["year_one_mine", "basin_well_road", SPANWATER]],
	"neris": [["neris_failing_grove", "neris_spanwater_feeder"], ["isolated_grove_nursery", SPANWATER]],
	"sova": [["sova_mine_tunnels"], ["year_one_mine", "cairnspine_assembly"]],
}

var _title: Title
var _mission: Mission
var _field_mission: Harness
var _profile_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-ilyra-flow-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	var profile := Profile.new(_profile_path)
	var seeded := profile.set_setting("fullscreen", false) == OK 		and profile.set_setting("reduced_motion", true) == OK and _seed_other_saves(profile)
	_title = TitleScene.instantiate()
	_title._profile = profile
	root.add_child(_title)
	var passed := seeded and await _flow()
	_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Ilyra campaign: all three physical chapter clears, abort/defeat/retry, loaded exit after closure, complete ending, replay, Continue and isolated first results passed.")
	quit(0 if passed else 1)


func _seed_other_saves(profile: Profile) -> bool:
	for id: String in OTHER_SAVES:
		var itinerary: Array = OTHER_SAVES[id]
		for cleared: String in itinerary[0]:
			var result := profile.record_grain_clear(&"both") if cleared == "mara_grain_crossing" 				else profile.record_mission_clear(id, cleared)
			if result != OK:
				return _fail("Could not create other campaign's existing clear.")
		var world := profile.load_campaign_world(id)
		for node: String in itinerary[1]:
			if world.travel_to(node, profile.completed_missions(id)) != World.TravelResult.ARRIVED:
				return _fail("Could not restore unrelated campaign fixture at " + node)
		if profile.record_world_waypoint(world) != OK:
			return _fail("Could not save unrelated campaign fixture.")
	return true


func _flow() -> bool:
	var human_harbor := World.new("mara").waypoint(HARBOR)
	var elven_harbor := World.new("ilyra").waypoint(HARBOR)
	if human_harbor.get("map_position") != elven_harbor.get("map_position") \
			or human_harbor.get("mission_id") == elven_harbor.get("mission_id"):
		return _fail("Shared Moonwash geography did not retain independent mission IDs.")
	if not _press("New Game") or not _press("ilyra") or not _on_map(CAMP):
		return _fail("Ilyra did not open in her own camp on the overworld.")
	if not _press("ConfirmTravel") or not _press("Read Dispatch") or not _is_dialogue(Beats.ILYRA_MOONWASH_DISPATCH):
		return _fail("Camp Operations did not present the authored rescue dispatch.")
	_read_dialogue()
	if not _press("Back") or not _on_map(CAMP):
		return _fail("Dispatch did not return through Camp Operations.")

	_map().select_waypoint(SHORE)
	_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not _map()._detail.text.contains("Hulls on Stone"):
		return _fail("Mara's same-harbor clear opened Ilyra's survey shore or hid the reason.")
	_map().select_waypoint(HARBOR)
	if not _on_map(CAMP) or not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Selecting moved the token before confirmation or arrival deployed automatically.")
	if not _press("Read Dispatch") or not _is_dialogue(Beats.ILYRA_MOONWASH_DISPATCH):
		return _fail("Ilyra's rescue briefing did not retain its authored dispatch.")
	_read_dialogue()
	if not _on_briefing():
		return _fail("Reading the dispatch bypassed deployment confirmation.")
	_joy(JOY_BUTTON_B)
	if not _on_map(HARBOR):
		return _fail("Cancel did not retain the arrived harbor.")
	_map().select_waypoint(SHORE)
	if not _map()._confirm_button.disabled or not _map()._detail.text.contains("Hulls on Stone"):
		return _fail("The attached onward route did not require Ilyra's real clear.")
	_map().select_waypoint(HARBOR)
	if not _press("ConfirmTravel") or not _on_briefing():
		return _fail("The arrived harbor could not reopen its own briefing.")
	if not _press("Confirm Deployment") or not _title._campaign_battle is Mission:
		return _fail("Confirmed deployment did not instantiate Ilyra's campaign rescue.")
	var arrived := FileAccess.get_file_as_string(_profile_path)
	_joy(JOY_BUTTON_BACK)
	if not _on_map(HARBOR) or FileAccess.get_file_as_string(_profile_path) != arrived:
		return _fail("An abandoned attempt wrote a clear, result or waypoint.")

	if not await _rescue(false):
		return false
	if not _is_dialogue(Beats.ILYRA_MOONWASH_CREWS_DEBRIEF):
		return _fail("Both real crew arrivals did not open the crews-only debrief.")
	var saved := Profile.new(_profile_path)
	if saved.ilyra_moonwash_clear_result() != Rescue.CREWS_ONLY 			or saved.completed_missions("ilyra") != PackedStringArray([CLEAR]) 			or saved.load_campaign_world("ilyra").current_waypoint_id() != HARBOR:
		return _fail("Crew result, clear and last position were not persisted before debrief.")
	_read_dialogue()
	if not _on_map(HARBOR):
		return _fail("Debrief did not return to the arrived harbor.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(HARBOR):
		return _fail("Continue did not restore Ilyra's cleared harbor.")

	var first_save := FileAccess.get_file_as_string(_profile_path)
	if not await _rescue(true):
		return false
	if not _is_dialogue(Beats.ILYRA_MOONWASH_CARGO_DEBRIEF):
		return _fail("Replay did not present the optional cargo debrief from this battle.")
	if FileAccess.get_file_as_string(_profile_path) != first_save 			or Profile.new(_profile_path).ilyra_moonwash_clear_result() != Rescue.CREWS_ONLY:
		return _fail("Replay rewrote the first clear or the original provision outcome.")
	_read_dialogue()
	_map().select_waypoint(SHORE)
	if not await _survey_flow() or not await _spanwater_flow():
		return false
	saved = Profile.new(_profile_path)
	for id: String in OTHER_SAVES:
		var itinerary: Array = OTHER_SAVES[id]
		if saved.completed_missions(id) != PackedStringArray(itinerary[0]) 				or saved.load_campaign_world(id).current_waypoint_id() != itinerary[1].back():
			return _fail("Ilyra's route overwrote " + id + "'s progress or position.")
	return (saved.grain_clear_result() == &"both" and saved.ilyra_moonwash_clear_result() == Rescue.CREWS_ONLY) \
		or _fail("Elven progress overwrote a first Moonwash or Human Grain outcome.")



func _survey_flow() -> bool:
	if not _press("ConfirmTravel") or not _on_briefing(SURVEY_CLEAR):
		return _fail("The real rescue clear did not open the Survey Shore briefing.")
	if not _press("Read Dispatch") or not _is_dialogue(Beats.ILYRA_COAST_SURVEY_DISPATCH):
		return _fail("The second mission did not present the authored survey dispatch.")
	_read_dialogue(5)
	if not _on_briefing(SURVEY_CLEAR) or not _press("Confirm Deployment"):
		return _fail("The survey dispatch bypassed deployment confirmation.")
	var survey := _title._campaign_battle as SurveyBattle
	if not survey or survey._field.name != &"MoonwashSurveyShore":
		return _fail("Confirmed deployment did not instantiate the survey battlefield.")
	_field_mission = survey
	survey.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _walk(STONE):
		return false
	_key(KEY_SPACE)
	_tick()
	if not survey.objective.has_reading(Survey.Reading.ANCESTRAL_STONE):
		return _fail("Abort fixture did not reach actual incomplete mission progress.")
	var before_abort := FileAccess.get_file_as_string(_profile_path)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await process_frame
	var back := _title._stage.get_node_or_null(^"ReturnToMap") as Button
	if not back or not survey._minimap.is_visible_in_tree() \
			or back.get_global_rect().intersects(survey._minimap_panel.get_global_rect()):
		return _fail("The passive map does not fit beside the campaign Return button in active command.")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = back.get_global_rect().get_center()
		click.pressed = pressed
		root.push_input(click, true)
	if not _on_map(SHORE) or FileAccess.get_file_as_string(_profile_path) != before_abort:
		return _fail("Aborting an incomplete survey wrote campaign progress.")
	_map().select_waypoint(SPANWATER)
	if not _map()._confirm_button.disabled or not _map()._detail.text.contains("Two Shorelines"):
		return _fail("An aborted survey opened Spanwater.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SHORE):
		return _fail("Continue did not resume at the reached, uncleared Survey Shore.")
	if not await _complete_survey(Survey.SignalSite.BEACH):
		return false
	if not _is_dialogue(Beats.ILYRA_COAST_SURVEY_BEACH_DEBRIEF):
		return _fail("Actual beach completion did not branch to the beach debrief.")
	var saved := Profile.new(_profile_path)
	if saved.completed_missions("ilyra") != PackedStringArray([CLEAR, SURVEY_CLEAR]) \
			or saved.load_campaign_world("ilyra").current_waypoint_id() != SHORE:
		return _fail("A real cutter acknowledgment did not persist the second clear and reached waypoint.")
	_read_dialogue(4)
	if not _on_map(SHORE):
		return _fail("Beach debrief lost the reached Survey Shore.")
	var first_survey_save := FileAccess.get_file_as_string(_profile_path)
	if not await _complete_survey(Survey.SignalSite.HEADLAND):
		return false
	if not _is_dialogue(Beats.ILYRA_COAST_SURVEY_HEADLAND_DEBRIEF) \
			or FileAccess.get_file_as_string(_profile_path) != first_survey_save:
		return _fail("Headland replay selected the wrong debrief or mutated saved outcomes.")
	_read_dialogue(5)
	return _on_map(SHORE) or _fail("The headland debrief did not return to the Survey Shore.")


func _spanwater_flow() -> bool:
	if not _map().select_waypoint(SPANWATER) or not _press("ConfirmTravel") or not _on_briefing(EVACUATION):
		return _fail("The genuine survey victory did not open the Elven Spanwater briefing.")
	var prior := PackedStringArray([CLEAR, SURVEY_CLEAR])
	var profile := Profile.new(_profile_path)
	if profile.completed_missions("ilyra") != prior or profile.load_campaign_world("ilyra").current_waypoint_id() != SPANWATER:
		return _fail("Arriving at the Elven landing wrote a clear or did not save the reached waypoint.")
	_joy(JOY_BUTTON_B)
	if not _on_map(SPANWATER):
		return _fail("Back did not retain the reached Spanwater waypoint.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SPANWATER) or not _press("ConfirmTravel") \
			or not _on_briefing(EVACUATION) or not _press("Read Dispatch") or not _is_dialogue(Beats.ILYRA_SPANWATER_DISPATCH):
		return _fail("Continue or the route failed to expose Ilyra's own briefing and dispatch.")
	_read_dialogue(Beats.get_beat(Beats.ILYRA_SPANWATER_DISPATCH).lines.size())
	if not _on_briefing(EVACUATION) or not _press("Confirm Deployment"):
		return _fail("Reading the dispatch did not return to explicit deployment.")
	var arrived := FileAccess.get_file_as_string(_profile_path)
	var evacuation := _title._campaign_battle as Evacuation
	if not await _mount_evacuation(evacuation):
		return false
	if not _call_party(BoatRescue.Group.NEAR):
		return false
	if evacuation.objective.group_status(BoatRescue.Group.NEAR) != BoatRescue.GroupStatus.APPROACHING:
		return _fail("The abort fixture never physically called the near households.")
	_joy(JOY_BUTTON_BACK)
	if not _on_map(SPANWATER) or FileAccess.get_file_as_string(_profile_path) != arrived:
		return _fail("Aborting a partial evacuation wrote a save.")
	if not _press("ConfirmTravel") or not _on_briefing(EVACUATION) or not _press("Confirm Deployment"):
		return _fail("A partial attempt prevented redeployment.")
	evacuation = _title._campaign_battle as Evacuation
	if not await _mount_evacuation(evacuation):
		return false
	if not _wait(func() -> bool: return evacuation.objective.outcome == BoatRescue.Outcome.FAILED, 6800):
		return false
	if evacuation.objective.failure != BoatRescue.Failure.LANDING_CLOSED \
			or _title._page != Title.Page.CAMPAIGN_BATTLE or FileAccess.get_file_as_string(_profile_path) != arrived:
		return _fail("A real loss to rising stairs changed the save or advanced the campaign.")
	_key(KEY_BACKSPACE)
	if evacuation.objective.landing_closed or evacuation.objective.outcome != BoatRescue.Outcome.ACTIVE \
			or evacuation.objective.group_status(BoatRescue.Group.FAR) != BoatRescue.GroupStatus.SHELTERED:
		return _fail("Retry did not restore launch and household starting states.")
	if not await _finish_evacuation(evacuation, BoatRescue.Group.FAR, true, arrived):
		return false
	profile = Profile.new(_profile_path)
	var complete := PackedStringArray([CLEAR, SURVEY_CLEAR, EVACUATION])
	if profile.completed_missions("ilyra") != complete or profile.ilyra_moonwash_clear_result() != Rescue.CREWS_ONLY \
			or not _is_dialogue(Beats.ILYRA_SPANWATER_DEBRIEF):
		return _fail("Both verified exits did not save the campaign and open its actual ending.")
	_read_dialogue(Beats.get_beat(Beats.ILYRA_SPANWATER_DEBRIEF).lines.size())
	if not _on_map(SPANWATER) or _map()._heading.text != "Campaign Complete":
		return _fail("The ending did not return to the completed map.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SPANWATER) or _map()._heading.text != "Campaign Complete" \
			or not _press("ConfirmTravel") or not _on_briefing(EVACUATION) or not _press("Confirm Deployment"):
		return _fail("Continue did not restore completion or permit a fresh finale replay.")
	var victory_save := FileAccess.get_file_as_string(_profile_path)
	evacuation = _title._campaign_battle as Evacuation
	if not await _mount_evacuation(evacuation) \
			or not await _finish_evacuation(evacuation, BoatRescue.Group.NEAR, false, victory_save):
		return false
	if not _is_dialogue(Beats.ILYRA_SPANWATER_DEBRIEF) or FileAccess.get_file_as_string(_profile_path) != victory_save:
		return _fail("The other boarding order changed the ending or rewrote the completed save.")
	_read_dialogue(Beats.get_beat(Beats.ILYRA_SPANWATER_DEBRIEF).lines.size())
	return (_on_map(SPANWATER) and _map()._heading.text == "Campaign Complete") \
		or _fail("Replay did not return to the completed Spanwater map.")


func _mount_evacuation(evacuation: Evacuation) -> bool:
	if not evacuation or evacuation._field.name != &"SpanwaterLockCampaign" \
			or evacuation.objective.group_status(BoatRescue.Group.NEAR) != BoatRescue.GroupStatus.SHELTERED \
			or evacuation.objective.group_status(BoatRescue.Group.FAR) != BoatRescue.GroupStatus.SHELTERED:
		return _fail("The confirmed finale did not deploy a fresh Elven Spanwater scene.")
	var prototype := evacuation.get_node_or_null("ObjectiveHUD/Panel/Margin/Readout/Prototype") as Label
	if not prototype or not prototype.is_visible_in_tree() or not prototype.text.contains("DEVELOPMENT PLAYTEST"):
		return _fail("The finale did not visibly retain its development-only visual label.")
	_field_mission = evacuation
	evacuation.set_physics_process(false)
	await physics_frame
	await physics_frame
	return true


func _call_party(group: BoatRescue.Group) -> bool:
	var far := group == BoatRescue.Group.FAR
	var path := ["Routes/LandingApproach", "Spawns/HouseholdsNear", "Routes/HouseholdScreenTurn", "Spawns/HouseholdsFar"] \
		if far else ["Routes/LandingApproach", "Spawns/HouseholdsNear"]
	if not _walk(path):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	return true


func _finish_evacuation(evacuation: Evacuation, first: BoatRescue.Group, through_closure: bool, save_before: String) -> bool:
	var objective := evacuation.objective
	if not _place_detachment(["Routes/LandingApproach"]) or not _call_party(first):
		return false
	if not _wait(func() -> bool: return objective.passenger_group(BoatRescue.Launch.FIRST) == first, 3600):
		return _fail("The initially called group did not physically board at the single berth.")
	var second := BoatRescue.Group.NEAR if first == BoatRescue.Group.FAR else BoatRescue.Group.FAR
	var next_path := ["Routes/HouseholdScreenTurn", "Spawns/HouseholdsNear"] if second == BoatRescue.Group.NEAR \
		else ["Routes/HouseholdScreenTurn", "Spawns/HouseholdsFar"]
	if not _walk(next_path):
		return false
	if through_closure:
		var closure_time := Evacuation.RELEASE_AT + (evacuation._landing.x - evacuation._sweep_start.x) / Evacuation.RIVER_SPEED \
			+ Evacuation.CLOSED_HEIGHT / Evacuation.RISE_SPEED
		if not _wait(func() -> bool: return evacuation._elapsed >= closure_time - 17.0, 2300):
			return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _wait(func() -> bool: return objective.group_status(first) == BoatRescue.GroupStatus.SAFE, 2500):
		return false
	if evacuation._boats[0].view.position != evacuation._boat_exit or objective.outcome != BoatRescue.Outcome.ACTIVE \
			or FileAccess.get_file_as_string(_profile_path) != save_before or _title._victory_pending:
		return _fail("The physical first exit incorrectly cleared both household groups.")
	if through_closure:
		if not _wait(func() -> bool: return objective.landing_closed, 2900):
			return false
		if objective.group_status(second) != BoatRescue.GroupStatus.ABOARD or not evacuation._stairs_water.visible \
				or FileAccess.get_file_as_string(_profile_path) != save_before:
			return _fail("The real closure did not leave an in-transit launch aboard without awarding its clear.")
	if not _wait(func() -> bool: return objective.outcome == BoatRescue.Outcome.SUCCEEDED, 3300):
		return false
	if objective.group_status(second) != BoatRescue.GroupStatus.SAFE or evacuation._boats[1].view.position != evacuation._boat_exit:
		return _fail("The game cleared before the second loaded launch reached the physical exit.")
	await process_frame
	return true


func _complete_survey(site: Survey.SignalSite) -> bool:
	if not _press("ConfirmTravel") or not _on_briefing(SURVEY_CLEAR) or not _press("Confirm Deployment"):
		return _fail("Could not reopen and confirm a fresh survey deployment.")
	var survey := _title._campaign_battle as SurveyBattle
	if not survey or survey.objective.phase != Survey.Phase.TAKING_READINGS \
			or survey.objective.has_reading(Survey.Reading.ANCESTRAL_STONE):
		return _fail("A fresh deployment inherited previous chart progress.")
	_field_mission = survey
	survey.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _walk(STONE):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _walk(INLET):
		return false
	_key(KEY_SPACE)
	_tick()
	var beach := site == Survey.SignalSite.BEACH
	var detachment_path := INLAND + (["Routes/InletFork", "Routes/InletBacktrack", "Routes/BeachGuard"] \
		if beach else ["Routes/HeadlandRoadFork"] + RAMP)
	if not _place_detachment(detachment_path):
		return false
	var hero_path := ["Routes/InletBeachTurn", "Objectives/BeachSignal"] if beach \
		else ["Routes/InletBacktrack", "Routes/HeadlandInlandCut"] + RAMP + ["Objectives/HeadlandSignal"]
	if not _walk(hero_path):
		return false
	if not _wait(func() -> bool: return survey._holding_site == site, 4800):
		return false
	# Use a full dwell rather than assuming the held cutter has just arrived.
	if survey._dwell_left <= SurveyBattle.SIGNAL_SECONDS + 0.1:
		if not _wait(func() -> bool: return survey._holding_site != site, 900) \
				or not _wait(func() -> bool: return survey._holding_site == site, 4800):
			return false
	_joy(JOY_BUTTON_A)
	if not _wait(func() -> bool: return survey.objective.phase == Survey.Phase.SUCCEEDED):
		return false
	if survey.objective.signal_site != site:
		return _fail("Result did not come from the attempted physical relay.")
	await process_frame
	return true


func _place_detachment(path: Array) -> bool:
	var detachment: Battle.Formation = _field_mission.battle.formations[0]
	for segment: String in path:
		var waypoint := _local_xz(_point(segment))
		_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
		_field_mission.cursor = waypoint
		_joy(JOY_BUTTON_X)
		_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
		if detachment.order != Battle.Order.MOVE or not _wait(func() -> bool: return detachment.position == waypoint):
			return _fail("Detachment did not physically reach " + segment)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_A)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return detachment.order == Battle.Order.HOLD or _fail("The command Hold did not secure the relay.")


func _rescue(with_cargo: bool) -> bool:
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("Could not reopen and deploy the rescue.")
	_mission = _title._campaign_battle as Mission
	if not _mission or _mission._field.name != &"MoonwashHarborCampaign" 			or _mission.battle.bounds.size != Vector2(288, 242):
		return _fail("Deployment did not use Ilyra's campaign-scale shared harbor.")
	_field_mission = _mission
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if with_cargo:
		if not _walk(PIER + ["Objectives/OptionalCargo"]):
			return false
		_key(KEY_SPACE)
		_tick()
		var return_pier := PIER.duplicate()
		return_pier.reverse()
		if not _mission._cargo_carried or _mission.objective.cargo_recovered 				or not _walk(return_pier + ["Objectives/ReceivingDeck"]):
			return _fail("Optional cargo could not be physically collected and carried aboard.")
		_joy(JOY_BUTTON_A)
		_tick()
		if not _mission.objective.cargo_recovered or not _walk(["Routes/ReceivingGangway"]):
			return _fail("Cargo was not loaded aboard the receiving deck.")
	if not _walk(PIER + STRANDED + ["Objectives/AftTransfer"]):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _walk(["Objectives/ForwardTransfer"]):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _wait(func() -> bool: return _mission.objective.crew_status(Rescue.Transfer.FORWARD) == Rescue.CrewStatus.PAUSED):
		return false
	var marines: Battle.Formation = _mission.battle.formations[Mission.MARINES]
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_mission.cursor = _local_xz(_point("Routes/OpenMooring"))
	_joy(JOY_BUTTON_X)
	if marines.order != Battle.Order.MOVE or not _wait(func() -> bool:
			return marines.position.distance_to(_mission.cursor) < Mission.SCREEN_RADIUS - 0.4):
		return _fail("Marines did not physically reach the contested mooring.")
	_joy(JOY_BUTTON_A)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _wait(func() -> bool: return _mission.objective.outcome == Rescue.Outcome.SUCCEEDED):
		return false
	if _mission._crews[Rescue.Transfer.FORWARD].global_position != _point("Objectives/ForwardReceiver") 			or _mission._crews[Rescue.Transfer.AFT].global_position != _point("Objectives/AftReceiver"):
		return _fail("The victory signal did not come from both actual deck arrivals.")
	await process_frame
	return true


func _walk(path: Array) -> bool:
	for segment: String in path:
		var point := _point(segment)
		var target := _local_xz(point)
		var budget := ceili(target.distance_to(_field_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 120
		for _step in range(budget):
			var remaining := target - _field_mission.battle.hero_position
			if remaining.length() < 0.12:
				break
			var move := remaining.normalized().rotated(_field_mission._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, move.x)
			_axis(JOY_AXIS_LEFT_Y, move.y)
			_tick()
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		if _field_mission.hero_world_position().distance_to(point) >= 0.14:
			return _fail("Could not physically walk to " + segment)
	return true


func _wait(condition: Callable, budget := 1900) -> bool:
	for _step in range(budget):
		if condition.call():
			return true
		_tick()
	return _fail("Expected campaign battlefield event did not occur.")


func _local_xz(point: Vector3) -> Vector2:
	var local := _field_mission.to_local(point)
	return Vector2(local.x, local.z)


func _point(path: String) -> Vector3:
	return _field_mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _tick() -> void:
	_field_mission._physics_process(DT)


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null 		and _title._campaign_world.campaign_id() == "ilyra" and _title._campaign_world.current_waypoint_id() == id


func _on_briefing(mission_id := CLEAR) -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null 		and _title._campaign_world.mission_at_current_waypoint() == mission_id


func _is_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	return dialogue != null and dialogue._active and dialogue._beat_id == id


func _read_dialogue(lines := 4) -> void:
	for _line in range(lines):
		_key(KEY_ENTER)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
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
