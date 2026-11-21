extends SceneTree

const Scene := preload("res://game/battlefield/raska_well_road_playtest.tscn")
const Mission := preload("res://game/battlefield/raska_well_road_playtest.gd")
const WellRoad := preload("res://game/battlefield/raska_well_road.gd")
const Rival := preload("res://game/battlefield/marches_rival_reserve.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0
const UPPER := WellRoad.Cart.UPPER
const LOWER := WellRoad.Cart.LOWER

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var objective := _mission.objective
	var upper := _mission._carts[UPPER].wagon
	var lower := _mission._carts[LOWER].wagon
	var upper_spawn := upper.global_position
	var lower_spawn := lower.global_position
	var exit := _marker("Objectives/BasinExit")
	_check(_mission._field.name == &"RedBasinWellRoad" and _mission._rival.status == Rival.Status.WAITING \
		and objective.cart_state(UPPER) == WellRoad.CartState.READY and objective.cart_state(LOWER) == WellRoad.CartState.LOADING,
		"Standalone scene uses the real basin, with independent staged carts and a waiting reserve.")
	_mission.battle.hero_position = _xz(exit) - Vector2(3.0, 0.0)
	_drive_to(exit)
	_check(objective.outcome == WellRoad.Outcome.ACTIVE, "Raska reaching the exit cannot count as a cart delivery.")
	_key(KEY_BACKSPACE)

	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_tick(15)
	_check(objective.route_for(UPPER) == WellRoad.Route.SALT_ROAD and upper.global_position != upper_spawn,
		"R1 immediately dispatches the upper cart along the actual salt route.")
	_check(objective.cart_state(LOWER) == WellRoad.CartState.LOADING and lower.global_position == lower_spawn,
		"The upper order does not move the lower cart.")
	_key(KEY_C)
	_button(JOY_BUTTON_Y)
	_key(KEY_SPACE)
	_tick()
	_check(_mission.selected_cart == LOWER and not _mission._boarding and objective.route_for(LOWER) == WellRoad.Route.NONE,
		"Remote loading and premature lower dispatch are both rejected.")
	_wait(func() -> bool: return _mission._rival.status == Rival.Status.MARCHING, 650)
	_check(_mission._cue.text.contains("approaching") and upper.global_position.distance_to(_marker("Routes/SaltRoadWest")) < 1.0,
		"Reaching the salt marker, not a hidden timer, raises a visible reserve warning.")
	var mustered := _mission._rival.global_position
	_tick(30)
	_check(_mission._rival.global_position != mustered, "The mounted reserve physically leaves its muster.")

	for path in [
		"Routes/UpperWellStaging", "Routes/WestApproachFork", "Routes/WashEntryTurn",
		"Routes/LowerWellStaging", "Objectives/LowerBoarding", "Spawns/LowerHouseholds", "Objectives/LowerStorehouse",
	]:
		_drive_to(_marker(path))
	var waiting_household := _mission._households[0].global_position
	_button(JOY_BUTTON_A)
	_tick(20)
	_check(_mission._boarding and _mission._boarded == 0 and lower.global_position != lower_spawn \
		and objective.cart_state(LOWER) == WellRoad.CartState.LOADING,
		"Cross at the real storehouse starts positional boarding, not an instant ready flag.")
	_key(KEY_T)
	_tick()
	_check(objective.route_for(LOWER) == WellRoad.Route.NONE, "A wash order while boarding is not retained.")
	_wait(func() -> bool: return objective.cart_state(LOWER) == WellRoad.CartState.READY, 600)
	_check(_mission._boarded == _mission._households.size() and not _mission._households[0].visible \
		and _mission._households[0].global_position != waiting_household and _mission._riders[0].visible \
		and lower.global_position == _marker("Objectives/LowerBoarding") and objective.route_for(LOWER) == WellRoad.Route.NONE,
		"Physical household arrival changes the lower cart to Ready and displays its riders, with no latent order.")
	_wait(func() -> bool: return _mission._carts[UPPER].waiting_on == "Mounted reserve", 2200)
	var blocked_at := upper.global_position
	_check(_mission._rival.status == Rival.Status.BLOCKING and _mission._status.text.contains("Mounted reserve"),
		"The visible reserve’s actual road position stops the salt cart.")
	_button(JOY_BUTTON_Y)
	_wait(func() -> bool: return objective.cart_state(LOWER) == WellRoad.CartState.SAFE, 3900)
	_check(objective.cart_state(LOWER) == WellRoad.CartState.SAFE and lower.global_position.distance_to(exit) < 2.0 \
		and upper.global_position == blocked_at and objective.outcome == WellRoad.Outcome.ACTIVE,
		"A fresh lower wash order reaches the actual exit while the salt cart remains safely blocked without a timer.")

	_button(JOY_BUTTON_LEFT_SHOULDER)
	_key(KEY_T)
	_tick(45)
	_check(objective.route_for(UPPER) == WellRoad.Route.WASH and upper.global_position.x < blocked_at.x \
		and upper.global_position.distance_to(blocked_at) < 8.0,
		"Rerouting a blocked cart actually reverses down the salt road rather than teleporting.")
	_wait(func() -> bool: return objective.outcome == WellRoad.Outcome.SUCCEEDED, 5800)
	_check(objective.outcome == WellRoad.Outcome.SUCCEEDED and upper.global_position.distance_to(exit) < 2.0 \
		and upper.global_position != lower.global_position and _mission._goal.text.contains("Both"),
		"Both real carts reach independent parking spots in the exit and only then win.")
	_key(KEY_BACKSPACE)
	_check(objective.outcome == WellRoad.Outcome.ACTIVE and _mission.selected_cart == UPPER and _mission._boarded == 0 \
		and _mission._households[0].visible and not _mission._riders[0].visible \
		and upper.global_position == upper_spawn and lower.global_position == lower_spawn \
		and _mission._rival.status == Rival.Status.WAITING, "Restart resets carts, passenger visuals, routes and pressure.")

	_key(KEY_G)
	_wait(func() -> bool: return _mission._carts[UPPER].waiting_on == "Mounted reserve", 3400)
	_check(_mission._carts[UPPER].waiting_on == "Mounted reserve", "The salt blockade repeats only after a new dispatched cart reaches it.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	var screen := _mission.battle.formations[0]
	for route in ["SaltRoadWest", "SaltChargeGate", "MountedChargeStart"]:
		_order_at(_marker("Routes/" + route))
		_finish_march(screen, _marker("Routes/" + route))
	_tick(15)
	_check(screen.order == Battle.Order.HOLD and _mission._rival.status == Rival.Status.SCREENED \
		and _mission._cue.text.contains("screened"), "A real formation reaches and Holds at the marker, reopening the salt lane.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_wait(func() -> bool: return objective.cart_state(UPPER) == WellRoad.CartState.SAFE, 1400)
	_check(objective.cart_state(UPPER) == WellRoad.CartState.SAFE and objective.outcome == WellRoad.Outcome.ACTIVE,
		"Screening lets the salt cart through without substituting for the lower cart.")
	_mission.battle.hero_position = _xz(_marker("Objectives/LowerStorehouse"))
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_button(JOY_BUTTON_A)
	_wait(func() -> bool: return objective.cart_state(LOWER) == WellRoad.CartState.READY, 600)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_wait(func() -> bool: return objective.outcome == WellRoad.Outcome.SUCCEEDED, 3200)
	_check(objective.outcome == WellRoad.Outcome.SUCCEEDED and objective.route_for(LOWER) == WellRoad.Route.SALT_ROAD \
		and lower.global_position.distance_to(exit) < 2.0,
		"The loaded lower cart can also climb onto the screened salt road and deliver.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Well Road verified: real dispatch and boarding, reserve warning/blockade, independent wash arrival, physical backtrack and exit, allied Hold alternative, and restart.")
	quit(0 if _failures == 0 else 1)


func _marker(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _xz(at: Vector3) -> Vector2:
	var local := _mission.to_local(at)
	return Vector2(local.x, local.z)


func _drive_to(at: Vector3) -> void:
	var point := _xz(at)
	var budget := ceili(_mission.battle.hero_position.distance_to(point) / Battle.LEAD_SPEED / DT) + 65
	for i in range(budget):
		var offset := point - _mission.battle.hero_position
		if offset.length() <= 0.18:
			break
		var aim := offset.normalized().rotated(_mission._hero_yaw)
		_march_lead(Vector2(aim.x, aim.y))
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_mission.battle.hero_position.distance_to(point) <= 0.18, "Raska physically reaches %s; got %s." % [point, _mission.battle.hero_position])


func _order_at(at: Vector3) -> void:
	var pointer := root.get_camera_3d().unproject_position(at)
	_check(root.get_visible_rect().has_point(pointer), "Projected formation target is visible: %s." % at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = pointer
	root.push_input(event, true)


func _finish_march(formation: Battle.Formation, at: Vector3) -> void:
	var point := _xz(at)
	var budget := ceili(formation.position.distance_to(point) / Battle.FORMATION_SPEED / DT) + 26
	_wait(func() -> bool: return formation.order != Battle.Order.MOVE, budget)
	_check(formation.order == Battle.Order.HOLD and formation.position.distance_to(point) < 0.085,
		"Formation follows the actual approach to %s; got %s." % [point, formation.position])


func _wait(condition: Callable, budget: int) -> void:
	for i in range(budget):
		if condition.call():
			break
		_tick()


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


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _tick(count := 1) -> void:
	for i in range(count):
		_mission._physics_process(DT)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


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
