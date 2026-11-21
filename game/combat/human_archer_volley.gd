class_name HumanArcherVolley
extends RefCounted
## Human bow volley profiles and target-locked shots, independent of either camera.

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")

enum Phase { IDLE, WINDUP, RELOAD }
enum Status { READY, BUSY, INACTIVE, INVALID_TARGET, INVALID_POSITION, PINNED, TOO_CLOSE, TOO_FAR, BLOCKED, HIT }

# Prototype tuning, not global ranged rules. Distances are in meters, times in seconds.
const STARTING_HP := 960.0
const MIN_RANGE := 3.5
const MAX_RANGE := 52.0
const WINDUP_SECONDS := 0.70
const RELOAD_SECONDS := 1.90
const BASIC_ATTACK := {Unit.Damage.RANGED: 52.0}
const HIT_BP := 4
const RELEASE_HEIGHT := 1.45
const IMPACT_HEIGHT := 0.90
const LONGBOW_MAX_RANGE := 66.0
const LONGBOW_WINDUP_SECONDS := 1.25


class Aim:
	var shooter_feet: Vector3
	var target: Unit
	var target_team: int
	var target_feet: Vector3
	var melee_engaged: bool

	func _init(from: Vector3, unit: Unit, team: int, to: Vector3, pinned := false) -> void:
		shooter_feet = from
		target = unit
		target_team = team
		target_feet = to
		melee_engaged = pinned


class Shot:
	var status: Status
	var hp_lost := 0.0
	var bp_credited := 0

	func _init(result: Status) -> void:
		status = result


var phase: Phase:
	get:
		return _phase

var _archer: Unit
var _team: int
var _shared_points: Points
var _clear_lane: Callable
var _locked_target: Unit
var _phase := Phase.IDLE
var _time := 0.0
var _max_range := MAX_RANGE
var _windup_seconds := WINDUP_SECONDS


## The battlefield supplies a clear-lane query (release -> impact) using the same
## coordinate space as Aim. Its terrain and cover may change during the windup.
func _init(archer: Unit, team: int, shared_points: Points, clear_lane: Callable) -> void:
	_archer = archer
	_team = team
	_shared_points = shared_points
	_clear_lane = clear_lane


## Opt-in, provisional resolver profile only. No campaign or promotion uses it.
static func for_marches_longbows(archer: Unit, team: int, shared_points: Points, clear_lane: Callable) -> HumanArcherVolley:
	var volley := HumanArcherVolley.new(archer, team, shared_points, clear_lane)
	volley._max_range = LONGBOW_MAX_RANGE
	volley._windup_seconds = LONGBOW_WINDUP_SECONDS
	return volley


static func make_unit() -> Unit:
	return Unit.new(STARTING_HP)


## Read-only admission and denial reason for command targeting or a HUD.
func status(battle_live: bool, aim: Aim) -> Status:
	if not _active(battle_live):
		return Status.INACTIVE
	if _phase != Phase.IDLE:
		return Status.BUSY
	return _check_aim(aim)


func start(battle_live: bool, aim: Aim) -> Status:
	var check := status(battle_live, aim)
	if check != Status.READY:
		return check
	_locked_target = aim.target
	_phase = Phase.WINDUP
	_time = 0.0
	return Status.READY


## The controller may call this when a move/hold order replaces the attack.
## A new shot takes a full draw from the new position. This cannot skip reload.
func cancel_windup() -> void:
	if _phase == Phase.WINDUP:
		_reset()


## Per-phase fill for a draw or reload indicator.
func phase_progress() -> float:
	match _phase:
		Phase.WINDUP:
			return clampf(_time / _windup_seconds, 0.0, 1.0)
		Phase.RELOAD:
			return clampf((_time - _windup_seconds) / RELOAD_SECONDS, 0.0, 1.0)
	return 0.0


## Supply the current Aim each tick; the target, range, and lane are checked
## again at release. Without an Aim at release the shot cannot deal damage.
## A non-null Shot reports the single release or a melee interruption.
func advance(delta: float, battle_live: bool, aim: Aim = null) -> Shot:
	if _phase == Phase.IDLE:
		return null
	if not _active(battle_live):
		_reset()
		return null
	if not is_finite(delta) or delta <= 0.0:
		return null

	var shot: Shot
	if _phase == Phase.WINDUP and aim != null and aim.melee_engaged:
		# Being engaged in melee breaks the draw immediately. Readying again
		# takes a full reload even if the enemy steps away on the next tick.
		shot = Shot.new(Status.PINNED)
		_time = _windup_seconds
		_begin_reload()
	else:
		_time += delta
		if _phase == Phase.WINDUP and _time >= _windup_seconds:
			shot = _release(aim)
			_begin_reload()
	if _time >= _windup_seconds + RELOAD_SECONDS:
		_reset()
	return shot


func _active(battle_live: bool) -> bool:
	return battle_live and _team >= 0 and _archer != null and _archer.is_alive()


func _check_aim(aim: Aim) -> Status:
	if aim == null or aim.target == null or aim.target == _archer or not aim.target.is_alive() \
			or aim.target_team < 0 or aim.target_team == _team:
		return Status.INVALID_TARGET
	if not aim.shooter_feet.is_finite() or not aim.target_feet.is_finite():
		return Status.INVALID_POSITION
	if aim.melee_engaged:
		return Status.PINNED
	var distance_squared := aim.shooter_feet.distance_squared_to(aim.target_feet)
	if distance_squared < MIN_RANGE * MIN_RANGE:
		return Status.TOO_CLOSE
	if distance_squared > _max_range * _max_range:
		return Status.TOO_FAR
	if not _clear_lane.is_valid() or not _clear_lane.call(
		aim.shooter_feet + Vector3.UP * RELEASE_HEIGHT, aim.target_feet + Vector3.UP * IMPACT_HEIGHT,
	):
		return Status.BLOCKED
	return Status.READY


func _release(aim: Aim) -> Shot:
	if aim == null or aim.target != _locked_target:
		return Shot.new(Status.INVALID_TARGET)
	var check := _check_aim(aim)
	if check != Status.READY:
		return Shot.new(check)

	var shot := Shot.new(Status.HIT)
	shot.hp_lost = aim.target.receive_hit(_archer, BASIC_ATTACK)
	if shot.hp_lost > 0.0 and _shared_points != null:
		shot.bp_credited = _shared_points.award_confirmed_hit(HIT_BP)
	return shot


func _begin_reload() -> void:
	_phase = Phase.RELOAD
	_locked_target = null


func _reset() -> void:
	_phase = Phase.IDLE
	_locked_target = null
	_time = 0.0
