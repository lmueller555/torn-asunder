extends Control
## A standalone map screen. It never instantiates a battlefield or persists progress.

signal waypoint_arrived(waypoint_id: String)
signal briefing_requested(mission_id: String)
signal camp_operations_requested
signal return_requested

const World := preload("res://game/campaign_world.gd")
const Missions := preload("res://game/campaign_missions.gd")
const Board := preload("res://game/campaign_map_board.gd")
const DISPLAY := preload("res://assets/fonts/Cinzel.ttf")
const BODY := preload("res://assets/fonts/SourceSans3.ttf")

const GOLD := Color("#edc486")
const INK := Color("#131b18")
const PALE := Color("#eee5d2")
const SOFT := Color("#b7b6a6")
const TRAVEL_SECONDS := 0.55

var _world := World.new("mara")
var _completed := PackedStringArray()
var _reduced_motion := false
var _selected_id := ""
var _tween: Tween
var _is_travelling := false

var _board: Board
var _backdrop: ColorRect
var _eyebrow: Label
var _heading: Label
var _panel: Panel
var _at_label: Label
var _location: Label
var _selection_label: Label
var _selection: Label
var _detail: Label
var _confirm_button: Button
var _back_button: Button
var _hint: Label


## Pass the same model back in when returning from a briefing; it owns location and visits.
func configure(world: World, completed_ids: PackedStringArray, reduced_motion: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_is_travelling = false
	_world = world
	_completed = completed_ids.duplicate()
	_reduced_motion = reduced_motion
	_selected_id = _world.current_waypoint_id()
	if is_node_ready():
		_sync_map()


func set_completed_ids(completed_ids: PackedStringArray) -> void:
	_completed = completed_ids.duplicate()
	if is_node_ready():
		_board.completed_ids = _completed
		_refresh_selection()


func selected_waypoint_id() -> String:
	return _selected_id


func is_travelling() -> bool:
	return _is_travelling


func token_map_position() -> Vector2:
	if is_node_ready():
		return _board.token_position
	return _world.waypoint(_world.current_waypoint_id()).get("map_position", Vector2.ZERO)


func select_waypoint(waypoint_id: String) -> bool:
	if _is_travelling or _world.waypoint(waypoint_id).is_empty():
		return false
	_selected_id = waypoint_id
	_refresh_selection()
	return true


func confirm_selection() -> void:
	if _is_travelling or _selected_id.is_empty():
		return
	if _selected_id == _world.current_waypoint_id():
		if _world.waypoint(_selected_id).get("kind") == World.WaypointKind.CAMP:
			camp_operations_requested.emit()
		else:
			_offer_briefing()
		return
	var route := _route_to_selection()
	if route.is_empty() or not route.is_open:
		return
	var destination: String = _selected_id
	var clears := _completed.duplicate()
	_is_travelling = true
	_refresh_selection()
	if _reduced_motion:
		_finish_travel(destination, clears)
		return
	var target: Vector2 = _world.waypoint(destination).map_position
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_board.set_token_position, _board.token_position, target, TRAVEL_SECONDS)
	_tween.finished.connect(_finish_travel.bind(destination, clears))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = ColorRect.new()
	_backdrop.color = INK
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_eyebrow = _make_label("TORN ASUNDER  /  CAMPAIGN", 17, GOLD)
	_heading = _make_label("Campaign Map", 54, PALE, DISPLAY)

	_board = Board.new()
	_board.name = "Waypoints"
	_board.clip_contents = true
	add_child(_board)
	_board.gui_input.connect(_map_input)
	_board.resized.connect(_board.queue_redraw)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _box(Color("#202722"), Color("#66604c")))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_at_label = _make_label("CURRENT LOCATION", 16, GOLD)
	_location = _make_label("", 28, PALE)
	_selection_label = _make_label("SELECTED WAYPOINT", 16, GOLD)
	_selection = _make_label("", 27, PALE)
	_detail = _make_label("", 20, SOFT)
	_detail.name = "RouteDetail"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_confirm_button = _make_button("ConfirmTravel", "", confirm_selection)
	_back_button = _make_button("Back", "Back", _request_return)
	_hint = _make_label("Select: click a waypoint, D-pad or arrows     Confirm: button, Cross or Enter     Back: Circle or Esc", 19, SOFT)
	resized.connect(_layout)
	_layout()
	if _selected_id.is_empty():
		_selected_id = _world.current_waypoint_id()
	_sync_map()


func _layout() -> void:
	var right := size.x - 366.0
	var bottom := size.y - 78.0
	_backdrop.size = size
	_place(_eyebrow, Rect2(48, 38, 750, 24))
	_place(_heading, Rect2(46, 70, 900, 66))
	_place(_back_button, Rect2(size.x - 190, 75, 142, 46))
	_place(_board, Rect2(48, 159, right - 70, bottom - 159))
	_place(_panel, Rect2(right, 159, 318, bottom - 159))
	_place(_at_label, Rect2(right + 23, 185, 270, 24))
	_place(_location, Rect2(right + 23, 215, 271, 55))
	_place(_selection_label, Rect2(right + 23, 312, 270, 24))
	_place(_selection, Rect2(right + 23, 342, 273, 55))
	_place(_detail, Rect2(right + 23, 418, 270, 142))
	_place(_confirm_button, Rect2(right + 22, bottom - 76, 274, 52))
	_place(_hint, Rect2(48, bottom + 18, size.x - 96, 28))


func _place(control: Control, bounds: Rect2) -> void:
	control.position = bounds.position
	control.size = bounds.size


func _sync_map() -> void:
	_board.world = _world
	_board.completed_ids = _completed
	_board.set_token_position(_world.waypoint(_world.current_waypoint_id()).get("map_position", Vector2.ZERO))
	_refresh_selection()


func _refresh_selection() -> void:
	if not is_node_ready():
		return
	var current := _world.waypoint(_world.current_waypoint_id())
	var campaign := _world.campaign_id()
	var complete := not Missions.missions_for_campaign(campaign).is_empty() \
		and Missions.first_unplayed_mission_id(campaign, _completed).is_empty()
	_heading.text = "Campaign Complete" if complete else "Campaign Map"
	var selected := _world.waypoint(_selected_id)
	_location.text = current.get("label", "No map")
	_selection.text = selected.get("label", "None")
	_board.selected_id = _selected_id
	_board.queue_redraw()
	_confirm_button.disabled = true
	_confirm_button.text = "Travel"
	_back_button.disabled = _is_travelling
	if _is_travelling:
		_detail.text = "Traveling to %s…" % _selection.text
	elif selected.is_empty():
		_detail.text = "This campaign does not have an overworld map yet."
	elif _selected_id == _world.current_waypoint_id():
		if not _world.mission_at_current_waypoint().is_empty():
			_detail.text = "Your party is at the battlefield. Review the briefing before deploying."
			_confirm_button.text = "Open Battlefield Briefing"
			_confirm_button.disabled = false
		elif selected.kind == World.WaypointKind.CAMP:
			_detail.text = "Visit camp for dispatch and preparations, or select the Mine to travel."
			_confirm_button.text = "Open Camp Operations"
			_confirm_button.disabled = false
		else:
			_detail.text = "Your party is here. Select a connected waypoint to travel."
			_confirm_button.text = "Current Waypoint"
	else:
		var route := _route_to_selection()
		var required_clear: String = _blocking_clear_for_selection() if route.is_empty() else route.required_clear_id
		if not route.is_empty() and route.is_open:
			_detail.text = "Connected route. Confirm to move your party to this waypoint."
			if selected.kind == World.WaypointKind.BATTLEFIELD:
				_detail.text += " Arriving opens the battlefield briefing."
			_confirm_button.disabled = false
		elif not required_clear.is_empty():
			_detail.text = _locked_route_detail(required_clear, selected.label)
			_confirm_button.text = "Road Locked"
		else:
			_detail.text = "No direct route from your party's current waypoint."
			_confirm_button.text = "No Direct Route"


func _blocking_clear_for_selection() -> String:
	for edge in _world.routes():
		# For a distant waypoint, describe its inbound gate, not an onward gate.
		if _selected_id == edge.to_id:
			var clear: String = edge.get("required_clear_id", "")
			if not clear.is_empty() and not _completed.has(clear):
				return clear
	return ""


func _locked_route_detail(clear: String, destination: String) -> String:
	if clear == "mara_mine_escort":
		return "Complete the Mine Escort to open the road into the Marches."
	var mission := Missions.mission_for_campaign(_world.campaign_id(), clear)
	return "Complete %s to open the route to %s." % [mission.get("title", "the required mission"), destination]


func _route_to_selection() -> Dictionary:
	for option in _world.route_options(_completed):
		if option.waypoint_id == _selected_id:
			return option
	return {}


func _finish_travel(destination: String, clears: PackedStringArray) -> void:
	_is_travelling = false
	var result := _world.travel_to(destination, clears)
	_sync_map()
	if result == World.TravelResult.ARRIVED:
		waypoint_arrived.emit(destination)
		_offer_briefing()


func _offer_briefing() -> void:
	var mission := _world.mission_at_current_waypoint()
	if not mission.is_empty():
		briefing_requested.emit(mission)


func _request_return() -> void:
	if not _is_travelling:
		return_requested.emit()


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var id := _board.waypoint_at(event.position)
		if not id.is_empty():
			select_waypoint(id)
			_board.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var viewport := get_viewport()
	var direction := Vector2.ZERO
	if event is InputEventKey:
		match event.keycode if event.keycode != KEY_NONE else event.physical_keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm_selection()
			KEY_ESCAPE: _request_return()
			_: return
	elif event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: direction = Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT: direction = Vector2.RIGHT
			JOY_BUTTON_DPAD_UP: direction = Vector2.UP
			JOY_BUTTON_DPAD_DOWN: direction = Vector2.DOWN
			JOY_BUTTON_A: confirm_selection()
			JOY_BUTTON_B: _request_return()
			_: return
	else:
		return
	if direction != Vector2.ZERO:
		_select_in_direction(direction)
	# Confirm or Back can replace the map synchronously in the campaign shell.
	viewport.set_input_as_handled()


func _select_in_direction(direction: Vector2) -> void:
	var selected := _world.waypoint(_selected_id)
	if selected.is_empty():
		return
	var origin: Vector2 = _board.point_at(selected.map_position)
	var best := -INF
	var best_id := ""
	for waypoint in _world.waypoints():
		if waypoint.id == _selected_id:
			continue
		var offset := _board.point_at(waypoint.map_position) - origin
		var alignment := offset.normalized().dot(direction)
		if alignment < 0.22:
			continue
		var score := alignment * 2.0 - offset.length() / maxf(_board.size.x, 1.0)
		if score > best:
			best = score
			best_id = waypoint.id
	if not best_id.is_empty():
		select_waypoint(best_id)


func _make_label(value: String, point_size: int, tint: Color, font: Font = BODY) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _make_button(node_name: String, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", PALE)
	button.add_theme_color_override("font_disabled_color", SOFT)
	button.add_theme_stylebox_override("normal", _box(Color("#353529"), Color("#9c7e55")))
	button.add_theme_stylebox_override("hover", _box(Color("#49402f"), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color("#4b4535"), PALE))
	button.add_theme_stylebox_override("disabled", _box(Color("#262922"), Color("#585649")))
	add_child(button)
	button.pressed.connect(action)
	return button


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
