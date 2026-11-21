extends RefCounted
## Pure objective for The Lamp in the Window. Stopping the court's bid is not
## a ruling about the dead, a witness arrival, or closure of the vault.

const MISSION_ID := &"sereth_no_proxy"
const TERRACE_OCCUPATION_LIMIT_SECONDS := 6.0

enum Phase { AT_ASSEMBLY, RELEASING_COURT_TROOPS, INTERCEPTING, CLEARING_TERRACE, SUCCEEDED, FAILED }
enum Route { NONE, SHELF, SIDE }
enum Failure { NONE, SERETH_FELL, SPEAKER_CROSSED_CUSTODY_LINE, WITNESS_POSITION_LOST }


class Observation:
	## Fresh hero interaction at the refusal marker, with the witnesses present.
	var refuse_escort := false
	var sereth_at_assembly := false
	var witnesses_present_at_refusal := false
	## The adapter visibly split the court-assigned troops; Sereth's household stays local.
	var court_assignments_released := false

	## Current physical escort route and any screen actually stalling it.
	var speaker_route := Route.NONE
	var escort_stalled_on := Route.NONE
	var challenge_speaker := false
	var sereth_at_speaker := false
	var speaker_before_custody_line := false
	## An actual crossing at the boundary, not a claim or a successful command.
	var speaker_crossed_custody_line := false

	var terrace_approach_clear := false
	## Full hostile hold, not approaching enemies or contested contact.
	var hostiles_control_witness_position := false
	var elapsed_seconds := 0.0
	var sereth_fell := false


var phase: Phase:
	get:
		return _phase

var failure: Failure:
	get:
		return _failure

var refused_escort: bool:
	get:
		return _refused_escort

var speaker_route: Route:
	get:
		return _speaker_route

var bid_halted: bool:
	get:
		return _bid_halted

var occupation_warned: bool:
	get:
		return _occupation_warned

var occupation_seconds: float:
	get:
		return _occupation_seconds


var _phase := Phase.AT_ASSEMBLY
var _failure := Failure.NONE
var _refused_escort := false
var _speaker_route := Route.NONE
var _bid_halted := false
var _occupation_warned := false
var _occupation_seconds := 0.0


## Submit once after world contacts. Defeat beats same-update victory.
func advance(observation: Observation) -> Phase:
	if _phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return _phase
	if observation.sereth_fell:
		return _fail(Failure.SERETH_FELL)
	match _phase:
		Phase.AT_ASSEMBLY:
			if observation.refuse_escort and observation.sereth_at_assembly and observation.witnesses_present_at_refusal:
				_refused_escort = true
				_phase = Phase.RELEASING_COURT_TROOPS
			return _phase
		Phase.RELEASING_COURT_TROOPS:
			if observation.court_assignments_released:
				_phase = Phase.INTERCEPTING
			return _phase

	if _phase == Phase.INTERCEPTING:
		_speaker_route = observation.speaker_route if observation.speaker_route in [Route.SHELF, Route.SIDE] else Route.NONE
		if observation.speaker_crossed_custody_line:
			return _fail(Failure.SPEAKER_CROSSED_CUSTODY_LINE)
	if _witness_position_lost(observation):
		return _fail(Failure.WITNESS_POSITION_LOST)

	if _phase == Phase.INTERCEPTING:
		if observation.challenge_speaker and observation.sereth_at_speaker and observation.speaker_before_custody_line \
				and _speaker_route != Route.NONE and observation.escort_stalled_on == _speaker_route:
			_bid_halted = true
			_phase = Phase.CLEARING_TERRACE
		return _phase
	if observation.terrace_approach_clear and not observation.hostiles_control_witness_position:
		_phase = Phase.SUCCEEDED
	return _phase


func restart() -> void:
	_phase = Phase.AT_ASSEMBLY
	_failure = Failure.NONE
	_refused_escort = false
	_speaker_route = Route.NONE
	_bid_halted = false
	_occupation_warned = false
	_occupation_seconds = 0.0


func _witness_position_lost(observation: Observation) -> bool:
	if not observation.hostiles_control_witness_position:
		_occupation_warned = false
		_occupation_seconds = 0.0
	elif not _occupation_warned:
		# The first full-hold update always warns, even on a large time step.
		_occupation_warned = true
	elif is_finite(observation.elapsed_seconds) and observation.elapsed_seconds > 0.0:
		_occupation_seconds = minf(TERRACE_OCCUPATION_LIMIT_SECONDS, _occupation_seconds + observation.elapsed_seconds)
	return _occupation_seconds >= TERRACE_OCCUPATION_LIMIT_SECONDS


func _fail(reason: Failure) -> Phase:
	_failure = reason
	_phase = Phase.FAILED
	return _phase
