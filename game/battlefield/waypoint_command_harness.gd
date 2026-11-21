extends "res://game/battlefield/command_harness.gd"
## The terrain cursor and both command camera views issue world-space orders.
## This isolated playtest does not change mission orders or shared inputs.

const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")

const Routes := preload("res://game/battlefield/command_platoon_routes.gd")

var _routes := Routes.new()
var _waypoint_feedback := ""
var _feedback_index := -1
var _waypoint_labels: Array[Label3D] = []


func _ready() -> void:
	_reset_routes()
	for index in Queue.MAX_WAYPOINTS:
		var marker := Label3D.new()
		marker.text = str(index + 1)
		marker.font_size = 42
		marker.outline_size = 10
		marker.pixel_size = 0.018
		marker.modulate = Color("#ffd886")
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(marker)
		_waypoint_labels.append(marker)
	super._ready()


func restart_battle() -> void:
	_reset_routes()
	super.restart_battle()


func route_for(index: int) -> PackedVector2Array:
	return _routes.snapshot(index)


func _reset_routes() -> void:
	_routes.reset(battle)
	_waypoint_feedback = ""
	_feedback_index = -1


func _move_selected() -> void:
	_issue_route(false)


func _hold_selected() -> void:
	if command_view:
		_routes.clear(selected_index)
		_waypoint_feedback = ""
	super._hold_selected()


func _issue_route(append: bool) -> void:
	if not command_view or not battle.formation_at(selected_index).can_receive_orders():
		return
	_feedback_index = selected_index
	var result := _routes.issue(battle, selected_index, cursor, append, _route_point_is_valid)
	match result:
		Queue.Result.ACCEPTED:
			_waypoint_feedback = ""
		Queue.Result.DUPLICATE:
			_waypoint_feedback = "Already on this route"
		Queue.Result.FULL:
			_waypoint_feedback = "Route full"
		_:
			_waypoint_feedback = "Outside the field"
	_sync_view()


func _route_point_is_valid(point: Vector2) -> bool:
	# The standalone harness is a flat field. Terrain-specific destination
	# checks belong to the larger campaign integration, not this adapter.
	return battle.clamp_to_field(point).is_equal_approx(point)


func _after_battle_step(_delta: float) -> void:
	_routes.advance(battle)


func _unhandled_input(event: InputEvent) -> void:
	if command_view and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			_issue_route(true)
			return
	if command_view and event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER and _uses_joypad(event.device):
			_issue_route(true)
			return
	super._unhandled_input(event)


func _sync_view() -> void:
	super._sync_view()
	var points := route_for(selected_index)
	for index in _waypoint_labels.size():
		var marker := _waypoint_labels[index]
		marker.visible = command_view and index < points.size()
		if marker.visible:
			marker.position = _ground(points[index], 0.35)
	if command_view:
		_formation_label.text += "  ·  %d/%d waypoints" % [points.size(), Queue.MAX_WAYPOINTS]
		if selected_index == _feedback_index and not _waypoint_feedback.is_empty():
			_formation_label.text += "  ·  " + _waypoint_feedback
		_controls_label.text += "\nR1 / G: append waypoint   ·   Move replaces the route"
