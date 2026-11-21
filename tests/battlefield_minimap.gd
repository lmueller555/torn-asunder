extends SceneTree

const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const Preview := preload("res://tests/battlefield_minimap_preview.tscn")
const FIELD := Rect2(-220, -90, 440, 300)
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := Minimap.new()
	root.add_child(map)
	map.size = Vector2(400, 260)
	_check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "A passive HUD does not capture battlefield clicks.")
	_check(not map.map_rect().has_area() and map.unproject(Vector2.ZERO) == null,
		"An unconfigured map does not admit points.")
	map.set_field_bounds(FIELD)
	var fit := map.map_rect()
	_check(is_equal_approx(fit.size.x / fit.size.y, FIELD.size.x / FIELD.size.y)
		and fit.get_center().is_equal_approx(map.size / 2.0), "The map preserves field aspect and stays centered.")
	_check(map.project(FIELD.position).is_equal_approx(fit.position) and map.project(FIELD.end).is_equal_approx(fit.end),
		"Field bounds project to the full fitted rectangle without flipping north/south.")
	var sample := Vector2(-120, 76)
	var round_trip: Vector2 = map.unproject(map.project(sample))
	_check(round_trip.is_equal_approx(sample) and map.unproject(Vector2.ZERO) == null, "Projection round-trips and ignores the letterbox.")

	var frame := Minimap.Frame.new()
	frame.hero = Minimap.Marker.new(&"hero", sample, Vector2.RIGHT)
	frame.allies = [Minimap.Marker.new(&"infantry", Vector2(-30, 70)), Minimap.Marker.new(&"archers", Vector2(62, 40))]
	frame.selected_ally = &"archers"
	frame.objectives = [
		Minimap.Marker.new(&"pickup", Vector2(-70, 10)),
		Minimap.Marker.new(&"exit", Vector2(220, 120), Vector2.UP, Minimap.ObjectiveKind.EXIT),
	]
	frame.camera_footprint = PackedVector2Array([Vector2(-250, 30), Vector2(-150, -10), Vector2(-107, 65), Vector2(-230, 117)])
	map.show_frame(frame)
	_check(map.marker_pixel(&"hero").is_equal_approx(map.project(sample))
		and _glyph(map, &"archers").selected and not _glyph(map, &"infantry").selected, "Live marker positions and selected ally are preserved.")
	_check(_glyph(map, &"pickup").icon == Minimap.Icon.PICKUP and _glyph(map, &"exit").icon == Minimap.Icon.EXIT,
		"Pickup and exit have separate icon shapes, including objectives placed on the playable boundary.")
	_check(map.marker_pixel(&"hidden") == null and _count_enemies(map) == 0, "A frame without visible enemies draws no enemies.")
	var sector := map.sector_pixels()
	_check(sector.size() == 1 and sector[0].size() >= 3, "A rotated footprint crossing the edge is clipped to one valid polygon.")
	for pixel in sector[0]:
		_check(pixel.x >= fit.position.x - 0.01 and pixel.x <= fit.end.x + 0.01
			and pixel.y >= fit.position.y - 0.01 and pixel.y <= fit.end.y + 0.01, "Footprint stays inside map bounds, not the letterbox.")

	frame.visible_enemies = [
		Minimap.Marker.new(&"scouted guard", Vector2(143, 0)),
		Minimap.Marker.new(&"outside field", Vector2(900, 900)),
	]
	map.show_frame(frame)
	_check(_count_enemies(map) == 1 and map.marker_pixel(&"scouted guard") != null, "Only explicitly visible in-bounds enemies render.")
	frame.visible_enemies.clear()
	frame.hero.position += Vector2(12, 0)
	frame.selected_ally = &"infantry"
	map.show_frame(frame)
	_check(_count_enemies(map) == 0 and map.marker_pixel(&"scouted guard") == null
		and map.marker_pixel(&"hero").is_equal_approx(map.project(frame.hero.position)) and _glyph(map, &"infantry").selected,
		"New snapshots replace current unit state and remove enemies entirely when contact is lost.")
	map.size = Vector2(245, 430)
	_check(map.marker_pixel(&"hero").is_equal_approx(map.project(frame.hero.position)) and map.map_rect().get_center() == map.size * 0.5,
		"A resized portrait widget reprojects existing snapshots without stretching.")
	frame.camera_footprint = PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(INF, NAN)])
	map.show_frame(frame)
	_check(map.sector_pixels().is_empty(), "Invalid camera points do not produce an on-map footprint.")
	map.set_field_bounds(Rect2(-50, -20, 100, 40))
	_check(map.marker_pixel(&"hero") == null and map.sector_pixels().is_empty(), "Changing fields clears stale state.")

	map.queue_free()
	await process_frame
	var preview := Preview.instantiate()
	root.add_child(preview)
	preview.set_process(false)
	await process_frame
	await process_frame
	var preview_map: Minimap = preview._map
	var old_focus: Vector2 = preview._focus
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var target := Vector2(120, -66)
	click.position = preview_map.global_position + preview_map.project(target)
	root.push_input(click, true)
	_check(preview._focus.distance_to(target) < 0.01 and preview._focus != old_focus,
		"Clicking the preview map moves its real command footprint in world coordinates.")
	preview._toggle_sight()
	_check(_count_enemies(preview_map) == 0, "The preview's visibility control demonstrates loss of enemy contact.")
	preview._cycle_selection()
	_check(_glyph(preview_map, &"Archers").selected, "The preview can change selection without map-specific actor dependencies.")

	preview.queue_free()
	await process_frame
	if _failures == 0:
		print("Battlefield minimap: fit, projection, clipped camera, live updates, distinct objectives, visibility and interactive preview passed.")
	quit(0 if _failures == 0 else 1)


func _glyph(map: Minimap, id: StringName) -> Minimap.Glyph:
	for marker in map._glyphs:
		if marker.id == id:
			return marker
	return null


func _count_enemies(map: Minimap) -> int:
	var count := 0
	for marker in map._glyphs:
		if marker.icon == Minimap.Icon.ENEMY:
			count += 1
	return count


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
