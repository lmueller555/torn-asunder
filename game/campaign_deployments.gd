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
}


## Missions with a dedicated battlefield script use it. Every other catalog mission runs
## on the generic mission view with its data from game/mission/missions.gd.
## Conversations already written for missions that run on the generic mission view.
const _AUTHORED_BEATS := {
	"orc_well_road": {"dispatch": Beats.RASKA_WELL_ROAD_DISPATCH, "debrief": Beats.RASKA_WELL_ROAD_DEBRIEF},
	"sova_public_record": {"dispatch": Beats.SOVA_PUBLIC_RECORD_DISPATCH, "debrief": Beats.SOVA_PUBLIC_RECORD_DEBRIEF},
	"mara_moonwash_quay": {"dispatch": Beats.MARA_HIGH_QUAY_DISPATCH, "debrief": Beats.MARA_HIGH_QUAY_DEBRIEF},
	"ilyra_moonwash_rescue": {"dispatch": Beats.ILYRA_MOONWASH_DISPATCH},
}


static func for_mission(mission_id: String) -> Dictionary:
	var entry: Dictionary = _DEPLOYMENTS.get(mission_id, {})
	if not entry.is_empty():
		return entry.duplicate()
	var data := MissionData.find(mission_id)
	if data.is_empty():
		return {}
	var beats: Dictionary = _AUTHORED_BEATS.get(mission_id, {})
	var debrief: StringName = beats.get("debrief", StringName(mission_id + "_debrief"))
	if mission_id == "ilyra_moonwash_rescue":
		var view: GDScript = load("res://game/mission/mission_view.gd")
		debrief = Beats.ILYRA_MOONWASH_CARGO_DEBRIEF if view.last_flags.has("cargo_loaded") else Beats.ILYRA_MOONWASH_CREWS_DEBRIEF
	return {
		"scene": GENERIC_SCENE,
		"mission_id": mission_id,
		"dispatch": beats.get("dispatch", StringName(mission_id + "_dispatch")),
		"debrief": debrief,
		"briefing_dispatch": true,
		"battlefield_label": String(data.map.get("name", "")).to_upper(),
		"orders": data.briefing,
	}


static func opening_for_campaign(campaign_id: String) -> Dictionary:
	var missions := Missions.missions_for_campaign(campaign_id)
	if missions.is_empty():
		return {}
	return for_mission(missions[0].id)
