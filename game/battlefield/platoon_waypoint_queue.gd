extends RefCounted
## One queue per platoon. Cursor and minimap callers supply the same battlefield
## XZ point and may share a read-only validator for bounds and terrain.

enum Result { ACCEPTED, NONFINITE_POINT, DUPLICATE, FULL, INVALID_FOR_BATTLEFIELD }

const MAX_WAYPOINTS := 8
# Provisional Torn Asunder tolerances in battlefield meters.
const DUPLICATE_RADIUS := 0.05
const ARRIVAL_RADIUS := 0.15

var _points := PackedVector2Array()


func count() -> int:
	return _points.size()


## Null means no pending waypoint. The battlefield origin is a valid point.
func next_waypoint() -> Variant:
	return null if _points.is_empty() else _points[0]


## A copy for tactical and minimap overlays; changing it cannot mutate the route.
func snapshot() -> PackedVector2Array:
	return _points.duplicate()


## Replace the whole route, but only after the new point is accepted.
func set_destination(point: Vector2, validator := Callable()) -> Result:
	var result := _admit(point, false, validator)
	if result == Result.ACCEPTED:
		_points = PackedVector2Array([point])
	return result


func add_waypoint(point: Vector2, validator := Callable()) -> Result:
	var result := _admit(point, true, validator)
	if result == Result.ACCEPTED:
		_points.append(point)
	return result


## Consume at most one point, and only the head of the queue. The caller
## supplies the platoon's actual location after movement, not a planned point.
func consume_if_arrived(position: Vector2) -> bool:
	if _points.is_empty() or not position.is_finite() \
			or position.distance_squared_to(_points[0]) > ARRIVAL_RADIUS * ARRIVAL_RADIUS:
		return false
	_points.remove_at(0)
	return true


## Call when a Hold or explicit cancel replaces the movement order.
func clear() -> void:
	_points.clear()


func _admit(point: Vector2, appending: bool, validator: Callable) -> Result:
	if not point.is_finite():
		return Result.NONFINITE_POINT
	for pending in _points:
		if point.distance_squared_to(pending) <= DUPLICATE_RADIUS * DUPLICATE_RADIUS:
			return Result.DUPLICATE
	if appending and _points.size() >= MAX_WAYPOINTS:
		return Result.FULL
	if not validator.is_null():
		if not validator.is_valid() or validator.get_argument_count() != 1:
			return Result.INVALID_FOR_BATTLEFIELD
		var permitted: Variant = validator.call(point)
		if not permitted is bool or not permitted:
			return Result.INVALID_FOR_BATTLEFIELD
	return Result.ACCEPTED
