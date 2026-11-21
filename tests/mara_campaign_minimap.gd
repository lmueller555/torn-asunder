extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Pocket := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Adapter := preload("res://game/battlefield/mara_campaign_minimap.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _hud: Adapter
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_hud = _mission.get_node("MinimapHUD/Panel") as Adapter
	_hud.set_physics_process(false)
	await process_frame
	var map := _hud.map
	var fight := _mission.encounter
	_hud.refresh()

	_check(map.is_visible_in_tree() and map.map_rect().has_area() and map.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The campaign minimap lays out as a passive HUD.")
	_check(map.get_global_rect().position.x > 550 and map.get_global_rect().position.y > 375,
		"The minimap sits in its own lower-right HUD area.")
	_check(map.marker_pixel(&"Mara") == map.project(_mission.battle.hero_position)
		and map.marker_pixel(&"Godbridle") == map.project(_point("Objectives/GodbridlePickup"))
		and map.marker_pixel(&"East exit") == null and map.marker_pixel(&"Pass warning") == null
		and map.marker_pixel(&"Orc guard") == null and map.sector_pixels().is_empty(),
		"Hero view shows hero and pickup, but not the exit, reserve, or a command-camera footprint.")
	_check(_glyph(&"Shield Infantry").selected and not _glyph(&"Archers").selected, "Initial formation selection is represented.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_tick()
	var local_sector := map.sector_pixels()
	_check(not local_sector.is_empty() and _footprint_contains_hero() and _glyph(&"Archers").selected,
		"L2 projects the active tactical camera and changing selection highlights Archers.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_tick()
	_check(not map.sector_pixels().is_empty()
		and _polygon_screen_area(map.sector_pixels()[0]) > _polygon_screen_area(local_sector[0]) * 1.5,
		"The overview updates the footprint from the larger active command camera.")
	_button(JOY_BUTTON_LEFT_STICK)
	_tick()
	var inspect := _point("Routes/EastPass")
	_map_click(MOUSE_BUTTON_LEFT, map.project(inspect))
	_tick()
	_check(map.mouse_filter == Control.MOUSE_FILTER_STOP and _mission.cursor.is_equal_approx(inspect)
			and _mission._sector.focus.is_equal_approx(inspect)
			and _mission.battle.formations[1].order == Battle.Order.HOLD,
			"Left-clicking the minimap recenters on the world point without ordering a platoon.")
	var orders := _point("Routes/RoadWest")
	_map_click(MOUSE_BUTTON_RIGHT, map.project(orders))
	_check(_mission.battle.formations[1].order == Battle.Order.MOVE
			and _mission.battle.formations[1].destination.is_equal_approx(orders),
			"Right-click maps to the walkable road world coordinate, not behind the HUD.")
	_map_click(MOUSE_BUTTON_RIGHT, Vector2(2.0, 2.0))
	_check(_mission.battle.formations[1].destination.is_equal_approx(orders),
			"Clicks in the map's letterbox cannot alter the order.")
	var blocked := _non_walkable_map_point()
	_check(blocked != Vector2.INF, "The field has a drawn location without valid walkable ground.")
	if blocked != Vector2.INF:
		_map_click(MOUSE_BUTTON_RIGHT, map.project(blocked))
		_check(_mission.battle.formations[1].destination.is_equal_approx(orders),
				"A map order on solid obstacles or void leaves the previous order intact.")
	_button(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	_map_click(MOUSE_BUTTON_RIGHT, map.project(orders))
	_check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE and map.sector_pixels().is_empty()
			and map.marker_pixel(&"Archers") != null and _mission.battle.formations[1].order == Battle.Order.HOLD,
		"Hero view keeps the map passive, no accidental order, while still showing positions.")

	_mission.battle.hero_position = fight.enemy_position + Vector2(0, 1.5)
	_tick()
	_check(map.marker_pixel(&"Orc guard") == null and map.marker_pixel(&"Pass warning") == null,
		"An unreleased reserve is not reported as a marked contact even with a nearby unit.")
	_mission.restart_mission()
	fight = _mission.encounter
	for id: String in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard",
		"Objectives/GodbridlePickup"]:
		_drive_to(id)
	_button(JOY_BUTTON_A)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.ESCORTING and map.marker_pixel(&"Godbridle") == null
		and map.marker_pixel(&"East exit") == map.project(_point("Objectives/GodbridleExit"))
		and map.marker_pixel(&"Orc guard") == null, "The real pickup switches the objective glyph to the actual exit.")
	for id: String in ["Routes/MineYard", "Routes/RoadWest", "Routes/RoadJunction", "Routes/RoadCut", "Routes/EastPass"]:
		_drive_to(id, id == "Routes/EastPass")
	_check(_mission.objective.interception_triggered and map.marker_pixel(&"Pass warning") == map.project(_point("Routes/InterceptRoadMerge"))
		and map.marker_pixel(&"Orc guard") == null and _hud._status.text.contains("INTERCEPTION REPORTED"),
		"Actual approach announces the road hazard without showing an unseen Orc's position.")

	_drive_to("Routes/EastPass")
	for step in range(200):
		if map.marker_pixel(&"Orc guard") != null:
			break
		_tick()
	_check(map.marker_pixel(&"Orc guard") == map.project(fight.enemy_position) and _hud._status.text.contains("ORC IN SIGHT"),
		"Once within unobstructed friendly sight, the live Orc position appears separately from the warning.")
	_drive_to("Routes/RoadCut")
	_check(map.marker_pixel(&"Orc guard") == null and map.marker_pixel(&"Pass warning") != null,
		"Retreat removes lost contact while retaining the reported road hazard.")
	# Fix both actors on opposite sides of the actual north pass crag. They
	# are within scouting distance; the obstruction alone hides the contact.
	_mission.battle.hero_position = _point("Routes/EastPass")
	fight.enemy_position = Vector2(96.0, -35.0)
	_hud.refresh()
	_check(map.marker_pixel(&"Orc guard") == null and map.marker_pixel(&"Pass warning") != null,
		"Solid cover hides an announced Orc even when it is within the spotting radius.")
	fight.enemy.receive_damage(fight.enemy.max_hp)
	_tick()
	_check(map.marker_pixel(&"Orc guard") == null and map.marker_pixel(&"Pass warning") == null,
		"Defeating the guard clears both the live marker and warning.")
	_mission.restart_mission()
	_tick()
	_check(map.marker_pixel(&"Godbridle") != null and map.marker_pixel(&"East exit") == null
		and map.marker_pixel(&"Orc guard") == null and map.marker_pixel(&"Pass warning") == null,
		"Restart restores pickup state without leaking last attempt's enemy or warning.")

	var pocket := Pocket.instantiate()
	_check(not pocket.has_node("MinimapHUD"), "The pocket prototype and shared mission scene remain opt-out.")
	pocket.free()
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Mara minimap: real camera, orders, pickup, interception, visible contact, retreat, defeat and retry passed.")
	quit(0 if _failures == 0 else 1)


func _glyph(id: StringName) -> Minimap.Glyph:
	for mark in _hud.map._glyphs:
		if mark.id == id:
			return mark
	return null


func _footprint_contains_hero() -> bool:
	var point := _hud.map.project(_mission.battle.hero_position)
	for outline in _hud.map.sector_pixels():
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
	return false


func _polygon_screen_area(polygon: PackedVector2Array) -> float:
	var shoelace := 0.0
	for index in range(polygon.size()):
		shoelace += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(shoelace) * 0.5


func _map_click(button: MouseButton, local_pixel: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = _hud.map.get_global_rect().position + local_pixel
	event.pressed = true
	root.push_input(event, true)


func _non_walkable_map_point() -> Vector2:
	var bounds := _mission.battle.bounds
	for x in range(1, 14):
		for z in range(1, 14):
			var point := bounds.position + bounds.size * Vector2(x, z) / 14.0
			var from := Vector3(point.x, 30.0, point.y)
			var to := Vector3(point.x, -12.0, point.y)
			if _mission._terrain.destination_from_ray(from, to) == null:
				return point
	return Vector2.INF


func _point(id: String) -> Vector2:
	var mark := _mission.battlefield_marker(NodePath("Markers/" + id))
	var p := _mission.to_local(mark.global_position)
	return Vector2(p.x, p.z)


func _drive_to(id: String, stop_at_interception := false) -> void:
	var target := _point(id)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 100
	var reached := false
	for step in range(budget):
		var remaining := target - _mission.battle.hero_position
		if remaining.length() < 0.14 or (stop_at_interception and _mission.objective.interception_triggered):
			reached = true
			break
		var aim := remaining.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(reached, "The hero reaches the actual route checkpoint %s." % id)


func _tick() -> void:
	_mission._physics_process(DT)
	_hud.refresh()


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
