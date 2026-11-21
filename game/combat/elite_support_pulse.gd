extends RefCounted
## An optional rare-beast support ability; not a unit, unlock or siege shot.
## A future caller attaches it only to an authorized beast, then supplies live
## positions, a legal ground placement, and cover observations. The model owns the paid tell and the one cohesion impact.

const Troop := preload("res://game/combat/platoon.gd")
const Points := preload("res://game/combat/battle_points.gd")

enum Phase { IDLE, ANNOUNCED, RESOLVED, INTERRUPTED }

# Provisional prototype tuning, not a roster assignment.
const BEAST_HANDLING := 2
const COST := 140
const PLACEMENT_RANGE := 8.0
const RADIUS := 4.0
const TELL_SECONDS := 1.1
const SOURCE_TOLERANCE := 0.35
const COHESION_PRESSURE := 24.0


class Contact:
	var troop: Troop
	var position: Vector2
	var opposing: bool
	var exposed: bool

	func _init(platoon: Troop, ground: Vector2, is_opposing: bool, wave_path_clear: bool) -> void:
		troop = platoon
		position = ground
		opposing = is_opposing
		exposed = wave_path_clear


var phase: Phase:
	get:
		return _phase

## Stable ground center throughout the tell. The view can hide it outside ANNOUNCED.
var center: Vector2:
	get:
		return _center

var tell_remaining: float:
	get:
		return _remaining

var affected_count: int:
	get:
		return _pressured.size()

var _beast: Troop
var _points: Points
var _phase := Phase.IDLE
var _origin := Vector2.ZERO
var _center := Vector2.ZERO
var _remaining := 0.0
var _pressured: Dictionary[int, float] = {}


func _init(beast: Troop, team_points: Points) -> void:
	_beast = beast
	_points = team_points


## Placement and willingness must both be proven before the shared pool is charged.
func begin(origin: Vector2, target_ground: Vector2, placeable: bool, lane_clear: bool) -> bool:
	if _phase != Phase.IDLE or not _points or not _can_act():
		return false
	if not _valid_ground(origin, target_ground, placeable, lane_clear) or not _points.try_spend(COST, true):
		return false
	_origin = origin
	_center = target_ground
	_remaining = TELL_SECONDS
	_phase = Phase.ANNOUNCED
	return true


## While announced, pass observations for the locked center, not a moved cursor.
## Interruption beats release on the same tick. Only the release frame's contacts
## count: opponents can step out, gain cover, or disrupt the beast before impact.
func advance(delta: float, origin: Vector2, placeable: bool, lane_clear: bool,
		contacts: Array[Contact] = [], disrupted := false) -> Phase:
	if _phase != Phase.ANNOUNCED:
		return _phase
	if disrupted or not _can_act() or not _valid_ground(origin, _center, placeable, lane_clear) \
			or origin.distance_to(_origin) > SOURCE_TOLERANCE:
		_remaining = 0.0
		_phase = Phase.INTERRUPTED
		return _phase
	if not is_finite(delta) or delta <= 0.0:
		return _phase
	_remaining = maxf(0.0, _remaining - delta)
	if is_zero_approx(_remaining):
		_remaining = 0.0
		_resolve(contacts)
		_phase = Phase.RESOLVED
	return _phase


func pressure_dealt(troop: Troop) -> float:
	return _pressured.get(troop.get_instance_id(), 0.0) if troop else 0.0


## Finish one attempt before reconsidering a different placement. No BP refund.
func reset_after_terminal() -> bool:
	if _phase not in [Phase.RESOLVED, Phase.INTERRUPTED]:
		return false
	_origin = Vector2.ZERO
	_center = Vector2.ZERO
	_pressured.clear()
	_phase = Phase.IDLE
	return true


func _can_act() -> bool:
	return _beast != null and _beast.rank(Troop.Skill.BEAST_HANDLING) >= BEAST_HANDLING \
		and _beast.beasts_follow_orders()


func _valid_ground(origin: Vector2, ground: Vector2, placeable: bool, lane_clear: bool) -> bool:
	return origin.is_finite() and ground.is_finite() and placeable and lane_clear \
		and origin.distance_to(ground) <= PLACEMENT_RANGE


func _resolve(contacts: Array[Contact]) -> void:
	for contact in contacts:
		if not contact or not contact.troop or contact.troop == _beast or not contact.opposing or not contact.exposed \
				or not contact.position.is_finite() or contact.position.distance_to(_center) > RADIUS:
			continue
		var id := contact.troop.get_instance_id()
		if _pressured.has(id) or contact.troop.health_fractions().x <= 0.0:
			continue
		var loss := contact.troop.lose_cohesion(COHESION_PRESSURE)
		if loss > 0.0:
			_pressured[id] = loss
