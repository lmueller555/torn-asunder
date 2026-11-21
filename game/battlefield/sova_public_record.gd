extends RefCounted
## Objective rules for Let Them Walk Out. The battlefield supplies venue and reading observations.

const MISSION_ID := &"sova_public_record"
const PASSAGES := 3

enum Venue { NONE, OPEN, RECESSED }
enum Phase { CHOOSING_VENUE, READING, INTERRUPTED, SUCCEEDED, FAILED }
enum Interruption { NONE, LEFT_LECTERN, RING_CONTESTED, EXIT_BLOCKED, RECORD_ABSENT, SCRIBE_ABSENT }
enum Failure { NONE, SOVA_FELL, RECORD_SEIZED, NO_SCRIBE_SURVIVES }


class VenueReport:
	var sova_at_lectern := false
	var record_at_lectern := false
	var scribe_present := false
	## Hostile or armed disruption, not neutral Keepers walking out.
	var ring_contested := false
	## The chosen exit is physically blocked, not merely in use by the public.
	var public_exit_blocked := false
	## Normalized effort supplied by the reader for this tick, not a countdown.
	var reading_credit := 0.0


class Observation:
	## The lectern Sova interacted with this tick. An attempt locks to one venue.
	var requested_venue := Venue.NONE
	var open := VenueReport.new()
	var recessed := VenueReport.new()
	var sova_fell := false
	var surviving_scribes := 1
	## A confirmed capture after the battlefield's signaled seizure opportunity.
	var record_seized := false


var venue: Venue:
	get:
		return _venue

var phase: Phase:
	get:
		return _phase

var interruption: Interruption:
	get:
		return _interruption

var failure: Failure:
	get:
		return _failure

var passages_read: int:
	get:
		return _passages_read

var passage_progress: float:
	get:
		return _passage_progress

var _venue := Venue.NONE
var _phase := Phase.CHOOSING_VENUE
var _interruption := Interruption.NONE
var _failure := Failure.NONE
var _passages_read := 0
var _passage_progress := 0.0


## Confirmed defeats win ties against final passage completion. Mere pressure
## never escalates into a seizure, and only the committed venue is evaluated.
func advance(observation: Observation) -> Phase:
	if _phase == Phase.SUCCEEDED or _phase == Phase.FAILED:
		return _phase
	if observation.sova_fell:
		return _fail(Failure.SOVA_FELL)
	if observation.record_seized:
		return _fail(Failure.RECORD_SEIZED)
	if observation.surviving_scribes <= 0:
		return _fail(Failure.NO_SCRIBE_SURVIVES)

	if _venue == Venue.NONE:
		if observation.requested_venue not in [Venue.OPEN, Venue.RECESSED]:
			return _phase
		var candidate := _report(observation, observation.requested_venue)
		if not candidate.sova_at_lectern:
			return _phase
		_venue = observation.requested_venue

	var report := _report(observation, _venue)
	if not report.sova_at_lectern:
		return _interrupt(Interruption.LEFT_LECTERN, true)
	if report.ring_contested:
		return _interrupt(Interruption.RING_CONTESTED, true)
	if report.public_exit_blocked:
		return _interrupt(Interruption.EXIT_BLOCKED)
	if not report.record_at_lectern:
		return _interrupt(Interruption.RECORD_ABSENT)
	if not report.scribe_present:
		return _interrupt(Interruption.SCRIBE_ABSENT)

	_phase = Phase.READING
	_interruption = Interruption.NONE
	_read(report.reading_credit)
	return _phase


func restart() -> void:
	_venue = Venue.NONE
	_phase = Phase.CHOOSING_VENUE
	_interruption = Interruption.NONE
	_failure = Failure.NONE
	_passages_read = 0
	_passage_progress = 0.0


func _read(credit: float) -> void:
	if not is_finite(credit) or credit <= 0.0:
		return
	_passage_progress = minf(_passage_progress + credit, 1.0)
	if not is_equal_approx(_passage_progress, 1.0):
		return
	# One passage per observation; excess effort doesn't start the next passage.
	_passages_read += 1
	_passage_progress = 0.0
	if _passages_read == PASSAGES:
		_phase = Phase.SUCCEEDED


func _report(observation: Observation, selected: Venue) -> VenueReport:
	return observation.open if selected == Venue.OPEN else observation.recessed


func _interrupt(reason: Interruption, reset_passage := false) -> Phase:
	_phase = Phase.INTERRUPTED
	_interruption = reason
	if reset_passage:
		_passage_progress = 0.0
	return _phase


func _fail(reason: Failure) -> Phase:
	_failure = reason
	_interruption = Interruption.NONE
	_phase = Phase.FAILED
	return _phase
