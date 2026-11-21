extends RefCounted
## Canonical counts for regular combat platoons, not individual heroes or auxiliaries.
const REGULAR_MELEE := 32
const REGULAR_MELEE_COLUMNS := 8

## Classify the unit by its combat role at the caller. Other roles retain their
## authored counts until they receive separate rules.
static func count_for(authored_count: int, is_regular_melee: bool) -> int:
	return REGULAR_MELEE if is_regular_melee else authored_count
