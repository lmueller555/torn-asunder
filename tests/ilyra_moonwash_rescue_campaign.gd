extends SceneTree

const Scene := preload("res://game/battlefield/ilyra_moonwash_rescue_campaign.tscn")
const Mission := preload("res://game/battlefield/ilyra_moonwash_rescue_campaign.gd")
const Rescue := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const StockHarbor := preload("res://game/battlefields/moonwash_harbor_campaign.tscn")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const DT := 1.0 / 60.0
const FORE := Rescue.Transfer.FORWARD
const AFT := Rescue.Transfer.AFT
const PIER_ROUTE := ["ReceivingGangway", "PierOuterTurn", "PierInnerTurn", "OpenMooring"]
const STRANDED_ROUTE := ["StrandedAccess", "StrandedDeckGangway"]
const FORE_RIG := "Objectives/ForwardTransfer"
const AFT_RIG := "Objectives/AftTransfer"

var _mission: Mission
var _results: Array[StringName] = []
var _signal_envelopes: Array[AABB] = []
var _signal_overlap_ticks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_cleared.connect(func(result: StringName) -> void: _results.append(result))
	var passed := _check_endpoint_clearance() and _aft_first() and _fore_first_with_cargo() \
		and _check_endpoint_clearance()
	if _signal_overlap_ticks != 0:
		passed = _fail("Rendered rescuers overlapped a solid endpoint in %d drive ticks." % _signal_overlap_ticks)
	_mission.queue_free()
	await process_frame
	if passed:
		print("Campaign Ilyra: physical approach, both rig orders, local Marine screen, actual deck arrivals, optional cargo, retry and independent output passed.")
	quit(0 if passed else 1)


func _check_endpoint_clearance() -> bool:
	_signal_envelopes.clear()
	var stock := StockHarbor.instantiate()
	var ship_path := ^"Geometry/Ships"
	var ships := _mission._field.get_node(ship_path)
	var stock_ships := stock.get_node(ship_path)
	var terrain := _mission._terrain as Terrain
	var space := _mission.get_world_3d().direct_space_state
	var legal := true
	var signals := [[^"ForwardSignal", ^"ForwardReceiverSignal"], [^"AftSignal", ^"AftReceiverSignal"]]
	for transfer in signals.size():
		var offset := Vector3(-1.1 if transfer == FORE else 1.1, 0, 0)
		for path: NodePath in signals[transfer]:
			var body := ships.get_node(path) as StaticBody3D
			var original := stock_ships.get_node(path) as StaticBody3D
			var shape := body.get_node(^"Collision") as CollisionShape3D
			var original_shape := original.get_node(^"Collision") as CollisionShape3D
			var dims: Vector3 = shape.shape.size
			_signal_envelopes.append(shape.global_transform * AABB(-dims*.5, dims))
			if not body.position.is_equal_approx(original.position + offset) or shape.shape != original_shape.shape 					or shape.transform != original_shape.transform or body.basis != original.basis 					or body.get_node(^"Mesh").mesh != original.get_node(^"Mesh").mesh 					or body.get_node(^"Mesh").transform != original.get_node(^"Mesh").transform:
				legal = _fail("Ilyra should translate exactly one existing assembly at %s." % path)
			var center := Vector2(original.position.x, original.position.z)
			var height := terrain.ground_height(center)
			var deck_center := Vector3(center.x, height, center.y)
			var pick: Variant = terrain.destination_from_ray(deck_center + Vector3.UP * 8, deck_center - Vector3.UP)
			var post := body.global_position
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				post + Vector3.UP * 8, post - Vector3.UP, Terrain.SOLID_MASK))
			if not (pick is Vector2 and pick.is_equal_approx(center)) or not terrain.can_move(center + Vector2(0,.08), center, false) 					or terrain.can_move(Vector2(post.x,post.z-.08), Vector2(post.x,post.z), false) 					or hit.is_empty() or hit.collider != body:
				legal = _fail("Clear deck center, walkable-pick and still-solid side post disagree at %s." % path)
		var mid := _mission._routes[transfer][1].lerp(_mission._routes[transfer][2],.5) as Vector3
		if terrain.destination_from_ray(mid + Vector3.UP * 10, mid - Vector3.UP * 6) != null 				or terrain.can_move(Vector2(mid.x,68.78),Vector2(mid.x,69.02),false) 				or terrain.can_move(Vector2(mid.x,82.25),Vector2(mid.x,82.01),false):
			legal = _fail("No endpoint clearance may turn the gap into a hero or command route.")
	stock.free()
	return legal


func _aft_first() -> bool:
	var spawn := _point("Spawns/ElfHero")
	var start_aft := _point("Spawns/AftCrew")
	var start_fore := _point("Spawns/ForwardCrew")
	if _mission._field.name != &"MoonwashHarborCampaign" or _mission.battle.bounds.size != Vector2(288, 242) \
			or not _mission.hero_world_position().is_equal_approx(spawn):
		return _fail("The scene uses neither the shared full harbor nor Ilyra's actual spawn.")
	if _mission._crews[AFT].global_position != start_aft or _mission._crews[FORE].global_position != start_fore:
		return _fail("Both crews should start stranded at their authored markers.")
	_key(KEY_SPACE)
	_tick()
	if _mission.objective.line_is_rigged(FORE) or _mission.objective.line_is_rigged(AFT):
		return _fail("Interacting from the receiving ship prepared a distant rescue line.")
	if not _go_stranded() or not _walk(AFT_RIG):
		return false
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key(KEY_SPACE)
	_joy(JOY_BUTTON_A)
	_tick()
	if _mission.objective.line_is_rigged(AFT):
		return _fail("Command view interacted with the aft hero rig.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_joy(JOY_BUTTON_A)
	_tick()
	if not _mission._lines[AFT].visible or _mission._lines[FORE].visible or _mission._salvage_started:
		return _fail("Ilyra's Cross did not rig only the aft line.")
	if not _wait(func() -> bool: return _state(AFT) == Rescue.CrewStatus.SAFE):
		return false
	if not _crew_on_deck(AFT) or _state(FORE) != Rescue.CrewStatus.STRANDED or not _results.is_empty():
		return _fail("The aft party did not physically land alone.")
	if not _walk(FORE_RIG):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _mission._salvagers.visible or not _mission._lines[FORE].visible:
		return _fail("The fore rig did not show its line and visible mooring pressure event.")
	if not _wait(func() -> bool: return _state(FORE) == Rescue.CrewStatus.PAUSED):
		return false
	if _mission._salvagers.global_position != _point("Routes/OpenMooring") or _crew_on_deck(FORE):
		return _fail("The actual mooring arrival did not pause the fore crew before reaching the deck.")
	var paused_at := _mission._crews[FORE].global_position
	_tick(70)
	if _mission._crews[FORE].global_position != paused_at or not _mission._pressure.text.contains("contested"):
		return _fail("A paused crew advanced without a screen or lacked a readable reason.")
	if not _screen_mooring() or not _wait(func() -> bool: return _mission.objective.outcome == Rescue.Outcome.SUCCEEDED):
		return false
	_tick(10)
	if not _crew_on_deck(FORE) or not _crew_on_deck(AFT) or _results != [Rescue.CREWS_ONLY]:
		return _fail("Both occupied receiving markers did not emit one cargo-free result.")
	_joy(JOY_BUTTON_START)
	if _mission.objective.outcome != Rescue.Outcome.ACTIVE or _mission._lines[FORE].visible \
			or _mission._lines[AFT].visible or _mission._salvagers.visible \
			or not _mission.hero_world_position().is_equal_approx(spawn) \
			or _mission._crews[FORE].global_position != start_fore or _mission._crews[AFT].global_position != start_aft:
		return _fail("Retry retained rescue geometry, crew position or pressure.")
	return true


func _fore_first_with_cargo() -> bool:
	if not _walk_routes(PIER_ROUTE) or not _walk("Objectives/OptionalCargo"):
		return false
	_key(KEY_SPACE)
	_tick()
	if not _mission._cargo_carried or _mission.objective.cargo_recovered:
		return _fail("An optional pickup was credited before actually reaching the receiving deck.")
	var reverse := PIER_ROUTE.duplicate()
	reverse.reverse()
	if not _walk_routes(reverse) or not _walk("Objectives/ReceivingDeck"):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _mission.objective.cargo_recovered or _mission._cargo_carried or _results.size() != 1:
		return _fail("Cargo loading did not remain optional progress without a clear.")
	if not _walk("Routes/ReceivingGangway") or not _go_stranded():
		return false
	_key(KEY_SPACE)
	_tick()
	if not _mission.objective.line_is_rigged(FORE) or _mission.objective.line_is_rigged(AFT):
		return _fail("Retry could not choose the fore rig first.")
	if not _walk(AFT_RIG):
		return false
	_joy(JOY_BUTTON_A)
	_tick()
	if not _wait(func() -> bool: return _state(AFT) == Rescue.CrewStatus.SAFE):
		return false
	if _state(FORE) != Rescue.CrewStatus.PAUSED or not _crew_on_deck(AFT) or _results.size() != 1:
		return _fail("Pressure on the fore lane prevented the independent aft crew from boarding.")
	if not _screen_mooring() or not _wait(func() -> bool: return _mission.objective.outcome == Rescue.Outcome.SUCCEEDED):
		return false
	if not _crew_on_deck(FORE) or not _crew_on_deck(AFT) or _results != [Rescue.CREWS_ONLY, Rescue.CARGO_RECOVERED]:
		return _fail("The fore-first retry did not award the actual cargo recovery on crew arrival.")
	_key(KEY_BACKSPACE)
	return (not _mission._cargo_carried and not _mission.objective.cargo_recovered
		and _mission._cargo.global_position == _point("Objectives/OptionalCargo")) or _fail("Retry retained optional cargo.")


func _go_stranded() -> bool:
	return _walk_routes(PIER_ROUTE) and _walk_routes(STRANDED_ROUTE) and _walk(FORE_RIG)


func _screen_mooring() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	if _mission.selected_index == 0:
		_joy(JOY_BUTTON_DPAD_RIGHT)
	var target := _point("Routes/OpenMooring")
	_mission.cursor = _local_xz(target)
	_joy(JOY_BUTTON_X)
	var marines: Battle.Formation = _mission.battle.formations[Mission.MARINES]
	if marines.order != Battle.Order.MOVE or not _wait(func() -> bool: return marines.position.distance_to(_mission.cursor) < Mission.SCREEN_RADIUS - 0.4):
		return _fail("The physical Marine platoon did not walk to the mooring.")
	if not _mission._forward_contested():
		return _fail("A moving platoon opened the lane without a Hold order.")
	_joy(JOY_BUTTON_A)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return (marines.order == Battle.Order.HOLD and not _mission._forward_contested()
		and _state(FORE) != Rescue.CrewStatus.PAUSED) or _fail("An actual Hold did not restart the fore transfer.")


func _crew_on_deck(group: Rescue.Transfer) -> bool:
	var receiver := _point("Objectives/ForwardReceiver" if group == FORE else "Objectives/AftReceiver")
	return _mission._crews[group].global_position.is_equal_approx(receiver)


func _state(group: Rescue.Transfer) -> Rescue.CrewStatus:
	return _mission.objective.crew_status(group)


func _walk_routes(route: Array) -> bool:
	for path: String in route:
		if not _walk("Routes/" + path):
			return false
	return true


func _walk(path: String) -> bool:
	var point := _point(path)
	var target := _local_xz(point)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 120
	for _step in range(budget):
		var remaining := target - _mission.battle.hero_position
		if remaining.length() < 0.12:
			break
		var move := remaining.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, move.x)
		_axis(JOY_AXIS_LEFT_Y, move.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return _mission.hero_world_position().distance_to(point) < 0.14 \
		or _fail("Ilyra could not physically walk to %s from %s." % [path, _mission.hero_world_position()])


func _wait(condition: Callable) -> bool:
	for _step in range(1900):
		if condition.call():
			return true
		_tick()
	return _fail("Expected crew or screen event never occurred.")


func _local_xz(point: Vector3) -> Vector2:
	var local := _mission.to_local(point)
	return Vector2(local.x, local.z)


func _point(path: String) -> Vector3:
	return _mission.battlefield_marker(NodePath("Markers/" + path)).global_position


func _tick(count := 1) -> void:
	for _step in range(count):
		_mission._physics_process(DT)
		_detect_signal_overlap()


func _detect_signal_overlap() -> void:
	if _signal_envelopes.size() != 4:
		return
	for transfer in [FORE,AFT]:
		if not _mission.objective.line_is_rigged(transfer):
			continue
		var party := _mission._crews[transfer]
		var z := party.global_position.z
		if z < 65.5 or z > 84.7:
			continue
		for child in party.get_children():
			if child is MeshInstance3D:
				var envelope: AABB = child.global_transform * child.mesh.get_aabb()
				if envelope.intersects(_signal_envelopes[transfer*2]) or envelope.intersects(_signal_envelopes[transfer*2+1]):
					_signal_overlap_ticks += 1
					break


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
