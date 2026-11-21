extends RefCounted
## Objective rules for Two Shorelines. The battlefield reports marker contact,
## staffing, contest, line of sight and physical cutter stops after world updates.

const MISSION_ID := &"ilyra_coast_survey"

enum Reading { NONE, ANCESTRAL_STONE, FISHING_INLET }
enum SignalSite { NONE, BEACH, HEADLAND }
enum Phase { TAKING_READINGS, WAITING_TO_SIGNAL, SIGNALING, SUCCEEDED, FAILED }
enum Interruption { NONE, UNSTAFFED, CONTESTED, LINE_OF_SIGHT_BLOCKED, CUTTER_OFF_STOP }
enum Failure { NONE, HERO_FELL, CUTTER_DISABLED }


class SignalReport:
	var staffed := false
	var contested := false
	## Current terrain line of sight from this site to the cutter.
	var line_of_sight_clear := false
	## Cutter is physically at this site's authored stop, not merely on its loop.
	var cutter_at_stop := false
	## Normalized signal effort accumulated during this observation's update.
	var signal_credit := 0.0


class Observation:
	var hero_at_reading := Reading.NONE
	var hero_inspected_marker := false
	## A new signal order. Repeating the existing order does not reset a signal.
	var requested_signal := SignalSite.NONE
	var beach := SignalReport.new()
	var headland := SignalReport.new()
	var hero_fell := false
	var cutter_disabled := false


var phase: Phase:
	get:
		return _phase

var signal_site: SignalSite:
	get:
		return _signal_site

var signal_progress: float:
	get:
		return _signal_progress

var interruption: Interruption:
	get:
		return _interruption

var failure: Failure:
	get:
		return _failure

var _phase := Phase.TAKING_READINGS
var _readings: Array[Reading] = []
var _signal_site := SignalSite.NONE
var _signal_progress := 0.0
var _interruption := Interruption.NONE
var _failure := Failure.NONE


func has_reading(reading: Reading) -> bool:
	return _readings.has(reading)


## Required losses beat final acknowledgement on the same update. Missing a
## cutter pass does not fail the mission or discard either recorded reading.
func advance(observation: Observation) -> Phase:
	if _phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return _phase
	if observation.hero_fell:
		return _fail(Failure.HERO_FELL)
	if observation.cutter_disabled:
		return _fail(Failure.CUTTER_DISABLED)

	if _phase == Phase.TAKING_READINGS:
		var reading := observation.hero_at_reading
		if observation.hero_inspected_marker and reading in [Reading.ANCESTRAL_STONE, Reading.FISHING_INLET] \
				and not has_reading(reading):
			_readings.append(reading)
		if _readings.size() == 2:
			_phase = Phase.WAITING_TO_SIGNAL
		# A request before securing the readings does not carry into the next stage.
		return _phase

	var requested := observation.requested_signal
	if requested in [SignalSite.BEACH, SignalSite.HEADLAND] and requested != _signal_site:
		# An explicit order at the other site replaces the attempt, not its reading data.
		var block := _signal_block(_report(observation, requested))
		if block != Interruption.NONE:
			return _wait_to_signal(block)
		_phase = Phase.SIGNALING
		_signal_site = requested
		_signal_progress = 0.0
		_interruption = Interruption.NONE
		return _phase

	if _phase != Phase.SIGNALING:
		return _phase
	var report := _report(observation, _signal_site)
	var block := _signal_block(report)
	if block != Interruption.NONE:
		return _wait_to_signal(block)
	var credit := report.signal_credit
	if is_finite(credit) and credit > 0.0:
		_signal_progress = minf(1.0, _signal_progress + credit)
		if is_equal_approx(_signal_progress, 1.0):
			_signal_progress = 1.0
			_phase = Phase.SUCCEEDED
	return _phase


func restart() -> void:
	_phase = Phase.TAKING_READINGS
	_readings.clear()
	_signal_site = SignalSite.NONE
	_signal_progress = 0.0
	_interruption = Interruption.NONE
	_failure = Failure.NONE


func _report(observation: Observation, site: SignalSite) -> SignalReport:
	return observation.beach if site == SignalSite.BEACH else observation.headland


func _signal_block(report: SignalReport) -> Interruption:
	if not report.staffed:
		return Interruption.UNSTAFFED
	if report.contested:
		return Interruption.CONTESTED
	if not report.cutter_at_stop:
		return Interruption.CUTTER_OFF_STOP
	if not report.line_of_sight_clear:
		return Interruption.LINE_OF_SIGHT_BLOCKED
	return Interruption.NONE


func _wait_to_signal(reason: Interruption) -> Phase:
	_phase = Phase.WAITING_TO_SIGNAL
	_signal_site = SignalSite.NONE
	_signal_progress = 0.0
	_interruption = reason
	return _phase


func _fail(reason: Failure) -> Phase:
	_wait_to_signal(Interruption.NONE)
	_failure = reason
	_phase = Phase.FAILED
	return _phase
