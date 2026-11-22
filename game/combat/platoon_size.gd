extends RefCounted
## Regular combat ranks exclude leaders, officers, heroes, and auxiliaries.
const REGULAR_MELEE_COLUMNS := 5
const REGULAR_MELEE_RANKS := 6
const REGULAR_MELEE := REGULAR_MELEE_COLUMNS * REGULAR_MELEE_RANKS
const PLATOON_WITH_LEADER := REGULAR_MELEE + 1


## Only non-hero regular melee gets one additional fighting leader.
static func count_for(authored_count: int, is_regular_melee: bool) -> int:
	return PLATOON_WITH_LEADER if is_regular_melee else authored_count
