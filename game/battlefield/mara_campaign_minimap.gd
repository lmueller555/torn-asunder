extends PanelContainer
## Campaign Mara HUD adapter only. Interception reports are coordinates on the
## road; actual unit icons are separately gated by a friendly's clear sight.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")

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


func _capture_button(event: InputEventJoypadButton) -> bool:
	var button := int(event.button_index)
	if _captured_buttons.has(button):
		if not event.pressed:
			_captured_buttons.erase(button)
		return true
	if not _draft_battle:
		if button != JOY_BUTTON_DPAD_UP or not event.pressed or not _can_open_controller():
			return false
		_captured_buttons[button] = true
		_open_controller()
		return true
	if event.pressed:
		_captured_buttons[button] = true
		match button:
			JOY_BUTTON_A: _confirm_controller()
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
		return false
	if key == KEY_SHIFT:
		if not event.pressed and not _mission._l2_down:
			_close_controller()
		return false
	if event.pressed and not event.echo:
		_captured_keys[key] = true
		if key == KEY_ESCAPE:
			_close_controller()
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
	_refresh_controller_overlay()


func _refresh_controller_overlay() -> void:
	_reticle.visible = _draft_battle != null
	if _draft_battle:
		_reticle.pixel = map.project(_draft_point)
		_reticle.queue_redraw()
		_key.text = "Stick: Aim  ·  Cross: Move  ·  Circle: Back"
		if _draft_denied:
			_key.text += "\nNot a walkable point"
	else:
		_key.text = _legend + ("\nD-pad Up: minimap cursor" if _mission.command_view else "")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_reset_capture()


func _on_controller_connection(device: int, connected: bool) -> void:
	if not connected and device == _mission._input_device:
		_reset_capture()


func _reset_capture() -> void:
	_axes_seen.clear()
	_axes_until_neutral.clear()
	_captured_buttons.clear()
	_captured_keys.clear()
	if _draft_battle:
		_close_controller()


func _physics_process(delta: float) -> void:
	if _draft_battle and _can_confirm_controller():
		var aim := Vector2(_map_axes.get(JOY_AXIS_LEFT_X, 0.0), _map_axes.get(JOY_AXIS_LEFT_Y, 0.0))
		if aim.length() > _mission.STICK_DEADZONE:
			_step_draft(aim.limit_length() * CURSOR_SPEED * delta)
	refresh()


func refresh() -> void:
	# Child controls are readied before their parent mission has loaded terrain.
	if not _mission.is_node_ready():
		return
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
