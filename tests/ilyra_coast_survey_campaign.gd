extends SceneTree

const Scene := preload("res://game/battlefield/ilyra_coast_survey_campaign.tscn")
const Mission := preload("res://game/battlefield/ilyra_coast_survey_campaign.gd")
const Deployment := preload("res://game/campaign_deployments.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Survey := preload("res://game/battlefield/ilyra_coast_survey.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0
const BEACH := Survey.SignalSite.BEACH
const HEADLAND := Survey.SignalSite.HEADLAND
const ANCESTRAL := Survey.Reading.ANCESTRAL_STONE
const INLET := Survey.Reading.FISHING_INLET
const STONE_PATH := ["Routes/StoneTrailTurn", "Objectives/AncestralStone"]
const INLET_PATH := ["Routes/StoneExit", "Routes/InletTrailTurn", "Objectives/FishingInlet"]
const BEACH_PATH := ["Routes/InletBeachTurn", "Objectives/BeachSignal"]
const HEADLAND_PATH := ["Routes/InletBacktrack", "Routes/HeadlandInlandCut", "Routes/HeadlandLandwardTurn",
	"Routes/HeadlandRampFoot", "Routes/HeadlandRampTop", "Routes/HeadlandApron", "Routes/HighGuard", "Objectives/HeadlandSignal"]
const DETACHMENT_ROAD := ["Routes/InlandJunction", "Routes/MidCoastLane"]
const DETACHMENT_BEACH := ["Routes/InletFork", "Routes/InletBacktrack", "Routes/BeachGuard"]
const DETACHMENT_HEADLAND := ["Routes/HeadlandRoadFork", "Routes/HeadlandLandwardTurn",
	"Routes/HeadlandRampFoot", "Routes/HeadlandRampTop", "Routes/HeadlandApron", "Routes/HighGuard"]

const CHART_PINS: Array[StringName] = [&"ancestral_stone", &"fishing_inlet", &"beach_relay", &"headland_relay"]
const PIN_PATHS := {
	&"ancestral_stone": "Objectives/AncestralStone", &"fishing_inlet": "Objectives/FishingInlet",
	&"beach_relay": "Objectives/BeachSignal", &"headland_relay": "Objectives/HeadlandSignal",
}

var _mission: Mission
var _capture_dir := ""
var _results: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_dir = arg.trim_prefix("--capture=")
	var deployment := Deployment.for_mission(Survey.MISSION_ID)
	if deployment.scene != Scene:
		_fail("Test the actual registered Two Shorelines mission and both relay placements.")
		quit(1)
		return
	_mission = deployment.scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_cleared.connect(func(value: StringName) -> void: _results.append(value))
	if not await _check_minimap() or not _check_beach_billboard_presentation() or not _visit_both() \
			or not await _reach_contested_beach():
		quit(1)
		return
	var obstruction := _place_test_obstruction()
	await physics_frame
	await physics_frame
	var blocked := _test_occluded_stop()
	obstruction.queue_free()
	await physics_frame
	await physics_frame
	var passed := blocked and await _finish_beach_and_retry() and _visit_both() and _take_headland() and _check_retry()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Two Shorelines: registered passive tactical map, real hero/formation routes, manual readings, moving cutter and missed loop, solid LOS, pressure, interrupted signal, both relay clears and retry passed.")
	quit(0 if passed else 1)


func _check_minimap() -> bool:
	var map := _mission._minimap
	var panel := _mission._minimap_panel
	if not map or not panel or not _map_hidden():
		return _fail("The registered hero starts with the minimap absent from the HUD.")
	var hero_before := await _capture_frame("hero-before-command")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await process_frame
	if not _map_context([]):
		return _fail("Initial command map should contain only the two friendlies and a live camera footprint.")
	if not root.get_visible_rect().encloses(panel.get_global_rect()) or not panel.get_global_rect().encloses(map.get_global_rect()):
		return _fail("Command minimap no longer fits the resized game viewport.")
	for path in ["HUD/Panel", "ObjectiveHUD/Panel"]:
		if panel.get_global_rect().intersects(_mission.get_node(path).get_global_rect()):
			return _fail("Command minimap covered " + path)
	var motion := InputEventMouseMotion.new()
	motion.position = map.get_global_rect().get_center()
	root.push_input(motion, true)
	if not _mission._mouse_cursor_active:
		return _fail("The passive map captured mouse movement instead of passing it to the world.")
	var sector := map.sector_pixels()
	_axis(JOY_AXIS_RIGHT_X, 0.8)
	_tick(15)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	if map.sector_pixels() == sector or map.sector_pixels().is_empty():
		return _fail("The drawn sector did not follow the actual command camera orbit.")
	await _capture_frame("command-before-readings")
	_joy(JOY_BUTTON_RIGHT_STICK)
	if not _mission._sector.overview or not _map_context([]):
		return _fail("The ordinary field overview no longer retains its minimap or camera controls.")
	await _capture_frame("command-overview")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	if not _map_hidden():
		return _fail("Hero view must remove the map and its frame immediately.")
	var hero_after := await _capture_frame("hero-after-command")
	if hero_before and hero_after and hero_before.get_data() != hero_after.get_data():
		return _fail("Command map left a pixel change in the unchanged hero view.")
	_mission.restart_mission()
	return true


func _map_context(pins: Array[StringName]) -> bool:
	var map := _mission._minimap
	var side := _mission.battle.formations[0]
	if not map.is_visible_in_tree() or map.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			or _mission._minimap_panel.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			or map.click_to_focus or map.right_click_to_move or map.sector_pixels().is_empty() \
			or map._glyphs.size() != 2 + pins.size():
		return false
	var center := map.marker_pixel(&"ilyra") as Vector2
	var detachment := map.marker_pixel(&"shore_detachment") as Vector2
	if not center.is_equal_approx(map.project(_mission.battle.hero_position)) \
			or not detachment.is_equal_approx(map.project(side.position)):
		return false
	for glyph in map._glyphs:
		if glyph.icon == Minimap.Icon.ENEMY or (glyph.id == &"shore_detachment" and not glyph.selected):
			return false
	for pin in pins:
		var marker: Variant = map.marker_pixel(pin)
		if not marker is Vector2 or not marker.is_equal_approx(map.project(_xz(_point(PIN_PATHS[pin])))):
			return false
	return true


func _map_hidden() -> bool:
	return not _mission._minimap.is_visible_in_tree() and _mission._minimap._glyphs.is_empty() \
		and _mission._minimap.sector_pixels().is_empty()


func _capture_frame(name: String) -> Image:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return null
	for _frame in 6:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(_capture_dir.path_join(name + ".png")) != OK:
		_fail("Cannot save minimap QA capture: " + name)
	return image


func _check_beach_billboard_presentation() -> bool:
	var styles := _mission._beach_billboards
	if styles.size() != 2 or styles[0].label.get_parent() != _mission._signal_flags[0] \
			or styles[1].label.get_parent() != _mission._crews[0]:
		return _fail("Only the Beach Signal and its own port crew billboards should be bound.")
	var beach: Label3D = styles[0].label
	var crew: Label3D = styles[1].label
	if not _walk_routes(STONE_PATH + INLET_PATH):
		return false
	if not beach.visible or beach.modulate != styles[0].face or crew.modulate != styles[1].face:
		return _fail("Distant hero route must retain the original nameplates.")
	var inlet := _point("Objectives/FishingInlet")
	var turn := _point("Routes/InletBeachTurn")
	if not _walk_to(inlet.lerp(turn, 0.75)):
		return false
	if not beach.visible or beach.modulate.a <= 0.1 or beach.modulate.a >= 0.9 \
			or not is_equal_approx(beach.outline_modulate.a, styles[0].outline.a * beach.modulate.a):
		return _fail("The beach caption should gradually fade along the actual approach.")
	if not _walk_routes(BEACH_PATH):
		return false
	_key(KEY_SPACE)
	_tick()
	if beach.visible or crew.visible or _mission._crews[0].visible \
			or _mission.objective.phase != Survey.Phase.TAKING_READINGS \
			or not _mission._hint.text.contains("First find"):
		return _fail("Up close, neither label should cover the unchanged pre-reading lock and ring.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	for style in styles:
		if style.label.visible != style.visible or style.label.modulate != style.face \
				or style.label.outline_modulate != style.outline:
			return _fail("Entering command must restore original caption style immediately.")
	if not _mission.command_view or _mission._crews[0].visible:
		return _fail("Restoring a crew caption must not show a crew that hasn't spawned.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if beach.visible or crew.visible:
		return _fail("Returning to the nearby hero must recede both labels again.")
	_key(KEY_BACKSPACE)
	return (_fresh_state() and beach.visible and crew.visible) \
		or _fail("Return to distant spawn did not restore original label visibility.")


func _visit_both() -> bool:
	var cutter_start := _point("BoatRoute/WestBlindPass")
	if _mission._field.name != &"MoonwashSurveyShore" or _mission.battle.formations.size() != 1 \
			or not _mission.hero_world_position().is_equal_approx(_point("Spawns/Ilyra")):
		return _fail("The standalone story did not mount its own field, hero and detachment.")
	_key(KEY_SPACE)
	_tick(45)
	if _mission._cutter.global_position != cutter_start or _mission.objective.has_reading(ANCESTRAL):
		return _fail("The cutter or reading advanced without an inspection at the marker.")
	if not _walk_routes(STONE_PATH):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key(KEY_SPACE)
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.has_reading(ANCESTRAL):
		return _fail("Command view interpreted Hold as a hero inspection.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_joy(JOY_BUTTON_A)
	_tick()
	if not _mission.objective.has_reading(ANCESTRAL) or _mission._cutter.global_position != cutter_start \
			or _mission._clear_signal_ray(0):
		return _fail("Only the actual first reading should launch from the obstructed west pass.")
	_tick(12)
	if _mission._cutter.global_position.distance_to(cutter_start) < 1.0:
		return _fail("The cutter was flagged without physically sailing.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	if not _map_context([&"ancestral_stone"]):
		return _fail("One reading should reveal that pin only, not the inlet, cutter or either relay.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _walk_routes(INLET_PATH):
		return false
	if _mission.objective.has_reading(INLET) or _mission._pressuring:
		return _fail("Walking over the inlet silently recorded it or brought in pressure.")
	_key(KEY_SPACE)
	_tick()
	if not _mission.objective.has_reading(INLET) or not _mission._pressuring \
			or _mission.objective.phase != Survey.Phase.WAITING_TO_SIGNAL:
		return _fail("Second reading did not start the relay phase.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var chart_visible := _map_context(CHART_PINS)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return chart_visible or _fail("Both read sites and relay choices should appear only when the chart is ready.")


func _reach_contested_beach() -> bool:
	if not _walk_routes(BEACH_PATH):
		return false
	# Wait for an actually occluded pass before trying. No signal may start then.
	if not _wait(func() -> bool: return not _mission._clear_signal_ray(0), "west headland occlusion"):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Survey.Phase.WAITING_TO_SIGNAL or not _mission._shore.text.contains("sightline obstructed"):
		return _fail("Confirming through a solid headland acted like an open-water transmission.")
	if not _wait(func() -> bool: return _mission._holding_site == BEACH and _mission._contested(0), "contested beach hold"):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.interruption != Survey.Interruption.CONTESTED or _mission.objective.signal_progress != 0.0 \
			or _mission._crews[0].global_position.distance_to(_point("Objectives/BeachSignal")) > Mission.CONTEST_RADIUS:
		return _fail("A real landing crew did not deny the beach relay.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	if not _map_context(CHART_PINS) or not _mission._crews[0].visible or not _mission._sea_guides.visible:
		return _fail("The map showed a contested crew, cutter or route, or changed the existing 3D command guides.")
	await _capture_frame("command-contested-beach")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if not _move_detachment(DETACHMENT_ROAD + DETACHMENT_BEACH):
		return false
	if not _mission._screened(0) or _mission._contested(0):
		return _fail("The holding detachment did not secure the beach.")
	if not _wait(func() -> bool: return _mission._holding_site != BEACH, "old beach stop departure"):
		return false
	if not _wait(func() -> bool: return _mission._site_status(0) == "cutter approaching", "visible advance warning"):
		return false
	if not _wait(func() -> bool: return _mission._holding_site == BEACH, "next beach hold"):
		return false
	return _mission._cutter.global_position == _point("BoatRoute/BeachHold") \
		or _fail("Beach acknowledgment used a nominal waypoint, not the stopped hull.")


func _place_test_obstruction() -> StaticBody3D:
	# The real hold is ordinarily visible; insert a solid behind the relay to
	# distinguish the LOS requirement from cutter-at-stop or authored route state.
	var screen := StaticBody3D.new()
	var block := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 11, 5)
	block.shape = box
	screen.add_child(block)
	_mission.add_child(screen)
	var middle := _point("Objectives/BeachSignal").lerp(_point("BoatRoute/BeachHold"), 0.55)
	screen.global_position = middle + Vector3.UP * 3
	return screen


func _test_occluded_stop() -> bool:
	_key(KEY_SPACE)
	_tick()
	return (_mission._holding_site == BEACH and not _mission._clear_signal_ray(0) \
		and _mission.objective.interruption == Survey.Interruption.LINE_OF_SIGHT_BLOCKED \
		and _mission.objective.phase == Survey.Phase.WAITING_TO_SIGNAL) \
		or _fail("An in-position cutter was credited through an actual solid obstruction.")


func _finish_beach_and_retry() -> bool:
	_tick(50)
	if _mission.objective.signal_progress != 0.0 or not _mission._clear_signal_ray(0) or not _results.is_empty():
		return _fail("Removing the obstruction started the signal without manual confirmation.")
	_joy(JOY_BUTTON_A)
	_tick(60)
	var before_command := _mission.objective.signal_progress
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_A)
	_tick(15)
	if not _mission.command_view or _mission.objective.phase != Survey.Phase.SIGNALING \
			or _mission.objective.signal_progress <= before_command:
		return _fail("An active, staffed relay paused or restarted in command view.")
	if not _map_context(CHART_PINS):
		return _fail("An active transmission changed the passive chart or added a cutter contact.")
	await _capture_frame("command-transmitting-beach")
	if not _wait(func() -> bool: return _mission.objective.phase == Survey.Phase.SUCCEEDED, "beach acknowledgment"):
		return false
	_tick(10)
	if _results != [Mission.CHART_CIRCULATED] or not _mission._shore.text.contains("acknowledged") or not _map_hidden():
		return _fail("Beach clear did not acknowledge once.")
	_joy(JOY_BUTTON_START)
	return _fresh_state()


func _take_headland() -> bool:
	if not _walk_routes(HEADLAND_PATH):
		return false
	if _mission.hero_world_position().y < 7.1 or not _move_detachment(DETACHMENT_ROAD + DETACHMENT_HEADLAND):
		return false
	if not _mission._screened(1) or not _wait(func() -> bool: return _mission._contested(0), "independent beach pressure"):
		return false
	if not _wait(func() -> bool: return not _mission._clear_signal_ray(1), "east headland occlusion"):
		return false
	if not _wait(func() -> bool: return _mission._holding_site == HEADLAND, "headland hold"):
		return false
	if _mission._cutter.global_position != _point("BoatRoute/HeadlandHold"):
		return _fail("Headland signal did not use the separate physical cutter stop.")
	_tick(45)
	if _mission.objective.phase != Survey.Phase.WAITING_TO_SIGNAL:
		return _fail("Headland sent the chart before manual confirmation.")
	_joy(JOY_BUTTON_A)
	_tick(18)
	if _mission.objective.signal_site != HEADLAND or _mission.objective.signal_progress <= 0.0:
		return _fail("The secured high site could not transmit while the beach was contested.")
	if not _walk("Routes/HighGuard"):
		return false
	if _mission.objective.interruption != Survey.Interruption.UNSTAFFED or _mission.objective.signal_progress != 0.0 \
			or not _mission.objective.has_reading(ANCESTRAL) or not _mission.objective.has_reading(INLET):
		return _fail("Leaving the signal abandoned either no progress or the complete chart.")
	if not _walk("Objectives/HeadlandSignal"):
		return false
	_key(KEY_SPACE)
	if not _wait(func() -> bool: return _mission.objective.phase == Survey.Phase.SUCCEEDED, "headland acknowledgment"):
		return false
	return _results == [Mission.CHART_CIRCULATED, Mission.CHART_CIRCULATED] \
		or _fail("Headland route could not clear the mission independently.")


func _check_retry() -> bool:
	_key(KEY_BACKSPACE)
	return _fresh_state()


func _fresh_state() -> bool:
	return (_mission.objective.phase == Survey.Phase.TAKING_READINGS and not _mission.objective.has_reading(ANCESTRAL) \
		and not _mission.objective.has_reading(INLET) and not _mission._cutter_launched and not _mission.command_view \
		and _mission.battle.formations.size() == 1 and not _mission._pressuring and _map_hidden() \
		and _mission._cutter.global_position == _point("BoatRoute/WestBlindPass") \
		and _mission.hero_world_position().is_equal_approx(_point("Spawns/Ilyra")) \
		and _mission.battle.formations[0].position == _xz(_point("Spawns/ShoreDetachment"))) \
		or _fail("Retry retained reading, order, cutter, camera or pressure state.")


func _move_detachment(paths: Array) -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var detachment: Battle.Formation = _mission.battle.formations[0]
	for path: String in paths:
		var target := _xz(_point(path))
		_mission.cursor = target
		_joy(JOY_BUTTON_X)
		if detachment.order != Battle.Order.MOVE:
			return _fail("Square did not issue a tactical Move.")
		_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
		var budget := ceili(detachment.position.distance_to(target) / Battle.FORMATION_SPEED / DT) + 4
		for _step in range(budget):
			if detachment.order != Battle.Order.MOVE:
				break
			_tick()
		if detachment.position != target:
			return _fail("Detachment geometry blocked %s at %s." % [path, detachment.position])
		_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	return detachment.order == Battle.Order.HOLD or _fail("Cross did not keep the detachment at the guard marker.")


func _walk_routes(paths: Array) -> bool:
	for path: String in paths:
		if not _walk(path):
			return false
	return true


func _walk(path: String) -> bool:
	return _walk_to(_point(path)) or _fail("Ilyra could not walk to %s from %s." % [path, _mission.hero_world_position()])


func _walk_to(point: Vector3) -> bool:
	var target := _xz(point)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 105
	for _step in range(budget):
		var remaining := target - _mission.battle.hero_position
		if remaining.length() < 0.12:
			break
		var motion := remaining.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, motion.x)
		_axis(JOY_AXIS_LEFT_Y, motion.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _mission.hero_world_position().distance_to(point) < 0.15


func _wait(condition: Callable, description: String) -> bool:
	for _step in range(5100):
		if condition.call():
			return true
		_tick()
	return _fail("Timed out waiting for %s." % description)


func _point(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _xz(world: Vector3) -> Vector2:
	var point := _mission.to_local(world)
	return Vector2(point.x, point.z)


func _tick(count := 1) -> void:
	for _step in range(count):
		_mission._physics_process(DT)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
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


func _fail(message: String) -> bool:
	push_error(message)
	return false
