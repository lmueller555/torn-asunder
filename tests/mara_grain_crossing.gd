extends SceneTree

const Crossing := preload("res://game/battlefield/mara_grain_crossing.gd")
const State := Crossing.CartState
const Cart := Crossing.Cart
const Outcome := Crossing.Outcome
const Failure := Crossing.Failure


func _initialize() -> void:
	var both := _check_both()
	var partial := _check_partial()
	var defeats := _check_defeats()
	var passed := both and partial and defeats
	if passed:
		print("Verified dual-cart dispatch, every delivery result, no-delivery and hero defeats, precedence, and replay.")
	quit(0 if passed else 1)


func _check_both() -> bool:
	var crossing := Crossing.new()
	var frame := Crossing.Observation.new()
	frame.seed.at_receiving_yard = true
	frame.seed.dispatch_ordered = true
	frame.bread.at_receiving_yard = true
	if crossing.advance(frame) != Outcome.ACTIVE or crossing.cart_state(Cart.SEED) != State.EN_ROUTE or crossing.cart_state(Cart.BREAD) != State.STAGED:
		return _fail("A yard report bypassed actual departure, or dispatch released both carts.")
	frame = Crossing.Observation.new()
	frame.bread.dispatch_ordered = true
	if crossing.advance(frame) != Outcome.ACTIVE or crossing.cart_state(Cart.BREAD) != State.EN_ROUTE:
		return _fail("Bread could not dispatch independently.")
	frame = Crossing.Observation.new()
	frame.seed.at_receiving_yard = true
	frame.bread.at_receiving_yard = true
	frame.bread.turn_back_ordered = true
	if crossing.advance(frame) != Outcome.SUCCEEDED or crossing.clear_result != Crossing.BOTH:
		return _fail("Two intact simultaneous arrivals did not produce a both-load clear.")
	frame.hero_fell = true
	frame.seed.definitively_lost = true
	frame.bread.definitively_lost = true
	if crossing.advance(frame) != Outcome.SUCCEEDED or crossing.clear_result != Crossing.BOTH:
		return _fail("A late casualty changed a completed result.")
	crossing.restart()
	return _check_clean_restart(crossing)


func _check_partial() -> bool:
	for securing in [Cart.SEED, Cart.BREAD]:
		for lose_second in [false, true]:
			var crossing := Crossing.new()
			var frame := Crossing.Observation.new()
			var delivered: Crossing.CartReport = frame.seed if securing == Cart.SEED else frame.bread
			var other: Crossing.CartReport = frame.bread if securing == Cart.SEED else frame.seed
			delivered.dispatch_ordered = true
			other.dispatch_ordered = lose_second
			crossing.advance(frame)
			delivered.dispatch_ordered = false
			other.dispatch_ordered = false
			delivered.at_receiving_yard = true
			if crossing.advance(frame) != Outcome.ACTIVE or crossing.cart_state(securing) != State.SECURED or crossing.clear_result != &"":
				return _fail("One arrival resolved the mission before the other cart finished.")
			delivered.at_receiving_yard = false
			delivered.definitively_lost = true
			delivered.turn_back_ordered = true
			other.turn_back_ordered = not lose_second
			other.definitively_lost = lose_second
			other.at_receiving_yard = lose_second
			var expected := Crossing.SEED_ONLY if securing == Cart.SEED else Crossing.BREAD_ONLY
			if crossing.advance(frame) != Outcome.SUCCEEDED or crossing.clear_result != expected or crossing.cart_state(securing) != State.SECURED:
				return _fail("Turning back or losing the other cart did not resolve a safe single-load delivery.")
			var other_cart := Cart.SEED if securing == Cart.BREAD else Cart.BREAD
			if crossing.cart_state(other_cart) != (State.LOST if lose_second else State.TURNED_BACK):
				return _fail("Loss, arrival, and turn-back did not resolve in the documented order.")
	return true


func _check_defeats() -> bool:
	for resolution in [[false, true], [true, true], [false, false]]:
		var crossing := Crossing.new()
		var frame := Crossing.Observation.new()
		frame.seed.turn_back_ordered = not resolution[0]
		frame.seed.definitively_lost = resolution[0]
		frame.seed.dispatch_ordered = true
		frame.bread.turn_back_ordered = not resolution[1]
		frame.bread.definitively_lost = resolution[1]
		frame.bread.dispatch_ordered = true
		if crossing.advance(frame) != Outcome.FAILED or crossing.failure != Failure.NO_DELIVERY or crossing.clear_result != &"":
			return _fail("Resolving both carts without an intact arrival did not fail.")
		if crossing.cart_state(Cart.SEED) != (State.LOST if resolution[0] else State.TURNED_BACK):
			return _fail("Loss or turn-back did not beat simultaneous dispatch.")
		frame = Crossing.Observation.new()
		frame.seed.dispatch_ordered = true
		frame.bread.dispatch_ordered = true
		if crossing.advance(frame) != Outcome.FAILED:
			return _fail("A failed attempt returned to active without a restart.")
		crossing.restart()
		if not _check_clean_restart(crossing):
			return false

	# A secured cart is safe, but the mission has not resolved while another is still travelling.
	var crossing := Crossing.new()
	var frame := Crossing.Observation.new()
	frame.seed.dispatch_ordered = true
	frame.bread.dispatch_ordered = true
	crossing.advance(frame)
	frame = Crossing.Observation.new()
	frame.seed.at_receiving_yard = true
	crossing.advance(frame)
	frame.bread.at_receiving_yard = true
	frame.hero_fell = true
	if crossing.advance(frame) != Outcome.FAILED or crossing.failure != Failure.HERO_FELL or crossing.clear_result != &"":
		return _fail("Hero defeat did not outweigh a same-tick final delivery.")
	if crossing.cart_state(Cart.SEED) != State.SECURED or crossing.cart_state(Cart.BREAD) != State.EN_ROUTE:
		return _fail("Hero defeat altered a previously safe cart or accepted a concurrent delivery.")
	return true


func _check_clean_restart(crossing: Crossing) -> bool:
	if crossing.outcome != Outcome.ACTIVE or crossing.failure != Failure.NONE or crossing.clear_result != &"":
		return _fail("Restart retained a terminal outcome.")
	if crossing.cart_state(Cart.SEED) != State.STAGED or crossing.cart_state(Cart.BREAD) != State.STAGED:
		return _fail("Restart retained cart progress.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
