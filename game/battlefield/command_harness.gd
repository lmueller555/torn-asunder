extends Node3D

const Battle := preload("res://game/battlefield/command_battle.gd")

const L2_PRESS := 0.48
const L2_RELEASE := 0.30
const STICK_DEADZONE := 0.18
const CURSOR_SPEED := 12.0
const ORBIT_SPEED := 1.6
const FLOOR := Plane(Vector3.UP, 0.0)

var battle := Battle.new()
var command_view := false
var selected_index := 0
var cursor := Vector2.ZERO

var _keys: Dictionary = {}
var _axes: Dictionary = {}
var _input_device := -1
var _l2_down := false
var _hero_yaw := 0.0
var _hero_pitch := deg_to_rad(23.0)
var _command_yaw := 0.0
var _command_pitch := deg_to_rad(59.0)
var _hero: Node3D
var _formation_models: Array[Node3D] = []
var _selection: MeshInstance3D
var _cursor_marker: MeshInstance3D
var _destination_marker: MeshInstance3D

@onready var _hero_camera: Camera3D = $HeroCamera
@onready var _command_camera: Camera3D = $CommandCamera
@onready var _mode_label: Label = $HUD/Panel/Margin/Readout/Mode
@onready var _formation_label: Label = $HUD/Panel/Margin/Readout/Formation
@onready var _controls_label: Label = $HUD/Panel/Margin/Readout/Controls


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		_input_device = devices[0]
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT]:
			_axes[axis] = Input.get_joy_axis(_input_device, axis)
		_l2_down = _axis(JOY_AXIS_TRIGGER_LEFT) >= L2_PRESS
	_build_placeholders()
	_update_cameras()
	_update_mode()
	_sync_view()


func _physics_process(delta: float) -> void:
	var movement := _motion(_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y), _digital(KEY_A, KEY_D, KEY_W, KEY_S))
	var look := _motion(_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), _digital(KEY_Q, KEY_E, KEY_R, KEY_F))
	if command_view:
		_command_yaw = wrapf(_command_yaw - look.x * ORBIT_SPEED * delta, -PI, PI)
		_command_pitch = clampf(_command_pitch + look.y * delta, deg_to_rad(50.0), deg_to_rad(75.0))
		cursor = Battle.clamp_to_field(cursor + movement.rotated(-_command_yaw) * CURSOR_SPEED * delta)
	else:
		_hero_yaw = wrapf(_hero_yaw - look.x * ORBIT_SPEED * delta, -PI, PI)
		_hero_pitch = clampf(_hero_pitch + look.y * delta, deg_to_rad(10.0), deg_to_rad(48.0))
	# Only the hero input is suppressed in command view. Formations always advance.
	battle.step(delta, Vector2.ZERO if command_view else movement.rotated(-_hero_yaw))
	_update_cameras()
	_sync_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: int = event.physical_keycode
		if code in [KEY_SHIFT, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_R, KEY_F]:
			if event.pressed:
				_keys[code] = true
			else:
				_keys.erase(code)
			if code == KEY_SHIFT:
				_update_mode()
		elif event.pressed:
			match code:
				KEY_Z: _select_relative(-1)
				KEY_X: _select_relative(1)
				KEY_H: _hold_selected()
	elif event is InputEventJoypadMotion and _uses_joypad(event.device):
		_axes[event.axis] = event.axis_value
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			_l2_down = event.axis_value > L2_RELEASE if _l2_down else event.axis_value >= L2_PRESS
			_update_mode()
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		# Godot names face buttons by their Xbox positions: X is Square and A is Cross.
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: _select_relative(-1)
			JOY_BUTTON_DPAD_RIGHT: _select_relative(1)
			JOY_BUTTON_X: _move_selected()
			JOY_BUTTON_A: _hold_selected()
	elif command_view and event is InputEventMouseMotion:
		_point_cursor(event.position, true)
	elif command_view and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _point_cursor(event.position, false):
			_select_at_cursor()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _point_cursor(event.position, false):
			_move_selected()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_keys.clear()
		_axes.clear()
		_l2_down = false
		_update_mode()


func _uses_joypad(device: int) -> bool:
	if _input_device < 0:
		_input_device = device
	return _input_device == device


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and _input_device == device:
		var devices := Input.get_connected_joypads()
		_input_device = devices[0] if not devices.is_empty() else -1
		_axes.clear()
		_l2_down = false
		_update_mode()


func _update_mode() -> void:
	var next_view := _keys.has(KEY_SHIFT) or _l2_down
	if command_view != next_view:
		command_view = next_view
		if command_view:
			_command_camera.make_current()
		else:
			_hero_camera.make_current()
	_sync_view()


func _select_relative(step: int) -> void:
	selected_index = posmod(selected_index + step, battle.formations.size())
	_sync_view()


func _select_at_cursor() -> void:
	var nearest := 2.2
	for index in range(battle.formations.size()):
		var distance := battle.formations[index].position.distance_to(cursor)
		if distance < nearest:
			nearest = distance
			selected_index = index
	_sync_view()


func _move_selected() -> void:
	if command_view:
		battle.order_move(selected_index, cursor)
		_sync_view()


func _hold_selected() -> void:
	if command_view:
		battle.order_hold(selected_index)
		_sync_view()


func _point_cursor(screen: Vector2, allow_clamp: bool) -> bool:
	var origin := to_local(_command_camera.project_ray_origin(screen))
	var direction := global_basis.inverse() * _command_camera.project_ray_normal(screen)
	var intersection: Variant = FLOOR.intersects_ray(origin, direction)
	if intersection == null:
		return false
	var point: Vector3 = intersection
	var target := Vector2(point.x, point.z)
	var bounded := Battle.clamp_to_field(target)
	if not allow_clamp and not bounded.is_equal_approx(target):
		return false
	cursor = bounded
	_sync_view()
	return true


func _update_cameras() -> void:
	var hero := _world(battle.hero_position, 1.15)
	var hero_offset := Vector3(0.0, sin(_hero_pitch), cos(_hero_pitch)) * 6.1
	_hero_camera.position = hero + hero_offset.rotated(Vector3.UP, _hero_yaw)
	_hero_camera.look_at(to_global(hero + Vector3(0.0, 0.0, -2.0).rotated(Vector3.UP, _hero_yaw)))
	_command_camera.position = Vector3(0.0, sin(_command_pitch), cos(_command_pitch)).rotated(Vector3.UP, _command_yaw) * 39.0
	_command_camera.look_at(global_position)


func _sync_view() -> void:
	var selected := battle.formations[selected_index]
	_hero.position = _world(battle.hero_position)
	_hero.rotation.y = atan2(-battle.hero_heading.x, -battle.hero_heading.y)
	for index in range(battle.formations.size()):
		var formation := battle.formations[index]
		_formation_models[index].position = _world(formation.position)
		_formation_models[index].rotation.y = atan2(-formation.heading.x, -formation.heading.y)
	_selection.position = _world(selected.position, 0.04)
	_selection.visible = command_view
	_cursor_marker.position = _world(cursor, 0.08)
	_cursor_marker.visible = command_view
	_destination_marker.position = _world(selected.destination, 0.06)
	_destination_marker.visible = command_view and selected.order == Battle.Order.MOVE
	var status := "Moving" if selected.order == Battle.Order.MOVE else "Holding"
	_mode_label.text = "COMMAND VIEW  /  LIVE" if command_view else "HERO VIEW  /  LIVE"
	_formation_label.text = "%s  ·  %s" % [selected.title, status]
	if command_view:
		_controls_label.text = "Release L2 / Shift to return to hero\nLeft stick / mouse: cursor   ·   Right stick / Q E R F: camera\nD-pad / Z X / left click: select   ·   Square / right click: move   ·   Cross / H: hold"
	else:
		_controls_label.text = "Hold L2 / Shift to command\nLeft stick / WASD: move   ·   Right stick / Q E R F: camera   ·   D-pad / Z X: allied status"


func _build_placeholders() -> void:
	var field_material := _material(Color("#536253"))
	for x in range(-16, 17, 4):
		_mesh($Floor, _box(Vector3(0.03, 0.01, 24.0)), field_material, Vector3(x, 0.16, 0.0))
	for z in range(-12, 13, 4):
		_mesh($Floor, _box(Vector3(34.0, 0.01, 0.03)), field_material, Vector3(0.0, 0.16, z))

	_hero = Node3D.new()
	add_child(_hero)
	var gold := _material(Color("#eabb66"))
	_mesh(_hero, _box(Vector3(0.72, 1.06, 0.50)), gold, Vector3(0.0, 0.82, 0.0))
	_mesh(_hero, _box(Vector3(0.46, 0.43, 0.44)), gold, Vector3(0.0, 1.58, 0.0))
	_mesh(_hero, _box(Vector3(0.30, 0.56, 0.22)), gold, Vector3(0.0, 0.91, -0.32))
	_mesh(_hero, _box(Vector3(0.53, 0.08, 0.95)), gold, Vector3(0.0, 0.07, 0.0))

	var troop := _box(Vector3(0.49, 1.15, 0.45))
	var equipment := _box(Vector3(0.43, 0.53, 0.13))
	for index in range(battle.formations.size()):
		var group := Node3D.new()
		add_child(group)
		_formation_models.append(group)
		var color := Color("#65b9d6") if index == 0 else Color("#8bbdaa")
		var uniform := _material(color)
		var trim := _material(color.lightened(0.47))
		for x in range(4):
			for z in range(3):
				var point := Vector3((x - 1.5) * 0.85, 0.60, (z - 1.0) * 0.78)
				_mesh(group, troop, uniform, point)
				_mesh(group, equipment, trim, point + Vector3(0.0, 0.1, -0.27))
		var banner := Label3D.new()
		banner.text = battle.formations[index].title
		banner.position.y = 2.1
		banner.pixel_size = 0.020
		banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		banner.outline_size = 9
		group.add_child(banner)

	_selection = _mesh(self, _ring(1.84, 1.97), _material(Color("#77dcfa"), true))
	_cursor_marker = _mesh(self, _ring(0.35, 0.48), _material(Color("#fff1bb"), true))
	_destination_marker = _mesh(self, _ring(0.49, 0.62), _material(Color("#77dcfa"), true))


static func _world(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, height, point.y)


func _axis(axis: int) -> float:
	return _axes.get(axis, 0.0)


func _stick(x: int, y: int) -> Vector2:
	var raw := Vector2(_axis(x), _axis(y))
	var magnitude := raw.length()
	if magnitude <= STICK_DEADZONE:
		return Vector2.ZERO
	return raw.normalized() * remap(minf(magnitude, 1.0), STICK_DEADZONE, 1.0, 0.0, 1.0)


func _digital(left: int, right: int, up: int, down: int) -> Vector2:
	return Vector2(int(_keys.has(right)) - int(_keys.has(left)), int(_keys.has(down)) - int(_keys.has(up)))


static func _motion(analog: Vector2, keys: Vector2) -> Vector2:
	return keys.limit_length() if keys != Vector2.ZERO else analog


static func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _ring(inner: float, outer: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 20
	ring.ring_segments = 8
	return ring


static func _mesh(parent: Node3D, shape: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
	return visual
