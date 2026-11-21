extends RefCounted
## Prototype attack order: one synchronized melee contact from the infantry.

const Battle := preload("res://game/battlefield/command_battle.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

enum Phase { APPROACH, WINDUP, RECOVERY }

const INFANTRY_INDEX := 0
const TARGET_RADIUS := 2.8
const REACH := 2.35
const STOP_RANGE := 2.10
const WINDUP_TIME := 0.45
const RECOVERY_TIME := 0.85
const BASE_DAMAGE := 42.0
const BP_PER_HIT := 6
const PROTOTYPE_HP := 310.0
const MIN_FORWARD_DOT := 0.50

var attacker: Unit
var _base_damage: float
var phase := Phase.APPROACH
var _remaining := 0.0



func _init(hp := PROTOTYPE_HP, base_damage := BASE_DAMAGE) -> void:
	attacker = Unit.new(hp)
	_base_damage = base_damage


func issue(group: Battle.Formation, enemy: Unit, target: Vector2) -> bool:
	if group.order == Battle.Order.DEFEATED or not attacker.is_alive() or not enemy.is_alive():
		return false
	if group.order != Battle.Order.ATTACK:
		_reset()
		group.destination = target
		group.order = Battle.Order.ATTACK
	return true


func advance(delta: float, battle: Battle, enemy: Unit, target: Vector2, clear_contact: Callable, can_move: Callable) -> float:
	var group := battle.formations[INFANTRY_INDEX]
	if group.order != Battle.Order.ATTACK:
		_reset()
		return 0.0
	if not attacker.is_alive():
		group.defeat()
		_reset()
		return 0.0
	if not enemy.is_alive():
		group.hold()
		_reset()
		return 0.0
	group.destination = target
	var offset := target - group.position
	var distance := offset.length()
	var direction := offset.normalized()
	match phase:
		Phase.APPROACH:
			if distance > 0.0:
				group.heading = direction
			if distance <= REACH and clear_contact.call(group.position, target):
				phase = Phase.WINDUP
				_remaining = WINDUP_TIME
			else:
				var remaining := distance - STOP_RANGE if distance > REACH else distance
				var next := battle.clamp_to_field(group.position + direction * minf(remaining, group.move_speed * delta))
				if next.is_equal_approx(group.position) or not can_move.call(group.position, next, true) or not group.footprint_fits(next):
					group.order = Battle.Order.BLOCKED
					_reset()
				else:
					group.position = next
		Phase.WINDUP:
			_remaining -= delta
			if _remaining <= 0.0:
				# Consume this windup once, even if it missed or the target had cover.
				phase = Phase.RECOVERY
				_remaining = RECOVERY_TIME
				if distance <= REACH and (distance == 0.0 or direction.dot(group.heading) >= MIN_FORWARD_DOT) \
					and clear_contact.call(group.position, target):
					var lost := enemy.receive_hit(attacker, {Unit.Damage.MELEE: _base_damage})
					if not enemy.is_alive():
						group.hold()
						_reset()
					return lost
		Phase.RECOVERY:
			_remaining -= delta
			if _remaining <= 0.0:
				_reset()
	return 0.0


func _reset() -> void:
	phase = Phase.APPROACH
	_remaining = 0.0
