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
const CAMP := "moonwash_camp"
const HARBOR := "moonwash_harbor"
const SHORE := "moonwash_survey_shore"
const CLEAR := "ilyra_moonwash_rescue"
const DT := 1.0 / 60.0
const PIER := ["Routes/ReceivingGangway", "Routes/PierOuterTurn", "Routes/PierInnerTurn", "Routes/OpenMooring"]
const STRANDED := ["Routes/StrandedAccess", "Routes/StrandedDeckGangway"]
const OTHER_SAVES := {
	"mara": [["mara_mine_escort", "mara_grain_crossing", "mara_moonwash_quay"],
		["year_one_mine", "marches_road", "marches_crossing", "moonwash_road", HARBOR]],
	"raska": [["orc_mine_witness"], ["year_one_mine", "basin_well_road"]],
	"sova": [["sova_mine_tunnels"], ["year_one_mine", "cairnspine_assembly"]],
}

var _title: Title
var _mission: Mission
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
		print("Ilyra campaign: Moonwash dispatch, map/briefing, physical rescue, optional replay, isolated first result and survey shore Continue passed.")
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
	if not _press("ConfirmTravel") or _title._campaign_world.current_waypoint_id() != SHORE \
			or _title._campaign_world.mission_at_current_waypoint() != "ilyra_coast_survey":
		return _fail("Actual clear did not open the survey shore and its survey mission.")
	if _title._page == Title.Page.MISSION_BRIEFING:
		_joy(JOY_BUTTON_B)
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SHORE):
		return _fail("Continue did not restore the reached survey shore.")
	saved = Profile.new(_profile_path)
	for id: String in OTHER_SAVES:
		var itinerary: Array = OTHER_SAVES[id]
		if saved.completed_missions(id) != PackedStringArray(itinerary[0]) 				or saved.load_campaign_world(id).current_waypoint_id() != itinerary[1].back():
			return _fail("Ilyra's route overwrote " + id + "'s progress or position.")
	return saved.grain_clear_result() == &"both" or _fail("Ilyra's result overwrote the Human Grain outcome.")


func _rescue(with_cargo: bool) -> bool:
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("Could not reopen and deploy the rescue.")
	_mission = _title._campaign_battle as Mission
	if not _mission or _mission._field.name != &"MoonwashHarborCampaign" 			or _mission.battle.bounds.size != Vector2(288, 242):
		return _fail("Deployment did not use Ilyra's campaign-scale shared harbor.")
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
		var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 120
		for _step in range(budget):
			var remaining := target - _mission.battle.hero_position
			if remaining.length() < 0.12:
				break
			var move := remaining.normalized().rotated(_mission._hero_yaw)
			_axis(JOY_AXIS_LEFT_X, move.x)
			_axis(JOY_AXIS_LEFT_Y, move.y)
			_tick()
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		if _mission.hero_world_position().distance_to(point) >= 0.14:
			return _fail("Could not physically walk to " + segment)
	return true


func _wait(condition: Callable) -> bool:
	for _step in range(1900):
		if condition.call():
			return true
		_tick()
	return _fail("Expected rescue event did not occur.")


func _local_xz(point: Vector3) -> Vector2:
	var local := _mission.to_local(point)
	return Vector2(local.x, local.z)


func _point(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _tick() -> void:
	_mission._physics_process(DT)


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null 		and _title._campaign_world.campaign_id() == "ilyra" and _title._campaign_world.current_waypoint_id() == id


func _on_briefing() -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null 		and _title._campaign_world.mission_at_current_waypoint() == CLEAR


func _is_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	return dialogue != null and dialogue._active and dialogue._beat_id == id


func _read_dialogue() -> void:
	for _line in range(4):
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
