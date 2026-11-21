extends SceneTree

const Finale := preload("res://game/battlefield/sereth_no_proxy.gd")
const Assembly := Finale.Phase.AT_ASSEMBLY
const Splitting := Finale.Phase.RELEASING_COURT_TROOPS
const Intercepting := Finale.Phase.INTERCEPTING
const Terrace := Finale.Phase.CLEARING_TERRACE
const Won := Finale.Phase.SUCCEEDED
const Lost := Finale.Phase.FAILED
const Shelf := Finale.Route.SHELF
const Side := Finale.Route.SIDE


func _initialize() -> void:
	var passed := _check_public_refusal_and_split() and _check_both_routes() \
		and _check_pressured_terrace() and _check_losses_and_retry()
	if passed:
		print("Sereth finale: public refusal and roster split, live route-stall challenge, terrace recovery, custody and hero defeat priority, and retry passed.")
	quit(0 if passed else 1)


func _check_public_refusal_and_split() -> bool:
	var objective := Finale.new()
	var frame := _local_challenge(Shelf)
	frame.court_assignments_released = true
	frame.terrace_approach_clear = true
	frame.speaker_crossed_custody_line = true
	if objective.advance(frame) != Assembly or objective.refused_escort or objective.bid_halted:
		return _fail("Before refusal, an escort report, challenge, or terrace could change the outcome.")
	frame.refuse_escort = true
	frame.witnesses_present_at_refusal = true
	if objective.advance(frame) != Assembly:
		return _fail("A remote refusal counted.")
	frame.sereth_at_assembly = true
	frame.witnesses_present_at_refusal = false
	if objective.advance(frame) != Assembly:
		return _fail("An unwitnessed refusal counted.")
	frame.witnesses_present_at_refusal = true
	if objective.advance(frame) != Splitting or not objective.refused_escort or objective.bid_halted:
		return _fail("Refusal did not expose a separate roster split before interception.")
	frame.court_assignments_released = false
	if objective.advance(frame) != Splitting or objective.speaker_route != Finale.Route.NONE:
		return _fail("The intervening split was bypassed without the court troops leaving.")
	frame.court_assignments_released = true
	if objective.advance(frame) != Intercepting or objective.bid_halted:
		return _fail("The roster split did not start interception as a distinct update.")
	return true


func _check_both_routes() -> bool:
	for route in [Shelf, Side]:
		var other := Side if route == Shelf else Shelf
		var objective := _interception()
		var input := _local_challenge(other)
		input.challenge_speaker = false
		if objective.advance(input) != Intercepting or objective.speaker_route != other:
			return _fail("A stall without a fresh challenge halted the bid.")
		input = _local_challenge(route)
		input.escort_stalled_on = other
		if objective.advance(input) != Intercepting or objective.speaker_route != route:
			return _fail("A stale stall from another route was accepted or failed to show the change.")
		input.escort_stalled_on = route
		input.sereth_at_speaker = false
		if objective.advance(input) != Intercepting:
			return _fail("A remote challenge counted.")
		input.sereth_at_speaker = true
		input.speaker_before_custody_line = false
		if objective.advance(input) != Intercepting:
			return _fail("An unconfirmed location counted as being on the safe side of custody.")
		input.speaker_before_custody_line = true
		if objective.advance(input) != Terrace or not objective.bid_halted:
			return _fail("A local challenge before custody did not halt a genuinely stalled escort.")
		if objective.advance(Finale.Observation.new()) != Terrace:
			return _fail("The halted bid won while the terrace approach was uncleared.")
		var clear := Finale.Observation.new()
		clear.terrace_approach_clear = true
		clear.speaker_crossed_custody_line = true
		if objective.advance(clear) != Won or objective.failure != Finale.Failure.NONE:
			return _fail("Clearing the approach did not finish the halted bid independently.")
		clear.sereth_fell = true
		if objective.advance(clear) != Won:
			return _fail("An already completed mission was not terminal.")
	return true


func _check_pressured_terrace() -> bool:
	var objective := _interception()
	var input := Finale.Observation.new()
	input.elapsed_seconds = 90.0
	for _step in range(8):
		if objective.advance(input) != Intercepting or objective.occupation_warned:
			return _fail("A merely blocked approach timed out even without a real hostile hold.")
	input = _local_challenge(Shelf)
	input.hostiles_control_witness_position = true
	input.elapsed_seconds = 90.0
	input.terrace_approach_clear = true
	if objective.advance(input) != Terrace or not objective.occupation_warned or objective.occupation_seconds != 0.0:
		return _fail("A first hostile hold was not warned and recoverable.")
	input.elapsed_seconds = Finale.TERRACE_OCCUPATION_LIMIT_SECONDS * 0.75
	if objective.advance(input) != Terrace or objective.occupation_seconds != input.elapsed_seconds:
		return _fail("Short pressure or contradictory access awarded an immediate result.")
	input.elapsed_seconds = NAN
	if objective.advance(input) != Terrace or not is_finite(objective.occupation_seconds):
		return _fail("Invalid timing corrupted the hold clock.")
	input.hostiles_control_witness_position = false
	input.terrace_approach_clear = false
	if objective.advance(input) != Terrace or objective.occupation_warned or objective.occupation_seconds != 0.0:
		return _fail("Breaking a hold did not reset the warning without undoing the challenge.")
	input.hostiles_control_witness_position = true
	input.elapsed_seconds = Finale.TERRACE_OCCUPATION_LIMIT_SECONDS * 0.75
	if objective.advance(input) != Terrace or objective.advance(input) != Terrace:
		return _fail("Separate short hostile holds were added into one continuous defeat.")
	input.hostiles_control_witness_position = false
	input.terrace_approach_clear = true
	return objective.advance(input) == Won or _fail("A cleared terrace approach after interrupted threats did not win.")


func _check_losses_and_retry() -> bool:
	var objective := _interception()
	var input := _local_challenge(Side)
	input.speaker_crossed_custody_line = true
	input.terrace_approach_clear = true
	if objective.advance(input) != Lost or objective.failure != Finale.Failure.SPEAKER_CROSSED_CUSTODY_LINE \
			or objective.bid_halted:
		return _fail("Actual custody crossing did not beat a same-update challenge.")
	if objective.advance(Finale.Observation.new()) != Lost:
		return _fail("A confirmed crossing defeat was not terminal.")
	objective.restart()
	if objective.phase != Assembly or objective.refused_escort or objective.bid_halted \
			or objective.speaker_route != Finale.Route.NONE or objective.failure != Finale.Failure.NONE \
			or objective.occupation_warned or objective.occupation_seconds != 0.0:
		return _fail("Retry carried a refusal, route, warning, or outcome to the next attempt.")
	_interception(objective)
	input = _local_challenge(Shelf)
	input.hostiles_control_witness_position = true
	input.elapsed_seconds = Finale.TERRACE_OCCUPATION_LIMIT_SECONDS
	input.challenge_speaker = false
	objective.advance(input)
	input.challenge_speaker = true
	if objective.advance(input) != Lost or objective.failure != Finale.Failure.WITNESS_POSITION_LOST \
			or objective.bid_halted:
		return _fail("Confirmed uninterrupted witness-position loss did not beat a same-update challenge.")
	objective.restart()
	_interception(objective)
	objective.advance(_local_challenge(Side))
	input = Finale.Observation.new()
	input.hostiles_control_witness_position = true
	input.elapsed_seconds = Finale.TERRACE_OCCUPATION_LIMIT_SECONDS
	if objective.advance(input) != Terrace or objective.advance(input) != Lost \
			or objective.failure != Finale.Failure.WITNESS_POSITION_LOST:
		return _fail("Stopping the bid removed a still-unsecured terrace from the mission.")
	objective.restart()
	_interception(objective)
	objective.advance(_local_challenge(Side))
	input = Finale.Observation.new()
	input.terrace_approach_clear = true
	input.sereth_fell = true
	return (objective.advance(input) == Lost and objective.failure == Finale.Failure.SERETH_FELL) \
		or _fail("Sereth's actual loss did not beat clearing the terrace.")


func _interception(objective := Finale.new()) -> Finale:
	var start := Finale.Observation.new()
	start.refuse_escort = true
	start.sereth_at_assembly = true
	start.witnesses_present_at_refusal = true
	objective.advance(start)
	start.court_assignments_released = true
	objective.advance(start)
	return objective


func _local_challenge(route: Finale.Route) -> Finale.Observation:
	var input := Finale.Observation.new()
	input.challenge_speaker = true
	input.sereth_at_speaker = true
	input.speaker_before_custody_line = true
	input.speaker_route = route
	input.escort_stalled_on = route
	return input


func _fail(message: String) -> bool:
	push_error(message)
	return false
