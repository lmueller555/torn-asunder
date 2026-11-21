extends RefCounted
## One explicitly paired mounted pass against an opposing formation.
## Position and facing decide the contact, not a troop label or camera.

const Platoon := preload("res://game/combat/platoon.gd")
const Roster := preload("res://game/combat/faction_roster.gd")

enum Phase { READY, CHARGING, RUNNING_OUT, REGROUPING }
enum Result { NONE, LANDED, REPELLED, MISSED, TERRAIN_BLOCKED, SHORT_RUNUP, SHORT_RUNOUT, CANCELLED }

# Prototype tuning for this model only. Distances are meters; times are seconds.
const SPEED := 8.0
const SAMPLE := 0.35
const CONTACT_RADIUS := 3.20
const BASE_RUNUP := 12.0
const RUNOUT := 6.0
const BASE_REGROUP_SECONDS := 3.0
const BRACE_SECONDS := 0.65
const MIN_BRACE_COHESION := 35.0
const FRONT_DOT := 0.66

var phase: Phase:
	get:
		return _phase

var result: Result:
	get:
		return _result

var rider_position: Vector2:
	get:
		return _position

var travel_direction: Vector2:
	get:
		return _direction

var distance_marched: float:
	get:
		return _distance

var brace_ready: bool:
	get:
		return _brace_time >= BRACE_SECONDS and _defender.cohesion >= MIN_BRACE_COHESION \
			and _defender.health_fractions().x > 0.0

var rider_cohesion_lost: float:
	get:
		return _rider_loss

var defender_cohesion_lost: float:
	get:
		return _defender_loss

var _riders: Platoon
var _defender: Platoon
var _eligible_brace: bool
var _can_move: Callable
var _clear_contact: Callable
var _position: Vector2
var _defender_position := Vector2.ZERO
var _defender_facing := Vector2.ZERO
var _has_defender_pose := false
var _brace_time := 0.0
var _phase := Phase.READY
var _result := Result.NONE
var _direction := Vector2.ZERO
var _remaining := 0.0
var _distance := 0.0
var _regroup_left := 0.0
var _rider_loss := 0.0
var _defender_loss := 0.0


## Both terrain callbacks take (from, to) in the same battlefield plane.
## can_move must test the mounted formation footprint; clear_contact must
## reject separated levels or walls. The caller pairs opposing formations.
func _init(riders: Platoon, defender: Platoon, rider_start: Vector2, defender_family: StringName,
		can_move: Callable, clear_contact: Callable) -> void:
	_riders = riders
	_defender = defender
	_position = rider_start
	_eligible_brace = defender_family == Roster.ANTI_RIDING
	_can_move = can_move
	_clear_contact = clear_contact


## Submit the actual defender position, heading and Hold order before advancing
## the pass. A relocation or any real turn starts a fresh brace, even on Hold.
func observe_defender(position: Vector2, facing: Vector2, holding: bool, delta: float) -> void:
	if not position.is_finite() or not facing.is_finite() or facing.is_zero_approx():
		_brace_time = 0.0
		_has_defender_pose = false
		return
	var heading := facing.normalized()
	var changed := not _has_defender_pose or not position.is_equal_approx(_defender_position) \
		or not heading.is_equal_approx(_defender_facing)
	_defender_position = position
	_defender_facing = heading
	_has_defender_pose = true
	if changed or not holding or not _eligible_brace or _defender.cohesion < MIN_BRACE_COHESION \
			or _defender.health_fractions().x <= 0.0:
		_brace_time = 0.0
	elif is_finite(delta) and delta > 0.0:
		_brace_time = minf(BRACE_SECONDS, _brace_time + delta)


## A scene may supply the riders' actual new staging position after ordinary
## maneuvering. It cannot relocate them during a charge, run-out, or regroup.
func sync_ready_riders(position: Vector2) -> bool:
	if _phase != Phase.READY or not position.is_finite():
		return false
	_position = position
	return true


func minimum_runup() -> float:
	return _riders.mounted_maneuver_seconds(BASE_RUNUP / SPEED) * SPEED


## Aim through a lane, not at a homing target. Riders must travel the actual
## run-up and require clear ground to continue past a potential impact.
func order_pass(end: Vector2) -> bool:
	if _phase != Phase.READY or not _position.is_finite() or not end.is_finite() \
			or not _has_defender_pose or not _live_opponents() or not _can_move.is_valid() or not _clear_contact.is_valid():
		return false
	var lane := end - _position
	if not lane.is_finite() or not is_finite(lane.length()) or lane.is_zero_approx():
		return false
	_direction = lane.normalized()
	_remaining = lane.length()
	_distance = 0.0
	_rider_loss = 0.0
	_defender_loss = 0.0
	_result = Result.NONE
	_phase = Phase.CHARGING
	return true


func cancel_before_impact() -> bool:
	if _phase != Phase.CHARGING:
		return false
	_regroup(Result.CANCELLED)
	return true


func advance(delta: float) -> Phase:
	if not is_finite(delta) or delta <= 0.0:
		return _phase
	if _phase == Phase.REGROUPING:
		_regroup_left -= delta
		if _regroup_left <= 0.0:
			_phase = Phase.READY
		return _phase
	if _phase == Phase.READY:
		return _phase
	if _phase == Phase.CHARGING and (not _has_defender_pose or not _live_opponents()):
		_regroup(Result.CANCELLED)
		return _phase

	var budget := minf(_remaining, SPEED * delta)
	while budget > 0.00001 and _phase in [Phase.CHARGING, Phase.RUNNING_OUT]:
		var step := minf(SAMPLE, budget)
		var contact := _contact_distance(step) if _phase == Phase.CHARGING else -1.0
		var traveled := contact if contact >= 0.0 else step
		var next := _position + _direction * traveled
		if not _can_move.call(_position, next):
			_regroup(Result.TERRAIN_BLOCKED if _phase == Phase.CHARGING else Result.LANDED)
			break
		_position = next
		_remaining -= traveled
		_distance += traveled
		budget -= traveled
		if contact >= 0.0:
			_resolve_contact()
	if _remaining <= 0.00001 and _phase in [Phase.CHARGING, Phase.RUNNING_OUT]:
		_regroup(Result.MISSED if _phase == Phase.CHARGING else Result.LANDED)
	return _phase


func _contact_distance(step: float) -> float:
	var relative := _position - _defender_position
	var outside := relative.length_squared() - CONTACT_RADIUS * CONTACT_RADIUS
	var projection := relative.dot(_direction)
	if outside <= 0.0:
		# A defender moving into the already-passed rear of a charge is not
		# a forward impact; the rider cannot strike backward.
		return 0.0 if projection <= 0.0 else -1.0
	var discriminant := projection * projection - outside
	if discriminant < 0.0:
		return -1.0
	var entry := -projection - sqrt(discriminant)
	return entry if entry >= 0.0 and entry <= step else -1.0


func _resolve_contact() -> void:
	if not _clear_contact.call(_position, _defender_position):
		_regroup(Result.TERRAIN_BLOCKED)
		return
	if _distance < minimum_runup():
		_regroup(Result.SHORT_RUNUP)
		return
	if _remaining < RUNOUT or not _runout_clear():
		_regroup(Result.SHORT_RUNOUT)
		return
	var contact_side := (_position - _defender_position).normalized()
	var frontal := _defender_facing.dot(contact_side) >= FRONT_DOT \
		and _defender_facing.dot(-_direction) >= FRONT_DOT
	if frontal and brace_ready:
		# The braced line meets the riders first. Resolve the counter and only
		# the reduced cohesion impact; never apply an ordinary hit afterward.
		_rider_loss = _riders.lose_cohesion(20.0 + 4.0 * _defender.rank(Platoon.Skill.CHARGE_BRACE))
		_defender_loss = _riders.charge(_defender, true)
		_brace_time = 0.0
		_regroup(Result.REPELLED)
	else:
		_defender_loss = _riders.charge(_defender, false)
		_brace_time = 0.0
		_result = Result.LANDED
		_phase = Phase.RUNNING_OUT


func _runout_clear() -> bool:
	var from := _position
	var remaining := RUNOUT
	while remaining > 0.00001:
		var step := minf(SAMPLE, remaining)
		var to := from + _direction * step
		if not _can_move.call(from, to):
			return false
		from = to
		remaining -= step
	return true


func _live_opponents() -> bool:
	return _riders != _defender and _riders.health_fractions().x > 0.0 and _defender.health_fractions().x > 0.0


func _regroup(outcome: Result) -> void:
	_phase = Phase.REGROUPING
	_result = outcome
	_regroup_left = _riders.mounted_maneuver_seconds(BASE_REGROUP_SECONDS)
