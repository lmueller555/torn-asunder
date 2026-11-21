extends SceneTree

const Objective := preload("res://game/battlefield/mine_escort_objective.gd")
const Phase := Objective.Phase
const Failure := Objective.Failure


func _initialize() -> void:
	var escort_ok := _check_escort()
	var failures_ok := _check_failures()
	var restart_ok := _check_restart()
	var passed := escort_ok and failures_ok and restart_ok
	if passed:
		print("Passed mine escort pickup, delivery, defeat, terminal state and restart checks.")
	quit(0 if passed else 1)


func _check_escort() -> bool:
	var objective := Objective.new()
	var frame := Objective.Observation.new()
	if objective.phase != Phase.AWAITING_PICKUP or objective.failure != Failure.NONE:
		return _fail("The objective did not start with the bridle waiting for pickup.")

	frame.carrier_in_road_exit = true
	frame.interact_pressed = true
	if objective.advance(frame) != Phase.AWAITING_PICKUP:
		return _fail("An exit report or interaction outside the pickup zone triggered pickup.")

	frame.interact_pressed = false
	frame.hero_in_pickup_zone = true
	if objective.advance(frame) != Phase.AWAITING_PICKUP:
		return _fail("Being in the pickup zone without interacting triggered pickup.")

	frame.interact_pressed = true
	if objective.advance(frame) != Phase.ESCORTING:
		return _fail("A valid interaction must start the escort, not complete it.")

	frame = Objective.Observation.new()
	if objective.advance(frame) != Phase.ESCORTING:
		return _fail("An escort without a carrier in the exit did not remain active.")

	frame.carrier_in_road_exit = true
	if objective.advance(frame) != Phase.SUCCEEDED or objective.failure != Failure.NONE:
		return _fail("Moving the carrier into the road exit did not complete the escort.")

	frame.carrier_in_road_exit = false
	frame.hero_incapacitated = true
	frame.bridle_lost = true
	if objective.advance(frame) != Phase.SUCCEEDED or objective.failure != Failure.NONE:
		return _fail("Late failure reports changed a delivered objective.")
	return true


func _check_failures() -> bool:
	for reason: Objective.Failure in [Failure.HERO_INCAPACITATED, Failure.BRIDLE_LOST]:
		for escorting in [false, true]:
			var objective := Objective.new()
			if escorting:
				objective.advance(_pickup_frame())

			var frame := _pickup_frame()
			frame.carrier_in_road_exit = true
			frame.hero_incapacitated = reason == Failure.HERO_INCAPACITATED
			frame.bridle_lost = reason == Failure.BRIDLE_LOST
			if objective.advance(frame) != Phase.FAILED or objective.failure != reason:
				return _fail("A defeat did not supersede pickup or delivery (reason %d)." % reason)

			frame.hero_incapacitated = not frame.hero_incapacitated
			frame.bridle_lost = not frame.bridle_lost
			if objective.advance(frame) != Phase.FAILED or objective.failure != reason:
				return _fail("A late event changed a failed objective or its failure reason.")
	return true


func _check_restart() -> bool:
	var objective := Objective.new()
	var frame := Objective.Observation.new()
	frame.hero_incapacitated = true
	frame.bridle_lost = true
	if objective.advance(frame) != Phase.FAILED or objective.failure != Failure.HERO_INCAPACITATED:
		return _fail("Simultaneous defeat reports did not select a stable reason.")

	objective.restart()
	if objective.phase != Phase.AWAITING_PICKUP or objective.failure != Failure.NONE:
		return _fail("Restart after defeat retained state.")

	objective.advance(_pickup_frame())
	frame = Objective.Observation.new()
	frame.carrier_in_road_exit = true
	if objective.advance(frame) != Phase.SUCCEEDED:
		return _fail("The restarted objective could not be won.")

	objective.restart()
	if objective.advance(frame) != Phase.AWAITING_PICKUP or objective.failure != Failure.NONE:
		return _fail("Restart after victory retained ownership or completion.")
	return true


func _pickup_frame() -> Objective.Observation:
	var frame := Objective.Observation.new()
	frame.interact_pressed = true
	frame.hero_in_pickup_zone = true
	return frame


func _fail(message: String) -> bool:
	push_error(message)
	return false
