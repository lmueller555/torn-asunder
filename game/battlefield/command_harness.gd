extends Node3D

const MissionHud := preload("res://game/ui/mission_hud.gd")
const GameplayBindings := preload("res://game/settings/control_bindings.gd")

const Battle := preload("res://game/battlefield/command_battle.gd")
const MarchRoutes := preload("res://game/battlefield/command_platoon_routes.gd")
const MarchQueue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const ControllerSupport := preload("res://game/controller.gd")
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
const HUMAN_ESCORT_SOLDIER_MODEL := "res://assets/models/human_infantry.glb"
## Combat ends once every hostile is beyond this range for LEAD_RELEASE_SECONDS.
const LEAD_RELEASE_RADIUS := 12.0
const LEAD_RELEASE_SECONDS := 1.5
## Outside combat the stick moves a tall waypoint marker out from the selected platoon.
const MARKER_SPEED := 16.0
## The marker stays within this distance of the selected platoon.
const MARKER_LEASH := 60.0
## The marker starts this far ahead of the platoon when it is (re)selected.
const MARKER_START := 4.0
const MARKER_CAMERA_DISTANCE := 9.0
## Hero camera distance multipliers for R3 "change camera view" (Heroes layout).
const CAMERA_VIEWS: PackedFloat32Array = [1.0, 1.6, 0.72]
const CAMERA_VIEW_NAMES: PackedStringArray = ["standard", "far", "near"]
## How far ahead of the platoon, toward the marker, the marching camera aims.
const MARKER_CAMERA_LOOK_AHEAD := 5.0
## The marker can't be pulled closer than this, so it never crosses the platoon
## and swings the camera round.
const MARKER_MIN_DISTANCE := 2.0
const MARKER_BEAM_HEIGHT := 9.0

@export var battlefield_scene: PackedScene
## Optional authored terrain. Joined before the terrain adapter indexes
## walkable shapes, without changing the identity of the shared battlefield.
@export var battlefield_perimeter: PackedScene
@export var field_bounds := Battle.FLAT_BOUNDS
@export var enable_sector_camera := false
@export_range(16.0, 150.0) var local_sector_size := 58.0
## Optional normalized rectangle outside this scene's HUD. Only whole-field
## overview uses it; the default preserves every existing deployment.
@export var overview_safe_frame := Rect2()
@export var hero_spawn: NodePath
@export var formation_spawns: Array[NodePath] = []
## Explicit metadata for authored slots; absent declarations retain legacy size.
@export var formation_roles: Array[Battle.FormationRole] = []
## Legacy scene values are accepted; regular melee now uses five files everywhere.
@export var regular_melee_slot_files: PackedInt32Array
## Measured feet spacing for scenes that still use only their stock 0.49m troops.
@export var regular_melee_spacing := Vector2(0.85, 0.78)
## A narrow marching block may sit behind its command pivot. This is a fixed
## deployment offset for every member, not a teleport/refile during movement.
@export var regular_melee_trailing_bias := 0.0
## Small local staging offsets only where the old marker fits a shorter platoon.
@export var regular_melee_staging_offsets: PackedVector2Array

## Off restores the free-walking leader for scenes that model their own hero platoon.
@export var lead_platoon_enabled := true
## Campaigns with a distinct hero and two officers can field a full regular escort.
@export var lead_has_officer_escort := false

var battle := Battle.new()
var command_view := false
var selected_index := Battle.LEAD_INDEX
var cursor := Vector2.ZERO

var _shared_mission_hud_enabled := false
var _mission_hud: MissionHud
var _mission_objective_feed: Node
var _mission_hero_name := ""
var _mission_lead_level := 1

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
var _lead_officers: Array[Node3D] = []
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
var _camera_yaw := 0.0
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
var _roster_label: Label
var _lead_was_engaged := false
var _r2_down := false
var _placed_spread := {}
var _camera_view := 0
## Set by mini-map HUDs while a mini-map aim draft is open.
var minimap_drafting := false
var _pre_combat_index := Battle.LEAD_INDEX
@onready var _controls_label: Label = $HUD/Panel/Margin/Readout/Controls


# The title shell opts campaign missions into tactical charts. Developer/drill
# scenes keep their authored controls and presentation until explicitly opted in.
var tactical_minimap_enabled := false
var _tactical_map_request: InputEventAction
var _tactical_map_target := Vector2.ZERO
var _tactical_map_append := false
var _tactical_map_result := false


func enable_tactical_minimap() -> void:
	tactical_minimap_enabled = true


## Dispatch a map order through the real scene's existing input and movement
## overrides, not through a made-up camera pixel or a direct battle mutation.
## The private event reference prevents a remapped action from impersonating it.
func request_tactical_map_order(point: Vector2, append: bool) -> bool:
	if not tactical_minimap_enabled or not command_view or get_tree().paused or _tactical_map_request != null:
		return false
	if not point.is_finite() or not battle.bounds.has_point(point) or not _terrain:
		return false
	var formation := battle.formation_at(selected_index)
	if formation == null or not formation.can_receive_orders():
		return false
	if selected_index == Battle.LEAD_INDEX and battle.direct_hero_control():
		return false
	var height_hit: Variant = _terrain.destination_from_ray(Vector3(point.x, 64.0, point.y), Vector3(point.x, -32.0, point.y))
	if height_hit == null or not _terrain.formation_fits_at(height_hit) or not formation.footprint_fits(height_hit):
		return false
	_tactical_map_request = InputEventAction.new()
	_tactical_map_target = height_hit
	_tactical_map_append = append
	_tactical_map_result = false
	_unhandled_input(_tactical_map_request)
	_tactical_map_request = null
	return _tactical_map_result


## Only the campaign shell opts in; free-standing combat drills retain their UI.
func enable_shared_mission_hud() -> void:
	_shared_mission_hud_enabled = true


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	GameplayBindings.set_mode_provider(_binding_mode)
	var device := ControllerSupport.device()
	if device >= 0:
		_input_device = device
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT]:
			_axes[axis] = GameplayBindings.axis(_input_device, axis)
		_l2_down = _axis(JOY_AXIS_TRIGGER_LEFT) >= L2_PRESS
	battle.lead_platoon_enabled = lead_platoon_enabled
	routes.reset(battle)
	_select_starting_platoon()
	_configure_formation_roles()
	_configure_field()
	_build_placeholders()
	_reset_march_marker()
	if _shared_mission_hud_enabled:
		_mission_hud = MissionHud.mount(self) as MissionHud
		$HUD/Panel.hide()
	_update_cameras()
	_update_mode()
	_sync_view()


func _physics_process(delta: float) -> void:
	_follow_lead_into_combat()
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
		var orbit := -look.x * ORBIT_SPEED * delta
		_hero_yaw = wrapf(_hero_yaw + orbit, -PI, PI)
		_hero_pitch = clampf(_hero_pitch + look.y * delta, deg_to_rad(10.0), deg_to_rad(48.0))
		_step_march_marker(movement, delta, orbit)
	_update_lead_engagement(delta)
	# Stick and D-pad steer the leader only in combat; otherwise the lead platoon
	# follows its Move order or waypoints. Formations always advance.
	var steering := hero_combat_active() and battle.direct_hero_control()
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
	return battle.lead_platoon_enabled and not command_view and not hero_combat_active()


## True when the stick and the attack buttons fight as the leader: the leader's
## platoon is in combat and selected, in hero view. Selecting another platoon during
## combat hands the stick to that platoon's waypoint marker instead; the leader
## stands their ground until you select the Lead Platoon again.
func hero_combat_active() -> bool:
	if command_view:
		return false
	if not battle.lead_platoon_enabled:
		return true # Scenes that opt out keep the free-walking, always-armed leader.
	_follow_lead_into_combat()
	return battle.lead_engaged and selected_index == Battle.LEAD_INDEX


func _step_march_marker(movement: Vector2, delta: float, orbit := 0.0) -> void:
	var active := march_mode()
	var selected := battle.formation_at(selected_index)
	if not active or selected == null:
		_marker_active = false
		return
	var origin := selected.position
	if not _marker_active or _marker_owner != selected_index:
		_reset_march_marker()
	elif orbit != 0.0:
		# The right stick swings the marker round its platoon, and the camera with it.
		march_marker = origin + (march_marker - origin).rotated(-orbit)
	_marker_active = true
	if movement != Vector2.ZERO:
		march_marker += movement.rotated(-_hero_yaw) * MARKER_SPEED * delta
		_march_note = ""
	var offset := march_marker - origin
	if offset.length() > MARKER_LEASH:
		march_marker = origin + offset.normalized() * MARKER_LEASH
	elif offset.length() < MARKER_MIN_DISTANCE:
		var bearing := offset.normalized() if offset.length() > 0.001 else Vector2(-sin(_hero_yaw), -cos(_hero_yaw))
		march_marker = origin + bearing * MARKER_MIN_DISTANCE
	march_marker = battle.clamp_to_field(march_marker)
	# The camera stays behind the platoon looking toward the marker, so the stick
	# pushes the marker away, pulls it back, or swings it left and right.
	offset = march_marker - origin
	if offset.length() > 0.5:
		_hero_yaw = atan2(-offset.x, -offset.y)


func _reset_march_marker() -> void:
	var selected := battle.formation_at(selected_index)
	_marker_owner = selected_index
	_march_note = ""
	if selected:
		var forward := Vector2(-sin(_hero_yaw), -cos(_hero_yaw))
		march_marker = battle.clamp_to_field(selected.position + forward * MARKER_START)


## R1 / G: add the marker as the selected platoon's next waypoint. With no route
## pending, the platoon sets off for it at once.
## R1 / G: send the selected platoon to the marker. By default this replaces the
## platoon's whole route; pass append (Square / J) to add the marker to the end of
## the route instead, so the platoon walks the waypoints in order.
func add_march_waypoint(append := false) -> int:
	if not march_mode() or not battle.is_valid_command_index(selected_index):
		return MarchQueue.Result.INVALID_FOR_BATTLEFIELD
	var result: int
	if march_route_provider and march_route_provider.has_method("march_issue"):
		result = march_route_provider.march_issue(selected_index, march_marker, append)
	else:
		result = routes.issue(battle, selected_index, march_marker, append, _march_point_fits)
	match result:
		MarchQueue.Result.ACCEPTED: _march_note = ""
		MarchQueue.Result.DUPLICATE: _march_note = "Already a waypoint"
		MarchQueue.Result.FULL: _march_note = "Route full (%d waypoints)" % MarchQueue.MAX_WAYPOINTS
		_: _march_note = "Can't march there"
	_sync_view()
	return result


## Square / J: add the marker to the end of the selected platoon's route.
func queue_march_waypoint() -> int:
	return add_march_waypoint(true)


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


## Y in the Heroes layout: every platoon that can take orders heads for the marker
## (or the command cursor), keeping its place relative to the selected platoon.
## Replaces their routes. The leader's platoon joins in only outside combat.
func move_all_troops() -> int:
	if not (march_mode() or command_view):
		return 0
	var anchor := battle.formation_at(selected_index)
	if anchor == null:
		return 0
	var target := march_marker if march_mode() else cursor
	var indices: Array[int] = []
	if battle.lead_platoon_enabled and not battle.direct_hero_control():
		indices.append(Battle.LEAD_INDEX)
	for index in range(battle.formations.size()):
		indices.append(index)
	var moved := 0
	for index in indices:
		var group := battle.formation_at(index)
		if group == null or not group.can_receive_orders():
			continue
		var point := battle.clamp_to_field(target + group.position - anchor.position)
		if not _march_point_fits(point):
			point = target
		var accepted := false
		if march_route_provider and march_route_provider.has_method("march_issue") and march_mode():
			accepted = march_route_provider.march_issue(index, point, false) == MarchQueue.Result.ACCEPTED
		elif march_mode():
			accepted = routes.issue(battle, index, point, false, _march_point_fits) == MarchQueue.Result.ACCEPTED
		else:
			if march_route_provider and march_route_provider.has_method("march_clear"):
				march_route_provider.march_clear(index)
			else:
				routes.clear(index)
			battle.order_move(index, point)
			accepted = true
		if accepted:
			moved += 1
	_march_note = "All troops moving" if moved > 0 else "No troops could move there"
	_sync_view()
	return moved


## R3 in the Heroes layout: change the hero camera's view (standard, far, near).
func cycle_camera_view() -> void:
	if command_view:
		return
	_camera_view = (_camera_view + 1) % CAMERA_VIEWS.size()
	_march_note = "Camera: %s view" % CAMERA_VIEW_NAMES[_camera_view]
	_update_cameras()
	_sync_view()


## What the Heroes controller layout needs to know to resolve a button press.
func _binding_mode() -> Dictionary:
	var mode := GameplayBindings.Mode.TACTICS
	if command_view:
		mode = GameplayBindings.Mode.COMMAND
	elif hero_combat_active():
		mode = GameplayBindings.Mode.ACTION
	var drafting: bool = minimap_drafting or (march_route_provider != null and march_route_provider.has_method("is_drafting")
		and march_route_provider.is_drafting())
	return {"mode": mode, "overrides": _heroes_overrides(mode), "drafting": drafting}


## Scenes reassign Heroes buttons whose classic slot means something else there,
## as {physical button: logical button}.
func _heroes_overrides(_mode: int) -> Dictionary:
	return {}


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
			_follow_lead_into_combat()
			_on_lead_engagement_changed(true)
		return
	if nearest <= LEAD_RELEASE_RADIUS:
		_calm_seconds = 0.0
		return
	_calm_seconds += delta
	if _calm_seconds >= LEAD_RELEASE_SECONDS:
		battle.lead_engaged = false
		_on_lead_engagement_changed(false)


## However combat starts, it hands the stick to the leader: the Lead Platoon is
## selected once, on the frame combat begins. D-pad away to command another platoon.
## When combat ends, the platoon you had selected before comes back, unless you
## switched platoons during the fight.
func _follow_lead_into_combat() -> void:
	if battle.lead_platoon_enabled and battle.lead_engaged != _lead_was_engaged:
		if battle.lead_engaged:
			_pre_combat_index = selected_index
			selected_index = Battle.LEAD_INDEX
		elif selected_index == Battle.LEAD_INDEX and battle.is_valid_command_index(_pre_combat_index):
			selected_index = _pre_combat_index
	_lead_was_engaged = battle.lead_engaged


## Scenes can react when the leader's platoon enters or leaves combat.
func _on_lead_engagement_changed(engaged: bool) -> void:
	# The marching camera faced the waypoint marker; combat turns it behind the
	# leader toward the nearest hostile (or the way the leader was walking).
	if engaged and battle.lead_platoon_enabled:
		var facing := battle.hero_heading
		var nearest := INF
		for hostile in _hostile_positions():
			var gap := hostile.distance_to(battle.hero_position)
			if gap > 0.01 and gap < nearest:
				nearest = gap
				facing = hostile - battle.hero_position
		if facing.length() > 0.001:
			_hero_yaw = atan2(-facing.x, -facing.y)
	_sync_view()


func _step_sector_cursor(movement: Vector2, delta: float) -> bool:
	if not movement.is_zero_approx():
		_mouse_cursor_active = false
		var aspect := _viewport_aspect()
		var span := _sector.view_size(aspect)
		if _sector.overview and overview_safe_frame.has_area():
			span = _sector.projection(aspect, _command_yaw, _command_pitch, overview_safe_frame).x
		var speed := span * 0.54
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
	if event == _tactical_map_request:
		var previous_cursor := cursor
		cursor = _tactical_map_target
		_move_selected()
		if not _tactical_map_result:
			cursor = previous_cursor
		return
	event = GameplayBindings.translate(event)
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
				KEY_J: if march_mode(): queue_march_waypoint()
				KEY_T: if march_mode(): clear_march_route()
				KEY_I: step_formation(-1)
				KEY_O: step_formation(1)
	elif event is InputEventJoypadMotion and _uses_joypad(event.device):
		_axes[event.axis] = event.axis_value
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			_l2_down = event.axis_value > L2_RELEASE if _l2_down else event.axis_value >= L2_PRESS
			_update_mode()
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var was_down := _r2_down
			_r2_down = event.axis_value > L2_RELEASE if was_down else event.axis_value >= L2_PRESS
			if _r2_down and not was_down:
				step_formation(1)
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		# Godot names face buttons by their Xbox positions: X is Square and A is Cross.
		match int(event.button_index):
			GameplayBindings.ACT_SET_WAYPOINT: if march_mode(): add_march_waypoint()
			GameplayBindings.ACT_ADD_WAYPOINT: if march_mode(): queue_march_waypoint()
			GameplayBindings.ACT_MOVE_ALL: move_all_troops()
			GameplayBindings.ACT_TIGHTER: step_formation(-1)
			GameplayBindings.ACT_WIDER: step_formation(1)
			GameplayBindings.ACT_CAMERA_VIEW: cycle_camera_view()
			JOY_BUTTON_LEFT_SHOULDER: step_formation(-1)
			JOY_BUTTON_DPAD_LEFT: _select_relative(-1)
			JOY_BUTTON_DPAD_RIGHT: _select_relative(1)
			JOY_BUTTON_X:
				# Square: Move in command view; while marching, add to the route.
				if command_view:
					_move_selected()
				elif march_mode():
					queue_march_waypoint()
			JOY_BUTTON_B: if march_mode(): clear_march_route()
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


func _exit_tree() -> void:
	GameplayBindings.clear_mode_provider(self)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED] and is_node_ready():
		_mouse_cursor_active = false
		_keys.clear()
		_axes.clear()
		_l2_down = false
		_update_mode()


func _uses_joypad(device: int) -> bool:
	# Follow the pad the player actually picks up: a stray HID device that connected
	# first (common on macOS) must not keep the controls.
	if _input_device < 0 or (device != _input_device and ControllerSupport.active_device == device):
		if _input_device >= 0:
			_axes.clear()
			_l2_down = false
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
		if _tactical_map_request != null:
			_tactical_map_result = routes.issue(battle, selected_index, cursor, _tactical_map_append,
				func(_point: Vector2) -> bool: return true) == MarchQueue.Result.ACCEPTED
		else:
			if tactical_minimap_enabled and march_route_provider == null:
				routes.clear(selected_index)
			battle.order_move(selected_index, cursor)
		_sync_view()


func _hold_selected() -> void:
	if command_view:
		if tactical_minimap_enabled and march_route_provider == null:
			routes.clear(selected_index)
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
	# Outside combat the camera hovers over and behind the selected platoon and looks
	# toward the waypoint marker; in combat it frames the leader.
	var marching := march_mode() and _marker_active and not march_camera_suppressed
	var selected := battle.formation_at(selected_index)
	if selected == null:
		marching = false
	var goal := _ground(selected.position, 1.15) if marching else _ground(battle.hero_position, 1.15)
	var step := get_physics_process_delta_time()
	# Ease only while marching; the leader's camera keeps its exact framing.
	if not marching or not _camera_pivot.is_finite() or step <= 0.0:
		_camera_pivot = goal
		_camera_yaw = _hero_yaw
	else:
		_camera_pivot = _camera_pivot.lerp(goal, minf(1.0, 12.0 * step))
		_camera_yaw = lerp_angle(_camera_yaw, _hero_yaw, minf(1.0, 10.0 * step))
	var hero := _camera_pivot
	var distance := (MARKER_CAMERA_DISTANCE if marching else 6.1) * CAMERA_VIEWS[_camera_view]
	var hero_offset := Vector3(0.0, sin(_hero_pitch), cos(_hero_pitch)) * distance
	var desired := hero + hero_offset.rotated(Vector3.UP, _camera_yaw)
	_hero_camera.position = _terrain.camera_position(hero, desired) if _terrain else desired
	var look_ahead := -MARKER_CAMERA_LOOK_AHEAD if marching else -2.0
	var focus := to_global(hero + Vector3(0.0, 0.0, look_ahead).rotated(Vector3.UP, _camera_yaw))
	if _hero_camera.global_position.distance_squared_to(focus) > 0.0001:
		_hero_camera.look_at(focus)
	var command_pitch := _command_pitch
	var frame_shift := Vector2.ZERO
	if _sector:
		var aspect := _viewport_aspect()
		if _sector.overview and overview_safe_frame.has_area():
			var projection := _sector.projection(aspect, _command_yaw, _command_pitch, overview_safe_frame)
			_command_camera.size = projection.x
			command_pitch = projection.y
			frame_shift = Vector2(projection.z, projection.w)
		else:
			_command_camera.size = _sector.view_size(aspect)
	var overview := _world(_sector.view_center() if _sector else battle.bounds.get_center())
	_command_camera.position = overview + Vector3(0.0, sin(command_pitch), cos(command_pitch)).rotated(Vector3.UP, _command_yaw) * _command_camera.size
	_command_camera.look_at(to_global(overview))
	if not frame_shift.is_zero_approx():
		var axes := _command_camera.transform.basis
		_command_camera.position += axes.x * frame_shift.x + axes.y * frame_shift.y


func _sync_view() -> void:
	_follow_lead_into_combat()
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
		moved = _place_formation_members(index, formation) or moved
		model.position = origin
		model.rotation.y = yaw
		if _terrain and moved:
			for slot in formation.members:
				var anchor := _formation_members[index][slot.index] as Node3D
				anchor.position.y = _terrain.ground_height(formation.member_position(slot)) - model.position.y
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
	if battle.lead_platoon_enabled and selected.uses_formations():
		_formation_label.text += "  ·  %s formation" % selected.spacing_name()
	_sync_roster()
	if command_view:
		if _sector:
			_mode_label.text = "%s  /  LIVE" % ("FIELD OVERVIEW" if _sector.overview else "TACTICAL SECTOR")
		_controls_label.text = "Release L2 / Shift to return to hero\nLeft stick / mouse: cursor   ·   Right stick / Q E R F: camera\nD-pad / Z X / left click: select   ·   Square / right click: move   ·   Cross / H: hold\nL1 / I: tighter formation   ·   R2 / O: wider formation"
		if GameplayBindings.heroes_active():
			_controls_label.text = "Back / release Shift: return to hero\nLeft stick / mouse: cursor   ·   Right stick / Q E R F: camera\nLT / RT / D-pad / Z X: select   ·   Cross / right click: move   ·   LT + RT + Cross: add waypoint\nCircle / H: hold   ·   Square / K: attack at cursor   ·   Triangle: move all troops\nL1 / O: wider formation   ·   R1 / I: tighter formation"
		if _sector:
			_controls_label.text += "\nR3 / M: overview / sector   ·   L3 / Home: center on hero"
			if not _sector.overview:
				_controls_label.text += "\nPan with the cursor or move the mouse to a screen edge"
	else:
		if hero_combat_active():
			_controls_label.text = "COMBAT · Left stick / WASD: fight as the leader   ·   Right stick / Q E R F: camera\nD-pad Left/Right / Z X: switch to another platoon   ·   Hold L2 / Shift: command view"
			if GameplayBindings.heroes_active():
				_controls_label.text = "COMBAT · Left stick / WASD: fight as the leader   ·   Cross: attack   ·   Triangle: heavy attack   ·   Hold Triangle + Circle: special\nCircle: dodge   ·   L1 / R1: guard   ·   Square: interact   ·   LT / RT / D-pad: switch platoon   ·   R3: camera view   ·   Back: mini-map"
		else:
			if battle.lead_engaged:
				_mode_label.text = "HERO VIEW  /  COMBAT · COMMANDING %s" % selected.title.to_upper()
			_controls_label.text = "MARCHING · %s · Left stick / WASD: move the waypoint   ·   %s   ·   Right stick / Q E: swing the waypoint" % [selected.title, _march_route_controls()]
			if not _march_note.is_empty():
				_controls_label.text += "\n" + _march_note

	_present_mission_hud()


func _present_mission_hud() -> void:
	if _mission_hud != null:
		_mission_hud.present(_mission_hud_state())


## Adapters supply only measured battle data. Negative HP means
## the authored encounter does not simulate that stat.
func _mission_hud_entry(index: int, hp: float = -1.0, max_hp: float = -1.0, level: int = 1) -> Dictionary:
	var group := battle.formation_at(index)
	return {
		"name": _mission_hero_name if index == Battle.LEAD_INDEX and not _mission_hero_name.is_empty() else group.title,
		"level": maxi(1, level),
		"hp": hp,
		"max_hp": max_hp,
		"selected": index == selected_index,
		"engaged": battle.lead_engaged if index == Battle.LEAD_INDEX else group.order == Battle.Order.ATTACK,
	}


func _mission_hud_state() -> Dictionary:
	var roster: Array[Dictionary] = []
	if battle.lead_platoon_enabled:
		roster.append(_mission_hud_entry(Battle.LEAD_INDEX, -1.0, -1.0, _mission_lead_level))
	elif not _mission_hero_name.is_empty():
		# The Cairnspine scout is directly controlled without a lead platoon.
		# Free movement is not an engagement or membership in a support unit.
		roster.append({
			"name": _mission_hero_name, "level": maxi(1, _mission_lead_level),
			"hp": -1.0, "max_hp": -1.0, "selected": not command_view, "engaged": false,
		})
	for index in range(battle.formations.size()):
		roster.append(_mission_hud_entry(index))
	var objective := ""
	var context := ""
	if is_instance_valid(_mission_objective_feed):
		var sample: Dictionary = _mission_objective_feed.call(&"sample")
		objective = String(sample.get("objective", ""))
		context = String(sample.get("context", ""))
	var anchor := _mission_hud_project(_hero.global_position) if not command_view else Vector2.INF
	return {
		"roster": roster,
		"bp": -1,
		"bp_max": -1,
		"objective": objective,
		"objective_visible": not objective.is_empty(),
		"context": context,
		"hero_hp": -1.0,
		"hero_max_hp": -1.0,
		"hero_anchor": anchor,
		"enemy": {},
		"combat": battle.lead_engaged and hero_combat_active(),
		"feedback": _march_note,
	}


func _mission_hud_project(world_position: Vector3) -> Vector2:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if not camera or camera.is_position_behind(world_position):
		return Vector2.INF
	var projected := camera.unproject_position(world_position)
	return projected if viewport.get_visible_rect().has_point(projected) else Vector2.INF


func _march_route_controls() -> String:
	if GameplayBindings.heroes_active():
		return "Cross / G: set waypoint (replaces route)   ·   LT + RT + Cross / J: add to route   ·   Circle / T: stop\nTriangle: move all troops   ·   Square: interact   ·   LT / RT / D-pad / Z X: change platoon\nL1 / O: wider formation   ·   R1 / I: tighter formation   ·   R3: camera view   ·   Back: mini-map"
	return "R1 / G: set waypoint (replaces route)   ·   Square / J: add to route\nCircle / D-pad Up / T: clear route   ·   D-pad Left/Right / Z X: change platoon\nL1 / I: tighter formation   ·   R2 / O: wider formation"


## The platoon roster under the selected platoon: every platoon you can switch to
## with D-pad Left/Right, the selected one in brackets, and who is fighting.
func roster_text() -> String:
	if not battle.lead_platoon_enabled and battle.formations.size() < 2:
		return ""
	var names: PackedStringArray = []
	var indices: Array[int] = []
	if battle.lead_platoon_enabled:
		indices.append(Battle.LEAD_INDEX)
	for index in range(battle.formations.size()):
		indices.append(index)
	for index in indices:
		var formation := battle.formation_at(index)
		if formation == null or not formation.can_receive_orders():
			continue
		var title := "Lead" if index == Battle.LEAD_INDEX else formation.title
		var fighting := battle.lead_engaged if index == Battle.LEAD_INDEX else formation.order == Battle.Order.ATTACK
		if fighting:
			title += " (fighting)"
		names.append("[%s]" % title if index == selected_index else title)
	return "◀ D-pad ▶   " + "  ·  ".join(names)


func _sync_roster() -> void:
	if _roster_label == null:
		_roster_label = Label.new()
		_roster_label.name = "Roster"
		_roster_label.add_theme_font_size_override("font_size", 14)
		_formation_label.add_sibling(_roster_label)
	_roster_label.text = roster_text()
	_roster_label.visible = not _roster_label.text.is_empty()


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


func _configure_formation_roles() -> void:
	if lead_has_officer_escort:
		battle.lead.configure_officer_escort()
	for index in range(battle.formations.size()):
		var group := battle.formations[index]
		var role := formation_roles[index] if index < formation_roles.size() else Battle.FormationRole.UNSPECIFIED
		var files := regular_melee_slot_files[index] if index < regular_melee_slot_files.size() else Battle.AUTHORED_MELEE_FILES
		group.configure_role(role, files, regular_melee_spacing, regular_melee_trailing_bias)
		if role == Battle.FormationRole.REGULAR_MELEE:
			group.member_footprint_check = _regular_melee_footprint_fits


func _regular_melee_footprint_fits(group: Battle.Formation, center: Vector2) -> bool:
	var low := Vector2.INF
	var high := -Vector2.INF
	for member in group.members:
		var offset := group.member_offset(member)
		low = low.min(offset)
		high = high.max(offset)
	var feet_half_size := (high - low) * 0.5
	var layout_center := (low + high) * 0.5
	var half_size := feet_half_size + group.footprint_padding
	var side := Vector2(-group.heading.y, group.heading.x)
	var back := -group.heading
	var hull_center := center + side * layout_center.x + back * layout_center.y
	for corner in [side * half_size.x + back * half_size.y, side * half_size.x - back * half_size.y]:
		if not battle.bounds.has_point(hull_center + corner) or not battle.bounds.has_point(hull_center - corner):
			return false
	var support := feet_half_size + Vector2(0.08, 0.08) if group.footprint_padding.x < 0.3 else Vector2.ZERO
	return not _terrain or _terrain.oriented_formation_fits_at(hull_center, group.heading, half_size, support)


func restart_battle() -> void:
	battle = Battle.new()
	_configure_formation_roles()
	battle.bounds = field_bounds
	battle.lead_platoon_enabled = lead_platoon_enabled
	routes.reset(battle)
	_marker_active = false
	_lead_was_engaged = false
	GameplayBindings.reset_heroes_state()
	for index in range(battle.formations.size()):
		_placed_spread[index] = -1.0
	_camera_pivot = Vector3.INF
	_calm_seconds = 0.0
	_select_starting_platoon()
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


func _select_starting_platoon() -> void:
	selected_index = Battle.LEAD_INDEX if battle.lead_platoon_enabled else 0
	_pre_combat_index = selected_index


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
			if formation.role == Battle.FormationRole.REGULAR_MELEE and index < regular_melee_staging_offsets.size():
				formation.position += regular_melee_staging_offsets[index]
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
		for slot in battle.formations[index].members:
			var member := Node3D.new()
			member.position = Vector3(slot.offset.x, 0.0, slot.offset.y)
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
	# The independent lead keeps its regular Infantry even when the subordinate
	# Shield Infantry slot equips Heavy Infantry for a Mine replay.
	var art := load(HUMAN_ESCORT_SOLDIER_MODEL) as PackedScene if lead_has_officer_escort else _lead_member_scene()
	_lead_members.clear()
	_lead_officers.clear()
	if lead_has_officer_escort:
		for slot in battle.lead.members:
			var anchor := _make_lead_member(slot.offset, troop, equipment, uniform, trim, art)
			anchor.name = "LeadSoldier%02d" % (slot.index + 1)
			_lead_members.append(anchor)
		for offset: Vector2 in Battle.LEAD_OFFICER_OFFSETS:
			var officer := _make_lead_member(offset, troop, equipment, uniform, trim, null)
			officer.name = "LeadOfficer%02d" % (_lead_officers.size() + 1)
			_lead_officers.append(officer)
	else:
		for side: float in [-1.0, 1.0]:
			for row in range(3):
				for file in range(2):
					var offset := Vector2(side * (1.5 + file * 0.85), -0.4 + row * 0.85)
					_lead_members.append(_make_lead_member(offset, troop, equipment, uniform, trim, art))
	_lead_banner = Label3D.new()
	_lead_banner.text = battle.lead.title
	_lead_banner.position = Vector3(0.0, 2.4, 0.4)
	_lead_banner.pixel_size = 0.016
	_lead_banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lead_banner.outline_size = 9
	_lead_model.add_child(_lead_banner)


func _make_lead_member(offset: Vector2, troop: Mesh, equipment: Mesh, uniform: Material, trim: Material, art: PackedScene) -> Node3D:
	var member := Node3D.new()
	member.position = Vector3(offset.x, 0.0, offset.y)
	_lead_model.add_child(member)
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
	return member


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
	_lead_banner.visible = command_view and not _shared_mission_hud_enabled
	var origin := _ground(battle.hero_position)
	var yaw := atan2(-battle.hero_heading.x, -battle.hero_heading.y)
	_lead_model.position = origin
	_lead_model.rotation.y = yaw
	_sync_lead_anchors(_lead_members, origin.y, yaw)
	_sync_lead_anchors(_lead_officers, origin.y, yaw)


func _sync_lead_anchors(anchors: Array[Node3D], origin_y: float, yaw: float) -> void:
	_apply_spread(anchors, battle.lead.spread)
	if _terrain:
		for member in anchors:
			var offset := Vector3(member.position.x, 0.0, member.position.z).rotated(Vector3.UP, yaw)
			member.position.y = _terrain.ground_height(battle.hero_position + Vector2(offset.x, offset.z)) - origin_y


## Gathers a platoon's soldiers in or fans them out as its formation changes.
## Returns true if any soldier moved.
func _place_formation_members(index: int, formation: Battle.Formation) -> bool:
	if is_equal_approx(formation.spread, _placed_spread.get(index, 1.0)):
		return false
	_placed_spread[index] = formation.spread
	var anchors: Array = _formation_members[index]
	for slot in formation.members:
		if slot.index < anchors.size():
			var anchor := anchors[slot.index] as Node3D
			var offset := formation.member_offset(slot)
			anchor.position.x = offset.x
			anchor.position.z = offset.y
	return true


## The leader's soldiers gather in or fan out from their Normal places.
static func _apply_spread(members: Array, spread: float) -> void:
	for member: Node3D in members:
		if not member.has_meta(&"formation_base"):
			member.set_meta(&"formation_base", Vector2(member.position.x, member.position.z))
		var base: Vector2 = member.get_meta(&"formation_base")
		member.position.x = base.x * spread
		member.position.z = base.y * spread


## Tighter (-1) or wider (+1) formation for the selected platoon, while marching
## and in command view.
func step_formation(direction: int) -> bool:
	if not battle.lead_platoon_enabled or not (march_mode() or command_view):
		return false
	var selected := battle.formation_at(selected_index)
	if selected == null:
		return false
	if not battle.step_spacing(selected_index, direction):
		if not selected.uses_formations():
			_march_note = "%s keep a single formation" % selected.title
		_sync_view()
		return false
	_march_note = "%s: %s formation" % [selected.title, selected.spacing_name()]
	_sync_view()
	return true


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
