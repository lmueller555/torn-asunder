extends SceneTree

const MissionScene := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = MissionScene.instantiate()
	_mission.opposition_enabled = false
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame

	var spawn := _mission.hero_world_position()
	var infantry_spawn := _mission.battle.formations[0].position
	var pickup := _mission.battlefield_marker(^"Markers/Objectives/GodbridlePickup").position
	var road_exit := _mission.battlefield_marker(^"Markers/Objectives/GodbridleExit").position
	_check(_mission._bridle.visible and _mission._pickup_beacon.visible and not _mission._exit_beacon.visible, "The initial signpost and prop point to the Godbridle.")
	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP, "Interact from outside the pickup zone cannot collect the Godbridle.")

	_drive(KEY_W, road_exit.x, true)
	_check(_mission.hero_world_position().distance_to(road_exit) < 0.15, "The hero can actually walk down the shared mine road to the east exit.")
	_joy_button(JOY_BUTTON_A)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP, "Reaching the exit empty-handed cannot clear the escort.")
	_key(KEY_BACKSPACE)
	_check(_mission.hero_world_position().is_equal_approx(spawn), "Backspace resets hero position and the encounter.")

	_move_to_pickup(pickup)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_button(JOY_BUTTON_X)
	_tick(2)
	_check(_mission.battle.formations[0].order == Battle.Order.MOVE, "Square issues Move during the objective.")
	_joy_button(JOY_BUTTON_A)
	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP and _mission.battle.formations[0].order == Battle.Order.HOLD, "Command Cross remains Hold, and command Space cannot pick up the Godbridle.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_joy_button(JOY_BUTTON_A)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.ESCORTING, "Cross picks up the Godbridle in hero view.")
	_check(_mission._bridle.visible and not _mission._pickup_beacon.visible and _mission._exit_beacon.visible and _mission._goal_label.text.contains("east road exit"), "Successful pickup attaches the prop and changes the HUD and beacon to the exit.")

	# Other formations are not carriers, even if they enter the objective zone.
	_mission.battle.formations[0].position = Vector2(road_exit.x, road_exit.z)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.ESCORTING, "An allied formation at the road exit cannot deliver the hero's Godbridle.")
	_drive(KEY_A, 0.0)
	_drive(KEY_W, road_exit.x, true)
	_check(_mission.objective.phase == Escort.Phase.SUCCEEDED and _mission._goal_label.text == "Escort complete", "Walking the carrier to the real exit wins the mission.")

	var delivered := _mission.hero_world_position()
	_key(KEY_S, true)
	_tick(60)
	_key(KEY_S, false)
	_check(_mission.hero_world_position() == delivered, "The completed objective holds the result until replay.")
	_joy_button(JOY_BUTTON_START)
	_check(_mission.hero_world_position().is_equal_approx(spawn) and _mission.battle.formations[0].position == infantry_spawn, "Options resets the hero and formations at the authored spawns.")
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP and _mission._bridle.visible and _mission._pickup_beacon.visible and not _mission._exit_beacon.visible, "Replay restores the pickup and objective HUD.")

	_move_to_pickup(pickup)
	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.ESCORTING, "Space picks up the Godbridle in hero view.")
	_drive(KEY_A, 0.0)
	_drive(KEY_W, road_exit.x - Mission.EXIT_RADIUS - 0.07, true)
	_mission.report_hero_incapacitated()
	_key(KEY_W, true)
	_tick(4)
	_key(KEY_W, false)
	_check(_mission.objective.phase == Escort.Phase.FAILED and _mission._instructions_label.text.contains("incapacitated"), "An incapacitated carrier cannot deliver and the failure is readable.")
	_mission._restart_button.pressed.emit()
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP and _mission.hero_world_position().is_equal_approx(spawn), "The visible Restart button starts a fresh attempt after failure.")
	_mission.report_bridle_lost()
	_tick()
	_check(_mission.objective.phase == Escort.Phase.FAILED and _mission._instructions_label.text.contains("lost"), "The Godbridle-lost outcome has its own failure text.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Mara mine escort: real road/yard route, gamepad and keyboard pickup, Hold separation, delivery, defeat, loss and restart passed.")
	quit(0 if _failures == 0 else 1)


func _move_to_pickup(pickup: Vector3) -> void:
	_drive(KEY_W, pickup.x, true)
	_drive(KEY_D, pickup.z)
	_check(_mission.hero_world_position().distance_to(pickup) < 0.15, "The hero can walk from the road to the authored pickup.")


func _drive(key: Key, target: float, along_x := false) -> void:
	# Outside combat the leader's platoon marches by Move orders; in combat the key steers.
	var heading: Vector2 = {KEY_W: Vector2.UP, KEY_S: Vector2.DOWN, KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT}[key]
	var held := false
	for index in range(1100):
		var point := _mission.hero_world_position()
		if absf((point.x if along_x else point.z) - target) < 0.10 or _mission._finished():
			break
		var battle = _mission.battle
		if battle.direct_hero_control():
			if not held:
				_key(key, true)
				held = true
		else:
			if held:
				_key(key, false)
				held = false
			battle.order_move(Battle.LEAD_INDEX, battle.hero_position + heading.rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED / 60.0)
		_tick()
	if held:
		_key(key, false)


func _tick(count := 1) -> void:
	for index in range(count):
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


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
