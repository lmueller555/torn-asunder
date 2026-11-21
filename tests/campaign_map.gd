extends SceneTree

const Map := preload("res://game/campaign_map.gd")
const Board := preload("res://game/campaign_map_board.gd")
const MapScene := preload("res://game/campaign_map.tscn")
const World := preload("res://game/campaign_world.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const ROAD := "marches_road"
const CROSSING := "marches_crossing"
const MISSION := "mara_mine_escort"

var _view: Map
var _world := World.new("mara")
var _arrivals := PackedStringArray()
var _briefings := PackedStringArray()
var _returns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_view = MapScene.instantiate()
	var profile_path := "user://profile.cfg"
	var original_save := FileAccess.get_file_as_string(profile_path) if FileAccess.file_exists(profile_path) else ""
	var original_exists := FileAccess.file_exists(profile_path)
	var clears := PackedStringArray()
	_view.configure(_world, clears, false)
	_view.waypoint_arrived.connect(func(id: String) -> void: _arrivals.append(id))
	_view.briefing_requested.connect(func(id: String) -> void: _briefings.append(id))
	_view.return_requested.connect(func() -> void: _returns += 1)
	root.add_child(_view)
	await process_frame
	var passed := _exercise_flow(clears)
	if FileAccess.file_exists(profile_path) != original_exists \
			or (original_exists and FileAccess.get_file_as_string(profile_path) != original_save):
		passed = _fail("Map navigation wrote a profile file.")
	_view.queue_free()
	await process_frame
	if passed:
		print("Campaign map: pointer, keys and DualSense, animated arrival, next-leg emphasis, locked route, reduced motion, and briefing-only signals passed.")
	quit(0 if passed else 1)


func _exercise_flow(clears: PackedStringArray) -> bool:
	var camp: Vector2 = _world.waypoint(CAMP).map_position
	var mine: Vector2 = _world.waypoint(MINE).map_position
	var road: Vector2 = _world.waypoint(ROAD).map_position
	if _view.selected_waypoint_id() != CAMP or _view.token_map_position() != camp:
		return _fail("The map did not show the token at the camp on arrival.")
	# A real pointer press selects the drawn Mine node but cannot move the token.
	_click(_view._board, _view._board.point_at(mine))
	if _view.selected_waypoint_id() != MINE or _world.current_waypoint_id() != CAMP \
			or not _arrivals.is_empty() or not _briefings.is_empty() or _view.token_map_position() != camp:
		return _fail("Pointer selection moved the player or raised a briefing.")
	if _route_cue(CAMP, MINE) != Board.RouteCue.SELECTED_REACHABLE:
		return _fail("Selecting an adjacent, open destination did not emphasize its leg.")
	_key(KEY_ENTER)
	if not _view.is_travelling() or _world.current_waypoint_id() != CAMP or not _briefings.is_empty():
		return _fail("Confirm did not begin distinct travel before exposing the briefing.")
	_view._tween.pause()
	_view._tween.custom_step(0.12)
	if _view.token_map_position().is_equal_approx(camp) or _view.token_map_position().is_equal_approx(mine):
		return _fail("The token did not visibly interpolate between waypoints.")
	if _route_cue(CAMP, MINE) != Board.RouteCue.SELECTED_REACHABLE:
		return _fail("The outgoing leg stopped being emphasized before arrival.")
	_view._tween.custom_step(0.56)
	if _view.is_travelling() or not _view.token_map_position().is_equal_approx(mine) \
			or _world.current_waypoint_id() != MINE or _arrivals != PackedStringArray([MINE]) \
			or _briefings != PackedStringArray([MISSION]) or _view.find_child("MaraMineEscort", true, false):
		return _fail("Mine arrival did not raise exactly one separate briefing without deployment.")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	if _view.selected_waypoint_id() != ROAD or not _view._confirm_button.disabled \
			or not _view._detail.text.contains("Complete the Mine Escort"):
		return _fail("The controller could not inspect the visible road and its reason for being locked.")
	if _route_cue(MINE, ROAD) != Board.RouteCue.LOCKED \
			or _route_cue(ROAD, CROSSING) != Board.RouteCue.DISTANT \
			or _route_cue(CAMP, MINE) != Board.RouteCue.REACHABLE:
		return _fail("Selecting the locked road confused a locked, distant, or unselected available leg.")
	_joy(JOY_BUTTON_A)
	_click(_view._confirm_button, _view._confirm_button.size * 0.5)
	if _world.current_waypoint_id() != MINE or _arrivals.size() != 1 or _briefings.size() != 1 or not clears.is_empty():
		return _fail("Attempting locked travel moved the token or wrote a clear.")

	# In reduced-motion mode the same confirmation lands immediately, not on a tween.
	_view.configure(_world, clears, true)
	_view.set_completed_ids(PackedStringArray([MISSION]))
	_key(KEY_RIGHT)
	if _view.selected_waypoint_id() != ROAD or _view._confirm_button.disabled \
			or _world.current_waypoint_id() != MINE:
		return _fail("A real clear did not present the neighboring road without auto-travelling.")
	if _route_cue(MINE, ROAD) != Board.RouteCue.SELECTED_REACHABLE \
			or _route_cue(ROAD, CROSSING) != Board.RouteCue.DISTANT:
		return _fail("A clear highlighted the wrong leg from the current location.")
	_joy(JOY_BUTTON_A)
	if _view.is_travelling() or _view.token_map_position() != road or _world.current_waypoint_id() != ROAD \
			or _arrivals != PackedStringArray([MINE, ROAD]) or _briefings.size() != 1:
		return _fail("Reduced-motion travel still animated, missed its arrival or raised a non-battle briefing.")

	# Mouse confirms a return along a real edge; Escape and Circle are shell requests.
	_click(_view._board, _view._board.point_at(mine))
	_click(_view._confirm_button, _view._confirm_button.size * 0.5)
	if _world.current_waypoint_id() != MINE or _briefings != PackedStringArray([MISSION, MISSION]):
		return _fail("The mouse Travel button did not cross the enabled return edge.")
	_joy(JOY_BUTTON_A)
	if _arrivals.size() != 3 or _briefings.size() != 3:
		return _fail("Reopening the current battlefield's briefing incorrectly travelled again.")
	_key(KEY_ESCAPE)
	_joy(JOY_BUTTON_B)
	return _returns == 2 or _fail("Escape and Circle were not offered to the shell as return requests.")


func _route_cue(first: String, second: String) -> Board.RouteCue:
	for edge in _world.routes():
		if (edge.from_id == first and edge.to_id == second) or (edge.from_id == second and edge.to_id == first):
			return _view._board.route_cue(edge)
	push_error("Missing route %s to %s." % [first, second])
	return -1 as Board.RouteCue


func _push_click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)


func _click(control: Control, inside: Vector2) -> void:
	var point := control.get_global_transform_with_canvas() * inside
	var hover := InputEventMouseMotion.new()
	hover.position = point
	root.push_input(hover, true)
	_push_click(point, true)
	_push_click(point, false)


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


func _fail(message: String) -> bool:
	push_error(message)
	return false
