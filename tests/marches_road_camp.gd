extends SceneTree

const Camp := preload("res://game/overworld/forward_campaign_camp.gd")
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Marches := preload("res://game/overworld/marches_overworld_view.gd")
const World := preload("res://game/campaign_world.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Map2D := preload("res://game/campaign_map.gd")
const MINE := "year_one_mine"

var _path: String
var _title: Title
var _with_spur := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-road-camp-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_path)
	var passed := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", true) == OK
	if passed:
		passed = await _exercise(profile)
	if is_instance_valid(_title):
		_title.queue_free()
		await process_frame
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Marches Road Camp: persisted reveal gate, renderer binding, optional spur, services and return passed.")
	quit(0 if passed else 1)


func _exercise(profile: Profile) -> bool:
	var clears := PackedStringArray([Camp.MINE_CLEAR])
	if Camp.available_for("mara", PackedStringArray(), true) or Camp.available_for("raska", clears, true) \
			or Camp.available_for("mara", clears, false):
		return _fail("The camp must require Mara, the Mine clear, and the completed reveal.")
	if profile.record_mission_clear("mara", Camp.MINE_CLEAR) != OK or profile.mark_played("mara") != OK:
		return _fail("Could not seed legacy Mara chapter progress.")
	if profile.record_world_waypoint(World.new("mara", Camp.ROAD, clears)) != OK:
		return _fail("Could not seed the pre-existing Road save ID.")
	_make_title(true)
	if not _press("Continue") or not _map() or _map().active_forward_camp() \
			or _map().select_waypoint(Camp.ROAD_CAMP) or _title._profile.greyhollow_reveal_completed():
		return _fail("A legacy clear without a reveal record exposed the forward camp.")
	if _title._profile.record_greyhollow_rescue_clear() != OK or _title._profile.greyhollow_reveal_completed():
		return _fail("A pending mandatory reveal must leave the camp unavailable.")
	_title.queue_free()
	await process_frame
	_make_title(true)
	if not _press("Continue") or _title._page != Title.Page.CAMPAIGN_DIALOGUE:
		return _fail("Reload must show the mandatory reveal before the pilot.")
	var dialogue := _title._stage.get_child(0) as Dialogue
	if not dialogue:
		return _fail("Expected the actual campaign dialogue scene.")
	dialogue.cancel() # The reveal's existing skip action acknowledges completion.
	var map := _map()
	if not map or not map.active_forward_camp() or not Profile.new(_path).greyhollow_reveal_completed():
		return _fail("Acknowledging the real reveal did not unlock the authored spur.")
	if _title._campaign_world.visited_waypoint_ids() != PackedStringArray(["marches_camp", Camp.ROAD]):
		return _fail("The test must restore Road without visiting Mine in this session.")

	var save := FileAccess.get_file_as_string(_path)
	var story_arrivals: Array[String] = []
	map.waypoint_arrived.connect(func(id: String) -> void: story_arrivals.append(id))
	map.forward_camp_operations_requested.emit(Camp.ROAD_CAMP)
	if _title._page != Title.Page.WORLD_MAP:
		return _fail("The junction cannot open camp services before the party arrives.")
	if not map.select_waypoint(Camp.ROAD_CAMP):
		return _fail("The available forward camp was not selectable.")
	map.confirm_selection()
	if not map.is_at_forward_camp(Camp.ROAD_CAMP) or _title._campaign_world.current_waypoint_id() != Camp.ROAD \
			or not story_arrivals.is_empty() or FileAccess.get_file_as_string(_path) != save:
		return _fail("Optional camp arrival must keep the canonical Road and leave the profile untouched.")
	if not map.select_waypoint(MINE):
		return _fail("Expected to inspect the Mine marker from the camp.")
	map.confirm_selection()
	if not map.is_at_forward_camp(Camp.ROAD_CAMP):
		return _fail("The forward camp bypassed its only return edge.")
	if not map.select_waypoint(Camp.ROAD_CAMP):
		return _fail("Expected to reselect the current camp.")
	map.confirm_selection()
	if _title._page != Title.Page.BRIEFING or _button("Read Dispatch") or _button("Confirm Deployment") \
			or not _button("Combat Drills") or not _button("Unit Progression"):
		return _fail("Forward camp should expose only its existing services.")
	if not _press("Unit Progression") or _title._page != Title.Page.UNIT_PROGRESSION or not _press("Back") \
			or not _button("Combat Drills") or not _press("Back") or not _map().is_at_forward_camp(Camp.ROAD_CAMP):
		return _fail("Back through a camp service must return to the same local camp.")
	map = _map()
	if not map.select_waypoint(Camp.ROAD):
		return _fail("The spur lost its canonical return edge.")
	map.confirm_selection()
	if map._world.current_waypoint_id() != Camp.ROAD or FileAccess.get_file_as_string(_path) != save \
			or Profile.new(_path).completed_missions("mara") != clears:
		return _fail("Return from the optional spur changed saved position or chapter progress.")
	if not map.select_waypoint(MINE):
		return _fail("The spur removed the normal road back to Mine.")
	map.confirm_selection()
	if Profile.new(_path).load_campaign_world("mara").current_waypoint_id() != MINE \
			or not map.select_waypoint(Camp.ROAD):
		return _fail("An active optional spur must still allow canonical travel and saves.")
	map.confirm_selection()
	if Profile.new(_path).load_campaign_world("mara").current_waypoint_id() != Camp.ROAD:
		return _fail("Canonical travel must still save the pre-existing Road waypoint ID.")
	_title.queue_free()
	await process_frame
	_with_spur = false
	_make_title(true)
	if not _press("Continue") or not _map() or _map().active_forward_camp():
		return _fail("The existing art without an authored path must hide the camp.")
	_title.queue_free()
	await process_frame
	_make_title(false)
	if not _press("Continue") or not _title._stage.get_child(0) is Map2D \
			or not _title._campaign_world.waypoint(Camp.ROAD_CAMP).is_empty():
		return _fail("Default 2D navigation must preserve the unmodified campaign graph.")
	return true


func _make_title(injected: bool) -> void:
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_path)
	if injected:
		_title.set_development_overworld_factory(_make_map)
	root.add_child(_title)


func _make_map(_world: World) -> Marches:
	var map := Marches.new()
	if not map.build():
		map.free()
		return null
	if _with_spur:
		# The diagnostic anchor and curve exist only in this test instance.
		var road := map._points[Camp.ROAD]
		var endpoint := road + Vector3(15, 2, -9)
		var curve := Curve3D.new()
		curve.add_point(road)
		curve.add_point(endpoint)
		map._points[Camp.ROAD_CAMP] = endpoint
		map._curves[map.route_key(Camp.ROAD, Camp.ROAD_CAMP)] = curve
	return map


func _map() -> Marches:
	return _title._stage.get_child(0) as Marches


func _button(name: String) -> Button:
	return _title._stage.find_child(name, true, false) as Button


func _press(name: String) -> bool:
	var button := _button(name)
	if not button or button.disabled:
		return false
	button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
