extends RefCounted
## Runtime wiring for authored missions with an actual campaign battlefield scene.

const Missions := preload("res://game/campaign_missions.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const MissionData := preload("res://game/mission/missions.gd")
const GENERIC_SCENE := preload("res://game/mission/mission_view.tscn")

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
	"ilyra_moonwash_rescue": {
		"scene": preload("res://game/battlefield/ilyra_moonwash_rescue_campaign.tscn"),
		"dispatch": Beats.ILYRA_MOONWASH_DISPATCH,
		"briefing_dispatch": true,
		"result_debrief": true,
		"battlefield_label": "MOONWASH HARBOR · RESCUE DECKS",
		"orders": "Reach the stranded deck and rig both lines in either order. Get both crews onto the receiving deck. Hold the Marines at the mooring if salvagers block the forward line. Shore cargo is optional: carry it aboard and load it before the last crew arrives.",
	},
	"neris_failing_grove": {
		"scene": preload("res://game/battlefield/neris_failing_grove_playtest.tscn"),
		"dispatch": Beats.NERIS_FAILING_GROVE_DISPATCH,
		"briefing_dispatch": true,
		"debrief": Beats.NERIS_FAILING_GROVE_DEBRIEF,
		"battlefield_label": "ISOLATED GROVE · RAISED NURSERY ROAD",
		"orders": "Speak to the grove envoy, then call the volunteers. Hold the low-track approach to keep the loading yard clear. Follow the sled along the raised road and help plant the tree at the nursery. Leave the town well alone.",
	},
}


const _INTERMISSIONS := {
	"mara": {"moonwash_road": Beats.MARA_WATER_REQUEST},
	"ilyra": {"pilot_villages": &"ilyra_record_interlude"},
	"sereth": {"court_chambers": &"sereth_writ_interlude"},
}


static func intermission_at(campaign_id: String, waypoint_id: String) -> StringName:
	return _INTERMISSIONS.get(campaign_id, {}).get(waypoint_id, &"")


## Conversations already written for missions that run on the generic mission view.
const _AUTHORED_BEATS := {
	"sereth_voices_at_the_cut": {"dispatch": Beats.SERETH_CUT_DISPATCH, "debrief": Beats.SERETH_CUT_DEBRIEF},
}


## Missions with a dedicated battlefield script use it. Every other catalog mission runs
## on the generic mission view with its data from game/mission/missions.gd.
static func for_mission(mission_id: String) -> Dictionary:
	var entry: Dictionary = _DEPLOYMENTS.get(mission_id, {})
	if not entry.is_empty():
		return entry.duplicate()
	var data := MissionData.find(mission_id)
	if data.is_empty():
		return {}
	var authored: Dictionary = _AUTHORED_BEATS.get(mission_id, {})
	return {
		"scene": GENERIC_SCENE,
		"mission_id": mission_id,
		"dispatch": authored.get("dispatch", StringName(mission_id + "_dispatch")),
		"debrief": authored.get("debrief", StringName(mission_id + "_debrief")),
		"briefing_dispatch": true,
		"battlefield_label": String(data.map.get("name", "")).to_upper(),
		"orders": data.briefing,
	}


static func opening_for_campaign(campaign_id: String) -> Dictionary:
	var missions := Missions.missions_for_campaign(campaign_id)
	if missions.is_empty():
		return {}
	return for_mission(missions[0].id)
