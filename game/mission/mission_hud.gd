extends Control
## Mission HUD: objectives, minimap, hero and Battle Points, the unit roster, dialogue,
## command-view overlays, world-space health bars and the result screen.

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const TacticalUnits := preload("res://game/mission/mission_units.gd")
const Battle := preload("res://game/mission/mission_battle.gd")
const Missions := preload("res://game/mission/missions.gd")
const Campaigns := preload("res://game/campaigns.gd")
const BODY := preload("res://assets/fonts/SourceSans3.ttf")
const DISPLAY := preload("res://assets/fonts/Cinzel.ttf")

const GOLD := Color("#e5bd7e")
const IVORY := Color("#f4e8d5")
const MUTED := Color("#b5afa2")
const PANEL := Color(0.05, 0.06, 0.06, 0.72)
const LINE := Color(0.63, 0.55, 0.43, 0.55)
const GREEN := Color("#63935d")
const RED := Color("#a84c47")
const BLACK := Color("#08090a")
const BP := Color("#7fb6e8")

const MAP_LAND := Color("#50563e")
const MAP_STONE := Color("#767260")
const MAP_WATER := Color("#3d5250")
const MAP_PIXELS := 192


# Native map plus the generic scenario's existing world-size objective zones.
class MissionMinimap extends Minimap:
	var active_zones: Array[Dictionary] = []

	func _draw() -> void:
		super._draw()
		if not map_rect().has_area():
			return
		for zone in active_zones:
			var center := project(zone.pos)
			var edge := project(zone.pos + Vector2.RIGHT * float(zone.radius))
			draw_arc(center, maxf(2.0, center.distance_to(edge)), 0, TAU, 20, GOLD, 1.0, true)


var view
var _message_index := 0
var _current: Dictionary = {}
var _current_until := 0.0
var _portraits: Dictionary = {}
var _outcome: Control
var _map: MissionMinimap
var _map_obstacles: Array = []
var _next_map_time := -1.0
var _map_selection := ""
var _explored_cells: Dictionary = {}


func setup(owner_view) -> void:
	view = owner_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = MissionMinimap.new()
	_map.name = "BattlefieldMinimap"
	_map.tactical_style = true
	add_child(_map)
	_map.place_tactical_overlay(false)
	_map.set_field_bounds(view.battle.bounds)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild_terrain(view.battle)
	for campaign in Campaigns.ALL:
		_portraits[campaign.id] = campaign.portrait


func refresh() -> void:
	var battle: Battle = view.battle
	var now: float = battle.elapsed
	if _current.is_empty() or now >= _current_until or (_message_index < battle.messages.size() and now >= _current_until - 0.01):
		if _message_index < battle.messages.size():
			_current = battle.messages[_message_index]
			_message_index += 1
			_current_until = now + 2.4 + _current.text.length() / 24.0
		elif now >= _current_until:
			_current = {}
	_map.visible = battle.outcome == Battle.Outcome.LIVE
	_map.process_mode = Node.PROCESS_MODE_DISABLED if view.paused else Node.PROCESS_MODE_INHERIT
	if _map.visible:
		var selected_entry: Dictionary = view.selected_entry()
		var selection: String = selected_entry.squad.id if selected_entry.get("kind") == "squad" else ""
		if _map_obstacles != battle.obstacles:
			_rebuild_terrain(battle)
		if now >= _next_map_time or selection != _map_selection:
			_map_selection = selection
			_next_map_time = now + (0.05 if view.minimap_expanded else 0.10)
			_refresh_map_frame(battle, selected_entry)
	queue_redraw()


func expand_minimap(expanded: bool) -> void:
	_map.set_tactical_expanded(expanded)
	_next_map_time = -1.0


func map_point_from_viewport(pixel: Vector2) -> Variant:
	return _map.unproject(_map.get_global_transform_with_canvas().affine_inverse() * pixel)


func contains_minimap_pixel(pixel: Vector2) -> bool:
	return _map.visible and Rect2(Vector2.ZERO, _map.size).has_point(
		_map.get_global_transform_with_canvas().affine_inverse() * pixel)


func show_outcome(won: bool, reason: String) -> void:
	if is_instance_valid(_outcome):
		_outcome.queue_free()
	_outcome = Control.new()
	_outcome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_outcome)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.025, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outcome.add_child(shade)
	var title := _label("VICTORY" if won else "DEFEAT", 64, GOLD if won else Color("#e08a7a"), DISPLAY)
	title.position = Vector2(0, size.y * 0.32)
	title.size = Vector2(size.x, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome.add_child(title)
	var detail := _label(reason, 26, IVORY)
	detail.position = Vector2(size.x * 0.2, size.y * 0.32 + 96)
	detail.size = Vector2(size.x * 0.6, 70)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome.add_child(detail)
	var battle: Battle = view.battle
	var stats := _label("%d:%02d  ·  %d allies lost  ·  %d enemies defeated" % [
		floori(battle.elapsed / 60.0), int(battle.elapsed) % 60, battle.player_losses, battle.enemy_losses,
	], 21, MUTED)
	stats.position = Vector2(0, size.y * 0.32 + 170)
	stats.size = Vector2(size.x, 30)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome.add_child(stats)
	var button := Button.new()
	button.text = "Continue" if won else "Retry Mission"
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", 26)
	button.position = Vector2(size.x * 0.5 - 150, size.y * 0.32 + 220)
	button.size = Vector2(300, 56)
	button.name = "OutcomeButton"
	_outcome.add_child(button)
	button.pressed.connect(func() -> void:
		if won:
			view.finish(true)
		else:
			view.restart()
	)
	button.grab_focus()


func _label(text: String, font_size: int, color: Color, font: Font = BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	return label


# ---------------------------------------------------------------- drawing


func _draw() -> void:
	if view == null or view.battle == null:
		return
	var battle: Battle = view.battle
	_draw_world_bars(battle)
	_draw_objectives(battle)
	_draw_hero(battle)
	_draw_units(battle)
	_draw_dialogue()
	if view.command_mode:
		_draw_command(battle)


func _text(at: Vector2, text: String, font_size: int, color: Color, font: Font = BODY, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(font, at, text, align, width, font_size, 4, Color(0, 0, 0, 0.75))
	draw_string(font, at, text, align, width, font_size, color)


func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, LINE, false, 1.0)


func _bar(rect: Rect2, fractions: Vector3) -> void:
	draw_rect(rect, Color("#131719"))
	var x := rect.position.x
	for i in range(3):
		var width: float = fractions[i] * rect.size.x
		draw_rect(Rect2(x, rect.position.y, width, rect.size.y), [GREEN, RED, BLACK][i])
		x += width


func _draw_objectives(battle: Battle) -> void:
	var lines: Array[Dictionary] = []
	for item in battle.objectives:
		if item.status == "hidden":
			continue
		lines.append(item)
	var height := 64.0 + lines.size() * 27.0
	var rect := Rect2(24, 22, 520, height)
	_panel(rect)
	_text(Vector2(40, 50), view.mission.get("title", ""), 24, IVORY, DISPLAY)
	_text(Vector2(40, 72), view.mission.get("year", ""), 16, MUTED)
	var y := 100.0
	for item in lines:
		var mark := "○"
		var color := IVORY
		match item.status:
			"done":
				mark = "✓"
				color = Color("#9fd08a")
			"failed":
				mark = "✕"
				color = Color("#e08a7a")
		if item.get("optional", false) and item.status == "active":
			color = MUTED
		var progress := battle.objective_progress(item)
		var text: String = "%s  %s" % [mark, item.text]
		if not progress.is_empty():
			text += "   " + progress
		_text(Vector2(40, y), text, 19, color, BODY, 490)
		y += 27.0


func _refresh_map_frame(battle: Battle, entry: Dictionary) -> void:
	var frame := Minimap.Frame.new()
	frame.selected_ally = StringName(_map_selection)
	if battle.hero.is_alive():
		frame.hero = Minimap.Marker.new(&"hero", battle.hero.position, battle.hero.facing)
	if view.minimap_expanded:
		frame.command_cursor = view.cursor
	if entry.get("kind") == "squad" and entry.squad.info.get("role") == TacticalUnits.Role.RANGED:
		frame.attack_range = float(entry.squad.info.get("range", 15.0))
	var observers := battle.tactic_observers()
	_update_exploration(battle, observers)
	frame.explored_areas.assign(_explored_cells.values())
	for squad in battle.squads:
		if not squad.spawned or squad.departed or squad.alive_count(battle) == 0:
			continue
		var marker := Minimap.Marker.new(StringName(squad.id), squad.anchor, squad.facing)
		if squad.team == Battle.PLAYER_TEAM:
			if squad.commandable:
				frame.allies.append(marker)
				var route := battle.waypoint_route(squad)
				if route.size() > 1:
					frame.platoon_routes[marker.id] = route
					frame.platoon_stops[marker.id] = battle.waypoint_stops(squad)
			else:
				frame.visible_neutrals.append(marker)
		elif squad.team == Battle.ENEMY_TEAM and battle.tactic_position_visible(squad.centroid(battle), observers):
			frame.visible_enemies.append(marker)
	_map.active_zones.clear()
	for item in battle.objectives:
		if item.status == "active" and item.has("zone") and battle.zones.has(item.zone):
			_map.active_zones.append(battle.zones[item.zone])
	for i in range(battle.interactables.size()):
		var item := battle.interactables[i]
		if item.active and not item.done:
			frame.objectives.append(Minimap.Marker.new(StringName("interact_%d" % i), item.pos))
	_map.show_frame(frame)


func _update_exploration(battle: Battle, observers: PackedVector2Array) -> void:
	const CELL := 12.0
	var field := battle.bounds
	for origin in observers:
		var lo := Vector2i(((origin - field.position - Vector2.ONE * Battle.TACTICAL_VISION_RANGE) / CELL).floor()).max(Vector2i.ZERO)
		var hi := Vector2i(((origin - field.position + Vector2.ONE * Battle.TACTICAL_VISION_RANGE) / CELL).floor()).min(
			Vector2i((field.size / CELL).ceil()) - Vector2i.ONE)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				var cell := Vector2i(x, y)
				if _explored_cells.has(cell):
					continue
				var area := Rect2(field.position + Vector2(cell) * CELL, Vector2.ONE * CELL).intersection(field)
				if battle.tactic_origin_sees(origin, area.get_center()):
					_explored_cells[cell] = area


func _rebuild_terrain(battle: Battle) -> void:
	# Schematic of the same real blockers previously drawn by the generic map,
	# not a new illustration or a texture inferred from another battlefield.
	_map_obstacles = battle.obstacles.duplicate(true)
	var field := battle.bounds
	var picture := Image.create_empty(MAP_PIXELS, MAP_PIXELS, false, Image.FORMAT_RGBA8)
	picture.fill(MAP_LAND)
	var pixel_bounds := Rect2i(0, 0, MAP_PIXELS, MAP_PIXELS)
	if field.has_area():
		for obstacle in _map_obstacles:
			var color := MAP_WATER if obstacle.get("kind", "") in ["water", "chasm"] else MAP_STONE
			if obstacle.has("rect"):
				var rect: Rect2 = obstacle.rect
				var corner := (rect.position - field.position) / field.size * MAP_PIXELS
				var spread := rect.size / field.size * MAP_PIXELS
				picture.fill_rect(Rect2i(Vector2i(corner.floor()), Vector2i(spread.ceil())).intersection(pixel_bounds), color)
			elif obstacle.has("circle"):
				var circle: Vector3 = obstacle.circle
				var center := (Vector2(circle.x, circle.y) - field.position) / field.size * MAP_PIXELS
				var radius := Vector2.ONE * circle.z / field.size * MAP_PIXELS
				if radius.x <= 0.0 or radius.y <= 0.0:
					continue
				var area := Rect2i(Vector2i((center - radius).floor()), Vector2i((radius * 2.0).ceil())).intersection(pixel_bounds)
				for y in range(area.position.y, area.end.y):
					for x in range(area.position.x, area.end.x):
						if ((Vector2(x, y) + Vector2.ONE * 0.5 - center) / radius).length_squared() <= 1.0:
							picture.set_pixel(x, y, color)
	_map.terrain_texture = ImageTexture.create_from_image(picture)



func _draw_hero(battle: Battle) -> void:
	var hero := battle.hero
	var rect := Rect2(24, size.y - 150, 430, 126)
	_panel(rect)
	var campaign_id: String = view.campaign_id
	if _portraits.has(campaign_id):
		var texture: Texture2D = _portraits[campaign_id]
		draw_texture_rect(texture, Rect2(rect.position + Vector2(8, 8), Vector2(80, 110)), false)
	var x := rect.position.x + 102
	_text(Vector2(x, rect.position.y + 30), hero.name, 22, IVORY, DISPLAY)
	_text(Vector2(x + 250, rect.position.y + 30), "Lv %d" % hero.unit.level, 17, MUTED)
	var hp := hero.unit.hp / hero.unit.max_hp
	draw_rect(Rect2(x, rect.position.y + 44, 310, 14), Color("#131719"))
	draw_rect(Rect2(x, rect.position.y + 44, 310 * hp, 14), GREEN if hp > 0.3 else RED)
	_text(Vector2(x, rect.position.y + 76), "HP %d / %d" % [hero.unit.hp, hero.unit.max_hp], 15, MUTED)
	var points := battle.points
	var fill := float(points.balance) / maxf(1.0, float(points.capacity))
	draw_rect(Rect2(x, rect.position.y + 84, 310, 10), Color("#131719"))
	draw_rect(Rect2(x, rect.position.y + 84, 310 * fill, 10), BP)
	var cost_mark := x + 310.0 * battle.ability_cost / maxf(1.0, float(points.capacity))
	draw_line(Vector2(cost_mark, rect.position.y + 82), Vector2(cost_mark, rect.position.y + 96), IVORY, 1.5)
	var ready := battle.ability_ready()
	_text(Vector2(x, rect.position.y + 114), "%s  ·  %d BP%s" % [battle.hero_ability_name, battle.ability_cost, "  READY" if ready else ""], 16, GOLD if ready else MUTED)
	if battle.interact_target >= 0:
		var item: Dictionary = battle.interactables[battle.interact_target]
		var center := Vector2(size.x * 0.5, size.y - 70)
		var available := battle.interact_available(item)
		var prompt: String = item.label
		if not available:
			prompt = "%s — clear the area first" % item.label
		_text(center + Vector2(-260, 0), prompt, 22, IVORY if available else Color("#e0a08a"), BODY, 520, HORIZONTAL_ALIGNMENT_CENTER)
		draw_rect(Rect2(center + Vector2(-160, 12), Vector2(320, 8)), Color("#131719"))
		draw_rect(Rect2(center + Vector2(-160, 12), Vector2(320 * clampf(battle.interact_progress, 0.0, 1.0), 8)), GOLD)


func _draw_units(battle: Battle) -> void:
	var entries: Array[Dictionary] = view.command_entries()
	if entries.is_empty():
		return
	var row := 46.0
	var rect := Rect2(size.x - 404, size.y - 24 - row * entries.size() - 30, 380, row * entries.size() + 30)
	_panel(rect)
	_text(rect.position + Vector2(14, 22), "UNITS", 15, MUTED)
	for i in range(entries.size()):
		var entry := entries[i]
		var y := rect.position.y + 30 + i * row
		if i == view.selected:
			draw_rect(Rect2(rect.position.x + 4, y, rect.size.x - 8, row - 4), Color(0.64, 0.42, 0.2, 0.25))
		var status := ""
		var fractions := Vector3(1, 0, 0)
		if entry.kind == "squad":
			var squad: Battle.Squad = entry.squad
			status = battle.order_label(squad)
			fractions = squad.combat.health_fractions()
		else:
			var cart: Battle.Fighter = entry.cart
			status = battle.cart_status(cart)
			var hp := cart.unit.hp / cart.unit.max_hp
			fractions = Vector3(hp, 1.0 - hp, 0)
		_text(Vector2(rect.position.x + 14, y + 18), "%d  %s" % [i + 1, entry.name], 18, IVORY)
		_text(Vector2(rect.position.x + 230, y + 18), status, 15, MUTED, BODY, 140, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Rect2(rect.position.x + 14, y + 26, rect.size.x - 28, 7), fractions)


func _draw_dialogue() -> void:
	if _current.is_empty():
		return
	var width := 720.0
	var rect := Rect2(size.x * 0.5 - width * 0.5, size.y - 290, width, 96)
	_panel(rect)
	var speaker: String = _current.speaker
	var x := rect.position.x + 16
	if _portraits.has(speaker):
		draw_texture_rect(_portraits[speaker], Rect2(rect.position + Vector2(8, 8), Vector2(58, 80)), false)
		x += 64
	var name: String = Missions.SPEAKERS.get(speaker, speaker)
	if not name.is_empty():
		_text(Vector2(x, rect.position.y + 28), name, 18, GOLD, DISPLAY)
	var font_size := 19
	var lines := _wrap(_current.text, rect.size.x - (x - rect.position.x) - 16, font_size)
	var y := rect.position.y + (54 if not name.is_empty() else 34)
	for line in lines.slice(0, 3):
		_text(Vector2(x, y), line, font_size, IVORY if not name.is_empty() else Color("#cfe3e8"))
		y += 22


func _wrap(text: String, width: float, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for word in text.split(" "):
		var attempt := word if current.is_empty() else current + " " + word
		if BODY.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = attempt
	if not current.is_empty():
		lines.append(current)
	return lines


func _draw_command(battle: Battle) -> void:
	draw_rect(Rect2(0, 0, size.x, 6), Color(0.9, 0.75, 0.45, 0.6))
	_text(Vector2(size.x * 0.5 - 300, 44), "COMMAND VIEW", 26, GOLD, DISPLAY, 600, HORIZONTAL_ALIGNMENT_CENTER)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for squad in battle.squads:
		if not squad.spawned or squad.departed or squad.alive_count(battle) == 0 or squad.team == Battle.NEUTRAL_TEAM:
			continue
		var at := squad.centroid(battle)
		var world := Vector3(at.x, 2.5, at.y)
		if camera.is_position_behind(world):
			continue
		var screen := camera.unproject_position(world)
		var color: Color = [Color("#9fe0ea"), Color("#f08a72")][squad.team]
		_text(screen + Vector2(-90, 0), squad.name, 15, color, BODY, 180, HORIZONTAL_ALIGNMENT_CENTER)
		if squad.team == Battle.PLAYER_TEAM:
			_text(screen + Vector2(-90, 16), battle.order_label(squad), 13, MUTED, BODY, 180, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_world_bars(battle: Battle) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for fighter in battle.fighters:
		if not fighter.is_alive() or fighter.controlled:
			continue
		var show := fighter.kind == Battle.Kind.STRUCTURE or (fighter.kind == Battle.Kind.HERO and fighter.team != Battle.NEUTRAL_TEAM)
		if not show:
			continue
		var height := 3.6 if fighter.kind == Battle.Kind.STRUCTURE else 2.7
		var world := Vector3(fighter.position.x, height, fighter.position.y)
		if camera.is_position_behind(world) or camera.global_position.distance_to(world) > 90.0:
			continue
		var screen := camera.unproject_position(world)
		var hp := fighter.unit.hp / fighter.unit.max_hp
		var rect := Rect2(screen + Vector2(-50, 0), Vector2(100, 7))
		draw_rect(rect.grow(1), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * hp, rect.size.y)), GREEN if fighter.team == Battle.PLAYER_TEAM else RED)
		if fighter.kind == Battle.Kind.STRUCTURE:
			_text(screen + Vector2(-90, -6), fighter.name, 14, IVORY, BODY, 180, HORIZONTAL_ALIGNMENT_CENTER)
