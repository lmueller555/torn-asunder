extends RefCounted
## Objective rules for Grain on Credit. Battlefield movement, input and combat provide the observations.

const MISSION_ID := &"mara_grain_crossing"
const SEED_ONLY := &"seed_only"
const BREAD_ONLY := &"bread_only"
const BOTH := &"both"

enum Cart { SEED, BREAD }
enum CartState { STAGED, EN_ROUTE, SECURED, TURNED_BACK, LOST }
enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Failure { NONE, HERO_FELL, NO_DELIVERY }


class CartReport:
	var dispatch_ordered := false
	## The intact cart reached its own receiving yard, not the other delivery's yard.
	var at_receiving_yard := false
	## A valid withdrawal order resolves the cart for this mission without making it travel home first.
	var turn_back_ordered := false
	var definitively_lost := false


class Observation:
	var seed := CartReport.new()
	var bread := CartReport.new()
	var hero_fell := false


var outcome: Outcome:
	get:
		return _outcome

var failure: Failure:
	get:
		return _failure

## Stable mission-scoped debrief ID. Empty until a successful resolution.
var clear_result: StringName:
	get:
		if _outcome != Outcome.SUCCEEDED:
			return &""
		if _carts[Cart.SEED] == CartState.SECURED:
			return BOTH if _carts[Cart.BREAD] == CartState.SECURED else SEED_ONLY
		return BREAD_ONLY

var _carts: Array[CartState] = [CartState.STAGED, CartState.STAGED]
var _outcome := Outcome.ACTIVE
var _failure := Failure.NONE


func cart_state(cart: Cart) -> CartState:
	return _carts[cart]


## Hero defeat takes priority over same-tick delivery. Both carts are then resolved
## from the same tick before the mission can succeed or fail.
func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.hero_fell:
		_outcome = Outcome.FAILED
		_failure = Failure.HERO_FELL
		return _outcome

	_advance_cart(Cart.SEED, observation.seed)
	_advance_cart(Cart.BREAD, observation.bread)
	if not _is_resolved(_carts[Cart.SEED]) or not _is_resolved(_carts[Cart.BREAD]):
		return _outcome
	if _carts[Cart.SEED] == CartState.SECURED or _carts[Cart.BREAD] == CartState.SECURED:
		_outcome = Outcome.SUCCEEDED
	else:
		_outcome = Outcome.FAILED
		_failure = Failure.NO_DELIVERY
	return _outcome


func restart() -> void:
	_carts[Cart.SEED] = CartState.STAGED
	_carts[Cart.BREAD] = CartState.STAGED
	_outcome = Outcome.ACTIVE
	_failure = Failure.NONE


func _advance_cart(cart: Cart, report: CartReport) -> void:
	var state := _carts[cart]
	if _is_resolved(state):
		return
	# Loss defeats a simultaneous arrival. An intact arrival beats a turn-back
	# order, and a turn-back order beats dispatch or further movement.
	if report.definitively_lost:
		_carts[cart] = CartState.LOST
	elif state == CartState.EN_ROUTE and report.at_receiving_yard:
		_carts[cart] = CartState.SECURED
	elif report.turn_back_ordered:
		_carts[cart] = CartState.TURNED_BACK
	elif state == CartState.STAGED and report.dispatch_ordered:
		_carts[cart] = CartState.EN_ROUTE


func _is_resolved(state: CartState) -> bool:
	return state in [CartState.SECURED, CartState.TURNED_BACK, CartState.LOST]
