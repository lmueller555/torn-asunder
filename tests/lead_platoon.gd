extends SceneTree
## The leader travels inside their own platoon. Outside combat the platoon takes Move
## orders and waypoint routes like every other platoon, and stick input does not move
## the leader. Contact with a hostile switches to direct control until the area is
## calm again, and the platoon re-forms around the leader.

const Battle := preload("res://game/battlefield/command_battle.gd")
const Routes := preload("res://game/battlefield/command_platoon_routes.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const DT := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_simulation()
	_check_routes()
	await _check_harness_engagement()
	if _failures == 0:
		print("Lead platoon: waypoint march outside combat, direct control only in combat, and re-forming on release passed.")
	quit(0 if _failures == 0 else 1)


func _check_simulation() -> void:
	var battle := Battle.new()
	var start := battle.hero_position
	battle.step(1.0, Vector2.RIGHT)
	_check(battle.hero_position == start and not battle.direct_hero_control(), "Stick input does not move the leader outside combat.")
	_check(battle.formation_at(Battle.LEAD_INDEX) == battle.lead and battle.formation_at(0) == battle.formations[0] \
		and battle.formation_at(battle.formations.size()) == null, "The lead platoon has its own command index beside the existing platoons.")
	var goal := start + Vector2(4.0, -3.0)
	battle.order_move(Battle.LEAD_INDEX, goal)
	battle.step(0.5, Vector2.ZERO)
	_check(is_equal_approx(start.distance_to(battle.hero_position), Battle.LEAD_SPEED * 0.5) and battle.lead.position == battle.hero_position,
		"The leader marches at the head of the platoon at the platoon's pace.")
	for i in range(120):
		battle.step(DT, Vector2.LEFT)
	_check(battle.hero_position.is_equal_approx(goal) and battle.lead.order == Battle.Order.HOLD, "The march halts at the ordered point; stick input never interferes.")
	battle.order_hold(Battle.LEAD_INDEX)
	battle.hero_position = Vector2(-5.0, 5.0)
	battle.step(DT, Vector2.ZERO)
	_check(battle.lead.position == battle.hero_position and battle.lead.order == Battle.Order.HOLD, "A scripted placement re-forms the platoon on the leader.")
	battle.lead_engaged = true
	var engaged_at := battle.hero_position
	battle.step(1.0, Vector2.RIGHT)
	_check(battle.hero_position.x > engaged_at.x and battle.lead.position == battle.hero_position, "In combat the stick steers the leader and the platoon fights around them.")
	battle.order_move(Battle.LEAD_INDEX, engaged_at)
	var steered := battle.hero_position
	battle.step(0.2, Vector2.ZERO)
	_check(battle.hero_position == steered, "A Move order cannot drag the leader out of a fight.")
	battle.lead_engaged = false
	_check(battle.lead.order == Battle.Order.HOLD and battle.lead.position == battle.hero_position, "When combat ends the platoon holds where the leader finished.")
	var legacy := Battle.new()
	legacy.lead_platoon_enabled = false
	var legacy_start := legacy.hero_position
	legacy.step(1.0, Vector2.RIGHT)
	_check(legacy.hero_position.x > legacy_start.x, "Scenes that opt out keep the free-walking leader.")


func _check_routes() -> void:
	var battle := Battle.new()
	var routes := Routes.new()
	routes.reset(battle)
	var start := battle.hero_position
	var points := [start + Vector2(3, 0), start + Vector2(3, -3), start + Vector2(0, -3)]
	_check(routes.issue(battle, Battle.LEAD_INDEX, points[0], false, Callable()) == Queue.Result.ACCEPTED \
		and routes.issue(battle, Battle.LEAD_INDEX, points[1], true, Callable()) == Queue.Result.ACCEPTED \
		and routes.issue(battle, Battle.LEAD_INDEX, points[2], true, Callable()) == Queue.Result.ACCEPTED,
		"The lead platoon accepts a waypoint route.")
	_check(routes.snapshot(Battle.LEAD_INDEX).size() == 3 and routes.snapshot(0).is_empty(), "The lead route is separate from the other platoons' routes.")
	var visited: Array[int] = []
	for i in range(400):
		battle.step(DT, Vector2.ZERO)
		routes.advance(battle)
		for index in range(points.size()):
			if not visited.has(index) and battle.hero_position.distance_to(points[index]) < 0.05:
				visited.append(index)
	_check(visited == [0, 1, 2] and routes.snapshot(Battle.LEAD_INDEX).is_empty() and battle.lead.order == Battle.Order.HOLD,
		"The leader follows the waypoints in order and halts at the last one.")
	routes.issue(battle, Battle.LEAD_INDEX, start, false, Callable())
	routes.issue(battle, Battle.LEAD_INDEX, start + Vector2(-2, 0), true, Callable())
	battle.lead_engaged = true
	routes.advance(battle)
	_check(routes.snapshot(Battle.LEAD_INDEX).is_empty(), "Combat cancels the leader's pending waypoints.")
	_check(routes.issue(battle, Battle.LEAD_INDEX, start, false, Callable()) == Queue.Result.INVALID_FOR_BATTLEFIELD,
		"Waypoints cannot be plotted for the leader's platoon during combat.")


func _check_harness_engagement() -> void:
	var script := GDScript.new()
	script.source_code = 'extends "res://game/battlefield/command_harness.gd"\nvar hostiles := PackedVector2Array()\n\nfunc _hostile_positions() -> PackedVector2Array:\n\treturn hostiles\n'
	if script.reload() != OK:
		_check(false, "Could not build the test harness.")
		return
	var harness = HarnessScene.instantiate()
	harness.set_script(script)
	root.add_child(harness)
	await physics_frame
	var battle: Battle = harness.battle
	var hero := battle.hero_position
	harness.hostiles = PackedVector2Array([hero + Vector2(20.0, 0.0)])
	await _frames(3)
	_check(not battle.lead_engaged, "A distant hostile does not start combat.")
	harness.hostiles = PackedVector2Array([hero + Vector2(6.0, 0.0)])
	await _frames(2)
	_check(battle.lead_engaged and battle.direct_hero_control(), "A hostile within engagement range switches the leader to direct control.")
	harness.hostiles = PackedVector2Array([hero + Vector2(10.0, 0.0)])
	await _frames(120)
	_check(battle.lead_engaged, "Combat holds while the hostile stays inside the release range.")
	harness.hostiles = PackedVector2Array()
	await _frames(int(harness.LEAD_RELEASE_SECONDS / DT) + 10)
	_check(not battle.lead_engaged and battle.lead.position == battle.hero_position, "Combat ends after a calm period and the platoon re-forms on the leader.")
	harness.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
