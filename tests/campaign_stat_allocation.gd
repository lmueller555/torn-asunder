extends SceneTree

const Allocation := preload("res://game/combat/campaign_stat_allocation.gd")
const Missions := preload("res://game/campaign_missions.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const MELEE := Unit.Damage.MELEE
const ICE := Unit.Damage.ICE
const HEAVY := Catalog.HUMAN_HEAVY_INFANTRY

# The current campaign curve cannot naturally reach the universal rating cap.
# Exercise cap behavior with a test-only authored base, not extra clear credit.
class NearCap extends Allocation:
	func _base_rating(discipline: int) -> int:
		return Unit.MAX_RATING - 1 if discipline == MELEE else Unit.MIN_RATING


var _failures := 0


func _initialize() -> void:
	_check_budget_and_isolation()
	_check_one_point_transitions()
	_check_rating_cap()
	_check_real_promotion_gate()
	if _failures == 0:
		print("Campaign stat preview: confirmed-clear budgets, all eight disciplines, local invest/refund, distinct campaigns and unchanged Heavy gate passed.")
	quit(0 if _failures == 0 else 1)


func _check_budget_and_isolation() -> void:
	var invalid := Allocation.new("not-authored", [])
	_check(not invalid.is_valid() and invalid.budget == 0 and invalid.rating(MELEE) == 0
		and not invalid.invest(MELEE) and not invalid.refund(MELEE) and invalid.inspect_promotion(HEAVY).is_empty(),
		"Unknown campaigns must be inert.")
	for id in ["mara", "raska", "sova", "ilyra", "neris", "sereth"]:
		var first: String = Missions.missions_for_campaign(id)[0].id
		var last: String = Missions.missions_for_campaign(id)[2].id
		var other := "raska" if id == "mara" else "mara"
		var unrelated := _clears(other)
		var blank := Allocation.new(id, unrelated + PackedStringArray([last, "unknown"]))
		var lead := Allocation.new(id, PackedStringArray([first, first, last]) + unrelated)
		var full := Allocation.new(id, _clears(id))
		var sibling := Allocation.new(id, _clears(id))
		_check(blank.campaign_id == id and blank.lead_level == 1 and blank.budget == 0
			and not blank.can_invest(ICE) and not blank.invest(ICE),
			"Foreign or out-of-order clears must not grant points to " + id)
		_check(lead.lead_level == 2 and lead.budget == 1 and lead.remaining_points == 1
			and lead.invest(ICE) and not lead.invest(MELEE),
			"A duplicate first clear must fund exactly one point for " + id)
		_check(full.lead_level == 3 and full.budget == 2 and full.invest(MELEE)
			and full.remaining_points == 1 and sibling.remaining_points == 2 and sibling.rating(MELEE) == 1,
			"Another local preview or campaign must not share allocations: " + id)
		if id != "mara":
			_check(full.inspect_promotion(HEAVY).is_empty(), "A foreign campaign exposed a Human promotion: " + id)


func _check_one_point_transitions() -> void:
	var draft := Allocation.new("mara", _clears("mara"))
	for invalid in [-1, Unit.Damage.size(), 100, 2147483647]:
		_check(not draft.can_invest(invalid) and not draft.can_refund(invalid)
			and not draft.invest(invalid) and not draft.refund(invalid) and draft.rating(invalid) == 0,
			"An unknown stat discipline must not affect the budget.")
	for discipline: int in Unit.Damage.values():
		_check(draft.rating(discipline) == Unit.MIN_RATING and not draft.can_refund(discipline)
			and draft.can_invest(discipline) and draft.can_invest(discipline)
			and draft.remaining_points == 2, "Eligibility must not buy anything or create a refund.")
		_check(draft.invest(discipline) and draft.rating(discipline) == 2
			and draft.invest(discipline) and draft.rating(discipline) == 3
			and draft.points_for(discipline) == draft.budget and draft.remaining_points == 0,
			"Each investment must buy exactly one rating and consume exactly one point.")
		_check(not draft.can_invest(discipline) and not draft.invest(discipline)
			and not draft.invest(Unit.Damage.MELEE) and draft.rating(discipline) <= Unit.MAX_RATING,
			"Spending past the earned cap must be rejected regardless of discipline.")
		_check(draft.can_refund(discipline) and draft.refund(discipline) and draft.rating(discipline) == 2
			and draft.remaining_points == 1 and draft.refund(discipline) and draft.rating(discipline) == Unit.MIN_RATING
			and draft.remaining_points == 2 and not draft.refund(discipline),
			"Each refund returns exactly one owned point, never the starting rating.")
	_check(draft.invest(MELEE) and draft.invest(ICE) and draft.rating(MELEE) == 2 and draft.rating(ICE) == 2
		and draft.refund(ICE) and draft.rating(MELEE) == 2 and draft.remaining_points == 1,
		"Refunds must return only the chosen discipline's allocation.")


func _check_rating_cap() -> void:
	var draft := NearCap.new("mara", _clears("mara"))
	_check(draft.invest(MELEE) and draft.rating(MELEE) == Unit.MAX_RATING and draft.remaining_points == 1,
		"A normal earned point can reach exactly, but not exceed, the rating cap.")
	_check(not draft.invest(MELEE) and draft.remaining_points == 1 and draft.invest(ICE),
		"A capped discipline cannot waste or box out points intended for other disciplines.")
	_check(draft.refund(MELEE) and draft.rating(MELEE) == Unit.MAX_RATING - 1
		and draft.remaining_points == 1 and not draft.refund(MELEE),
		"Refunding returns to, but never eats into, the authored baseline.")


func _check_real_promotion_gate() -> void:
	var draft := Allocation.new("mara", _clears("mara"))
	var baseline := draft.inspect_promotion(HEAVY)
	draft.invest(MELEE)
	draft.invest(MELEE)
	var gate := draft.inspect_promotion(HEAVY)
	_check(gate.source == Catalog.HUMAN_INFANTRY and gate.target == HEAVY
		and gate.ratings[MELEE] == {"current": 3, "minimum": 10, "missing": 7}
		and baseline.ratings[MELEE] == {"current": 1, "minimum": 10, "missing": 9}
		and not gate.meets_ratings and not gate.reachable_with_unspent_points and not gate.reachable_with_refunds,
		"A fully cleared campaign has two points and cannot reach the actual Melee Power 10 Heavy gate.")
	gate.ratings[MELEE].minimum = 1
	_check(draft.inspect_promotion(HEAVY).ratings[MELEE].minimum == 10
		and draft.inspect_promotion(&"unrecognized").is_empty() and draft.inspect_promotion(Catalog.HUMAN_INFANTRY).is_empty(),
		"Preview data cannot mutate the authoritative tier requirement or fabricate another promotion.")


func _clears(id: String) -> PackedStringArray:
	var selected := PackedStringArray()
	for mission in Missions.missions_for_campaign(id):
		selected.append(mission.id)
	return selected


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
