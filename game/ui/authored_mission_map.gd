extends Control
## Tactical chart and controller adapter for authored CommandHarness missions.
## It only sees public terrain and friendly formations; expanded orders go
## through the deployment's existing movement rules.
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Bindings := preload("res://game/settings/control_bindings.gd")
const NAME := &"AuthoredMissionMap"
const MINE_CHART := preload("res://game/battlefield/greyhollow_tactical_map.res")
const CHART_PIXELS := 256
const CHART_VOID := Color("#25291f")
const CHART_GROUND := Color("#4c5740")
const CHART_HIGH := Color("#65725b")
const CHART_SOLID := Color("#55554a")
const CHART_ROAD := Color("#93805c")
const CHART_WATER := Color("#354f48")
const CHART_SHALLOWS := Color("#526e59")
const FLOOR := Plane(Vector3.UP, 0.0)
const PAD_AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]
const PAD_NUDGE := 2.0
const PAD_SPEED := 90.0


class Exploration:
	var seen: Dictionary = {}
	var last_field: Battle

	# Preserve explored cells per deployment, not live enemy intelligence.
	func update(battle: Battle, positions: PackedVector2Array) -> Array[Rect2]:
		if last_field != battle:
			seen.clear()
			last_field = battle
		var areas: Array[Rect2] = []
		var bounds := battle.bounds
		if not bounds.has_area():
			return areas
		var cell := 18.0
		for position in positions:
			var center := Vector2i(((position - bounds.position) / cell).floor())
			for iy in range(-1, 2):
				for ix in range(-1, 2):
					var at := center + Vector2i(ix, iy)
					if at.x >= 0 and at.y >= 0:
						seen[at] = true
		for at: Vector2i in seen:
			var area := Rect2(bounds.position + Vector2(at) * cell, Vector2.ONE * cell).intersection(bounds)
			if area.has_area():
				areas.append(area)
		return areas

# Exact deployment resource paths, not mission titles or node names. Mara,
# Sereth's Cut and Ilyra's Survey have their own chart adapters.
const DEPLOYMENTS := {
	"raska_mine_witness_campaign": "mine",
	"sova_mine_evacuation_campaign": "mine",
	"neris_greyhollow_campaign": "mine",
	"mara_grain_crossing_campaign": "crossing",
	"mara_moonwash_playtest": "harbor",
	"raska_well_road_playtest": "basin",
	"raska_spanwater": "lock",
	"sova_public_record_playtest": "pass",
	"sova_vault_return_playtest": "pass",
	"ilyra_moonwash_rescue_campaign": "harbor",
	"ilyra_spanwater_playtest": "lock",
	"neris_failing_grove_playtest": "grove",
	"neris_cairnspine_survey": "boundary",
	"sereth_pass_writ_playtest": "boundary",
	"sereth_no_proxy_playtest": "pass",
}

# Public visible terrain paint only; no objective, patrol, spawn or clue markers.
# These paths add cartographic color to the projected static collision.
const PUBLIC_PAINT := {
	"crossing": {"water": ["Valley/DownstreamWater"], "shallows": ["Crossings/ShallowWater"],
		"road_colliders": ["Crossings/BridgeDeck"],
		"road": ["Routes/Seed0", "Routes/Seed1", "Routes/Seed2",
			"Routes/Seed3", "Routes/Seed4", "Routes/Bread0", "Routes/Bread1", "Routes/Bread2",
			"Routes/Bread3", "Routes/Bread4", "Routes/Bread5", "Routes/StagingApron"],
		# Invisible blockers over the actual river: keep the public water silhouette.
		"skip_colliders": ["Valley/DeepChannel1", "Valley/DeepChannel2", "Valley/DeepChannel3"]},
	"harbor": {"water": ["Geometry/Water/HarborWaterline", "Geometry/CampaignTerrain/OuterWater"]},
	"basin": {"road": ["Geometry/SaltRoad/SaltHaulRoad", "Geometry/Wells/UpperSourceTrack",
		"Geometry/SaltRoad/WestForkMarks", "Geometry/Wash/CurvingWashTrack", "Geometry/SaltRoad/BasinExitApron"]},
	"lock": {"water": ["Geometry/River/ReservoirOutline"],
		"road": ["Geometry/River/ExposedLowFord", "Geometry/Feeder/HighFeedTrack",
		"Geometry/Landing/LandingPlateauTrack", "Geometry/Landing/LandingDeck"]},
	"pass": {"road": ["Geometry/Hearing/OpenPublicTrail", "Geometry/Hearing/RecessedPublicTrail",
		"Geometry/Forecourt/ShelfRejoinPaving", "Geometry/Forecourt/SideRejoinPaving", "Geometry/Vault/CustodyPaving"]},
	"grove": {"road": ["Geometry/Road/RaisedSledRoad", "Geometry/Track/SunkenFootTrack"]},
	"boundary": {"road": ["Geometry/Road/RoadLane", "Geometry/Track/EastTrackEmergence",
		"Geometry/Track/WestTrackLead", "Geometry/Track/TrackBed", "Geometry/Road/WithdrawalLead",
		"Geometry/Ridge/ScoutApronTrack"]},
}

var map: Minimap
var expanded := false
var _host: Harness
var _source: Node3D
var _battle: Battle
var _bounds := Rect2()
var _profile := ""
var _chart_ready := false
var _exploration := Exploration.new()
var _owns_map := true
var _map_aim := Vector2.ZERO
var _aim_ready := false
var _aim_device := -1
var _map_axes: Dictionary[int, float] = {}
var _quarantine: Dictionary[int, bool] = {}
var _claimed: Dictionary[int, bool] = {}


## Map-specific scripted charts can share the order controls without layering a
## duplicate renderer or losing their discovered mission markers.
static func bind_existing_controls(host: Harness, chart: Minimap) -> Control:
	var adapter := new()
	adapter.name = &"TacticalOrderControls"
	adapter._host = host
	adapter._owns_map = false
	adapter.map = chart
	chart.add_child(adapter)
	return adapter


static func add_order_route(frame: Minimap.Frame, host: Harness, index: int, id: StringName) -> void:
	var platoon := host.battle.formation_at(index)
	if not platoon or not platoon.can_receive_orders():
		return
	if index == Battle.LEAD_INDEX and host.battle.direct_hero_control():
		return
	if platoon.order not in [Battle.Order.MOVE, Battle.Order.BLOCKED]:
		return
	var stops := host.march_waypoints(index)
	# World-issued Move can replace a pending plan; the live order wins.
	if stops.is_empty() or not platoon.destination.is_equal_approx(stops[0]):
		stops = PackedVector2Array([platoon.destination])
	var route := PackedVector2Array([platoon.position])
	route.append_array(stops)
	frame.platoon_routes[id] = route


## Validate the actual receiving formation's footprint against mounted terrain.
static func can_plot(host: Harness, point: Vector2) -> bool:
	if not point.is_finite() or not host.battle.bounds.has_point(point) or not host._terrain:
		return false
	var platoon := host.battle.formation_at(host.selected_index)
	if not platoon or not platoon.can_receive_orders():
		return false
	if host.selected_index == Battle.LEAD_INDEX and host.battle.direct_hero_control():
		return false
	var hit: Variant = host._terrain.destination_from_ray(Vector3(point.x, 64.0, point.y), Vector3(point.x, -32.0, point.y))
	return hit != null and host._terrain.formation_fits_at(hit) and platoon.footprint_fits(hit)


## Hit-test visible friendly formations in screen pixels, not world meters.
static func select_platoon_at(host: Harness, chart: Minimap, point: Vector2) -> bool:
	var at := chart.project(point)
	var closest := 10.0
	var found := -2
	for index in range(Battle.LEAD_INDEX, host.battle.formations.size()):
		var platoon := host.battle.formation_at(index)
		if not platoon or not platoon.can_receive_orders() or (index == Battle.LEAD_INDEX and not host.battle.lead_platoon_enabled):
			continue
		var distance := at.distance_to(chart.project(platoon.position))
		if distance < closest:
			closest = distance
			found = index
	if found == -2:
		return false
	host.selected_index = found
	host._sync_view()
	return true


func command_cursor() -> Variant:
	return _map_aim if expanded and _aim_ready else null


## Call once after adding an actual campaign deployment to the tree. Repeated
## calls return the same adapter; existing/unknown deployments are untouched.
static func mount(host: Node3D) -> Control:
	var field := host as Harness
	if field == null or not field.is_node_ready() or field._terrain == null or field._sector == null:
		return null
	var prefix := "res://game/battlefield/"
	if not field.scene_file_path.begins_with(prefix) or not field.scene_file_path.ends_with(".tscn"):
		return null
	var profile: String = DEPLOYMENTS.get(field.scene_file_path.trim_prefix(prefix).trim_suffix(".tscn"), "")
	var layer := field.get_node_or_null("HUD") as CanvasLayer
	if profile.is_empty() or layer == null or not field.tactical_minimap_enabled:
		return null
	var existing := layer.get_node_or_null(NodePath(NAME)) as Control
	if existing != null:
		return existing
	var adapter := new()
	adapter.name = NAME
	adapter._host = field
	adapter._profile = profile
	layer.add_child(adapter)
	return adapter


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _owns_map:
		map = Minimap.new()
		map.name = &"Chart"
		map.tactical_style = true
		add_child(map)
		map.place_tactical_overlay(false)
		map.hide()
	# Disable the shared widget's direct signals; this adapter owns commands.
	map.click_to_focus = false
	map.tooltip_text = "In command: N / LT + D-pad Up to open. Right-click / A sets a waypoint; Ctrl + right-click / RB appends. Click a platoon / X to switch."
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	map.mouse_entered.connect(_stop_edge_pan)
	map.gui_input.connect(_map_input)
	Input.joy_connection_changed.connect(_joy_connection)


func _process(delta: float) -> void:
	if not _can_order() and expanded:
		_set_expanded(false)
	if expanded and _aim_device >= 0:
		var motion := Vector2(_map_axes.get(JOY_AXIS_LEFT_X, 0.0), _map_axes.get(JOY_AXIS_LEFT_Y, 0.0))
		if motion.length() > Harness.STICK_DEADZONE:
			_nudge(motion.limit_length() * PAD_SPEED * delta)
	if _owns_map:
		refresh()


func refresh() -> void:
	if not is_instance_valid(_host) or not _host.is_visible_in_tree() or get_tree().paused:
		_hide_chart()
		return
	if _battle != _host.battle:
		_battle = _host.battle
		_set_expanded(false)
	var changed := _source != _host._field or _bounds != _battle.bounds
	if changed:
		_source = _host._field
		_bounds = _battle.bounds
		_chart_ready = false
	if (not _host.command_view and _battle.lead_engaged and _host.selected_index == Battle.LEAD_INDEX) \
		or not _bounds.has_area():
		_hide_chart()
		return
	if not _chart_ready:
		map.terrain_texture = MINE_CHART if _profile == "mine" else build_terrain(_host, PUBLIC_PAINT[_profile])
		map.set_field_bounds(_bounds)
		_chart_ready = true
	if map.terrain_texture == null:
		_hide_chart()
		return
	map.show()
	var frame := Minimap.Frame.new()
	frame.hero = Minimap.Marker.new(&"hero", _battle.hero_position, _battle.hero_heading)
	frame.selected_hero = _battle.lead_platoon_enabled and _host.selected_index == Battle.LEAD_INDEX
	add_order_route(frame, _host, Battle.LEAD_INDEX, &"hero")
	var friends := PackedVector2Array([_battle.hero_position])
	for index in range(_battle.formations.size()):
		var platoon := _battle.formations[index]
		if not platoon.can_receive_orders():
			continue
		var id := StringName("formation_%d" % index)
		frame.allies.append(Minimap.Marker.new(id, platoon.position, platoon.heading))
		add_order_route(frame, _host, index, id)
		friends.append(platoon.position)
		if index == _host.selected_index:
			frame.selected_ally = id
	frame.camera_footprint = _camera_footprint()
	frame.command_cursor = command_cursor()
	frame.explored_areas = _exploration.update(_battle, friends)
	map.show_frame(frame)


func _hide_chart() -> void:
	if map.visible:
		map.show_frame(null)
		map.hide()
	_set_expanded(false)


func _set_expanded(value: bool, device := -1) -> void:
	if value == expanded:
		return
	expanded = value
	map.set_tactical_expanded(value)
	_aim_device = device if value else -1
	_aim_ready = value
	if value:
		_map_aim = _host.battle.clamp_to_field(_host.cursor)
		_stop_edge_pan()
	for axis: int in PAD_AXES:
		var previous: float = _map_axes.get(axis, _host._axis(axis))
		if absf(previous) > Harness.STICK_DEADZONE:
			_quarantine[axis] = true
		_host._axes.erase(axis)
	_map_axes.clear()


func _can_order() -> bool:
	return (is_instance_valid(_host) and _host.command_view and map.is_visible_in_tree()
		and not get_tree().paused)


func _input(raw: InputEvent) -> void:
	if not is_instance_valid(_host) or get_tree().paused:
		return
	var event := Bindings.translate(raw)
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if expanded and code == KEY_SHIFT and not event.pressed and not _host._l2_down:
			_set_expanded(false)
		if _host.command_view and Minimap.is_tactical_toggle(event):
			if _owns_map and not map.is_visible_in_tree():
				refresh()
			if _can_order():
				_set_expanded(not expanded)
				get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		_on_pad_button(event)
	elif event is InputEventJoypadMotion:
		_on_pad_axis(event)


func _on_pad_button(event: InputEventJoypadButton) -> void:
	var button := int(event.button_index)
	# Pause, Options, Start, Back, and other shell inputs never belong to the map.
	if button not in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER,
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		return
	if not _host._uses_joypad(event.device):
		return
	if _claimed.has(button) and not event.pressed:
		_claimed.erase(button)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or not _host._l2_down:
		return
	if _owns_map and button == JOY_BUTTON_DPAD_UP and not map.is_visible_in_tree():
		refresh()
	if not _can_order():
		return
	if (not expanded or _aim_device < 0) and button == JOY_BUTTON_DPAD_UP:
		if expanded:
			_set_expanded(false)
		_set_expanded(true, event.device)
	elif expanded and _aim_device == event.device:
		match button:
			JOY_BUTTON_B: _set_expanded(false)
			JOY_BUTTON_A: _host.request_tactical_map_order(_map_aim, false)
			JOY_BUTTON_X: _host._select_relative(1)
			JOY_BUTTON_RIGHT_SHOULDER: _host.request_tactical_map_order(_map_aim, true)
			JOY_BUTTON_DPAD_LEFT: _nudge(Vector2.LEFT * PAD_NUDGE)
			JOY_BUTTON_DPAD_RIGHT: _nudge(Vector2.RIGHT * PAD_NUDGE)
			JOY_BUTTON_DPAD_UP: _nudge(Vector2.UP * PAD_NUDGE)
			JOY_BUTTON_DPAD_DOWN: _nudge(Vector2.DOWN * PAD_NUDGE)
	else:
		return
	_claimed[button] = true
	get_viewport().set_input_as_handled()


func _on_pad_axis(event: InputEventJoypadMotion) -> void:
	var axis := int(event.axis)
	if not _host._uses_joypad(event.device):
		return
	var value := event.axis_value if is_finite(event.axis_value) else 0.0
	if axis == JOY_AXIS_TRIGGER_LEFT:
		if expanded and _aim_device == event.device and value <= Harness.L2_RELEASE and not _host._keys.has(KEY_SHIFT):
			_set_expanded(false)
		return # Native command/camera mode must see L2 and its release.
	if axis not in PAD_AXES:
		return
	if _quarantine.has(axis):
		if absf(value) <= Harness.STICK_DEADZONE:
			_quarantine.erase(axis)
		get_viewport().set_input_as_handled()
	elif expanded and _aim_device == event.device:
		_map_axes[axis] = value
		get_viewport().set_input_as_handled()


func _nudge(delta: Vector2) -> void:
	_map_aim = _host.battle.clamp_to_field(_map_aim + delta)


func _joy_connection(device: int, connected: bool) -> void:
	if not connected and device == _aim_device:
		_set_expanded(false)
		_quarantine.clear()
		_claimed.clear()


func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_set_expanded(false)
		_quarantine.clear()
		_claimed.clear()
		if _owns_map:
			_hide_chart()


func _map_input(raw: InputEvent) -> void:
	if not _can_order() or not expanded:
		return
	var event := Bindings.translate(raw)
	if event is InputEventMouseMotion:
		var point: Variant = map.unproject(event.position)
		if point != null:
			_map_aim = point
			_aim_ready = true
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var point: Variant = map.unproject(event.position)
		if point == null:
			return
		_map_aim = point
		_aim_ready = true
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_platoon_at(_host, map, point)
		else:
			_host.request_tactical_map_order(point, event.ctrl_pressed)
		map.accept_event()


func _stop_edge_pan() -> void:
	# This is a UI-only flag. Do not leave a pre-hover edge pan running.
	if map.is_visible_in_tree() and is_instance_valid(_host):
		_host._mouse_cursor_active = false


func _camera_footprint() -> PackedVector2Array:
	var camera := get_viewport().get_camera_3d()
	var rect := get_viewport().get_visible_rect()
	if camera != _host._command_camera or not rect.has_area() or not is_instance_valid(_source):
		return PackedVector2Array()
	var points := PackedVector2Array()
	for pixel in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var origin := _source.to_local(camera.project_ray_origin(pixel))
		var direction := _source.global_basis.inverse() * camera.project_ray_normal(pixel)
		var hit: Variant = FLOOR.intersects_ray(origin, direction)
		if hit == null:
			return PackedVector2Array()
		points.append(Vector2(hit.x, hit.z))
	return points


## Project the mounted static bodies on the same registered solid/walkable
## layers as CommandTerrain. This is a static reference chart, NOT a pathfinding
## mask. Public road/water paint comes from the exact visible shapes above.
## Rasterizing a bounded 256px chart once avoids loading map art or per-frame rays.
static func build_terrain(host: Node3D, paths: Dictionary = {}) -> Texture2D:
	var source := host as Harness
	if source == null or source._field == null or source._terrain == null:
		return null
	var field := source._field
	var bounds := source.battle.bounds
	if not bounds.has_area() or not bounds.position.is_finite() or not bounds.size.is_finite():
		return null
	var extent := (bounds.size * (float(CHART_PIXELS) / maxf(bounds.size.x, bounds.size.y))).round()
	var image := Image.create_empty(maxi(1, int(extent.x)), maxi(1, int(extent.y)), false, Image.FORMAT_RGBA8)
	image.fill(CHART_VOID)
	var pieces: Array[Dictionary] = []
	for item in field.find_children("*", "CollisionShape3D", true, false):
		var shape := item as CollisionShape3D
		var body := shape.get_parent() as StaticBody3D
		if shape.disabled or body == null or not (body.collision_layer & Terrain.SOLID_MASK):
			continue
		# Ignore invisible paths placed outside this registered scene or UI.
		var body_path := str(field.get_path_to(body))
		if body_path in paths.get("skip_colliders", []):
			continue
		var transform := field.global_transform.affine_inverse() * shape.global_transform
		var points := PackedVector3Array()
		if shape.shape is BoxShape3D:
			points = _box_points(AABB(-shape.shape.size * 0.5, shape.shape.size))
		elif shape.shape is ConvexPolygonShape3D:
			points = shape.shape.points
		else:
			continue # Deliberate: never substitute an invented footprint.
		var piece := _project_piece(points, transform, true)
		if piece.is_empty():
			continue
		piece.color = CHART_SOLID
		if body.collision_layer & Terrain.WALKABLE_MASK:
			piece.color = CHART_GROUND.lerp(CHART_HIGH, clampf(float(piece.height) / 22.0, 0.0, 1.0))
			if float(piece.height) < 0.0:
				piece.color = CHART_GROUND.darkened(minf(absf(piece.height) / 42.0, 0.25))
		if body_path in paths.get("road_colliders", []):
			piece.color = CHART_ROAD
		pieces.append(piece)
	if pieces.is_empty():
		return null
	for kind in ["water", "shallows", "road"]:
		for path in paths.get(kind, []):
			var node := field.get_node_or_null(path) as Node3D
			if node == null or not node.is_visible_in_tree():
				continue
			var points := PackedVector3Array()
			var convex := false
			if node is MeshInstance3D and (node.mesh is BoxMesh or node.mesh is PlaneMesh):
				points = _box_points(node.mesh.get_aabb())
				convex = true
			elif node is CSGPolygon3D and node.mode == CSGPolygon3D.MODE_DEPTH:
				for point in node.polygon:
					points.append(Vector3(point.x, point.y, 0.0))
			var piece := _project_piece(points, field.global_transform.affine_inverse() * node.global_transform, convex)
			if not piece.is_empty():
				match kind:
					"water": piece.color = CHART_WATER
					"shallows": piece.color = CHART_SHALLOWS
					_: piece.color = CHART_ROAD
				piece.height += 0.03
				pieces.append(piece)
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.height < b.height)
	for piece in pieces:
		var pixels := PackedVector2Array()
		for point: Vector2 in piece.polygon:
			pixels.append((point - bounds.position) / bounds.size * extent)
		_paint(image, pixels, piece.color)
	return ImageTexture.create_from_image(image)


static func _box_points(box: AABB) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for index in range(8):
		vertices.append(box.get_endpoint(index))
	return vertices


static func _project_piece(points: PackedVector3Array, transform: Transform3D, convex: bool) -> Dictionary:
	var polygon := PackedVector2Array()
	var top := -INF
	for vertex in points:
		var at := transform * vertex
		polygon.append(Vector2(at.x, at.z))
		top = maxf(top, at.y)
	if convex and polygon.size() >= 3:
		polygon = Geometry2D.convex_hull(polygon)
		polygon.remove_at(polygon.size() - 1) # convex_hull repeats first point.
	if polygon.size() < 3 or not is_finite(top):
		return {}
	return {"polygon": polygon, "height": top}


## Even-odd scanline fill preserves concave authored road strips.
static func _paint(image: Image, polygon: PackedVector2Array, color: Color) -> void:
	var min_y := INF
	var max_y := -INF
	for at in polygon:
		min_y = minf(min_y, at.y)
		max_y = maxf(max_y, at.y)
	for y in range(clampi(ceili(min_y - 0.5), 0, image.get_height()), clampi(ceili(max_y - 0.5), 0, image.get_height())):
		var scan := float(y) + 0.5
		var edges := PackedFloat32Array()
		var previous := polygon[-1]
		for at in polygon:
			if (previous.y > scan) != (at.y > scan):
				edges.append(lerpf(previous.x, at.x, (scan - previous.y) / (at.y - previous.y)))
			previous = at
		edges.sort()
		for i in range(0, edges.size() - 1, 2):
			var left := clampi(ceili(edges[i] - 0.5), 0, image.get_width())
			var right := clampi(ceili(edges[i + 1] - 0.5), 0, image.get_width())
			if right > left:
				image.fill_rect(Rect2i(left, y, right - left, 1), color)
