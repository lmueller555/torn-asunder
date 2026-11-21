extends SceneTree

const Grove := preload("res://game/battlefield/neris_failing_grove.gd")
const Phase := Grove.Phase
const Interruption := Grove.Interruption
const Failure := Grove.Failure


func _initialize() -> void:
	var passed := _check_gates()
	passed = _check_recoverable_pressure() and passed
	passed = _check_terminal_and_retry() and passed
	if passed:
		print("Verified envoy, volunteer loading, recoverable pressures, sled delivery, transplant, and retry.")
	quit(0 if passed else 1)


func _check_gates() -> bool:
	var model := Grove.new()
	var noise := Grove.Observation.new()
	noise.volunteers_called = true
	noise.loading_credit = 1.0
	noise.sled_at_nursery = true
	noise.transplant_interaction_confirmed = true
	if model.advance(noise) != Phase.AWAITING_ENVOY:
		return _fail("Premature work, arrival, or transplant bypassed the envoy.")
	noise.envoy_interaction_confirmed = true
	if model.advance(noise) != Phase.AWAITING_VOLUNTEERS or model.loading_progress != 0.0:
		return _fail("Speaking with the envoy processed a future volunteer or loading report.")
	noise = Grove.Observation.new()
	noise.loading_credit = 1.0
	if model.advance(noise) != Phase.AWAITING_VOLUNTEERS:
		return _fail("A stale call was retained instead of requiring a new interaction.")
	noise.volunteers_called = true
	if model.advance(noise) != Phase.LOADING or model.loading_progress != 0.0:
		return _fail("The volunteer call skipped the separate loading stage.")
	noise.sled_at_nursery = true
	noise.transplant_interaction_confirmed = true
	if model.advance(noise) != Phase.ESCORTING:
		return _fail("The loading tick also confirmed arrival or transplant.")
	if model.advance(Grove.Observation.new()) != Phase.ESCORTING:
		return _fail("A premature nursery report was remembered after loading.")
	if model.advance(noise) != Phase.AWAITING_TRANSPLANT:
		return _fail("Sled arrival also applied a premature transplant interaction.")
	noise.sled_at_nursery = false
	if model.advance(noise) != Phase.AWAITING_TRANSPLANT:
		return _fail("A hero-only transplant completed without the sled currently present.")
	noise.sled_at_nursery = true
	noise.transplant_interaction_confirmed = false
	if model.advance(noise) != Phase.AWAITING_TRANSPLANT:
		return _fail("Physical arrival won without a fresh transplant interaction.")
	noise.transplant_interaction_confirmed = true
	return model.advance(noise) == Phase.SUCCEEDED or _fail("A valid nursery transplant did not win.")


func _check_recoverable_pressure() -> bool:
	var model := Grove.new()
	_start_loading(model)
	for tick in range(120):
		model.advance(Grove.Observation.new())
	if model.phase != Phase.LOADING or model.loading_progress != 0.0:
		return _fail("Idle ticks performed or timed out the loading task.")
	var frame := Grove.Observation.new()
	for malformed in [INF, NAN, -1.0]:
		frame.loading_credit = malformed
		model.advance(frame)
	if model.loading_progress != 0.0:
		return _fail("Invalid loading credit changed the loading progress.")
	frame.loading_credit = 0.4
	model.advance(frame)
	frame.yard_contested = true
	frame.loading_credit = 1.0
	for tick in range(120):
		model.advance(frame)
	if model.phase != Phase.LOADING or model.interruption != Interruption.YARD_CONTESTED or not is_equal_approx(model.loading_progress, 0.4):
		return _fail("Yard pressure advanced or reset work instead of pausing it.")
	frame.yard_contested = false
	frame.loading_credit = 0.6
	if model.advance(frame) != Phase.ESCORTING or model.interruption != Interruption.NONE or model.loading_progress != 1.0:
		return _fail("Clearing the yard did not resume the existing work.")
	frame = Grove.Observation.new()
	frame.sled_route_contested = true
	frame.sled_at_nursery = true
	if model.advance(frame) != Phase.ESCORTING or model.interruption != Interruption.SLED_ROUTE_CONTESTED:
		return _fail("A blocked sled counted as a nursery delivery.")
	frame.sled_route_contested = false
	if model.advance(frame) != Phase.AWAITING_TRANSPLANT or model.interruption != Interruption.NONE:
		return _fail("Clearing the sled's route did not allow an intact arrival.")
	frame.nursery_contested = true
	frame.transplant_interaction_confirmed = true
	if model.advance(frame) != Phase.AWAITING_TRANSPLANT or model.interruption != Interruption.NURSERY_CONTESTED:
		return _fail("Pressure at the nursery caused a win or defeat instead of an interruption.")
	frame.nursery_contested = false
	frame.transplant_interaction_confirmed = false
	if model.advance(frame) != Phase.AWAITING_TRANSPLANT or model.interruption != Interruption.NONE:
		return _fail("A blocked transplant was queued and executed without a fresh interaction.")
	frame.transplant_interaction_confirmed = true
	return model.advance(frame) == Phase.SUCCEEDED or _fail("The recovered transplant did not succeed.")


func _check_terminal_and_retry() -> bool:
	for reason: Grove.Failure in [Failure.NONE, Failure.NERIS_FELL, Failure.SLED_DESTROYED]:
		var model := Grove.new()
		_start_loading(model)
		var frame := Grove.Observation.new()
		frame.loading_credit = 1.5
		model.advance(frame)
		frame = Grove.Observation.new()
		frame.sled_at_nursery = true
		model.advance(frame)
		frame.transplant_interaction_confirmed = true
		frame.neris_fell = reason == Failure.NERIS_FELL
		frame.sled_definitively_destroyed = reason != Failure.NONE
		var outcome := Phase.SUCCEEDED if reason == Failure.NONE else Phase.FAILED
		if model.advance(frame) != outcome or model.failure != reason:
			return _fail("A terminal conflict did not preserve defeat precedence.")
		frame.neris_fell = not frame.neris_fell
		frame.sled_definitively_destroyed = not frame.sled_definitively_destroyed
		if model.advance(frame) != outcome or model.failure != reason:
			return _fail("A late observation changed a terminal result.")
		model.restart()
		if model.phase != Phase.AWAITING_ENVOY or model.failure != Failure.NONE or model.interruption != Interruption.NONE or model.loading_progress != 0.0:
			return _fail("Retry retained stage, failure, pressure, or root-loading progress.")
		if model.advance(Grove.Observation.new()) != Phase.AWAITING_ENVOY:
			return _fail("Retry resumed the old escort rather than waiting for the envoy.")
	return true


func _start_loading(model: Grove) -> void:
	var frame := Grove.Observation.new()
	frame.envoy_interaction_confirmed = true
	model.advance(frame)
	frame = Grove.Observation.new()
	frame.volunteers_called = true
	model.advance(frame)


func _fail(message: String) -> bool:
	push_error(message)
	return false
