extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const World := preload("res://game/campaign_world.gd")
const TitleFlow := preload("res://tests/campaign_flow_helpers.gd")
const Marches := preload("res://game/overworld/marches_overworld_view.gd")
const Map2D := preload("res://game/campaign_map.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"

var _path: String
var _title: Title


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-station-title-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_path)
	var passed := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", false) == OK
	if passed:
		passed = await _authored_station()
	if passed:
		passed = await _fallback_station()
	if is_instance_valid(_title):
		_title.queue_free()
		await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara Station: explicit arrival confirm, Operations, Barracks, Training Grounds, unchanged battlefield briefing, and 2D fallback passed.")
	quit(0 if passed else 1)


func _authored_station() -> bool:
	_make_title("mara", true)
	await process_frame
	var map := _map() as Marches
	if not map or not _on_map(CAMP):
		return _fail("Expected Mara's authored Marches map.")
	map.set_process(false)
	if not _hover_marker(map, CAMP) or not _on_map(CAMP):
		return _fail("Hovering over the current camp must not enter the station.")
	if not map.select_waypoint(MINE):
		return _fail("Mine must be selectable from camp.")
	map.confirm_selection()
	if not map._navigation.is_travelling() or not _on_map(CAMP):
		return _fail("Travel to Mine must not open a station.")
	map.confirm_selection()
	if not map._navigation.is_travelling() or not _on_map(CAMP):
		return _fail("Confirming a second time during travel must not enter a station.")
	map._process(3.1)
	if not _on_map(MINE) or _button("Confirm Deployment") or _title._campaign_battle:
		return _fail("Mine arrival must not open its briefing or launch combat.")
	map.confirm_selection()
	if _title._page != Title.Page.MISSION_BRIEFING or not _button("Confirm Deployment") \
			or _button("Barracks") or _title._campaign_battle:
		return _fail("The Mine must still open the existing battlefield briefing only on confirm.")
	if not _press("Back") or not _on_map(MINE):
		return _fail("Battlefield briefing Back did not restore Mine.")
	map = _map() as Marches
	if not map or not map.select_waypoint(CAMP):
		return _fail("The party must be able to return to Marches Camp.")
	map.set_process(false)
	if not _on_map(MINE):
		return _fail("Selecting Camp while away must not enter a station.")
	map.camp_operations_requested.emit() # A stale UI event cannot enter the selected but unarrived camp.
	if not _on_map(MINE):
		return _fail("A camp action emitted while away must not enter a station.")
	map.confirm_selection()
	map._process(0.2)
	map.confirm_selection()
	map.camp_operations_requested.emit()
	if not map._navigation.is_travelling() or not _on_map(MINE):
		return _fail("Confirming mid-route toward Marches Camp must not enter it.")
	map._process(3.1)
	if not _on_map(CAMP) or _button("Barracks"):
		return _fail("Arrival at Marches Camp must stay on the map until a separate confirm.")
	map.confirm_selection()
	if not _station_shell():
		return _fail("Confirm on the arrived friendly camp must open only the Station shell.")
	var before := FileAccess.get_file_as_string(_path)
	if not _exercise_services():
		return false
	if not _press("Main Gate") or not _on_map(CAMP) or _map() != map:
		return _fail("Main Gate did not restore the same authored waypoint.")
	if FileAccess.get_file_as_string(_path) != before:
		return _fail("Browsing station services changed the save.")
	return true


func _fallback_station() -> bool:
	_title.queue_free()
	await process_frame
	_make_title("mara", false)
	var map := _map() as Map2D
	if not map or not _on_map(CAMP):
		return _fail("Normal title must retain the 2D map at the saved canonical camp.")
	map.confirm_selection()
	if not _station_shell() or not _press("Main Gate") or not _on_map(CAMP) or _map() != map:
		return _fail("The 2D fallback must enter and exit the same canonical Station safely.")
	_joy(JOY_BUTTON_A)
	if not _station_shell():
		return _fail("The 2D map must accept actual input again after Main Gate.")
	_joy(JOY_BUTTON_B)
	if not _on_map(CAMP) or _map() != map:
		return _fail("Controller Back from Station must also restore the same 2D map.")
	TitleFlow.resume_at_map(_title, "sova")
	map = _map() as Map2D
	if not map:
		return _fail("Expected the existing Sova fallback map.")
	map.confirm_selection()
	if _title._page != Title.Page.BRIEFING or _button("Barracks") or not _button("Read Dispatch"):
		return _fail("The Mara Station must not replace another leader's Camp Operations.")
	return true


func _exercise_services() -> bool:
	if not _focused("Operations"):
		return _fail("The first available station destination must have focus.")
	_joy(JOY_BUTTON_A)
	if not _press("Read Dispatch") or _title._page != Title.Page.CAMPAIGN_DIALOGUE:
		return _fail("Operations must preserve the original dispatch.")
	var dialogue := _title._stage.get_child(0) as Dialogue
	if not dialogue or dialogue._beat_id != Beats.MARA_MINE_DISPATCH:
		return _fail("Operations opened the wrong dispatch.")
	dialogue.cancel()
	if not _button("Read Dispatch") or not _press("Back") or not _station_shell():
		return _fail("Dispatch and Operations did not return to their immediate parent pages.")
	if not _focused("Operations"):
		return _fail("Operations Back did not restore the station entry's focus.")
	_joy(JOY_BUTTON_DPAD_DOWN)
	if not _focused("Barracks"):
		return _fail("D-pad did not move from Operations to Barracks.")
	_stick_y(0.9)
	if not _focused("Training Grounds"):
		return _fail("Left stick did not move to Training Grounds.")
	_stick_y(0.95)
	if not _focused("Training Grounds"):
		return _fail("Holding the stick skipped past the next station destination.")
	_stick_y(0.0)
	_stick_y(-0.9)
	_stick_y(0.0)
	if not _focused("Barracks"):
		return _fail("The stick did not re-arm after returning to neutral.")
	_joy(JOY_BUTTON_A)
	if _title._page != Title.Page.BARRACKS:
		return _fail("The Barracks must open its own page.")
	var job_action := _button("BarracksJobAction")
	if not _button("JobShieldInfantry") or not _button("JobMarchesLongbows") \
			or not job_action or job_action.visible:
		return _fail("The station must open an inspectable tree without inventing a live job action.")
	_joy(JOY_BUTTON_B)
	if not _station_shell() or not _focused("Barracks"):
		return _fail("Controller Back from Barracks must restore the station and its originating focus.")
	if not _press("Training Grounds") or _title._page != Title.Page.STATION_TRAINING or _button("Read Dispatch") \
			or not _press("Combat Drills") or _title._page != Title.Page.DRILLS or not _press("Back") \
			or _title._page != Title.Page.STATION_TRAINING or not _press("Unit Progression") \
			or _title._page != Title.Page.UNIT_PROGRESSION or not _press("Back") \
			or _title._page != Title.Page.STATION_TRAINING or not _press("Back") or not _station_shell():
		return _fail("Training Grounds must separately host the existing drills and own their Back target.")
	return true


func _station_shell() -> bool:
	return _title._page == Title.Page.STATION and _button("Operations") != null and _button("Barracks") != null \
		and _button("Training Grounds") != null and _button("Main Gate") != null \
		and not _button("Confirm Deployment") and not _button("Read Dispatch") \
		and not _button("Confirm Training (1 drill credit)") and not _title._campaign_battle


func _make_title(campaign: String, authored: bool) -> void:
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_path)
	if authored:
		_title.set_development_overworld_factory(_make_map)
	root.add_child(_title)
	TitleFlow.resume_at_map(_title, campaign)


func _make_map(_world: World) -> Marches:
	var map := Marches.new()
	if map.build():
		return map
	map.free()
	return null


func _map() -> Node:
	return _title._stage.get_child(0)


func _on_map(waypoint: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _title._campaign_world.current_waypoint_id() == waypoint


func _hover_marker(map: Marches, id: String) -> bool:
	var projected := map._projections()
	if not projected.has(id):
		return false
	var event := InputEventMouseMotion.new()
	event.position = map.get_global_transform_with_canvas() * projected[id]
	root.push_input(event, true)
	return true


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _stick_y(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	root.push_input(event, true)


func _focused(label: String) -> bool:
	return root.gui_get_focus_owner() == _button(label) and _button(label) != null


func _button(label: String) -> Button:
	return _title._stage.find_child(label, true, false) as Button


func _press(label: String) -> bool:
	var button := _button(label)
	if not button or button.disabled:
		return false
	button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
