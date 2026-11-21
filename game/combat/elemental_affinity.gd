extends RefCounted
## Opt-in counter resolution for an elemental subject. Combat ratings, level
## scaling and HP caps still belong to CombatUnit. No class or spell grants it.

const Unit := preload("res://game/combat/combat_unit.gd")

enum Affinity { NONE, ROOT }
enum Ground { UNKNOWN, DRY, SATURATED }

# Provisional tuning for one matchup, not a universal elemental damage table.
const ROOT_ICE_MULTIPLIER := 1.25
const ROOT_DRAG_SECONDS := 2.0
const ROOT_DRAG_MOVEMENT := 0.70


class Subject:
	var unit: Unit
	var affinity: Affinity

	func _init(combatant: Unit, body_affinity := Affinity.NONE) -> void:
		unit = combatant
		affinity = body_affinity


class HitFacts:
	## The battlefield confirms hostility, current contact through terrain, and
	## the ground under the defender at impact (not under the attacker).
	var opposing := false
	var lane_clear := false
	var defender_ground := Ground.UNKNOWN


class RootDrag:
	var _remaining := ROOT_DRAG_SECONDS

	var remaining: float:
		get:
			return _remaining

	var movement_scale: float:
		get:
			return ROOT_DRAG_MOVEMENT if _remaining > 0.0 else 1.0

	func advance(delta: float) -> void:
		if is_finite(delta) and delta > 0.0:
			_remaining = maxf(0.0, _remaining - delta)
			if is_zero_approx(_remaining):
				_remaining = 0.0


class HitResult:
	var damage_done := 0.0
	var affinity_counter := false
	## Applies only to actual surviving root elementals struck on saturated ground.
	var root_drag: RootDrag


## Resolve a single already released hit. Range/timing/spell cost are upstream
## concerns. A spell's damage type or a high rating never gives its user affinity.
static func resolve(attacker: Unit, defender: Subject, type: Unit.Damage, base_damage: float, facts: HitFacts) -> HitResult:
	var result := HitResult.new()
	if not attacker or not defender or not defender.unit or attacker == defender.unit or not facts:
		return result
	if not attacker.is_alive() or not defender.unit.is_alive() or not facts.opposing or not facts.lane_clear:
		return result
	if type not in Unit.Damage.values() or not is_finite(base_damage) or base_damage <= 0.0:
		return result

	var counter := defender.affinity == Affinity.ROOT and type == Unit.Damage.ICE
	var adjusted := base_damage * ROOT_ICE_MULTIPLIER if counter else base_damage
	if not is_finite(adjusted):
		return result
	result.damage_done = defender.unit.receive_hit(attacker, {type: adjusted})
	result.affinity_counter = counter and result.damage_done > 0.0
	if result.affinity_counter and defender.unit.is_alive() and facts.defender_ground == Ground.SATURATED:
		result.root_drag = RootDrag.new()
	return result
