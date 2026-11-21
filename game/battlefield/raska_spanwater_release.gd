extends RefCounted
## Objective rules for River, Not Sea. The battlefield owns control, flow and actor observations.

signal lower_towns_withdrawal_ordered
signal high_bank_unlocked

const MISSION_ID := &"orc_spanwater_release"
const SPILLWAY_WHEEL := ^"Markers/Objectives/SpillwayWheel"
const HIGH_BANK_EXIT := ^"Markers/Objectives/HighBankExit"

enum Phase { SECURE_SPILLWAY, READY_AT_WHEEL, RELEASING, PAUSED, EXTRACT, SUCCEEDED, FAILED }
enum WheelControl { UNSECURED, SECURED, CONTESTED }
enum Failure { NONE, RASKA_FELL, SPILLWAY_SHUT }


class Observation:
	## Secured means the Orcs hold the wheel and no defender is contesting it.
	var wheel_control := WheelControl.UNSECURED
	## A new interact by Raska himself at the authorized spillway wheel.
	var raska_opens_spillway := false
	## New, confirmed release advancement in normalized units; 1.0 is river stage.
	## The battlefield must supply only new credit, not time or total water level.
	var river_credit := 0.0
	## The battlefield confirmed that defenders physically shut the spillway.
	## Contest or enemy presence alone is never confirmation.
	var shutdown_confirmed := false
	## Raska himself reached the high-bank exit, not a troop formation.
	var raska_at_high_bank := false
	var raska_fell := false


var phase: Phase:
	get:
		return _phase

var failure: Failure:
	get:
		return _failure

var release_progress: float:
	get:
		return _release_progress

## True once the order has been published. Unit withdrawal and selection are scene effects.
var withdrawal_ordered: bool:
	get:
		return _withdrawal_ordered

var _phase := Phase.SECURE_SPILLWAY
var _failure := Failure.NONE
var _release_progress := 0.0
var _withdrawal_ordered := false


## Failures take precedence over progress reported on the same tick.
func advance(observation: Observation) -> Phase:
	if _phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return _phase
	if observation.raska_fell:
		return _fail(Failure.RASKA_FELL)
	if _phase in [Phase.RELEASING, Phase.PAUSED] and observation.shutdown_confirmed:
		return _fail(Failure.SPILLWAY_SHUT)

	var secured := observation.wheel_control == WheelControl.SECURED
	match _phase:
		Phase.SECURE_SPILLWAY:
			if secured:
				_phase = Phase.READY_AT_WHEEL
		Phase.READY_AT_WHEEL:
			if not secured:
				_phase = Phase.SECURE_SPILLWAY
			elif observation.raska_opens_spillway:
				_phase = Phase.RELEASING
				_withdrawal_ordered = true
				lower_towns_withdrawal_ordered.emit()
		Phase.RELEASING, Phase.PAUSED:
			if not secured:
				_phase = Phase.PAUSED
			else:
				_phase = Phase.RELEASING
				if is_finite(observation.river_credit) and observation.river_credit > 0.0:
					_release_progress = minf(1.0, _release_progress + observation.river_credit)
				if is_equal_approx(_release_progress, 1.0):
					_release_progress = 1.0
					_phase = Phase.EXTRACT
					high_bank_unlocked.emit()
		Phase.EXTRACT:
			if observation.raska_at_high_bank:
				_phase = Phase.SUCCEEDED
	return _phase


func restart() -> void:
	_phase = Phase.SECURE_SPILLWAY
	_failure = Failure.NONE
	_release_progress = 0.0
	_withdrawal_ordered = false


func _fail(reason: Failure) -> Phase:
	_failure = reason
	_phase = Phase.FAILED
	return _phase
