extends RefCounted
## One straight sortie against one committed target and one optional defender.
## The caller owns affiliation, equipment and live target/defender poses.

const Unit := preload("res://game/combat/combat_unit.gd")

enum Role { GROUND, FIGHTER, BOMBER }
enum Phase { READY, APPROACH, FINISHED }
enum Admission { READY, ALREADY_ORDERED, INVALID_ROLE, INVALID_TARGET, INVALID_POSITION, NO_TERRAIN, BAD_APPROACH }
enum Result { NONE, HIT, UNDER_COVER, NO_CLEAR_LANE, TARGET_EVADED, TARGET_LOST, DRIVEN_OFF, FLYER_LOST, FLIGHT_OBSTRUCTED }

# Prototype values in game meters, seconds, and base Ranged damage.
const SAMPLE := 0.5
const SPEED := 12.0
const MAX_APPROACH := 60.0
const FIGHTER_LEAD := 7.0
const FIGHTER_REACH := 9.0
const FIGHTER_COUNTER_REACH := 10.0
const GROUND_COUNTER_REACH := 19.0
const BOMB_RADIUS := 2.6
const MIN_BOMB_HEIGHT := 4.0
const MAX_BOMB_HEIGHT := 18.0
const FIGHTER_DAMAGE := 47.0
const BOMB_DAMAGE := 72.0
const GROUND_COUNTER_DAMAGE := 38.0


class Actor:
	var unit: Unit
	var team: int
	var role: Role
	var position: Vector3
	# Explicit equipment, not implied by a Ranged rating or a roster family.
	var anti_air_equipped := false
	var response_ready := true

	func _init(body: Unit, side: int, kind: Role, at: Vector3) -> void:
		unit = body
		team = side
		role = kind
		position = at

	func alive() -> bool:
		return unit != null and unit.is_alive()


var phase: Phase:
	get:
		return _phase

var result: Result:
	get:
		return _result

var flight_position: Vector3:
	get:
		return _flight_position

var target_hp_lost: float:
	get:
		return _target_hp_lost

var flyer_hp_lost: float:
	get:
		return _flyer_hp_lost

var _phase := Phase.READY
var _result := Result.NONE
var _flight_position := Vector3.ZERO
var _target_hp_lost := 0.0
var _flyer_hp_lost := 0.0
var _flyer: Actor
var _target: Actor
var _counter: Actor
var _flight_role: Role
var _gate: Vector3
var _clear_lane: Callable
var _ground_covered: Callable


## clear_lane(from: Vector3, to: Vector3) checks real terrain on flight and shot segments.
## ground_covered(ground_position: Vector3) checks overhead cover at the ground
## target, including authored foliage that may not be in the collision layer.
## Both return bool. No missing query silently grants a clear attack.
func _init(clear_lane: Callable, ground_covered: Callable) -> void:
	_clear_lane = clear_lane
	_ground_covered = ground_covered


func order(flyer: Actor, target: Actor, counter: Actor = null) -> Admission:
	if _phase != Phase.READY:
		return Admission.ALREADY_ORDERED
	if not flyer or not flyer.alive() or flyer.role not in [Role.FIGHTER, Role.BOMBER]:
		return Admission.INVALID_ROLE
	if not _valid_target(flyer, target, flyer.role):
		return Admission.INVALID_TARGET
	if not flyer.position.is_finite() or not target.position.is_finite():
		return Admission.INVALID_POSITION
	if not _clear_lane.is_valid() or (flyer.role == Role.BOMBER and not _ground_covered.is_valid()):
		return Admission.NO_TERRAIN
	# Flight stays on a fixed level heading to the original release gate. It
	# cannot pivot with the target or acquire another unit at the last moment.
	var gate := Vector3(target.position.x, flyer.position.y, target.position.z)
	var leg := flyer.position.distance_to(gate)
	var lead := FIGHTER_LEAD if flyer.role == Role.FIGHTER else 0.0
	if leg < lead + 1.0 or leg > MAX_APPROACH:
		return Admission.BAD_APPROACH
	_flyer = flyer
	_target = target
	_counter = counter
	_flight_role = flyer.role
	_flight_position = flyer.position
	_gate = gate.move_toward(_flight_position, lead)
	_phase = Phase.APPROACH
	return Admission.READY


## Move the real flight position. Live cover, contact and counter decisions
## are made during advance, not when the player confirms the order.
func advance(delta: float) -> Result:
	if _phase != Phase.APPROACH or not is_finite(delta) or delta <= 0.0:
		return _result
	if not _flyer.alive():
		return _finish(Result.FLYER_LOST)
	if not _valid_target(_flyer, _target, _flight_role):
		return _finish(Result.TARGET_LOST)
	var budget := minf(MAX_APPROACH, SPEED * delta)
	while _phase == Phase.APPROACH:
		# Check the response before release, even at the exact gate. A fighter
		# or equipped ground unit gets one valid shot and forces a fly-off.
		if _can_counter():
			var damage := FIGHTER_DAMAGE if _counter.role == Role.FIGHTER else GROUND_COUNTER_DAMAGE
			_flyer_hp_lost = _flyer.unit.receive_hit(_counter.unit, {Unit.Damage.RANGED: damage})
			return _finish(Result.DRIVEN_OFF if _flyer.alive() else Result.FLYER_LOST)
		if _flight_position.distance_squared_to(_gate) <= 1.0e-8:
			return _release()
		if budget <= 0.0:
			break
		var step := minf(budget, SAMPLE)
		var next := _flight_position.move_toward(_gate, step)
		if not _clear_lane.call(_flight_position, next):
			return _finish(Result.FLIGHT_OBSTRUCTED)
		_flight_position = next
		budget -= step
	return _result


func _valid_target(flyer: Actor, target: Actor, flight_role: Role) -> bool:
	if not target or not target.alive() or target.unit == flyer.unit or target.team == flyer.team:
		return false
	if flight_role == Role.BOMBER:
		return target.role == Role.GROUND
	return target.role in [Role.FIGHTER, Role.BOMBER]


func _can_counter() -> bool:
	if not _counter or not _counter.alive() or _counter.unit == _flyer.unit \
			or _counter.team != _target.team or not _counter.response_ready or not _counter.position.is_finite():
		return false
	var origin := _counter.position
	var reach := FIGHTER_COUNTER_REACH
	if _counter.role == Role.GROUND and _counter.anti_air_equipped:
		origin += Vector3.UP * 1.45
		reach = GROUND_COUNTER_REACH
	elif _counter.role != Role.FIGHTER:
		return false
	return origin.distance_squared_to(_flight_position) <= reach * reach \
		and _clear_lane.call(origin, _flight_position)


func _release() -> Result:
	var impact := _target.position
	if not impact.is_finite():
		return _finish(Result.TARGET_EVADED)
	if _flight_role == Role.BOMBER:
		var horizontal := Vector2(_flight_position.x - impact.x, _flight_position.z - impact.z)
		var height := _flight_position.y - impact.y
		if horizontal.length_squared() > BOMB_RADIUS * BOMB_RADIUS \
				or height < MIN_BOMB_HEIGHT or height > MAX_BOMB_HEIGHT:
			return _finish(Result.TARGET_EVADED)
		if _ground_covered.call(impact):
			return _finish(Result.UNDER_COVER)
		impact.y += 0.90
	elif _flight_position.distance_squared_to(impact) > FIGHTER_REACH * FIGHTER_REACH:
		return _finish(Result.TARGET_EVADED)
	if not _clear_lane.call(_flight_position, impact):
		return _finish(Result.NO_CLEAR_LANE)
	var damage := BOMB_DAMAGE if _flight_role == Role.BOMBER else FIGHTER_DAMAGE
	_target_hp_lost = _target.unit.receive_hit(_flyer.unit, {Unit.Damage.RANGED: damage})
	return _finish(Result.HIT)


func _finish(outcome: Result) -> Result:
	_result = outcome
	_phase = Phase.FINISHED
	return _result
