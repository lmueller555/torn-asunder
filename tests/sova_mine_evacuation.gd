extends SceneTree

const MissionScene := preload("res://game/battlefield/sova_mine_evacuation.tscn")
const Mission := preload("res://game/battlefield/sova_mine_evacuation.gd")
const Evacuation := preload("res://game/battlefield/sova_mine_tunnels.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = MissionScene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_tick()

	var spawn := _marker(^"Markers/Spawns/DruidGuard")
	var entrance := _marker(^"Markers/Routes/TunnelEntrance")
	var midpoint := _marker(^"Markers/Routes/TunnelMidpoint")
	var outlet := _marker(^"Markers/Routes/TunnelExit")
	var safety := _marker(^"Markers/Objectives/MinerEvacuation")
	_check(_mission.hero_world_position().is_equal_approx(spawn), "Sova did not spawn at DruidGuard.")
	_check(_mission.battle.formations[0].title == "Tunnel Guard" and _mission.battle.formations[1].title == "Outlet Screen", "The allied placeholders are not named for Sova's mission.")
	_check(_party(0) == entrance and _party(1) == midpoint and _mission._witness.global_position.distance_to(midpoint) < 1.0, "The worker stages are not at the real mouth and bend.")

	_drive(KEY_A, -27.0, true)
	_key(KEY_SPACE)
	_tick()
	_check(_status(0) == Evacuation.GroupStatus.STAGED and _status(1) == Evacuation.GroupStatus.STAGED, "Interacting outside both stage zones released a group.")
	_drive(KEY_D, entrance.x, true)
	_drive(KEY_S, entrance.z)
	_check(_mission.hero_world_position().distance_to(entrance) < 0.2, "The hero could not walk to the mouth from the Druid spawn.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mission.battle.order_move(0, _mission.battle.formations[0].position + Vector2.LEFT * 2.0)
	_joy_button(JOY_BUTTON_A)
	_key(KEY_SPACE)
	_tick()
	_check(_status(0) == Evacuation.GroupStatus.STAGED and _mission.battle.formations[0].order == Battle.Order.HOLD, "Command-view Cross is Hold and neither it nor Space releases a group there.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_joy_button(JOY_BUTTON_A)
	_tick()
	_check(_status(0) == Evacuation.GroupStatus.MOVING and _status(1) == Evacuation.GroupStatus.STAGED, "Hero-view Cross did not independently release the mouth group.")
	_tick(75)
	_check(absf(_party(0).x - entrance.x) < 0.05 and _party(0).z > entrance.z and _party(0).z < midpoint.z, "A released group did not visually advance along the tunnel centerline.")
	_drive(KEY_S, midpoint.z)
	_check(_mission.hero_world_position().distance_to(midpoint) < 0.2, "The hero could not walk into the actual tunnel to the bend.")
	_key(KEY_SPACE)
	_tick()
	_check(_status(1) == Evacuation.GroupStatus.MOVING, "Space did not release the bend group from the real marker.")

	_finish_and_check(outlet, safety)
	_joy_button(JOY_BUTTON_START)
	_tick()
	_check(_mission.hero_world_position().is_equal_approx(spawn) and _party(0) == entrance and _party(1) == midpoint and not _mission._witness_at_truce, "Options did not reset hero, groups, and witness to their authored staging positions.")
	_check(_mission.objective.outcome == Evacuation.Outcome.ACTIVE and _mission._stages[0].visible and _mission._stages[1].visible, "Restart did not restore the active objective and stage markers.")

	_drive(KEY_D, midpoint.x, true)
	_drive(KEY_S, midpoint.z)
	_key(KEY_SPACE)
	_tick()
	_check(_status(0) == Evacuation.GroupStatus.STAGED and _status(1) == Evacuation.GroupStatus.MOVING, "The bend could not be released first.")
	_advance_until_safe(1)
	_check(_mission.objective.outcome == Evacuation.Outcome.ACTIVE and _mission._witness_at_truce, "A safe bend group and witness should still wait for the mouth group.")
	_drive(KEY_W, entrance.z)
	_key(KEY_SPACE)
	_tick()
	_finish_and_check(outlet, safety)
	_key(KEY_BACKSPACE)
	_check(_mission.objective.outcome == Evacuation.Outcome.ACTIVE and _party(0) == entrance, "Backspace did not restart the objective.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Sova mine evacuation: authored stages, both release sequences, hero and command controls, tunnel movement, witness truce, completion and replay passed.")
	quit(0 if _failures == 0 else 1)


func _finish_and_check(outlet: Vector3, safety: Vector3) -> void:
	_advance_until_safe(0)
	_advance_until_safe(1)
	_check(_party(0).distance_to(safety) <= 1.0 and _party(1).distance_to(safety) <= 1.0 and _party(0).distance_to(_party(1)) >= 1.5, "The groups did not reach separate spots at the authored Druid safety destination.")
	_check(_mission._witness.global_position.distance_to(outlet) <= 1.0 and _mission._witness.global_position.distance_to(safety) > 10.0, "The willing witness did not stay by the real tunnel outlet under truce.")
	_check(_mission.objective.outcome == Evacuation.Outcome.SUCCEEDED and _mission._goal_label.text == "Evacuation complete", "Both real arrivals plus the truce did not show a complete objective.")


func _advance_until_safe(group: int) -> void:
	for _index in range(1450):
		if _status(group) == Evacuation.GroupStatus.SAFE:
			return
		_tick()
	_check(false, "A released group never reached Druid safety.")


func _drive(key: Key, target: float, along_x := false) -> void:
	_key(key, true)
	for _index in range(560):
		var point := _mission.hero_world_position()
		if absf((point.x if along_x else point.z) - target) < 0.10:
			break
		_tick()
	_key(key, false)


func _marker(path: NodePath) -> Vector3:
	return _mission.battlefield_marker(path).global_position


func _party(group: int) -> Vector3:
	return _mission._groups[group].global_position


func _status(group: int) -> Evacuation.GroupStatus:
	return _mission.objective.group_status(group)


func _tick(count := 1) -> void:
	for _index in range(count):
		_mission._physics_process(1.0 / 60.0)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _joy_button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
