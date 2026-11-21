extends SceneTree

const Map := preload("res://game/battlefields/cairnspine_vault_road.tscn")
const Return := preload("res://game/battlefield/sova_vault_return.gd")
const Phase := Return.Phase
const Pause := Return.PauseReason
const Failure := Return.Failure


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fresh := _check_fresh_interact()
	var approaches := _check_route_independence()
	var recovery := _check_recovery()
	var defeat := _check_defeat()
	var passed := fresh and approaches and recovery and defeat
	if passed:
		print("Verified fresh vault interaction, shared route-neutral closure, contest and retreat recovery, and defeat/retry.")
	quit(0 if passed else 1)


func _check_fresh_interact() -> bool:
	var mission := Return.new()
	var frame := Return.Observation.new()
	frame.return_pressed = true
	frame.closure_credit = 1.0
	if mission.advance(frame) != Phase.CARRYING:
		return _fail("Early interaction away from the actual vault started closure.")

	frame.sova_in_closure_zone = true
	frame.sova_at_return_marker = true
	frame.return_pressed = false
	if mission.advance(frame) != Phase.CARRYING or mission.closure_progress != 0.0:
		return _fail("Arriving at the vault queued the earlier interaction.")

	frame.return_pressed = true
	frame.sova_has_bridle = false
	if mission.advance(frame) != Phase.CARRYING:
		return _fail("An invalid carrier started closure.")
	frame.sova_has_bridle = true
	frame.hostile_in_closure_zone = true
	if mission.advance(frame) != Phase.CARRYING:
		return _fail("Contested interaction armed closure.")
	frame.hostile_in_closure_zone = false
	frame.return_pressed = false
	if mission.advance(frame) != Phase.CARRYING:
		return _fail("Clearing hostile pressure queued a rejected interaction.")

	frame.return_pressed = true
	frame.sova_at_return_marker = false
	if mission.advance(frame) != Phase.CARRYING:
		return _fail("Being inside the zone away from the vault prompt was enough to start.")
	return true


func _check_route_independence() -> bool:
	var map := Map.instantiate() as Node3D
	root.add_child(map)
	map.position = Vector3(12, 4, -7)
	var return_marker := map.get_node(Return.RETURN_MARKER) as Marker3D
	var zone := map.get_node(Return.CLOSURE_ZONE) as Marker3D
	var dimensions: Vector3 = zone.get_meta(&"box_size")
	var bounds := AABB(zone.global_position - dimensions * 0.5, dimensions)
	var witness_terrace := map.get_node(^"Markers/Objectives/WitnessTerrace") as Marker3D
	var routes := {
		"shelf": ["ShelfDecision", "ShelfHold", "ShelfRejoin", "Forecourt"],
		"side path": ["SideDecision", "SideBlindBend", "SideRejoin", "Forecourt"],
	}
	for approach: String in routes:
		var mission := Return.new()
		var frame := Return.Observation.new()
		# No civilian visits or other campaigns are reported by either trace.
		_report_position(frame, witness_terrace.global_position, return_marker.global_position, bounds)
		frame.return_pressed = true
		frame.closure_credit = 1.0
		if mission.advance(frame) != Phase.CARRYING:
			return _fail("The separate witness terrace accidentally started the vault return.")
		frame.return_pressed = false
		for id: String in routes[approach]:
			var point := map.get_node(NodePath("Markers/Routes/" + id)) as Marker3D
			_report_position(frame, point.global_position, return_marker.global_position, bounds)
			if mission.advance(frame) != Phase.CARRYING or mission.closure_progress != 0.0:
				return _fail("The %s waypoint %s started closure early." % [approach, id])
		_report_position(frame, return_marker.global_position, return_marker.global_position, bounds)
		frame.return_pressed = true
		frame.closure_credit = 0.45
		if mission.advance(frame) != Phase.RETURNING:
			return _fail("The %s could not start the same legal return." % approach)
		frame.return_pressed = false
		frame.closure_credit = 0.55
		if mission.advance(frame) != Phase.SUCCEEDED or mission.closure_progress != 1.0:
			return _fail("The %s could not clear without a witness or another campaign." % approach)
		frame.sova_fell = true
		frame.hostile_in_closure_zone = true
		if mission.advance(frame) != Phase.SUCCEEDED:
			return _fail("A later hostile event replaced a confirmed vault return.")
		mission.restart()
		if not _check_reset(mission):
			return false
	map.queue_free()
	return true


func _report_position(frame: Return.Observation, feet: Vector3, prompt: Vector3, bounds: AABB) -> void:
	frame.sova_in_closure_zone = bounds.has_point(feet + Vector3.UP * 0.8)
	frame.sova_at_return_marker = feet.distance_to(prompt) <= 1.8


func _check_recovery() -> bool:
	var mission := Return.new()
	var frame := _at_prompt()
	frame.closure_credit = 0.35
	mission.advance(frame)
	frame.return_pressed = false
	frame.hostile_in_closure_zone = true
	frame.closure_credit = 1.0
	for _step in range(1000):
		mission.advance(frame)
	if mission.phase != Phase.PAUSED or mission.pause_reason != Pause.CONTESTED or not is_equal_approx(mission.closure_progress, 0.35):
		return _fail("A long contest timed out or changed actual closure progress.")
	frame.hostile_in_closure_zone = false
	frame.closure_credit = 0.15
	if mission.advance(frame) != Phase.RETURNING or not is_equal_approx(mission.closure_progress, 0.5):
		return _fail("Clearing opposition did not resume the same authorized return.")

	frame.sova_in_closure_zone = false
	frame.sova_at_return_marker = false
	if mission.advance(frame) != Phase.PAUSED or mission.pause_reason != Pause.CARRIER_AWAY:
		return _fail("Retreat allowed off-zone closure credit.")
	frame = _at_prompt()
	frame.return_pressed = false
	frame.closure_credit = 1.0
	if mission.advance(frame) != Phase.PAUSED or mission.pause_reason != Pause.RETURN_INTERACTION_REQUIRED:
		return _fail("Re-entry without a fresh interaction resumed the retreating carrier's return.")
	frame.return_pressed = true
	frame.sova_has_bridle = false
	if mission.advance(frame) != Phase.PAUSED or mission.pause_reason != Pause.BRIDLE_ABSENT:
		return _fail("A temporary lack of carriage advanced closure or caused defeat.")
	frame.sova_has_bridle = true
	frame.closure_credit = NAN
	if mission.advance(frame) != Phase.RETURNING or not is_equal_approx(mission.closure_progress, 0.5):
		return _fail("A valid re-engagement did not restore closure, or invalid effort advanced it.")
	frame.return_pressed = false
	frame.closure_credit = 0.5
	if mission.advance(frame) != Phase.SUCCEEDED:
		return _fail("Resuming after retreat could not complete the vault return.")
	return true


func _check_defeat() -> bool:
	var mission := Return.new()
	var frame := _at_prompt()
	frame.closure_credit = 0.75
	mission.advance(frame)
	frame.return_pressed = false
	frame.closure_credit = 0.25
	frame.sova_fell = true
	if mission.advance(frame) != Phase.FAILED or mission.failure != Failure.SOVA_FELL or mission.closure_progress >= 1.0:
		return _fail("A falling carrier did not lose before the same-tick final closure.")
	if mission.advance(_at_prompt()) != Phase.FAILED:
		return _fail("A terminal defeat restarted without retry.")
	mission.restart()
	return _check_reset(mission)


func _at_prompt() -> Return.Observation:
	var frame := Return.Observation.new()
	frame.sova_in_closure_zone = true
	frame.sova_at_return_marker = true
	frame.return_pressed = true
	return frame


func _check_reset(mission: Return) -> bool:
	if mission.phase != Phase.CARRYING or mission.closure_progress != 0.0 			or mission.pause_reason != Pause.NONE or mission.failure != Failure.NONE:
		return _fail("Restart retained vault progress or an old outcome.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
