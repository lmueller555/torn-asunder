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
	"sova_mine_tunnels": {
		"scene": preload("res://game/battlefield/sova_mine_evacuation_campaign.tscn"),
		"dispatch": Beats.SOVA_MINE_DISPATCH,
		"debrief": Beats.SOVA_MINE_DEBRIEF,
		"orders": "Release both groups at the tunnel mouth and bend. The evacuation is complete when both reach Druid safety and the willing witness is waiting at the outlet. The Godbridle is not your objective.",
	},
	"ilyra_moonwash_rescue": {
		"scene": preload("res://game/battlefield/ilyra_moonwash_rescue_campaign.tscn"),
		"dispatch": Beats.ILYRA_MOONWASH_DISPATCH,
		"briefing_dispatch": true,
		"result_debrief": true,
		"battlefield_label": "MOONWASH HARBOR · RESCUE DECKS",
		"orders": "Reach the stranded deck and rig both lines in either order. Get both crews onto the receiving deck. Hold the Marines at the mooring if salvagers block the forward line. Shore cargo is optional: carry it aboard and load it before the last crew arrives.",
	},
}


const _INTERMISSIONS := {
	"mara": {"moonwash_road": Beats.MARA_WATER_REQUEST},
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
