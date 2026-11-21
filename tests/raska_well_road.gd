extends SceneTree

const Objective := preload("res://game/battlefield/raska_well_road.gd")
const Missions := preload("res://game/campaign_missions.gd")
const Cart := Objective.Cart
const State := Objective.CartState
const Route := Objective.Route
const Outcome := Objective.Outcome
const Failure := Objective.Failure


func _initialize() -> void:
	var passed := _check_boarding_and_routes()
	passed = _check_arrival_orders_and_retry() and passed
	passed = _check_loss_precedence() and passed
	quit(0 if passed else 1)


func _check_boarding_and_routes() -> bool:
	var record := Missions.mission_for_campaign("raska", String(Objective.MISSION_ID))
	if record.get("battlefield_id") != "red_basin_well_road":
		return _fail("The objective does not match the authored Orc campaign route.")
	var objective := Objective.new()
	var report := _order(Cart.UPPER, Route.SALT_ROAD)
	report.upper.at_basin_exit = true
	report.lower = _order(Cart.LOWER, Route.WASH).lower
	report.lower.at_basin_exit = true
	if objective.advance(report) != Outcome.ACTIVE or objective.cart_state(Cart.UPPER) != State.EN_ROUTE \
			or objective.cart_state(Cart.LOWER) != State.LOADING or objective.route_for(Cart.LOWER) != Route.NONE:
		return _fail("Upper must start on a legal order without counting spawn as delivery; Lower must wait to board.")

	report = _order(Cart.UPPER, Route.WASH, false)
	objective.advance(report)
	if objective.route_for(Cart.UPPER) != Route.SALT_ROAD:
		return _fail("A denied reroute replaced the active route.")
	objective.advance(_order(Cart.UPPER, Route.WASH))
	if objective.route_for(Cart.UPPER) != Route.WASH or objective.cart_state(Cart.UPPER) != State.EN_ROUTE:
		return _fail("A valid fallback route could not replace the original lane.")

	report = _order(Cart.LOWER, Route.SALT_ROAD)
	report.lower_households_aboard = true
	report.upper.at_basin_exit = true
	if objective.advance(report) != Outcome.ACTIVE or objective.cart_state(Cart.UPPER) != State.SAFE \
			or objective.cart_state(Cart.LOWER) != State.READY or objective.route_for(Cart.LOWER) != Route.NONE:
		return _fail("Boarding must first expose a distinct ready state; one safe cart cannot clear the mission.")
	report = _order(Cart.LOWER, Route.SALT_ROAD, false)
	for i in range(1200):
		if objective.advance(report) != Outcome.ACTIVE or objective.cart_state(Cart.LOWER) != State.READY:
			return _fail("A denied lane secretly dispatched or expired the loaded cart.")
	objective.advance(_order(Cart.LOWER, Route.SALT_ROAD))
	if objective.cart_state(Cart.LOWER) != State.EN_ROUTE or objective.route_for(Cart.LOWER) != Route.SALT_ROAD:
		return _fail("Independent legal dispatch after visible boarding was rejected.")
	report = Objective.Observation.new()
	report.lower.at_basin_exit = true
	if objective.advance(report) != Outcome.SUCCEEDED:
		return _fail("Two intact arrivals did not clear the objective with no optional unit positioning.")
	print("Verified immediate upper dispatch, confirmed lower boarding, denied/admitted routes, and both necessary arrivals.")
	return true


func _check_arrival_orders_and_retry() -> bool:
	var objective := Objective.new()
	var report := Objective.Observation.new()
	report.lower_households_aboard = true
	objective.advance(report)
	objective.advance(_order(Cart.LOWER, Route.WASH))
	report = Objective.Observation.new()
	report.lower.at_basin_exit = true
	if objective.advance(report) != Outcome.ACTIVE or objective.cart_state(Cart.LOWER) != State.SAFE \
			or objective.cart_state(Cart.UPPER) != State.READY:
		return _fail("Lower cannot arrive first independently.")
	report = _order(Cart.UPPER, Route.SALT_ROAD)
	report.lower.definitively_lost = true
	if objective.advance(report) != Outcome.ACTIVE or objective.cart_state(Cart.LOWER) != State.SAFE:
		return _fail("A stale loss corrupted an already exited cart.")
	report = Objective.Observation.new()
	report.upper.at_basin_exit = true
	if objective.advance(report) != Outcome.SUCCEEDED:
		return _fail("Upper could not arrive after Lower.")
	report.raska_incapacitated = true
	if objective.advance(report) != Outcome.SUCCEEDED or objective.failure != Failure.NONE:
		return _fail("A terminal clear was not sticky.")

	objective.restart()
	if objective.outcome != Outcome.ACTIVE or objective.failure != Failure.NONE \
			or objective.route_for(Cart.UPPER) != Route.NONE or objective.route_for(Cart.LOWER) != Route.NONE \
			or objective.cart_state(Cart.UPPER) != State.READY or objective.cart_state(Cart.LOWER) != State.LOADING:
		return _fail("Restart retained stale routes, boarding, or order state.")
	_dispatch_both(objective)
	if objective.advance(_both_at_exit()) != Outcome.SUCCEEDED:
		return _fail("Two real same-tick arrivals did not clear the retry.")
	print("Verified lower-first and simultaneous arrivals, intact terminal states, and clean replay.")
	return true


func _check_loss_precedence() -> bool:
	var objective := Objective.new()
	_dispatch_both(objective)
	var report := _both_at_exit()
	report.lower.definitively_lost = true
	if objective.advance(report) != Outcome.FAILED or objective.failure != Failure.LOWER_CART_LOST \
			or objective.cart_state(Cart.UPPER) != State.SAFE or objective.cart_state(Cart.LOWER) != State.LOST:
		return _fail("A genuine loss did not beat same-cart arrival, or erased the other genuine arrival.")
	if objective.advance(_both_at_exit()) != Outcome.FAILED:
		return _fail("Additional arrivals changed a terminal loss.")

	objective.restart()
	report = _order(Cart.UPPER, Route.SALT_ROAD)
	report.upper.definitively_lost = true
	if objective.advance(report) != Outcome.FAILED or objective.failure != Failure.UPPER_CART_LOST \
			or objective.route_for(Cart.UPPER) != Route.NONE:
		return _fail("Destruction before dispatch did not immediately fail the required escort.")
	objective.restart()
	report.lower.definitively_lost = true
	if objective.advance(report) != Outcome.FAILED or objective.failure != Failure.BOTH_CARTS_LOST:
		return _fail("Two actual losses did not resolve as a simultaneous defeat.")

	objective.restart()
	_dispatch_both(objective)
	report = _both_at_exit()
	report.raska_incapacitated = true
	report.lower.definitively_lost = true
	if objective.advance(report) != Outcome.FAILED or objective.failure != Failure.RASKA_INCAPACITATED \
			or objective.cart_state(Cart.UPPER) != State.EN_ROUTE:
		return _fail("Raska going down did not beat a same-tick exit or loss.")
	print("Verified real cart loss at any stage and deterministic conflict precedence.")
	return true


func _dispatch_both(objective: Objective) -> void:
	var report := Objective.Observation.new()
	report.lower_households_aboard = true
	objective.advance(report)
	report = _order(Cart.UPPER, Route.WASH)
	report.lower = _order(Cart.LOWER, Route.SALT_ROAD).lower
	objective.advance(report)


func _both_at_exit() -> Objective.Observation:
	var report := Objective.Observation.new()
	report.upper.at_basin_exit = true
	report.lower.at_basin_exit = true
	return report


func _order(cart: Cart, route: Route, admitted := true) -> Objective.Observation:
	var report := Objective.Observation.new()
	var target := report.upper if cart == Cart.UPPER else report.lower
	target.requested_route = route
	target.route_admitted = admitted
	return report


func _fail(message: String) -> bool:
	push_error(message)
	return false
