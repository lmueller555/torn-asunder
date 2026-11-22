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
	await _check_waypoint_marker()
	if _failures == 0:
		print("Lead platoon: waypoint march, the steerable waypoint marker and its camera, direct control only in combat, and re-forming on release passed.")
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
	var yaw: float = harness._hero_yaw
	_check(Vector2(-sin(yaw), -cos(yaw)).dot(Vector2.RIGHT) > 0.99, "Combat turns the camera behind the leader toward the hostile.")
	harness.hostiles = PackedVector2Array([hero + Vector2(10.0, 0.0)])
	await _frames(120)
	_check(battle.lead_engaged, "Combat holds while the hostile stays inside the release range.")
	harness.hostiles = PackedVector2Array()
	await _frames(int(harness.LEAD_RELEASE_SECONDS / DT) + 10)
	_check(not battle.lead_engaged and battle.lead.position == battle.hero_position, "Combat ends after a calm period and the platoon re-forms on the leader.")
	harness.queue_free()
	await process_frame


func _check_waypoint_marker() -> void:
	var harness = HarnessScene.instantiate()
	root.add_child(harness)
	await physics_frame
	var battle: Battle = harness.battle
	await _frames(2)
	_check(harness.selected_index == Battle.LEAD_INDEX and harness.march_mode(), "Deployment selects the leader’s platoon and the stick drives its waypoint marker.")
	var hero := battle.hero_position
	var start: Vector2 = harness.march_marker
	_check(start.distance_to(battle.lead.position) <= harness.MARKER_START + 0.01, "The marker starts just ahead of the selected platoon.")
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(30)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(20)
	var marker: Vector2 = harness.march_marker
	_check(marker.distance_to(start) > 5.0 and battle.hero_position == hero, "The stick moves the marker away from the platoon without moving the leader.")
	_check(_camera_frames(harness, battle.lead.position, marker), "The camera hovers behind the selected platoon and looks toward the marker.")
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(20)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(30)
	var swung: Vector2 = harness.march_marker
	_check(absf(swung.distance_to(battle.lead.position) - marker.distance_to(battle.lead.position)) < 6.0 and swung.distance_to(marker) > 3.0 \
		and _camera_frames(harness, battle.lead.position, swung), "Steering sideways swings the marker round the platoon and the camera turns to follow it.")
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await _frames(120)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(30)
	_check(harness.march_marker.distance_to(battle.lead.position) >= harness.MARKER_MIN_DISTANCE - 0.01 \
		and _camera_frames(harness, battle.lead.position, harness.march_marker), "Pulling the marker back stops short of the platoon without spinning the camera.")
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(30)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(20)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_check(harness.march_waypoints(Battle.LEAD_INDEX).size() == 1 and battle.lead.order == Battle.Order.MOVE, "R1 adds a waypoint and the lead platoon sets off for it.")
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(15)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_X)
	var second: Vector2 = harness.march_marker
	_check(harness.march_waypoints(Battle.LEAD_INDEX).size() == 2, "Square adds the marker to the end of the route.")
	await _frames(240)
	_check(battle.hero_position.distance_to(second) < 0.2 and harness.march_waypoints(Battle.LEAD_INDEX).is_empty(), "The leader marches through both waypoints and halts at the last.")
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(400)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(harness.march_marker.distance_to(battle.lead.position) <= harness.MARKER_LEASH + 0.01, "The marker stays leashed to the selected platoon.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	var infantry := battle.formations[0]
	_check(harness.selected_index == 0 and harness.march_marker.distance_to(infantry.position) <= harness.MARKER_START + 0.01, "Changing platoon moves the marker out from the newly selected platoon.")
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_check(infantry.order == Battle.Order.MOVE, "Other platoons take marker waypoints the same way.")
	# Queue two more, then R1 again: the default waypoint replaces the whole route.
	for side in [1.0, -1.0]:
		_axis(JOY_AXIS_LEFT_X, side)
		await _frames(10)
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_button(JOY_BUTTON_X)
	_check(harness.march_waypoints(0).size() == 3, "Square builds a route of several waypoints.")
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(10)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	var replaced: Vector2 = harness.march_marker
	_check(harness.march_waypoints(0).size() == 1 and harness.march_waypoints(0)[0].is_equal_approx(replaced)
		and infantry.order == Battle.Order.MOVE and infantry.destination.is_equal_approx(replaced),
		"R1 replaces the platoon's whole route and sends it straight to the marker.")
	_button(JOY_BUTTON_B)
	_check(infantry.order == Battle.Order.HOLD and harness.march_waypoints(0).is_empty(), "Circle clears the route and holds.")
	harness.add_march_waypoint()
	_button(JOY_BUTTON_DPAD_UP)
	_check(infantry.order == Battle.Order.HOLD and harness.march_waypoints(0).is_empty(), "D-pad Up clears the route and holds too.")
	_check(harness.roster_text().contains("[Shield Infantry]") and harness.roster_text().contains("Lead"), "The roster shows every platoon and brackets the selected one.")
	battle.lead_engaged = true
	await _frames(2)
	_check(harness.selected_index == Battle.LEAD_INDEX and not harness.march_mode() and not harness._march_beam.visible,
		"Combat selects the leader, hides the marker and returns the stick to the leader.")
	# Mid-fight, switch to another platoon: its marker comes back and the leader holds.
	var hero_in_fight := battle.hero_position
	_button(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_check(harness.selected_index == 0 and harness.march_mode() and harness._march_beam.visible and not harness.hero_combat_active(),
		"D-pad switches platoons during combat and the stick drives that platoon's marker.")
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(10)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_check(battle.hero_position == hero_in_fight and infantry.order == Battle.Order.MOVE, "Commanding another platoon mid-fight leaves the leader standing.")
	_button(JOY_BUTTON_DPAD_LEFT)
	await _frames(2)
	_check(harness.hero_combat_active() and not harness.march_mode(), "Switching back to the Lead Platoon resumes fighting as the leader.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	battle.lead_engaged = false
	await _frames(2)
	_check(harness.selected_index == 0, "When combat ends, a platoon chosen during the fight stays selected.")
	battle.lead_engaged = true
	await _frames(2)
	battle.lead_engaged = false
	await _frames(2)
	_check(harness.selected_index == 0, "Otherwise the platoon selected before combat comes back afterwards.")
	harness.restart_battle()
	_check(harness.selected_index == Battle.LEAD_INDEX and harness._marker_owner == Battle.LEAD_INDEX,
		"Restart selects the leader’s platoon and resets its waypoint marker.")
	harness.queue_free()
	await process_frame


## The camera sits behind the platoon (on the far side from the marker) and faces the marker.
func _camera_frames(harness: Node, platoon: Vector2, marker: Vector2) -> bool:
	var pivot: Vector3 = harness._camera_pivot
	var camera: Camera3D = harness._hero_camera
	var eye := Vector2(camera.position.x, camera.position.z)
	var toward := (marker - platoon).normalized()
	var facing := -camera.global_transform.basis.z
	var flat := Vector2(facing.x, facing.z).normalized()
	return Vector2(pivot.x, pivot.z).distance_to(platoon) < 0.5 and (platoon - eye).dot(toward) > 3.0 \
		and flat.dot(toward) > 0.95 and camera.position.y > pivot.y + 1.0


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		root.push_input(event, true)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
