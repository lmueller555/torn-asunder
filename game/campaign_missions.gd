extends RefCounted
## Authored mission order and battlefield routing, not runtime availability.
## The design counterparts are in docs/campaigns/implementation-index.md.

const _BY_CAMPAIGN := {
	"mara": [
		{"id": "mara_mine_escort", "title": "Get Them Out", "year": 3, "battlefield_id": "year_one_mine"},
		{"id": "mara_grain_crossing", "title": "Grain on Credit", "year": 3, "battlefield_id": "marches_crossing"},
		{"id": "mara_moonwash_quay", "title": "The High Quay", "year": 3, "battlefield_id": "moonwash_harbor"},
	],
	"raska": [
		{"id": "orc_mine_witness", "title": "One Person to Ask", "year": 1, "battlefield_id": "year_one_mine"},
		{"id": "orc_well_road", "title": "The Second Bucket", "year": 3, "battlefield_id": "red_basin_well_road"},
		{"id": "orc_spanwater_release", "title": "River, Not Sea", "year": 4, "battlefield_id": "spanwater_lock"},
	],
	"sova": [
		{"id": "sova_mine_tunnels", "title": "The Workers' Way Out", "year": 1, "battlefield_id": "year_one_mine"},
		{"id": "sova_public_record", "title": "Let Them Walk Out", "year": 2, "battlefield_id": "cairnspine_vault_road"},
		{"id": "sova_vault_return", "title": "No New Command", "year": 5, "battlefield_id": "cairnspine_vault_road"},
	],
	"ilyra": [
		{"id": "ilyra_moonwash_rescue", "title": "Hulls on Stone", "year": 2, "battlefield_id": "moonwash_harbor"},
		{"id": "ilyra_coast_survey", "title": "Two Shorelines", "year": 3, "battlefield_id": "moonwash_survey_shore"},
		{"id": "ilyra_spanwater_evacuation", "title": "Last Boat at Spanwater", "year": 4, "battlefield_id": "spanwater_lock"},
	],
	"neris": [
		{"id": "neris_failing_grove", "title": "What We Planted Here", "year": 3, "battlefield_id": "isolated_grove_nursery"},
		{"id": "neris_spanwater_feeder", "title": "Water at the Town Gauge", "year": 4, "battlefield_id": "spanwater_lock"},
		{"id": "neris_cairnspine_passage", "title": "A Road We Can Share", "year": 5, "battlefield_id": "cairnspine_vault_road"},
	],
	"sereth": [
		{"id": "sereth_voices_at_the_cut", "title": "The Names at the Cut", "year": 3, "battlefield_id": "still_kingdom_cut"},
		{"id": "sereth_pass_writ", "title": "An Audience, Not a Seizure", "year": 4, "battlefield_id": "cairnspine_boundary_post"},
		{"id": "sereth_no_proxy", "title": "The Lamp in the Window", "year": 5, "battlefield_id": "cairnspine_vault_road"},
	],
}


## Returns a copy in campaign order; an unknown campaign returns an empty list.
static func missions_for_campaign(campaign_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _rows(campaign_id):
		result.append(entry.duplicate())
	return result


## An unknown mission or one belonging to another campaign returns an empty dictionary.
static func mission_for_campaign(campaign_id: String, mission_id: String) -> Dictionary:
	for entry: Dictionary in _rows(campaign_id):
		if entry.id == mission_id:
			return entry.duplicate()
	return {}


## Returns the first uncleared mission in authored order (including on a fresh save).
## An unknown or fully cleared campaign returns an empty string.
static func first_unplayed_mission_id(campaign_id: String, completed_ids: PackedStringArray) -> String:
	for entry: Dictionary in _rows(campaign_id):
		if not completed_ids.has(entry.id):
			return entry.id
	return ""


## A mission can be replayed once all its predecessors are cleared. Duplicate,
## unknown, or foreign clear IDs cannot unlock past a missing predecessor.
## This checks progression only; the caller separately decides what can launch.
static func is_unlocked(campaign_id: String, mission_id: String, completed_ids: PackedStringArray) -> bool:
	for entry: Dictionary in _rows(campaign_id):
		if entry.id == mission_id:
			return true
		if not completed_ids.has(entry.id):
			return false
	return false


## The immediate authored successor, independent of progression or runtime wiring.
## An unknown mission or one at the end of its campaign returns an empty string.
static func successor_id(campaign_id: String, mission_id: String) -> String:
	var rows := _rows(campaign_id)
	for index in rows.size() - 1:
		if rows[index].id == mission_id:
			return rows[index + 1].id
	return ""


static func _rows(campaign_id: String) -> Array:
	return _BY_CAMPAIGN.get(campaign_id, [])
