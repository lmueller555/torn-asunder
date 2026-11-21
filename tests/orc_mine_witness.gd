extends SceneTree

const Objective := preload("res://game/battlefield/orc_mine_witness.gd")
const Phase := Objective.Phase
const Failure := Objective.Failure


func _initialize() -> void:
	var escort_ok := _check_voluntary_escort()
	var failures_ok := _check_defeat()
	var passed := escort_ok and failures_ok
	if passed:
		print("Verified voluntary terms, waiting for the workers, recoverable blockage, actual witness delivery, and restart.")
	quit(0 if passed else 1)


func _check_voluntary_escort() -> bool:
	var objective := Objective.new()
	var frame := Objective.Observation.new()
	frame.raska_accepts_terms = true
	frame.witness_at_orc_rally = true
	if objective.advance(frame) != Phase.WAITING_FOR_OFFER:
		return _fail("Interaction or rally arrival bypassed the witness's offer.")

	frame.outlet_blocked = true
	frame.witness_offers_terms = true
	if objective.advance(frame) != Phase.WAITING_FOR_OFFER:
		return _fail("The blocked outlet opened negotiations.")
	frame.outlet_blocked = false
	frame.last_escape_window_closes = true
	if objective.advance(frame) != Phase.TERMS_OFFERED:
		return _fail("A clear outlet at the close should allow the offer but not skip consent.")

	frame = Objective.Observation.new()
	frame.outlet_blocked = true
	frame.raska_accepts_terms = true
	if objective.advance(frame) != Phase.TERMS_OFFERED:
		return _fail("A temporarily blocked outlet let Raska accept the terms.")
	frame.outlet_blocked = false
	frame.raska_accepts_terms = false
	if objective.advance(frame) != Phase.TERMS_OFFERED:
		return _fail("An interaction from before the outlet reopened was queued.")
	frame.raska_accepts_terms = true
	if objective.advance(frame) != Phase.WAITING_FOR_WORKERS:
		return _fail("Raska could not accept the witness's offer with a clear outlet.")

	frame = Objective.Observation.new()
	frame.witness_at_orc_rally = true
	if objective.advance(frame) != Phase.WAITING_FOR_WORKERS:
		return _fail("A rally report bypassed the other workers' escape.")
	frame.other_workers_clear = true
	frame.outlet_blocked = true
	if objective.advance(frame) != Phase.WAITING_FOR_WORKERS:
		return _fail("The witness departed through the blocked outlet.")
	frame.outlet_blocked = false
	if objective.advance(frame) != Phase.ESCORTING:
		return _fail("The witness did not start following Raska after the others were clear.")

	frame = Objective.Observation.new()
	if objective.advance(frame) != Phase.ESCORTING:
		return _fail("The escort ended without a valid witness arrival.")
	frame.witness_at_orc_rally = true
	if objective.advance(frame) != Phase.SUCCEEDED or objective.failure != Failure.NONE:
		return _fail("The willing witness did not complete the escort at the rally.")
	frame.witness_lost = true
	if objective.advance(frame) != Phase.SUCCEEDED:
		return _fail("A late witness loss changed a completed mission.")
	objective.restart()
	if objective.phase != Phase.WAITING_FOR_OFFER or objective.failure != Failure.NONE:
		return _fail("Restart retained a completed mission.")
	return true


func _check_defeat() -> bool:
	for expected in [Failure.RASKA_FELL, Failure.WITNESS_LOST, Failure.OUTLET_WINDOW_CLOSED]:
		var objective := Objective.new()
		var frame := Objective.Observation.new()
		frame.witness_offers_terms = true
		objective.advance(frame)
		frame.raska_accepts_terms = true
		objective.advance(frame)
		frame.other_workers_clear = true
		objective.advance(frame)

		frame = Objective.Observation.new()
		frame.witness_at_orc_rally = true
		frame.raska_fell = expected == Failure.RASKA_FELL
		frame.witness_lost = expected == Failure.WITNESS_LOST
		frame.outlet_blocked = expected == Failure.OUTLET_WINDOW_CLOSED
		frame.last_escape_window_closes = frame.outlet_blocked
		if objective.advance(frame) != Phase.FAILED or objective.failure != expected:
			return _fail("A same-tick loss did not take precedence (reason %d)." % expected)
		frame = Objective.Observation.new()
		frame.witness_at_orc_rally = true
		if objective.advance(frame) != Phase.FAILED or objective.failure != expected:
			return _fail("A later rally report erased a defeat.")
		objective.restart()
		if objective.phase != Phase.WAITING_FOR_OFFER or objective.failure != Failure.NONE:
			return _fail("Restart retained a failure.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
