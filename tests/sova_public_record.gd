extends SceneTree

const Hearing := preload("res://game/battlefield/sova_public_record.gd")
const Venue := Hearing.Venue
const Phase := Hearing.Phase
const Interruption := Hearing.Interruption
const Failure := Hearing.Failure


func _initialize() -> void:
	var open_ok := _check_venue(Venue.OPEN)
	var recessed_ok := _check_venue(Venue.RECESSED)
	var failures_ok := _check_defeats()
	var passed := open_ok and recessed_ok and failures_ok
	if passed:
		print("Verified both hearing venues and their own exits, passage recovery, neutral walkouts, actual defeats and retry.")
	quit(0 if passed else 1)


func _check_venue(selected: Hearing.Venue) -> bool:
	var hearing := Hearing.new()
	var frame := Hearing.Observation.new()
	var other_venue := Venue.RECESSED if selected == Venue.OPEN else Venue.OPEN
	var report := _report(frame, selected)
	var other := _report(frame, other_venue)
	frame.requested_venue = selected
	other.sova_at_lectern = true
	other.record_at_lectern = true
	other.scribe_present = true
	other.reading_credit = 1.0
	if hearing.advance(frame) != Phase.CHOOSING_VENUE or hearing.venue != Venue.NONE:
		return _fail("Interacting away from the requested lectern committed the hearing.")

	_ready_to_read(report)
	report.reading_credit = 1.0
	if hearing.advance(frame) != Phase.READING or hearing.venue != selected or hearing.passages_read != 1:
		return _fail("The actual lectern did not select its venue and complete the first eligible passage.")

	frame.requested_venue = other_venue
	other.public_exit_blocked = true
	other.ring_contested = true
	report.reading_credit = 0.35
	if hearing.advance(frame) != Phase.READING or hearing.venue != selected or not is_equal_approx(hearing.passage_progress, 0.35):
		return _fail("The other ring or exit changed the committed venue or reading progress.")
	report.public_exit_blocked = true
	report.reading_credit = 1.0
	if hearing.advance(frame) != Phase.INTERRUPTED or hearing.interruption != Interruption.EXIT_BLOCKED or not is_equal_approx(hearing.passage_progress, 0.35):
		return _fail("The committed public exit did not pause the current passage.")

	report.public_exit_blocked = false
	report.reading_credit = 0.10
	if hearing.advance(frame) != Phase.READING or not is_equal_approx(hearing.passage_progress, 0.45):
		return _fail("Clearing the public exit did not resume the same passage.")

	# The record and living scribe can be momentarily absent without losing the hearing.
	report.record_at_lectern = false
	if hearing.advance(frame) != Phase.INTERRUPTED or hearing.interruption != Interruption.RECORD_ABSENT:
		return _fail("Temporary loss of access to the record was treated as a seizure.")
	report.record_at_lectern = true
	report.scribe_present = false
	if hearing.advance(frame) != Phase.INTERRUPTED or hearing.interruption != Interruption.SCRIBE_ABSENT:
		return _fail("A living but absent scribe was confused with defeat.")
	report.scribe_present = true

	# An armed charge disrupts the line currently being read, not prior passages.
	report.ring_contested = true
	for _tick in range(1000):
		hearing.advance(frame)
	if hearing.phase != Phase.INTERRUPTED or hearing.interruption != Interruption.RING_CONTESTED or hearing.passages_read != 1 or hearing.passage_progress != 0.0:
		return _fail("Ongoing contest implicitly seized the record or erased a completed passage.")
	report.ring_contested = false
	report.reading_credit = 0.5
	hearing.advance(frame)
	report.sova_at_lectern = false
	if hearing.advance(frame) != Phase.INTERRUPTED or hearing.interruption != Interruption.LEFT_LECTERN or hearing.passages_read != 1 or hearing.passage_progress != 0.0:
		return _fail("Stepping away did not reset just the current passage.")

	# People may depart while the exit remains clear. No audience count or
	# approval is required, and a quiet tick does not read for the hero.
	report.sova_at_lectern = true
	report.reading_credit = 0.0
	for _tick in range(100):
		hearing.advance(frame)
	if hearing.phase != Phase.READING or hearing.passages_read != 1:
		return _fail("An open exit or idle tick created a deadline or advanced the hearing.")
	report.reading_credit = 2.0
	if hearing.advance(frame) != Phase.READING or hearing.passages_read != 2:
		return _fail("Reading credit resolved more than one passage or failed to resume.")
	if hearing.advance(frame) != Phase.SUCCEEDED or hearing.passages_read != Hearing.PASSAGES:
		return _fail("All three passages with an open public exit and a scribe did not clear the hearing.")
	frame.record_seized = true
	frame.sova_fell = true
	frame.surviving_scribes = 0
	if hearing.advance(frame) != Phase.SUCCEEDED:
		return _fail("A late event replaced a completed hearing.")

	hearing.restart()
	if not _check_reset(hearing):
		return false
	frame = Hearing.Observation.new()
	frame.requested_venue = other_venue
	_ready_to_read(_report(frame, other_venue))
	if hearing.advance(frame) != Phase.READING or hearing.venue != other_venue:
		return _fail("Restart did not permit the other placement and exit.")
	return true


func _check_defeats() -> bool:
	for expected in [Failure.SOVA_FELL, Failure.RECORD_SEIZED, Failure.NO_SCRIBE_SURVIVES]:
		var hearing := Hearing.new()
		var frame := Hearing.Observation.new()
		frame.requested_venue = Venue.OPEN
		_ready_to_read(frame.open)
		frame.open.reading_credit = 1.0
		for _read in range(Hearing.PASSAGES - 1):
			hearing.advance(frame)
		frame.sova_fell = expected == Failure.SOVA_FELL
		frame.record_seized = expected == Failure.RECORD_SEIZED
		frame.surviving_scribes = 0 if expected == Failure.NO_SCRIBE_SURVIVES else 1
		if hearing.advance(frame) != Phase.FAILED or hearing.failure != expected or hearing.passages_read != 2:
			return _fail("A definitive loss failed to override same-tick completion: %d." % expected)
		if hearing.advance(Hearing.Observation.new()) != Phase.FAILED or hearing.failure != expected:
			return _fail("A terminal defeat resumed without a restart.")
		hearing.restart()
		if not _check_reset(hearing):
			return false
	return true


func _ready_to_read(report: Hearing.VenueReport) -> void:
	report.sova_at_lectern = true
	report.record_at_lectern = true
	report.scribe_present = true


func _report(frame: Hearing.Observation, selected: Hearing.Venue) -> Hearing.VenueReport:
	return frame.open if selected == Venue.OPEN else frame.recessed


func _check_reset(hearing: Hearing) -> bool:
	if hearing.phase != Phase.CHOOSING_VENUE or hearing.venue != Venue.NONE or hearing.failure != Failure.NONE or hearing.interruption != Interruption.NONE:
		return _fail("Restart retained the venue, warning, or terminal outcome.")
	if hearing.passages_read != 0 or hearing.passage_progress != 0.0:
		return _fail("Restart retained reading progress.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
