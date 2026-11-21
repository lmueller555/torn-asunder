extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/neris_failing_grove_playtest.gd")
const Grove := preload("res://game/battlefield/neris_failing_grove.gd")
const FeederScene := preload("res://game/battlefield/neris_spanwater_playtest.gd")
const Feeder := preload("res://game/battlefield/neris_spanwater_feeder.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const CAMP := "grove_camp"
const NURSERY := "isolated_grove_nursery"
const SPANWATER := "spanwater_lock"
const CAIRNSPINE := "cairnspine_vault_road"
const CLEAR := "neris_failing_grove"
const FEEDER_CLEAR := "neris_spanwater_feeder"
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
			and profile.completed_missions("neris") == PackedStringArray([CLEAR, FEEDER_CLEAR]) \
			and profile.load_campaign_world("neris").current_waypoint_id() == CAIRNSPINE) \
			or _fail("Campaign progression or shared Spanwater position was not isolated.")
	_title.queue_free()
	await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Neris campaign: reaches the feeder after the physical transplant; actual crest defeat, retry, gauge clear, debrief, Cairnspine travel and independent Continue passed.")
	quit(0 if passed else 1)


func _exercise() -> bool:
	if not _press("New Game") or not _press("neris") or not _on_map(CAMP):
		return _fail("Neris did not open her own Grove Camp map.")
	_map().select_waypoint(NURSERY)
	if not _press("ConfirmTravel") or not _on_briefing():
		return _fail("Arrival at the grove did not stop at the correct briefing.")
	_joy(JOY_BUTTON_B)
	if not _on_map(NURSERY) or not _map().select_waypoint(SPANWATER) \
			or not _button("ConfirmTravel").disabled or not _map()._detail.text.contains("What We Planted Here"):
		return _fail("A foreign campaign clear or arriving at the grove unlocked the feeder waypoint.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(NURSERY) or not _press("ConfirmTravel") \
			or not _on_briefing() or not _press("Read Dispatch") \
			or not _read_dialogue(Beats.NERIS_FAILING_GROVE_DISPATCH) or not _on_briefing():
		return _fail("Continue or the dispatch bypassed Neris's explicit deployment.")
	var at_grove := FileAccess.get_file_as_string(_path)
	if not _press("Confirm Deployment") or not _press("ReturnToMap") or not _on_map(NURSERY) \
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
	if Profile.new(_path).completed_missions("neris") != PackedStringArray([CLEAR]) \
			or not _read_dialogue(Beats.NERIS_FAILING_GROVE_DEBRIEF) or not _on_map(NURSERY):
		return _fail("The physical transplant did not save the clear and show the authored debrief.")
	if not _press("ConfirmTravel") or not _on_briefing() or not _press("Confirm Deployment"):
		return _fail("The completed grove could not be replayed.")
	var replay := _title._campaign_battle as Mission
	if not replay or replay.objective.phase != Grove.Phase.AWAITING_ENVOY or not _press("ReturnToMap"):
		return _fail("The completed grove replay did not begin with a fresh objective.")
	return await _run_spanwater()


func _run_spanwater() -> bool:
	if not _map().select_waypoint(SPANWATER) or not _press("ConfirmTravel") or not _on_briefing(FEEDER_CLEAR):
		return _fail("The grove clear did not open the independent Dryad mission at Spanwater.")
	_joy(JOY_BUTTON_B)
	if not _on_map(SPANWATER) or not _map().select_waypoint(CAIRNSPINE) or not _button("ConfirmTravel").disabled:
		return _fail("Arrival or Raska's release alone unlocked Cairnspine.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SPANWATER) or not _press("ConfirmTravel") \
			or not _on_briefing(FEEDER_CLEAR) or not _press("Read Dispatch") \
			or not _read_dialogue(Beats.NERIS_SPANWATER_FEEDER_DISPATCH) or not _on_briefing(FEEDER_CLEAR):
		return _fail("Continue or the Dryad dispatch skipped explicit Spanwater deployment.")
	var at_lock := FileAccess.get_file_as_string(_path)
	if not _press("Confirm Deployment"):
		return false
	var patrol_mission := _title._campaign_battle as FeederScene
	if not patrol_mission or patrol_mission._field.scene_file_path != "res://game/battlefields/spanwater_lock_campaign.tscn":
		return _fail("The Dryad briefing did not deploy the live feeder lane on shared Spanwater terrain.")
	patrol_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _wait(func() -> bool: return patrol_mission.objective.phase == Feeder.Phase.FAILED, 4200, patrol_mission) \
			or patrol_mission.objective.failure != Feeder.Failure.FEEDER_BURIED or _title._page != Title.Page.CAMPAIGN_BATTLE \
			or FileAccess.get_file_as_string(_path) != at_lock:
		return _fail("The real crest defeat left the battle or wrote progression.")
	_key(KEY_BACKSPACE)
	if patrol_mission.objective.phase != Feeder.Phase.CLEAR_INLET or patrol_mission._elapsed != 0.0 \
			or FileAccess.get_file_as_string(_path) != at_lock:
		return _fail("Retry did not reset the local feeder scene without touching the save.")

	# Play through Neris and an actual formation; no model input or win signal is injected.
	if not _walk("Routes/FeederPathWest", patrol_mission) or not _walk("Objectives/FeederInletRack", patrol_mission):
		return false
	_joy(JOY_BUTTON_A)
	_tick(patrol_mission)
	if patrol_mission.objective.phase != Feeder.Phase.FIT_BOARDS:
		return _fail("A physical inlet-rack interaction did not start the work.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_RIGHT_STICK)
	_joy(JOY_BUTTON_DPAD_RIGHT)
	var order := InputEventMouseButton.new()
	var screen := patrol_mission.to_global(patrol_mission._ground(patrol_mission._screen_point))
	order.position = root.get_camera_3d().unproject_position(screen)
	order.pressed = true
	order.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(order, true)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _wait(func() -> bool: return patrol_mission.objective.phase == Feeder.Phase.RAISE_GAUGE, 1800, patrol_mission) \
			or patrol_mission.objective.board_progress != 1.0 or not patrol_mission._screened:
		return _fail("A real formation screen did not let town workers complete the guide boards.")
	if not _wait(func() -> bool: return patrol_mission._ford_closed, 900, patrol_mission) \
			or not is_zero_approx(patrol_mission.objective.gauge_progress) or _title._victory_pending \
			or FileAccess.get_file_as_string(_path) != at_lock:
		return _fail("Main-river stage alone wrote a Dryad clear.")
	if not _wait(func() -> bool: return patrol_mission.objective.phase == Feeder.Phase.SUCCEEDED, 4200, patrol_mission) \
			or patrol_mission.objective.gauge_progress != 1.0 or not patrol_mission._channel_visual.visible:
		return _fail("The actual downstream water did not reach the mark and finish the mission.")
	await process_frame
	var profile := Profile.new(_path)
	if profile.completed_missions("neris") != PackedStringArray([CLEAR, FEEDER_CLEAR]) \
			or profile.load_campaign_world("neris").current_waypoint_id() != SPANWATER \
			or not _read_dialogue(Beats.NERIS_SPANWATER_FEEDER_DEBRIEF) or not _on_map(SPANWATER):
		return _fail("The genuine gauge clear lost the grove record, skipped the local debrief, or fast-traveled.")
	if not _map().select_waypoint(CAIRNSPINE) or not _press("ConfirmTravel") or not _on_map(CAIRNSPINE) \
			or not _title._campaign_world.mission_at_current_waypoint().is_empty():
		return _fail("The Dryad route did not open an explicit travel-only Cairnspine waypoint.")
	_joy(JOY_BUTTON_B)
	return (_press("Continue") and _on_map(CAIRNSPINE) and _button("ConfirmTravel").disabled \
		and _map()._heading.text == "Campaign Map") or _fail("Continue did not restore the unfinished campaign at Cairnspine.")


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
	var budget := ceili(active.battle.hero_position.distance_to(target) / Battle.HERO_SPEED / DT) + 65
	for _step in range(budget):
		var offset := target - active.battle.hero_position
		if offset.length() <= 0.18:
			break
		var aim := offset.normalized().rotated(active._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
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


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
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


func _fail(message: String) -> bool:
	push_error(message)
	return false
