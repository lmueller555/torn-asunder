extends RefCounted
## Tracks the Humans' Godbridle objective independently of the map and combat.

## Request the warning/advance once; never a requirement for delivering the bridle.
signal interception_requested

enum Phase { AWAITING_PICKUP, ESCORTING, SUCCEEDED, FAILED }
enum Failure { NONE, HERO_INCAPACITATED, BRIDLE_LOST }


class Observation:
	## True only on the frame the hero requests an objective interaction.
	var interact_pressed := false
	var hero_in_pickup_zone := false
	## Only the current allied carrier of the Godbridle can trigger the exit.
	var carrier_in_road_exit := false
	## The living allied carrier is on the map's visible interception approach.
	var carrier_in_interception_approach := false
	var hero_incapacitated := false
	## Set once the bridle is definitively lost, not just dropped or contested.
	var bridle_lost := false


var phase: Phase:
	get:
		return _phase

var failure: Failure:
	get:
		return _failure

var interception_triggered: bool:
	get:
		return _interception_triggered

var _phase := Phase.AWAITING_PICKUP
var _failure := Failure.NONE
var _interception_triggered := false


## Advance once after collecting the frame's interaction, spatial and combat observations.
## Defeat takes priority over delivery when both happen on the same frame.
func advance(observation: Observation) -> Phase:
	if _phase == Phase.SUCCEEDED or _phase == Phase.FAILED:
		return _phase
	if observation.hero_incapacitated:
		_phase = Phase.FAILED
		_failure = Failure.HERO_INCAPACITATED
	elif observation.bridle_lost:
		_phase = Phase.FAILED
		_failure = Failure.BRIDLE_LOST
	elif _phase == Phase.AWAITING_PICKUP:
		if observation.interact_pressed and observation.hero_in_pickup_zone:
			_phase = Phase.ESCORTING
	elif observation.carrier_in_road_exit:
		_phase = Phase.SUCCEEDED
	elif observation.carrier_in_interception_approach and not _interception_triggered:
		_interception_triggered = true
		interception_requested.emit()
	return _phase


func restart() -> void:
	_phase = Phase.AWAITING_PICKUP
	_failure = Failure.NONE
	_interception_triggered = false
