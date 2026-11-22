extends SceneTree

const CampaignFlow := preload("res://tests/campaign_flow_helpers.gd")
const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/raska_mine_witness.gd")
const Witness := preload("res://game/battlefield/orc_mine_witness.gd")
const WellRoad := preload("res://game/battlefield/raska_well_road.gd")
const WellScene := preload("res://game/battlefield/raska_well_road_playtest.gd")
const Spanwater := preload("res://game/battlefield/raska_spanwater.gd")
const Release := preload("res://game/battlefield/raska_spanwater_release.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const CAMP := "basin_camp"
const MINE := "year_one_mine"
const WELL_ROAD := "basin_well_road"
const CLEAR := "orc_mine_witness"
const WELL_CLEAR := "orc_well_road"
const SPANWATER := "spanwater_lock"
const SPAN_CLEAR := "orc_spanwater_release"
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
		and profile.record_grain_clear(Grain.SEED_ONLY) == OK \
		and profile.record_ilyra_moonwash_clear(Moonwash.CREWS_ONLY) == OK \
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
		print("Raska campaign: all three physical victories, defeat/retry, dispatches/debriefs, one coda, replay, independent saves and Continue passed.")
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
	CampaignFlow.resume_at_map(_title, "raska")
	if not _on_map(CAMP):
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
	if not _press("ConfirmTravel") or not _on_briefing(WELL_CLEAR):
		return _fail("The real Mine clear did not open the Well Road briefing.")
	var well_route := PackedStringArray([CLEAR])
	if _saved_clears() != well_route or Profile.new(_profile_path).load_campaign_world("raska").current_waypoint_id() != WELL_ROAD:
		return _fail("Well Road arrival wrote a clear or failed to save the waypoint.")
	_joy(JOY_BUTTON_B)
	if not _on_map(WELL_ROAD) or not _map().select_waypoint(SPANWATER) \
			or not _button("ConfirmTravel").disabled or not _map()._detail.text.contains("The Second Bucket"):
		return _fail("Spanwater travel did not require exactly the Well Road clear.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(WELL_ROAD) or not _press("ConfirmTravel") or not _on_briefing(WELL_CLEAR):
		return _fail("Continue did not restore the Well Road waypoint without deploying.")
	if not _press("Read Dispatch") or not _read_dialogue(Beats.RASKA_WELL_ROAD_DISPATCH) \
			or not _on_briefing(WELL_CLEAR) or not _press("Confirm Deployment"):
		return _fail("The authored Well Road dispatch did not return to deployment.")
	if not PauseTest.leave_battle(_title) or not _on_map(WELL_ROAD) or _saved_clears() != well_route \
			or not _press("ConfirmTravel") or not _on_briefing(WELL_CLEAR) or not _press("Confirm Deployment"):
		return _fail("Leaving the battle early saved a clear or lost the return waypoint.")

	var well := _title._campaign_battle as WellScene
	if not well or well._field.name != &"RedBasinWellRoad":
		return _fail("Well Road briefing did not deploy the actual Red Basin battle.")
	well.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not _deliver_well_carts(well):
		return false
	await process_frame
	if _saved_clears() != PackedStringArray([CLEAR, WELL_CLEAR]) or not _read_dialogue(Beats.RASKA_WELL_ROAD_DEBRIEF):
		return _fail("Two real cart arrivals did not save Raska's clear and present his debrief.")
	if not _on_map(WELL_ROAD) or not _map().select_waypoint(SPANWATER) or not _press("ConfirmTravel") \
			or not _on_briefing(SPAN_CLEAR):
		return _fail("The actual Well Road victory did not open the Spanwater briefing.")
	var prior := PackedStringArray([CLEAR, WELL_CLEAR])
	if _saved_clears() != prior or Profile.new(_profile_path).has_seen_intermission("raska", Beats.RASKA_SPANWATER_CODA):
		return _fail("Arriving at Spanwater advanced the finale or marked its coda early.")
	_joy(JOY_BUTTON_B)
	if not _on_map(SPANWATER):
		return _fail("Back did not return from the Spanwater briefing.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SPANWATER) or not _press("ConfirmTravel") \
			or not _on_briefing(SPAN_CLEAR) or not _press("Read Dispatch") \
			or not _read_dialogue(Beats.RASKA_SPANWATER_DISPATCH) or not _on_briefing(SPAN_CLEAR) \
			or not _press("Confirm Deployment"):
		return _fail("Continue and Spanwater dispatch did not return to explicit deployment.")
	if not await _spanwater_flow(prior):
		return false

	var profile := Profile.new(_profile_path)
	if profile.completed_missions("mara") != PackedStringArray(["mara_mine_escort", "mara_grain_crossing"]) \
			or profile.grain_clear_result() != Grain.SEED_ONLY \
			or profile.completed_missions("ilyra") != PackedStringArray(["ilyra_moonwash_rescue"]) \
			or profile.ilyra_moonwash_clear_result() != Moonwash.CREWS_ONLY \
			or profile.completed_missions("sova") != PackedStringArray(["sova_mine_tunnels"]) \
			or profile.completed_missions("raska") != PackedStringArray([CLEAR, WELL_CLEAR, SPAN_CLEAR]) \
			or not profile.has_seen_intermission("raska", Beats.RASKA_SPANWATER_CODA) \
			or profile.has_seen_intermission("sova", Beats.RASKA_SPANWATER_CODA) \
			or profile.load_campaign_world("mara").current_waypoint_id() != "marches_road" \
			or profile.load_campaign_world("sova").current_waypoint_id() != "cairnspine_assembly" \
			or profile.load_campaign_world("raska").current_waypoint_id() != SPANWATER:
		return _fail("Campaign clears or waypoint saves crossed namespaces.")
	return true


func _spanwater_flow(prior: PackedStringArray) -> bool:
	var span := _title._campaign_battle as Spanwater
	if not span or span._field.name != &"SpanwaterLockCampaign":
		return _fail("Spanwater did not deploy Raska's campaign-scale lock scene.")
	span.set_physics_process(false)
	await physics_frame
	await physics_frame
	var wheel := _span_point(span, "Objectives/SpillwayWheel")
	var exit := _span_point(span, "Objectives/HighBankExit")
	var outcomes: Array[bool] = []
	span.mission_finished.connect(func(won: bool) -> void: outcomes.append(won))
	for path in ["Routes/ServiceCauseway", "Routes/LockApron", "Objectives/SpillwayWheel"]:
		if not _walk_spanwater(span, _span_point(span, path), 0.18):
			return false
	_key(KEY_SPACE)
	span._physics_process(DT)
	if span.objective.phase != Release.Phase.SECURE_SPILLWAY or _saved_clears() != prior:
		return _fail("Touching the contested wheel wrote a clear.")
	if not _secure_spanwater(span, wheel):
		return false
	_joy(JOY_BUTTON_A)
	span._physics_process(DT)
	var regulars := span.battle.formations[0]
	regulars.position = _span_point(span, "Routes/LockApron")
	regulars.hold()
	for _step in range(600):
		span._physics_process(DT)
	if span.objective.failure != Release.Failure.SPILLWAY_SHUT or outcomes != [false] \
			or _saved_clears() != prior or _title._page != Title.Page.CAMPAIGN_BATTLE:
		return _fail("The physical shutdown did not fail once, or it advanced the campaign.")
	_key(KEY_BACKSPACE)
	if span.objective.phase != Release.Phase.SECURE_SPILLWAY or span._withdrawal_count != 0:
		return _fail("Retry did not reset Spanwater's attempt.")
	for path in ["Routes/ServiceCauseway", "Routes/LockApron", "Objectives/SpillwayWheel"]:
		if not _walk_spanwater(span, _span_point(span, path), 0.18):
			return false
	if not _secure_spanwater(span, wheel):
		return false
	_joy(JOY_BUTTON_A)
	for _step in range(650):
		if span.objective.phase == Release.Phase.EXTRACT:
			break
		span._physics_process(DT)
	if span.objective.phase != Release.Phase.EXTRACT or not span._crossing_closed \
			or span._withdrawal_count != 1 or _saved_clears() != prior or _title._victory_pending:
		return _fail("Achieving river stage did not close the ford, or won without extraction.")
	for path in ["Routes/MarchCounterattackApproach", "Routes/HighBankStaging", "Routes/HighBank"]:
		if not _walk_spanwater(span, _span_point(span, path), 0.18):
			return false
	if not _walk_spanwater(span, exit, Spanwater.EXIT_RADIUS):
		return false
	if span.objective.phase != Release.Phase.SUCCEEDED or outcomes != [false, true]:
		return _fail("Physical high-bank extraction did not signal victory exactly once.")
	await process_frame
	var full := PackedStringArray([CLEAR, WELL_CLEAR, SPAN_CLEAR])
	if _saved_clears() != full or not _finish_span_ending():
		return _fail("Actual extraction did not save the finale and play the debrief, then the coda.")
	if not _on_map(SPANWATER) or _map()._heading.text != "Campaign Complete" \
			or not Profile.new(_profile_path).has_seen_intermission("raska", Beats.RASKA_SPANWATER_CODA):
		return _fail("The finale did not return to the completed campaign map and save the coda.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(SPANWATER) or not _press("ConfirmTravel") \
			or not _on_briefing(SPAN_CLEAR) or not _press("Confirm Deployment"):
		return _fail("Continue repeated the coda, or a finished Spanwater could not replay.")
	var replay := _title._campaign_battle as Spanwater
	if not replay or replay.objective.phase != Release.Phase.SECURE_SPILLWAY \
			or replay._withdrawal_count != 0 or _saved_clears() != full:
		return _fail("Replay did not start a fresh attempt or changed the completed campaign.")
	replay.set_physics_process(false)
	await physics_frame
	await physics_frame
	# Repeat the decisive inputs after staging the replay at the wheel.
	replay.battle.hero_position = wheel
	replay.battle.formations[0].position = wheel
	for _step in range(100):
		replay._physics_process(DT)
	_key(KEY_SPACE)
	for _step in range(650):
		if replay.objective.phase == Release.Phase.EXTRACT:
			break
		replay._physics_process(DT)
	if replay.objective.phase != Release.Phase.EXTRACT:
		return _fail("The replay could not repeat the release.")
	replay.battle.hero_position = exit
	replay._physics_process(DT)
	await process_frame
	if not _read_dialogue(Beats.RASKA_SPANWATER_DEBRIEF) or not _on_map(SPANWATER) \
			or _map()._heading.text != "Campaign Complete" or _saved_clears() != full:
		return _fail("A replay victory changed the saved clear or repeated the coda.")
	return true


func _finish_span_ending() -> bool:
	# The debrief changes directly into the independent coda without returning to the map.
	if not _play_dialogue(Beats.RASKA_SPANWATER_DEBRIEF):
		return false
	var coda := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not coda or not coda._active or coda._beat_id != Beats.RASKA_SPANWATER_CODA \
			or Profile.new(_profile_path).has_seen_intermission("raska", Beats.RASKA_SPANWATER_CODA):
		return _fail("The coda did not open after the debrief, or was marked read before playback finished.")
	# Simulate closing after the clear, before marking the coda read.
	_title._show_title()
	if not _press("Continue"):
		return false
	return _read_dialogue(Beats.RASKA_SPANWATER_CODA)


func _span_point(span: Spanwater, path: String) -> Vector2:
	return span._marker_position(span.battlefield_marker(NodePath("Markers/" + path)))


func _walk_spanwater(span: Spanwater, point: Vector2, tolerance: float) -> bool:
	var budget := ceili(span.battle.hero_position.distance_to(point) / Battle.LEAD_SPEED / DT) + 65
	for _step in range(budget):
		var offset := point - span.battle.hero_position
		if offset.length() <= tolerance or span._finished():
			break
		var aim := offset.normalized().rotated(span._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y), span)
		span._physics_process(DT)
	_stop()
	return span.battle.hero_position.distance_to(point) <= tolerance or _fail("Raska did not reach " + str(point))


func _secure_spanwater(span: Spanwater, wheel: Vector2) -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_RIGHT_STICK)
	var regulars := span.battle.formations[0]
	for point: Vector2 in [_span_point(span, "Routes/UpstreamApproach"), _span_point(span, "Routes/ServiceCauseway"), _span_point(span, "Routes/LockApron"), wheel]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = root.get_camera_3d().unproject_position(span.to_global(span._ground(point)))
		root.push_input(event, true)
		var budget := ceili(regulars.position.distance_to(point) / Battle.FORMATION_SPEED / DT) + 60
		for _step in range(budget):
			if regulars.order != Battle.Order.MOVE:
				break
			span._physics_process(DT)
		if regulars.position.distance_to(point) >= 0.09:
			return _fail("The Basin Regulars did not reach " + str(point))
	for _step in range(100):
		span._physics_process(DT)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return span.objective.phase == Release.Phase.READY_AT_WHEEL or _fail("The Basin Regulars did not secure the wheel.")


func _deliver_well_carts(well: WellScene) -> bool:
	var objective := well.objective
	_joy(JOY_BUTTON_Y)
	well._physics_process(DT)
	if objective.cart_state(WellRoad.Cart.UPPER) != WellRoad.CartState.EN_ROUTE:
		return _fail("The upper cart did not take the actual wash route.")
	_joy(JOY_BUTTON_LEFT_SHOULDER)
	_joy(JOY_BUTTON_Y)
	well._physics_process(DT)
	if objective.cart_state(WellRoad.Cart.LOWER) != WellRoad.CartState.LOADING:
		return _fail("A premature route order bypassed boarding.")
	for path in [
		"Routes/UpperWellStaging", "Routes/WestApproachFork", "Routes/WashEntryTurn",
		"Routes/LowerWellStaging", "Objectives/LowerBoarding", "Spawns/LowerHouseholds", "Objectives/LowerStorehouse",
	]:
		var point := well.battlefield_marker(NodePath("Markers/" + path)).global_position
		if not _walk_well_hero(well, point):
			return false
	_joy(JOY_BUTTON_A)
	for _step in range(850):
		if objective.cart_state(WellRoad.Cart.LOWER) == WellRoad.CartState.READY:
			break
		well._physics_process(DT)
	if objective.cart_state(WellRoad.Cart.LOWER) != WellRoad.CartState.READY or not well._riders[0].visible:
		return _fail("The lower cart never physically took its households aboard.")
	for _step in range(3500):
		if objective.cart_state(WellRoad.Cart.UPPER) == WellRoad.CartState.SAFE:
			break
		well._physics_process(DT)
	if objective.cart_state(WellRoad.Cart.UPPER) != WellRoad.CartState.SAFE \
			or objective.cart_state(WellRoad.Cart.LOWER) != WellRoad.CartState.READY \
			or _saved_clears() != PackedStringArray([CLEAR]) or _title._victory_pending:
		return _fail("A single real delivery wrote a clear, or the early order was replayed.")
	_key(KEY_T)
	for _step in range(3500):
		if objective.outcome != WellRoad.Outcome.ACTIVE:
			break
		well._physics_process(DT)
	var exit := well.battlefield_marker(^"Markers/Objectives/BasinExit").global_position
	return (objective.outcome == WellRoad.Outcome.SUCCEEDED \
		and well._carts[0].wagon.global_position.distance_to(exit) <= WellScene.EXIT_RADIUS \
		and well._carts[1].wagon.global_position.distance_to(exit) <= WellScene.EXIT_RADIUS) \
		or _fail("Both physical carts did not arrive in the Basin exit after a fresh order.")


func _walk_well_hero(well: WellScene, target: Vector3) -> bool:
	var local := well.to_local(target)
	var point := Vector2(local.x, local.z)
	var budget := ceili(well.battle.hero_position.distance_to(point) / Battle.LEAD_SPEED / DT) + 75
	for _step in range(budget):
		var offset := point - well.battle.hero_position
		if offset.length() <= 0.17:
			break
		var aim := offset.normalized().rotated(well._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y), well)
		well._physics_process(DT)
	_stop()
	return well.battle.hero_position.distance_to(point) <= 0.17 or _fail("Raska did not reach " + str(point))

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
	var budget := ceili(_mission.hero_world_position().distance_to(target) / Battle.LEAD_SPEED / DT) + 90
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
	_march_lead(Vector2(aim.x, aim.y), _mission)
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


func _on_briefing(mission_id := CLEAR) -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null \
		and _title._campaign_world.mission_at_current_waypoint() == mission_id


func _read_dialogue(id: StringName) -> bool:
	return _play_dialogue(id) and _title._page != Title.Page.CAMPAIGN_DIALOGUE


func _play_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	if not dialogue or not dialogue._active or dialogue._beat_id != id:
		return false
	for _line in Beats.get_beat(id).lines:
		_key(KEY_ENTER)
	return not dialogue._active


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
