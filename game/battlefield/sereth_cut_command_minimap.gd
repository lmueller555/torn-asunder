extends PanelContainer
## Cut-only adapter for the existing minimap and command harness. It has
## neither raider awareness nor any controller input bindings.

const Harness := preload("res://game/battlefield/command_harness.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const SECTOR_PLANE := Plane(Vector3.UP, 0.0)

var _field: Harness

@onready var map: Minimap = $Margin/Readout/Map


func _ready() -> void:
	map.right_click_to_move = true
	map.point_requested.connect(_focus_sector)
	map.move_requested.connect(_move_from_map)
	mouse_entered.connect(_stop_world_mouse_pan)
	map.mouse_entered.connect(_stop_world_mouse_pan)


func refresh(field: Harness, available: bool) -> void:
	_field = field
	var active := available and field.command_view and field._sector != null and field._terrain != null
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


func _move_from_map(point: Vector2) -> void:
	if not _usable(point) or not _field.battle.formations[_field.selected_index].can_receive_orders():
		return
	# Like the world mouse, a solid first hit must also be tagged walkable.
	# Cast vertically so the map never orders the roof above the record room.
	var start := Vector3(point.x, 64.0, point.y)
	var finish := Vector3(point.x, -16.0, point.y)
	var hit: Variant = _field._terrain.destination_from_ray(start, finish)
	if hit == null:
		return
	_snap_sector(hit)
	_field._move_selected()


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
