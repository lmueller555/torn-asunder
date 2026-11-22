extends SceneTree
## Runtime coverage for authored cards: the old map cannot issue a duplicate
## order; both portraits and plans are sourced from the real deployment.
const Adapter := preload("res://game/ui/authored_mission_map.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Bindings := preload("res://game/settings/control_bindings.gd")
const Catalog := preload("res://game/campaign_missions.gd")
const Deployments := preload("res://game/campaign_deployments.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event)

func _button(code: JoyButton, device := 0) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = code
		event.pressed = down
		root.push_input(event)

func _l2(strength: float, device := 0) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = strength
	root.push_input(event)

func _click(chart: Minimap, world: Vector2, button := MOUSE_BUTTON_RIGHT, append := false) -> void:
	var point := chart.get_global_rect().position + chart.project(world)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.ctrl_pressed = append
		event.pressed = down
		root.push_input(event)

func _active_map(host: Node) -> Minimap:
	for child in host.find_children("*", "Control", true, false):
		if child is Minimap and child.tactical_style:
			return child
	return null

func _run() -> void:
	root.size = Vector2i(1440, 810)
	var deployment_count := 0
	for campaign in ["mara", "raska", "sova", "ilyra", "neris", "sereth"]:
		for mission in Catalog.missions_for_campaign(campaign):
			var id: String = mission.id
			var host := Deployments.for_mission(id).scene.instantiate() as Harness
			host.enable_tactical_minimap()
			host.enable_shared_mission_hud()
			root.add_child(host)
			var adapter := Adapter.mount(host)
			if adapter:
				adapter.refresh()
			await process_frame
			await process_frame
			deployment_count += 1
			var map := _active_map(host)
			_check(map != null and map.is_visible_in_tree(), id + " compact displayed")
			if map == null:
				host.free()
				continue
			_check(map.terrain_texture != null, id + " real terrain")
			_check(map.size == Minimap.TACTICAL_COMPACT_SIZE, id + " compact size " + str(map.size))
			if id in ["mara_mine_escort", "sereth_voices_at_the_cut", "mara_grain_crossing"]:
				_check_tooltip_presets(id, map)
			_key(KEY_SHIFT, true)
			_check(host.command_view, id + " enters command")
			await process_frame
			_key(KEY_N, true)
			_key(KEY_N, false)
			await process_frame
			await process_frame
			_check(map.size == Minimap.TACTICAL_EXPANDED_SIZE, id + " keyboard expands " + str(map.size))
			if id == "mara_grain_crossing":
				await _exercise_grain(host, map, adapter)
			elif id in ["mara_mine_escort", "sereth_voices_at_the_cut", "ilyra_coast_survey"]:
				await _exercise_bespoke(id, host, map)
			_key(KEY_SHIFT, false)
			await process_frame
			await process_frame
			_check(map.size == Minimap.TACTICAL_COMPACT_SIZE, id + " releases to compact " + str(map.size))
			host.free()
	_check(deployment_count == 18, "all normal campaign deployments")
	print("%d/%d authored tactical map checks passed." % [checks - failures, checks])
	quit(1 if failures else 0)

## The three missions represent the Mine, Cut and shared authored chart tooltip owners.
func _check_tooltip_presets(id: String, map: Minimap) -> void:
	var source := map.tooltip_text
	var classic := "In command: N / LT + D-pad Up to open."
	var heroes := "In command: N / Back, then D-pad Up to open."
	_check(source.begins_with(classic), id + " stock Classic chart hint")
	Bindings.set_layout(Bindings.Layout.HEROES, "")
	_check(Bindings.heroes_active() and TranslationServer.translate(source) == source.replace(classic, heroes),
		id + " Heroes opening hint changes without altering keyboard or waypoint hints")
	Bindings.set_layout(Bindings.Layout.CLASSIC, "")
	_check(TranslationServer.translate(map.tooltip_text) == source, id + " Classic hint returns on same chart")


func _exercise_grain(host: Harness, map: Minimap, adapter: Control) -> void:
	var commanded: Array[int] = []
	host.battle.formation_commanded.connect(func(index: int) -> void: commanded.append(index))
	var first := host.battle.formations[0].position
	var at := _open_ground(host, first, 2.0)
	var subsequent := _open_ground(host, first, 12.0)
	_check(at.is_finite() and subsequent.is_finite(), "Grain test found two legal points")
	if not at.is_finite() or not subsequent.is_finite():
		return
	_click(map, Vector2.ZERO)
	_check(commanded.is_empty(), "Grain water rejected")
	_click(map, at)
	_check(commanded == [0] and host.march_waypoints(0).size() == 1, "Grain one native Move from mouse")
	_click(map, subsequent, MOUSE_BUTTON_RIGHT, true)
	_check(commanded == [0] and host.march_waypoints(0).size() == 2, "Grain append doesn't repeat or replace native Move")
	await process_frame
	_check(map._ally_routes.has(&"formation_0") and map._selected_route_id == &"formation_0", "accepted route reads into chart")
	_key(KEY_SHIFT, false)
	_l2(0.8)
	_button(JOY_BUTTON_DPAD_UP)
	_check(adapter.expanded, "L2/D-pad expands and drafts")
	_button(JOY_BUTTON_X)
	var idx := host.selected_index
	_check(idx != 0 and host.battle.is_valid_command_index(idx), "map controller changes platoon")
	var next := _open_ground(host, host.battle.formation_at(idx).position, 3.0)
	adapter._map_aim = next
	_button(JOY_BUTTON_A)
	_check(commanded == [0, idx], "controller confirms native Move")
	_check(host.march_waypoints(0).size() == 2 and host.march_waypoints(idx).size() == 1,
		"each platoon queue survives selection")
	await process_frame
	_check(map._ally_routes.size() == 2, "selected and muted orders both present")
	_button(JOY_BUTTON_BACK)
	_check(adapter.expanded, "map never claims Back")
	_button(JOY_BUTTON_B)
	_check(not adapter.expanded, "map cancel releases aiming")
	_l2(0.0)
	_key(KEY_SHIFT, true)
	_key(KEY_N, true)
	var observation := Grain.Observation.new()
	observation.hero_fell = true
	host.objective.advance(observation)
	_check(not host.request_tactical_map_order(at, false), "real mission defeat gate refuses command")
	_check(commanded == [0, idx], "invalid, pause and defeat never issue ghost orders")

func _exercise_bespoke(id: String, host: Harness, map: Minimap) -> void:
	# The authored wrappers update input ownership on the next simulation tick.
	# Drive that tick explicitly before clicking, even when Godot runs unthrottled.
	await physics_frame
	host._sync_view()
	await process_frame
	var commanded: Array[int] = []
	host.battle.formation_commanded.connect(func(index: int) -> void: commanded.append(index))
	var first := host.battle.formations[0].position
	var at := _open_ground(host, first, 7.0)
	var subsequent := _open_ground(host, first, 12.0)
	_check(at.is_finite() and subsequent.is_finite(), id + " two orderable map points")
	if not at.is_finite() or not subsequent.is_finite():
		return
	_click(map, at)
	_check(commanded == [0] and host.march_waypoints(0).size() == 1, id + " exactly one genuine tactical mouse Move")
	_click(map, subsequent, MOUSE_BUTTON_RIGHT, true)
	_check(commanded == [0] and host.march_waypoints(0).size() == 2, id + " tactical mouse append preserved Move")
	await physics_frame
	await process_frame
	host._sync_view()
	if id == "mara_mine_escort":
		map.get_parent().get_parent().get_parent().call(&"refresh")
	_check(map._selected_route_id != &"" and map._ally_routes.has(map._selected_route_id),
		id + " native accepted queue renders: " + str(map._ally_routes))
	_check(not map._explored_areas.is_empty(), id + " fog uses live friendly exploration")
	_key(KEY_SHIFT, false)
	await process_frame
	_l2(0.85)
	_button(JOY_BUTTON_DPAD_UP)
	await process_frame
	await physics_frame
	await physics_frame
	_check(map.size == Minimap.TACTICAL_EXPANDED_SIZE, id + " controller expands existing map")
	_check(map._command_cursor is Vector2, id + " controller reticle rendered")
	if map._command_cursor is Vector2:
		var position: Vector2 = map._command_cursor
		_button(JOY_BUTTON_DPAD_RIGHT)
		await process_frame
		await physics_frame
		await physics_frame
		_check(map._command_cursor is Vector2 and position != map._command_cursor, id + " controller moves reticle on map")
	_button(JOY_BUTTON_BACK)
	_check(map.size == Minimap.TACTICAL_EXPANDED_SIZE, id + " Back remains available to title Pause")
	_button(JOY_BUTTON_B)
	_l2(0.0)
	await process_frame
	await process_frame
	_check(map.size == Minimap.TACTICAL_COMPACT_SIZE, id + " controller cancel releases capture")


func _open_ground(host: Harness, center: Vector2, radius: float) -> Vector2:
	for axis in range(16):
		var at := center + Vector2.from_angle(TAU * float(axis) / 16.0) * radius
		if Adapter.can_plot(host, at) and Adapter.can_plot(host, at + Vector2(0.02, 0.02)) \
				and Adapter.can_plot(host, at - Vector2(0.02, 0.02)):
			return at
	return Vector2.INF
