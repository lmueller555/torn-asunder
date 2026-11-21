extends RefCounted
## Commands one proxy volley for Mara's Archers. Archers never move to chase a target.

const Battle := preload("res://game/battlefield/command_battle.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")

const ARCHER_INDEX := 1
const PIN_RANGE := 2.40
# Preserve the Archer's 80% relative HP at the encounter's 310 HP proxy scale.
const PROTOTYPE_HP := 248.0

var attacker := Unit.new(PROTOTYPE_HP)
var volley: Archer
var _enemy_team: int


func _init(points: Points, team: int, enemy_team: int, clear_lane: Callable) -> void:
	volley = Archer.new(attacker, team, points, clear_lane)
	_enemy_team = enemy_team


func issue(group: Battle.Formation, enemy: Unit, target: Vector2, feet: Callable, clear_melee: Callable) -> Archer.Status:
	if not attacker.is_alive() or not enemy.is_alive():
		return Archer.Status.INACTIVE
	if group.order == Battle.Order.ATTACK:
		return Archer.Status.READY
	var status := volley.start(true, _aim(group, enemy, target, feet, clear_melee))
	if status == Archer.Status.READY:
		_face_target(group, target)
		group.order = Battle.Order.ATTACK
	return status


func advance(
	delta: float, battle_live: bool, group: Battle.Formation, enemy: Unit, target: Vector2,
	feet: Callable, clear_melee: Callable,
) -> Archer.Shot:
	if group.order != Battle.Order.ATTACK or not battle_live or not enemy.is_alive() or not attacker.is_alive():
		if group.order == Battle.Order.ATTACK:
			group.hold()
		volley.cancel_windup()
		# Time spent holding or moving counts toward a reload; it never resets it.
		volley.advance(delta, battle_live)
		return null
	_face_target(group, target)
	var aim := _aim(group, enemy, target, feet, clear_melee)
	var shot := volley.advance(delta, battle_live, aim)
	if not enemy.is_alive():
		group.hold()
	elif volley.phase == Archer.Phase.IDLE:
		var status := volley.start(battle_live, aim)
		if status not in [Archer.Status.READY, Archer.Status.PINNED, Archer.Status.TOO_CLOSE]:
			group.hold()
			group.order = Battle.Order.BLOCKED
			return Archer.Shot.new(status)
	return shot


func _aim(group: Battle.Formation, enemy: Unit, target: Vector2, feet: Callable, clear_melee: Callable) -> Archer.Aim:
	var pinned: bool = group.position.distance_squared_to(target) <= PIN_RANGE * PIN_RANGE \
		and clear_melee.call(group.position, target)
	return Archer.Aim.new(feet.call(group.position), enemy, _enemy_team, feet.call(target), pinned)


func _face_target(group: Battle.Formation, target: Vector2) -> void:
	group.destination = target
	var offset := target - group.position
	if not offset.is_zero_approx():
		group.heading = offset.normalized()
