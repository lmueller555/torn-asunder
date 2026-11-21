extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/raska_mine_witness.gd")
const Witness := preload("res://game/battlefield/orc_mine_witness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const CAMP := "basin_camp"
const MINE := "year_one_mine"
const WELL_ROAD := "basin_well_road"
const CLEAR := "orc_mine_witness"
const DT := 1.0 / 60.0

const ROUTE := [
	"OrcApproach", "RidgeEastFoot", "RidgeEastCrest", "RidgeOverlook", "RidgeWestCrest",
	"RidgeWestFoot", "RidgeWestApproach", "WestAssembly", "QuarryTurn", "RoadWest",
	"MineYard", "TunnelEntrance", "TunnelMidpoint", "TunnelExit",
]

var _title: Title
var _mission: Mission
var _profile_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-raska-flow-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	var profile := Profile.new(_profile_path)
	var seeded := profile.set_setting("fullscreen", false) == OK \
		and profile.set_setting("reduced_motion", true) == OK \
		and _seed_clear_and_position(profile, "mara", "mara_mine_escort", "marches_road") \
		and _seed_clear_and_position(profile, "sova", "sova_mine_tunnels", "cairnspine_assembly")
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
		print("Raska campaign: camp dispatch, gated map, actual outlet failure, retry, willing witness and real rally, debrief, independent saves and Continue passed.")
	quit(0 if passed else 1)


func _seed_clear_and_position(profile: Profile, campaign_id: String, clear_id: String, end: String) -> bool:
	if profile.record_mission_clear(campaign_id, clear_id) != OK:
		return false
	var world := profile.load_campaign_world(campaign_id)
	var clears := profile.completed_missions(campaign_id)
	world.travel_to(MINE, clears)
	world.travel_to(end, clears)
	return world.current_waypoint_id() == end and profile.record_world_waypoint(world) == OK


func _flow() -> bool:
	if not _press("New Game") or not _press("raska") or not _on_map(CAMP):
		return _fail("Raska did not open his own Basin Camp on the overworld.")
	if not _press("ConfirmTravel") or not _press("Read Dispatch") or not _read_dialogue(Beats.RASKA_MINE_DISPATCH):
		return _fail("Basin Camp Operations did not present Raska's dispatch.")
	if not _press("Back") or not _on_map(CAMP):
		return _fail("Dispatch did not return through Camp Operations.")
	_map().select_waypoint(WELL_ROAD)
	_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not _map()._detail.text.contains("One Person to Ask"):
		return _fail("The Human/Druid clears opened the Orc road, or the lock text named the wrong mission.")
	_map().select_waypoint(MINE)
	if not _press("ConfirmTravel") or not _on_briefing() or not _saved_clears().is_empty():
		return _fail("Arriving at the shared Mine did not stop at Raska's unplayed briefing.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Cancel did not retain the Mine waypoint and its reopening action.")
	var at_mine := FileAccess.get_file_as_string(_profile_path)
	if not _press("Confirm Deployment"):
		return false
	_mission = _title._campaign_battle as Mission
	if not _mission:
		return _fail("Explicit deployment was not Raska's actual mission.")
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if _mission._field.name != &"YearOneMineCampaign" or _mission._window_started:
		return _fail("The first attempt is not on the campaign-scale field or fired before approach.")
	if not _follow(ROUTE) or not _wait_for(Witness.Phase.FAILED, 60 * 30):
		return false
	if _mission.objective.failure != Witness.Failure.OUTLET_WINDOW_CLOSED \
			or _mission._detachment.global_position != _mission._screen_end \
			or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Failure did not correspond to the real closure, or wrote a clear.")

	_key(KEY_BACKSPACE)
	if _mission.objective.phase != Witness.Phase.WAITING_FOR_OFFER or _mission._window_started \
			or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Retry did not restore the actual approach without progression.")
	if not _win_route(at_mine):
		return false
	await process_frame
	if _saved_clears() != PackedStringArray([CLEAR]) or not _read_dialogue(Beats.RASKA_MINE_DEBRIEF):
		return _fail("Actual rally delivery did not save Raska's clear and present his debrief.")
	if not _on_map(MINE):
		return _fail("Raska's debrief did not leave the party at the same Mine waypoint.")
	_map().select_waypoint(WELL_ROAD)
	if not _press("ConfirmTravel") or not _on_map(WELL_ROAD) or _button("Confirm Deployment"):
		return _fail("Raska's clear did not open the onward route, or connected an unbuilt battle.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(WELL_ROAD):
		return _fail("Continue did not reload Raska's arriving Well Road waypoint.")
	var profile := Profile.new(_profile_path)
	if profile.completed_missions("mara") != PackedStringArray(["mara_mine_escort"]) \
			or profile.completed_missions("sova") != PackedStringArray(["sova_mine_tunnels"]) \
			or profile.completed_missions("raska") != PackedStringArray([CLEAR]) \
			or profile.load_campaign_world("mara").current_waypoint_id() != "marches_road" \
			or profile.load_campaign_world("sova").current_waypoint_id() != "cairnspine_assembly" \
			or profile.load_campaign_world("raska").current_waypoint_id() != WELL_ROAD:
		return _fail("Campaign clears or waypoint saves crossed namespaces.")
	return true


func _win_route(at_mine: String) -> bool:
	var turn := _point("EvacuationTurn")
	var trail := _point("EvacuationTrail")
	var outlet := _point("TunnelExit")
	if not _follow(ROUTE) or not _drive_to(turn) or not _drive_to(trail):
		return false
	for _step in range(240):
		if _mission._screen_held:
			break
		_walk_tick(_mission._detachment.global_position)
	_stop()
	if not _mission._screen_held or _mission._detachment.visible:
		return _fail("Real movement did not intercept the approaching detachment.")
	if not _drive_to(trail) or not _drive_to(turn) or not _drive_to(outlet):
		return false
	_key(KEY_SPACE)
	_mission._physics_process(DT)
	if _mission.objective.phase != Witness.Phase.WAITING_FOR_OFFER or not _wait_for(Witness.Phase.TERMS_OFFERED, 60 * 35):
		return _fail("The witness did not withhold her offer until the other workers reached safety.")
	_joy(JOY_BUTTON_A)
	_mission._physics_process(DT)
	if _mission.objective.phase != Witness.Phase.WAITING_FOR_WORKERS:
		return _fail("The witness's consent was not registered as its own step.")
	_mission._physics_process(DT)
	if _mission.objective.phase != Witness.Phase.ESCORTING or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Hero-view confirmation did not start the voluntary escort without a clear.")

	var reverse := ROUTE.duplicate()
	reverse.reverse()
	reverse.pop_front()
	reverse.pop_back()
	if not _follow(reverse):
		return false
	var rally := _point("OrcApproach")
	var near := rally + (_mission.hero_world_position() - rally).normalized() * 2.0
	if not _drive_to(near):
		return false
	for _step in range(60):
		_mission._physics_process(DT)
	if _mission.objective.phase != Witness.Phase.ESCORTING or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Raska arriving without the witness completed the escort.")
	if not _drive_to(rally, true):
		return false
	return (_mission.objective.phase == Witness.Phase.SUCCEEDED \
		and _mission._witness.global_position.distance_to(rally) <= Mission.RALLY_RADIUS) \
		or _fail("The real witness never arrived at the Orc rally.")


func _follow(route: Array) -> bool:
	for id: String in route:
		if not _drive_to(_point(id)):
			return false
	return true


func _drive_to(target: Vector3, allow_success := false) -> bool:
	var budget := ceili(_mission.hero_world_position().distance_to(target) / Battle.HERO_SPEED / DT) + 90
	for _step in range(budget):
		if _mission.hero_world_position().distance_to(target) < 0.13 or _mission._finished():
			break
		_walk_tick(target)
	_stop()
	return _mission.hero_world_position().distance_to(target) < 0.14 \
		or (allow_success and _mission.objective.phase == Witness.Phase.SUCCEEDED) \
		or _fail("The real hero did not reach " + str(target))


func _walk_tick(target: Vector3) -> void:
	var local := _mission.to_local(target)
	var aim := (Vector2(local.x, local.z) - _mission.battle.hero_position).normalized().rotated(_mission._hero_yaw)
	_axis(JOY_AXIS_LEFT_X, aim.x)
	_axis(JOY_AXIS_LEFT_Y, aim.y)
	_mission._physics_process(DT)


func _stop() -> void:
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)


func _wait_for(phase: Witness.Phase, budget: int) -> bool:
	for _step in range(budget):
		if _mission.objective.phase == phase or _mission._finished():
			break
		_mission._physics_process(DT)
	return _mission.objective.phase == phase or _fail("Unexpected witness objective phase: " + str(_mission.objective.phase))


func _point(id: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/Routes/" + id)).global_position


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null \
		and _title._campaign_world.campaign_id() == "raska" and _title._campaign_world.current_waypoint_id() == id


func _on_briefing() -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null \
		and _title._campaign_world.mission_at_current_waypoint() == CLEAR


func _read_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not dialogue or not dialogue._active or dialogue._beat_id != id:
		return false
	for _line in Beats.get_beat(id).lines:
		_key(KEY_ENTER)
	return _title._page != Title.Page.CAMPAIGN_DIALOGUE


func _saved_clears() -> PackedStringArray:
	return Profile.new(_profile_path).completed_missions("raska")


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
