extends SceneTree

const Scene := preload("res://game/battlefield/mara_moonwash_playtest.tscn")
const Mission := preload("res://game/battlefield/mara_moonwash_playtest.gd")
const Quay := preload("res://game/battlefield/mara_moonwash_quay.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _failures := 0
var _warnings := 0
var _closures := 0
var _results: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.objective.lower_quay_warned.connect(func() -> void: _warnings += 1)
	_mission.objective.lower_quay_closed.connect(func() -> void: _closures += 1)
	_mission.mission_finished.connect(func(won: bool) -> void: _results.append(won))
	var battle := _mission.battle
	var field := _mission._field
	var vanguard := battle.formations[0]
	var rear_guard := battle.formations[1]
	var hero_camera := root.get_camera_3d()
	_check(field.name == &"MoonwashHarborCampaign" and battle.hero_position == _point("Spawns/HumanHero")
		and vanguard.position == _point("Spawns/RoyalVanguard") and rear_guard.position == _point("Spawns/RoyalRearGuard"),
		"The actual campaign-scale Human spawns are used.")
	_check(_mission.objective.lower_quay == Quay.LowerQuay.OPEN and _mission._blocker.collision_layer == 0
		and not _mission._cracks.visible, "No hazard advances before a real approach.")

	_drive("Routes/FracturedQuay")
	_drive("Routes/UpperStairFoot")
	_check(_warnings == 1 and _closures == 0 and _mission._cracks.visible
		and _mission._route.text.contains("cracking"), "The actual foot/slab approach warns visibly before closure.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	_button(JOY_BUTTON_DPAD_RIGHT) # Select Royal Vanguard.
	_march(vanguard, "Routes/UpperStairFoot")
	_march(vanguard, "Routes/UpperStairLanding")
	_button(JOY_BUTTON_A)
	_check(vanguard.order == Battle.Order.HOLD and _closures == 0 and _mission._blocker.collision_layer == 0,
		"Vanguard can hold the real landing without dropping a wall on the hero at the stair foot.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_drive("Routes/UpperStairLanding")
	_check(_closures == 1 and _mission.objective.lower_quay == Quay.LowerQuay.CLOSED and _mission._rubble.visible
		and _mission._roster.text.contains("Royal Rear Guard: Withdrawing"),
		"Once the gate is empty and the inland route is protected, only the lower stair closes.")
	await physics_frame
	await physics_frame
	var probe := _point("Routes/UpperStairFoot")
	_check(not _mission._terrain.can_move(probe, probe + Vector2(0, -0.28), true)
		and _mission._blocker.collision_layer == 1,
		"The phase change is a physical obstruction to the lower stair, not only UI.")

	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	for id: String in ["Routes/UpperStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		_march(vanguard, id)
	_check(vanguard.order == Battle.Order.EXTRACTED and _mission.objective.is_platoon_extracted(Quay.Platoon.FIRST)
		and not _mission._formation_models[0].visible and _mission._formation_label.text.contains("Extracted"),
		"All visible vanguard members reached the exit and the formation is visibly locked.")
	var safe_position := vanguard.position
	_order("Routes/UpperQuay")
	_button(JOY_BUTTON_X)
	_button(JOY_BUTTON_A)
	_tick(100)
	_check(vanguard.position == safe_position and vanguard.order == Battle.Order.EXTRACTED,
		"Real Move and Hold input cannot draw a saved platoon back into the fight.")

	_button(JOY_BUTTON_DPAD_RIGHT)
	for id: String in ["Routes/QuaySafeTurn", "Routes/InlandBypass", "Routes/InlandApproach", "Routes/InlandStairTop",
		"Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		_march(rear_guard, id)
	_check(rear_guard.order == Battle.Order.EXTRACTED and _mission.objective.phase == Quay.Phase.WITHDRAWING
		and _results.is_empty(), "The rear guard can bypass the physical closure; two platoons alone cannot win.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	for id: String in ["Routes/UpperStairTop", "Routes/UpperQuay", "Objectives/UpperQuayExit"]:
		_drive(id)
	_check(_mission.objective.phase == Quay.Phase.SUCCEEDED and _mission._goal.text == "Withdrawal complete"
		and _results == [true] and _warnings == 1 and _closures == 1,
		"The live hero and both routes complete the withdrawal without any Elven rescue or combat condition.")
	_button(JOY_BUTTON_START)
	_check(_mission._field == field and _mission.battle != battle and _mission.battle.hero_position == _point("Spawns/HumanHero")
		and root.get_camera_3d() == hero_camera and _mission.objective.lower_quay == Quay.LowerQuay.OPEN
		and _mission._blocker.collision_layer == 0 and not _mission._cracks.visible
		and _mission._formation_members[0][0].visible and _mission._formation_members[1][0].visible,
		"Options retries on the same maps and resets hazard, orders, members and hero camera.")

	_spoil_inland_route_for_test()
	await physics_frame
	await physics_frame
	for id: String in ["Routes/FracturedQuay", "Routes/UpperStairFoot", "Routes/UpperStairLanding"]:
		_drive(id)
	_tick(100)
	_check(_warnings == 2 and _closures == 1 and _mission.objective.lower_quay == Quay.LowerQuay.WARNED
		and _mission._blocker.collision_layer == 0, "If a real obstruction blocks the inland route, only a warning is possible.")
	_mission.report_platoon_wiped(Quay.Platoon.SECOND)
	_tick()
	_check(_mission.objective.phase == Quay.Phase.FAILED and _results == [true, false]
		and _mission._route.text.contains("Royal Rear Guard"), "A wiped unextracted group correctly fails the attempt.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("High Quay playtest: real inputs, stair and inland paths, warning, safe solid closure, extraction, orders, defeat and retry passed.")
	quit(0 if _failures == 0 else 1)


func _spoil_inland_route_for_test() -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 4)
	collider.shape = box
	_mission.add_child(body)
	body.position = _mission._ground(_point("Routes/InlandBypass"), 1.5)
	body.add_child(collider)


func _marker(id: String) -> Marker3D:
	return _mission.battlefield_marker(NodePath("Markers/" + id))


func _point(id: String) -> Vector2:
	var local := _mission.to_local(_marker(id).global_position)
	return Vector2(local.x, local.z)


func _order(id: String) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = root.get_camera_3d().unproject_position(_marker(id).global_position)
	root.push_input(click, true)


func _march(group: Battle.Formation, id: String) -> void:
	var target := _point(id)
	_order(id)
	_check(group.order == Battle.Order.MOVE and group.destination.distance_to(target) < 0.05, "Projected order reaches %s." % id)
	var budget := ceili(group.position.distance_to(target) / (group.move_speed * group.speed_factor()) / DT) + 95
	for step in range(budget):
		if group.order != Battle.Order.MOVE:
			break
		_tick()
	_check((group.order == Battle.Order.HOLD and group.position.distance_to(target) < 0.05)
		or (id == "Objectives/UpperQuayExit" and group.order == Battle.Order.EXTRACTED),
		"%s actually reaches %s; got %s / order %d." % [group.title, id, group.position, group.order])


func _drive(id: String) -> void:
	var target := _point(id)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.LEAD_SPEED / DT) + 110
	var reached := false
	for step in range(budget):
		var remaining := target - _mission.battle.hero_position
		if remaining.length() < 0.14 or (id == "Objectives/UpperQuayExit" and _mission.objective.hero_extracted):
			reached = true
			break
		var aim := remaining.normalized().rotated(_mission._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y))
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(reached, "Actual hero travel reaches %s; got %s." % [id, _mission.battle.hero_position])


func _tick(count := 1) -> void:
	for step in range(count):
		_mission._physics_process(DT)


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


## Outside combat the leader travels with their platoon by Move orders, as the
## player sets them; in combat the stick steers the leader directly.
func _march_lead(aim: Vector2) -> void:
	var battle = _mission.battle
	if battle.direct_hero_control():
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		return
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if aim.length_squared() > 0.0:
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED * DT)
