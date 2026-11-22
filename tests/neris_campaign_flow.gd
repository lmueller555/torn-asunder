extends SceneTree

const CampaignFlow := preload("res://tests/campaign_flow_helpers.gd")
const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/neris_failing_grove_playtest.gd")
const Grove := preload("res://game/battlefield/neris_failing_grove.gd")
const Survey := preload("res://game/battlefield/neris_cairnspine_survey.gd")
const Finale := preload("res://game/battlefield/neris_greyhollow_campaign.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const CAMP := "grove_camp"
const NURSERY := "isolated_grove_nursery"
const SPANWATER := "spanwater_lock"
const CAIRNSPINE := "cairnspine_boundary_post"
const MINE := "year_one_mine"
const CLEAR := "neris_failing_grove"
const SURVEY_CLEAR := "neris_cairnspine_survey"
const FINALE_CLEAR := "neris_greyhollow"
const LEGACY := ["neris_spanwater_feeder", "neris_cairnspine_passage"]
const DT := 1.0 / 60.0

var _title: Title
var _mission: Mission
var _path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-neris-flow-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_path)
	var raska_clears := PackedStringArray(["orc_mine_witness", "orc_well_road", "orc_spanwater_release"])
	var saved := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", true) == OK
	for id in raska_clears:
		saved = profile.record_mission_clear("raska", id) == OK and saved
	var world := profile.load_campaign_world("raska")
	for waypoint in ["year_one_mine", "basin_well_road", SPANWATER]:
		world.travel_to(waypoint, raska_clears)
	saved = saved and world.current_waypoint_id() == SPANWATER and profile.record_world_waypoint(world) == OK
	# A pre-retime profile can still contain both old clears and the removed
	# vault-road waypoint. Read it as-is: it cannot unlock the boundary post
	# or mine and it must not count as having completed the new campaign.
	for id: String in LEGACY:
		saved = profile.record_mission_clear("neris", id) == OK and saved
	var old := ConfigFile.new()
	saved = saved and old.load(_path) == OK
	old.set_value(Profile.CAMPAIGN_WAYPOINTS, "neris", "cairnspine_vault_road")
	saved = saved and old.save(_path) == OK
	profile = Profile.new(_path)
	saved = saved and profile.load_campaign_world("neris").current_waypoint_id() == CAMP
	_title = TitleScene.instantiate()
	_title._profile = profile
	root.add_child(_title)
	var passed := saved and await _exercise()
	if passed:
		profile = Profile.new(_path)
		passed = (profile.completed_missions("raska") == raska_clears \
			and profile.load_campaign_world("raska").current_waypoint_id() == SPANWATER \
			and profile.completed_missions("sova").is_empty() \
			and profile.completed_missions("ilyra").is_empty() \
			and profile.completed_missions("neris") == _neris_clears([CLEAR, SURVEY_CLEAR, FINALE_CLEAR]) \
			and profile.load_campaign_world("neris").current_waypoint_id() == MINE) \
			or _fail("Campaign progression or shared Spanwater position was not isolated.")
	_title.queue_free()
	await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Neris campaign: real transplant, two physical clues, failed interdiction and screened withdrawal, debriefs, retry/Continue, and legacy-save isolation passed.")
	quit(0 if passed else 1)


func _exercise() -> bool:
	CampaignFlow.resume_at_map(_title, "neris")
	if not _on_map(CAMP):
		return _fail("Neris did not open her own Grove Camp map.")
	_map().select_waypoint(NURSERY)
	if not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Arrival at the grove did not stop at the correct briefing.")
	_joy(JOY_BUTTON_B)
	if not _on_map(NURSERY) or not _map().select_waypoint(CAIRNSPINE) \
			or not _button("ConfirmTravel").disabled or not _map()._detail.text.contains("What We Planted Here"):
		return _fail("An old or foreign clear or merely arriving at the Grove unlocked the boundary post.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(NURSERY) or not _press("ConfirmTravel") \
			or not _on_briefing() or not _press("Read Dispatch") \
			or not _read_dialogue(Beats.NERIS_FAILING_GROVE_DISPATCH) or not _on_briefing():
		return _fail("Continue or the dispatch bypassed Neris's explicit deployment.")
	var at_grove := FileAccess.get_file_as_string(_path)
	if not _press("Confirm Deployment") or not PauseTest.leave_battle(_title) or not _on_map(NURSERY) \
			or FileAccess.get_file_as_string(_path) != at_grove or not _press("ConfirmTravel") \
			or not _press("Confirm Deployment"):
		return _fail("Aborting a deployment changed progress or prevented redeployment.")
	_mission = _title._campaign_battle as Mission
	if not _mission or _mission._field.name != &"IsolatedGroveNursery":
		return _fail("The briefing did not launch the real nursery battlefield.")
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	# This playtest accepts a definitive defeat report, but its patrol is not a damage model.
	_mission.report_sled_destroyed()
	_tick()
	if _mission.objective.failure != Grove.Failure.SLED_DESTROYED or _title._page != Title.Page.CAMPAIGN_BATTLE \
			or FileAccess.get_file_as_string(_path) != at_grove:
		return _fail("Defeat fabricated progression or left the campaign battle.")
	_key(KEY_BACKSPACE)
	if _mission.objective.phase != Grove.Phase.AWAITING_ENVOY or FileAccess.get_file_as_string(_path) != at_grove:
		return _fail("Retry did not reset the scene without touching the save.")
	if not _transplant(at_grove):
		return false
	await process_frame
	if Profile.new(_path).completed_missions("neris") != _neris_clears([CLEAR]) \
			or not _read_dialogue(Beats.NERIS_FAILING_GROVE_DEBRIEF) or not _on_map(NURSERY):
		return _fail("The physical transplant did not save the clear and show the authored debrief.")
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("The completed grove could not be replayed.")
	var replay := _title._campaign_battle as Mission
	if not replay or replay.objective.phase != Grove.Phase.AWAITING_ENVOY or not PauseTest.leave_battle(_title):
		return _fail("The completed grove replay did not begin with a fresh objective.")
	return await _run_survey()


func _run_survey() -> bool:
	if not _map().select_waypoint(CAIRNSPINE) or not _press("ConfirmTravel") or not _on_briefing(SURVEY_CLEAR):
		return _fail("The Grove clear did not open the Year Two survey.")
	_joy(JOY_BUTTON_B)
	if not _on_map(CAIRNSPINE) or not _map().select_waypoint(MINE) or not _button("ConfirmTravel").disabled \
			or _map()._heading.text == "Campaign Complete":
		return _fail("An old clear or arriving at the post unlocked Greyhollow/completed the campaign.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(CAIRNSPINE) or not _press("ConfirmTravel") \
			or not _on_briefing(SURVEY_CLEAR) or not _press("Read Dispatch") \
			or not _read_dialogue(Beats.NERIS_SURVEY_DISPATCH) or not _on_briefing(SURVEY_CLEAR):
		return _fail("Continue or the dispatch skipped the explicit survey deployment.")
	var at_post := FileAccess.get_file_as_string(_path)
	if not _press("Confirm Deployment"):
		return false
	var survey := _title._campaign_battle as Survey
	if not survey or survey._field.scene_file_path != "res://game/battlefields/cairnspine_boundary_post.tscn":
		return _fail("The Year Two briefing did not open the real Cairnspine boundary terrain.")
	survey.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _read_ruts(survey, at_post):
		return false
	_key(KEY_BACKSPACE)
	if survey.stage != Survey.Stage.TRACK or not _read_ruts(survey, at_post):
		return _fail("Restart did not reset local survey evidence before the second attempt.")
	for marker in ["CoveredTrackHold", "EastRampBottom", "EastRampTop", "EastTrackLanding",
			"TrackEmergence", "TrackWallCorner", "PostTrackTurn"]:
		if not _walk("Routes/" + marker, survey):
			return false
	if not _walk("Objectives/WritHandover", survey) or not _wait_for_watch(survey):
		return false
	_joy(JOY_BUTTON_A)
	_tick(survey)
	if survey.stage != Survey.Stage.EXIT or not _save_unchanged(at_post):
		return _fail("The Greyhollow slate itself wrote a clear without reaching the report point.")
	for marker in ["PostDoorway", "PostRoadApproach", "PostEastTurn", "EastMarchEdge"]:
		if not _walk("Routes/" + marker, survey):
			return false
	if not _wait_for_watch(survey):
		return false
	_key(KEY_SPACE)
	_tick(survey)
	if survey.stage != Survey.Stage.CLEARED:
		return _fail("Reporting both real clues from the turn-off did not clear the survey.")
	await process_frame
	if Profile.new(_path).completed_missions("neris") != _neris_clears([CLEAR, SURVEY_CLEAR]) \
			or not _read_dialogue(Beats.NERIS_SURVEY_DEBRIEF) or not _on_map(CAIRNSPINE):
		return _fail("Survey completion missed the debrief or changed the campaign location.")
	return await _run_finale()


func _read_ruts(survey: Survey, at_post: String) -> bool:
	if not _walk("Routes/SheepTrackBend", survey) or not _walk("Routes/SheepPinch", survey):
		return false
	_joy(JOY_BUTTON_A)
	_tick(survey)
	return (survey.stage == Survey.Stage.POST and _save_unchanged(at_post)) \
		or _fail("The trench clue was not recorded separately from the posted freight slate.")


func _wait_for_watch(survey: Survey) -> bool:
	return _wait(func() -> bool:
		return survey.stage < Survey.Stage.CLEARED and not survey._watch_has_sight(survey.hero_world_position()),
		180, survey
	) or _fail("The survey watch did not leave an opening at this route point.")


func _run_finale() -> bool:
	if not _map().select_waypoint(MINE) or not _press("ConfirmTravel") or not _on_briefing(FINALE_CLEAR) \
			or not _press("Read Dispatch") or not _read_dialogue(Beats.NERIS_GREYHOLLOW_DISPATCH) \
			or not _on_briefing(FINALE_CLEAR):
		return _fail("The actual survey did not unlock the Year Three Greyhollow dispatch.")
	var at_mine := FileAccess.get_file_as_string(_path)
	if not _press("Confirm Deployment") or not _title._campaign_battle is Finale \
			or not PauseTest.leave_battle(_title) or not _on_map(MINE) or not _save_unchanged(at_mine) \
			or _map()._heading.text == "Campaign Complete" or not _press("ConfirmTravel") \
			or not _on_briefing(FINALE_CLEAR) or not _press("Confirm Deployment"):
		return _fail("An abandoned strike wrote a clear or prevented legitimate redeployment.")
	var finale := _title._campaign_battle as Finale
	if not finale or finale._field.scene_file_path != "res://game/battlefields/year_one_mine_campaign.tscn":
		return _fail("The Year Three briefing did not open the shared Greyhollow mine terrain.")
	finale.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _order(finale, Finale.STRIKE, finale._press) \
			or not _wait(func() -> bool: return finale.phase == Finale.Phase.FAILED, 4800, finale) \
			or _title._page != Title.Page.CAMPAIGN_BATTLE or not _save_unchanged(at_mine):
		return _fail("Leaving the Strike Party exposed did not fail in place without a clear.")
	_key(KEY_BACKSPACE)
	if finale.phase != Finale.Phase.APPROACH or finale.miners_beyond_reach or not _save_unchanged(at_mine):
		return _fail("The finale could not be retried from before the contact.")
	if not _withdraw(finale, at_mine):
		return false
	await process_frame
	var profile := Profile.new(_path)
	if profile.completed_missions("neris") != _neris_clears([CLEAR, SURVEY_CLEAR, FINALE_CLEAR]) \
			or profile.load_campaign_world("neris").current_waypoint_id() != MINE \
			or not _read_dialogue(Beats.NERIS_GREYHOLLOW_DEBRIEF) \
			or not _on_map(MINE) or _map()._heading.text != "Campaign Complete":
		return _fail("Surviving the withdrawal did not save the finale and show its debrief at Greyhollow.")
	var completed := FileAccess.get_file_as_string(_path)
	if not _press("ConfirmTravel") or not _on_briefing(FINALE_CLEAR) or not _press("Confirm Deployment"):
		return _fail("The completed finale could not be replayed.")
	var replay := _title._campaign_battle as Finale
	if not replay or replay.phase != Finale.Phase.APPROACH or replay.miners_beyond_reach \
			or not PauseTest.leave_battle(_title) or not _on_map(MINE) or not _save_unchanged(completed):
		return _fail("Replaying the finale did not start fresh or changed the completed save.")
	_joy(JOY_BUTTON_B)
	return (_press("Continue") and _on_map(MINE) \
		and _map()._heading.text == "Campaign Complete") or _fail("Continue did not restore the completed route at Greyhollow.")


func _withdraw(finale: Finale, at_mine: String) -> bool:
	if not _order(finale, Finale.SCREEN_PARTY, Finale.COVER) \
			or not _wait(func() -> bool:
				return finale.battle.formations[Finale.SCREEN_PARTY].order == Battle.Order.HOLD, 240, finale):
		return _fail("The Screen Party could not reach its actual hold point.")
	if not _order(finale, Finale.STRIKE, finale._press) \
			or not _wait(func() -> bool: return finale.phase == Finale.Phase.CONTACT, 1200, finale) \
			or finale.miners_beyond_reach:
		return _fail("The Strike Party did not try to interdict the Humans before their breakout.")
	if not _order(finale, Battle.LEAD_INDEX, Finale.FALLBACK) \
			or not _wait(func() -> bool: return finale.phase == Finale.Phase.SCREEN, 1800, finale) \
			or not finale.miners_beyond_reach or not _save_unchanged(at_mine):
		return _fail("The Human breakout failed to happen independently, or itself wrote a Dryad clear.")
	if not _order(finale, Finale.STRIKE, Finale.STRIKE_TURN) \
			or not _wait(func() -> bool:
				var strike := finale.battle.formations[Finale.STRIKE]
				return strike.order == Battle.Order.HOLD and strike.position.distance_to(Finale.STRIKE_TURN) < 0.3,
				1000, finale):
		return _fail("The Strike Party could not physically reach the authored turn.")
	if not _order(finale, Finale.STRIKE, Finale.FALLBACK) \
			or not _wait(func() -> bool: return finale.phase == Finale.Phase.RETREAT, 1500, finale) \
			or finale.battle.lead.order != Battle.Order.EXTRACTED or not _save_unchanged(at_mine):
		return _fail("Neris and the Strike Party could not withdraw under the screen without a premature clear.")
	if not _order(finale, Finale.SCREEN_PARTY, Finale.FALLBACK) \
			or not _wait(func() -> bool: return finale.phase == Finale.Phase.SUCCEEDED, 1200, finale) \
			or not finale.miners_beyond_reach:
		return _fail("The actual Screen Party withdrawal did not finish independently of the Humans.")
	return true


func _order(finale: Finale, group: int, point: Vector2) -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var steps := group - finale.selected_index
	for i in absi(steps):
		_joy(JOY_BUTTON_DPAD_RIGHT if steps > 0 else JOY_BUTTON_DPAD_LEFT)
	var order := InputEventMouseButton.new()
	order.position = root.get_camera_3d().unproject_position(finale.to_global(finale._ground(point)))
	order.pressed = true
	order.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(order, true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var formation := finale.battle.formation_at(group)
	return (formation.order == Battle.Order.MOVE and formation.destination.distance_to(point) < 0.3) \
		or _fail("Real tactical input did not order %s to %s (order %d, destination %s)." % [
			formation.title, point, formation.order, formation.destination])


func _save_unchanged(snapshot: String) -> bool:
	return not _title._victory_pending and FileAccess.get_file_as_string(_path) == snapshot


func _neris_clears(new_missions: Array) -> PackedStringArray:
	return PackedStringArray(LEGACY + new_missions)


func _transplant(at_grove: String) -> bool:
	for waypoint in ["Routes/GroveAssembly", "Objectives/GroveEnvoy"]:
		if not _walk(waypoint):
			return false
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.phase != Grove.Phase.AWAITING_VOLUNTEERS or not _walk("Objectives/VolunteerCall"):
		return _fail("Neris did not physically get the envoy's approval before calling help.")
	_joy(JOY_BUTTON_A)
	_tick()
	if not _wait(func() -> bool: return _mission.objective.interruption == Grove.Interruption.YARD_CONTESTED, 950):
		return _fail("No actual patrol contested the loading yard.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_RIGHT_STICK)
	_joy(JOY_BUTTON_DPAD_RIGHT)
	var screen := _mission.battle.formations[1]
	var pointer := root.get_camera_3d().unproject_position(_marker("Routes/LoadingScreenHold"))
	var order := InputEventMouseButton.new()
	order.position = pointer
	order.pressed = true
	order.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(order, true)
	if not _wait(func() -> bool: return screen.order == Battle.Order.HOLD, 650):
		return _fail("The patrol screen did not take the real projected formation order.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _wait(func() -> bool: return _mission.objective.phase == Grove.Phase.AWAITING_TRANSPLANT, 4400):
		return _fail("The sled never physically reached the nursery after recovering the yard.")
	if FileAccess.get_file_as_string(_path) != at_grove or _title._victory_pending:
		return _fail("Sled arrival without the actual transplant wrote a clear.")
	for waypoint in Mission.SLED_ROUTE:
		if not _walk(waypoint):
			return false
	_joy(JOY_BUTTON_A)
	_tick()
	return _mission.objective.phase == Grove.Phase.SUCCEEDED or _fail("The actual nursery interaction did not plant the tree.")


func _marker(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _walk(path: String, battlefield: Harness = null) -> bool:
	var active := battlefield if battlefield else _mission
	var point := active.battlefield_marker(NodePath("Markers/" + path))
	var target := active._marker_position(point)
	var budget := ceili(active.battle.hero_position.distance_to(target) / Battle.LEAD_SPEED / DT) + 65
	for _step in range(budget):
		var offset := target - active.battle.hero_position
		if offset.length() <= 0.18:
			break
		var aim := offset.normalized().rotated(active._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y), active)
		_tick(active)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return active.battle.hero_position.distance_to(target) <= 0.18 or _fail("Neris did not reach " + path)


func _wait(check: Callable, steps: int, battlefield: Harness = null) -> bool:
	for _step in range(steps):
		if check.call():
			return true
		_tick(battlefield)
	return check.call()


func _tick(battlefield: Harness = null) -> void:
	var active := battlefield if battlefield else _mission
	active._physics_process(DT)


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(point: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null \
		and _title._campaign_world.campaign_id() == "neris" and _title._campaign_world.current_waypoint_id() == point


func _on_briefing(mission_id := CLEAR) -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null \
		and _title._campaign_world.mission_at_current_waypoint() == mission_id


func _read_dialogue(id: StringName) -> bool:
	var panel := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not panel or not panel._active or panel._beat_id != id:
		return false
	for _line in Beats.get_beat(id).lines:
		_key(KEY_ENTER)
	return _title._page != Title.Page.CAMPAIGN_DIALOGUE


func _button(id: String) -> Button:
	return _title.find_child(id, true, false) as Button


func _press(id: String) -> bool:
	var button := _button(id)
	if not button or button.disabled or not button.is_visible_in_tree():
		return _fail("Missing or unavailable control: " + id)
	button.pressed.emit()
	return true


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
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


func _fail(message: String) -> bool:
	push_error(message)
	return false


## Outside combat the leader travels with their platoon by Move orders, as the
## player sets them; in combat the stick steers the leader directly.
func _march_lead(aim: Vector2, mission: Node) -> void:
	var battle = mission.battle
	if battle.direct_hero_control():
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		return
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if aim.length_squared() > 0.0:
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-mission._hero_yaw) * Battle.LEAD_SPEED * DT)
