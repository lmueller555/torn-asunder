extends SceneTree

const Scene := preload("res://game/battlefield/sova_vault_return_playtest.tscn")
const Mission := preload("res://game/battlefield/sova_vault_return_playtest.gd")
const Return := preload("res://game/battlefield/sova_vault_return.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const SHELF := ["ShelfDecision", "ShelfFoot", "ShelfClimb", "ShelfHold", "ShelfRejoin", "Forecourt"]
const SIDE := ["SideDecision", "SideApproach", "SideTurn", "SideRampFoot", "SideBlindBend", "SideRampTurn", "SideNorthToe", "SideHighBend", "SideRejoin", "Forecourt"]

var _mission: Mission
var _outcomes: Array[bool] = []
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_finished.connect(func(won: bool) -> void: _outcomes.append(won))
	for shelf in [true, false]:
		_check_reset()
		_play_route(shelf)
		_check(_mission.objective.phase == Return.Phase.SUCCEEDED and _mission._goal.text.contains("back in the vault") and _mission._detail.text.contains("without speaking a command"), "A real vault return did not clear without a command.")
		_check(_mission._bridle.global_position.distance_to(_marker(Return.RETURN_MARKER)) < 1.25, "The clear did not leave the carried bridle at the vault.")
		var count := _outcomes.size()
		_tick(100)
		_check(_outcomes.size() == count, "A terminal return repeated the result.")
		_button(JOY_BUTTON_START, true)
		_check_reset()

	_check(_outcomes == [true, true], "Both actual routes must emit one success each.")
	_mission.report_sova_fell()
	_tick()
	_check(_mission.objective.phase == Return.Phase.FAILED and _outcomes == [true, true, false], "Confirmed carrier defeat did not emit one actual failure.")
	_key(KEY_BACKSPACE, true)
	_check_reset()
	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Vault playtest: actual shelf/side routes, physical reserve and screens, fresh closure, separate terrace, no command and retry passed.")
	quit(0 if _failures == 0 else 1)


func _play_route(shelf: bool) -> void:
	var terrain_route: Array = SHELF if shelf else SIDE
	var custody := _marker(^"Markers/Objectives/CustodyLine")
	var entrance := _marker(^"Markers/Objectives/VaultEntrance")
	var vault := _marker(Return.RETURN_MARKER)
	var forecourt := _route("Forecourt")
	_read(shelf, true)
	_tick(150)
	_read(shelf, false)
	_check(_mission.objective.phase == Return.Phase.CARRYING and not _mission._reserve_active and _mission.objective.closure_progress == 0.0, "Waiting or interacting away from the vault armed closure or mobilized the reserve.")
	_walk(_route("ValleyAssembly"))
	_walk(_route("SafeStaging"))
	var branch_rejoin: String = "ShelfRejoin" if shelf else "SideRejoin"
	for point: String in terrain_route:
		_walk(_route(point))
		if point == branch_rejoin:
			_check(_mission._reserve_active and _mission._reserve_status.text.contains("reserve") and _mission._reserve.global_position.distance_to(_mission._rival_route[0]) < 40.0, "The reserve did not react visibly to the actual branch approach, or teleported to the vault.")
	_check(_mission.objective.phase == Return.Phase.CARRYING and _mission.hero_world_position().distance_to(forecourt) < 0.3, "Arriving at the actual forecourt should not return the bridle.")

	if shelf:
		for spot in [_route("TerraceApproach"), _route("TerraceEntry"), _marker(^"Markers/Objectives/WitnessTerrace")]:
			_walk(spot)
		_read(shelf, true)
		_tick(100)
		_read(shelf, false)
		_check(_mission.objective.phase == Return.Phase.CARRYING, "The separate witness terrace activated the vault return.")
		for spot in [_route("TerraceEntry"), _route("TerraceApproach"), forecourt]:
			_walk(spot)

	for spot in [custody, entrance, vault]:
		_walk(spot)
	_advance_until(func() -> bool: return _mission._reserve_contests())
	_check(_mission._reserve.global_position.distance_to(entrance) < 6.1 and _mission._vault_label.text == "VAULT CONTESTED", "Hostile pressure did not originate from a physical reserve in the marked closure zone.")
	_read(shelf, true)
	_tick(140)
	_read(shelf, false)
	_check(_mission.objective.phase == Return.Phase.CARRYING and _mission.objective.closure_progress == 0.0, "A rejected interaction in a contested vault advanced closure or caused automatic defeat.")

	var guard_index := 0 if shelf else 1
	for point: String in terrain_route:
		_move_guard(guard_index, _route(point))
	_move_guard(guard_index, custody)
	_check(_mission._reserve_screened and _mission._reserve_contests(), "A Hold order should start physical relief but not make the rival instantly disappear.")
	_advance_until(func() -> bool: return not _mission._reserve_contests())
	_check(_mission._reserve.global_position != entrance and _mission.objective.phase == Return.Phase.CARRYING, "Relieving the zone did not physically dislodge the reserve or incorrectly queued the old interaction.")

	_key(KEY_SHIFT, true)
	_button(JOY_BUTTON_A, true)
	_tick()
	_button(JOY_BUTTON_A, false)
	_key(KEY_SHIFT, false)
	_check(_mission.objective.phase == Return.Phase.CARRYING, "Command Cross issued a vault interaction instead of Hold.")
	_read(shelf, true)
	_tick(15)
	_read(shelf, false)
	var partial := _mission.objective.closure_progress
	_check(partial > 0.15 and _mission.objective.phase == Return.Phase.RETURNING, "The carrier's fresh return interaction did not start visible closure.")

	# Repositioning the guard removes the screen. The reserve must walk back in.
	_order_guard(guard_index, forecourt)
	_tick(12)
	_check(not _mission._reserve_screened and _mission.battle.formations[guard_index].order == Battle.Order.MOVE and is_equal_approx(_mission.objective.closure_progress, partial), "A live guard order or paused player progress did not continue correctly.")
	_advance_until(func() -> bool: return _mission._reserve_contests())
	_read(shelf, true)
	_tick(30)
	_read(shelf, false)
	_check(_mission.objective.pause_reason == Return.PauseReason.CONTESTED and is_equal_approx(_mission.objective.closure_progress, partial), "Renewed physical contest did not pause the same closure.")
	_move_guard(guard_index, forecourt)
	_move_guard(guard_index, custody)
	_advance_until(func() -> bool: return not _mission._reserve_contests())

	# Retreat is recoverable, but re-entering without fresh input does not use
	# the old authorization. There is no independent witness count or gate.
	_walk(custody)
	_check(_mission.objective.pause_reason == Return.PauseReason.CARRIER_AWAY, "Leaving the vault zone did not interrupt the carrier's return.")
	_read(shelf, true)
	_tick()
	_walk(entrance)
	_walk(vault)
	_read(shelf, false)
	_check(_mission.objective.pause_reason == Return.PauseReason.RETURN_INTERACTION_REQUIRED and is_equal_approx(_mission.objective.closure_progress, partial), "Early input while retreating queued a return or erased prior progress.")
	_read(shelf, true)
	_advance_until(func() -> bool: return _mission.objective.phase == Return.Phase.SUCCEEDED)
	_read(shelf, false)


func _check_reset() -> void:
	var spawn := _marker(^"Markers/Spawns/SovaCarrier")
	_check(_mission.hero_world_position().is_equal_approx(spawn) and _mission._bridle.visible and _mission._bridle.global_position.distance_to(spawn) < 1.3, "Retry did not restore the authored carrier and his bridle.")
	_check(_mission.objective.phase == Return.Phase.CARRYING and _mission.objective.closure_progress == 0.0 and not _mission._reserve_active and _mission._reserve.global_position == _mission._rival_route[0], "Retry retained a result, progress, or a moved reserve.")


func _move_guard(index: int, at: Vector3) -> void:
	_order_guard(index, at)
	var guard := _mission.battle.formations[index]
	_advance_until(func() -> bool: return guard.order != Battle.Order.MOVE)
	_check(guard.order == Battle.Order.HOLD and guard.position.is_equal_approx(_flat(at)), "An authored guard Move/Hold could not reach %s from %s." % [at, guard.position])


func _order_guard(index: int, at: Vector3) -> void:
	_key(KEY_SHIFT, true)
	_mission.selected_index = index
	_mission.cursor = _flat(at)
	_button(JOY_BUTTON_X, true)
	_key(KEY_SHIFT, false)


func _walk(target: Vector3) -> void:
	for _index in range(1300):
		var distance := _flat(target) - _flat(_mission.hero_world_position())
		if distance.length() < 0.25:
			break
		var stick := distance.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(_flat(target).distance_to(_flat(_mission.hero_world_position())) < 0.27, "Sova could not walk to %s from %s." % [target, _mission.hero_world_position()])


func _read(shelf: bool, down: bool) -> void:
	if shelf:
		_button(JOY_BUTTON_A, down)
	else:
		_key(KEY_SPACE, down)


func _advance_until(condition: Callable) -> void:
	for _index in range(1300):
		if condition.call():
			return
		_tick()
	_check(false, "An expected vault event never arrived.")


func _route(id: String) -> Vector3:
	return _marker(NodePath("Markers/Routes/" + id))


func _marker(path: NodePath) -> Vector3:
	return _mission.battlefield_marker(path).global_position


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _tick(count := 1) -> void:
	for _index in range(count):
		_mission._physics_process(0.06)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _button(code: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = down
	root.push_input(event, true)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
