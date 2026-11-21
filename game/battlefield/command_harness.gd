extends Node3D

const Battle := preload("res://game/battlefield/command_battle.gd")
const MarchRoutes := preload("res://game/battlefield/command_platoon_routes.gd")
const MarchQueue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const SectorCamera := preload("res://game/battlefield/sector_camera.gd")

const L2_PRESS := 0.48
const L2_RELEASE := 0.30
const STICK_DEADZONE := 0.18
const CURSOR_SPEED := 12.0
const ORBIT_SPEED := 1.6
const FLOOR := Plane(Vector3.UP, 0.0)
## A hostile this close to the leader or their platoon starts combat.
const LEAD_ENGAGE_RADIUS := 8.0
## Combat ends once every hostile is beyond this range for LEAD_RELEASE_SECONDS.
const LEAD_RELEASE_RADIUS := 12.0
const LEAD_RELEASE_SECONDS := 1.5
## Outside combat the stick moves a tall waypoint marker out from the selected platoon.
const MARKER_SPEED := 16.0
## The marker stays within this distance of the selected platoon.
const MARKER_LEASH := 60.0
## The marker starts this far ahead of the platoon when it is (re)selected.
const MARKER_START := 4.0
const MARKER_CAMERA_DISTANCE := 11.0
const MARKER_BEAM_HEIGHT := 9.0

@export var battlefield_scene: PackedScene
## Optional authored terrain. Joined before the terrain adapter indexes
## walkable shapes, without changing the identity of the shared battlefield.
@export var battlefield_perimeter: PackedScene
@export var field_bounds := Battle.FLAT_BOUNDS
@export var enable_sector_camera := false
@export_range(16.0, 150.0) var local_sector_size := 58.0
@export var hero_spawn: NodePath
@export var formation_spawns: Array[NodePath] = []

## Off restores the free-walking leader for scenes that model their own hero platoon.
@export var lead_platoon_enabled := true

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
var _lead_model: Node3D
var _lead_members: Array[Node3D] = []
var _lead_banner: Label3D
var _calm_seconds := 0.0
## The waypoint marker steered with the stick outside combat (battlefield XZ).
var march_marker := Vector2.ZERO
## Route queues used by the marker. A scene with its own route store registers an
## object with march_issue(index, point, append), pending_waypoints(index) and
## march_clear(index) here; otherwise the harness keeps its own queues.
var march_route_provider: Object
## Scenes set this while the player has asked the camera to stay on the leader.
var march_camera_suppressed := false
var routes := MarchRoutes.new()
var _marker_owner := 999
var _marker_active := false
var _march_beam: Node3D
var _march_tether: MeshInstance3D
var _route_pins: Array[Node3D] = []
var _march_note := ""
var _camera_pivot := Vector3.INF
var _formation_models: Array[Node3D] = []
var _formation_members: Array[Array] = []
var _field: Node3D
var _terrain: Terrain
var _sector: SectorCamera
var _mouse_cursor_active := false
var _mouse_position := Vector2.ZERO
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
	battle.lead_platoon_enabled = lead_platoon_enabled
	routes.reset(battle)
	selected_index = 0
	_configure_field()
	_build_placeholders()
	_reset_march_marker()
	_update_cameras()
	_update_mode()
	_sync_view()


func _physics_process(delta: float) -> void:
	var movement := _movement_input()
	var repoint := false
	var look := _motion(_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), _digital(KEY_Q, KEY_E, KEY_R, KEY_F))
	if command_view:
		_command_yaw = wrapf(_command_yaw - look.x * ORBIT_SPEED * delta, -PI, PI)
		_command_pitch = clampf(_command_pitch + look.y * delta, deg_to_rad(50.0), deg_to_rad(75.0))
		if _sector:
			repoint = _step_sector_cursor(movement, delta)
		else:
			cursor = battle.clamp_to_field(cursor + movement.rotated(-_command_yaw) * CURSOR_SPEED * delta)
	else:
		_hero_yaw = wrapf(_hero_yaw - look.x * ORBIT_SPEED * delta, -PI, PI)
		_hero_pitch = clampf(_hero_pitch + look.y * delta, deg_to_rad(10.0), deg_to_rad(48.0))
		_step_march_marker(movement, delta)
	_update_lead_engagement(delta)
	# Stick and D-pad steer the leader only in combat; otherwise the lead platoon
	# follows its Move order or waypoints. Formations always advance.
	var steering := not command_view and battle.direct_hero_control()
	battle.step(delta, movement.rotated(-_hero_yaw) * _hero_move_factor() if steering else Vector2.ZERO, _movement_check())
	if march_route_provider == null:
		routes.advance(battle)
	_after_battle_step(delta)
	_update_cameras()
	if not repoint or not _point_cursor(_mouse_position, true):
		_sync_view()


func _after_battle_step(_delta: float) -> void:
	pass


## True outside combat in hero view: the stick steers the waypoint marker.
func march_mode() -> bool:
	return battle.lead_platoon_enabled and not command_view and not battle.direct_hero_control()


func _step_march_marker(movement: Vector2, delta: float) -> void:
	var active := march_mode()
	var selected := battle.formation_at(selected_index)
	if not active or selected == null:
		_marker_active = false
		return
	if not _marker_active or _marker_owner != selected_index:
		_reset_march_marker()
	_marker_active = true
	if movement != Vector2.ZERO:
		march_marker += movement.rotated(-_hero_yaw) * MARKER_SPEED * delta
		_march_note = ""
	var origin := selected.position
	if march_marker.distance_to(origin) > MARKER_LEASH:
		march_marker = origin + (march_marker - origin).normalized() * MARKER_LEASH
	march_marker = battle.clamp_to_field(march_marker)


func _reset_march_marker() -> void:
	var selected := battle.formation_at(selected_index)
	_marker_owner = selected_index
	_march_note = ""
	if selected:
		var forward := Vector2(-sin(_hero_yaw), -cos(_hero_yaw))
		march_marker = battle.clamp_to_field(selected.position + forward * MARKER_START)


## R1 / G: add the marker as the selected platoon's next waypoint. With no route
## pending, the platoon sets off for it at once.
func add_march_waypoint() -> int:
	if not march_mode() or not battle.is_valid_command_index(selected_index):
		return MarchQueue.Result.INVALID_FOR_BATTLEFIELD
	var result: int
	if march_route_provider and march_route_provider.has_method("march_issue"):
		result = march_route_provider.march_issue(selected_index, march_marker, true)
	else:
		result = routes.issue(battle, selected_index, march_marker, true, _march_point_fits)
	match result:
		MarchQueue.Result.ACCEPTED: _march_note = ""
		MarchQueue.Result.DUPLICATE: _march_note = "Already a waypoint"
		MarchQueue.Result.FULL: _march_note = "Route full (%d waypoints)" % MarchQueue.MAX_WAYPOINTS
		_: _march_note = "Can't march there"
	_sync_view()
	return result


## D-pad Up / T: drop the selected platoon's route and hold where it stands.
func clear_march_route() -> void:
	if not march_mode() or not battle.is_valid_command_index(selected_index):
		return
	# Nothing to cancel: leave a halted platoon's orders alone.
	if march_waypoints(selected_index).is_empty() and battle.formation_at(selected_index).order != Battle.Order.MOVE:
		return
	if march_route_provider and march_route_provider.has_method("march_clear"):
		march_route_provider.march_clear(selected_index)
	else:
		routes.clear(selected_index)
	battle.order_hold(selected_index)
	_march_note = ""
	_sync_view()


func march_waypoints(index: int) -> PackedVector2Array:
	if march_route_provider and march_route_provider.has_method("pending_waypoints"):
		return march_route_provider.pending_waypoints(index)
	return routes.snapshot(index)


func _march_point_fits(point: Vector2) -> bool:
	if not battle.clamp_to_field(point).is_equal_approx(point):
		return false
	if not _terrain:
		return true
	return _terrain.destination_from_ray(Vector3(point.x, 30.0, point.y), Vector3(point.x, -12.0, point.y)) != null


## Hostile battlefield positions that can engage the leader's platoon. Scenes with
## enemies override this; an empty list means the leader always marches by orders.
func _hostile_positions() -> PackedVector2Array:
	return PackedVector2Array()


## Battlefield XZ of the visible, live nodes among `nodes`, for _hostile_positions.
func _visible_node_positions(nodes: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for node in nodes:
		if node is Node3D and is_instance_valid(node) and node.is_inside_tree() and node.is_visible_in_tree():
			var local := to_local((node as Node3D).global_position)
			result.append(Vector2(local.x, local.z))
	return result


func _update_lead_engagement(delta: float) -> void:
	var nearest := INF
	for point in _hostile_positions():
		if point.is_finite():
			nearest = minf(nearest, minf(point.distance_to(battle.hero_position), point.distance_to(battle.lead.position)))
	if not battle.lead_engaged:
		if nearest <= LEAD_ENGAGE_RADIUS:
			battle.lead_engaged = true
			_calm_seconds = 0.0
			_on_lead_engagement_changed(true)
		return
	if nearest <= LEAD_RELEASE_RADIUS:
		_calm_seconds = 0.0
		return
	_calm_seconds += delta
	if _calm_seconds >= LEAD_RELEASE_SECONDS:
		battle.lead_engaged = false
		_on_lead_engagement_changed(false)


## Scenes can react when the leader's platoon enters or leaves combat.
func _on_lead_engagement_changed(_engaged: bool) -> void:
	_sync_view()


func _step_sector_cursor(movement: Vector2, delta: float) -> bool:
	if not movement.is_zero_approx():
		_mouse_cursor_active = false
		var speed := _sector.view_size(_viewport_aspect()) * 0.54
		cursor = battle.clamp_to_field(cursor + movement.rotated(-_command_yaw) * speed * delta)
	if _mouse_cursor_active:
		var edge := SectorCamera.pointer_edge(_mouse_position, get_viewport().get_visible_rect())
		return _sector.pan(edge.rotated(-_command_yaw), delta)
	_sector.follow_cursor(cursor, _ground(cursor).y, _command_yaw, _command_pitch, _viewport_aspect())
	return false


func _viewport_aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return maxf(size.x, 1.0) / maxf(size.y, 1.0)


func _toggle_overview() -> void:
	if not command_view or not _sector:
		return
	_mouse_cursor_active = false
	_sector.toggle(cursor)
	_update_cameras()
	_sync_view()


func _center_on_hero() -> void:
	if not command_view or not _sector:
		return
	_mouse_cursor_active = false
	cursor = battle.hero_position
	_sector.center_on(cursor)
	_update_cameras()
	_sync_view()


func _movement_input() -> Vector2:
	return _motion(_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y), _digital(KEY_A, KEY_D, KEY_W, KEY_S))


func _hero_move_factor() -> float:
	return 1.0


func _movement_check() -> Callable:
	return _terrain.can_move if _terrain else Callable()


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
				KEY_M: _toggle_overview()
				KEY_HOME: _center_on_hero()
				KEY_G: if march_mode(): add_march_waypoint()
				KEY_T: if march_mode(): clear_march_route()
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
			JOY_BUTTON_RIGHT_STICK: _toggle_overview()
			JOY_BUTTON_LEFT_STICK: _center_on_hero()
			JOY_BUTTON_RIGHT_SHOULDER: if march_mode(): add_march_waypoint()
			JOY_BUTTON_DPAD_UP: if march_mode(): clear_march_route()
	elif command_view and event is InputEventMouseMotion:
		_mouse_cursor_active = true
		_mouse_position = event.position
		_point_cursor(event.position, true)
	elif command_view and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _point_cursor(event.position, false):
			_select_at_cursor()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _point_cursor(event.position, false):
			_move_selected()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_mouse_cursor_active = false
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
		_mouse_cursor_active = false
		if command_view:
			_center_on_hero()
			_command_camera.make_current()
		else:
			_hero_camera.make_current()
	_sync_view()


## The leader's platoon (LEAD_INDEX) comes first in the selection cycle.
func _select_relative(step: int) -> void:
	var count := battle.formations.size() + 1
	selected_index = posmod(selected_index + 1 + step, count) - 1
	_sync_view()


func _select_at_cursor() -> void:
	var nearest := 2.2
	for index in range(Battle.LEAD_INDEX, battle.formations.size()):
		if not battle.formation_at(index).can_receive_orders():
			continue
		var distance := battle.formation_at(index).position.distance_to(cursor)
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
	var target: Vector2
	if _terrain:
		var pick: Variant = _terrain.destination_from_ray(origin, origin + direction * _command_camera.far)
		if pick == null:
			return false
		target = pick
	else:
		var intersection: Variant = FLOOR.intersects_ray(origin, direction)
		if intersection == null:
			return false
		var point: Vector3 = intersection
		target = Vector2(point.x, point.z)
	var bounded := battle.clamp_to_field(target)
	if not allow_clamp and not bounded.is_equal_approx(target):
		return false
	cursor = bounded
	_sync_view()
	return true


func _update_cameras() -> void:
	# Outside combat the camera fixes on the waypoint marker and follows it; in
	# combat it frames the leader. The pivot eases between the two.
	var marching := march_mode() and _marker_active and not march_camera_suppressed
	var goal := _ground(march_marker, 1.0) if marching else _ground(battle.hero_position, 1.15)
	var step := get_physics_process_delta_time()
	# Ease only while following the marker; the leader's camera keeps its exact framing.
	if not marching or not _camera_pivot.is_finite() or step <= 0.0:
		_camera_pivot = goal
	else:
		_camera_pivot = _camera_pivot.lerp(goal, minf(1.0, 12.0 * step))
	var hero := _camera_pivot
	var distance := MARKER_CAMERA_DISTANCE if marching else 6.1
	var hero_offset := Vector3(0.0, sin(_hero_pitch), cos(_hero_pitch)) * distance
	var desired := hero + hero_offset.rotated(Vector3.UP, _hero_yaw)
	_hero_camera.position = _terrain.camera_position(hero, desired) if _terrain else desired
	var look_ahead := 0.0 if marching else -2.0
	var focus := to_global(hero + Vector3(0.0, 0.0, look_ahead).rotated(Vector3.UP, _hero_yaw))
	if _hero_camera.global_position.distance_squared_to(focus) > 0.0001:
		_hero_camera.look_at(focus)
	if _sector:
		_command_camera.size = _sector.view_size(_viewport_aspect())
	var overview := _world(_sector.view_center() if _sector else battle.bounds.get_center())
	_command_camera.position = overview + Vector3(0.0, sin(_command_pitch), cos(_command_pitch)).rotated(Vector3.UP, _command_yaw) * _command_camera.size
	_command_camera.look_at(to_global(overview))


func _sync_view() -> void:
	if not battle.is_valid_command_index(selected_index):
		selected_index = 0 if not battle.formations.is_empty() else Battle.LEAD_INDEX
	var selected := battle.formation_at(selected_index)
	_hero.position = _ground(battle.hero_position)
	_hero.rotation.y = atan2(-battle.hero_heading.x, -battle.hero_heading.y)
	_sync_lead_platoon()
	_sync_march_marker()
	for index in range(battle.formations.size()):
		var formation := battle.formations[index]
		var model := _formation_models[index]
		model.visible = formation.can_receive_orders()
		var yaw := atan2(-formation.heading.x, -formation.heading.y)
		var origin := _ground(formation.position)
		var moved := model.position != origin or not is_equal_approx(model.rotation.y, yaw)
		model.position = origin
		model.rotation.y = yaw
		if _terrain and moved:
			for member: Node3D in _formation_members[index]:
				var offset := Vector3(member.position.x, 0.0, member.position.z).rotated(Vector3.UP, model.rotation.y)
				var feet := formation.position + Vector2(offset.x, offset.z)
				member.position.y = _terrain.ground_height(feet) - model.position.y
	_selection.position = _ground(selected.position, 0.05)
	_selection.visible = command_view and selected.can_receive_orders()
	_cursor_marker.position = _ground(cursor, 0.10)
	_cursor_marker.visible = command_view
	_destination_marker.position = _ground(selected.destination, 0.08)
	_destination_marker.visible = command_view and selected.order == Battle.Order.MOVE
	var status: String = ["Holding", "Moving", "Blocked", "Attacking", "Defeated", "Extracted"][selected.order]
	if selected == battle.lead and battle.lead_engaged:
		status = "In combat · direct control"
	_mode_label.text = "COMMAND VIEW  /  LIVE" if command_view else ("HERO VIEW  /  COMBAT" if battle.lead_engaged else "HERO VIEW  /  MARCHING")
	_formation_label.text = "%s  ·  %s" % [selected.title, status]
	if command_view:
		if _sector:
			_mode_label.text = "%s  /  LIVE" % ("FIELD OVERVIEW" if _sector.overview else "TACTICAL SECTOR")
		_controls_label.text = "Release L2 / Shift to return to hero\nLeft stick / mouse: cursor   ·   Right stick / Q E R F: camera\nD-pad / Z X / left click: select   ·   Square / right click: move   ·   Cross / H: hold"
		if _sector:
			_controls_label.text += "\nR3 / M: overview / sector   ·   L3 / Home: center on hero"
			if not _sector.overview:
				_controls_label.text += "\nPan with the cursor or move the mouse to a screen edge"
	else:
		if battle.direct_hero_control():
			_controls_label.text = "COMBAT · Left stick / WASD: fight as the leader   ·   Right stick / Q E R F: camera\nHold L2 / Shift to command other platoons"
		else:
			_controls_label.text = "MARCHING · %s · Left stick / WASD: move the waypoint   ·   %s   ·   Right stick / Q E R F: camera" % [selected.title, _march_route_controls()]
			if not _march_note.is_empty():
				_controls_label.text += "\n" + _march_note


func _march_route_controls() -> String:
	return "R1 / G: add waypoint\nD-pad Up / T: clear route   ·   D-pad / Z X: change platoon"


func _configure_field() -> void:
	battle.bounds = field_bounds
	if enable_sector_camera:
		_sector = SectorCamera.new(field_bounds, local_sector_size)
	if not battlefield_scene:
		return
	_field = battlefield_scene.instantiate()
	if battlefield_perimeter:
		var perimeter := battlefield_perimeter.instantiate()
		if perimeter is Node3D:
			_field.add_child(perimeter)
		else:
			perimeter.free()
			push_warning("A battlefield perimeter requires a Node3D root.")
	add_child(_field)
	$Floor.hide()
	_terrain = Terrain.new(_field)
	_command_camera.size = maxf(_command_camera.size, field_bounds.size.length() * 1.08)
	_place_at_spawns()


func restart_battle() -> void:
	battle = Battle.new()
	battle.bounds = field_bounds
	battle.lead_platoon_enabled = lead_platoon_enabled
	routes.reset(battle)
	_marker_active = false
	_camera_pivot = Vector3.INF
	_calm_seconds = 0.0
	selected_index = 0
	cursor = Vector2.ZERO
	_mouse_cursor_active = false
	if _sector:
		_sector.center_on(cursor)
	_keys.clear()
	_axes.clear()
	_l2_down = false
	_hero_yaw = 0.0
	_hero_pitch = deg_to_rad(23.0)
	_command_yaw = 0.0
	_command_pitch = deg_to_rad(59.0)
	_place_at_spawns()
	_reset_march_marker()
	_update_cameras()
	_update_mode()


func _place_at_spawns() -> void:
	var hero_marker := battlefield_marker(hero_spawn)
	if hero_marker:
		battle.hero_position = _marker_position(hero_marker)
		battle.hero_heading = _marker_heading(hero_marker)
		_hero_yaw = atan2(-battle.hero_heading.x, -battle.hero_heading.y)
		cursor = battle.hero_position
	for index in range(mini(formation_spawns.size(), battle.formations.size())):
		var marker := battlefield_marker(formation_spawns[index])
		if marker:
			var formation := battle.formations[index]
			formation.position = _marker_position(marker)
			formation.heading = _marker_heading(marker)
			formation.hold()


func battlefield_marker(path: NodePath) -> Marker3D:
	return _field.get_node_or_null(path) as Marker3D if _field and not path.is_empty() else null


func hero_world_position() -> Vector3:
	return to_global(_ground(battle.hero_position))


func _marker_position(marker: Marker3D) -> Vector2:
	var local := to_local(marker.global_position)
	return Vector2(local.x, local.z)


func _marker_heading(marker: Marker3D) -> Vector2:
	var heading := global_basis.inverse() * -marker.global_basis.z
	return Vector2(heading.x, heading.z).normalized()


func _ground(point: Vector2, offset := 0.0) -> Vector3:
	return _world(point, offset + (_terrain.ground_height(point) if _terrain else 0.0))


func _build_placeholders() -> void:
	if not battlefield_scene:
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
		var members: Array[Node3D] = []
		for x in range(4):
			for z in range(3):
				var member := Node3D.new()
				member.position = Vector3((x - 1.5) * 0.85, 0.0, (z - 1.0) * 0.78)
				group.add_child(member)
				members.append(member)
				if not _add_formation_member_visual(member, index):
					_mesh(member, troop, uniform, Vector3(0.0, 0.60, 0.0))
					_mesh(member, equipment, trim, Vector3(0.0, 0.70, -0.27))
		_formation_members.append(members)
		var banner := Label3D.new()
		banner.text = battle.formations[index].title
		banner.position.y = 2.1
		banner.pixel_size = 0.020
		banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		banner.outline_size = 9
		group.add_child(banner)

	_build_lead_platoon(troop, equipment)
	_build_march_marker()
	_selection = _mesh(self, _ring(1.84, 1.97), _material(Color("#77dcfa"), true))
	_cursor_marker = _mesh(self, _ring(0.35, 0.48), _material(Color("#fff1bb"), true))
	_destination_marker = _mesh(self, _ring(0.49, 0.62), _material(Color("#77dcfa"), true))


## The leader's own platoon: two files flanking and trailing the leader, leaving a
## clear lane behind them for the hero camera.
func _build_lead_platoon(troop: Mesh, equipment: Mesh) -> void:
	_lead_model = Node3D.new()
	_lead_model.name = "LeadPlatoon"
	add_child(_lead_model)
	var uniform := _material(Color("#d9a85a"))
	var trim := _material(Color("#f2dcae"))
	var art := _lead_member_scene()
	_lead_members.clear()
	for side in [-1.0, 1.0]:
		for row in range(3):
			for file in range(2):
				var member := Node3D.new()
				member.position = Vector3(side * (1.5 + file * 0.85), 0.0, -0.4 + row * 0.85)
				_lead_model.add_child(member)
				_lead_members.append(member)
				var model: Node3D = art.instantiate() as Node3D if art and art.can_instantiate() else null
				if model:
					model.rotate_y(PI)
					member.add_child(model)
					var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
					if player and player.has_animation(&"Idle"):
						player.play(&"Idle")
				else:
					_mesh(member, troop, uniform, Vector3(0.0, 0.60, 0.0))
					_mesh(member, equipment, trim, Vector3(0.0, 0.70, -0.27))
	_lead_banner = Label3D.new()
	_lead_banner.text = battle.lead.title
	_lead_banner.position = Vector3(0.0, 2.4, 0.4)
	_lead_banner.pixel_size = 0.016
	_lead_banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lead_banner.outline_size = 9
	_lead_model.add_child(_lead_banner)


func _build_march_marker() -> void:
	_march_beam = Node3D.new()
	_march_beam.name = "WaypointMarker"
	add_child(_march_beam)
	var glow := _material(Color(1.0, 0.86, 0.48, 0.55), true)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.no_depth_test = true
	var beam := CylinderMesh.new()
	beam.top_radius = 0.10
	beam.bottom_radius = 0.30
	beam.height = MARKER_BEAM_HEIGHT
	_mesh(_march_beam, beam, glow, Vector3(0.0, MARKER_BEAM_HEIGHT * 0.5, 0.0))
	var cap := SphereMesh.new()
	cap.radius = 0.45
	cap.height = 0.9
	_mesh(_march_beam, cap, _material(Color("#ffe39a"), true), Vector3(0.0, MARKER_BEAM_HEIGHT, 0.0))
	_mesh(_march_beam, _ring(0.9, 1.15), _material(Color("#ffe39a"), true), Vector3(0.0, 0.06, 0.0))
	var tether_material := _material(Color(1.0, 0.86, 0.48, 0.45), true)
	tether_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_march_tether = _mesh(self, _box(Vector3(0.12, 0.02, 1.0)), tether_material)
	for index in range(MarchQueue.MAX_WAYPOINTS):
		var pin := Node3D.new()
		add_child(pin)
		var post := CylinderMesh.new()
		post.top_radius = 0.06
		post.bottom_radius = 0.18
		post.height = 2.6
		_mesh(pin, post, _material(Color("#77dcfa"), true), Vector3(0.0, 1.3, 0.0))
		var number := Label3D.new()
		number.text = str(index + 1)
		number.position.y = 3.0
		number.pixel_size = 0.02
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.outline_size = 8
		pin.add_child(number)
		pin.hide()
		_route_pins.append(pin)


func _sync_march_marker() -> void:
	if not _march_beam:
		return
	var showing := march_mode() and _marker_active
	var selected := battle.formation_at(selected_index)
	_march_beam.visible = showing
	_march_tether.visible = showing and selected != null
	if showing:
		_march_beam.position = _ground(march_marker)
		if selected:
			var from := _ground(selected.position, 0.08)
			var to := _ground(march_marker, 0.08)
			var length := from.distance_to(to)
			_march_tether.visible = length > 0.3
			if _march_tether.visible:
				_march_tether.position = (from + to) * 0.5
				_march_tether.look_at_from_position(_march_tether.position, to, Vector3.UP)
				_march_tether.scale = Vector3(1.0, 1.0, length)
	var pending := march_waypoints(selected_index) if showing or command_view else PackedVector2Array()
	for index in range(_route_pins.size()):
		var pin := _route_pins[index]
		pin.visible = index < pending.size()
		if pin.visible:
			pin.position = _ground(pending[index])


## Scenes with rigged soldier art return it here for the leader's platoon.
func _lead_member_scene() -> PackedScene:
	return null


func _sync_lead_platoon() -> void:
	if not _lead_model:
		return
	_lead_model.visible = battle.lead_platoon_enabled
	_lead_banner.visible = command_view
	var origin := _ground(battle.hero_position)
	var yaw := atan2(-battle.hero_heading.x, -battle.hero_heading.y)
	_lead_model.position = origin
	_lead_model.rotation.y = yaw
	if _terrain:
		for member in _lead_members:
			var offset := Vector3(member.position.x, 0.0, member.position.z).rotated(Vector3.UP, yaw)
			member.position.y = _terrain.ground_height(battle.hero_position + Vector2(offset.x, offset.z)) - origin.y


## Scenes may fill the existing feet anchor without changing simulation or formations.
func _add_formation_member_visual(_member: Node3D, _formation_index: int) -> bool:
	return false


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
