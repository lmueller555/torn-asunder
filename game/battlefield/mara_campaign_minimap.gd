extends PanelContainer
## Campaign Mara HUD adapter only. Interception reports are coordinates on the
## road; actual unit icons are separately gated by a friendly's clear sight.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const Routes := preload("res://game/battlefield/command_platoon_routes.gd")
const LeadAction := preload("res://game/battlefield/mara_lead_action_camera.gd")
const ShieldFollow := preload("res://game/battlefield/mara_shield_follow_camera.gd")
const RouteOverlay := preload("res://game/battlefield/minimap_route_overlay.gd")

const SIGHT_RANGE := 48.0
const GROUND := Plane(Vector3.UP, 0.0)
const SOLID_MASK := 1

const CURSOR_SPEED := 90.0
const CURSOR_NUDGE := 2.0

class AimReticle extends Control:
	var pixel := Vector2.ZERO

	func _draw() -> void:
		draw_circle(pixel, 7.0, Minimap.INK, false, 4.0, true)
		draw_circle(pixel, 7.0, Minimap.HERO, false, 1.8, true)
		draw_line(pixel - Vector2(10.0, 0.0), pixel + Vector2(10.0, 0.0), Minimap.HERO, 1.6, true)
		draw_line(pixel - Vector2(0.0, 10.0), pixel + Vector2(0.0, 10.0), Minimap.HERO, 1.6, true)


var _reticle := AimReticle.new()
var _route_overlay := RouteOverlay.new()
var _lead_action := LeadAction.new()
var _shield_follow := ShieldFollow.new()
var _routes := Routes.new()
var _route_battle: Battle
var _sending_route_order := false
var _route_note := ""
var _route_note_index := -1
var _draft_battle: Battle
var _draft_index := -1
var _draft_point := Vector2.ZERO
var _draft_denied := false
var _axes_seen: Dictionary[int, float] = {}
var _axes_until_neutral: Dictionary[int, bool] = {}
var _map_axes: Dictionary[int, float] = {}
var _captured_buttons: Dictionary[int, bool] = {}
var _captured_keys: Dictionary[int, bool] = {}
var _legend := ""

@onready var map: Minimap = $Margin/Readout/Map
@onready var _status: Label = $Margin/Readout/Status
@onready var _key: Label = $Margin/Readout/Key
@onready var _mission: Mission = get_parent().get_parent() as Mission


func _ready() -> void:
	map.right_click_to_move = true
	map.point_requested.connect(_focus_map_point)
	map.move_requested.connect(_move_from_map)
	_legend = _key.text
	map.add_child(_route_overlay)
	_route_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_route_overlay.hide()
	map.add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.hide()
	map.resized.connect(_refresh_controller_overlay)
	Input.joy_connection_changed.connect(_on_controller_connection)


func _focus_map_point(point: Vector2) -> void:
	if not _mission.command_view or not _mission._sector:
		return
	_mission._mouse_cursor_active = false
	_mission.cursor = point
	_mission._sector.center_on(point)
	_mission._update_cameras()
	_mission._sync_view()


func _move_from_map(point: Vector2) -> bool:
	if not _mission.command_view or not _mission._terrain or not _mission._sector:
		return false
	# This is the existing mouse rule, now also used for confirmed controller
	# points. A painted tile can cover a nonwalkable roof or crag.
	var vertical_start := Vector3(point.x, 30.0, point.y)
	var vertical_end := Vector3(point.x, -12.0, point.y)
	if _mission._terrain.destination_from_ray(vertical_start, vertical_end) == null:
		return false
	_focus_map_point(point)
	_mission._move_selected()
	return true


func _input(event: InputEvent) -> void:
	if not _mission.is_node_ready():
		return
	_bind_route_battle()
	if _shield_follow.active and _input_leaves_follow(event):
		_shield_follow.restore(_mission)
	var swallow := false
	if event is InputEventJoypadButton and _mission._uses_joypad(event.device):
		swallow = _capture_button(event)
	elif event is InputEventJoypadMotion and _mission._uses_joypad(event.device):
		swallow = _capture_axis(event)
	elif event is InputEventKey:
		swallow = _capture_key(event)
	elif _draft_battle and event is InputEventMouse:
		swallow = true
	if swallow:
		# Trap the event before the camera and combat's unhandled bindings.
		get_viewport().set_input_as_handled()


# Restore the ordinary projection before mouse ray picking or any explicit
# command. Do not consume these events or introduce a second input mode.
func _input_leaves_follow(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion and _mission._uses_joypad(event.device):
		return (event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value <= _mission.L2_RELEASE) \
			or (event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) > _mission.STICK_DEADZONE)
	if event is InputEventJoypadButton:
		return event.pressed and _mission._uses_joypad(event.device)
	return event is InputEventMouse or event is InputEventKey


func _capture_button(event: InputEventJoypadButton) -> bool:
	var button := int(event.button_index)
	if _captured_buttons.has(button):
		if not event.pressed:
			_captured_buttons.erase(button)
		return true
	if not _draft_battle:
		if not event.pressed:
			return false
		if button == JOY_BUTTON_DPAD_DOWN and not _mission._finished():
			_captured_buttons[button] = true
			_lead_action.focused = not _lead_action.focused
			return true
		if _mission.command_view and button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			_lead_action.clear()
		if not _can_open_controller():
			return false
		if button == JOY_BUTTON_DPAD_UP:
			_captured_buttons[button] = true
			_open_controller()
			return true
		if button == JOY_BUTTON_RIGHT_SHOULDER:
			_captured_buttons[button] = true
			_append_waypoint(_mission.cursor)
			return true
		return false
	if event.pressed:
		_captured_buttons[button] = true
		match button:
			JOY_BUTTON_A: _confirm_controller()
			JOY_BUTTON_RIGHT_SHOULDER: _append_minimap_waypoint()
			JOY_BUTTON_B: _close_controller()
			JOY_BUTTON_DPAD_UP: _step_draft(Vector2.UP * CURSOR_NUDGE)
			JOY_BUTTON_DPAD_DOWN: _step_draft(Vector2.DOWN * CURSOR_NUDGE)
			JOY_BUTTON_DPAD_LEFT: _step_draft(Vector2.LEFT * CURSOR_NUDGE)
			JOY_BUTTON_DPAD_RIGHT: _step_draft(Vector2.RIGHT * CURSOR_NUDGE)
	return true


func _capture_axis(event: InputEventJoypadMotion) -> bool:
	var axis := int(event.axis)
	var value := event.axis_value if is_finite(event.axis_value) else 0.0
	if axis == JOY_AXIS_TRIGGER_LEFT:
		if _draft_battle and value <= _mission.L2_RELEASE and not _mission._keys.has(KEY_SHIFT):
			_close_controller()
		# The existing L2 binding, including its release, must still see this.
		return false
	_axes_seen[axis] = value
	if _axes_until_neutral.has(axis):
		if absf(value) <= _mission.STICK_DEADZONE:
			_axes_until_neutral.erase(axis)
		return true
	if not _draft_battle:
		return false
	if axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		_map_axes[axis] = value
	return true


func _capture_key(event: InputEventKey) -> bool:
	var key := int(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
	if _captured_keys.has(key):
		if not event.pressed:
			_captured_keys.erase(key)
		return true
	if not _draft_battle:
		if key == KEY_C and event.pressed and not event.echo and not _mission._finished():
			_captured_keys[key] = true
			_lead_action.focused = not _lead_action.focused
			return true
		if event.pressed and not event.echo and _mission.command_view and key in [KEY_Z, KEY_X]:
			_lead_action.clear()
		if key == KEY_G and event.pressed and not event.echo and _can_open_controller():
			_captured_keys[key] = true
			_append_waypoint(_mission.cursor)
			return true
		return false
	if key == KEY_SHIFT:
		if not event.pressed and not _mission._l2_down:
			_close_controller()
		return false
	if event.pressed and not event.echo:
		_captured_keys[key] = true
		match key:
			KEY_ESCAPE: _close_controller()
			KEY_G: _append_minimap_waypoint()
	return true


func _can_open_controller() -> bool:
	return _mission.command_view and not _mission._finished() \
		and _mission.battle.formations[_mission.selected_index].can_receive_orders()


func _can_confirm_controller() -> bool:
	return _draft_battle == _mission.battle and _draft_index == _mission.selected_index and _can_open_controller()


func _open_controller() -> void:
	_draft_battle = _mission.battle
	_draft_index = _mission.selected_index
	_draft_point = _draft_battle.clamp_to_field(_mission.cursor)
	_draft_denied = false
	_zero_bound_input()
	_refresh_controller_overlay()


func _confirm_controller() -> void:
	if not _can_confirm_controller():
		_close_controller()
	elif _move_from_map(_draft_point):
		_close_controller()
	else:
		_draft_denied = true
		_refresh_controller_overlay()


## Bound only by the live campaign Mine HUD. Neither the shared escort scene
## nor the small Mine opt in, and the audited pickup/visual code is untouched.
func _bind_route_battle() -> void:
	if _route_battle == _mission.battle:
		return
	if _route_battle:
		_route_battle.formation_commanded.disconnect(_on_formation_commanded)
		for index in _route_battle.formations.size():
			_route_battle.formations[index].order_changed.disconnect(_on_formation_order_changed.bind(index))
	_route_battle = _mission.battle
	_lead_action.clear()
	_routes.reset(_route_battle)
	_route_note = ""
	_route_note_index = -1
	_route_battle.formation_commanded.connect(_on_formation_commanded)
	for index in _route_battle.formations.size():
		_route_battle.formations[index].order_changed.connect(_on_formation_order_changed.bind(index))


func pending_waypoints(index: int) -> PackedVector2Array:
	return _routes.snapshot(index) if _route_battle == _mission.battle else PackedVector2Array()


func _append_minimap_waypoint() -> void:
	if not _can_confirm_controller():
		_close_controller()
		return
	_append_waypoint(_draft_point)


func _append_waypoint(point: Vector2) -> void:
	var index := _mission.selected_index
	_sending_route_order = true
	var result := _routes.issue(_route_battle, index, point, true, _waypoint_fits)
	_sending_route_order = false
	_route_note_index = index
	_draft_denied = false
	match result:
		Queue.Result.ACCEPTED: _route_note = ""
		Queue.Result.DUPLICATE: _route_note = "Already on this route"
		Queue.Result.FULL: _route_note = "Route full (%d pending)" % Queue.MAX_WAYPOINTS
		_: _route_note = "Not a walkable formation point"
	_refresh_controller_overlay()


func _waypoint_fits(point: Vector2) -> bool:
	if not _mission.battle.clamp_to_field(point).is_equal_approx(point) or not _mission._terrain:
		return false
	if _mission._terrain.destination_from_ray(Vector3(point.x, 30.0, point.y), Vector3(point.x, -12.0, point.y)) == null:
		return false
	return _mission._terrain.formation_fits_at(point)


func _on_formation_commanded(index: int) -> void:
	# Explicit direct Move/Hold, including a Move to our current head, wins.
	if not _sending_route_order:
		_clear_waypoints(index)


func _on_formation_order_changed(order: Battle.Order, index: int) -> void:
	if order in [Battle.Order.ATTACK, Battle.Order.DEFEATED, Battle.Order.EXTRACTED]:
		_clear_waypoints(index)


func _clear_waypoints(index: int) -> void:
	_routes.clear(index)
	if _route_note_index == index:
		_route_note = ""
	if index == _mission.selected_index:
		_refresh_selected_route()


func _close_controller() -> void:
	_draft_battle = null
	_draft_index = -1
	_draft_denied = false
	_zero_bound_input()
	_refresh_controller_overlay()


func _zero_bound_input() -> void:
	_map_axes.clear()
	for axis in _axes_seen:
		if absf(_axes_seen[axis]) > _mission.STICK_DEADZONE:
			_axes_until_neutral[axis] = true
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		_mission._axes.erase(axis)
	for key in _mission._keys.keys():
		if key != KEY_SHIFT:
			_mission._keys.erase(key)
	_mission._mouse_cursor_active = false
	_mission._guard_key = false
	_mission._guard_pad = false
	_mission._special_pad_down = false


func _step_draft(offset: Vector2) -> void:
	_draft_point = _draft_battle.clamp_to_field(_draft_point + offset)
	_draft_denied = false
	_route_note = ""
	_refresh_controller_overlay()


func _refresh_selected_route() -> void:
	# Show the selected friendly plan in either command cursor mode. The
	# controller draft and enemy intelligence are separate from accepted orders.
	var index := _mission.selected_index
	var pending := pending_waypoints(index)
	_route_overlay.visible = _can_open_controller() and not pending.is_empty()
	if not _route_overlay.visible:
		_route_overlay.clear_route()
		return
	var formation := _mission.battle.formations[index]
	var active_from: Variant = null
	if formation.order == Battle.Order.MOVE and formation.destination.is_equal_approx(pending[0]):
		active_from = formation.position
	_route_overlay.show_route(map, pending, active_from)


func _refresh_controller_overlay() -> void:
	_refresh_selected_route()
	_reticle.visible = _draft_battle != null
	if _draft_battle:
		_reticle.pixel = map.project(_draft_point)
		_reticle.queue_redraw()
		_key.text = "Stick: Aim  ·  Cross: Move  ·  Circle: Back"
		if _draft_denied:
			_key.text += "\nNot a walkable point"
	else:
		_key.text = _legend + ("\nD-pad Up: minimap cursor" if _mission.command_view else "")
		if not _mission._finished():
			_key.text += "\nD-pad Down / C: " + ("Clear Mara focus" if _lead_action.focused else "Focus Mara")
	if _mission.command_view:
		_key.text += "\nR1 / G: Append waypoint  ·  %d/%d" % [pending_waypoints(_mission.selected_index).size(), Queue.MAX_WAYPOINTS]
		if _route_note_index == _mission.selected_index and not _route_note.is_empty():
			_key.text += "\n" + _route_note


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_reset_capture()


func _on_controller_connection(device: int, connected: bool) -> void:
	if not connected and device == _mission._input_device:
		_reset_capture()


func _reset_capture() -> void:
	_lead_action.clear()
	_axes_seen.clear()
	_axes_until_neutral.clear()
	_captured_buttons.clear()
	_captured_keys.clear()
	if _draft_battle:
		_close_controller()


func _physics_process(delta: float) -> void:
	if not _mission.is_node_ready():
		return
	_bind_route_battle()
	if _mission._finished():
		for index in _route_battle.formations.size():
			_clear_waypoints(index)
	else:
		_sending_route_order = true
		_routes.advance(_route_battle)
		_sending_route_order = false
	if _draft_battle and _can_confirm_controller():
		var aim := Vector2(_map_axes.get(JOY_AXIS_LEFT_X, 0.0), _map_axes.get(JOY_AXIS_LEFT_Y, 0.0))
		if aim.length() > _mission.STICK_DEADZONE:
			_step_draft(aim.limit_length() * CURSOR_SPEED * delta)
	_shield_follow.frame(_mission, _draft_battle != null, delta)
	_lead_action.frame(_mission, delta)
	refresh()


func refresh() -> void:
	# Child controls are readied before their parent mission has loaded terrain.
	if not _mission.is_node_ready():
		return
	_bind_route_battle()
	if _draft_battle and not _can_confirm_controller():
		_close_controller()
	if map.click_to_focus != _mission.command_view:
		map.click_to_focus = _mission.command_view
		map.tooltip_text = "Left click: inspect sector. Right click: move the selected platoon." if _mission.command_view else ""
	var battle := _mission.battle
	var objective := _mission.objective
	var encounter := _mission.encounter
	map.set_field_bounds(battle.bounds)
	var frame := Minimap.Frame.new()
	if not encounter or encounter.hero.is_alive():
		frame.hero = Minimap.Marker.new(&"Mara", battle.hero_position, battle.hero_heading)
	for index in range(battle.formations.size()):
		var formation := battle.formations[index]
		if formation.order == Battle.Order.DEFEATED:
			continue
		var id := StringName(formation.title)
		frame.allies.append(Minimap.Marker.new(id, formation.position, formation.heading))
		if index == _mission.selected_index:
			frame.selected_ally = id
	if _mission.command_view:
		frame.camera_footprint = _command_footprint()
	match objective.phase:
		Escort.Phase.AWAITING_PICKUP:
			_add_landmark(frame, &"Godbridle", ^"Markers/Objectives/GodbridlePickup", Minimap.ObjectiveKind.PICKUP)
		Escort.Phase.ESCORTING:
			_add_landmark(frame, &"East exit", ^"Markers/Objectives/GodbridleExit", Minimap.ObjectiveKind.EXIT)
	var warning := objective.phase == Escort.Phase.ESCORTING and objective.interception_triggered \
		and encounter != null and encounter.enemy.is_alive()
	_status.text = "YEAR ONE MINE  /  SECTOR" if _mission.command_view else "YEAR ONE MINE  /  HERO"
	_status.modulate = Color.WHITE
	if warning:
		_add_landmark(frame, &"Pass warning", ^"Markers/Routes/InterceptRoadMerge", Minimap.ObjectiveKind.ALERT)
		_status.text = "EAST PASS  /  INTERCEPTION REPORTED"
		_status.modulate = Minimap.ALERT
		if encounter.enemy_phase != Encounter.EnemyPhase.AT_RESERVE and _spot_guard(battle, encounter):
			frame.visible_enemies.append(Minimap.Marker.new(&"Orc guard", encounter.enemy_position))
			_status.text = "EAST PASS  /  ORC IN SIGHT"
	map.show_frame(frame)
	_refresh_controller_overlay()


func _add_landmark(frame: Minimap.Frame, id: StringName, path: NodePath, kind: Minimap.ObjectiveKind) -> void:
	var marker := _mission.battlefield_marker(path)
	if marker:
		var point := _mission.to_local(marker.global_position)
		frame.objectives.append(Minimap.Marker.new(id, Vector2(point.x, point.z), Vector2.UP, kind))


func _command_footprint() -> PackedVector2Array:
	var camera := get_viewport().get_camera_3d()
	var viewport := get_viewport().get_visible_rect()
	if not camera or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or not viewport.has_area():
		return PackedVector2Array()
	var points := PackedVector2Array()
	for corner in [viewport.position, Vector2(viewport.end.x, viewport.position.y),
		viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
		var origin := _mission.to_local(camera.project_ray_origin(corner))
		var direction := _mission.global_basis.inverse() * camera.project_ray_normal(corner)
		var point: Variant = GROUND.intersects_ray(origin, direction)
		if point == null:
			return PackedVector2Array()
		points.append(Vector2(point.x, point.z))
	return points


func _spot_guard(battle: Battle, encounter: Encounter) -> bool:
	var contact := encounter.enemy_position
	if encounter.hero.is_alive() and _has_clear_sight(battle.hero_position, contact):
		return true
	for ally in battle.formations:
		if ally.order != Battle.Order.DEFEATED and _has_clear_sight(ally.position, contact):
			return true
	return false


func _has_clear_sight(observer: Vector2, target: Vector2) -> bool:
	if observer.distance_squared_to(target) > SIGHT_RANGE * SIGHT_RANGE:
		return false
	var from := _mission.to_global(_mission._ground(observer, 1.58))
	var to := _mission.to_global(_mission._ground(target, 1.10))
	var query := PhysicsRayQueryParameters3D.create(from, to, SOLID_MASK)
	query.hit_from_inside = true
	return _mission.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
