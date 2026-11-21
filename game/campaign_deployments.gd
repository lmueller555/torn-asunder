extends RefCounted
## Runtime wiring for authored missions with an actual campaign battlefield scene.

const Missions := preload("res://game/campaign_missions.gd")
const Beats := preload("res://game/campaign_dialogues.gd")

const _DEPLOYMENTS := {
	"mara_mine_escort": {
		"scene": preload("res://game/battlefield/mara_mine_escort_campaign.tscn"),
		"dispatch": Beats.MARA_MINE_DISPATCH,
		"debrief": Beats.MARA_MINE_DEBRIEF,
		"orders": "Recover the Godbridle at the mine approach and carry it to the east road exit. Use the ridge and the pass to cover the escort; defeating the road guard is not required.",
	},
	"mara_grain_crossing": {
		"scene": preload("res://game/battlefield/mara_grain_crossing_playtest.tscn"),
		"dispatch": Beats.MARA_GRAIN_DISPATCH,
		"briefing_dispatch": true,
		"result_debrief": true,
		"battlefield_label": "MARCHES CROSSING · BRIDGE AND FORD",
		"orders": "Deliver at least one grain load and resolve both carts. The rival reserve moves against the first cart to commit to a crossing. Screen the threatened lane with a holding platoon, or turn back that cart and get the other through.",
	},
	"mara_moonwash_quay": {
		"scene": preload("res://game/battlefield/mara_moonwash_playtest.tscn"),
		"dispatch": Beats.MARA_HIGH_QUAY_DISPATCH,
		"debrief": Beats.MARA_HIGH_QUAY_DEBRIEF,
		"briefing_dispatch": true,
		"battlefield_label": "MOONWASH HARBOR · UPPER QUAY",
		"orders": "Withdraw the hero and both royal platoons through the upper-quay exit. Hold the landing to cover the retreat, then bring up the rear guard. Use the marked inland bypass if the lower stair closes. Leave the crews and boats to Ilyra.",
	},
	"orc_mine_witness": {
		"scene": preload("res://game/battlefield/raska_mine_witness_campaign.tscn"),
		"dispatch": Beats.RASKA_MINE_DISPATCH,
		"debrief": Beats.RASKA_MINE_DEBRIEF,
		"orders": "Reach the tunnel outlet and stop the Human rear detachment from sealing it. Let the other workers reach safety, accept the willing witness's terms in person, and escort her to the Orc rally. Leave the Godbridle to Mara.",
	},
	"orc_well_road": {
		"scene": preload("res://game/battlefield/raska_well_road_playtest.tscn"),
		"dispatch": Beats.RASKA_WELL_ROAD_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.RASKA_WELL_ROAD_DEBRIEF,
		"battlefield_label": "RED BASIN · SALT ROAD AND COVERED WASH",
		"orders": "Get both well carts to the Basin exit. The upper cart can leave now. Send Raska to the lower storehouse to board the households before ordering their cart. Screen the mounted reserve or take the covered wash.",
	},
	"orc_spanwater_release": {
		"scene": preload("res://game/battlefield/raska_spanwater.tscn"),
		"dispatch": Beats.RASKA_SPANWATER_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.RASKA_SPANWATER_DEBRIEF,
		"victory_coda": Beats.RASKA_SPANWATER_CODA,
		"battlefield_label": "SPANWATER LOCK · BASIN SPILLWAY",
		"orders": "Secure the wheel and send Raska to open the spillway. The lower-town companies will leave. Hold the wheel with the Basin Regulars until the river reaches its mark, then take Raska to the high-bank exit. Leave the sea gate shut.",
	},
	"sova_mine_tunnels": {
		"scene": preload("res://game/battlefield/sova_mine_evacuation_campaign.tscn"),
		"dispatch": Beats.SOVA_MINE_DISPATCH,
		"debrief": Beats.SOVA_MINE_DEBRIEF,
		"orders": "Release both groups at the tunnel mouth and bend. The evacuation is complete when both reach Druid safety and the willing witness is waiting at the outlet. The Godbridle is not your objective.",
	},
	"sova_public_record": {
		"scene": preload("res://game/battlefield/sova_public_record_playtest.tscn"),
		"dispatch": Beats.SOVA_PUBLIC_RECORD_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.SOVA_PUBLIC_RECORD_DEBRIEF,
		"battlefield_label": "CAIRNSPINE ASSEMBLY · PUBLIC HEARING",
		"orders": "Choose one lectern and read all three passages with the public scribe. Hold armed formations outside the hearing ring and leave its public exit clear. Keepers who walk out are not targets.",
	},
	"sova_vault_return": {
		"scene": preload("res://game/battlefield/sova_vault_return_playtest.tscn"),
		"dispatch": Beats.SOVA_VAULT_RETURN_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.SOVA_VAULT_RETURN_DEBRIEF,
		"battlefield_label": "CAIRNSPINE VAULT · SHELF AND SIDE PATH",
		"orders": "The valleys have pledged guards under public custody terms. Take either path with Sova carrying the Godbridle. Hold a guard at the marked approach to clear the closure zone, then finish the vault return. Leave the witness terrace open.",
	},
	"ilyra_moonwash_rescue": {
		"scene": preload("res://game/battlefield/ilyra_moonwash_rescue_campaign.tscn"),
		"dispatch": Beats.ILYRA_MOONWASH_DISPATCH,
		"briefing_dispatch": true,
		"result_debrief": true,
		"battlefield_label": "MOONWASH HARBOR · RESCUE DECKS",
		"orders": "Reach the stranded deck and rig both lines in either order. Get both crews onto the receiving deck. Hold the Marines at the mooring if salvagers block the forward line. Shore cargo is optional: carry it aboard and load it before the last crew arrives.",
	},
	"ilyra_coast_survey": {
		"scene": preload("res://game/battlefield/ilyra_coast_survey_campaign.tscn"),
		"dispatch": Beats.ILYRA_COAST_SURVEY_DISPATCH,
		"briefing_dispatch": true,
		"result_debrief": true,
		"battlefield_label": "MOONWASH SURVEY SHORE · BEACH AND HEADLAND",
		"orders": "Record both readings as Ilyra. Hold the Shore Detachment at a marked guard ring. Transmit from either staffed, secure relay while the cutter is at its stop and in sight. Missed passes return.",
	},
	"neris_failing_grove": {
		"scene": preload("res://game/battlefield/neris_failing_grove_playtest.tscn"),
		"dispatch": Beats.NERIS_FAILING_GROVE_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.NERIS_FAILING_GROVE_DEBRIEF,
		"battlefield_label": "ISOLATED GROVE · RAISED NURSERY ROAD",
		"orders": "Speak to the grove envoy, then call the volunteers. Hold the low-track approach to keep the loading yard clear. Follow the sled along the raised road and help plant the tree at the nursery. Leave the town well alone.",
	},
	"neris_spanwater_feeder": {
		"scene": preload("res://game/battlefield/neris_spanwater_playtest.tscn"),
		"dispatch": Beats.NERIS_SPANWATER_FEEDER_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.NERIS_SPANWATER_FEEDER_DEBRIEF,
		"battlefield_label": "SPANWATER LOCK · RAISED FEEDER PATH",
		"orders": "Clear the inlet rack. Hold a platoon at the marked screen so town workers can fit the guide boards. If the release brings fresh debris, clear it before the crest. The town gauge must reach its mark: river stage alone is not enough.",
	},
	"sereth_voices_at_the_cut": {
		"scene": preload("res://game/battlefield/sereth_cut_playtest.tscn"),
		"dispatch": Beats.SERETH_CUT_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.SERETH_CUT_DEBRIEF,
		"battlefield_label": "STILL KINGDOM CUT · CEMETERY STAIR AND RECORD ROOM",
		"orders": "Hear Iren by the stair and relay her account to the village clerk. Carry the exposed bundle to the record room. If raiders take it, hold a guard to stall them and recover it before they reach the east exit.",
	},
}


const _INTERMISSIONS := {
	"mara": {"moonwash_road": Beats.MARA_WATER_REQUEST},
	"sova": {"cairnspine_vault_road": Beats.SOVA_GODBRIDLE_HANDOVER},
}


static func intermission_at(campaign_id: String, waypoint_id: String) -> StringName:
	return _INTERMISSIONS.get(campaign_id, {}).get(waypoint_id, &"")


static func for_mission(mission_id: String) -> Dictionary:
	var entry: Dictionary = _DEPLOYMENTS.get(mission_id, {})
	return entry.duplicate()


static func opening_for_campaign(campaign_id: String) -> Dictionary:
	var missions := Missions.missions_for_campaign(campaign_id)
	if missions.is_empty():
		return {}
	return for_mission(missions[0].id)
