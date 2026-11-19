class_name CombatPlatoon
extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")

enum Skill { CHARGE_BRACE, MOUNTED_TRAINING, FORMATION_DRILL, SCOUTING, SIEGECRAFT, BEAST_HANDLING }

const MAX_RANK := 5
const FULL_COHESION := 100.0

var cohesion: float:
	get:
		return _cohesion

var _cohesion := FULL_COHESION
var _roster: Array[Unit]
var _training: Dictionary


func _init(roster: Array[Unit], training: Dictionary = {}) -> void:
	_roster = roster.duplicate()
	_training = training.duplicate()


func rank(skill: Skill) -> int:
	return clampi(int(_training.get(skill, 0)), 0, MAX_RANK)


# The channels are living HP, missing HP on survivors, and maximum HP lost to casualties.
func health_fractions() -> Vector3:
	var hp_pools := Vector3.ZERO
	for unit in _roster:
		if unit.is_alive():
			hp_pools.x += unit.hp
			hp_pools.y += unit.max_hp - unit.hp
		else:
			hp_pools.z += unit.max_hp
	var total := hp_pools.x + hp_pools.y + hp_pools.z
	return hp_pools / total if total > 0.0 else Vector3.ZERO


func hit_unit(index: int, attacker: Unit, components: Dictionary) -> float:
	if index < 0 or index >= _roster.size():
		return 0.0
	var unit := _roster[index]
	var lost := unit.receive_hit(attacker, components)
	if lost > 0.0 and not unit.is_alive():
		lose_cohesion(22.0)
	return lost


func charge(defender: CombatPlatoon, braced: bool) -> float:
	if not _has_survivors() or not defender._has_survivors():
		return 0.0
	var impact := 24.0 + 8.0 * rank(Skill.CHARGE_BRACE)
	if braced:
		impact -= 8.0 + 6.0 * defender.rank(Skill.CHARGE_BRACE)
	return defender.lose_cohesion(impact)


func lose_cohesion(pressure: float) -> float:
	var loss := maxf(0.0, pressure) / (1.0 + 0.12 * rank(Skill.FORMATION_DRILL))
	loss = minf(loss, _cohesion)
	_cohesion -= loss
	return loss


func reform(seconds: float) -> void:
	_recover_cohesion(seconds, 7.0 + 3.0 * rank(Skill.FORMATION_DRILL))


func mounted_maneuver_seconds(base_seconds: float) -> float:
	return maxf(0.0, base_seconds) / (1.0 + 0.15 * rank(Skill.MOUNTED_TRAINING))


func detection_range(in_cover: bool) -> float:
	var scout_rank := rank(Skill.SCOUTING)
	return 24.0 + 5.0 * scout_rank if in_cover else 48.0 + 8.0 * scout_rank


func can_detect(distance: float, in_cover: bool, has_line_of_sight: bool) -> bool:
	return _has_survivors() and has_line_of_sight and distance >= 0.0 and distance <= detection_range(in_cover)


func siege_setup_seconds() -> float:
	return 12.0 / (1.0 + 0.15 * rank(Skill.SIEGECRAFT))


func siege_hit_chance() -> float:
	return 0.50 + 0.08 * rank(Skill.SIEGECRAFT)


func siege_reload_seconds() -> float:
	return 8.0 / (1.0 + 0.10 * rank(Skill.SIEGECRAFT))


func beasts_follow_orders() -> bool:
	return _has_survivors() and _cohesion >= beast_order_threshold()


func beast_order_threshold() -> float:
	return 60.0 - 8.0 * rank(Skill.BEAST_HANDLING)


func rally_beasts(seconds: float) -> void:
	_recover_cohesion(seconds, 3.0 + 2.0 * rank(Skill.BEAST_HANDLING))


func _recover_cohesion(seconds: float, rate: float) -> void:
	if _has_survivors():
		_cohesion = minf(FULL_COHESION, _cohesion + maxf(0.0, seconds) * rate)


func _has_survivors() -> bool:
	for unit in _roster:
		if unit.is_alive():
			return true
	return false
