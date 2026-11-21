extends PanelContainer
## Cut-only adapter for the existing minimap and command harness. It has
## no raider awareness or orders beyond the existing selected platoon Move.

const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const SECTOR_PLANE := Plane(Vector3.UP, 0.0)
const AIM_SPEED := 83.0
const NUDGE := 3.0
const AIM_AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]
const AIM_BUTTONS := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]


class AimReticle extends Control:
	var pixel := Vector2.ZERO

	func _draw() -> void:
		draw_circle(pixel, 7.0, Minimap.INK, false, 4.0, true)
		draw_circle(pixel, 7.0, Minimap.HERO, false, 1.8, true)
		draw_line(pixel - Vector2(9, 0), pixel + Vector2(9, 0), Minimap.HERO, 1.5, true)
		draw_line(pixel - Vector2(0, 9), pixel + Vector2(0, 9), Minimap.HERO, 1.5, true)


var _field: Harness
var _draft_battle: Battle
var _draft_index := -1
var _draft_point := Vector2.ZERO
var _draft_blocked := false
var _axes: Dictionary[int, float] = {}
var _until_neutral: Dictionary[int, bool] = {}
var _claimed_buttons: Dictionary[int, bool] = {}
var _capture_device := -1
var _aim := AimReticle.new()
var _normal_hint := ""

@onready var map: Minimap = $Margin/Readout/Map
@onready var _hint: Label = $Margin/Readout/Hint


func _ready() -> void:
	map.right_click_to_move = true
	map.point_requested.connect(_focus_sector)
	map.move_requested.connect(_move_from_map)
	mouse_entered.connect(_stop_world_mouse_pan)
	map.mouse_entered.connect(_stop_world_mouse_pan)
	_normal_hint = _hint.text
	_aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(_aim)
	_aim.hide()
	map.resized.connect(_sync_draft)
	Input.joy_connection_changed.connect(_controller_connection_changed)


func refresh(field: Harness, available: bool) -> void:
	_field = field
	var active := available and field.command_view and field._sector != null and field._terrain != null
	if _draft_battle and (not active or not _can_aim()):
		_close_draft()
	if visible != active:
		visible = active
		map.click_to_focus = active
		if not active:
			map.show_frame(null)
	if not active:
		return
	map.set_field_bounds(field.battle.bounds)
	var frame := Minimap.Frame.new()
	frame.hero = Minimap.Marker.new(&"sereth", field.battle.hero_position, field.battle.hero_heading)
	for index in range(field.battle.formations.size()):
		var platoon := field.battle.formations[index]
		if not platoon.can_receive_orders():
			continue
		var id := StringName("formation_%d" % index)
		frame.allies.append(Minimap.Marker.new(id, platoon.position, platoon.heading))
		if index == field.selected_index:
			frame.selected_ally = id
	frame.camera_footprint = _sector_footprint()
	map.show_frame(frame)


func _focus_sector(point: Vector2) -> void:
	if _usable(point):
		_snap_sector(point)
		_field._sync_view()


func _move_from_map(point: Vector2) -> bool:
	if not _usable(point) or not _field.battle.formations[_field.selected_index].can_receive_orders():
		return false
	# Like the world mouse, a solid first hit must also be tagged walkable.
	# Cast vertically so the map never orders the roof above the record room.
	var start := Vector3(point.x, 64.0, point.y)
	var finish := Vector3(point.x, -16.0, point.y)
	var hit: Variant = _field._terrain.destination_from_ray(start, finish)
	if hit == null:
		return false
	_snap_sector(hit)
	_field._move_selected()
	return true


func _input(event: InputEvent) -> void:
	if not _field or (not visible and not _draft_battle and _until_neutral.is_empty() and _claimed_buttons.is_empty()):
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
		if (event is InputEventJoypadButton and not _claimed_buttons.has(int(event.button_index))
				and (not event.pressed or event.button_index != JOY_BUTTON_DPAD_UP or not _can_open())):
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
		return false
	if button not in AIM_BUTTONS:
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
	return true


func _can_open() -> bool:
	return (visible and _field.command_view and _field._l2_down
		and _field.battle.formations[_field.selected_index].can_receive_orders())


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
	_sync_draft()


func _sync_draft() -> void:
	_aim.visible = _draft_battle != null
	_hint.text = _normal_hint
	if _draft_battle:
		_aim.pixel = map.project(_draft_point)
		_aim.queue_redraw()
		var line := "Blocked ground; aim again" if _draft_blocked else "Stick / D-pad: aim"
		_hint.text = line + "\nCross: move  ·  Circle: cancel"


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		# A held axis must still return to neutral after regaining focus.
		_close_draft()


func _controller_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _capture_device:
		_close_draft()
		_until_neutral.clear()
		_claimed_buttons.clear()
		_capture_device = -1


func _usable(point: Vector2) -> bool:
	return visible and _field != null and _field.command_view and point.is_finite() \
		and point.is_equal_approx(_field.battle.clamp_to_field(point))


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
