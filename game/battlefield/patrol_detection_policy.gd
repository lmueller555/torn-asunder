extends RefCounted
## Converts a battlefield observation into intent. The caller owns movement,
## ground/cover queries, melee admission, and the authored patrol/guard route.

enum AuthoredOrder { GUARD, PATROL }
enum Intent { GUARD, PATROL, PURSUE, INVESTIGATE, ENGAGE, INTERCEPT }


class Sighting:
	var id: StringName
	var position: Vector2
	var eligible := true
	var unobstructed := false
	## Independent combat result, never inferred from scouting distance.
	var melee_reachable := false

	func _init(key: StringName, at: Vector2, line_clear: bool, combat_reachable := false) -> void:
		id = key
		position = at
		unobstructed = line_clear
		melee_reachable = combat_reachable


class Observation:
	var patrol_position := Vector2.ZERO
	var leash_anchor := Vector2.ZERO
	var authored_order := AuthoredOrder.GUARD
	var candidates: Array[Sighting] = []
	## Movement adapter's result for the active scenario waypoint, not a timer.
	var interception_arrived := false
	var interception_blocked := false


class Contact:
	var id: StringName
	var position: Vector2

	func _init(key: StringName, at: Vector2) -> void:
		id = key
		position = at


class Decision:
	var intent: Intent
	## Empty for authored orders and scripted interception. Investigate
	## exposes only the remembered identity and last-seen position.
	var contact_id: StringName
	var destination := Vector2.ZERO
	var has_destination := false
	## Only current visible contacts. Memory is not included here, including
	## when the guard is moving to the last-seen point.
	var visible_contacts: Array[Contact] = []

	func _init(order: Intent) -> void:
		intent = order

	func direct(order: Intent, point: Vector2, id := &"") -> void:
		intent = order
		destination = point
		has_destination = true
		contact_id = id


var _sight: float
var _leash: float
var _memory: float
var _pursued: StringName
var _last_seen := Vector2.ZERO
var _remaining := 0.0
var _has_interception := false
var _interception_point := Vector2.ZERO


func _init(sight_range: float, pursuit_leash: float, memory_seconds: float) -> void:
	_sight = _finite_nonnegative(sight_range)
	_leash = _finite_nonnegative(pursuit_leash)
	_memory = _finite_nonnegative(memory_seconds)


## Only an explicit scenario order may bypass ordinary target acquisition.
## The destination is a fixed authored point, not a friendly's hidden position.
func assign_interception(authored_destination: Vector2) -> bool:
	if not authored_destination.is_finite():
		return false
	_forget()
	_interception_point = authored_destination
	_has_interception = true
	return true


func cancel_interception() -> void:
	_has_interception = false


func reset() -> void:
	_forget()
	cancel_interception()


func advance(delta: float, observation: Observation) -> Decision:
	if observation == null:
		return Decision.new(Intent.GUARD)
	var out := Decision.new(Intent.PATROL if observation.authored_order == AuthoredOrder.PATROL else Intent.GUARD)
	var visible := _visible(observation)
	for item in visible:
		out.visible_contacts.append(Contact.new(item.id, item.position))

	if _has_interception:
		if not observation.interception_arrived and not observation.interception_blocked:
			out.direct(Intent.INTERCEPT, _interception_point)
			return out
		cancel_interception()

	if not _inside_leash(observation.patrol_position, observation.leash_anchor):
		_forget()
		return out
	var pursuit := _choose_contact(visible, observation)
	if pursuit:
		_pursued = pursuit.id
		_last_seen = pursuit.position
		_remaining = _memory
		var next := Intent.ENGAGE if pursuit.melee_reachable else Intent.PURSUE
		out.direct(next, pursuit.position, pursuit.id)
		return out

	_remaining = maxf(0.0, _remaining - _finite_nonnegative(delta))
	if _pursued != &"" and _remaining > 0.0 and _inside_leash(_last_seen, observation.leash_anchor):
		out.direct(Intent.INVESTIGATE, _last_seen, _pursued)
	else:
		_forget()
	return out


func _visible(observation: Observation) -> Array[Sighting]:
	var result: Array[Sighting] = []
	if _sight <= 0.0 or not observation.patrol_position.is_finite():
		return result
	for item in observation.candidates:
		if item and item.id != &"" and item.eligible and item.unobstructed and item.position.is_finite() \
			and observation.patrol_position.distance_to(item.position) <= _sight:
			result.append(item)
	return result


func _choose_contact(visible: Array[Sighting], observation: Observation) -> Sighting:
	var nearest: Sighting
	var best := INF
	for item in visible:
		if not _inside_leash(item.position, observation.leash_anchor):
			continue
		if item.id == _pursued:
			return item
		var distance := observation.patrol_position.distance_squared_to(item.position)
		if distance < best or (nearest and is_equal_approx(distance, best) and String(item.id) < String(nearest.id)):
			nearest = item
			best = distance
	return nearest


func _inside_leash(point: Vector2, anchor: Vector2) -> bool:
	return _leash > 0.0 and point.is_finite() and anchor.is_finite() and point.distance_to(anchor) <= _leash


func _forget() -> void:
	_pursued = &""
	_remaining = 0.0
	_last_seen = Vector2.ZERO


static func _finite_nonnegative(value: float) -> float:
	return maxf(0.0, value) if is_finite(value) else 0.0
