extends SceneTree

const Cut := preload("res://game/battlefield/sereth_voices_at_the_cut.gd")
const Account := Cut.AccountStatus
const Bundle := Cut.BundleStatus
const InputAction := Cut.Interaction
const ACTIVE := Cut.Outcome.ACTIVE
const SUCCEEDED := Cut.Outcome.SUCCEEDED
const FAILED := Cut.Outcome.FAILED


func _initialize() -> void:
	var passed := _check_witness_relay_and_pause() and _check_bundle_first() \
		and _check_theft_drop_and_recovery() and _check_extraction_priority_and_retry()
	if passed:
		print("Sereth at the Cut: distinct account and records, local contact gates, contested filing, recoverable theft, confirmed losses, and retry passed.")
	quit(0 if passed else 1)


func _check_witness_relay_and_pause() -> bool:
	var cut := Cut.new()
	var input := Cut.Observation.new()
	input.hero_interaction = InputAction.RELAY_ACCOUNT
	input.sereth_at_account_entry = true
	input.clerk_at_entry = true
	if cut.advance(input) != ACTIVE or cut.account_status != Account.UNHEARD:
		return _fail("A clerk interaction filed an account Sereth had not yet received.")
	input.hero_interaction = InputAction.LISTEN_TO_IREN
	if cut.advance(input) != ACTIVE or cut.account_status != Account.UNHEARD:
		return _fail("An interaction away from Iren's witness marker counted.")
	input.sereth_at_witness_account = true
	if cut.advance(input) != ACTIVE or cut.account_status != Account.HEARD:
		return _fail("A firsthand account at the proper contact did not stay distinct from relay.")
	input.hero_interaction = InputAction.RELAY_ACCOUNT
	input.sereth_at_account_entry = false
	if cut.advance(input) != ACTIVE or cut.account_status != Account.HEARD:
		return _fail("The account was relayed from the stair without reaching AccountEntry.")
	input.sereth_at_account_entry = true
	input.clerk_at_entry = false
	if cut.advance(input) != ACTIVE or cut.account_status != Account.HEARD:
		return _fail("A relay succeeded without the clerk.")
	input.clerk_at_entry = true
	input.record_room_contested = true
	if cut.advance(input) != ACTIVE or cut.account_status != Account.RELAYED:
		return _fail("Relay did not retain the account for the clerk, or filed under contest.")
	for _tick in range(60):
		if cut.advance(input) != ACTIVE or cut.account_status != Account.RELAYED:
			return _fail("A contested room filed the account or silently failed the mission.")
	input = Cut.Observation.new()
	if cut.advance(input) != ACTIVE or cut.account_status != Account.RELAYED:
		return _fail("Removing the contest alone filed the account without the clerk.")
	input.clerk_at_entry = true
	if cut.advance(input) != ACTIVE or cut.account_status != Account.FILED or cut.bundle_status != Bundle.EXPOSED:
		return _fail("Recovered filing did not persist independently of the actual bundle.")
	_pick_up(cut)
	return (_secure(cut) == SUCCEEDED and cut.bundle_status == Bundle.SECURED) \
		or _fail("Delivering the bundle after filing did not finish the two required tracks.")


func _check_bundle_first() -> bool:
	var cut := Cut.new()
	var input := Cut.Observation.new()
	input.hero_interaction = InputAction.PICK_UP_BUNDLE
	input.sereth_at_bundle_secure = true
	if cut.advance(input) != ACTIVE or cut.bundle_status != Bundle.EXPOSED:
		return _fail("Hero touching the room did not physically reach the exposed bundle.")
	if _secure(cut) != ACTIVE or cut.bundle_status != Bundle.EXPOSED:
		return _fail("Securing in an empty room fabricated the bundle.")
	_pick_up(cut)
	input.hero_interaction = InputAction.SECURE_BUNDLE
	input.sereth_at_bundle_secure = false
	if cut.advance(input) != ACTIVE or cut.bundle_status != Bundle.WITH_SERETH:
		return _fail("A carrier deposited records away from the secure point.")
	input.sereth_at_bundle_secure = true
	input.record_room_contested = true
	if cut.advance(input) != ACTIVE or cut.bundle_status != Bundle.WITH_SERETH:
		return _fail("A contested room accepted the records as secure.")
	if _secure(cut) != ACTIVE or cut.bundle_status != Bundle.SECURED or cut.account_status != Account.UNHEARD:
		return _fail("Securing records alone cleared the mission or fabricated testimony.")
	var pressure := Cut.Observation.new()
	pressure.record_room_contested = true
	if cut.advance(pressure) != ACTIVE or cut.bundle_status != Bundle.SECURED:
		return _fail("Room contest alone counted as an enemy seizure.")
	_relay(cut)
	var clerk := Cut.Observation.new()
	clerk.clerk_at_entry = true
	return (cut.advance(clerk) == SUCCEEDED and cut.account_status == Account.FILED) \
		or _fail("A completed account after securing records did not finish the mission.")


func _check_theft_drop_and_recovery() -> bool:
	var cut := Cut.new()
	_relay(cut)
	var theft := Cut.Observation.new()
	theft.enemy_took_bundle = true
	theft.enemy_carrier_at_retreat_exit = true
	theft.clerk_at_entry = true
	if cut.advance(theft) != ACTIVE or cut.bundle_status != Bundle.WITH_ENEMY or cut.account_status != Account.FILED:
		return _fail("A seizure at the cut was incorrectly treated as a confirmed extraction.")
	if cut.advance(Cut.Observation.new()) != ACTIVE or cut.bundle_status != Bundle.WITH_ENEMY:
		return _fail("Enemy custody alone failed the mission or erased the captured records.")
	var dropped := Cut.Observation.new()
	dropped.enemy_dropped_bundle = true
	if cut.advance(dropped) != ACTIVE or cut.bundle_status != Bundle.DROPPED:
		return _fail("Interception did not leave a recoverable bundle.")
	dropped = Cut.Observation.new()
	dropped.enemy_carrier_at_retreat_exit = true
	if cut.advance(dropped) != ACTIVE or cut.bundle_status != Bundle.DROPPED:
		return _fail("An empty handed enemy reaching the retreat exit after a drop caused a defeat.")
	_pick_up(cut)
	if cut.account_status != Account.FILED or _secure(cut) != SUCCEEDED:
		return _fail("Sereth could not physically recover the dropped records without replaying the account.")
	return true


func _check_extraction_priority_and_retry() -> bool:
	var cut := Cut.new()
	_pick_up(cut)
	_secure(cut)
	_relay(cut)
	var theft := Cut.Observation.new()
	theft.enemy_took_bundle = true
	if cut.advance(theft) != ACTIVE or cut.bundle_status != Bundle.SECURED:
		return _fail("A secure occupied room lost the bundle to an unconfirmed raid.")
	theft.record_room_contested = true
	if cut.advance(theft) != ACTIVE or cut.bundle_status != Bundle.WITH_ENEMY:
		return _fail("An actual enemy seizure did not make the room's records recoverable.")
	var loss := Cut.Observation.new()
	loss.clerk_at_entry = true
	loss.enemy_carrier_at_retreat_exit = true
	if cut.advance(loss) != FAILED or cut.failure != Cut.Failure.BUNDLE_EXTRACTED \
			or cut.bundle_status != Bundle.EXTRACTED or cut.account_status != Account.RELAYED:
		return _fail("Confirmed extraction did not beat same-update filing.")
	if cut.advance(Cut.Observation.new()) != FAILED:
		return _fail("A confirmed extraction was not terminal.")
	cut.restart()
	if cut.outcome != ACTIVE or cut.failure != Cut.Failure.NONE or cut.account_status != Account.UNHEARD \
			or cut.bundle_status != Bundle.EXPOSED:
		return _fail("Retry retained account, extraction or defeat state.")
	_pick_up(cut)
	_secure(cut)
	_relay(cut)
	loss = Cut.Observation.new()
	loss.clerk_at_entry = true
	loss.sereth_fell = true
	if cut.advance(loss) != FAILED or cut.failure != Cut.Failure.SERETH_FELL or cut.account_status != Account.RELAYED:
		return _fail("Sereth's defeat did not beat the last required filing.")
	cut.restart()
	_pick_up(cut)
	_secure(cut)
	_relay(cut)
	loss.sereth_fell = false
	if cut.advance(loss) != SUCCEEDED:
		return _fail("A new attempt could not complete both objectives.")
	loss.sereth_fell = true
	return cut.advance(loss) == SUCCEEDED or _fail("A completed mission was not terminal.")


func _relay(cut: Cut) -> void:
	var input := Cut.Observation.new()
	input.hero_interaction = InputAction.LISTEN_TO_IREN
	input.sereth_at_witness_account = true
	cut.advance(input)
	input.hero_interaction = InputAction.RELAY_ACCOUNT
	input.sereth_at_witness_account = false
	input.sereth_at_account_entry = true
	input.clerk_at_entry = true
	cut.advance(input)


func _pick_up(cut: Cut) -> void:
	var input := Cut.Observation.new()
	input.hero_interaction = InputAction.PICK_UP_BUNDLE
	input.sereth_at_bundle = true
	cut.advance(input)


func _secure(cut: Cut) -> Cut.Outcome:
	var input := Cut.Observation.new()
	input.hero_interaction = InputAction.SECURE_BUNDLE
	input.sereth_at_bundle_secure = true
	return cut.advance(input)


func _fail(message: String) -> bool:
	push_error(message)
	return false
