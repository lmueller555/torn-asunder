extends SceneTree

const Objective := preload("res://game/battlefield/raska_spanwater_release.gd")
const Field := preload("res://game/battlefields/spanwater_lock.tscn")
const Missions := preload("res://game/campaign_missions.gd")
const Phase := Objective.Phase
const WheelControl := Objective.WheelControl
const Failure := Objective.Failure

var _withdrawals := 0
var _unlocks := 0


func _initialize() -> void:
	var passed := _check_marker_contract()
	passed = _check_attempt_and_retry() and passed
	passed = _check_failure_precedence() and passed
	quit(0 if passed else 1)


func _check_marker_contract() -> bool:
	var field := Field.instantiate()
	var wheel := field.get_node_or_null(Objective.SPILLWAY_WHEEL) as Marker3D
	var exit := field.get_node_or_null(Objective.HIGH_BANK_EXIT) as Marker3D
	var sea_gate := field.get_node_or_null(^"Markers/Objectives/SeaGate") as Marker3D
	var valid := wheel != null and exit != null and sea_gate != null \
		and wheel.position != sea_gate.position and wheel.position != exit.position and exit.position != sea_gate.position
	field.free()
	if not valid:
		return _fail("The wheel and exit must be distinct from the sea-gate landmark on the actual map.")
	var route := Missions.mission_for_campaign("raska", String(Objective.MISSION_ID))
	if route.get("battlefield_id") != "spanwater_lock":
		return _fail("The objective's mission ID does not route to Raska's Spanwater battlefield.")
	return true


func _check_attempt_and_retry() -> bool:
	var objective := Objective.new()
	objective.lower_towns_withdrawal_ordered.connect(func() -> void: _withdrawals += 1)
	objective.high_bank_unlocked.connect(func() -> void: _unlocks += 1)

	var premature := _sample(WheelControl.CONTESTED, true, 1.0, true)
	if objective.advance(premature) != Phase.SECURE_SPILLWAY or objective.release_progress != 0.0 \
		or objective.withdrawal_ordered or _withdrawals != 0 or _unlocks != 0:
		return _fail("An attack-side interact or early high-bank arrival advanced an uncleared objective.")
	if objective.advance(_sample(WheelControl.SECURED, true, 1.0)) != Phase.READY_AT_WHEEL:
		return _fail("The capture tick opened the wheel instead of waiting for a new Raska interact.")
	if objective.advance(_sample(WheelControl.CONTESTED, true)) != Phase.SECURE_SPILLWAY \
		or objective.advance(_sample(WheelControl.SECURED)) != Phase.READY_AT_WHEEL \
		or objective.advance(_sample(WheelControl.SECURED, false, 1.0, true)) != Phase.READY_AT_WHEEL:
		return _fail("A stale interact, lost control or early flow authorized a release.")
	if objective.advance(_sample(WheelControl.SECURED, true, 1.0, true)) != Phase.RELEASING \
		or objective.release_progress != 0.0 or not objective.withdrawal_ordered or _withdrawals != 1:
		return _fail("The first authorized interact did not order exactly one withdrawal before advancing flow.")

	objective.advance(_sample(WheelControl.SECURED, true, 0.25))
	if not is_equal_approx(objective.release_progress, 0.25) or _withdrawals != 1:
		return _fail("Secured control failed to accumulate release credit or ordered a second withdrawal.")
	var contested := _sample(WheelControl.CONTESTED, true, 1.0, true)
	for i in range(240):
		if objective.advance(contested) != Phase.PAUSED or not is_equal_approx(objective.release_progress, 0.25):
			return _fail("Contest progressed flow or caused a hidden time-based defeat.")
	if objective.advance(_sample(WheelControl.UNSECURED, false, 1.0)) != Phase.PAUSED or _unlocks != 0:
		return _fail("An empty wheel counted as held by Orc troops.")
	for value in [NAN, INF, -0.1]:
		if objective.advance(_sample(WheelControl.SECURED, false, value)) != Phase.RELEASING:
			return _fail("Recapturing the wheel required a new interact.")
	if not is_equal_approx(objective.release_progress, 0.25):
		return _fail("Invalid release credit changed the river state.")
	if objective.advance(_sample(WheelControl.SECURED, false, 0.35)) != Phase.RELEASING \
		or not is_equal_approx(objective.release_progress, 0.60) or _withdrawals != 1:
		return _fail("A cleared contest did not resume from the previous progress.")
	if objective.advance(_sample(WheelControl.SECURED, false, 2.0, true)) != Phase.EXTRACT \
		or objective.release_progress != 1.0 or _unlocks != 1:
		return _fail("Reaching river stage must unlock, not auto-complete, the high-bank objective.")
	if objective.advance(_sample(WheelControl.UNSECURED)) != Phase.EXTRACT or _unlocks != 1:
		return _fail("The exit did not stay unlocked after the release was complete.")
	if objective.advance(_sample(WheelControl.UNSECURED, false, 0.0, true)) != Phase.SUCCEEDED:
		return _fail("Raska could not extract after reaching the required river stage.")
	var late_defeat := _sample(WheelControl.CONTESTED)
	late_defeat.raska_fell = true
	if objective.advance(late_defeat) != Phase.SUCCEEDED or objective.failure != Failure.NONE:
		return _fail("A terminal win was not stable.")

	objective.restart()
	if objective.phase != Phase.SECURE_SPILLWAY or objective.release_progress != 0.0 \
		or objective.withdrawal_ordered or objective.failure != Failure.NONE:
		return _fail("Retry did not clear the attempt state.")
	_start_release(objective)
	for i in range(12):
		objective.advance(_sample(WheelControl.SECURED, true, 0.0))
	if _withdrawals != 2 or _unlocks != 1 or not objective.withdrawal_ordered:
		return _fail("Retry must emit its own withdrawal exactly once and not re-emit the exit event.")
	for i in range(10):
		objective.advance(_sample(WheelControl.SECURED, false, 0.1))
	if objective.phase != Phase.EXTRACT or objective.release_progress != 1.0 or _unlocks != 2:
		return _fail("Decimal release increments did not reach the same normalized threshold on retry.")
	print("Verified Spanwater capture, Raska interaction, one withdrawal per attempt, pause/resume, river stage and extraction.")
	return true


func _check_failure_precedence() -> bool:
	var objective := Objective.new()
	var shutdown := _sample(WheelControl.CONTESTED, false, 1.0, true)
	shutdown.shutdown_confirmed = true
	if objective.advance(shutdown) != Phase.SECURE_SPILLWAY:
		return _fail("A closed pre-battle spillway was treated as defeat.")
	_start_release(objective)
	objective.advance(_sample(WheelControl.SECURED, false, 0.75))
	objective.advance(_sample(WheelControl.CONTESTED))
	shutdown.wheel_control = WheelControl.SECURED
	if objective.advance(shutdown) != Phase.FAILED or objective.failure != Failure.SPILLWAY_SHUT \
		or objective.release_progress != 0.75:
		return _fail("A confirmed physical shutdown did not take precedence over same-tick release progress.")
	if objective.advance(_sample(WheelControl.SECURED, true, 1.0, true)) != Phase.FAILED:
		return _fail("A terminal loss could be continued without retry.")

	objective.restart()
	_start_release(objective)
	objective.advance(_sample(WheelControl.SECURED, false, 1.0))
	shutdown.wheel_control = WheelControl.CONTESTED
	shutdown.raska_at_high_bank = false
	if objective.advance(shutdown) != Phase.EXTRACT or objective.failure != Failure.NONE:
		return _fail("A later shutdown erased an already-completed release.")
	shutdown.raska_at_high_bank = true
	shutdown.raska_fell = true
	if objective.advance(shutdown) != Phase.FAILED or objective.failure != Failure.RASKA_FELL:
		return _fail("Raska falling at the exit did not take precedence over extraction.")
	print("Verified only an observed shutdown can fail the unfinished release, with defeat taking priority over extraction.")
	return true


func _start_release(objective: Objective) -> void:
	objective.advance(_sample(WheelControl.SECURED))
	objective.advance(_sample(WheelControl.SECURED, true))


func _sample(control: WheelControl, interact := false, credit := 0.0, exit := false) -> Objective.Observation:
	var observation := Objective.Observation.new()
	observation.wheel_control = control
	observation.raska_opens_spillway = interact
	observation.river_credit = credit
	observation.raska_at_high_bank = exit
	return observation


func _fail(message: String) -> bool:
	push_error(message)
	return false
