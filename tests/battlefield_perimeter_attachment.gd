extends SceneTree

const Harness := preload("res://game/battlefield/command_harness.gd")
const Scene := preload("res://game/battlefield/command_harness.tscn")
const Battle := preload("res://game/battlefield/command_battle.gd")

const SPAWN := Vector3(-4, 2, 0)
const OUTER_TARGET := Vector2(26, 0)
const OUTER_STOP := Vector2(34, 0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var base := _pack(false)
	var plain := Scene.instantiate() as Harness
	_setup(plain, base)
	root.add_child(plain)
	plain.set_physics_process(false)
	await physics_frame
	var passed := _pick(plain, OUTER_TARGET) == null and plain._field.get_node_or_null(^"FarApproach") == null
	plain.queue_free()
	await process_frame
	await physics_frame

	var extended := Scene.instantiate() as Harness
	_setup(extended, base)
	extended.battlefield_perimeter = _pack(true)
	root.add_child(extended)
	extended.set_physics_process(false)
	await physics_frame
	var wing := extended._field.get_node_or_null(^"FarApproach") as Node3D
	passed = _check(passed, "A shared field must not gain terrain without opting in.") and passed
	passed = _check(extended.battlefield_scene == base and wing != null
		and extended.battlefield_marker(^"OriginalSpawn").global_position == SPAWN
		and extended.hero_world_position().is_equal_approx(SPAWN)
		and extended.battle.bounds == extended.field_bounds,
		"The original battlefield, marker, spawn and deployment command bounds are retained.") and passed
	passed = _check(_pick(extended, OUTER_TARGET) == OUTER_TARGET,
		"The optional terrain is registered for walkable overhead picking.") and passed

	var group := extended.battle.formations[0]
	passed = _check(_march(extended, OUTER_TARGET) == Battle.Order.HOLD
		and group.position == OUTER_TARGET,
		"A real formation crosses the seam onto supported ground.") and passed
	passed = _check(_march(extended, OUTER_STOP) == Battle.Order.BLOCKED
		and group.position.x > OUTER_TARGET.x and group.position.x < 30.0,
		"The physical rim blocks movement before the command clamp.") and passed
	extended.restart_battle()
	passed = _check(extended._field.get_node_or_null(^"FarApproach") == wing
		and _pick(extended, OUTER_TARGET) == OUTER_TARGET,
		"Restart keeps one mounted perimeter and reuses the same walkable geometry.") and passed
	extended.queue_free()
	await process_frame
	if passed:
		print("Perimeter attachment: opt-in, original spawn and identity, physical march, rim and retry passed.")
	quit(0 if passed else 1)


func _setup(mission: Harness, base: PackedScene) -> void:
	mission.battlefield_scene = base
	mission.field_bounds = Rect2(-9, -6, 44, 12)
	mission.hero_spawn = ^"OriginalSpawn"
	mission.formation_spawns = [^"OriginalSpawn"]


func _pack(outer: bool) -> PackedScene:
	var field := Node3D.new()
	field.name = "FarApproach" if outer else "OriginalGround"
	_box(field, Vector3(20 if outer else 0, 1.5, 0), Vector3(20, 1, 20), 3)
	if outer:
		_box(field, Vector3(30.5, 4, 0), Vector3(1, 4, 20), 1)
	else:
		var spawn := Marker3D.new()
		spawn.name = "OriginalSpawn"
		spawn.position = SPAWN
		field.add_child(spawn)
		spawn.owner = field
	var result := PackedScene.new()
	result.pack(field)
	field.free()
	return result


func _box(field: Node3D, at: Vector3, dimensions: Vector3, layers: int) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = layers
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	field.add_child(body)
	body.owner = field
	body.add_child(collider)
	collider.owner = field


func _pick(mission: Harness, point: Vector2) -> Variant:
	return mission._terrain.destination_from_ray(Vector3(point.x, 15, point.y), Vector3(point.x, -4, point.y))


func _march(mission: Harness, destination: Vector2) -> Battle.Order:
	mission.battle.order_move(0, destination)
	var group := mission.battle.formations[0]
	for _i in range(800):
		if group.order != Battle.Order.MOVE:
			break
		mission.battle.step(1.0 / 60.0, Vector2.ZERO, mission._movement_check())
		if _pick(mission, group.position) == null:
			return Battle.Order.DEFEATED
	return group.order


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
	return ok
