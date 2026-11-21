extends SceneTree

const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const FieldCamera := preload("res://game/battlefield/sector_camera.gd")
const FIELD := Rect2(-220, -150, 440, 300)
const HERO_SPAWN := Vector2(-130, -69)

var _harness: Harness
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_harness = HarnessScene.instantiate()
	_harness.battlefield_scene = _ground_fixture()
	_harness.field_bounds = FIELD
	_harness.enable_sector_camera = true
	_harness.hero_spawn = ^"TestHero"
	_harness.formation_spawns = [^"TestInfantry"]
	root.add_child(_harness)
	_harness.set_physics_process(false)
	await physics_frame
	await physics_frame
	var battle := _harness.battle
	var infantry := battle.formations[0]
	var sector := _harness._sector
	var hero_camera := root.get_camera_3d()
	var screen := root.get_visible_rect()

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var camera := root.get_camera_3d()
	_check(camera != hero_camera and camera.size == 58.0 and sector.view_center() == HERO_SPAWN
		and _harness.cursor == HERO_SPAWN and _harness._mode_label.text.begins_with("TACTICAL SECTOR"),
		"L2 opens a close, readable tactical sector at the hero.")
	var projected_infantry := camera.unproject_position(Vector3(infantry.position.x, 0.0, infantry.position.y))
	_check(screen.has_point(projected_infantry), "Nearby infantry are visible from the hero's tactical sector.")

	var local_target := Vector2(-104, -65)
	_point(local_target, MOUSE_BUTTON_RIGHT)
	_check(infantry.order == Battle.Order.MOVE and infantry.destination.distance_to(local_target) < 0.01,
		"Right click still issues precise local orders.")
	_tick(20)
	var advancing := infantry.position
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_tick(180)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_check(sector.view_center().x > HERO_SPAWN.x + 30 and _harness.cursor.x > sector.view_center().x,
		"Stick pans only after the cursor crosses the tactical window.")
	_check(screen.has_point(camera.unproject_position(Vector3(_harness.cursor.x, 0, _harness.cursor.y))),
		"Safe-zone following keeps the stick cursor inside the tactical viewport.")
	_check(_harness.battle == battle and infantry.position.x > advancing.x,
		"Formation orders were not changed by panning.")

	_button(JOY_BUTTON_RIGHT_STICK)
	_check(sector.overview and camera.size > 500.0 and sector.view_center() == FIELD.get_center()
		and _harness._mode_label.text.begins_with("FIELD OVERVIEW"), "R3 switches to a whole-field overview.")
	for corner in [FIELD.position, Vector2(FIELD.end.x, FIELD.position.y), FIELD.end, Vector2(FIELD.position.x, FIELD.end.y)]:
		_check(screen.has_point(camera.unproject_position(Vector3(corner.x, 0.0, corner.y))),
			"The overview contains field corner %s." % corner)
	var scale_before := sector.view_size(1.0)
	_check(sector.view_size(0.5) > scale_before, "Overview size adapts to a portrait viewport.")
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	_tick(75)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	for corner in [FIELD.position, Vector2(FIELD.end.x, FIELD.position.y), FIELD.end, Vector2(FIELD.position.x, FIELD.end.y)]:
		_check(screen.has_point(camera.unproject_position(Vector3(corner.x, 0.0, corner.y))),
			"The overview still contains field corner %s after camera orbit." % corner)

	var distant_target := Vector2(182.0, 124.0)
	_point(distant_target)
	_check(_harness.cursor.distance_to(distant_target) < 0.01, "Overview cursor can pick walkable terrain beyond the old 300-metre ray limit.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_X)
	_check(battle.formations[1].destination.distance_to(distant_target) < 0.01, "Overview supports issuing orders at the pointed location.")
	_key(KEY_M)
	_check(not sector.overview and sector.view_center().distance_to(distant_target) < 0.01 and camera.size == 58.0,
		"Leaving overview zooms in on the pointed sector.")
	_button(JOY_BUTTON_LEFT_STICK)
	_check(sector.view_center() == HERO_SPAWN and _harness.cursor == HERO_SPAWN, "L3 returns to the hero from a distant sector.")

	var prior := sector.view_center()
	var edge := screen.position + Vector2(screen.size.x - 1.0, screen.size.y * 0.5)
	_mouse(edge)
	_tick(100)
	_check(sector.view_center().distance_to(prior) > 50.0, "A mouse at the screen edge pans the local camera without needing repeated motion events.")
	_mouse(screen.get_center())
	var settled := sector.view_center()
	_tick(25)
	_check(sector.view_center() == settled, "Moving the pointer away from the screen edge stops the pan.")
	_mouse(edge)
	_tick(950)
	_check(sector.view_center().is_equal_approx(Vector2(FIELD.position.x, FIELD.end.y)), "Prolonged edge scrolling clamps to both rotated map edges.")

	_key(KEY_HOME)
	_check(sector.view_center() == HERO_SPAWN, "Home recenters the tactical sector.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(root.get_camera_3d() == hero_camera and not _harness.command_view and _harness.battle == battle,
		"Releasing L2 restores the original hero camera without replacing the battlefield.")
	_key(KEY_D, true)
	_tick(12)
	_key(KEY_D, false)
	_key(KEY_SHIFT)
	_check(sector.view_center() == battle.hero_position and sector.view_center() != HERO_SPAWN,
		"Re-entering command view centers on the hero's current location.")
	_check(infantry.position.distance_to(local_target) < 0.01, "The original order completed after view changes and camera navigation.")

	_harness.queue_free()
	await process_frame
	if _failures == 0:
		print("Large field: tactical sector, stick and edge pan, full overview, long-range picking, recenter, bounds and persistent orders passed.")
	quit(0 if _failures == 0 else 1)


func _ground_fixture() -> PackedScene:
	var map := Node3D.new()
	map.name = "LargeGroundFixture"
	var ground := StaticBody3D.new()
	ground.collision_layer = 3
	ground.position.y = -1.0
	map.add_child(ground)
	ground.owner = map
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(FIELD.size.x + 10, 2, FIELD.size.y + 10)
	collider.shape = shape
	ground.add_child(collider)
	collider.owner = map
	_marker(map, "TestHero", HERO_SPAWN)
	_marker(map, "TestInfantry", HERO_SPAWN + Vector2(4.0, 0.0))
	var packaged := PackedScene.new()
	packaged.pack(map)
	map.free()
	return packaged


func _marker(parent: Node3D, id: String, point: Vector2) -> void:
	var marker := Marker3D.new()
	marker.name = id
	marker.position = Vector3(point.x, 0.0, point.y)
	parent.add_child(marker)
	marker.owner = parent


func _tick(count: int) -> void:
	for index in range(count):
		_harness._physics_process(1.0 / 60.0)


func _point(target: Vector2, button := MOUSE_BUTTON_NONE) -> void:
	var screen := root.get_camera_3d().unproject_position(Vector3(target.x, 0.0, target.y))
	if button == MOUSE_BUTTON_NONE:
		_mouse(screen)
	else:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.button_index = button
		event.pressed = true
		root.push_input(event, true)


func _mouse(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	root.push_input(event, true)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
