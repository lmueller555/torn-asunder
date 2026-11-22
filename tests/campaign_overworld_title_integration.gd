extends SceneTree

const CampaignFlow := preload("res://tests/campaign_flow_helpers.gd")
const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Pilot := preload("res://game/campaign_overworld_3d.gd")
const CampaignMap := preload("res://game/campaign_map.gd")
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Mission := preload("res://game/battlefield/mara_greyhollow_rescue.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const ROAD := "marches_road"
const CROSSING := "marches_crossing"
const CLEAR := "mara_mine_escort"

var _title: Title
var _save_path: String
var _points: Dictionary[String, Vector3] = {}
var _curves: Dictionary[String, Curve3D] = {}
var _pace: float
var _renderer: PackedScene


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _build_fixture():
		_fail("Could not pack the camera and party anchors.")
		quit(1)
		return
	_save_path = OS.get_temp_dir().path_join("torn-overworld-integration-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec()
	])
	var profile := Profile.new(_save_path)
	var passed := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", false) == OK \
		and profile.mark_played("raska") == OK and profile.record_mission_clear("raska", "orc_mine_witness") == OK
	if passed:
		_make_title(true)
		passed = await _opening()
	if passed:
		passed = await _reload_and_return()
	if is_instance_valid(_title):
		_title.queue_free()
		await process_frame
	for path in [_save_path, _save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Private overworld: campaign resume, curved travel and cancel, gated road, saved arrival, explicit Greyhollow deployment, retreat, mandatory reload dialogue, reduced-motion, and 2D fallback passed.")
	quit(0 if passed else 1)


func _opening() -> bool:
	CampaignFlow.resume_at_map(_title, "mara")
	if not _on_pilot(CAMP):
		return _fail("Resume did not start the injected Mara overworld.")
	await process_frame
	var map := _pilot()
	map.set_process(false)
	var before_travel := FileAccess.get_file_as_string(_save_path)
	_click_marker(map, MINE)
	_key(KEY_ENTER)
	if not map._navigation.is_travelling() or _location() != CAMP:
		return _fail("Mouse selection and keyboard confirm did not start travel.")
	var curve := _curves[Pilot.route_key(CAMP, MINE)]
	var duration := curve.get_baked_length() / _pace
	map._process(duration * 0.5)
	var expected := curve.sample_baked(curve.get_baked_length() * 0.5)
	if not map._party.global_position.is_equal_approx(map._renderer.to_global(expected)) or _location() != CAMP:
		return _fail("The injected party did not follow the authored world-space curve before arrival.")
	_joy(JOY_BUTTON_B)
	if not _on_pilot(CAMP) or map._navigation.is_travelling() \
			or not map._party.global_position.is_equal_approx(map._renderer.to_global(_points[CAMP])) \
			or _title._campaign_world.visited_waypoint_ids() != PackedStringArray([CAMP]) \
			or FileAccess.get_file_as_string(_save_path) != before_travel:
		return _fail("Cancel changed the title, profile, party origin, or graph progress.")
	_joy(JOY_BUTTON_A)
	map._process(duration)
	if not _on_pilot(MINE) or _location() != MINE or _button("Confirm Deployment") \
			or not _title._profile.completed_missions("mara").is_empty():
		return _fail("Arrival must save immediately and stay on the map without awarding a clear.")
	if Profile.new(_save_path).completed_missions("raska") != PackedStringArray(["orc_mine_witness"]):
		return _fail("Saving the pilot arrival changed existing chapter progress in the profile.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_joy(JOY_BUTTON_A)
	if map._navigation.selected_waypoint_id() != ROAD or map.confirm_button.text != "Road Locked" \
			or map._navigation.is_travelling() or _location() != MINE:
		return _fail("The controller did not expose the locked Road into the Marches without advancing.")
	_click_marker(map, MINE)
	_key(KEY_ENTER)
	if _title._page != Title.Page.MISSION_BRIEFING or _title._campaign_battle:
		return _fail("Explicit map confirm must open briefing without launching combat.")
	_joy(JOY_BUTTON_B)
	if not _on_pilot(MINE):
		return _fail("Backing out of briefing must restore the pilot at Mine.")
	_joy(JOY_BUTTON_A)
	if not _press("Confirm Deployment") or not (_title._campaign_battle is Mission):
		return _fail("Confirm Deployment did not launch the existing Greyhollow battlefield.")
	await physics_frame
	_key(KEY_ESCAPE)
	if not PauseTest.confirm_leave(_title._pause_menu) or not _on_pilot(MINE) or _location() != MINE \
			or not _title._profile.completed_missions("mara").is_empty():
		return _fail("Retreat should return to the same saved waypoint with the chapter unchanged.")
	return true


func _reload_and_return() -> bool:
	# Seed the existing post-victory save transaction to exercise mandatory dialogue on reload.
	if _title._profile.record_greyhollow_rescue_clear() != OK or _title._profile.set_setting("reduced_motion", true) != OK:
		return _fail("Could not seed the saved victory and reduced-motion settings.")
	_title.queue_free()
	await process_frame
	_make_title(true)
	if not _press("Continue") or _title._page != Title.Page.CAMPAIGN_DIALOGUE or _button("Confirm Deployment"):
		return _fail("Continue must honor the saved mandatory reveal before any briefing.")
	var dialogue := _title._stage.get_child(0) as Dialogue
	if not dialogue or dialogue._beat_id != Beats.MARA_MINE_DEBRIEF:
		return _fail("Expected the original Greyhollow reveal on reload.")
	dialogue.cancel()
	if not _on_pilot(MINE) or _title._profile.greyhollow_reveal_pending() \
			or _title._profile.completed_missions("mara") != PackedStringArray([CLEAR]):
		return _fail("Completing the reveal did not restore the saved map and chapter state.")
	await process_frame
	_joy(JOY_BUTTON_DPAD_RIGHT)
	_joy(JOY_BUTTON_A)
	if not _on_pilot(ROAD) or _location() != ROAD or _pilot()._navigation.is_travelling():
		return _fail("Reduced motion must use the same unlocked route and commit the saved destination immediately.")
	_joy(JOY_BUTTON_DPAD_LEFT)
	_joy(JOY_BUTTON_A)
	if not _on_pilot(MINE) or _location() != MINE:
		return _fail("The same authored curve must support reverse traversal.")
	var outside := World.new("mara", CROSSING, PackedStringArray([CLEAR]))
	if _title._profile.record_world_waypoint(outside) != OK:
		return _fail("Could not prepare an existing save outside pilot coverage.")
	_joy(JOY_BUTTON_B)
	if not _press("Continue") or _pilot() or not _title._stage.get_child(0) is CampaignMap or _location() != CROSSING:
		return _fail("A save outside the pilot must reopen on the existing 2D map.")
	if _title._profile.record_world_waypoint(World.new("mara", MINE)) != OK:
		return _fail("Could not prepare a saved position inside the pilot area.")
	_title.queue_free()
	await process_frame
	_make_title(false)
	if not _press("Continue") or _pilot() or not _title._stage.get_child(0) is CampaignMap \
			or _title._campaign_world.current_waypoint_id() != MINE:
		return _fail("Normal title startup must use the existing 2D map at the saved pilot waypoint.")
	return true


func _build_fixture() -> bool:
	_points = {CAMP: Vector3(-13, 0, 0), MINE: Vector3.ZERO, ROAD: Vector3(13, 0, 0)}
	_curves[Pilot.route_key(CAMP, MINE)] = _curve(CAMP, Vector3(-7, 3, -6), MINE)
	_curves[Pilot.route_key(MINE, ROAD)] = _curve(MINE, Vector3(6, 1, -4), ROAD)
	_pace = 5.0
	var node := Node3D.new()
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 28.0, 26.0)).looking_at(Vector3.ZERO)
	node.add_child(camera)
	camera.owner = node
	var party := Node3D.new()
	party.name = "Party"
	node.add_child(party)
	party.owner = node
	_renderer = PackedScene.new()
	var result := _renderer.pack(node)
	node.free()
	return result == OK


func _curve(origin: String, bend: Vector3, target: String) -> Curve3D:
	var curve := Curve3D.new()
	curve.add_point(_points[origin])
	curve.add_point(bend)
	curve.add_point(_points[target])
	return curve


func _make_title(injected: bool) -> void:
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_save_path)
	if injected:
		_title.set_development_overworld_factory(_make_pilot)
	root.add_child(_title)


func _make_pilot(world: World) -> Pilot:
	if world.campaign_id() != "mara":
		return null
	var view := Pilot.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.map_surface = SubViewportContainer.new()
	view.map_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.map_surface.offset_left = 64.0
	view.map_surface.offset_top = 80.0
	view.map_surface.offset_right = -32.0
	view.map_surface.offset_bottom = -32.0
	view.map_surface.stretch = true
	view.add_child(view.map_surface)
	view.render_viewport = SubViewport.new()
	view.render_viewport.own_world_3d = true
	view.map_surface.add_child(view.render_viewport)
	var controls := HBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(controls)
	view.status_label = Label.new()
	controls.add_child(view.status_label)
	view.confirm_button = Button.new()
	controls.add_child(view.confirm_button)
	view.back_button = Button.new()
	controls.add_child(view.back_button)
	if view.configure_renderer(_renderer, ^"Camera", ^"Party", _points, _curves, _pace):
		return view
	view.free()
	return null


func _pilot() -> Pilot:
	return _title._stage.get_child(0) as Pilot


func _on_pilot(id: String) -> bool:
	return _title._page == Title.Page.WORLD_MAP and _pilot() != null and _title._campaign_world.current_waypoint_id() == id


func _location() -> String:
	return Profile.new(_save_path).load_campaign_world("mara").current_waypoint_id()


func _button(name: String) -> Button:
	return _title._stage.find_child(name, true, false) as Button


func _press(name: String) -> bool:
	var button := _button(name)
	if not button or button.disabled:
		return false
	button.pressed.emit()
	return true


func _click_marker(map: Pilot, id: String) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	var world_point := map._renderer.to_global(_points[id])
	var projected := map._camera.unproject_position(world_point)
	var surface_point := projected * map.map_surface.size / Vector2(map.render_viewport.size)
	event.position = map.map_surface.get_global_transform_with_canvas() * surface_point
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
