extends RefCounted
## Pure objective for An Audience, Not a Seizure. The adapter observes the
## hero at WritHandover, the neutral Keeper and actual yard/road contacts.

const MISSION_ID := &"sereth_pass_writ"
const POST_OCCUPATION_LIMIT_SECONDS := 6.0

enum Phase { CARRYING_WRIT, AWAITING_KEEPER, WITHDRAWING, SUCCEEDED, FAILED }
enum Reserve { UNALERTED, ALERTED, COMMITTED }
enum Failure { NONE, SERETH_FELL, KEEPER_DRIVEN_AWAY }


class Observation:
	## New field-hero interaction with the handover marker.
	var offer_writ := false
	var sereth_at_handover := false
	var keeper_at_post := false
	## A Keeper reply explicitly allowing a hearing at the assembly, referring
	## to the current pending offer. Zero means no observed reply.
	var keeper_accepts_offer_id := 0
	var sereth_at_withdrawal_rally := false
	var sereth_fell := false

	## Contest blocks handover. Only an uninterrupted hostile hold can drive
	## the Keeper away; contact, an approaching patrol or a standoff cannot.
	var post_contested := false
	var hostile_controls_post := false
	var elapsed_seconds := 0.0

	## Reports from the map, not automatic timers or route locks.
	var lookout_signaled := false
	var mounted_reserve_at_road := false


var phase: Phase:
	get:
		return _phase

var reserve: Reserve:
	get:
		return _reserve

var failure: Failure:
	get:
		return _failure

## A one-attempt offer, not acknowledgement from the Keeper.
var pending_offer_id: int:
	get:
		return _pending_offer_id

## The Keeper allowed a hearing at the valley assembly only. This is not
## vault admission, custody, use of the bridle, or consent from the dead.
var audience_granted: bool:
	get:
		return _audience_granted

var post_occupation_warned: bool:
	get:
		return _post_occupation_warned

var post_occupation_seconds: float:
	get:
		return _post_occupation_seconds


var _phase := Phase.CARRYING_WRIT
var _reserve := Reserve.UNALERTED
var _failure := Failure.NONE
var _pending_offer_id := 0
var _last_offer_id := 0
var _audience_granted := false
var _post_occupation_warned := false
var _post_occupation_seconds := 0.0


## Call once after world updates. Confirmed defeat beats same-update success.
## A reserve encounter can affect the battlefield, but is not a required duel.
func advance(observation: Observation) -> Phase:
	if _phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return _phase
	if observation.sereth_fell:
		return _fail(Failure.SERETH_FELL)
	_advance_reserve(observation)
	if _phase == Phase.WITHDRAWING:
		if observation.sereth_at_withdrawal_rally:
			_phase = Phase.SUCCEEDED
		return _phase
	if _post_lost(observation):
		return _fail(Failure.KEEPER_DRIVEN_AWAY)

	var handover_open := observation.sereth_at_handover and observation.keeper_at_post \
		and not observation.post_contested and not observation.hostile_controls_post
	if _phase == Phase.AWAITING_KEEPER:
		if not handover_open:
			_pending_offer_id = 0
			_phase = Phase.CARRYING_WRIT
		elif observation.keeper_accepts_offer_id == _pending_offer_id:
			_pending_offer_id = 0
			_audience_granted = true
			_clear_occupation()
			_phase = Phase.WITHDRAWING
		return _phase
	if observation.offer_writ and handover_open:
		_last_offer_id += 1
		_pending_offer_id = _last_offer_id
		_phase = Phase.AWAITING_KEEPER
	return _phase


func restart() -> void:
	_phase = Phase.CARRYING_WRIT
	_reserve = Reserve.UNALERTED
	_failure = Failure.NONE
	_pending_offer_id = 0
	# Do not recycle tokens: late replies from an interrupted offer or retry
	# cannot stamp a new offer on this same objective instance.
	_audience_granted = false
	_clear_occupation()


func _advance_reserve(observation: Observation) -> void:
	if _reserve == Reserve.UNALERTED and observation.lookout_signaled:
		_reserve = Reserve.ALERTED
	elif _reserve == Reserve.ALERTED and observation.mounted_reserve_at_road:
		_reserve = Reserve.COMMITTED


func _post_lost(observation: Observation) -> bool:
	if not observation.hostile_controls_post:
		_clear_occupation()
		return false
	if not _post_occupation_warned:
		# Always expose one warning update before assessing a loss.
		_post_occupation_warned = true
		return false
	var elapsed := observation.elapsed_seconds
	if is_finite(elapsed) and elapsed > 0.0:
		_post_occupation_seconds = minf(POST_OCCUPATION_LIMIT_SECONDS, _post_occupation_seconds + elapsed)
	return _post_occupation_seconds >= POST_OCCUPATION_LIMIT_SECONDS


func _clear_occupation() -> void:
	_post_occupation_warned = false
	_post_occupation_seconds = 0.0


func _fail(reason: Failure) -> Phase:
	_pending_offer_id = 0
	_failure = reason
	_phase = Phase.FAILED
	return _phase
