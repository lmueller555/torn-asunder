extends SceneTree

const Objective := preload("res://game/battlefield/mine_escort_objective.gd")
const Phase := Objective.Phase
const Failure := Objective.Failure


func _initialize() -> void:
	var escort_ok := _check_escort()
	var failures_ok := _check_failures()
	var restart_ok := _check_restart()
	var interception_ok := _check_interception()
	var interception_priority_ok := _check_interception_priority()
	var passed := escort_ok and failures_ok and restart_ok and interception_ok and interception_priority_ok
	if passed:
		print("Passed mine escort pickup, delivery, defeat, interception, terminal state and restart checks.")
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


func _check_interception() -> bool:
	var objective := Objective.new()
	var requests: Array[bool] = []
	objective.interception_requested.connect(func() -> void: requests.append(true))
	var approach := Objective.Observation.new()
	approach.carrier_in_interception_approach = true
	for tick in range(90):
		if objective.advance(approach) != Phase.AWAITING_PICKUP or not requests.is_empty():
			return _fail("The approach requested an interception before actual pickup.")
	var pickup := _pickup_frame()
	pickup.carrier_in_interception_approach = true
	if objective.advance(pickup) != Phase.ESCORTING or objective.interception_triggered or not requests.is_empty():
		return _fail("The pickup frame also requested an interception.")
	var outside := Objective.Observation.new()
	for tick in range(90):
		objective.advance(outside)
	if objective.interception_triggered or not requests.is_empty():
		return _fail("Waiting with the bridle outside the approach requested an interception.")
	if objective.advance(approach) != Phase.ESCORTING or not objective.interception_triggered or requests != [true]:
		return _fail("The carrier entering the approach did not request one non-terminal interception.")
	objective.advance(approach)
	objective.advance(outside)
	objective.advance(approach)
	if requests != [true] or not objective.interception_triggered:
		return _fail("Holding or re-entering the approach repeated the interception.")
	objective.restart()
	if objective.interception_triggered or objective.advance(approach) != Phase.AWAITING_PICKUP:
		return _fail("Restart retained the old trigger or pickup.")
	objective.advance(_pickup_frame())
	if objective.advance(approach) != Phase.ESCORTING or requests != [true, true]:
		return _fail("Retry did not allow one fresh interception after pickup.")
	approach.carrier_in_road_exit = true
	if objective.advance(approach) != Phase.SUCCEEDED or requests != [true, true]:
		return _fail("Delivery after interception required another event or repeated the warning.")
	return true


func _check_interception_priority() -> bool:
	for terminal_reason: Objective.Failure in [Failure.NONE, Failure.HERO_INCAPACITATED, Failure.BRIDLE_LOST]:
		var objective := Objective.new()
		var requests: Array[bool] = []
		objective.interception_requested.connect(func() -> void: requests.append(true))
		objective.advance(_pickup_frame())
		var frame := Objective.Observation.new()
		frame.carrier_in_interception_approach = true
		frame.carrier_in_road_exit = true
		frame.hero_incapacitated = terminal_reason == Failure.HERO_INCAPACITATED
		frame.bridle_lost = terminal_reason == Failure.BRIDLE_LOST
		var expected := Phase.SUCCEEDED if terminal_reason == Failure.NONE else Phase.FAILED
		if objective.advance(frame) != expected or objective.failure != terminal_reason:
			return _fail("An approach report changed terminal priority or became a delivery requirement.")
		objective.advance(frame)
		if not requests.is_empty() or objective.interception_triggered:
			return _fail("A fresh interception fired on or after a terminal frame.")
	return true


func _pickup_frame() -> Objective.Observation:
	var frame := Objective.Observation.new()
	frame.interact_pressed = true
	frame.hero_in_pickup_zone = true
	return frame


func _fail(message: String) -> bool:
	push_error(message)
	return false
