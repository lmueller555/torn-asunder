extends SceneTree

const Scene := preload("res://game/battlefield/mara_grain_crossing_playtest.tscn")
const Mission := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const Rival := preload("res://game/battlefield/marches_rival_reserve.gd")
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

	# North first: an unopposed rival physically blocks seed. Reposition and Hold
	# using the real command inputs, then turn back the second, undispatched cart.
	_key(KEY_SHIFT, true)
	_button(JOY_BUTTON_A)
	_check(_mission.battle.formations[0].order == Battle.Order.HOLD and _state(SEED) == Grain.CartState.STAGED, "Command Cross did not stay separate from cart dispatch.")
	_key(KEY_G)
	_tick()
	_key(KEY_SHIFT, false)
	_check(_state(SEED) == Grain.CartState.EN_ROUTE and _state(BREAD) == Grain.CartState.STAGED and _cues.is_empty(), "Dispatch should start one cart without firing a crossing cue.")
	_check_blockade(SEED, &"BridgeWestBank", &"MillApproach")
	_check(_mission.battle.formations[0].position.is_equal_approx(Vector2(reserve.x, reserve.z)), "The event moved an allied formation without an order.")
	var blocked_at := _mission._carts[SEED].global_position
	_tick(320)
	_check(_mission.objective.outcome == Grain.Outcome.ACTIVE and _mission._carts[SEED].global_position == blocked_at and _state(BREAD) == Grain.CartState.STAGED, "The blocked cart advanced, the second cart moved, or a hidden timer resolved the operation.")
	_screen_lane([&"ReserveFork", &"BridgeApproachWest", &"BridgeWestBank", &"BridgeDeck", &"BridgeEastBank"], &"MillApproach")
	_advance_until(func() -> bool: return _state(SEED) == Grain.CartState.SECURED)
	_check(_mission._carts[SEED].global_position.is_equal_approx(_marker(^"Markers/Objectives/SeedGrainMillYard")) and _mission.objective.outcome == Grain.Outcome.ACTIVE and _clears.is_empty(), "Screened seed did not reach the actual yard and wait for bread resolution.")
	_key(KEY_C)
	_key(KEY_T)
	_tick()
	_check(_mission.objective.clear_result == Grain.SEED_ONLY and _clears == [Grain.SEED_ONLY], "A staged turn-back did not complete the seed-only run.")

	# South first: the rival goes south instead. Leave it unopposed, deliver the
	# north cart, then turn back bread. Relief is an option, not a required kill.
	_button(JOY_BUTTON_START)
	_check_reset_positions()
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_tick()
	_check(_state(BREAD) == Grain.CartState.EN_ROUTE and _state(SEED) == Grain.CartState.STAGED and _cues == [SEED], "Controller dispatch did not start the selected bread cart without firing a cue.")
	_check_blockade(BREAD, &"FordWestBank", &"StoreApproach")
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_tick()
	_advance_until(func() -> bool: return _state(SEED) == Grain.CartState.SECURED)
	_check(_cues == [SEED, BREAD] and _mission._blocked_cart == BREAD, "The rival switched lanes or prevented the unopposed north delivery.")
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_button(JOY_BUTTON_Y)
	_tick()
	_check(_mission.objective.clear_result == Grain.SEED_ONLY and _clears == [Grain.SEED_ONLY, Grain.SEED_ONLY], "The alternate delivery and controller turn-back did not resolve the blocked attempt.")
	var retreat_start := _mission._carts[BREAD].global_position
	_tick(5)
	_check(_mission._carts[BREAD].visible and _mission._carts[BREAD].global_position != retreat_start, "A returning cart did not visibly retrace its route.")

	# North first again: bread remains viable and gives a distinct debrief.
	_key(KEY_BACKSPACE)
	_check_reset_positions()
	_key(KEY_G)
	_tick()
	_check_blockade(SEED, &"BridgeWestBank", &"MillApproach")
	_key(KEY_C)
	_key(KEY_G)
	_tick()
	_advance_until(func() -> bool: return _state(BREAD) == Grain.CartState.SECURED)
	_check(_mission._carts[BREAD].global_position.is_equal_approx(_marker(^"Markers/Objectives/BreadGrainStoreYard")) and _mission._blocked_cart == SEED, "Leaving the rival north did not preserve the real south delivery.")
	_key(KEY_C)
	_key(KEY_T)
	_tick()
	_check(_mission.objective.clear_result == Grain.BREAD_ONLY and _cues == [SEED, BREAD, SEED], "The alternate southern delivery did not resolve once without changing the rival's lane.")

	# South first with relief: both carts can still be delivered.
	_button(JOY_BUTTON_START)
	_check_reset_positions()
	_key(KEY_C)
	_key(KEY_G)
	_tick()
	_check_blockade(BREAD, &"FordWestBank", &"StoreApproach")
	_key(KEY_C)
	_key(KEY_G)
	_tick()
	_screen_lane([&"ReserveFork", &"ShelteredTurn", &"FordApproachWest", &"FordWestBank", &"FordShallows", &"FordEastBank"], &"StoreApproach")
	_advance_until(func() -> bool: return _mission.objective.outcome != Grain.Outcome.ACTIVE)
	_check(_mission.objective.clear_result == Grain.BOTH and _clears == [Grain.SEED_ONLY, Grain.SEED_ONLY, Grain.BREAD_ONLY, Grain.BOTH] and _cues == [SEED, BREAD, SEED, BREAD], "A relieved two-cart run did not award both loads with one event.")
	_tick(10)
	_check(_clears.size() == 4 and _cues.size() == 4, "Terminal scene state repeated an event.")

	_button(JOY_BUTTON_START)
	_key(KEY_T)
	_key(KEY_C)
	_key(KEY_T)
	_tick()
	_check(_mission.objective.outcome == Grain.Outcome.FAILED and _mission._goal.text == "No grain was delivered" and _clears.size() == 4 and _cues.size() == 4, "Turning back both loads did not fail without emitting a clear or event.")
	_mission._restart_button.pressed.emit()
	_check_reset_positions()

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Marches playtest: both real rival marches, blockades, allied Hold relief, viable other lanes, all delivery outcomes and retry passed.")
	quit(0 if _failures == 0 else 1)


func _check_blockade(cart: Grain.Cart, crossing: StringName, post: StringName) -> void:
	var initial := _mission.rival.global_position
	var cue_count := _cues.size()
	_advance_until(func() -> bool: return _mission.committed_cart != -1)
	_check(_cues.size() == cue_count + 1 and _cues.back() == cart and _mission._commit_beacons[cart].visible, "Physical crossing commitment did not emit exactly one visible rival event.")
	_check(_mission._carts[cart].global_position.distance_to(_route(crossing)) < 0.6 and _mission.rival.global_position == initial, "The cart did not reach its real crossing or the rival teleported on commitment.")
	_tick(25)
	_check(_mission.rival.status == Rival.Status.MARCHING and _mission.rival.global_position.distance_to(initial) > 5.0, "The provisional reserve did not visibly move along its selected approach.")
	_advance_until(func() -> bool: return _mission._blocked_cart == cart)
	_check(_mission.rival.status == Rival.Status.BLOCKING and _mission.rival.global_position.is_equal_approx(_route(post)), "The reserve did not reach the proper authored lane blockade.")
	_check(_state(cart) == Grain.CartState.EN_ROUTE and _mission._status.text.contains("Blocked by rival reserve"), "A blockade did not stall only the threatened cart or report the reason.")


func _screen_lane(route: Array, post: StringName) -> void:
	_key(KEY_SHIFT, true)
	var formation: Battle.Formation = _mission.battle.formations[0]
	for waypoint in route:
		var point := _route(waypoint)
		_mission.cursor = Vector2(point.x, point.z)
		_button(JOY_BUTTON_X)
		_advance_until(func() -> bool: return formation.order != Battle.Order.MOVE)
		_check(formation.position.is_equal_approx(_mission.cursor), "The real allied Move order could not reach the lane waypoint %s." % waypoint)

	var target := _route(post)
	_mission.cursor = Vector2(target.x, target.z)
	_button(JOY_BUTTON_X)
	_advance_until(func() -> bool: return formation.position.distance_to(_mission.cursor) < Rival.SCREEN_RADIUS - 0.6)
	_check(formation.order == Battle.Order.MOVE and _mission.rival.status == Rival.Status.BLOCKING, "A moving ally screened the lane without a Hold order.")
	_button(JOY_BUTTON_A)
	_tick()
	_check(formation.order == Battle.Order.HOLD and _mission.rival.status == Rival.Status.SCREENED and _mission._blocked_cart == -1, "Holding an ally at the live blockade did not reopen the lane.")
	_mission.cursor = formation.position + Vector2.LEFT * 8.0
	_button(JOY_BUTTON_X)
	_tick()
	_check(_mission.rival.status == Rival.Status.BLOCKING and _mission._blocked_cart == _mission.committed_cart, "Moving off the screen did not restore the physical blockade before the cart passed.")
	_button(JOY_BUTTON_A)
	_tick()
	_check(_mission.rival.status == Rival.Status.SCREENED, "Re-establishing Hold did not restore the screen.")
	_key(KEY_SHIFT, false)


func _route(id: StringName) -> Vector3:
	return _marker(NodePath("Markers/Routes/" + String(id)))


func _check_reset_positions() -> void:
	_check(_mission.objective.outcome == Grain.Outcome.ACTIVE and _mission.committed_cart == -1 and _mission.selected_cart == SEED, "Restart retained a result, selection, or crossing cue.")
	_check(_state(SEED) == Grain.CartState.STAGED and _state(BREAD) == Grain.CartState.STAGED, "Restart did not stage both wagons.")
	_check(_mission.rival.status == Rival.Status.WAITING and _mission.rival.global_position == _mission.get_node("RivalApproach/ReserveMuster").global_position, "Restart retained rival movement or a blockade.")
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
