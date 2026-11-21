extends RefCounted
## Local planning model for Mara's Shield Infantry slot. Not a deployed platoon,
## saved purchase or loadout. Confirmed clear IDs must come from the campaign
## record; an in-progress attempt or debrief visit is not a clear.

const Catalog := preload("res://game/combat/unit_catalog.gd")
const Platoon := preload("res://game/combat/platoon.gd")

const CAMPAIGN_ID := "mara"
const QUALIFYING_CLEAR := "mara_mine_escort"
const SHIELD_INFANTRY_SLOT := &"mara_shield_infantry"
const DEFAULT_UNIT := Catalog.HUMAN_INFANTRY
const BRANCH_UNIT := Catalog.HUMAN_HEAVY_INFANTRY
const REQUIRED_FORMATION_DRILL := 2

var _is_mara: bool
var _credit_granted: bool
var _trained := false


func _init(campaign_id: String, confirmed_ids: PackedStringArray) -> void:
	_is_mara = campaign_id == CAMPAIGN_ID
	# One entitlement, not one per array entry/result/replay. No other mission
	# can fill in for the first Human chapter.
	_credit_granted = _is_mara and confirmed_ids.has(QUALIFYING_CLEAR)


func available_drill_credit(slot_id: StringName) -> int:
	return 1 if _owns_slot(slot_id) and _credit_granted and not _trained else 0


func formation_drill_rank(slot_id: StringName) -> int:
	if not _owns_slot(slot_id):
		return 0
	var base: int = Catalog.TYPES[DEFAULT_UNIT].platoon_training.get(Platoon.Skill.FORMATION_DRILL, 0)
	return base + int(_trained)


## This only spends the slot's own credit in this model. It does not touch
## lead ratings, tactical BP, or authored training tables.
func train_formation_drill(slot_id: StringName) -> bool:
	if available_drill_credit(slot_id) == 0:
		return false
	_trained = true
	return true


func default_unit_type(slot_id: StringName) -> StringName:
	return DEFAULT_UNIT if _owns_slot(slot_id) else &""


## Eligibility is not equip. The regular default remains unchanged after training.
## Practice and skirmish still use Catalog's separate Melee Power 10 rule.
func qualifies_for_branch(slot_id: StringName, unit_id: StringName) -> bool:
	return _owns_slot(slot_id) and unit_id == BRANCH_UNIT and formation_drill_rank(slot_id) >= REQUIRED_FORMATION_DRILL


func _owns_slot(slot_id: StringName) -> bool:
	return _is_mara and slot_id == SHIELD_INFANTRY_SLOT
