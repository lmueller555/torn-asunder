extends RefCounted
## Objective rules for What We Planted Here. The grove's refusal is fixed:
## this attempt moves one tree by sled, never through a root crossing.

const MISSION_ID := &"neris_failing_grove"

enum Phase { AWAITING_ENVOY, AWAITING_VOLUNTEERS, LOADING, ESCORTING, AWAITING_TRANSPLANT, SUCCEEDED, FAILED }
enum Interruption { NONE, YARD_CONTESTED, SLED_ROUTE_CONTESTED, NURSERY_CONTESTED }
enum Failure { NONE, NERIS_FELL, SLED_DESTROYED }


class Observation:
	## Valid hero interactions, sampled only on the tick the player performs them.
	var envoy_interaction_confirmed := false
	var volunteers_called := false
	var transplant_interaction_confirmed := false
	var yard_contested := false
	## Work actually completed by volunteers, normalized to a full root-ball load.
	var loading_credit := 0.0
	## Pressure on the sled's next section, not enemies elsewhere on the map.
	var sled_route_contested := false
	## The intact sled itself is currently in the nursery, not just the hero.
	var sled_at_nursery := false
	var nursery_contested := false
	var neris_fell := false
	## A confirmed destruction, not a stalled, contested, or temporarily stopped sled.
	var sled_definitively_destroyed := false


var phase: Phase:
	get:
		return _phase

var interruption: Interruption:
	get:
		return _interruption

var failure: Failure:
	get:
		return _failure

var loading_progress: float:
	get:
		return _loading_progress

var _phase := Phase.AWAITING_ENVOY
var _interruption := Interruption.NONE
var _failure := Failure.NONE
var _loading_progress := 0.0


## Submit once after resolving interactions, worker progress, and movement.
## Each observation can change at most one phase; losses win terminal ties.
func advance(observation: Observation) -> Phase:
	if _phase == Phase.SUCCEEDED or _phase == Phase.FAILED:
		return _phase
	if observation.neris_fell:
		return _fail(Failure.NERIS_FELL)
	if observation.sled_definitively_destroyed:
		return _fail(Failure.SLED_DESTROYED)

	_interruption = Interruption.NONE
	match _phase:
		Phase.AWAITING_ENVOY:
			if observation.envoy_interaction_confirmed:
				_phase = Phase.AWAITING_VOLUNTEERS
		Phase.AWAITING_VOLUNTEERS:
			if observation.volunteers_called:
				_phase = Phase.LOADING
		Phase.LOADING:
			if observation.yard_contested:
				_interruption = Interruption.YARD_CONTESTED
			else:
				_load(observation.loading_credit)
		Phase.ESCORTING:
			if observation.sled_route_contested:
				_interruption = Interruption.SLED_ROUTE_CONTESTED
			elif observation.sled_at_nursery:
				_phase = Phase.AWAITING_TRANSPLANT
		Phase.AWAITING_TRANSPLANT:
			if observation.nursery_contested:
				_interruption = Interruption.NURSERY_CONTESTED
			elif observation.transplant_interaction_confirmed and observation.sled_at_nursery:
				_phase = Phase.SUCCEEDED
	return _phase


func restart() -> void:
	_phase = Phase.AWAITING_ENVOY
	_interruption = Interruption.NONE
	_failure = Failure.NONE
	_loading_progress = 0.0


func _load(credit: float) -> void:
	if not is_finite(credit) or credit <= 0.0:
		return
	_loading_progress = minf(_loading_progress + credit, 1.0)
	if is_equal_approx(_loading_progress, 1.0):
		_loading_progress = 1.0
		_phase = Phase.ESCORTING


func _fail(reason: Failure) -> Phase:
	_phase = Phase.FAILED
	_failure = reason
	_interruption = Interruption.NONE
	return _phase
