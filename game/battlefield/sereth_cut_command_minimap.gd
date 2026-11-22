extends PanelContainer
## Cut-only adapter for the existing minimap and command harness. It has
## no raider awareness and uses the same physical Move as the world cursor.

const GameplayBindings := preload("res://game/settings/control_bindings.gd")

const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Chart := preload("res://game/ui/authored_mission_map.gd")
const CUT_MAP_PAINT := {"road": ["Geometry/Road/VillageRoad", "Geometry/Road/OpenRecordApproach",
	"Geometry/Village/CemeteryFootLane"]}
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const Routes := preload("res://game/battlefield/command_platoon_routes.gd")
const RouteOverlay := preload("res://game/battlefield/minimap_route_overlay.gd")
const SECTOR_PLANE := Plane(Vector3.UP, 0.0)
const AIM_SPEED := 83.0
const NUDGE := 3.0
const AIM_AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]
const AIM_BUTTONS := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_RIGHT_SHOULDER]


class AimReticle extends Control:
	var pixel := Vector2.ZERO

	func _draw() -> void:
		draw_circle(pixel, 7.0, Minimap.INK, false, 4.0, true)
		draw_circle(pixel, 7.0, Minimap.HERO, false, 1.8, true)
		draw_line(pixel - Vector2(9, 0), pixel + Vector2(9, 0), Minimap.HERO, 1.5, true)
		draw_line(pixel - Vector2(0, 9), pixel + Vector2(0, 9), Minimap.HERO, 1.5, true)


var _field: Harness
var _routes := Routes.new()
var _route_battle: Battle
var _route_overlay: RouteOverlay
var _sending_route_order := false
var _route_note := ""
var _route_note_index := -1
var _route_note_point := Vector2.ZERO
var _route_note_size := 0
var _draft_battle: Battle
var _draft_index := -1
var _draft_point := Vector2.ZERO
var _draft_blocked := false
var _axes: Dictionary[int, float] = {}
var _until_neutral: Dictionary[int, bool] = {}
var _claimed_buttons: Dictionary[int, bool] = {}
var _capture_device := -1
var _aim: AimReticle
var _normal_hint := ""
var _map_expanded := false
var _map_exploration := Chart.Exploration.new()
var _map_available := false
var _chart_source: Node3D
var _chart_bounds := Rect2()

@onready var map: Minimap = $Margin/Readout/Map
@onready var _hint: Label = $Margin/Readout/Hint


func _ready() -> void:
	map.right_click_to_move = true
	map.point_requested.connect(_focus_sector)
	map.move_requested.connect(_move_from_map)
	map.append_requested.connect(_append_map_point)
	mouse_entered.connect(_stop_world_mouse_pan)
	map.mouse_entered.connect(_stop_world_mouse_pan)
	_normal_hint = _hint.text
	# Match the Mine HUD: do not leave unparented Controls on a bare instance.
	_route_overlay = RouteOverlay.new()
	map.add_child(_route_overlay)
	_route_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_route_overlay.hide()
	_aim = AimReticle.new()
	_aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(_aim)
	_aim.hide()
	map.resized.connect(_sync_draft)
	Input.joy_connection_changed.connect(_controller_connection_changed)


func refresh(field: Harness, available: bool) -> void:
	_field = field
	_map_available = available
	if not map.tactical_style and field.tactical_minimap_enabled:
		var title := get_node_or_null(^"Margin/Readout/Title") as Label
		map.configure_tactical_panel(self, [title, _hint])
		map.tooltip_text = "In command: N / LT + D-pad Up to open. Right-click / A sets a waypoint; Ctrl + right-click / RB appends. Click a platoon / X to switch."
	_bind_routes(field.battle if available else null)
	var active := available and (field.command_view or (map.tactical_style and field.march_mode())) \
		and field._sector != null and field._terrain != null
	if not field.command_view:
		_map_expanded = false
	if _draft_battle and (not active or not _can_aim()):
		_close_draft()
	if visible != active:
		visible = active
		map.click_to_focus = active and (not map.tactical_style or _map_expanded or _draft_battle != null)
		if not active:
			map.show_frame(null)
	if not active:
		_sync_draft()
		return
	if map.tactical_style and (_chart_source != field._field or _chart_bounds != field.battle.bounds):
		_chart_source = field._field
		_chart_bounds = field.battle.bounds
		map.terrain_texture = Chart.build_terrain(field, CUT_MAP_PAINT)
	map.set_field_bounds(field.battle.bounds)
	var frame := Minimap.Frame.new()
	frame.hero = Minimap.Marker.new(&"sereth", field.battle.hero_position, field.battle.hero_heading)
	frame.selected_hero = field.selected_index == Battle.LEAD_INDEX
	Chart.add_order_route(frame, field, Battle.LEAD_INDEX, &"sereth")
	var friends := PackedVector2Array([field.battle.hero_position])
	for index in range(field.battle.formations.size()):
		var platoon := field.battle.formations[index]
		if not platoon.can_receive_orders():
			continue
		var id := StringName("formation_%d" % index)
		frame.allies.append(Minimap.Marker.new(id, platoon.position, platoon.heading))
		Chart.add_order_route(frame, field, index, id)
		friends.append(platoon.position)
		if index == field.selected_index:
			frame.selected_ally = id
	frame.camera_footprint = _sector_footprint()
	if map.tactical_style:
		frame.explored_areas = _map_exploration.update(field.battle, friends)
		if _draft_battle:
			frame.command_cursor = _draft_point
		elif _map_expanded:
			frame.command_cursor = map.unproject(map.get_local_mouse_position())
	map.show_frame(frame)
	_sync_draft()


func _append_map_point(point: Vector2) -> void:
	if map.tactical_style and (_map_expanded or _draft_battle) and _can_plan():
		_append_waypoint(point)


func _focus_sector(point: Vector2) -> void:
	if map.tactical_style and (not (_map_expanded or _draft_battle) or Chart.select_platoon_at(_field, map, point)):
		return
	if _usable(point):
		_snap_sector(point)
		_field._sync_view()


func _move_from_map(point: Vector2) -> bool:
	if map.tactical_style:
		if not (_map_expanded or _draft_battle) or not _can_plan():
			return false
		_sending_route_order = true
		var result := _routes.issue(_route_battle, _field.selected_index, point, false,
			func(at: Vector2) -> bool: return Chart.can_plot(_field, at))
		_sending_route_order = false
		if result == Queue.Result.ACCEPTED:
			_snap_sector(point)
			_field._sync_view()
			return true
		return false
	if not _usable(point) or not _field.battle.formation_at(_field.selected_index).can_receive_orders():
		return false
	var hit: Variant = _walkable_hit(point)
	if hit == null:
		return false
	_snap_sector(hit)
	_field._move_selected()
	return true


func _walkable_hit(point: Vector2) -> Variant:
	# Like the world mouse, a solid first hit must be tagged walkable.
	# The vertical ray never picks through the record room's roof.
	return _field._terrain.destination_from_ray(Vector3(point.x, 64.0, point.y), Vector3(point.x, -16.0, point.y))


func _bind_routes(battle: Battle) -> void:
	if battle == _route_battle:
		return
	if _route_battle:
		_route_battle.formation_commanded.disconnect(_on_formation_commanded)
	_route_battle = battle
	_route_note = ""
	_route_note_index = -1
	if battle:
		_routes.reset(battle)
		battle.formation_commanded.connect(_on_formation_commanded)
		_field.march_route_provider = self
	else:
		if _field and _field.march_route_provider == self:
			_field.march_route_provider = null
		_routes = Routes.new()
		_route_overlay.hide()
		_route_overlay.clear_route()


func pending_waypoints(index: int) -> PackedVector2Array:
	return _routes.snapshot(index)


func _on_formation_commanded(index: int) -> void:
	# Explicit direct Move/Hold overrides an accepted plan, even at its head.
	if not _sending_route_order:
		_routes.clear(index)
		if _route_note_index == index:
			_route_note = ""


func _append_waypoint(point: Vector2) -> void:
	if not _can_plan():
		return
	var index := _field.selected_index
	_sending_route_order = true
	var result := _routes.issue(_route_battle, index, point, true, _waypoint_fits)
	_sending_route_order = false
	_route_note_index = index
	_route_note_point = point
	_route_note_size = pending_waypoints(index).size()
	_draft_blocked = false
	match result:
		Queue.Result.ACCEPTED: _route_note = ""
		Queue.Result.DUPLICATE: _route_note = "Already on this route"
		Queue.Result.FULL: _route_note = "Route full (%d/%d)" % [Queue.MAX_WAYPOINTS, Queue.MAX_WAYPOINTS]
		_: _route_note = "Not a walkable formation point"
	_sync_draft()


func _waypoint_fits(point: Vector2) -> bool:
	if map.tactical_style:
		return Chart.can_plot(_field, point)
	# Both the command overlay and the hero marker use the same physical test.
	# Neither the visibility of this panel nor the active camera defines ground.
	return _in_bounds(point) and _field._terrain != null \
		and _walkable_hit(point) != null and _field._terrain.formation_fits_at(point)


## The hero-view waypoint marker plots through these route queues.
func march_issue(index: int, point: Vector2, append: bool) -> int:
	if _field == null or _route_battle == null or _route_battle != _field.battle or not _field.march_mode():
		return Queue.Result.INVALID_FOR_BATTLEFIELD
	_sending_route_order = true
	var result := _routes.issue(_route_battle, index, point, append, _waypoint_fits)
	_sending_route_order = false
	_route_note_index = index
	return result


## True while a mini-map aim draft is open (the Heroes layout keeps its buttons).
func is_drafting() -> bool:
	return _draft_battle != null


func march_clear(index: int) -> void:
	_routes.clear(index)
	if _route_note_index == index:
		_route_note = ""


func advance_routes() -> void:
	if _route_battle == null or _route_battle != _field.battle:
		return
	_sending_route_order = true
	_routes.advance(_route_battle)
	_sending_route_order = false


func _input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if not _field or (not visible and not _draft_battle and _until_neutral.is_empty() and _claimed_buttons.is_empty()):
		return
	if map.tactical_style and event is InputEventKey and event.physical_keycode == KEY_SHIFT \
			and not event.pressed and not _field._l2_down:
		_map_expanded = false
		_sync_draft()
	if map.tactical_style and event is InputEventKey and _can_plan() and Minimap.is_tactical_toggle(event):
		_map_expanded = not _map_expanded
		_sync_draft()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key == KEY_G and (_can_aim() or (not _draft_battle and _can_plan())):
			if event.pressed and not event.echo:
				_append_waypoint(_draft_point if _draft_battle else _field.cursor)
			get_viewport().set_input_as_handled()
			return
	if _draft_battle and ((event is InputEventMouseButton and event.pressed)
			or (event is InputEventKey and event.pressed and not event.echo)
			or (event is InputEventMouseMotion and not event.relative.is_zero_approx())):
		# Switching back to a mouse deliberately leaves the draft. Do not
		# steal the click from the map, world or title's Return button.
		_close_draft()
		return
	if not _draft_battle:
		if event is InputEventJoypadMotion and not _until_neutral.has(int(event.axis)):
			return
		if event is InputEventJoypadButton and not _claimed_buttons.has(int(event.button_index)):
			var can_start: bool = ((event.button_index == JOY_BUTTON_DPAD_UP and _can_open())
				or (event.button_index == JOY_BUTTON_RIGHT_SHOULDER and _can_plan()))
			if not event.pressed or not can_start:
				return
	var claimed := false
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if not _field._uses_joypad(event.device):
			return
		if event is InputEventJoypadMotion:
			claimed = _capture_axis(event)
		else:
			claimed = _capture_button(event)
	if claimed:
		get_viewport().set_input_as_handled()


func _capture_axis(event: InputEventJoypadMotion) -> bool:
	var axis := int(event.axis)
	var value := clampf(event.axis_value, -1.0, 1.0) if is_finite(event.axis_value) else 0.0
	if axis == JOY_AXIS_TRIGGER_LEFT:
		if _draft_battle and value <= Harness.L2_RELEASE:
			_close_draft()
		return false # Always let the existing trigger enter or leave command.
	if axis not in AIM_AXES:
		return false
	if _until_neutral.has(axis):
		if absf(value) <= Harness.STICK_DEADZONE:
			_until_neutral.erase(axis)
			_axes.erase(axis)
		return true
	if not _draft_battle:
		return false
	_axes[axis] = value
	return true


func _capture_button(event: InputEventJoypadButton) -> bool:
	var button := int(event.button_index)
	if _claimed_buttons.has(button):
		if not event.pressed:
			_claimed_buttons.erase(button)
		return true
	if not _draft_battle:
		if event.pressed and button == JOY_BUTTON_DPAD_UP and _can_open():
			_claimed_buttons[button] = true
			_open_draft(event.device)
			return true
		if event.pressed and button == JOY_BUTTON_RIGHT_SHOULDER and _can_plan():
			_claimed_buttons[button] = true
			_capture_device = event.device
			_append_waypoint(_field.cursor)
			return true
		return false
	if button not in AIM_BUTTONS and not (map.tactical_style and button == JOY_BUTTON_X):
		return false # Options, Create and other existing shell actions pass.
	if event.pressed:
		_claimed_buttons[button] = true
		match button:
			JOY_BUTTON_DPAD_UP: _nudge(Vector2.UP * NUDGE)
			JOY_BUTTON_DPAD_DOWN: _nudge(Vector2.DOWN * NUDGE)
			JOY_BUTTON_DPAD_LEFT: _nudge(Vector2.LEFT * NUDGE)
			JOY_BUTTON_DPAD_RIGHT: _nudge(Vector2.RIGHT * NUDGE)
			JOY_BUTTON_A:
				if not _can_aim() or _move_from_map(_draft_point):
					_close_draft()
				else:
					_draft_blocked = true
					_sync_draft()
			JOY_BUTTON_B: _close_draft()
			JOY_BUTTON_X:
				_draft_index = posmod(_field.selected_index + 2, _field.battle.formations.size() + 1) - 1
				_field._select_relative(1)
			JOY_BUTTON_RIGHT_SHOULDER:
				if _can_aim():
					_append_waypoint(_draft_point)
	return true


func _can_plan() -> bool:
	return (visible and _map_available and not get_tree().paused and _route_battle != null and _field.command_view
		and _field.battle.is_valid_command_index(_field.selected_index)
		and _field.battle.formation_at(_field.selected_index).can_receive_orders())


func _can_open() -> bool:
	return _can_plan() and _field._l2_down


func _can_aim() -> bool:
	return _can_open() and _draft_battle == _field.battle and _draft_index == _field.selected_index


func _open_draft(device: int) -> void:
	_capture_device = device
	_draft_battle = _field.battle
	_draft_index = _field.selected_index
	_draft_point = _draft_battle.clamp_to_field(_field.cursor)
	_quarantine_axes()
	_sync_draft()


func _close_draft() -> void:
	if not _draft_battle:
		return
	if _route_note_index == _draft_index:
		_route_note = ""
	_draft_battle = null
	_draft_index = -1
	_draft_blocked = false
	_quarantine_axes()
	_sync_draft()


func _quarantine_axes() -> void:
	for axis: int in AIM_AXES:
		if absf(_axes.get(axis, _field._axis(axis))) > Harness.STICK_DEADZONE:
			_until_neutral[axis] = true
		_field._axes.erase(axis)
	_axes.clear()
	_stop_world_mouse_pan()


func _physics_process(delta: float) -> void:
	if not _draft_battle:
		return
	if not _can_aim():
		_close_draft()
		return
	var stick := Vector2(_axes.get(JOY_AXIS_LEFT_X, 0.0), _axes.get(JOY_AXIS_LEFT_Y, 0.0))
	if stick.length() > Harness.STICK_DEADZONE:
		_nudge(stick.limit_length() * AIM_SPEED * delta)


func _nudge(offset: Vector2) -> void:
	_draft_point = _draft_battle.clamp_to_field(_draft_point + offset)
	_draft_blocked = false
	_route_note = ""
	_sync_draft()


func _sync_draft() -> void:
	if map.tactical_style:
		map.set_tactical_expanded(_map_expanded or _draft_battle != null)
		map.click_to_focus = _can_plan() and (_map_expanded or _draft_battle != null)
	_aim.visible = not map.tactical_style and _draft_battle != null
	var may_show_route := _can_plan()
	var index := _field.selected_index if _field else -1
	var pending := pending_waypoints(index) if may_show_route else PackedVector2Array()
	var route_blocked := false
	_route_overlay.visible = not map.tactical_style and not pending.is_empty()
	if _route_overlay.visible:
		var platoon := _field.battle.formation_at(index)
		var marching := platoon.order == Battle.Order.MOVE and platoon.destination.is_equal_approx(pending[0])
		_route_overlay.show_route(map, pending, platoon.position if marching else null)
		route_blocked = platoon.order == Battle.Order.BLOCKED
	else:
		_route_overlay.clear_route()

	var hint := _normal_hint
	if _draft_battle:
		_aim.pixel = map.project(_draft_point)
		_aim.queue_redraw()
		hint = "Stick / D-pad: aim" if not _draft_blocked else "Blocked ground; aim again"
		hint += "\nCross: move  ·  Circle: cancel"
	if may_show_route:
		var status := "R1 / G: append  ·  %d/%d" % [pending.size(), Queue.MAX_WAYPOINTS]
		var aim := _draft_point if _draft_battle else _field.cursor
		# Feedback describes the rejected point and route at that instant. A
		# different aim or head arrival makes it stale, including a full queue.
		if _route_note_index != index or _route_note_size != pending.size() or not aim.is_equal_approx(_route_note_point):
			_route_note = ""
		hint += "\n" + (_route_note if not _route_note.is_empty() else status)
		if route_blocked:
			hint += "\nRoute blocked  ·  Move to replace"
	else:
		_route_note = ""
	_hint.text = hint


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED] and is_node_ready():
		# A held axis must still return to neutral after regaining focus.
		_close_draft()
		# Button releases may happen outside the app; unlike axes they do not
		# repeat, so a fresh press after focus should not be swallowed.
		_claimed_buttons.clear()


func _controller_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _capture_device:
		_close_draft()
		_until_neutral.clear()
		_claimed_buttons.clear()
		_capture_device = -1


func _usable(point: Vector2) -> bool:
	return visible and _field != null and _field.command_view and _in_bounds(point)


func _in_bounds(point: Vector2) -> bool:
	return _field != null and point.is_finite() and point.is_equal_approx(_field.battle.clamp_to_field(point))


func _stop_world_mouse_pan() -> void:
	if visible and _field != null:
		_field._mouse_cursor_active = false


func _snap_sector(point: Vector2) -> void:
	_stop_world_mouse_pan()
	_field.cursor = point
	_field._sector.center_on(point)
	_field._update_cameras()


func _sector_footprint() -> PackedVector2Array:
	var camera := get_viewport().get_camera_3d()
	var viewport := get_viewport().get_visible_rect()
	if camera != _field._command_camera or not viewport.has_area():
		return PackedVector2Array()
	# The command camera's focus lives on this X/Z reference plane, not on
	# ceilings or valley surfaces. Use its live rays to include resize/orbit.
	var corners := PackedVector2Array()
	for pixel in [viewport.position, Vector2(viewport.end.x, viewport.position.y),
			viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
		var origin := _field.to_local(camera.project_ray_origin(pixel))
		var direction := _field.global_basis.inverse() * camera.project_ray_normal(pixel)
		var hit: Variant = SECTOR_PLANE.intersects_ray(origin, direction)
		if hit == null:
			return PackedVector2Array()
		corners.append(Vector2(hit.x, hit.z))
	return corners
