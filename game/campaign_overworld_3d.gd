extends Control
## Private renderer host. The campaign shell owns save, dialogue, briefing, and deployment.

signal waypoint_arrived(waypoint_id: String)
signal briefing_requested(mission_id: String)
signal camp_operations_requested
signal forward_camp_operations_requested(camp_id: String)
signal return_requested

const World := preload("res://game/campaign_world.gd")
const Navigation := preload("res://game/campaign_overworld_navigation.gd")
const ForwardCamp := preload("res://game/overworld/forward_campaign_camp.gd")
const PICK_RADIUS := 30.0

## UI and viewport nodes are supplied by the caller's composition.
@export var map_surface: SubViewportContainer
@export var render_viewport: SubViewport
@export var status_label: Label
@export var confirm_button: Button
@export var back_button: Button

var _renderer: Node3D
var _camera: Camera3D
var _party: Node3D
var _points: Dictionary[String, Vector3] = {}
var _curves: Dictionary[String, Curve3D] = {}
var _pace := 0.0
var _navigation: Navigation
var _world: World
var _reduced_motion := false
var _confirmed := PackedStringArray()
var _forward_camp: ForwardCamp.Definition
var _forward_camp_resume := ""
var _travel_origin_id := ""


static func route_key(origin_id: String, target_id: String) -> String:
	return "%s/%s" % [origin_id, target_id]


## Bind the viewport and controls first, then configure before adding this view to the tree.
## Geometry and paths use renderer-root coordinates. For bidirectional routes supply one
## oriented curve keyed by route_key(first_id, second_id). Pace is in scene units per second.
func configure_renderer(scene: PackedScene, camera_path: NodePath, party_path: NodePath,
		points: Dictionary[String, Vector3], curves: Dictionary[String, Curve3D], pace: float) -> bool:
	if not map_surface or not render_viewport or render_viewport.get_parent() != map_surface \
			or not status_label or not confirm_button or not back_button or confirm_button == back_button:
		return false
	if is_instance_valid(_renderer) or not scene or not scene.can_instantiate() \
			or points.is_empty() or not is_finite(pace) or pace <= 0.0:
		return false
	for point in points.values():
		if not point.is_finite():
			return false
	var instance := scene.instantiate()
	var renderer := instance as Node3D
	var camera := renderer.get_node_or_null(camera_path) as Camera3D if renderer else null
	var party := renderer.get_node_or_null(party_path) as Node3D if renderer else null
	if not renderer or not camera or not party or party == renderer or party == camera or party.is_ancestor_of(camera):
		instance.free()
		return false
	_renderer = renderer
	_camera = camera
	_party = party
	_points = points.duplicate()
	for key in curves:
		if curves[key]:
			_curves[key] = curves[key].duplicate() as Curve3D
	_pace = pace
	render_viewport.add_child(_renderer)
	return true


func can_present(world: World) -> bool:
	return is_instance_valid(_renderer) and world != null and _points.has(world.current_waypoint_id())


## The camp is visible to navigation only with a valid authored spur in this renderer.
func configure_forward_camp(camp: ForwardCamp.Definition, resume_camp_id := "") -> void:
	_forward_camp = null
	_forward_camp_resume = ""
	if camp and _curve_for(camp.junction_id, camp.id):
		_forward_camp = camp
		_forward_camp_resume = resume_camp_id


func active_forward_camp() -> ForwardCamp.Definition:
	return _forward_camp


func is_at_forward_camp(camp_id: String) -> bool:
	return _forward_camp != null and _forward_camp.id == camp_id and _navigation != null \
		and not _navigation.is_travelling() and _world.current_waypoint_id() == camp_id


func configure(world: World, completed_ids: PackedStringArray, reduced_motion: bool) -> void:
	_world = world
	if _forward_camp:
		_world = ForwardCamp.MapWorld.new(world, _forward_camp, _forward_camp_resume == _forward_camp.id)
	_forward_camp_resume = ""
	_confirmed = completed_ids.duplicate()
	_navigation = Navigation.new(_world, completed_ids)
	_navigation.waypoint_arrived.connect(_on_arrived)
	_reduced_motion = reduced_motion
	_refresh()


func _ready() -> void:
	if not _navigation or not _renderer:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_button.focus_mode = Control.FOCUS_NONE
	back_button.focus_mode = Control.FOCUS_NONE
	_camera.make_current()
	confirm_button.pressed.connect(confirm_selection)
	back_button.pressed.connect(_back_or_cancel)
	_refresh()


func select_waypoint(id: String) -> bool:
	if not _navigation or not _points.has(id) or not _navigation.select(id):
		return false
	_refresh()
	return true


func confirm_selection() -> void:
	if not _navigation:
		return
	match _navigation.action():
		Navigation.Action.TRAVEL:
			var origin := _world.current_waypoint_id()
			var target := _navigation.selected_waypoint_id()
			var curve := _curve_for(origin, target)
			if not curve:
				return
			var duration := curve.get_baked_length() / _pace
			if _navigation.start_travel(duration):
				_travel_origin_id = origin
				_refresh()
				if _reduced_motion:
					_navigation.advance(duration)
		Navigation.Action.BRIEFING:
			briefing_requested.emit(_world.mission_at_current_waypoint())
		Navigation.Action.CAMP:
			if _forward_camp and _world.current_waypoint_id() == _forward_camp.id:
				forward_camp_operations_requested.emit(_forward_camp.id)
			else:
				camp_operations_requested.emit()


func _process(delta: float) -> void:
	if not _navigation or not _navigation.is_travelling() or not is_visible_in_tree():
		return
	_navigation.advance(delta)
	if not is_inside_tree():
		return
	if _navigation.is_travelling():
		_update_party()
	else:
		_refresh()


func _on_arrived(id: String) -> void:
	_refresh()
	if _forward_camp and (id == _forward_camp.id or _travel_origin_id == _forward_camp.id):
		return
	waypoint_arrived.emit(id)


func _back_or_cancel() -> void:
	if _navigation.cancel_travel():
		_refresh()
	else:
		return_requested.emit()


func _curve_for(origin: String, target: String) -> Curve3D:
	if not _points.has(origin) or not _points.has(target):
		return null
	var forward := _curves.has(route_key(origin, target))
	var from := origin if forward else target
	var to := target if forward else origin
	var curve := _curves.get(route_key(from, to)) as Curve3D
	if not curve or curve.point_count < 2:
		return null
	if not curve.get_point_position(0).is_equal_approx(_points[from]) \
			or not curve.get_point_position(curve.point_count - 1).is_equal_approx(_points[to]):
		return null
	var duration := curve.get_baked_length() / _pace
	return curve if is_finite(duration) and duration > 0.0 else null


func _party_point() -> Vector3:
	if not _navigation.is_travelling():
		return _points[_world.current_waypoint_id()]
	var origin := _navigation.travel_origin_id()
	var target := _navigation.travel_target_id()
	var curve := _curve_for(origin, target)
	var progress := _navigation.travel_progress()
	if not _curves.has(route_key(origin, target)):
		progress = 1.0 - progress
	return curve.sample_baked(progress * curve.get_baked_length())


func _update_party() -> void:
	_party.global_position = _renderer.to_global(_party_point())


func _refresh() -> void:
	if not is_node_ready() or not _navigation or not _renderer or not _renderer.is_inside_tree():
		return
	_update_party()
	var id := _navigation.selected_waypoint_id()
	var action := _navigation.action()
	var text := "Current Waypoint"
	var can_confirm := false
	match action:
		Navigation.Action.CAMP:
			text = "Open Camp Operations"
			can_confirm = true
		Navigation.Action.BRIEFING:
			text = "Open Battlefield Briefing"
			can_confirm = true
		Navigation.Action.LOCKED: text = "Road Locked"
		Navigation.Action.NO_ROUTE: text = "No Direct Route"
		Navigation.Action.TRAVEL:
			can_confirm = _curve_for(_world.current_waypoint_id(), id) != null
			text = "Travel" if can_confirm else "Route Unavailable"
	confirm_button.disabled = not can_confirm
	confirm_button.text = "Traveling…" if _navigation.is_travelling() else text
	back_button.text = "Cancel Travel" if _navigation.is_travelling() else "Back"
	status_label.text = "%s  →  %s" % [_world.waypoint(_world.current_waypoint_id()).label, _world.waypoint(id).label]


func _projections() -> Dictionary[String, Vector2]:
	var projected: Dictionary[String, Vector2] = {}
	var viewport_size := Vector2(render_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return projected
	var surface_to_view := get_global_transform_with_canvas().affine_inverse() \
		* map_surface.get_global_transform_with_canvas()
	for waypoint in _world.waypoints():
		var id: String = waypoint.id
		if not _points.has(id):
			continue
		var point := _renderer.to_global(_points[id])
		if not _camera.is_position_behind(point):
			var surface_point := _camera.unproject_position(point) * map_surface.size / viewport_size
			projected[id] = surface_to_view * surface_point
	return projected


func _select_at(point: Vector2) -> bool:
	var distance := PICK_RADIUS
	var best_id := ""
	var projected := _projections()
	for id in projected:
		var candidate := point.distance_to(projected[id])
		if candidate < distance:
			distance = candidate
			best_id = id
	return select_waypoint(best_id)


func _direction_projections() -> Dictionary[String,Vector2]:
	var all := _projections()
	var options: Dictionary[String,Vector2] = {}
	for id in [_world.current_waypoint_id(),_navigation.selected_waypoint_id()]:
		if all.has(id): options[id] = all[id]
	for route in _world.route_options(_confirmed):
		var id:String = route.waypoint_id
		if all.has(id): options[id] = all[id]
	return options


func _unhandled_input(event: InputEvent) -> void:
	if not _navigation or not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var viewport := get_viewport()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (make_input_local(event) as InputEventMouseButton).position
		if _select_at(point):
			viewport.set_input_as_handled()
		return
	var direction := Vector2.ZERO
	if event is InputEventKey:
		match event.keycode if event.keycode != KEY_NONE else event.physical_keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm_selection()
			KEY_ESCAPE: _back_or_cancel()
			_: return
	elif event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: direction = Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT: direction = Vector2.RIGHT
			JOY_BUTTON_DPAD_UP: direction = Vector2.UP
			JOY_BUTTON_DPAD_DOWN: direction = Vector2.DOWN
			JOY_BUTTON_A: confirm_selection()
			JOY_BUTTON_B: _back_or_cancel()
			_: return
	else:
		return
	if direction != Vector2.ZERO and _navigation.select_in_direction(direction, _direction_projections(), map_surface.size.x):
		_refresh()
	viewport.set_input_as_handled()
