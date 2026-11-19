class_name CombatUnit
extends RefCounted

enum Damage { MELEE, RANGED, FIRE, LIGHTNING, ICE, NATURE, HOLY, CURSE }

const MAX_RANK := 5

var max_hp: float:
	get:
		return _max_hp
var hp: float:
	get:
		return _hp

var _max_hp: float
var _hp: float
var _ratings: Dictionary


func _init(hit_points: float, ratings: Dictionary = {}) -> void:
	_max_hp = maxf(1.0, hit_points)
	_hp = _max_hp
	_ratings = ratings.duplicate()


func is_alive() -> bool:
	return _hp > 0.0


func receive_hit(attacker: CombatUnit, components: Dictionary) -> float:
	if not is_alive() or not attacker.is_alive():
		return 0.0

	var damage := 0.0
	for type in Damage.values():
		var base_damage := maxf(0.0, float(components.get(type, 0.0)))
		damage += base_damage * attacker.damage_multiplier(type) / damage_multiplier(type)
	var lost := minf(_hp, damage)
	_hp -= lost
	return lost


func damage_multiplier(type: Damage) -> float:
	var rank := clampi(int(_ratings.get(type, 0)), 0, MAX_RANK)
	return 1.0 + 0.1 * rank
