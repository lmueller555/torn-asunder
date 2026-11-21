extends SceneTree

const Scene := preload("res://game/battlefield/mara_grain_crossing_playtest.tscn")
const Mission := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const SEED := Grain.Cart.SEED
const BREAD := Grain.Cart.BREAD

var _mission: Mission
var _cues: Array[int] = []
var _clears: Array[StringName] = []
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.first_crossing_committed.connect(func(cart: Grain.Cart) -> void: _cues.append(cart))
	_mission.mission_cleared.connect(func(result: StringName) -> void: _clears.append(result))

	var reserve := _marker(^"Markers/Spawns/InfantryReserve")
	_check(_mission.hero_world_position().is_equal_approx(_marker(^"Markers/Spawns/RoyalHero")), "The hero did not start at the Marches spawn.")
	_check(_mission.battle.formations[0].position.is_equal_approx(Vector2(reserve.x, reserve.z)) and _mission.battle.formations[0].title == "Infantry Reserve", "The real reserve was not placed at its Marches marker.")
	_check_reset_positions()

	_key(KEY_SHIFT, true)
	_button(JOY_BUTTON_A)
	_check(_mission.battle.formations[0].order == Battle.Order.HOLD and _state(SEED) == Grain.CartState.STAGED, "Command Cross did not stay separate from cart dispatch.")
	_key(KEY_G)
	_tick()
	_check(_state(SEED) == Grain.CartState.EN_ROUTE and _state(BREAD) == Grain.CartState.STAGED and _cues.is_empty(), "Dispatch should start one cart without firing a crossing cue.")
	_key(KEY_SHIFT, false)
	_advance_until(func() -> bool: return _mission.committed_cart != -1)
	_check(_cues == [SEED] and _mission._commit_beacons[SEED].visible and _mission._cue.text.contains("north bridge"), "The seed cart did not fire exactly one visible north bridge cue.")
	_check(_mission._carts[SEED].global_position.distance_to(_marker(^"Markers/Routes/BridgeWestBank")) < 0.5, "The cue did not follow physical commitment to the authored bridge.")
	_check(_mission.battle.formations[0].position.is_equal_approx(Vector2(reserve.x, reserve.z)), "The advisory cue moved the reserve without an order.")
	_advance_until(func() -> bool: return _state(SEED) == Grain.CartState.SECURED)
	_check(_mission._carts[SEED].global_position.is_equal_approx(_marker(^"Markers/Objectives/SeedGrainMillYard")) and _mission.objective.outcome == Grain.Outcome.ACTIVE and _clears.is_empty(), "Seed-only travel did not reach the actual yard and wait for bread resolution.")
	_key(KEY_C)
	_key(KEY_T)
	_tick()
	_check(_mission.objective.clear_result == Grain.SEED_ONLY and _mission._goal.text.contains("mill") and _clears == [Grain.SEED_ONLY], "A real turn-back command did not complete a seed-only run.")

	_button(JOY_BUTTON_START)
	_check_reset_positions()
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_tick()
	_check(_state(BREAD) == Grain.CartState.EN_ROUTE and _state(SEED) == Grain.CartState.STAGED and _cues == [SEED], "Controller dispatch did not start the selected bread cart without firing a cue.")
	_advance_until(func() -> bool: return _mission.committed_cart != -1)
	_check(_cues == [SEED, BREAD] and _mission._commit_beacons[BREAD].visible and _mission._cue.text.contains("south ford"), "The bread-first attempt did not fire the distinct south ford cue.")
	_check(_mission._carts[BREAD].global_position.distance_to(_marker(^"Markers/Routes/FordWestBank")) < 0.5, "The south cue did not follow physical commitment to the authored ford.")
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_tick()
	_advance_until(func() -> bool: return _state(BREAD) == Grain.CartState.SECURED)
	_check(_mission._carts[BREAD].global_position.is_equal_approx(_marker(^"Markers/Objectives/BreadGrainStoreYard")), "The bread cart did not traverse to its actual store yard.")
	_check(_cues == [SEED, BREAD] and _state(SEED) == Grain.CartState.EN_ROUTE, "The second dispatch repeated the once-only cue or prematurely secured the seed cart.")
	_button(JOY_BUTTON_Y)
	_tick()
	_check(_mission.objective.clear_result == Grain.BREAD_ONLY and _mission._goal.text.contains("town store") and _clears == [Grain.SEED_ONLY, Grain.BREAD_ONLY], "Controller turn-back did not produce a distinct bread-only result.")
	var retreat_start := _mission._carts[SEED].global_position
	_tick(5)
	_check(_mission._carts[SEED].visible and _mission._carts[SEED].global_position != retreat_start, "A cart already on the road did not visibly retrace its route after the turn-back order.")

	_key(KEY_BACKSPACE)
	_check_reset_positions()
	_key(KEY_G)
	_key(KEY_C)
	_key(KEY_G)
	_tick()
	_advance_until(func() -> bool: return _mission.objective.outcome != Grain.Outcome.ACTIVE)
	_check(_mission.objective.clear_result == Grain.BOTH and _clears == [Grain.SEED_ONLY, Grain.BREAD_ONLY, Grain.BOTH] and _cues == [SEED, BREAD, SEED], "A two-cart run did not award both loads and only one crossing cue.")
	_tick(10)
	_check(_clears.size() == 3 and _cues.size() == 3, "Terminal scene state repeated an event.")

	_button(JOY_BUTTON_START)
	_key(KEY_T)
	_key(KEY_C)
	_key(KEY_T)
	_tick()
	_check(_mission.objective.outcome == Grain.Outcome.FAILED and _mission._goal.text == "No grain was delivered" and _clears.size() == 3 and _cues.size() == 3, "Turning back both loads did not fail without emitting a clear or cue.")
	_mission._restart_button.pressed.emit()
	_check_reset_positions()

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Marches playtest: actual dispatch/turn-back inputs, both first-crossing cues, yard arrivals, all delivery outcomes and retry passed.")
	quit(0 if _failures == 0 else 1)


func _check_reset_positions() -> void:
	_check(_mission.objective.outcome == Grain.Outcome.ACTIVE and _mission.committed_cart == -1 and _mission.selected_cart == SEED, "Restart retained a result, selection, or crossing cue.")
	_check(_state(SEED) == Grain.CartState.STAGED and _state(BREAD) == Grain.CartState.STAGED, "Restart did not stage both wagons.")
	_check(_mission._carts[SEED].global_position.is_equal_approx(_marker(^"Markers/Spawns/SeedGrainCart")) and _mission._carts[BREAD].global_position.is_equal_approx(_marker(^"Markers/Spawns/BreadGrainCart")), "Wagons were not reset to the two authored staging markers.")


func _state(cart: Grain.Cart) -> Grain.CartState:
	return _mission.objective.cart_state(cart)


func _marker(path: NodePath) -> Vector3:
	return _mission.battlefield_marker(path).global_position


func _advance_until(condition: Callable) -> void:
	for _index in range(1050):
		if condition.call():
			return
		_tick()
	_check(false, "An expected route event never arrived.")


func _tick(count := 1) -> void:
	for _index in range(count):
		_mission._physics_process(0.07)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
