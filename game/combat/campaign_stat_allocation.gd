extends RefCounted
## Temporary allocation preview. No edits to the profile or a deployed unit.

const Progress := preload("res://game/combat/campaign_platoon_progress.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

var campaign_id: String:
	get:
		return _campaign_id
var lead_level: int:
	get:
		return _lead_level
var budget: int:
	get:
		return maxi(0, _lead_level - 1)
var remaining_points: int:
	get:
		return budget - _spent

var _campaign_id: String
var _lead_level := 0
var _spent := 0
var _allocated: Dictionary[int, int] = {}


func _init(id: String, confirmed_ids: PackedStringArray) -> void:
	_campaign_id = id
	var progression := Progress.inspect(id, confirmed_ids)
	if progression:
		_lead_level = progression.lead_level


func is_valid() -> bool:
	return _lead_level >= 1


func rating(discipline: int) -> int:
	return _base_rating(discipline) + points_for(discipline) if _known_discipline(discipline) else 0


func points_for(discipline: int) -> int:
	return _allocated.get(discipline, 0)


func can_invest(discipline: int) -> bool:
	return is_valid() and _known_discipline(discipline) and remaining_points > 0 and rating(discipline) < Unit.MAX_RATING


func invest(discipline: int) -> bool:
	if not can_invest(discipline):
		return false
	_allocated[discipline] = points_for(discipline) + 1
	_spent += 1
	return true


func can_refund(discipline: int) -> bool:
	return _known_discipline(discipline) and points_for(discipline) > 0


func refund(discipline: int) -> bool:
	if not can_refund(discipline):
		return false
	var spent_here := points_for(discipline) - 1
	if spent_here > 0:
		_allocated[discipline] = spent_here
	else:
		_allocated.erase(discipline)
	_spent -= 1
	return true


## Report the actual modeled Human promotion gate, not a campaign unlock.
## The other factions' exploratory training/role metadata is not equippable here.
func inspect_promotion(target: StringName) -> Dictionary:
	if not is_valid() or _campaign_id != "mara":
		return {}
	var source := Catalog.HUMAN_INFANTRY
	var definition: Dictionary = Catalog.TYPES.get(target, {})
	if definition.get("promotes_from", &"") != source:
		return {}
	var minimums: Dictionary = definition.promotion_minimum_ratings
	var ratings := {}
	var needed_now := 0
	var needed_after_refunds := 0
	for discipline: int in minimums:
		var current := rating(discipline)
		var minimum: int = minimums[discipline]
		var missing := maxi(0, minimum - current)
		ratings[discipline] = {"current": current, "minimum": minimum, "missing": missing}
		needed_now += missing
		needed_after_refunds += maxi(0, minimum - _base_rating(discipline))
	return {
		"source": source,
		"target": target,
		"ratings": ratings,
		"meets_ratings": Catalog.can_promote_with_ratings(source, target, rating),
		"reachable_with_unspent_points": needed_now <= remaining_points,
		"reachable_with_refunds": needed_after_refunds <= budget,
	}


func _base_rating(discipline: int) -> int:
	if _campaign_id == "mara":
		return clampi(Catalog.TYPES[Catalog.HUMAN_INFANTRY].ratings.get(discipline, Unit.MIN_RATING),
			Unit.MIN_RATING, Unit.MAX_RATING)
	return Unit.MIN_RATING


func _known_discipline(discipline: int) -> bool:
	return is_valid() and Unit.Damage.values().has(discipline)
