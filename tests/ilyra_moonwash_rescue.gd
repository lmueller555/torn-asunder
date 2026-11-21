extends SceneTree

const Rescue := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const FORWARD := Rescue.Transfer.FORWARD
const AFT := Rescue.Transfer.AFT
const ACTIVE := Rescue.Outcome.ACTIVE
const SUCCEEDED := Rescue.Outcome.SUCCEEDED
const FAILED := Rescue.Outcome.FAILED
const STRANDED := Rescue.CrewStatus.STRANDED
const CROSSING := Rescue.CrewStatus.CROSSING
const PAUSED := Rescue.CrewStatus.PAUSED
const SAFE := Rescue.CrewStatus.SAFE
const LOST := Rescue.CrewStatus.LOST


func _initialize() -> void:
	var passed := _check_both_orders() and _check_contest() and _check_losses() and _check_cargo_and_retry()
	if passed:
		print("Verified both Moonwash transfer orders, contested pause/resume, crew and hero loss, optional cargo and retry.")
	quit(0 if passed else 1)


func _check_both_orders() -> bool:
	for first in [FORWARD, AFT]:
		var rescue := Rescue.new()
		var second := AFT if first == FORWARD else FORWARD
		var arriving := Rescue.Observation.new()
		arriving.forward.crew_at_receiving_deck = true
		arriving.aft.crew_at_receiving_deck = true
		arriving.hero_rigged_transfer = 8
		if rescue.advance(arriving) != ACTIVE or rescue.crew_status(first) != STRANDED \
				or rescue.crew_status(second) != STRANDED:
			return _fail("Neither an invalid rig target nor reported deck presence can start a transfer.")
		arriving.hero_rigged_transfer = first
		if rescue.advance(arriving) != ACTIVE or not rescue.line_is_rigged(first) \
				or rescue.line_is_rigged(second) or rescue.crew_status(first) != CROSSING:
			return _fail("One hero interaction should rig one line, not also deliver its crew.")
		arriving.hero_rigged_transfer = -1
		if rescue.advance(arriving) != ACTIVE or rescue.crew_status(first) != SAFE \
				or rescue.crew_status(second) != STRANDED or rescue.clear_result != &"":
			return _fail("One actual arrival or an unrigged crew must not complete the mission.")
		arriving.hero_rigged_transfer = second
		if rescue.advance(arriving) != ACTIVE or rescue.crew_status(second) != CROSSING:
			return _fail("The other transfer did not start from its own rigging interaction.")
		arriving.hero_rigged_transfer = -1
		if rescue.advance(arriving) != SUCCEEDED or not rescue.line_is_rigged(second) \
				or rescue.clear_result != Rescue.CREWS_ONLY:
			return _fail("Both crew arrivals must win without cargo regardless of their order.")
	return true


func _check_contest() -> bool:
	var rescue := Rescue.new()
	var blocked := Rescue.Observation.new()
	blocked.hero_rigged_transfer = FORWARD
	blocked.forward.receiving_point_contested = true
	blocked.forward.crew_at_receiving_deck = true
	rescue.advance(blocked)
	if not rescue.line_is_rigged(FORWARD) or rescue.crew_status(FORWARD) != PAUSED:
		return _fail("Rigging a contested transfer did not preserve the line and pause the crew.")
	blocked.hero_rigged_transfer = AFT
	rescue.advance(blocked)
	blocked.hero_rigged_transfer = -1
	blocked.aft.crew_at_receiving_deck = true
	if rescue.advance(blocked) != ACTIVE or rescue.crew_status(AFT) != SAFE:
		return _fail("Contest at one receiving point blocked the other crew's safety.")
	for _step in range(20):
		rescue.advance(blocked)
	if rescue.crew_status(FORWARD) != PAUSED:
		return _fail("A contested crew accepted an apparent arrival or advanced by time.")
	var resume := Rescue.Observation.new()
	resume.forward.crew_at_receiving_deck = true
	if rescue.advance(resume) != ACTIVE or rescue.crew_status(FORWARD) != CROSSING:
		return _fail("A clear receiving point should resume, not accept a stale deck report.")
	if rescue.advance(Rescue.Observation.new()) != ACTIVE:
		return _fail("Resumed crossing cannot finish without a physical arrival report.")
	blocked.aft.crew_at_receiving_deck = false
	if rescue.advance(blocked) != ACTIVE or rescue.crew_status(FORWARD) != PAUSED:
		return _fail("Renewed contest did not pause a moving transfer.")
	rescue.advance(Rescue.Observation.new())
	if rescue.advance(resume) != SUCCEEDED:
		return _fail("The recovered lane did not accept a new deck arrival without another rig.")
	return true


func _check_losses() -> bool:
	for transfer in [FORWARD, AFT]:
		var rescue := Rescue.new()
		_rig(rescue, transfer)
		var lost := Rescue.Observation.new()
		var report: Rescue.TransferReport = lost.forward if transfer == FORWARD else lost.aft
		report.crew_at_receiving_deck = true
		report.crew_definitively_lost = true
		if rescue.advance(lost) != FAILED or rescue.failure != Rescue.Failure.REQUIRED_CREW_LOST \
				or rescue.crew_status(transfer) != LOST or rescue.clear_result != &"":
			return _fail("A required crew loss did not beat the same-tick arrival.")
	var rescue := Rescue.new()
	_rig(rescue, FORWARD)
	_rig(rescue, AFT)
	var first_arrival := Rescue.Observation.new()
	first_arrival.forward.crew_at_receiving_deck = true
	rescue.advance(first_arrival)
	var after_safety := Rescue.Observation.new()
	after_safety.forward.crew_definitively_lost = true
	if rescue.advance(after_safety) != ACTIVE or rescue.crew_status(FORWARD) != SAFE:
		return _fail("A crew already delivered to safety leaked back into the loss check.")
	after_safety.aft.crew_at_receiving_deck = true
	after_safety.hero_fell = true
	after_safety.cargo_at_receiving_deck = true
	if rescue.advance(after_safety) != FAILED or rescue.failure != Rescue.Failure.HERO_FELL \
			or rescue.cargo_recovered or rescue.clear_result != &"":
		return _fail("Hero loss must take precedence over final delivery and cargo.")
	return true


func _check_cargo_and_retry() -> bool:
	var rescue := Rescue.new()
	var cargo := Rescue.Observation.new()
	cargo.cargo_at_receiving_deck = true
	if not rescue.clear_result.is_empty() or rescue.advance(cargo) != ACTIVE or not rescue.cargo_recovered:
		return _fail("Optional cargo needs its own state without revealing a successful debrief early.")
	_rig(rescue, FORWARD)
	_rig(rescue, AFT)
	var rescue_crews := Rescue.Observation.new()
	rescue_crews.forward.crew_at_receiving_deck = true
	rescue_crews.aft.crew_at_receiving_deck = true
	if rescue.advance(rescue_crews) != SUCCEEDED or rescue.clear_result != Rescue.CARGO_RECOVERED:
		return _fail("Delivered cargo was not available in the successful debrief result.")
	cargo.hero_fell = true
	cargo.aft.crew_definitively_lost = true
	if rescue.advance(cargo) != SUCCEEDED or rescue.clear_result != Rescue.CARGO_RECOVERED:
		return _fail("Post-clear reports corrupted the committed result.")
	rescue.restart()
	if rescue.outcome != ACTIVE or rescue.failure != Rescue.Failure.NONE or rescue.cargo_recovered \
			or rescue.line_is_rigged(FORWARD) or rescue.line_is_rigged(AFT) or rescue.clear_result != &"" \
			or rescue.crew_status(FORWARD) != STRANDED or rescue.crew_status(AFT) != STRANDED:
		return _fail("Retry retained lines, crew departures, cargo, or a terminal result.")
	_rig(rescue, AFT)
	_rig(rescue, FORWARD)
	if rescue.advance(rescue_crews) != SUCCEEDED or rescue.clear_result != Rescue.CREWS_ONLY:
		return _fail("A cargo-free retry could not clear with its own result.")
	cargo.hero_fell = false
	cargo.aft.crew_definitively_lost = false
	if rescue.advance(cargo) != SUCCEEDED or rescue.clear_result != Rescue.CREWS_ONLY:
		return _fail("Cargo landing after the victory rewrote the debrief.")
	return true


func _rig(rescue: Rescue, transfer: Rescue.Transfer) -> void:
	var observation := Rescue.Observation.new()
	observation.hero_rigged_transfer = transfer
	rescue.advance(observation)


func _fail(message: String) -> bool:
	push_error(message)
	return false
