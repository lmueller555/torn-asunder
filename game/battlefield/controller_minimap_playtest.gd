extends "res://game/battlefield/engagement_camera_playtest.gd"
## Standalone input experiment. Neither the shared minimap nor any live mission opts in.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const MAP_SPEED := 13.0
const NUDGE := 1.0

class Reticle extends Control:
	var point := Vector2.ZERO

	func _draw() -> void:
		draw_circle(point, 7.0, Minimap.INK, false, 3.5, true)
		draw_circle(point, 7.0, Minimap.HERO, false, 1.6, true)
		draw_line(point - Vector2(10.0, 0.0), point + Vector2(10.0, 0.0), Minimap.HERO, 1.5, true)
		draw_line(point - Vector2(0.0, 10.0), point + Vector2(0.0, 10.0), Minimap.HERO, 1.5, true)


var _map_open := false
var _map_cursor := Vector2.ZERO
var _map_selection := &""
var _raw_axes: Dictionary[int, float] = {}
var _muted_axes: Dictionary[int, bool] = {}
var _map_axes: Dictionary[int, float] = {}
var _map_needs_neutral: Dictionary[int, bool] = {}
var _consumed_buttons: Dictionary[int, bool] = {}
var _consumed_keys: Dictionary[int, bool] = {}
var _reticle := Reticle.new()
var _map_note := ""

@onready var _map_panel: PanelContainer = $MapHUD/Panel
@onready var _map: Minimap = $MapHUD/Panel/Margin/Readout/Map
@onready var _map_title: Label = $MapHUD/Panel/Margin/Readout/Title
@onready var _map_help: Label = $MapHUD/Panel/Margin/Readout/Help


func _ready() -> void:
	super._ready()
	_map.set_field_bounds(battle.bounds)
	_map.resized.connect(_refresh_reticle)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_layout()
	_refresh_minimap()


func _physics_process(delta: float) -> void:
	if _map_open:
		var direction := Vector2(_map_axes.get(JOY_AXIS_LEFT_X, 0.0), _map_axes.get(JOY_AXIS_LEFT_Y, 0.0))
		if direction.length() > STICK_DEADZONE:
			_step_map_cursor(direction.limit_length() * MAP_SPEED * delta)
	# Existing battle orders continue while the draft is edited.
	super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	super._after_battle_step(delta)
	if _map_open and not _can_order_draft():
		_close_map("Contact changed. No minimap order sent.")
	_refresh_minimap()


func _input(event: InputEvent) -> void:
	if not is_node_ready():
		return
	var consume := false
	if event is InputEventJoypadMotion and _uses_joypad(event.device):
		consume = _sample_axis(event)
	elif event is InputEventJoypadButton and _uses_joypad(event.device):
		consume = _read_map_button(event)
	elif event is InputEventKey:
		consume = _read_map_key(event)
	elif _map_open and event is InputEventMouse:
		consume = true
	if consume:
		# Capture before GUI and the original harness's unhandled input.
		get_viewport().set_input_as_handled()


func _sample_axis(event: InputEventJoypadMotion) -> bool:
	var channel := int(event.axis)
	var value := event.axis_value if is_finite(event.axis_value) else 0.0
	_raw_axes[channel] = value
	if _muted_axes.has(channel):
		if absf(value) <= STICK_DEADZONE:
			_muted_axes.erase(channel)
		if not _map_open:
			return true
	if not _map_open:
		return false
	if channel in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if _map_needs_neutral.has(channel):
			if absf(value) <= STICK_DEADZONE:
				_map_needs_neutral.erase(channel)
		else:
			_map_axes[channel] = value
	return true


func _read_map_button(event: InputEventJoypadButton) -> bool:
	var button := int(event.button_index)
	if _consumed_buttons.has(button):
		if not event.pressed:
			_consumed_buttons.erase(button)
		return true
	if not _map_open:
		if button != JOY_BUTTON_DPAD_UP or not event.pressed:
			return false
		_consumed_buttons[button] = true
		_open_map()
		return true
	if event.pressed:
		_consumed_buttons[button] = true
		match button:
			JOY_BUTTON_A: _confirm_draft()
			JOY_BUTTON_B: _close_map("Minimap canceled. No order sent.")
			JOY_BUTTON_DPAD_UP: _step_map_cursor(Vector2.UP * NUDGE)
			JOY_BUTTON_DPAD_DOWN: _step_map_cursor(Vector2.DOWN * NUDGE)
			JOY_BUTTON_DPAD_LEFT: _step_map_cursor(Vector2.LEFT * NUDGE)
			JOY_BUTTON_DPAD_RIGHT: _step_map_cursor(Vector2.RIGHT * NUDGE)
	return true


func _read_map_key(event: InputEventKey) -> bool:
	var key := int(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
	if _consumed_keys.has(key):
		if not event.pressed:
			_consumed_keys.erase(key)
		return true
	if not _map_open:
		if key != KEY_N or not event.pressed or event.echo:
			return false
		_consumed_keys[key] = true
		_open_map()
		return true
	if event.pressed and not event.echo:
		_consumed_keys[key] = true
		match key:
			KEY_ENTER, KEY_KP_ENTER: _confirm_draft()
			KEY_ESCAPE, KEY_N: _close_map("Minimap canceled. No order sent.")
			KEY_UP: _step_map_cursor(Vector2.UP * NUDGE)
			KEY_DOWN: _step_map_cursor(Vector2.DOWN * NUDGE)
			KEY_LEFT: _step_map_cursor(Vector2.LEFT * NUDGE)
			KEY_RIGHT: _step_map_cursor(Vector2.RIGHT * NUDGE)
	return true


func _open_map() -> void:
	if not policy.accepts_formation_orders() or not battle.formations[selected_index].can_receive_orders():
		_map_note = "Minimap orders are unavailable in this context."
		_refresh_minimap()
		return
	_map_open = true
	_map_selection = policy.selected_id()
	_map_cursor = battle.clamp_to_field(cursor)
	_map_note = ""
	_map_axes.clear()
	_map_needs_neutral.clear()
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if absf(_raw_axes.get(axis, 0.0)) > STICK_DEADZONE:
			_map_needs_neutral[axis] = true
	_clear_world_input()
	_refresh_layout()
	_refresh_minimap()


func _can_order_draft() -> bool:
	return policy.accepts_formation_orders() and policy.selected_id() == _map_selection \
		and battle.formations[selected_index].can_receive_orders()


func _confirm_draft() -> void:
	if not _can_order_draft():
		_close_map("Selection changed. No minimap order sent.")
		return
	var point := _map_cursor
	if not point.is_finite() or not battle.clamp_to_field(point).is_equal_approx(point):
		_map_note = "Choose a point inside the field."
		_refresh_minimap()
		return
	# This flat fixture has no obstacles. If reused with terrain, respect the
	# same solid-hit rule as the existing world/minimap mouse bindings.
	if _terrain and _terrain.destination_from_ray(Vector3(point.x, 128.0, point.y), Vector3(point.x, -32.0, point.y)) == null:
		_map_note = "That point is not walkable."
		_refresh_minimap()
		return
	var unit := battle.formations[selected_index].title
	battle.order_move(selected_index, point)
	_close_map("Move sent to " + unit + ".")
	_sync_view()


func _close_map(note: String) -> void:
	_map_open = false
	_map_selection = &""
	_map_note = note
	_map_axes.clear()
	_map_needs_neutral.clear()
	# An axis held through confirm/cancel cannot move the hero or orbit the
	# world camera afterward. A neutral event rearms that axis.
	for axis in _raw_axes:
		if absf(_raw_axes[axis]) > STICK_DEADZONE:
			_muted_axes[axis] = true
	_clear_world_input()
	_refresh_layout()
	_refresh_minimap()


func _clear_world_input() -> void:
	_axes.clear()
	_keys.clear()
	_l2_down = false
	_mouse_cursor_active = false


func _step_map_cursor(displacement: Vector2) -> void:
	_map_cursor = battle.clamp_to_field(_map_cursor + displacement)
	_refresh_reticle()


func _refresh_layout() -> void:
	_map_panel.offset_left = -475.0 if _map_open else -268.0
	_map_panel.offset_top = -333.0 if _map_open else -205.0
	_refresh_reticle()


func _refresh_reticle() -> void:
	_reticle.visible = _map_open
	if _map_open:
		_reticle.point = _map.project(_map_cursor)
		_reticle.queue_redraw()


func _refresh_minimap() -> void:
	var snapshot := Minimap.Frame.new()
	snapshot.hero = Minimap.Marker.new(&"hero_actor", battle.hero_position, battle.hero_heading)
	snapshot.selected_ally = policy.selected_id()
	for index in battle.formations.size():
		var unit := battle.formations[index]
		if unit.can_receive_orders():
			snapshot.allies.append(Minimap.Marker.new(ROSTER[index], unit.position, unit.heading))
	for index in _opponents.size():
		if _opponents[index].is_alive():
			snapshot.visible_enemies.append(Minimap.Marker.new(StringName("practice_%d" % index), _positions[index]))
	_map.show_frame(snapshot)
	if _map_open:
		_map_title.text = "MINIMAP DRAFT · " + battle.formations[selected_index].title
		_map_help.text = "Left stick / D-pad: aim\nCross / Enter: Move   ·   Circle / Esc: cancel"
	else:
		_map_title.text = "MINIMAP · DEVELOPMENT PREVIEW"
		_map_help.text = "D-pad Up / N: draft a Move" if policy.accepts_formation_orders() else "Read-only in hero action"
	if not _map_note.is_empty():
		_map_help.text += "\n" + _map_note
	_refresh_reticle()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_clear_controller_state()
		if _map_open:
			_close_map("Focus changed. No minimap order sent.")


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if device == _input_device and not connected:
		_clear_controller_state()
		if _map_open:
			_close_map("Controller disconnected. No minimap order sent.")
	super._on_joy_connection_changed(device, connected)


func _clear_controller_state() -> void:
	_raw_axes.clear()
	_muted_axes.clear()
	_consumed_buttons.clear()
	_consumed_keys.clear()
