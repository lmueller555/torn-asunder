extends RefCounted
## Objective rules for No New Command. Neither route nor the witness terrace owns closure.

const MISSION_ID := &"sova_vault_return"
const RETURN_MARKER := ^"Markers/Objectives/BridleReturn"
const CLOSURE_ZONE := ^"Markers/PhaseZones/VaultClosure"

enum Phase { CARRYING, RETURNING, PAUSED, SUCCEEDED, FAILED }
enum PauseReason { NONE, CONTESTED, CARRIER_AWAY, BRIDLE_ABSENT, RETURN_INTERACTION_REQUIRED }
enum Failure { NONE, SOVA_FELL }


class Observation:
	## Sova is the sole carrier and begins with the bridle.
	var sova_has_bridle := true
	var sova_in_closure_zone := false
	## Reaching the forecourt is not a valid return interaction.
	var sova_at_return_marker := false
	## A fresh interaction edge this tick, never queued while invalid.
	var return_pressed := false
	## Only a hostile inside the marked zone contests closure.
	var hostile_in_closure_zone := false
	## New closure effort this tick in normalized units, not a countdown.
	var closure_credit := 0.0
	var sova_fell := false


var phase: Phase:
	get:
		return _phase

var pause_reason: PauseReason:
	get:
		return _pause_reason

var failure: Failure:
	get:
		return _failure

var closure_progress: float:
	get:
		return _closure_progress

var _phase := Phase.CARRYING
var _pause_reason := PauseReason.NONE
var _failure := Failure.NONE
var _closure_progress := 0.0
var _requires_interaction := true


## Confirmed hero defeat wins against a would-be final closure on the same tick.
func advance(observation: Observation) -> Phase:
	if _phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return _phase
	if observation.sova_fell:
		_failure = Failure.SOVA_FELL
		_pause_reason = PauseReason.NONE
		_phase = Phase.FAILED
		return _phase

	if _phase == Phase.CARRYING and not _can_start(observation):
		return _phase
	if not observation.sova_has_bridle:
		_requires_interaction = true
		return _pause(PauseReason.BRIDLE_ABSENT)
	if not observation.sova_in_closure_zone:
		_requires_interaction = true
		return _pause(PauseReason.CARRIER_AWAY)
	if observation.hostile_in_closure_zone:
		return _pause(PauseReason.CONTESTED)
	if _requires_interaction:
		if not _can_start(observation):
			return _pause(PauseReason.RETURN_INTERACTION_REQUIRED)
		_requires_interaction = false

	_phase = Phase.RETURNING
	_pause_reason = PauseReason.NONE
	if is_finite(observation.closure_credit) and observation.closure_credit > 0.0:
		_closure_progress = minf(_closure_progress + observation.closure_credit, 1.0)
		if is_equal_approx(_closure_progress, 1.0):
			_closure_progress = 1.0
			_phase = Phase.SUCCEEDED
	return _phase


func restart() -> void:
	_phase = Phase.CARRYING
	_pause_reason = PauseReason.NONE
	_failure = Failure.NONE
	_closure_progress = 0.0
	_requires_interaction = true


func _can_start(observation: Observation) -> bool:
	return observation.return_pressed and observation.sova_has_bridle 		and observation.sova_in_closure_zone and observation.sova_at_return_marker 		and not observation.hostile_in_closure_zone


func _pause(reason: PauseReason) -> Phase:
	_pause_reason = reason
	_phase = Phase.PAUSED
	return _phase
