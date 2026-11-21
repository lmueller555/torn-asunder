extends SceneTree

const Survey := preload("res://game/battlefield/ilyra_coast_survey.gd")
const STONE := Survey.Reading.ANCESTRAL_STONE
const INLET := Survey.Reading.FISHING_INLET
const BEACH := Survey.SignalSite.BEACH
const HEADLAND := Survey.SignalSite.HEADLAND
const TAKING := Survey.Phase.TAKING_READINGS
const WAITING := Survey.Phase.WAITING_TO_SIGNAL
const SIGNALING := Survey.Phase.SIGNALING
const SUCCEEDED := Survey.Phase.SUCCEEDED
const FAILED := Survey.Phase.FAILED


func _initialize() -> void:
	var passed := _check_stage_and_both_orders() and _check_signal_conditions() \
		and _check_switch_and_missed_passes() and _check_defeat_priority_and_retry()
	if passed:
		print("Ilyra coast survey: both reading orders, independent sites, staffed LOS and stops, interrupted and missed passes, defeats and retries passed.")
	quit(0 if passed else 1)


func _check_stage_and_both_orders() -> bool:
	for first in [STONE, INLET]:
		var second := INLET if first == STONE else STONE
		var site := BEACH if first == STONE else HEADLAND
		var survey := Survey.new()
		var sample := _available()
		sample.requested_signal = site
		sample.hero_at_reading = first
		if survey.advance(sample) != TAKING or survey.has_reading(first):
			return _fail("The hero's presence alone recorded a reading or started a signal.")
		sample.hero_at_reading = Survey.Reading.NONE
		sample.hero_inspected_marker = true
		if survey.advance(sample) != TAKING or survey.has_reading(Survey.Reading.NONE):
			return _fail("An inspection away from both reading markers counted.")
		sample.hero_at_reading = first
		survey.advance(sample)
		if survey.advance(sample) != TAKING or not survey.has_reading(first) or survey.has_reading(second):
			return _fail("Re-inspecting one marker granted the other reading.")
		sample.hero_at_reading = second
		if survey.advance(sample) != WAITING or not _both_readings(survey) or survey.signal_progress != 0.0:
			return _fail("Both readings did not arm a separate signal stage without credit.")
		if survey.advance(_available()) != WAITING:
			return _fail("A pre-reading signal order carried over without a fresh order.")
		if survey.advance(sample) != SIGNALING or survey.signal_site != site or survey.signal_progress != 0.0:
			return _fail("A signal order either failed to start or credited its same-tick observation.")
		if survey.advance(_available()) != SUCCEEDED or survey.signal_progress != 1.0:
			return _fail("An uninterrupted signal did not deliver both readings from the chosen site.")
		var too_late := _available()
		too_late.cutter_disabled = true
		too_late.hero_fell = true
		if survey.advance(too_late) != SUCCEEDED or survey.signal_site != site \
				or survey.failure != Survey.Failure.NONE or not _both_readings(survey):
			return _fail("A confirmed win was not terminal.")
	return true


func _check_signal_conditions() -> bool:
	var blockers := {
		"staffed": [false, Survey.Interruption.UNSTAFFED],
		"contested": [true, Survey.Interruption.CONTESTED],
		"line_of_sight_clear": [false, Survey.Interruption.LINE_OF_SIGHT_BLOCKED],
		"cutter_at_stop": [false, Survey.Interruption.CUTTER_OFF_STOP],
	}
	for flag: String in blockers:
		var survey := Survey.new()
		_record_both(survey)
		var blocked := _available()
		blocked.requested_signal = BEACH
		blocked.beach.set(flag, blockers[flag][0])
		if survey.advance(blocked) != WAITING or survey.interruption != blockers[flag][1] \
				or survey.signal_progress != 0.0 or not _both_readings(survey):
			return _fail("Invalid beach start accepted with " + flag)
		var partial := _available()
		partial.requested_signal = BEACH
		partial.beach.signal_credit = 0.6
		survey.advance(partial)
		if survey.advance(partial) != SIGNALING or not is_equal_approx(survey.signal_progress, 0.6):
			return _fail("A valid update could not progress independently of the other signal site.")
		blocked.requested_signal = Survey.SignalSite.NONE
		if survey.advance(blocked) != WAITING or survey.interruption != blockers[flag][1] \
				or survey.signal_progress != 0.0 or survey.signal_site != Survey.SignalSite.NONE \
				or not _both_readings(survey) or survey.failure != Survey.Failure.NONE:
			return _fail("Signal interruption did not reset only the current attempt: " + flag)
		if survey.advance(_available()) != WAITING:
			return _fail("Clear conditions alone resurrected an interrupted signal.")
		if survey.advance(partial) != SIGNALING or survey.interruption != Survey.Interruption.NONE:
			return _fail("A new order at the recovered site did not start a new attempt.")
		if survey.advance(partial) != SIGNALING or not is_equal_approx(survey.signal_progress, 0.6):
			return _fail("An interrupted signal silently retained its previous progress.")
		if survey.advance(partial) != SUCCEEDED:
			return _fail("A full replacement signal could not be acknowledged.")
	return true


func _check_switch_and_missed_passes() -> bool:
	var survey := Survey.new()
	_record_both(survey)
	var departure := _available()
	departure.requested_signal = BEACH
	departure.beach.cutter_at_stop = false
	for _pass in range(100):
		if survey.advance(departure) != WAITING or survey.failure != Survey.Failure.NONE:
			return _fail("Missing repeated cutter loops imposed an undocumented deadline.")
	var wrong_stop := _available()
	wrong_stop.requested_signal = HEADLAND
	wrong_stop.headland.cutter_at_stop = false
	if survey.advance(wrong_stop) != WAITING:
		return _fail("The boat at the beach stop was counted for the headland.")
	var ordered := _available()
	ordered.requested_signal = BEACH
	ordered.beach.signal_credit = 0.8
	survey.advance(ordered)
	survey.advance(ordered)
	var headland := _available()
	headland.requested_signal = HEADLAND
	headland.headland.signal_credit = 0.3
	if survey.advance(headland) != SIGNALING or survey.signal_site != HEADLAND or survey.signal_progress != 0.0:
		return _fail("Switching signal sites retained the old site's progress.")
	if survey.advance(headland) != SIGNALING or not is_equal_approx(survey.signal_progress, 0.3):
		return _fail("Credit was not isolated to the active headland.")
	headland.beach.line_of_sight_clear = false
	headland.beach.contested = true
	for invalid in [NAN, INF, -1.0, 0.0]:
		headland.headland.signal_credit = invalid
		if survey.advance(headland) != SIGNALING or not is_equal_approx(survey.signal_progress, 0.3):
			return _fail("Bad effort or contest at the other site changed the current signal.")
	headland.headland.signal_credit = 0.7
	if survey.advance(headland) != SUCCEEDED or not _both_readings(survey):
		return _fail("A later valid cutter pass at the other site could not finish the survey.")
	return true


func _check_defeat_priority_and_retry() -> bool:
	var defeats := {"hero_fell": Survey.Failure.HERO_FELL, "cutter_disabled": Survey.Failure.CUTTER_DISABLED}
	for loss: String in defeats:
		var early := Survey.new()
		var first := _available()
		first.hero_at_reading = STONE
		first.hero_inspected_marker = true
		first.set(loss, true)
		if early.advance(first) != FAILED or early.failure != defeats[loss] or early.has_reading(STONE):
			return _fail("Confirmed defeat did not beat the same-tick reading.")
		var survey := Survey.new()
		_record_both(survey)
		var finish := _available()
		finish.requested_signal = HEADLAND
		survey.advance(finish)
		finish.set(loss, true)
		if survey.advance(finish) != FAILED or survey.failure != defeats[loss] or survey.signal_progress != 0.0:
			return _fail("Confirmed defeat did not beat the same-tick acknowledgement.")
		if survey.advance(_available()) != FAILED or survey.failure != defeats[loss]:
			return _fail("A confirmed defeat was not terminal.")
		survey.restart()
		if survey.phase != TAKING or survey.failure != Survey.Failure.NONE \
				or survey.interruption != Survey.Interruption.NONE or survey.signal_progress != 0.0 \
				or survey.signal_site != Survey.SignalSite.NONE or survey.has_reading(STONE) or survey.has_reading(INLET):
			return _fail("Retry did not discard old readings, target, progress and failure.")
	return true


func _record_both(survey: Survey) -> void:
	var sample := Survey.Observation.new()
	sample.hero_inspected_marker = true
	sample.hero_at_reading = STONE
	survey.advance(sample)
	sample.hero_at_reading = INLET
	survey.advance(sample)


func _available() -> Survey.Observation:
	var report := Survey.Observation.new()
	for site in [report.beach, report.headland]:
		site.staffed = true
		site.line_of_sight_clear = true
		site.cutter_at_stop = true
		site.signal_credit = 1.0
	return report


func _both_readings(survey: Survey) -> bool:
	return survey.has_reading(STONE) and survey.has_reading(INLET)


func _fail(message: String) -> bool:
	push_error(message)
	return false
