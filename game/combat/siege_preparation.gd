extends RefCounted
## A siege crew trades the ability to move for a prepared shot. The caller
## supplies actual positions, enemy contact, and target/arc knowledge.

const Troop := preload("res://game/combat/platoon.gd")

enum Phase { STOWED, SETTING_UP, READY, RELOADING }

const MIN_RANGE := 12.0
const MAX_RANGE := 54.0
const ANCHOR_TOLERANCE := 0.14


class Shot:
	var origin: Vector2
	var target: Vector2
	var on_target: bool


var phase: Phase:
	get:
		return _phase
var remaining: float:
	get:
		return _remaining

var _crew: Troop
var _anchor := Vector2.ZERO
var _phase := Phase.STOWED
var _remaining := 0.0


func _init(crew: Troop) -> void:
	_crew = crew


## Order and contact changes take priority over cooldown or setup this tick.
func advance(delta: float, position: Vector2, holding: bool, alive: bool, in_melee: bool) -> void:
	if not _crew or not position.is_finite() or not holding or not alive or in_melee:
		_stow()
		return
	if _phase == Phase.STOWED or position.distance_to(_anchor) > ANCHOR_TOLERANCE:
		_anchor = position
		_phase = Phase.SETTING_UP
		_remaining = _crew.siege_setup_seconds()
		return
	if not is_finite(delta) or delta <= 0.0 or _phase == Phase.READY:
		return
	_remaining = maxf(0.0, _remaining - delta)
	if is_zero_approx(_remaining):
		_remaining = 0.0
		_phase = Phase.READY


## A valid shot uses the supplied deterministic roll once. A miss still reloads;
## an invalid request changes neither the crew nor the aiming target.
func fire(target: Vector2, arc_clear: bool, accuracy_roll: float) -> Shot:
	if _phase != Phase.READY or not target.is_finite() or not arc_clear:
		return null
	if not is_finite(accuracy_roll) or accuracy_roll < 0.0 or accuracy_roll >= 1.0:
		return null
	var range_to_target := _anchor.distance_to(target)
	if range_to_target < MIN_RANGE or range_to_target > MAX_RANGE:
		return null
	var shot := Shot.new()
	shot.origin = _anchor
	shot.target = target
	shot.on_target = accuracy_roll < _crew.siege_hit_chance()
	_phase = Phase.RELOADING
	_remaining = _crew.siege_reload_seconds()
	return shot


func _stow() -> void:
	_phase = Phase.STOWED
	_remaining = 0.0
