extends RefCounted
## First targeted-caster rules, separate from input, pathing and effects.

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")

enum Phase { IDLE, WINDUP, RELEASED, INTERRUPTED }

# Provisional gameplay tuning, not a faction unlock or production VFX.
const COST := 120
const ICE_RATING := 6
const RANGE := 16.0
const WINDUP_SECONDS := 0.7
const BASE_ICE_DAMAGE := 70.0

var phase: Phase:
	get:
		return _phase
var damage_done: float:
	get:
		return _damage_done

var _points: Points
var _caster: Unit
var _target: Unit
var _time := 0.0
var _damage_done := 0.0
var _phase := Phase.IDLE


func _init(team_points: Points) -> void:
	_points = team_points


func locked_target() -> Unit:
	return _target if _phase == Phase.WINDUP else null


func begin(caster: Unit, target: Unit, distance: float, clear_lane: bool) -> bool:
	if _phase != Phase.IDLE or not _points or not caster or not target or caster == target:
		return false
	if not caster.is_alive() or not target.is_alive() or caster.rating(Unit.Damage.ICE) < ICE_RATING:
		return false
	if not _in_range(distance) or not clear_lane or not _points.try_spend(COST, true):
		return false
	_caster = caster
	_target = target
	_phase = Phase.WINDUP
	return true


## Supply current range and visibility to locked_target(), not to the cursor's
## latest highlighted unit. Invalid state wins over same-tick completion.
func advance(delta: float, locked_distance: float, clear_lane: bool, interrupted := false) -> Phase:
	if _phase != Phase.WINDUP:
		return _phase
	if interrupted or not _caster.is_alive() or not _target.is_alive() or not _in_range(locked_distance) or not clear_lane:
		_phase = Phase.INTERRUPTED
		return _phase
	if not is_finite(delta) or delta <= 0.0:
		return _phase
	_time += delta
	if _time >= WINDUP_SECONDS or is_equal_approx(_time, WINDUP_SECONDS):
		# This paid ability causes ice damage once and does not generate BP.
		_damage_done = _target.receive_hit(_caster, {Unit.Damage.ICE: BASE_ICE_DAMAGE})
		_phase = Phase.RELEASED
	return _phase


## Close a finished invocation before a new attempt. No pool reset or refund.
func reset_after_terminal() -> bool:
	if _phase != Phase.RELEASED and _phase != Phase.INTERRUPTED:
		return false
	_caster = null
	_target = null
	_time = 0.0
	_damage_done = 0.0
	_phase = Phase.IDLE
	return true


static func _in_range(distance: float) -> bool:
	return is_finite(distance) and distance >= 0.0 and distance <= RANGE
