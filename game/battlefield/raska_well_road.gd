extends RefCounted
## Objective rules for The Second Bucket. Loading, route safety and combat
## belong to the battlefield; only actual cart departures, arrivals and losses count.

const MISSION_ID := &"orc_well_road"

enum Cart { UPPER, LOWER }
enum CartState { LOADING, READY, EN_ROUTE, SAFE, LOST }
enum Route { NONE, SALT_ROAD, WASH }
enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Failure { NONE, RASKA_INCAPACITATED, UPPER_CART_LOST, LOWER_CART_LOST, BOTH_CARTS_LOST }


class CartReport:
	## A new dispatch or reroute order. No order is queued if it is not admitted.
	var requested_route := Route.NONE
	## Battlefield validation for this order, including terrain or lane restrictions.
	## Cavalry pressure alone does not report a definitive cart loss.
	var route_admitted := false
	## This cart itself reached the Basin exit intact while en route.
	var at_basin_exit := false
	var definitively_lost := false


class Observation:
	var upper := CartReport.new()
	var lower := CartReport.new()
	## The loading scene confirms that the households are aboard the lower cart.
	var lower_households_aboard := false
	var raska_incapacitated := false


var outcome: Outcome:
	get:
		return _outcome

var failure: Failure:
	get:
		return _failure

var _states: Array[CartState] = [CartState.READY, CartState.LOADING]
var _routes: Array[Route] = [Route.NONE, Route.NONE]
var _outcome := Outcome.ACTIVE
var _failure := Failure.NONE


func cart_state(cart: Cart) -> CartState:
	return _states[cart]


## Last accepted route, or NONE until dispatch. The scene draws and follows it.
func route_for(cart: Cart) -> Route:
	return _routes[cart]


func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.raska_incapacitated:
		return _fail(Failure.RASKA_INCAPACITATED)

	# Take both physical reports before deciding the mission. Loss beats arrival
	# for that cart; a genuine same-tick arrival of the other cart still counts.
	_observe_cart(Cart.UPPER, observation.upper)
	_observe_cart(Cart.LOWER, observation.lower)
	var upper_lost := _states[Cart.UPPER] == CartState.LOST
	var lower_lost := _states[Cart.LOWER] == CartState.LOST
	if upper_lost and lower_lost:
		return _fail(Failure.BOTH_CARTS_LOST)
	if upper_lost or lower_lost:
		return _fail(Failure.UPPER_CART_LOST if upper_lost else Failure.LOWER_CART_LOST)
	if _states[Cart.UPPER] == CartState.SAFE and _states[Cart.LOWER] == CartState.SAFE:
		_outcome = Outcome.SUCCEEDED
		return _outcome

	_order_cart(Cart.UPPER, observation.upper)
	_order_cart(Cart.LOWER, observation.lower)
	# Boarding first changes the visible state. A premature or same-tick
	# order cannot leave automatically; the ready lower cart needs a new order.
	if _states[Cart.LOWER] == CartState.LOADING and observation.lower_households_aboard:
		_states[Cart.LOWER] = CartState.READY
	return _outcome


func restart() -> void:
	_states[Cart.UPPER] = CartState.READY
	_states[Cart.LOWER] = CartState.LOADING
	_routes[Cart.UPPER] = Route.NONE
	_routes[Cart.LOWER] = Route.NONE
	_outcome = Outcome.ACTIVE
	_failure = Failure.NONE


func _observe_cart(cart: Cart, report: CartReport) -> void:
	if _states[cart] in [CartState.SAFE, CartState.LOST]:
		return
	if report.definitively_lost:
		_states[cart] = CartState.LOST
	elif _states[cart] == CartState.EN_ROUTE and report.at_basin_exit:
		_states[cart] = CartState.SAFE


func _order_cart(cart: Cart, report: CartReport) -> void:
	if _states[cart] not in [CartState.READY, CartState.EN_ROUTE] or not report.route_admitted:
		return
	if report.requested_route in [Route.SALT_ROAD, Route.WASH]:
		_routes[cart] = report.requested_route
		_states[cart] = CartState.EN_ROUTE


func _fail(reason: Failure) -> Outcome:
	_failure = reason
	_outcome = Outcome.FAILED
	return _outcome
