extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Map := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Mission := preload("res://game/battlefield/sova_mine_evacuation.gd")
const Evacuation := preload("res://game/battlefield/sova_mine_tunnels.gd")
const Hearing := preload("res://game/battlefield/sova_public_record.gd")
const HearingMission := preload("res://game/battlefield/sova_public_record_playtest.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const CAMP := "cairnspine_camp"
const MINE := "year_one_mine"
const ASSEMBLY := "cairnspine_assembly"
const CLEAR := "sova_mine_tunnels"
const HEARING_CLEAR := "sova_public_record"
const VAULT_ROAD := "cairnspine_vault_road"
const HUMAN_CLEAR := "mara_mine_escort"
const DT := 1.0 / 60.0

var _title: Title
var _profile_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-sova-flow-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	var profile := Profile.new(_profile_path)
	var mara := profile.load_campaign_world("mara")
	var seeded := profile.set_setting("fullscreen", false) == OK \
		and profile.set_setting("reduced_motion", true) == OK \
		and profile.record_mission_clear("mara", HUMAN_CLEAR) == OK
	var completed := profile.completed_missions("mara")
	mara.travel_to(MINE, completed)
	mara.travel_to("marches_road", completed)
	seeded = seeded and profile.record_world_waypoint(mara) == OK
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
		print("Sova campaign: real Mine evacuation and public hearing, separate dispatch/debriefs, gated Vault Road, independent saves and Continue passed.")
	quit(0 if passed else 1)


func _flow() -> bool:
	if not _press("New Game") or not _press("sova") or not _on_map(CAMP):
		return _fail("Sova did not open his own camp on the overworld.")
	if not _press("ConfirmTravel") or not _press("Read Dispatch") or not _is_dialogue(Beats.SOVA_MINE_DISPATCH):
		return _fail("Camp Operations did not present Sova's authored dispatch.")
	_read_dialogue()
	if not _press("Back") or not _on_map(CAMP):
		return _fail("Dispatch did not return through Camp Operations.")
	_map().select_waypoint(ASSEMBLY)
	_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not _map()._detail.text.contains("The Workers' Way Out"):
		return _fail("Mara's clear unlocked Sova's road or the wrong lock reason was shown.")
	_map().select_waypoint(MINE)
	if not _press("ConfirmTravel") or not _on_briefing() or not _saved_clears().is_empty():
		return _fail("Travel failed to request Sova's briefing without deployment or a clear.")
	_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or not _open_and_deploy():
		return _fail("Cancel did not leave an arrived Mine waypoint that could reopen briefing.")
	var at_mine := FileAccess.get_file_as_string(_profile_path)
	_joy(JOY_BUTTON_BACK)
	if not _on_map(MINE) or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Abandoning the Druid attempt changed its clear or waypoint.")

	if not _open_and_deploy():
		return false
	var mission := _title._campaign_battle as Mission
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	mission._physics_process(DT)
	if mission._field.name != &"YearOneMineCampaign" or mission.battle.bounds.size != Vector2(320, 224):
		return _fail("Sova did not deploy on the campaign-scale shared battlefield.")
	if not _walk_to(mission, "TunnelEntrance"):
		return false
	_joy(JOY_BUTTON_A)
	mission._physics_process(DT)
	if mission.objective.group_status(0) != Evacuation.GroupStatus.MOVING \
			or mission.objective.group_status(1) != Evacuation.GroupStatus.STAGED:
		return _fail("Hero-view Cross did not release only the mouth group.")
	for _step in range(60 * 55):
		if mission.objective.group_status(0) == Evacuation.GroupStatus.SAFE:
			break
		mission._physics_process(DT)
	if mission.objective.group_status(0) != Evacuation.GroupStatus.SAFE \
			or mission.objective.outcome != Evacuation.Outcome.ACTIVE or not _saved_clears().is_empty():
		return _fail("One safe group did not remain a recoverable, uncleared mission.")
	if not _walk_to(mission, "TunnelMidpoint"):
		return false
	_key(KEY_SPACE)
	mission._physics_process(DT)
	if mission.objective.group_status(1) != Evacuation.GroupStatus.MOVING:
		return _fail("Space did not release the bend party at its authored marker.")
	for _step in range(60 * 55):
		if mission.objective.outcome != Evacuation.Outcome.ACTIVE:
			break
		mission._physics_process(DT)
	if mission.objective.outcome != Evacuation.Outcome.SUCCEEDED or not mission._witness_at_truce:
		return _fail("Both arrivals and the witness's truce did not complete the real scene.")
	await process_frame
	if not _is_dialogue(Beats.SOVA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR]) \
			or Profile.new(_profile_path).load_campaign_world("sova").current_waypoint_id() != MINE:
		return _fail("The actual clear and Druid waypoint were not persisted before debrief.")
	_read_dialogue()
	if not _on_map(MINE):
		return _fail("Druid debrief did not return to the same Mine position.")
	_map().select_waypoint(ASSEMBLY)
	if not _press("ConfirmTravel") or not _on_briefing(HEARING_CLEAR) or _saved_clears() != PackedStringArray([CLEAR]):
		return _fail("Mine victory did not unlock the hearing briefing as an arrived Assembly waypoint.")
	if not _press("Read Dispatch") or not _is_dialogue(Beats.SOVA_PUBLIC_RECORD_DISPATCH):
		return _fail("The hearing briefing did not offer its authored dispatch.")
	_read_dialogue()
	if not _on_briefing(HEARING_CLEAR) or not _press("Confirm Deployment") or not _title._campaign_battle is HearingMission:
		return _fail("The dispatch did not return to an explicitly deployable hearing briefing.")
	var assembly_save := FileAccess.get_file_as_string(_profile_path)
	_joy(JOY_BUTTON_BACK)
	if not _on_map(ASSEMBLY) or FileAccess.get_file_as_string(_profile_path) != assembly_save:
		return _fail("Abandoning a hearing attempt changed progress.")
	_map().select_waypoint(VAULT_ROAD)
	_joy(JOY_BUTTON_A)
	if not _on_map(ASSEMBLY) or not _map()._detail.text.contains("Let Them Walk Out"):
		return _fail("The Vault Road was not correctly gated by the hearing clear.")
	_map().select_waypoint(ASSEMBLY)
	if not _press("ConfirmTravel") or not _on_briefing(HEARING_CLEAR) or not _press("Confirm Deployment"):
		return _fail("Could not reopen the arrived Assembly briefing and deploy the hearing.")

	var hearing := _title._campaign_battle as HearingMission
	hearing.set_physics_process(false)
	await physics_frame
	await physics_frame
	for marker in ["RecessedApproach", "RecessedRingCenter", "RecessedLectern"]:
		if not _walk_to(hearing, marker, "Hearing"):
			return false
	_key(KEY_SPACE)
	for _step in range(60 * 10):
		if hearing.objective.passages_read >= 2:
			break
		hearing._physics_process(DT)
	if hearing.objective.venue != Hearing.Venue.RECESSED or hearing.objective.passages_read != 2 \
			or hearing.objective.phase == Hearing.Phase.SUCCEEDED or _saved_clears() != PackedStringArray([CLEAR]):
		return _fail("The first two real passages did not read, or a partial hearing registered a clear.")
	for _step in range(60 * 5):
		if hearing.objective.phase == Hearing.Phase.SUCCEEDED:
			break
		hearing._physics_process(DT)
	_key(KEY_SPACE, false)
	await process_frame
	if not _is_dialogue(Beats.SOVA_PUBLIC_RECORD_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR, HEARING_CLEAR]) \
			or Profile.new(_profile_path).load_campaign_world("sova").current_waypoint_id() != ASSEMBLY:
		return _fail("Completing three real passages did not persist the clear and show the authored debrief.")
	_read_dialogue(5)
	if not _on_map(ASSEMBLY):
		return _fail("The hearing debrief did not return to Assembly.")
	_map().select_waypoint(VAULT_ROAD)
	if not _press("ConfirmTravel") or not _on_map(VAULT_ROAD) or _button("Confirm Deployment") \
			or _title._campaign_world.mission_at_current_waypoint() != "":
		return _fail("The hearing did not open the Vault Road, or exposed an unbuilt vault mission.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or not _on_map(VAULT_ROAD):
		return _fail("Continue did not restore Sova's arrived Vault Road.")

	var saved := Profile.new(_profile_path)
	if saved.completed_missions("mara") != PackedStringArray([HUMAN_CLEAR]) \
			or saved.load_campaign_world("mara").current_waypoint_id() != "marches_road" \
			or saved.completed_missions("sova") != PackedStringArray([CLEAR, HEARING_CLEAR]):
		return _fail("One campaign overwrote clear or position state in the other.")
	return true


func _open_and_deploy() -> bool:
	return _press("ConfirmTravel") and _on_briefing() and _press("Confirm Deployment") \
		and _title._campaign_battle is Mission


func _walk_to(mission: Node3D, marker: String, group := "Routes") -> bool:
	var world: Vector3 = mission.battlefield_marker(NodePath("Markers/" + group + "/" + marker)).global_position
	var point: Vector3 = mission.to_local(world)
	var target := Vector2(point.x, point.z)
	var budget := ceili(target.distance_to(mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 90
	for _step in range(budget):
		var offset: Vector2 = target - mission.battle.hero_position
		if offset.length() < 0.12:
			break
		var move := offset.normalized().rotated(mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, move.x)
		_axis(JOY_AXIS_LEFT_Y, move.y)
		mission._physics_process(DT)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return mission.hero_world_position().distance_to(world) < 0.13 or _fail("Could not walk to " + marker)


func _map() -> Map:
	return _title._stage.get_node_or_null("CampaignMap") as Map


func _on_map(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _map() != null \
		and _title._campaign_world.campaign_id() == "sova" and _title._campaign_world.current_waypoint_id() == id


func _on_briefing(mission_id := CLEAR) -> bool:
	return _title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null \
		and _title._campaign_world.mission_at_current_waypoint() == mission_id


func _is_dialogue(id: StringName) -> bool:
	var dialogue := _title._stage.get_node_or_null("CampaignDialogue") as Dialogue
	return dialogue != null and dialogue._active and dialogue._beat_id == id


func _read_dialogue(lines := 4) -> void:
	for _line in range(lines):
		_key(KEY_ENTER)


func _saved_clears() -> PackedStringArray:
	return Profile.new(_profile_path).completed_missions("sova")


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
