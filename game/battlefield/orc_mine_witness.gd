extends RefCounted
## Objective rules for One Person to Ask. World checks and the closing window come from the battlefield.

const MISSION_ID := &"orc_mine_witness"

enum Phase { WAITING_FOR_OFFER, TERMS_OFFERED, WAITING_FOR_WORKERS, ESCORTING, SUCCEEDED, FAILED }
enum Failure { NONE, RASKA_FELL, WITNESS_LOST, OUTLET_WINDOW_CLOSED }


class Observation:
	## The willing witness has reached the outlet and is offering her terms.
	var witness_offers_terms := false
	## A valid interaction by Raska with the witness; never a formation order.
	var raska_accepts_terms := false
	## The remaining workers cleared the outlet toward Druid safety.
	var other_workers_clear := false
	## The witness herself has reached the Orc rally, not just Raska.
	var witness_at_orc_rally := false
	var outlet_blocked := false
	## True on the tick the announced final escape window closes.
	var last_escape_window_closes := false
	var raska_fell := false
	var witness_lost := false


var phase: Phase:
	get:
		return _phase

var failure: Failure:
	get:
		return _failure

var _phase := Phase.WAITING_FOR_OFFER
var _failure := Failure.NONE


## Losses take precedence over progress reported on the same tick.
func advance(observation: Observation) -> Phase:
	if _phase == Phase.SUCCEEDED or _phase == Phase.FAILED:
		return _phase
	if observation.raska_fell:
		return _fail(Failure.RASKA_FELL)
	if observation.witness_lost:
		return _fail(Failure.WITNESS_LOST)
	if observation.outlet_blocked and observation.last_escape_window_closes:
		return _fail(Failure.OUTLET_WINDOW_CLOSED)

	match _phase:
		Phase.WAITING_FOR_OFFER:
			if observation.witness_offers_terms and not observation.outlet_blocked:
				_phase = Phase.TERMS_OFFERED
		Phase.TERMS_OFFERED:
			if observation.raska_accepts_terms and not observation.outlet_blocked:
				_phase = Phase.WAITING_FOR_WORKERS
		Phase.WAITING_FOR_WORKERS:
			if observation.other_workers_clear and not observation.outlet_blocked:
				_phase = Phase.ESCORTING
		Phase.ESCORTING:
			if observation.witness_at_orc_rally:
				_phase = Phase.SUCCEEDED
	return _phase


func restart() -> void:
	_phase = Phase.WAITING_FOR_OFFER
	_failure = Failure.NONE


func _fail(reason: Failure) -> Phase:
	_failure = reason
	_phase = Phase.FAILED
	return _phase
