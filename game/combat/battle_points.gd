class_name BattlePoints
extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")

const STARTING_BALANCE := 400
const BASE_CAPACITY := 700
const CAPACITY_PER_LEVEL := 20

var balance: int:
	get:
		return _balance
var capacity: int:
	get:
		return _capacity

var _balance := STARTING_BALANCE
var _capacity: int


func _init(hero_platoon_level: int = 1) -> void:
	var level := clampi(hero_platoon_level, 1, Unit.MAX_LEVEL)
	_capacity = BASE_CAPACITY + (level - 1) * CAPACITY_PER_LEVEL


# Call only from confirmed combat effects. The resolver supplies the award amount.
func award_confirmed_hit(amount: int) -> int:
	var credited := clampi(amount, 0, _capacity - _balance)
	_balance += credited
	return credited


func can_afford(cost: int) -> bool:
	return cost >= 0 and cost <= _balance


# Eligibility (stats, targeting, etc.) is checked independently by the ability caller.
func try_spend(cost: int, meets_requirements: bool) -> bool:
	if not meets_requirements or not can_afford(cost):
		return false
	_balance -= cost
	return true
