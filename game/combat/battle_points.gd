class_name BattlePoints
extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")

const STARTING_BALANCE := 400
const BASE_CAPACITY := 700
const CAPACITY_PER_LEVEL := 20

enum SpendStatus { READY, INVALID_COST, REQUIREMENTS_NOT_MET, INSUFFICIENT }


## A detached readout. Never use a saved frame to authorize a later spend;
## try_spend always checks the current pool again.
class Frame:
	var balance: int:
		get:
			return _balance
	var capacity: int:
		get:
			return _capacity
	var lead_level: int:
		get:
			return _lead_level

	var _balance: int
	var _capacity: int
	var _lead_level: int

	func _init(current: int, cap: int, level: int) -> void:
		_balance = current
		_capacity = cap
		_lead_level = level

	func spend_status(cost: int, meets_requirements := true) -> SpendStatus:
		return _classify(_balance, cost, meets_requirements)

	static func _classify(current: int, cost: int, meets_requirements: bool) -> SpendStatus:
		if cost < 0:
			return SpendStatus.INVALID_COST
		if not meets_requirements:
			return SpendStatus.REQUIREMENTS_NOT_MET
		return SpendStatus.READY if cost <= current else SpendStatus.INSUFFICIENT


var balance: int:
	get:
		return _balance
var capacity: int:
	get:
		return _capacity

var _balance := STARTING_BALANCE
var _capacity: int
var _lead_level: int


func _init(hero_platoon_level: int = 1) -> void:
	_lead_level = clampi(hero_platoon_level, 1, Unit.MAX_LEVEL)
	_capacity = BASE_CAPACITY + (_lead_level - 1) * CAPACITY_PER_LEVEL


func frame() -> Frame:
	return Frame.new(_balance, _capacity, _lead_level)


# Call only from confirmed combat effects. The resolver supplies the award amount.
func award_confirmed_hit(amount: int) -> int:
	var credited := clampi(amount, 0, _capacity - _balance)
	_balance += credited
	return credited


func can_afford(cost: int) -> bool:
	return Frame._classify(_balance, cost, true) == SpendStatus.READY


# Eligibility (stats, targeting, etc.) is checked independently by the ability caller.
func try_spend(cost: int, meets_requirements: bool) -> bool:
	if Frame._classify(_balance, cost, meets_requirements) != SpendStatus.READY:
		return false
	_balance -= cost
	return true
