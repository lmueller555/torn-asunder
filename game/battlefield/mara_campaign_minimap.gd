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

@onready var map: Minimap = $Margin/Readout/Map
@onready var _status: Label = $Margin/Readout/Status
@onready var _mission: Mission = get_parent().get_parent() as Mission


func _ready() -> void:
	map.right_click_to_move = true
	map.point_requested.connect(_focus_map_point)
	map.move_requested.connect(_move_from_map)


func _focus_map_point(point: Vector2) -> void:
	if not _mission.command_view or not _mission._sector:
		return
	_mission._mouse_cursor_active = false
	_mission.cursor = point
	_mission._sector.center_on(point)
	_mission._update_cameras()
	_mission._sync_view()


func _move_from_map(point: Vector2) -> void:
	if not _mission.command_view or not _mission._terrain or not _mission._sector:
		return
	# Use the same solid-hit rule as a world click; a painted map tile is
	# not necessarily walkable (e.g. a roof over a tunnel or a crag).
	var vertical_start := Vector3(point.x, 30.0, point.y)
	var vertical_end := Vector3(point.x, -12.0, point.y)
	if _mission._terrain.destination_from_ray(vertical_start, vertical_end) == null:
		return
	_focus_map_point(point)
	_mission._move_selected()


func _physics_process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	# Child controls are readied before their parent mission has loaded terrain.
	if not _mission.is_node_ready():
		return
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
