extends SceneTree

const Mission := preload("res://game/battlefield/neris_greyhollow_campaign.gd")
const SCENE := preload("res://game/battlefield/neris_greyhollow_campaign.tscn")
const MAP := preload("res://game/battlefields/year_one_mine_campaign.tscn")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 0.1

var _mission: Mission
var _outcomes: Array[bool] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_mission = SCENE.instantiate()
	_mission.set_physics_process(false)
	root.add_child(_mission)
	_mission.mission_finished.connect(func(won: bool) -> void: _outcomes.append(won))
	await physics_frame
	await physics_frame
	if not _require(_mission.battlefield_scene == MAP, "registered Greyhollow map is required"):
		return
	if not _require(_mission.enable_sector_camera and _mission.battle.lead_platoon_enabled, "ordinary lead and sector command required"):
		return
	if not _require(_paths_fit(), "authored actor or tactical route is obstructed"):
		return
	if not _try_clear() or not _try_party_loss() or not _try_neris_loss() or not _try_timeout():
		return
	print("Greyhollow Dryad finale: real geometry, contact, rescue, screened withdrawal, losses, and restart verified.")
	quit()


func _try_clear() -> bool:
	var cue: Label = _mission.get_node("ObjectiveHUD/Panel/Margin/Readout/Cue")
	if not _require(cue.text.contains("believes"), "opening must distinguish Neris's fear from a confirmed event"):
		return false
	_mission.battle.order_move(Mission.SCREEN_PARTY, Mission.COVER)
	_tick(4.0)
	if not _require(_mission.phase == Mission.Phase.APPROACH and _outcomes.is_empty(), "screen alone cannot start the strike"):
		return false
	# The actual tactical mouse route must find the marker through the camera
	# ray, not just accept an injected destination into the simulation.
	if not _issue_strike_order():
		return false
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.CONTACT):
		return _require(false, "real Strike order did not initiate contact")
	if not _require(not _mission.miners_beyond_reach, "striking did not show the attempted interdiction before the breakout"):
		return false
	_mission.battle.order_move(Battle.LEAD_INDEX, Mission.FALLBACK)
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.SCREEN):
		return _require(false, "Human rescue detail did not break through")
	if not _require(_mission.miners_beyond_reach and _mission._xz(_mission._miners).y >= 75, "breakout must physically clear the tunnel midpoint"):
		return false
	_mission.battle.order_move(Mission.STRIKE, Mission.STRIKE_TURN)
	if not _until(func() -> bool: return _mission.battle.formations[Mission.STRIKE].position == Mission.STRIKE_TURN):
		return _require(false, "the marked strike turn was not reachable under pressure")
	_mission.battle.order_move(Mission.STRIKE, Mission.FALLBACK)
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.RETREAT):
		return _require(false, "screen did not cover Neris and Strike until they were clear")
	if not _require(_outcomes.is_empty() and _mission.battle.formations[Mission.STRIKE].order == Battle.Order.EXTRACTED, "one party and Neris cannot finish without the screen"):
		return false
	var screen := _mission.battle.formations[Mission.SCREEN_PARTY]
	if not _issue_projected_order(Mission.SCREEN_PARTY, Mission.SCREEN_TURN) or not _until(func() -> bool:
		return screen.order == Battle.Order.HOLD and screen.position.distance_to(Mission.SCREEN_TURN) < 0.03):
		return _require(false, "Screen Party must clear the shelf in Closed using the marked turn")
	if not _issue_projected_order(Mission.SCREEN_PARTY, Mission.FALLBACK, true):
		return false
	if not _require(screen.spacing == Battle.Spacing.NORMAL, "A real formation key widens the Screen Party for its final retreat"):
		return false
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.SUCCEEDED):
		return _require(false, "screen did not withdraw on the real route")
	_tick(1.0)
	return _require(_outcomes == [true] and _mission.miners_beyond_reach, "only one clear, independent Human rescue preserved") \
		and _require(_mission.battle.lead.order == Battle.Order.EXTRACTED \
			and _mission.battle.formations[Mission.SCREEN_PARTY].order == Battle.Order.EXTRACTED, "all required units must extract") \
		and _require(cue.text.contains("did not stop"), "victory must not be presented as stopping the Humans")


func _issue_strike_order() -> bool:
	return _issue_projected_order(Mission.STRIKE, _mission._press)


func _issue_projected_order(index: int, destination: Vector2, widen := false) -> bool:
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	_mission._unhandled_input(shift)
	for i in _mission.battle.formations.size():
		if _mission.selected_index == index:
			break
		var select_next := InputEventKey.new()
		select_next.physical_keycode = KEY_X
		select_next.pressed = true
		_mission._unhandled_input(select_next)
	if widen:
		var loosen := InputEventKey.new()
		loosen.physical_keycode = KEY_O
		loosen.pressed = true
		_mission._unhandled_input(loosen)
	var camera: Camera3D = _mission.get_node("CommandCamera")
	var order := InputEventMouseButton.new()
	order.button_index = MOUSE_BUTTON_RIGHT
	order.pressed = true
	order.position = camera.unproject_position(_mission.to_global(_mission._ground(destination)))
	_mission._unhandled_input(order)
	shift.pressed = false
	_mission._unhandled_input(shift)
	var formation := _mission.battle.formations[index]
	return _require(formation.order == Battle.Order.MOVE and formation.destination.distance_to(destination) < 0.03,
		"Shift and a right-click must order %s to its visible marker" % formation.title)


func _try_party_loss() -> bool:
	if not _restart_and_attack():
		return false
	# Leave the Strike party in the yard to be physically overrun.
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.FAILED):
		return _require(false, "uncovered Strike party never fell")
	_tick(1.0)
	return _require(_outcomes == [true, false] and _mission.battle.formations[Mission.STRIKE].order == Battle.Order.DEFEATED \
		and _mission.strength[Mission.STRIKE + 1] == 0.0, "live rearguard pressure must defeat the Strike party exactly once")


func _try_neris_loss() -> bool:
	if not _restart_and_attack():
		return false
	_mission.battle.order_move(Battle.LEAD_INDEX, Vector2(-68.0, 35.0))
	_mission.battle.order_move(Mission.STRIKE, Mission.STRIKE_TURN)
	if not _until(func() -> bool: return _mission.battle.lead_engaged):
		return _require(false, "hostile contact must hand Neris direct control")
	# Follow toward the contact with actual hero steering instead of freezing
	# on the safe side of the rearguard's route.
	var forward := InputEventKey.new()
	forward.physical_keycode = KEY_W
	forward.pressed = true
	_mission._unhandled_input(forward)
	_tick(2.0)
	forward.pressed = false
	_mission._unhandled_input(forward)
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.FAILED):
		return _require(false, "Neris should fall if left in live rearguard contact")
	return _require(_outcomes == [true, false, false] and _mission.battle.lead.order == Battle.Order.DEFEATED \
		and _mission.strength[0] == 0.0, "Neris falling must defeat the attempt independently of the Strike party")


func _try_timeout() -> bool:
	if not _restart_and_attack():
		return false
	_mission.battle.order_move(Battle.LEAD_INDEX, Mission.FALLBACK + Vector2(10.0, -3.0))
	_mission.battle.order_move(Mission.SCREEN_PARTY, Mission.FALLBACK + Vector2(10.0, -1.0))
	_mission.battle.order_move(Mission.STRIKE, Mission.STRIKE_TURN)
	if not _until(func() -> bool: return _mission.battle.formations[Mission.STRIKE].position == Mission.STRIKE_TURN):
		return _require(false, "Strike route became blocked")
	_mission.battle.order_move(Mission.STRIKE, Mission.FALLBACK + Vector2(10.0, 0.0))
	if not _until(func() -> bool: return _mission.phase == Mission.Phase.FAILED):
		return _require(false, "skipping the screen must not complete the mission or wait forever")
	return _require(_outcomes == [true, false, false, false] and _mission.seconds_left == 0.0 \
		and _mission.miners_safe and _mission.battle.lead.can_receive_orders(), "withdrawal deadline can fail surviving parties without undoing Human escape")


func _restart_and_attack() -> bool:
	_mission.restart_mission()
	if not _require(_mission.phase == Mission.Phase.APPROACH and not _mission.miners_beyond_reach \
		and _mission.strength == PackedFloat32Array([100.0, 100.0, 100.0]) \
		and _mission.battle.hero_position == Mission.NERIS_SPAWN \
		and _mission.battle.formations[Mission.STRIKE].position == Mission.STRIKE_SPAWN \
		and _mission.battle.formations[Mission.SCREEN_PARTY].position == Mission.SCREEN_SPAWN, "restart did not fully reset parties and rescue"):
		return false
	_mission.battle.order_move(Mission.STRIKE, _mission._press)
	return _until(func() -> bool: return _mission.phase == Mission.Phase.CONTACT) or _require(false, "restarting did not re-arm strike contact")


func _paths_fit() -> bool:
	for path: Array in [
		[Mission.STRIKE_SPAWN, _mission._press, Mission.STRIKE_TURN, Mission.FALLBACK],
		[Mission.SCREEN_SPAWN, Mission.COVER, Mission.FALLBACK],
		[Mission.NERIS_SPAWN, Mission.FALLBACK],
		Mission.PURSUIT_ROUTE, Array(_mission._escape_path),
	]:
		for index in range(1, path.size()):
			var point: Vector2 = path[index - 1]
			var goal: Vector2 = path[index]
			while point != goal:
				var next := point.move_toward(goal, 0.15)
				if not _mission._terrain.can_move(point, next, true):
					printerr("Blocked segment: %s to %s at %s" % [path[index - 1], goal, next])
					return false
				point = next
	return true


func _tick(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_mission._physics_process(DT)


func _until(done: Callable) -> bool:
	for i in 500:
		if done.call():
			return true
		_mission._physics_process(DT)
	return done.call()


func _require(expected: bool, message: String) -> bool:
	if not expected:
		printerr(message)
		quit(1)
	return expected
