extends RefCounted
## Objective rules for Hulls on Stone. The battlefield supplies hero interactions,
## receiving-deck movement and threat observations, independent of the Human retreat.

const MISSION_ID := &"ilyra_moonwash_rescue"
const CREWS_ONLY := &"crews_only"
const CARGO_RECOVERED := &"cargo_recovered"

enum Transfer { FORWARD, AFT }
enum CrewStatus { STRANDED, CROSSING, PAUSED, SAFE, LOST }
enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Failure { NONE, HERO_FELL, REQUIRED_CREW_LOST }


class TransferReport:
	## Enemy pressure at this transfer's receiving point, not another lane.
	var receiving_point_contested := false
	## This crew physically reached its receiving deck, not the marked line itself.
	var crew_at_receiving_deck := false
	var crew_definitively_lost := false


class Observation:
	var forward := TransferReport.new()
	var aft := TransferReport.new()
	## Only a valid field-hero rig interaction. A tick can target at most one line.
	var hero_rigged_transfer: int = -1
	var hero_fell := false
	## The optional marked bundle actually landed on the receiving deck.
	var cargo_at_receiving_deck := false


var outcome: Outcome:
	get:
		return _outcome

var failure: Failure:
	get:
		return _failure

var cargo_recovered: bool:
	get:
		return _cargo_recovered

## A successful debrief key. Cargo never gates transfer or mission success.
var clear_result: StringName:
	get:
		if _outcome != Outcome.SUCCEEDED:
			return &""
		return CARGO_RECOVERED if _cargo_recovered else CREWS_ONLY

var _outcome := Outcome.ACTIVE
var _failure := Failure.NONE
var _rigged: Array[bool] = [false, false]
var _crews: Array[CrewStatus] = [CrewStatus.STRANDED, CrewStatus.STRANDED]
var _cargo_recovered := false


func line_is_rigged(transfer: Transfer) -> bool:
	return _rigged[transfer]


func crew_status(transfer: Transfer) -> CrewStatus:
	return _crews[transfer]


## Submit once after movement and threat checks. Required losses take priority
## over same-tick arrival. Terminal results do not accept further updates.
func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.hero_fell:
		return _fail(Failure.HERO_FELL)
	var forward_lost := _lose_crew_if_reported(Transfer.FORWARD, observation.forward)
	var aft_lost := _lose_crew_if_reported(Transfer.AFT, observation.aft)
	if forward_lost or aft_lost:
		return _fail(Failure.REQUIRED_CREW_LOST)

	_advance_transfer(Transfer.FORWARD, observation.forward, observation.hero_rigged_transfer == Transfer.FORWARD)
	_advance_transfer(Transfer.AFT, observation.aft, observation.hero_rigged_transfer == Transfer.AFT)
	_cargo_recovered = _cargo_recovered or observation.cargo_at_receiving_deck
	if _crews[Transfer.FORWARD] == CrewStatus.SAFE and _crews[Transfer.AFT] == CrewStatus.SAFE:
		_outcome = Outcome.SUCCEEDED
	return _outcome


func restart() -> void:
	_outcome = Outcome.ACTIVE
	_failure = Failure.NONE
	_rigged = [false, false]
	_crews = [CrewStatus.STRANDED, CrewStatus.STRANDED]
	_cargo_recovered = false


func _advance_transfer(transfer: Transfer, report: TransferReport, rig_ordered: bool) -> void:
	match _crews[transfer]:
		CrewStatus.STRANDED:
			if rig_ordered:
				_rigged[transfer] = true
				_crews[transfer] = CrewStatus.PAUSED if report.receiving_point_contested else CrewStatus.CROSSING
		CrewStatus.PAUSED:
			if not report.receiving_point_contested:
				_crews[transfer] = CrewStatus.CROSSING
		CrewStatus.CROSSING:
			# Rigging and resuming do not accept an arrival on that same tick.
			if report.receiving_point_contested:
				_crews[transfer] = CrewStatus.PAUSED
			elif report.crew_at_receiving_deck:
				_crews[transfer] = CrewStatus.SAFE


func _lose_crew_if_reported(transfer: Transfer, report: TransferReport) -> bool:
	if _crews[transfer] != CrewStatus.SAFE and report.crew_definitively_lost:
		_crews[transfer] = CrewStatus.LOST
		return true
	return false


func _fail(reason: Failure) -> Outcome:
	_failure = reason
	_outcome = Outcome.FAILED
	return _outcome
