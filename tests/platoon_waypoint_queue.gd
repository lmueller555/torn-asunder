extends SceneTree

const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")
const Result := Queue.Result

var _validator_calls := 0


func _initialize() -> void:
	var passed := _check_admission()
	passed = _check_consumption_and_isolation() and passed
	quit(0 if passed else 1)


func _check_admission() -> bool:
	var route := Queue.new()
	if route.count() != 0 or route.next_waypoint() != null or route.consume_if_arrived(Vector2.ZERO):
		return _fail("An empty queue acted as if the battlefield origin were pending.")
	if route.set_destination(Vector2.ZERO, _walkable) != Result.ACCEPTED or route.next_waypoint() != Vector2.ZERO:
		return _fail("A legal order at the battlefield origin was rejected.")
	for i in range(1, Queue.MAX_WAYPOINTS):
		if route.add_waypoint(Vector2(i, 0.0), _walkable) != Result.ACCEPTED:
			return _fail("A distinct point below the eight-point cap was rejected.")
	var old := route.snapshot()
	if route.count() != 8 or route.add_waypoint(Vector2(8.0, 0.0), _walkable) != Result.FULL:
		return _fail("The queue did not cap pending waypoints at eight.")
	if _validator_calls != 8 or route.snapshot() != old:
		return _fail("Overflow called the terrain validator or changed the route.")
	if route.add_waypoint(Vector2(1.02, 0.0)) != Result.DUPLICATE \
			or route.set_destination(Vector2(6.02, 0.0)) != Result.DUPLICATE:
		return _fail("A duplicate pending point was accepted.")
	if route.set_destination(Vector2(INF, 0.0)) != Result.NONFINITE_POINT \
			or route.add_waypoint(Vector2(0.0, NAN)) != Result.NONFINITE_POINT:
		return _fail("A non-finite point was admitted.")
	if route.set_destination(Vector2(9.0, 0.0), _walkable) != Result.INVALID_FOR_BATTLEFIELD \
			or route.set_destination(Vector2(5.0, 1.0), Callable(self, &"_missing_validator")) != Result.INVALID_FOR_BATTLEFIELD \
			or route.set_destination(Vector2(5.0, 1.0), _invalid_return) != Result.INVALID_FOR_BATTLEFIELD \
			or route.set_destination(Vector2(5.0, 1.0), _wrong_arguments) != Result.INVALID_FOR_BATTLEFIELD:
		return _fail("A blocked, missing, ill-typed or wrong-arity terrain validator admitted an order.")
	if route.snapshot() != old:
		return _fail("Rejecting a new destination destroyed or edited the prior route.")
	if route.set_destination(Vector2(-3.0, -2.0), _walkable) != Result.ACCEPTED \
			or route.snapshot() != PackedVector2Array([Vector2(-3.0, -2.0)]):
		return _fail("A legal direct destination did not replace a full route.")
	print("Verified eight pending points, transactional order rejection, duplicate tolerance and atomic replacement.")
	return true


func _check_consumption_and_isolation() -> bool:
	var blue := Queue.new()
	var amber := Queue.new()
	var a := Vector2(2.0, 4.0)
	var b := a + Vector2(0.10, 0.0)
	blue.add_waypoint(a)
	blue.add_waypoint(b)
	blue.add_waypoint(Vector2(4.0, 8.0))
	amber.add_waypoint(Vector2(3.0, 6.0))
	if blue.consume_if_arrived(Vector2(4.0, 8.0)) or blue.consume_if_arrived(Vector2(NAN, 4.0)) \
			or blue.consume_if_arrived(a + Vector2(0.0, Queue.ARRIVAL_RADIUS + 0.01)):
		return _fail("Arrival at a later waypoint, a bad position or a near miss consumed the head.")
	var overlay := blue.snapshot()
	overlay.remove_at(0)
	overlay[0] = Vector2.ZERO
	if blue.count() != 3 or blue.next_waypoint() != a:
		return _fail("An overlay was able to change the formation's queue.")
	if not blue.consume_if_arrived(a) or blue.count() != 2 or blue.next_waypoint() != b:
		return _fail("An arrival skipped a nearby point or consumed more than the head.")
	if blue.add_waypoint(a) != Result.ACCEPTED:
		return _fail("A point already passed cannot be reused later in a route.")
	if blue.add_waypoint(Vector2(-9.0, 1.0), _walkable) != Result.INVALID_FOR_BATTLEFIELD or blue.count() != 3:
		return _fail("A rejected append changed the valid pending route.")
	blue.clear()
	blue.clear()
	if blue.count() != 0 or blue.next_waypoint() != null or amber.count() != 1 \
			or amber.next_waypoint() != Vector2(3.0, 6.0):
		return _fail("Hold/cancel failed to clear the selected formation alone.")
	if not amber.consume_if_arrived(Vector2(3.0, 6.0)) or amber.next_waypoint() != null:
		return _fail("Arriving at the last waypoint did not finish the route.")
	print("Verified ordered, arrival-only consumption, explicit clear, and independent platoon snapshots.")
	return true


func _walkable(point: Vector2) -> bool:
	_validator_calls += 1
	return absf(point.x) <= 8.0


func _invalid_return(_point: Vector2) -> int:
	return 1


func _wrong_arguments() -> bool:
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
