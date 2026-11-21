extends SceneTree

const Deployments := preload("res://game/campaign_deployments.gd")
const Harness := preload("res://game/battlefield/command_harness.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Scale := preload("res://game/battlefield/battlefield_march_scale.gd")

const MISSION_IDS := ["neris_cairnspine_passage", "sereth_no_proxy", "sova_vault_return"]
const DT := 1.0 / 60.0
# Battlefield-local XZ, north perimeter to south perimeter around the west
# foot of the raised pass. Valley floor throughout; not the shelf or flank.
const RIM_ROUTE: Array[Vector2] = [
	Vector2(124, -79), Vector2(-75.5, -47.5), Vector2(-90.5, -35.5),
	Vector2(-51.5, 74), Vector2(21, 83), Vector2(133, 83),
]

var _mission: Harness


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for mission_id: String in MISSION_IDS:
		var deployment := Deployments.for_mission(mission_id)
		var scene: PackedScene = deployment.get("scene")
		if scene == null:
			_fail("Missing registered Year Five deployment: %s" % mission_id)
			return
		_mission = scene.instantiate() as Harness
		if _mission == null:
			_fail("Registered Year Five deployment does not use the command harness: %s" % mission_id)
			return
		root.add_child(_mission)
		# Inspect the deployed terrain and command limits without running combat
		# or objective ticks; the isolated infantry still uses the live adapter.
		_mission.set_physics_process(false)
		await physics_frame
		await physics_frame
		for point in RIM_ROUTE:
			var selectable = _mission._terrain.destination_from_ray(
				Vector3(point.x, 60, point.y), Vector3(point.x, -8, point.y)
			)
			if selectable == null or not _mission.battle.bounds.has_point(point):
				_fail("The command cursor cannot select %s in %s" % [point, mission_id])
				return
		var reversed := RIM_ROUTE.duplicate()
		reversed.reverse()
		if not _expect_block(RIM_ROUTE[0], Vector2(124, -100), &"ValleyCrag06", 3.0) \
				or not _expect_block(RIM_ROUTE[-1], Vector2(133, 105), &"ValleyCrag19", 3.0) \
				or not _expect_block(RIM_ROUTE[0], RIM_ROUTE[-1], &"ForecourtFoundations"):
			_fail("The Cairnspine perimeter or the cross-valley obstruction changed: %s" % mission_id)
			return
		for i in range(RIM_ROUTE.size() - 2):
			for j in range(i + 2, RIM_ROUTE.size()):
				if not _walk([RIM_ROUTE[i], RIM_ROUTE[j]]).blocked:
					_fail("The perimeter benchmark has a clear shortcut in %s: %s to %s" % [
						mission_id, RIM_ROUTE[i], RIM_ROUTE[j],
					])
					return
		for route: Array[Vector2] in [RIM_ROUTE, reversed]:
			var march := _walk(route)
			var seconds: float = march.seconds
			if not march.reached or not Scale.within_baseline_band(seconds) \
					or Scale.classify_baseline(seconds) != Scale.Tier.EXPANSIVE \
					or absf(seconds - 174.2) > 0.1 or absf(march.meters - 522.48) > 0.25:
				_fail("Expected the Expansive perimeter march in %s at %s: %s" % [mission_id, route[-1], march])
				return
			print("%s %s → %s: %.2f m in %.2f s (%d steps, Expansive perimeter route)." % [
				mission_id, route[0], route[-1], march.meters, seconds, march.ticks,
			])
		_mission.queue_free()
		await physics_frame
	quit()


func _expect_block(from: Vector2, toward: Vector2, collider: StringName, max_meters := INF) -> bool:
	if not _mission.battle.bounds.has_point(toward):
		return false
	var attempt := _walk([from, toward])
	if not attempt.blocked or attempt.meters > max_meters:
		return false
	var t := _mission._terrain
	var stop: Vector2 = attempt.position
	var height := t.ground_height(stop) + 0.9
	var ray := t._ray(Vector3(stop.x, height, stop.y), Vector3(toward.x, height, toward.y), Terrain.SOLID_MASK)
	var obstacle := ray.get("collider") as Node
	if obstacle == null or obstacle.name != collider:
		print("Unexpected collision: ", from, " → ", toward, " at ", stop, " got ", obstacle)
		return false
	print("  blocked ", from, " → ", toward, " after %.2f m at %s" % [attempt.meters, obstacle.name])
	return true


func _walk(route: Array[Vector2]) -> Dictionary:
	var battle := Battle.new()
	battle.bounds = _mission.battle.bounds
	var formation := battle.formations[0]
	formation.position = route[0]
	formation.hold()
	var tick := 0
	var meters := 0.0
	var reached := _supports_floor(formation.position)
	for i in range(1, route.size()):
		if not reached:
			break
		battle.order_move(0, route[i])
		while formation.order == Battle.Order.MOVE and tick < 60 * 200:
			var before := formation.position
			battle.step(DT, Vector2.ZERO, _mission._movement_check())
			tick += 1
			meters += before.distance_to(formation.position)
			if not _supports_floor(formation.position):
				reached = false
				break
		reached = reached and formation.order == Battle.Order.HOLD and formation.position == route[i]
	return {
		"reached": reached,
		"blocked": formation.order == Battle.Order.BLOCKED,
		"position": formation.position,
		"seconds": tick * DT,
		"ticks": tick,
		"meters": meters,
	}


func _supports_floor(point: Vector2) -> bool:
	var t := _mission._terrain
	var above := Vector3(point.x, 20, point.y)
	var below := Vector3(point.x, -8, point.y)
	return t.formation_fits_at(point) and not t._ray(above, below, Terrain.WALKABLE_MASK).is_empty()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
