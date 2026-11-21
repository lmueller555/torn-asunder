extends RefCounted
## Dispatch, debrief and overworld interlude conversations for missions that run on the
## generic mission view. Missions with their own battlefield scripts keep their beats in
## game/campaign_dialogues.gd.

const Missions := preload("res://game/mission/missions.gd")
const Campaigns := preload("res://game/campaigns.gd")

const NARRATOR := "Chronicle"

## Short exchanges before each mission. Speaker IDs resolve through Missions.SPEAKERS.
const DISPATCHES := {
	"mara_grain_crossing": [
		["ally", "Ashmarch wants water or its grain goes home, Majesty. Westmarch wants the grain impounded before it reaches your towns."],
		["mara", "Two carts. Seed for the mill yard, bread for the town store. Which reaches us first?"],
		["aldric", "The bridge is quick and exposed. The ford is slow and screened. Keep a reserve at the fork and we can answer either lane."],
		["mara", "Then we choose under fire. Move out."],
	],
	"mara_moonwash_quay": [
		["judge", "The water reached some of the Marches, Majesty. Not all of them. And there are reports from the coast."],
		["mara", "Then I go and see what I moved. Warn the harbor pilots. We are not there to claim anything."],
		["aldric", "And if the harbor won't have us?"],
		["mara", "Then we leave the way we came, and we write down what we saw."],
	],
	"orc_well_road": [
		["durga", "Halden moved the water again, Marshal. The well road is carrying everything the river used to."],
		["vasha", "And a March company is coming for our carts because their own wells failed."],
		["raska", "Open the lower storehouse to anyone without a well right. March refugees too. Then we run both carts to the exit."],
		["vasha", "My company will escort them. The barrels I count myself."],
	],
	"orc_spanwater_release": [
		["vasha", "Spanwater, Marshal. Two controls. The lower towns want both opened."],
		["raska", "The spillway gives the Basin its river. The sea gate drowns the assembly town."],
		["vasha", "Then you know what we'll ask when you reach the wheel."],
		["raska", "And you know what I'll answer."],
	],
	"sova_public_record": [
		["bryn", "The Keepers have gathered. Some say they'll walk out the moment you open the seal."],
		["sova", "Let them. Walking out is an answer. Spoiling the reading is not."],
		["bryn", "And if armed men come for the record?"],
		["sova", "Then we hold outside the ring, and leave the public exit open for anyone who wants it."],
	],
	"sova_vault_return": [
		["bryn", "Enough valleys have pledged guards. The full account is in the terms; no First Listener can seal it again."],
		["sova", "Then we take it up the pass. No command. Not a word to Orrun."],
		["bryn", "The crowns and the court have not accepted the terms."],
		["sova", "They don't have to accept them. They only have to watch."],
	],
	"ilyra_moonwash_rescue": [
		["captain", "Speaker, the Marches are distracted. The ports say send the pledged ships after the bridle."],
		["ilyra", "That's the corner of my street under that hull. The ships stay. Rig the lines."],
		["pilot", "Two crews on the stone, forward and aft. You'll have to rig each yourself."],
	],
	"ilyra_coast_survey": [
		["captain", "The ports want a chart that proves the old coast can be raised."],
		["ilyra", "They'll have a chart. It will show the drowned streets and the working harbors that would lose their water."],
		["pilot", "Put our soundings on the same sheet, and the villages will help you."],
	],
	"ilyra_spanwater_evacuation": [
		["pilot", "Households are stranded on the low bank at Spanwater. The War Marshal is about to open the spillway."],
		["captain", "Several ports signal: pursue the bridle convoy instead."],
		["ilyra", "The launches stay until the households are clear. Tell them exactly that."],
	],
	"neris_failing_grove": [
		["reeve", "The grove has gone dry since the cut, Rootspeaker. The town will give it a nursery plot if it helps keep the old feeder open."],
		["neris", "I could bring the Deepwood's roots here in a season."],
		["grove", "Not under their wells. Help us move the first tree."],
		["neris", "Then that is what I'll do."],
	],
	"neris_spanwater_feeder": [
		["reeve", "Raska opens the spillway today. The first rush could bury our feeder in silt."],
		["neris", "The nursery needs water through the feeder after the release, not just water in the river."],
		["reeve", "Then clear the rack and keep the March troops off our workers."],
	],
	"neris_cairnspine_passage": [
		["neris", "The groves refused the great crossing. No grove will be bound by a command spoken for it."],
		["reeve", "But they sent volunteers. Refugees and witnesses are at the foot of the pass."],
		["neris", "Then we keep the road open long enough for people to walk it."],
	],
	"sereth_voices_at_the_cut": [
		["aurel", "The bank at the cut fell away from the oldest graves. The village hears voices calling people by name."],
		["sereth", "Then we listen, and we write down exactly what was heard. Nothing more."],
		["aurel", "The court wants names it can recall."],
		["sereth", "The court can wait for a catalog."],
	],
	"sereth_pass_writ": [
		["aurel", "Mara has given the bridle to the First Listener. The court sends a writ requesting an audience before the vault is closed."],
		["sereth", "An audience. Not a seizure. I'll carry it myself."],
		["aurel", "A March patrol watches the road, with a mounted reserve."],
	],
	"sereth_no_proxy": [
		["aurel", "The court has named its speaker, Executor. You are ordered to escort him to the vault."],
		["sereth", "To speak for people who left no permission."],
		["aurel", "There's something else. The clerk found a letter in the Hollowmere records. It's addressed to you."],
	],
}

## Overworld scenes between missions, keyed by the waypoint's "beat".
const INTERLUDES := {
	"mara_command_interlude": {
		"title": "Precise Wording",
		"location": "Headwater Council · Year Two",
		"lines": [
			["ally", "A second failed harvest, Majesty. Ashmarch cannot stay pledged to a crown that cannot water it."],
			["mara", "Then I will speak to Orrun. Water back into the dry headwater channels of the Marches. Only ours."],
			["judge", "And whose water could fill them, Majesty?"],
			["mara", "I have chosen the words carefully. The neighbors will be spared."],
			["narrator", "Orrun heard him. No one yet knew what it would move."],
		],
	},
	"raska_assembly_interlude": {
		"title": "A River, Not a Sea",
		"location": "Assembly Town · Year Four",
		"lines": [
			["vasha", "The breach at Spanwater branches near the old spillway. The lower towns want it widened, and the sea gate opened."],
			["raska", "The sea would come in over this town. Over the assembly that elected me."],
			["vasha", "They'll recall their companies if you refuse."],
			["raska", "Then they'll recall them. I was sent for a river."],
		],
	},
	"sova_handover_interlude": {
		"title": "Custody, Not Ownership",
		"location": "Spanwater high bank · Year Four",
		"lines": [
			["narrator", "After the breach at Spanwater, King Mara refused to ask Orrun to close it."],
			["mara", "I will not give a second order to fix the first. Take it, Listener, before a rival crown does."],
			["sova", "I'll open the seal only to see what changes hands. Into my keeping, not my ownership."],
			["raska", "The Basin witnesses it."],
			["ilyra", "So does the coast."],
			["narrator", "In Year Five, enough Keepers pledged guards for the vault road once Sova read the full account into the terms of custody."],
		],
	},
	"ilyra_record_interlude": {
		"title": "Whose Coast",
		"location": "Pilot villages · Year Two",
		"lines": [
			["pilot", "A copy of the Druid record came on the morning boat, Speaker."],
			["ilyra", "Their first command raised the Cairnspine and drowned my city. Now I know where to look."],
			["pilot", "And now you've seen what one rising harbor does to the people living above it."],
			["ilyra", "Then I'll count them too. Every one."],
		],
	},
	"neris_nursery_interlude": {
		"title": "Room to Grow",
		"location": "Town nursery · Year Three",
		"lines": [
			["reeve", "The first tree has taken. The rest will need time, and the feeder kept clear."],
			["neris", "The grove's crews will keep it clear. That was the bargain."],
			["grove", "No crossing under their wells."],
			["neris", "No crossing. I'll still look for the Godbridle, in case another grove has no town to bargain with."],
		],
	},
	"sereth_writ_interlude": {
		"title": "A Later Ruling",
		"location": "The Still Court · Year Four",
		"lines": [
			["aurel", "The court thanks you for the catalog. It would have preferred the names."],
			["sereth", "A voice is a reason to listen. It is not permission to bring anyone back."],
			["aurel", "The court has deferred the question of consent. It has not deferred its claim on the bridle."],
			["sereth", "Then I'll deliver its writ exactly as written."],
		],
	},
}


static func has_beat(id: StringName) -> bool:
	var text := String(id)
	if INTERLUDES.has(text):
		return true
	for suffix in ["_dispatch", "_debrief"]:
		if text.ends_with(suffix) and not Missions.find(text.trim_suffix(suffix)).is_empty():
			return true
	return false


## Builds a dialogue beat in the campaign dialogue format. Debriefs read the flags
## recorded when the mission ended.
static func get_beat(id: StringName, flags: Dictionary = {}) -> Dictionary:
	var text := String(id)
	if INTERLUDES.has(text):
		var interlude: Dictionary = INTERLUDES[text]
		return {"title": interlude.title, "location": interlude.location, "lines": _lines(interlude.lines)}
	if text.ends_with("_dispatch"):
		var mission := Missions.find(text.trim_suffix("_dispatch"))
		if mission.is_empty():
			return {}
		var lines: Array = DISPATCHES.get(mission.id, [])
		var built := _lines(lines)
		if built.is_empty():
			built.append({"speaker": NARRATOR, "text": mission.briefing})
		return {"title": mission.title, "location": "%s · %s" % [mission.map.get("name", ""), mission.year], "lines": built}
	if text.ends_with("_debrief"):
		var mission := Missions.find(text.trim_suffix("_debrief"))
		if mission.is_empty():
			return {}
		var built: Array[Dictionary] = []
		for paragraph in String(mission.debrief).split("\n\n"):
			if not paragraph.strip_edges().is_empty():
				built.append({"speaker": NARRATOR, "text": paragraph.strip_edges()})
		var variants: Dictionary = mission.get("debrief_flags", {})
		for key: String in variants:
			var wanted := not key.begins_with("!")
			if flags.has(key.trim_prefix("!")) == wanted:
				built.insert(0, {"speaker": NARRATOR, "text": variants[key]})
		return {"title": "After: %s" % mission.title, "location": "%s · %s" % [mission.map.get("name", ""), mission.year], "lines": built}
	return {}


static func _lines(source: Array) -> Array[Dictionary]:
	var portraits := {}
	for campaign in Campaigns.ALL:
		portraits[campaign.id] = campaign.portrait
	var result: Array[Dictionary] = []
	for entry: Array in source:
		var speaker_id: String = entry[0]
		var name: String = Missions.SPEAKERS.get(speaker_id, speaker_id)
		if name.is_empty():
			name = NARRATOR
		var line := {"speaker": name, "text": entry[1]}
		if portraits.has(speaker_id):
			line["portrait"] = portraits[speaker_id]
		result.append(line)
	return result
