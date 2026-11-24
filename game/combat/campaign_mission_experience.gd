extends RefCounted
## Results may only be composed from enemies an actual mission owner confirms
## defeated in combat. Visual squad members, withdrawn and despawned actors are
## not additional units. Complete first delivery: Mara's registered Greyhollow.

const XP_PER_DEFEATED_COMBAT_UNIT := 10


class Receipt:
	var error: Error
	var defeated: int
	var clear_xp: int
	var combat_xp: int
	var pending: bool

	func _init(outcome: Error, count: int, clear_amount: int, combat_amount: int, resumable: bool) -> void:
		error = outcome
		defeated = count
		clear_xp = clear_amount
		combat_xp = combat_amount
		pending = resumable

	func total_xp() -> int:
		return clear_xp + combat_xp

	func stored() -> Dictionary:
		return {"defeated": defeated, "clear_xp": clear_xp, "combat_xp": combat_xp}


static func restore(value: Variant) -> Receipt:
	if not value is Dictionary:
		return null
	var defeated: Variant = value.get("defeated")
	var clear_xp: Variant = value.get("clear_xp")
	var combat_xp: Variant = value.get("combat_xp")
	if not defeated is int or not clear_xp is int or not combat_xp is int:
		return null
	if defeated < 0 or clear_xp <= 0 or combat_xp < 0:
		return null
	return Receipt.new(OK, defeated, clear_xp, combat_xp, true)
