extends RefCounted
## Pure objectives for Mara's High Quay withdrawal. All observations describe the
## current tick in the Human lane. No state from Ilyra's rescue is required.

signal platoon_extracted(platoon: Platoon)
signal lower_quay_warned
signal lower_quay_closed

enum Phase { WITHDRAWING, SUCCEEDED, FAILED }
enum Platoon { FIRST, SECOND }
enum Failure { NONE, HERO_DEFEATED, FIRST_PLATOON_LOST, SECOND_PLATOON_LOST }
enum LowerQuay { OPEN, WARNED, CLOSED }


class PlatoonObservation:
	## Stable IDs for every currently living roster member, including any who
	## already crossed and left the simulated battlefield safely.
	var living_members := PackedStringArray()
	## Members crossing the actual upper-quay exit in this tick. Duplicates
	## and IDs not present in living_members never increase extraction progress.
	var crossed_upper_exit := PackedStringArray()


class Observation:
	var hero_defeated := false
	var hero_crossed_upper_exit := false
	## Omit an observation to keep this platoon's prior state unchanged. An
	## explicitly empty living roster means a wipeout, not missing data.
	var first: PlatoonObservation
	var second: PlatoonObservation
	var lower_quay_cracking := false
	var lower_quay_closure_requested := false
	## True only while the protected inland route still connects the
	## withdrawing survivors to the permanently available upper exit.
	var inland_route_open := false


var phase: Phase:
	get:
		return _phase
var failure: Failure:
	get:
		return _failure
var hero_extracted: bool:
	get:
		return _hero_extracted
var lower_quay: LowerQuay:
	get:
		return _lower_quay

var _phase := Phase.WITHDRAWING
var _failure := Failure.NONE
var _hero_extracted := false
var _lower_quay := LowerQuay.OPEN
var _extracted: Array[bool] = [false, false]
var _crossed_members: Array[Dictionary] = [{}, {}]


func is_platoon_extracted(platoon: int) -> bool:
	return _valid_platoon(platoon) and _extracted[platoon]


func can_order_platoon(platoon: int) -> bool:
	return _phase == Phase.WITHDRAWING and _valid_platoon(platoon) and not _extracted[platoon]


func advance(observation: Observation) -> Phase:
	if _phase != Phase.WITHDRAWING or not observation:
		return _phase

	# Defeat wins ties with delivery. A previously extracted platoon is safe;
	# subsequent empty snapshots cannot undo its result.
	if observation.hero_defeated:
		_fail(Failure.HERO_DEFEATED)
	elif _wiped(Platoon.FIRST, observation.first):
		_fail(Failure.FIRST_PLATOON_LOST)
	elif _wiped(Platoon.SECOND, observation.second):
		_fail(Failure.SECOND_PLATOON_LOST)
	if _phase == Phase.FAILED:
		return _phase

	_hero_extracted = _hero_extracted or observation.hero_crossed_upper_exit
	var first_finished := _extract(Platoon.FIRST, observation.first)
	var second_finished := _extract(Platoon.SECOND, observation.second)
	if _hero_extracted and _extracted.all(func(out: bool) -> bool: return out):
		_phase = Phase.SUCCEEDED

	if first_finished:
		platoon_extracted.emit(Platoon.FIRST)
	if second_finished:
		platoon_extracted.emit(Platoon.SECOND)
	if _phase == Phase.WITHDRAWING:
		_advance_lower_quay(observation)
	return _phase


func restart() -> void:
	_phase = Phase.WITHDRAWING
	_failure = Failure.NONE
	_hero_extracted = false
	_lower_quay = LowerQuay.OPEN
	_extracted = [false, false]
	_crossed_members = [{}, {}]


func _valid_platoon(platoon: int) -> bool:
	return platoon >= 0 and platoon < _extracted.size()


func _fail(reason: Failure) -> void:
	_phase = Phase.FAILED
	_failure = reason


func _wiped(platoon: Platoon, record: PlatoonObservation) -> bool:
	if not record or _extracted[platoon]:
		return false
	for id in record.living_members:
		if not id.is_empty():
			return false
	return true


func _extract(platoon: Platoon, record: PlatoonObservation) -> bool:
	if not record or _extracted[platoon]:
		return false
	var living: Dictionary[String, bool] = {}
	for id in record.living_members:
		if not id.is_empty():
			living[id] = true
	var crossed := _crossed_members[platoon]
	for id in record.crossed_upper_exit:
		if living.has(id):
			crossed[id] = true
	for id in living:
		if not crossed.has(id):
			return false
	_extracted[platoon] = true
	return true


func _advance_lower_quay(observation: Observation) -> void:
	# The model has no way to close the upper exit or the protected inland lane.
	# Requests never skip the warning tick or cut the lower lane without a bypass.
	if _lower_quay == LowerQuay.OPEN and observation.lower_quay_cracking:
		_lower_quay = LowerQuay.WARNED
		lower_quay_warned.emit()
	elif _lower_quay == LowerQuay.WARNED and observation.lower_quay_closure_requested and observation.inland_route_open:
		_lower_quay = LowerQuay.CLOSED
		lower_quay_closed.emit()
