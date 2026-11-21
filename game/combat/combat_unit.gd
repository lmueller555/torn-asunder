class_name CombatUnit
extends RefCounted

enum Damage { MELEE, RANGED, FIRE, LIGHTNING, ICE, NATURE, HOLY, CURSE }

const MIN_RATING := 1
const MAX_RATING := 100
const DEFENSE_WEIGHT := 0.2
const STARTING_HP := 1200.0
const REFERENCE_HIT := 40.0
const MAX_LEVEL := 99
const HP_GROWTH_MULTIPLIER := 6.0
const FIRST_LEVEL_XP := 100
const LEVEL_XP_STEP := 25

var max_hp: float:
	get:
		return _max_hp
var hp: float:
	get:
		return _hp
var level: int:
	get:
		return _level
var experience: int:
	get:
		return _experience
var stat_points: int:
	get:
		return _stat_points

var _starting_hp: float
var _max_hp: float
var _hp: float
var _ratings: Dictionary
var _level := 1
var _level_scale := 1.0
var _experience := 0
var _stat_points := 0


func _init(hit_points: float = STARTING_HP, ratings: Dictionary = {}) -> void:
	_starting_hp = maxf(1.0, hit_points)
	_max_hp = _starting_hp
	_hp = _max_hp
	_ratings = ratings.duplicate()


func is_alive() -> bool:
	return _hp > 0.0


func experience_for_next_level() -> int:
	if _level >= MAX_LEVEL:
		return 0
	return FIRST_LEVEL_XP + LEVEL_XP_STEP * (_level - 1)


func award_experience(amount: int) -> int:
	var gained := 0
	while amount > 0 and _level < MAX_LEVEL:
		var needed := experience_for_next_level() - _experience
		if amount < needed:
			_experience += amount
			break
		amount -= needed
		_experience = 0
		_level += 1
		gained += 1

	if gained == 0:
		return 0

	var previous_max_hp := _max_hp
	# Use levels gained as the HP curve's reference, independent of rating purchases.
	var reference_rating := float(_level - 1)
	var reference_scale := damage_factor(reference_rating, reference_rating)
	var hp_scale := 1.0 + HP_GROWTH_MULTIPLIER * (reference_scale - 1.0)
	_max_hp = _starting_hp * hp_scale
	_level_scale = hp_scale / reference_scale
	if is_alive():
		_hp = _max_hp - (previous_max_hp - _hp)
	_stat_points += gained
	return gained


func rating(type: Damage) -> int:
	return clampi(int(_ratings.get(type, MIN_RATING)), MIN_RATING, MAX_RATING)


func spend_stat_point(type: Damage) -> bool:
	if _stat_points == 0 or not Damage.values().has(type):
		return false
	var current := rating(type)
	if current >= MAX_RATING:
		return false
	_ratings[type] = current + 1
	_stat_points -= 1
	return true


func receive_hit(attacker: CombatUnit, components: Dictionary) -> float:
	if not is_alive() or not attacker.is_alive():
		return 0.0

	return receive_damage(damage_from(attacker, components))


func damage_from(attacker: CombatUnit, components: Dictionary) -> float:
	var damage := 0.0
	for type in Damage.values():
		var base_damage := maxf(0.0, float(components.get(type, 0.0)))
		var matchup := damage_factor(attacker.rating(type), rating(type))
		damage += base_damage * matchup
	# Peer damage grows in proportion to HP. A level gap adds an advantage or resistance.
	return damage * attacker._level_scale * (attacker._level_scale / _level_scale)


func receive_damage(damage: float) -> float:
	var lost := minf(_hp, maxf(0.0, damage))
	# Clear floating-point residue at an exact defeat threshold.
	if _hp - lost <= minf(1.0e-9, lost * 1.0e-9):
		lost = _hp
	_hp -= lost
	return lost


func heal(amount: float) -> float:
	if not is_alive():
		return 0.0
	var gained := minf(_max_hp - _hp, maxf(0.0, amount))
	_hp += gained
	return gained


static func damage_factor(attacking_rating: float, defending_rating: float) -> float:
	return (MAX_RATING + attacking_rating) / (MAX_RATING + DEFENSE_WEIGHT * defending_rating)
