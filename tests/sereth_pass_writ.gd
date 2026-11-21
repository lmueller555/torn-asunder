extends SceneTree

const Writ := preload("res://game/battlefield/sereth_pass_writ.gd")
const Phase := Writ.Phase
const Reserve := Writ.Reserve
const Failure := Writ.Failure


func _initialize() -> void:
	var passed := _check_contact_and_observed_permission() and _check_interrupted_offer() \
		and _check_occupation_and_recovery() and _check_reserve_independence() and _check_losses_and_retry()
	if passed:
		print("Sereth's writ: local offer and correlated Keeper reply, distinct rally, recoverable occupation warning, optional reserve, terminal losses and retry passed.")
	quit(0 if passed else 1)


func _check_contact_and_observed_permission() -> bool:
	var writ := Writ.new()
	var observation := Writ.Observation.new()
	observation.sereth_at_withdrawal_rally = true
	observation.keeper_accepts_offer_id = 1
	for _tick in range(40):
		observation.elapsed_seconds = 60.0
		if writ.advance(observation) != Phase.CARRYING_WRIT or writ.audience_granted:
			return _fail("Idle time, premature rally contact or an unsolicited reply changed the objective.")
	observation.offer_writ = true
	if writ.advance(observation) != Phase.CARRYING_WRIT:
		return _fail("A remote interaction offered the writ.")
	observation.sereth_at_handover = true
	if writ.advance(observation) != Phase.CARRYING_WRIT:
		return _fail("An empty yard accepted an offer.")
	observation.keeper_at_post = true
	observation.post_contested = true
	if writ.advance(observation) != Phase.CARRYING_WRIT:
		return _fail("A contested yard accepted an offer.")
	observation.post_contested = false
	observation.offer_writ = false
	if writ.advance(observation) != Phase.CARRYING_WRIT:
		return _fail("Hero and Keeper contact or an unsolicited reply replaced deliberate input.")
	observation.offer_writ = true
	if writ.advance(observation) != Phase.AWAITING_KEEPER or writ.pending_offer_id <= 0 or writ.audience_granted:
		return _fail("The offer observation itself must never acknowledge the writ, even with a predicted ID.")
	observation.offer_writ = false
	observation.keeper_accepts_offer_id = 0
	if writ.advance(observation) != Phase.AWAITING_KEEPER or writ.audience_granted:
		return _fail("Proximity or waiting alone approved an audience.")
	observation.keeper_accepts_offer_id = writ.pending_offer_id
	if writ.advance(observation) != Phase.WITHDRAWING or not writ.audience_granted or writ.pending_offer_id != 0:
		return _fail("A neutral reply did not grant an audience, or simultaneous rally contact skipped withdrawal.")
	return (writ.advance(Writ.Observation.new()) == Phase.WITHDRAWING and _rally(writ) == Phase.SUCCEEDED \
		and writ.reserve == Reserve.UNALERTED) or _fail("An uncontested withdrawal could not finish without fighting.")


func _check_interrupted_offer() -> bool:
	var writ := Writ.new()
	var first_id := _offer(writ)
	var observation := _handover()
	observation.keeper_accepts_offer_id = first_id
	observation.sereth_at_handover = false
	if writ.advance(observation) != Phase.CARRYING_WRIT or writ.pending_offer_id != 0 or writ.audience_granted:
		return _fail("A reply recorded the offer after Sereth left the handover.")
	var second_id := _offer(writ)
	if second_id <= first_id:
		return _fail("An interrupted offer token was reused.")
	observation = _handover()
	observation.keeper_accepts_offer_id = first_id
	if writ.advance(observation) != Phase.AWAITING_KEEPER or writ.audience_granted:
		return _fail("A stale reply approved a different offer.")
	observation.keeper_at_post = false
	observation.keeper_accepts_offer_id = second_id
	if writ.advance(observation) != Phase.CARRYING_WRIT or writ.audience_granted:
		return _fail("An absent Keeper approved an offer.")
	return true


func _check_occupation_and_recovery() -> bool:
	var writ := Writ.new()
	var pressure := _handover()
	pressure.post_contested = true
	pressure.elapsed_seconds = 100.0
	if writ.advance(pressure) != Phase.CARRYING_WRIT or writ.post_occupation_warned:
		return _fail("A standoff counted as a hostile hold.")
	pressure.hostile_controls_post = true
	pressure.post_contested = false
	pressure.offer_writ = true
	if writ.advance(pressure) != Phase.CARRYING_WRIT or not writ.post_occupation_warned or writ.post_occupation_seconds != 0.0:
		return _fail("A hostile hold bypassed its visible warning or accepted a writ.")
	for bad: float in [-1.0, INF, NAN]:
		pressure.elapsed_seconds = bad
		if writ.advance(pressure) != Phase.CARRYING_WRIT or writ.post_occupation_seconds != 0.0:
			return _fail("An invalid elapsed time added occupation credit.")
	pressure.elapsed_seconds = Writ.POST_OCCUPATION_LIMIT_SECONDS - 0.5
	if writ.advance(pressure) != Phase.CARRYING_WRIT or not writ.post_occupation_warned:
		return _fail("A warning denied the player time to break the hold.")
	if writ.advance(Writ.Observation.new()) != Phase.CARRYING_WRIT or writ.post_occupation_warned \
			or writ.post_occupation_seconds != 0.0:
		return _fail("Breaking the hostile hold did not reset its warning and duration.")
	pressure.elapsed_seconds = 1.0
	if writ.advance(pressure) != Phase.CARRYING_WRIT or writ.advance(pressure) != Phase.CARRYING_WRIT:
		return _fail("A new hold inherited the old duration.")
	var id := _offer(writ)
	if id == 0 or not _reply(writ, id) or writ.post_occupation_warned:
		return _fail("A relieved post could not take the writ.")
	pressure.elapsed_seconds = 100.0
	if writ.advance(pressure) != Phase.WITHDRAWING or writ.advance(pressure) != Phase.WITHDRAWING:
		return _fail("A later occupation revoked a genuine, already delivered writ.")
	return _rally(writ) == Phase.SUCCEEDED or _fail("Relief route did not finish.")


func _check_reserve_independence() -> bool:
	var writ := Writ.new()
	var road := Writ.Observation.new()
	road.mounted_reserve_at_road = true
	if writ.advance(road) != Phase.CARRYING_WRIT or writ.reserve != Reserve.UNALERTED:
		return _fail("A road report alone fabricated the lookout's warning.")
	road.lookout_signaled = true
	if writ.advance(road) != Phase.CARRYING_WRIT or writ.reserve != Reserve.ALERTED:
		return _fail("The lookout report did not expose an alert before commitment.")
	if writ.advance(Writ.Observation.new()) != Phase.CARRYING_WRIT or writ.reserve != Reserve.ALERTED:
		return _fail("Commitment happened without observing the reserve on the road.")
	if writ.advance(road) != Phase.CARRYING_WRIT or writ.reserve != Reserve.COMMITTED:
		return _fail("A genuine reserve advance did not become visible pressure.")
	var id := _offer(writ)
	return (id > 0 and _reply(writ, id) and _rally(writ) == Phase.SUCCEEDED \
		and writ.reserve == Reserve.COMMITTED) or _fail("The reserve became a required kill or immediate defeat.")


func _check_losses_and_retry() -> bool:
	var writ := Writ.new()
	var id := _offer(writ)
	var pressure := _handover()
	pressure.hostile_controls_post = true
	pressure.lookout_signaled = true
	pressure.keeper_accepts_offer_id = id
	if writ.advance(pressure) != Phase.CARRYING_WRIT or writ.audience_granted or writ.pending_offer_id != 0:
		return _fail("A hostile takeover did not interrupt pending consent, or accepted it anyway.")
	pressure.elapsed_seconds = Writ.POST_OCCUPATION_LIMIT_SECONDS
	if writ.advance(pressure) != Phase.FAILED or writ.failure != Failure.KEEPER_DRIVEN_AWAY or writ.audience_granted:
		return _fail("An unbroken hostile hold failed to drive away the Keeper.")
	if _rally(writ) != Phase.FAILED:
		return _fail("A rally changed a terminal defeat.")
	writ.restart()
	if writ.phase != Phase.CARRYING_WRIT or writ.reserve != Reserve.UNALERTED or writ.failure != Failure.NONE \
			or writ.post_occupation_warned or writ.post_occupation_seconds != 0.0 or writ.pending_offer_id != 0:
		return _fail("Retry did not clear attempt-local pressure and failure.")
	var fresh_id := _offer(writ)
	if fresh_id <= id or not _reply(writ, fresh_id):
		return _fail("A fresh attempt could not record a valid new reply.")
	var fatal := Writ.Observation.new()
	fatal.sereth_fell = true
	fatal.sereth_at_withdrawal_rally = true
	if writ.advance(fatal) != Phase.FAILED or writ.failure != Failure.SERETH_FELL:
		return _fail("A falling Sereth cleared the simultaneous rally update.")
	writ.restart()
	if writ.audience_granted:
		return _fail("An accepted but failed attempt retained its audience in a new attempt.")
	fresh_id = _offer(writ)
	return (_reply(writ, fresh_id) and _rally(writ) == Phase.SUCCEEDED and writ.advance(fatal) == Phase.SUCCEEDED) \
		or _fail("A terminal clear was overwritten after the rally.")


func _handover() -> Writ.Observation:
	var observation := Writ.Observation.new()
	observation.sereth_at_handover = true
	observation.keeper_at_post = true
	return observation


func _offer(writ: Writ) -> int:
	var observation := _handover()
	observation.offer_writ = true
	return writ.pending_offer_id if writ.advance(observation) == Phase.AWAITING_KEEPER else 0


func _reply(writ: Writ, id: int) -> bool:
	var observation := _handover()
	observation.keeper_accepts_offer_id = id
	return writ.advance(observation) == Phase.WITHDRAWING and writ.audience_granted


func _rally(writ: Writ) -> Phase:
	var observation := Writ.Observation.new()
	observation.sereth_at_withdrawal_rally = true
	return writ.advance(observation)


func _fail(message: String) -> bool:
	push_error(message)
	return false
