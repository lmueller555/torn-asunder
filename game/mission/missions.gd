extends RefCounted
## The eighteen campaign missions of the five-year war.
##
## Six campaigns of three missions each tell one story. Several battles are fought
## from more than one side: the Greyhollow Mine (Mara, Raska, Sova), the Kingswell
## moot (Mara, Raska) and the Drowned Road (Ilyra, Sereth). Every campaign ends at
## the Vault of the First Command in Year Five, on a different part of the field.
## See docs/story.md for the full timeline.

const Maps := preload("res://game/mission/maps.gd")

const SPEAKERS := {
	"narrator": "",
	"sova": "Sova Cairn",
	"ilyra": "Ilyra Venn",
	"mara": "Mara Halden",
	"raska": "Raska Vennor",
	"neris": "Neris Alder",
	"sereth": "Sereth Vale",
	"aldric": "Ser Aldric Thorne",
	"durga": "Durga Ashtusk",
	"edrin": "Edrin Coll",
	"bryn": "Keeper Bryn Hollin",
	"orla": "Keeper Orla Thane",
	"brannoc": "Ser Brannoc Hale",
	"maren": "Maren Tull",
	"rook": "Captain Wystan Rook",
	"corvin": "Corvin Ashe",
	"aurel": "Advocate Aurel Mott",
	"choir": "The Drowned Choir",
	"hollis": "Reeve Hollis Bram",
	"skarn": "Skarn Emberhand",
	"gorrum": "Gorrum Saltjaw",
	"isolde": "Queen Isolde Varr",
	"ashgrove": "Ashgrove",
	"voice": "A voice in the stones",
	"miner": "A Greyhollow miner",
}

static var _cache: Dictionary = {}


static func for_campaign(id: String) -> Array:
	if _cache.is_empty():
		_cache = {
			"mara": [_mara_1(), _mara_2(), _mara_3()],
			"raska": [_raska_1(), _raska_2(), _raska_3()],
			"sova": [_sova_1(), _sova_2(), _sova_3()],
			"ilyra": [_ilyra_1(), _ilyra_2(), _ilyra_3()],
			"sereth": [_sereth_1(), _sereth_2(), _sereth_3()],
			"neris": [_neris_1(), _neris_2(), _neris_3()],
		}
	return _cache.get(id, [])


static func _p(id: String, type: StringName, team: int, count: int, level: int, pos: Variant, extra: Dictionary = {}) -> Dictionary:
	var entry := {"id": id, "type": type, "team": team, "count": count, "level": level, "pos": pos}
	entry.merge(extra, true)
	return entry


static func _hero(id: String, type: StringName, team: int, level: int, pos: Variant, extra: Dictionary = {}) -> Dictionary:
	return _p(id, type, team, 1, level, pos, extra)


const ALLY := 0
const FOE := 1
const LAST_COMMAND := "In the Listening Chamber, six leaders who had spent five years at war spoke one command together, each in their own tongue, each naming who would bear its cost.\n\n“Sleep, Orrun. Sleep, and hear no one.”\n\nThe Godbridle went cold. The rivers stayed where they ran, the coast stayed drowned, the groves stayed scattered, and the dead stayed silent. Everything the god had made would now have to be shared by treaty, at wells and harbors and tables, by people who would have to keep asking one another."


# ======================================================================= MARA


static func _mara_1() -> Dictionary:
	return {
		"id": "mara_1",
		"title": "The Greyhollow Pass",
		"year": "Year One · Spring",
		"briefing": "The miners asked the Godbridle for water, and a river a hundred miles away ran dry. Mara has taken the artifact under his royal seal. Escort the bridle wagon down the pass before the Orc companies following their dead river can cut the road.",
		"epilogue": "The wagon reached the Marches road with its seal unbroken. Behind it, the Orcs carried off the foreman, Edrin Coll, and the rest of the miners vanished into tunnels no Human map recorded. Mara rode home with the most powerful object in Vareth and no one left who could tell him how it had been used.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(4, -56), "facing": Vector2(0, 1)},
		"hero_level": 5,
		"structures": [
			{"id": "wagon", "kind": &"wagon", "team": ALLY, "pos": Vector2(0, -60), "moving": true, "speed": 1.7, "escort_radius": 14.0,
				"path": [Vector2(0, -40), Vector2(0, -30), Vector2(-2, 0), Vector2(0, 30), Vector2(0, 64)]},
		],
		"platoons": [
			_p("shields", &"marcher_infantry", ALLY, 20, 3, Vector2(-5, -50), {"name": "Halden Shields", "persist": "shields", "order": {"kind": "follow"}}),
			_p("archers", &"marcher_archers", ALLY, 12, 3, Vector2(8, -51), {"name": "Ridge Archers", "persist": "archers", "order": {"kind": "follow"}}),
			_p("scouts", &"basin_slingers", FOE, 10, 2, Vector2(36, -46), {"name": "Basin Scouts", "aggro": 20.0}),
			_p("redwater", &"basin_warriors", FOE, 18, 3, Vector2(48, -8), {"name": "Redwater Company", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "attack", "target": "hero"}}),
			_p("redwater_slings", &"basin_slingers", FOE, 10, 3, Vector2(50, -6), {"name": "Redwater Slingers", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "hunt"}}),
			_hero("durga", &"durga", FOE, 6, Vector2(34, 44), {"name": "Durga Ashtusk", "hidden": true, "order": {"kind": "hunt"}}),
			_p("saltwell", &"basin_warriors", FOE, 18, 4, Vector2(36, 36), {"name": "Saltwell Company", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "assault", "to": "lower_pass"}}),
		],
		"objectives": [
			{"id": "escort", "text": "Escort the bridle wagon to the Marches road", "type": "reach", "who": "wagon", "zone": "pass_mouth"},
			{"id": "wagon", "text": "The wagon must survive", "type": "protect", "who": ["wagon"], "fail_text": "The Orcs seized the Godbridle."},
			{"id": "durga", "text": "Defeat Durga Ashtusk", "type": "defeat", "who": ["durga"], "hidden": true, "optional": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "mara", "The wagon moves when I am close. Shields, keep to me. Archers, watch the eastern ridge."],
				["say", "aldric", "Orc scouts on the plateau, Majesty. They have been following the riverbed for days."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Mara."]]},
			{"if": {"zone": ["wagon", "pass_top"]}, "do": [
				["spawn", "redwater"], ["spawn", "redwater_slings"],
				["say", "raska", "Halden! You carry what drank our river. Give me the ones who used it, or give me that wagon."],
				["say", "mara", "The wagon stops while they are on it. Clear the riverbed."],
			]},
			{"if": {"zone": ["wagon", "lower_pass"]}, "do": [
				["spawn", "saltwell"], ["spawn", "durga"], ["objective", "durga"],
				["say", "durga", "The Marshal wants the miners. I want the wagon. Saltwell, with me!"],
			]},
			{"if": {"dead": "durga"}, "do": [["say", "aldric", "Ashtusk is down. The road is open."]]},
			{"if": {"done": "escort"}, "do": [
				["say", "mara", "Seal the wagon. Not one hand touches it before we reach Haldenford."],
				["victory", "The Godbridle reached the Seven Marches."],
			]},
		],
	}


static func _mara_2() -> Dictionary:
	return {
		"id": "mara_2",
		"title": "The Kingswell Moot",
		"year": "Year Two · Summer",
		"briefing": "Mara has called the seven crowns to Kingswell to bargain for the bridle’s water. War Marshal Raska answers under a parley flag, bringing the foreman Edrin Coll to testify. Keep the crowns’ pavilions standing and the witness alive. Not every crown wants this moot to end in peace.",
		"epilogue": "Edrin testified at the well-stone: the spring at Greyhollow had been the Red Basin’s river. By Marcher law, a ruler’s first duty is to the people downstream. Mara swore on the well to return the water. Three crowns walked out. That night his chancellor, Corvin Ashe, rode north with a sealed letter for Queen Isolde of the Lowmarch.",
		"map": Maps.kingswell(),
		"hero": {"pos": Vector2(0, 10), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"structures": [
			{"id": "pavilion_west", "kind": &"pavilion", "team": ALLY, "pos": Vector2(-14, -10), "name": "Westmarch pavilion"},
			{"id": "pavilion_east", "kind": &"pavilion", "team": ALLY, "pos": Vector2(14, -10), "name": "Rivergate pavilion"},
			{"id": "pavilion_south", "kind": &"pavilion", "team": ALLY, "pos": Vector2(-2, 15), "name": "Halden pavilion"},
		],
		"platoons": [
			_p("shields", &"marcher_infantry", ALLY, 20, 8, Vector2(-6, 4), {"name": "Halden Shields", "persist": "shields", "order": {"kind": "follow"}}),
			_p("archers", &"marcher_archers", ALLY, 12, 8, Vector2(6, 4), {"name": "Ridge Archers", "persist": "archers", "order": {"kind": "follow"}}),
			_p("rivergate", &"marcher_infantry", ALLY, 18, 7, Vector2(0, -16), {"name": "Rivergate Infantry", "persist": "rivergate", "order": {"kind": "hold"}}),
			_hero("raska", &"raska", ALLY, 10, Vector2(34, 46), {"name": "Raska Vennor", "hidden": true, "commandable": false, "order": {"kind": "move", "to": Vector2(14, 20)}}),
			_p("raska_escort", &"basin_warriors", ALLY, 14, 8, Vector2(38, 50), {"name": "Raska's Escort", "hidden": true, "commandable": false, "order": {"kind": "move", "to": Vector2(18, 24)}}),
			_hero("edrin", &"edrin", ALLY, 6, Vector2(36, 48), {"name": "Edrin Coll", "hidden": true, "commandable": false, "order": {"kind": "move", "to": Vector2(16, 24)}}),
			_p("knights_west", &"lowmarch_knights", FOE, 18, 9, Vector2(-10, -52), {"name": "Unmarked Riders", "hidden": true, "order": {"kind": "assault", "to": Vector2(-14, -10)}}),
			_p("knights_east", &"lowmarch_knights", FOE, 18, 9, Vector2(22, -52), {"name": "Unmarked Riders", "hidden": true, "order": {"kind": "assault", "to": Vector2(14, -10)}}),
			_p("crossbows", &"lowmarch_crossbows", FOE, 12, 9, Vector2(6, -50), {"name": "Lowmarch Crossbows", "hidden": true, "order": {"kind": "move", "to": Vector2(6, -44)}, "aggro": 18.0}),
			_hero("brannoc", &"brannoc", FOE, 12, Vector2(-48, 0), {"name": "Ser Brannoc Hale", "hidden": true, "order": {"kind": "attack", "target": "edrin"}}),
			_p("knights_woods", &"lowmarch_knights", FOE, 18, 10, Vector2(-46, 8), {"name": "Lowmarch Knights", "hidden": true, "facing": Vector2(1, 0), "order": {"kind": "attack", "target": "edrin"}}),
		],
		"objectives": [
			{"id": "pavilions", "text": "Keep the crowns' pavilions standing", "type": "protect", "who": ["pavilion_west", "pavilion_east", "pavilion_south"], "fail_text": "A crown's pavilion burned. The moot collapsed into war."},
			{"id": "riders", "text": "Drive off the unmarked riders", "type": "defeat", "who": ["knights_west", "knights_east", "crossbows"], "hidden": true},
			{"id": "edrin", "text": "Edrin Coll must survive", "type": "protect", "who": ["edrin"], "hidden": true, "fail_text": "The witness was killed before he could testify."},
			{"id": "brannoc", "text": "Defeat Ser Brannoc Hale", "type": "defeat", "who": ["brannoc"], "hidden": true},
			{"id": "testify", "text": "Let Edrin reach the Kingswell", "type": "reach", "who": "edrin", "zone": "well", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "mara", "Seven crowns, one well. Whatever is said here, no blade is drawn inside the moot."],
				["say", "narrator", "War Marshal Raska approaches along the Basin road under a parley flag."],
				["spawn", "raska"], ["spawn", "raska_escort"], ["spawn", "edrin"],
			]},
			{"if": {"time": 10.0}, "do": [
				["say", "raska", "I bring the man who asked your bridle for water. Let him speak at your well, King of Halden."],
				["say", "edrin", "I only wanted the camp to drink. I didn't know what it would take from them."],
			]},
			{"if": {"time": 20.0}, "do": [
				["spawn", "knights_west"], ["spawn", "knights_east"], ["spawn", "crossbows"],
				["objective", "riders"], ["objective", "edrin"],
				["say", "aldric", "Riders at the fords! No colors, but those are Lowmarch horses."],
				["say", "mara", "Protect the pavilions. Whoever sent them wants the crowns to blame the Orcs."],
			]},
			{"if": {"time": 24.0}, "do": [["say", "raska", "My escort will fight beside yours, Halden. Keep this war between us honest."]]},
			{"if": {"any": [{"done": "riders"}, {"time": 150.0}]}, "do": [
				["spawn", "brannoc"], ["spawn", "knights_woods"], ["objective", "brannoc"],
				["say", "brannoc", "The witness dies here. Queen Isolde sends her regards to the moot."],
				["say", "mara", "Isolde. Then the Lowmarch has already chosen war. Guard Edrin!"],
			]},
			{"if": {"done": "brannoc"}, "do": [
				["objective", "testify"], ["order", "edrin", {"kind": "move", "to": "well"}],
				["say", "edrin", "Then I'll say it where everyone can hear."],
			]},
			{"if": {"done": "testify"}, "delay": 2.0, "do": [
				["say", "edrin", "The spring came up through our camp. The same night, the Basin's river died. I asked for it. I'm sorry."],
				["say", "mara", "By the oath of the wells, the downstream comes first. The water goes back to the Basin."],
				["victory", "The crowns heard the testimony at the Kingswell."],
			]},
		],
	}


static func _mara_3() -> Dictionary:
	return {
		"id": "mara_3",
		"title": "The King’s Causeway",
		"year": "Year Five · The Last Command",
		"briefing": "Five years on, the six peoples have gathered at the Vault of the First Command to decide what to tell Orrun. Queen Isolde of the Lowmarch leads her host up the southern causeway to take the vault before they can agree. Mara holds the causeway: the crown he promised water to now marches against him.",
		"epilogue": "Isolde fell on the causeway with her banner still in her hand. When Mara climbed to the Listening Chamber, he broke his royal seal over the Godbridle in front of the other five. “I promised water I had no right to give,” he said. “I will not give a command I have no right to speak alone.”",
		"map": Maps.vault(),
		"hero": {"pos": Vector2(0, 30), "facing": Vector2(0, 1)},
		"hero_level": 18,
		"platoons": [
			_p("shields", &"marcher_infantry", ALLY, 20, 16, Vector2(-5, 36), {"name": "Halden Shields", "persist": "shields", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("archers", &"marcher_archers", ALLY, 12, 16, Vector2(0, 26), {"name": "Ridge Archers", "persist": "archers", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("rivergate", &"marcher_infantry", ALLY, 18, 15, Vector2(6, 36), {"name": "Rivergate Infantry", "persist": "rivergate", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("vanguard", &"lowmarch_knights", FOE, 18, 16, Vector2(-3, 80), {"name": "Lowmarch Vanguard", "order": {"kind": "assault", "to": "causeway"}, "facing": Vector2(0, -1)}),
			_p("crossbows", &"lowmarch_crossbows", FOE, 12, 16, Vector2(4, 82), {"name": "Lowmarch Crossbows", "order": {"kind": "move", "to": Vector2(0, 62)}, "aggro": 18.0, "facing": Vector2(0, -1)}),
			_p("wave_two", &"lowmarch_knights", FOE, 18, 17, Vector2(0, 82), {"name": "Lowmarch Knights", "hidden": true, "order": {"kind": "assault", "to": "causeway"}, "facing": Vector2(0, -1)}),
			_p("wave_two_b", &"saltjaw_raiders", FOE, 16, 16, Vector2(6, 80), {"name": "Saltjaw Raiders", "hidden": true, "order": {"kind": "assault", "to": "causeway"}, "facing": Vector2(0, -1)}),
			_hero("raska", &"raska", ALLY, 18, Vector2(40, 10), {"name": "Raska Vennor", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
			_p("raska_company", &"basin_warriors", ALLY, 16, 16, Vector2(44, 14), {"name": "Saltwell Company", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
			_hero("isolde", &"isolde", FOE, 20, Vector2(0, 82), {"name": "Queen Isolde Varr", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("guard", &"lowmarch_knights", FOE, 16, 18, Vector2(-4, 84), {"name": "Queen's Guard", "hidden": true, "order": {"kind": "assault", "to": "causeway"}, "facing": Vector2(0, -1)}),
		],
		"objectives": [
			{"id": "hold", "text": "Hold the King's causeway", "type": "hold", "seconds": 150.0, "zone": "causeway", "overrun": 12, "fail_text": "The Lowmarch host broke through to the vault."},
			{"id": "isolde", "text": "Defeat Queen Isolde Varr", "type": "defeat", "who": ["isolde"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "mara", "The other five are at the vault. Nothing crosses this causeway until they have spoken."],
				["say", "isolde", "Halden! You promised the Marches water and gave it to the Orcs. The Lowmarch will take what you would not use."],
			]},
			{"if": {"time": 45.0}, "do": [
				["spawn", "wave_two"], ["spawn", "wave_two_b"],
				["say", "aldric", "Saltjaw's raiders march under Isolde's banner. Second wave on the causeway!"],
			]},
			{"if": {"time": 80.0}, "do": [
				["spawn", "raska"], ["spawn", "raska_company"],
				["say", "raska", "You kept your oath at the well, Halden. The Basin keeps its own."],
			]},
			{"if": {"done": "hold"}, "do": [
				["spawn", "isolde"], ["spawn", "guard"], ["objective", "isolde"],
				["say", "isolde", "Then I will take the vault myself."],
				["say", "mara", "Face me, Isolde. Whatever happens to the bridle, it will not be decided by one crown."],
			]},
			{"if": {"done": "isolde"}, "delay": 1.5, "do": [
				["say", "isolde", "You will give it away… to all of them…"],
				["say", "mara", "Not give. Share. Shields, form on the road. We climb to the chamber."],
				["victory", "The King's causeway held."],
			]},
		],
		"ending": LAST_COMMAND,
	}


# ====================================================================== RASKA


static func _raska_1() -> Dictionary:
	return {
		"id": "raska_1",
		"title": "Dry River, Full Mine",
		"year": "Year One · Spring",
		"briefing": "The Red Basin’s river has run dry. The Orc assembly elected Raska to restore it, and the trail of dead water leads to a Human mine in the Cairnspine. The bridle is already leaving under escort. Break the rearguard at the miners’ camp and find whoever spoke the command.",
		"epilogue": "Edrin Coll walked out of the Cairnspine under Orc guard, still apologizing. Raska had his witness and lost the wagon. The other miners were gone, led into the mountain by grey-skinned Druids who left no tracks. For the first time, the War Marshal began to wonder who else had known about the bridle.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(44, -60), "facing": Vector2(-1, 0)},
		"hero_level": 5,
		"platoons": [
			_p("saltwell", &"basin_warriors", ALLY, 18, 3, Vector2(40, -52), {"name": "Saltwell Company", "persist": "saltwell", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("redwater", &"basin_warriors", ALLY, 18, 3, Vector2(46, -48), {"name": "Redwater Company", "persist": "redwater", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("slingers", &"basin_slingers", ALLY, 12, 3, Vector2(48, -56), {"name": "Basin Slingers", "persist": "slingers", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("rearguard", &"marcher_infantry", FOE, 18, 3, Vector2(-6, -48), {"name": "Halden Rearguard", "aggro": 18.0, "facing": Vector2(1, 0)}),
			_p("camp_archers", &"marcher_archers", FOE, 12, 3, Vector2(-12, -58), {"name": "Camp Archers", "aggro": 20.0, "facing": Vector2(1, 0)}),
			_p("tent_guard", &"marcher_infantry", FOE, 14, 3, Vector2(-26, -50), {"name": "Tent Guard", "aggro": 14.0, "facing": Vector2(1, 0)}),
			_hero("edrin", &"edrin", ALLY, 4, Vector2(-27, -56), {"name": "Edrin Coll", "hidden": true, "commandable": false, "order": {"kind": "follow"}}),
			_hero("aldric", &"aldric", FOE, 6, Vector2(0, -24), {"name": "Ser Aldric Thorne", "hidden": true, "order": {"kind": "attack", "target": "edrin"}}),
			_p("returning", &"marcher_infantry", FOE, 18, 4, Vector2(-2, -22), {"name": "Halden Shields", "hidden": true, "order": {"kind": "attack", "target": "edrin"}}),
			_p("returning_archers", &"marcher_archers", FOE, 10, 4, Vector2(6, -24), {"name": "Ridge Archers", "hidden": true, "order": {"kind": "hunt"}}),
		],
		"interactables": [
			{"id": "foreman", "pos": Vector2(-27, -55), "label": "Search the foreman's tent", "duration": 3.0, "hidden": true},
		],
		"objectives": [
			{"id": "rearguard", "text": "Break the Human rearguard at the camp", "type": "defeat", "who": ["rearguard", "camp_archers", "tent_guard"]},
			{"id": "find", "text": "Search the foreman's tent", "type": "interact", "who": "foreman", "hidden": true},
			{"id": "extract", "text": "Bring Edrin Coll to the east ridge", "type": "reach", "who": "edrin", "zone": "east_ridge", "hidden": true},
			{"id": "edrin", "text": "Edrin Coll must survive", "type": "protect", "who": ["edrin"], "hidden": true, "fail_text": "The only witness to the command was killed."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "raska", "The wagon is gone down the pass. Let it go. A wagon cannot tell me what happened to our river."],
				["say", "durga", "Ashtusk's band is chasing it anyway, Marshal. She never listens."],
				["say", "raska", "Then we take the camp. Someone there spoke the command."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your companies. Release to return to Raska."]]},
			{"if": {"near": ["camp", 30.0], "zone": ["hero", "camp"]}, "do": [
				["say", "raska", "Where are the miners? There should be fifty people in this camp."],
			]},
			{"if": {"done": "rearguard"}, "do": [
				["reveal", "foreman"], ["objective", "find"],
				["say", "raska", "Check the foreman's tent. The one who gives orders keeps records."],
			]},
			{"if": {"done": "find"}, "do": [
				["spawn", "edrin"], ["objective", "extract"], ["objective", "edrin"],
				["say", "edrin", "Don't — please. I'm Edrin Coll. I asked it for water. Just water."],
				["say", "raska", "Then you will tell my assembly that, word for word. Walk with me."],
				["say", "edrin", "The others went with the grey ones. The Druids. Into the old tunnels."],
			]},
			{"if": {"after": ["find", 12.0]}, "do": [
				["spawn", "aldric"], ["spawn", "returning"], ["spawn", "returning_archers"],
				["say", "aldric", "The Orcs have the foreman! The King wants no witnesses in Basin hands. Take him back!"],
			]},
			{"if": {"done": "extract"}, "do": [
				["say", "raska", "Our river died for a camp's drinking water. Halden will answer for this at a well, in front of everyone."],
				["victory", "Raska has the witness."],
			]},
		],
	}


static func _raska_2() -> Dictionary:
	return {
		"id": "raska_2",
		"title": "Testimony at Kingswell",
		"year": "Year Two · Summer",
		"briefing": "King Mara has called the seven crowns to Kingswell. Raska brings Edrin Coll under a parley flag so the Humans hear, at their own sacred well, what the bridle took from the Basin. The lower towns would rather Raska came with an army. Get Edrin to the well-stone alive.",
		"epilogue": "Halden swore on the well to return the river, and three crowns walked out rather than hear it. Raska rode home with an oath instead of water. The lower towns did not want an oath. Their leader, Gorrum Saltjaw, wanted the whole inland sea, and the assembly’s own town sat on its old shoreline.",
		"map": Maps.kingswell(),
		"hero": {"pos": Vector2(36, 48), "facing": Vector2(-0.5, -1).normalized()},
		"hero_level": 11,
		"platoons": [
			_p("saltwell", &"basin_warriors", ALLY, 18, 8, Vector2(40, 52), {"name": "Saltwell Company", "persist": "saltwell", "order": {"kind": "follow"}}),
			_p("slingers", &"basin_slingers", ALLY, 12, 8, Vector2(32, 54), {"name": "Basin Slingers", "persist": "slingers", "order": {"kind": "follow"}}),
			_hero("edrin", &"edrin", ALLY, 6, Vector2(38, 50), {"name": "Edrin Coll", "commandable": false, "order": {"kind": "follow"}}),
			_hero("mara", &"mara", ALLY, 10, Vector2(0, 6), {"name": "Mara Halden", "commandable": false, "order": {"kind": "hold"}}),
			_p("halden", &"marcher_infantry", ALLY, 18, 8, Vector2(-4, 10), {"name": "Halden Shields", "commandable": false, "order": {"kind": "hold"}}),
			_p("ambush_west", &"lowmarch_knights", FOE, 18, 9, Vector2(-46, 4), {"name": "Lowmarch Knights", "hidden": true, "facing": Vector2(1, 0), "order": {"kind": "attack", "target": "edrin"}}),
			_p("ambush_north", &"lowmarch_knights", FOE, 18, 9, Vector2(22, -50), {"name": "Unmarked Riders", "hidden": true, "order": {"kind": "attack", "target": "edrin"}}),
			_p("ambush_bows", &"lowmarch_crossbows", FOE, 12, 9, Vector2(-8, -50), {"name": "Lowmarch Crossbows", "hidden": true, "order": {"kind": "move", "to": Vector2(-6, -30)}, "aggro": 20.0}),
			_hero("brannoc", &"brannoc", FOE, 12, Vector2(-48, -6), {"name": "Ser Brannoc Hale", "hidden": true, "order": {"kind": "attack", "target": "edrin"}}),
		],
		"objectives": [
			{"id": "approach", "text": "Escort Edrin to the moot", "type": "reach", "who": "edrin", "zone": "approach"},
			{"id": "edrin", "text": "Edrin Coll must survive", "type": "protect", "who": ["edrin"], "fail_text": "Edrin Coll was killed before he could testify."},
			{"id": "ambush", "text": "Break the Lowmarch ambush", "type": "defeat", "who": ["ambush_west", "ambush_north", "ambush_bows"], "hidden": true},
			{"id": "brannoc", "text": "Defeat Ser Brannoc Hale", "type": "defeat", "who": ["brannoc"], "hidden": true},
			{"id": "testify", "text": "Bring Edrin to the Kingswell", "type": "reach", "who": "edrin", "zone": "well", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "raska", "Parley flag high. We walk in slowly, and nobody draws unless they draw first."],
				["say", "edrin", "They'll hang me for this, won't they?"],
				["say", "raska", "Not while you walk beside me."],
			]},
			{"if": {"done": "approach"}, "do": [
				["say", "mara", "War Marshal. You have my word as host. Bring your witness to the well."],
				["spawn", "ambush_west"], ["spawn", "ambush_north"], ["spawn", "ambush_bows"], ["objective", "ambush"],
				["say", "raska", "Riders! Is this your word, Halden?"],
				["say", "mara", "Those are not mine. Shields, to the Marshal's side!"],
			]},
			{"if": {"any": [{"done": "ambush"}, {"after": ["approach", 120.0]}]}, "do": [
				["spawn", "brannoc"], ["objective", "brannoc"],
				["say", "brannoc", "Queen Isolde would prefer the Orcs and Halden kill each other. Since you won't, I'll take the witness."],
			]},
			{"if": {"done": "brannoc"}, "do": [
				["objective", "testify"], ["order", "edrin", {"kind": "move", "to": "well"}],
				["say", "raska", "Go on, Edrin. Say it where they keep their oaths."],
			]},
			{"if": {"done": "testify"}, "delay": 2.0, "do": [
				["say", "edrin", "I asked the bridle for water. By morning we had a spring and the Basin had no river."],
				["say", "mara", "Then by the oath of the wells, the water goes back downstream. I swear it here."],
				["say", "raska", "An oath at a well. My grandmother would have accepted that. My lower towns will not."],
				["victory", "Edrin testified at the Kingswell."],
			]},
		],
	}


static func _raska_3() -> Dictionary:
	return {
		"id": "raska_3",
		"title": "The Salt Host",
		"year": "Year Five · The Last Command",
		"briefing": "Gorrum Saltjaw broke from the assembly and marched the lower-town companies to the Vault beside Queen Isolde, promising them the inland sea. Those are still Raska’s people. Plant the assembly’s recall banners in their camps along the dry spillway, and those companies remember whose wells they drank from. Then face Gorrum.",
		"epilogue": "Gorrum died believing the sea was worth any town. The companies he led carried his body home, and they marched back under the assembly’s banner. At the Listening Chamber, Raska named the wells he had kept open through two failed rains and asked the others to name theirs. Then he asked the god to stop listening.",
		"map": Maps.vault(),
		"hero": {"pos": Vector2(40, -8), "facing": Vector2(1, 0)},
		"hero_level": 18,
		"platoons": [
			_p("saltwell", &"basin_warriors", ALLY, 18, 16, Vector2(34, -12), {"name": "Saltwell Company", "persist": "saltwell", "order": {"kind": "follow"}}),
			_p("redwater", &"basin_warriors", ALLY, 18, 16, Vector2(34, -2), {"name": "Redwater Company", "persist": "redwater", "order": {"kind": "follow"}}),
			_p("slingers", &"basin_slingers", ALLY, 12, 16, Vector2(28, -8), {"name": "Basin Slingers", "persist": "slingers", "order": {"kind": "follow"}}),
			_p("camp_n", &"saltjaw_raiders", FOE, 16, 16, Vector2(64, -2), {"name": "Brackwater Company", "aggro": 16.0, "facing": Vector2(-1, 0)}),
			_p("camp_s", &"saltjaw_raiders", FOE, 16, 16, Vector2(64, 30), {"name": "Lowshore Company", "aggro": 16.0, "facing": Vector2(-1, 0)}),
			_p("camp_f", &"basin_slingers", FOE, 12, 16, Vector2(68, 58), {"name": "Saltpan Slingers", "aggro": 18.0, "facing": Vector2(-1, 0)}),
			_p("lowmarch", &"lowmarch_knights", FOE, 18, 17, Vector2(50, 18), {"name": "Lowmarch Knights", "aggro": 16.0, "facing": Vector2(-1, 0)}),
			_hero("gorrum", &"gorrum", FOE, 20, Vector2(60, 18), {"name": "Gorrum Saltjaw", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("gorrum_guard", &"saltjaw_raiders", FOE, 16, 18, Vector2(64, 20), {"name": "Saltjaw's Own", "hidden": true, "order": {"kind": "hunt"}}),
		],
		"interactables": [
			{"id": "banner_n", "pos": Vector2(64, -6), "label": "Plant the recall banner", "duration": 3.0},
			{"id": "banner_s", "pos": Vector2(66, 34), "label": "Plant the recall banner", "duration": 3.0},
			{"id": "banner_f", "pos": Vector2(70, 62), "label": "Plant the recall banner", "duration": 3.0},
		],
		"objectives": [
			{"id": "banners", "text": "Plant recall banners in the lower-town camps", "type": "interact", "who": ["banner_n", "banner_s", "banner_f"]},
			{"id": "gorrum", "text": "Defeat Gorrum Saltjaw", "type": "defeat", "who": ["gorrum"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "raska", "Those camps are Basin towns. I will not cut through my own people to reach Gorrum."],
				["say", "durga", "Then plant the banners, Marshal. Let them choose."],
			]},
			{"if": {"interact": "banner_n"}, "do": [
				["defect", "camp_n"],
				["say", "raska", "Brackwater! Your wells are on the assembly's rolls. Come home."],
			]},
			{"if": {"interact": "banner_s"}, "do": [
				["defect", "camp_s"],
				["say", "raska", "Lowshore. Gorrum's sea would drown your own market. Stand with the assembly."],
			]},
			{"if": {"interact": "banner_f"}, "do": [
				["defect", "camp_f"],
				["say", "raska", "Saltpan, the Basin needs your slings, not his sea."],
			]},
			{"if": {"done": "banners"}, "do": [
				["spawn", "gorrum"], ["spawn", "gorrum_guard"], ["objective", "gorrum"],
				["say", "gorrum", "You give them back their wells and take away their sea! Then I take away your mandate, Vennor."],
				["say", "raska", "The assembly gave it. Only the assembly takes it."],
			]},
			{"if": {"done": "gorrum"}, "delay": 1.5, "do": [
				["say", "raska", "Carry him home. He kept wells too, once."],
				["victory", "The lower towns returned to the assembly."],
			]},
		],
		"ending": LAST_COMMAND,
	}


# ======================================================================= SOVA


static func _sova_1() -> Dictionary:
	return {
		"id": "sova_1",
		"title": "The Tunnels Beneath Greyhollow",
		"year": "Year One · Spring",
		"briefing": "The Druids hear Orrun stir and know what the miners did. Human soldiers hold the mine, and an Orc warband is coming down the dry riverbed. Get the miners out through the old listening tunnels before either army claims them, then seal the way behind you.",
		"epilogue": "Forty-one miners walked out under the Cairnspine. The foreman was not among them: Orc soldiers had already taken him. Sova sealed the tunnel with a word, and in the dark he decided that the record his predecessors had kept under seal could stay sealed no longer.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(-44, -38), "facing": Vector2(1, 0)},
		"hero_level": 5,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 16, 3, Vector2(-40, -44), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("callers", &"stonecallers", ALLY, 10, 3, Vector2(-46, -46), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("miners", &"miners", ALLY, 10, 2, Vector2(-17, -54), {"name": "Greyhollow Miners", "commandable": false, "order": {"kind": "hold"}}),
			_p("camp_guard", &"marcher_infantry", FOE, 16, 3, Vector2(-6, -44), {"name": "Halden Rearguard", "aggro": 15.0, "facing": Vector2(-1, 0)}),
			_p("orc_band", &"basin_warriors", FOE, 16, 3, Vector2(24, -50), {"name": "Redwater Company", "aggro": 16.0, "facing": Vector2(-1, 0)}),
			_p("orc_wave", &"basin_warriors", FOE, 16, 4, Vector2(0, -60), {"name": "Saltwell Company", "hidden": true, "order": {"kind": "assault", "to": "tunnel_mouth"}}),
			_p("human_wave", &"marcher_infantry", FOE, 16, 4, Vector2(-14, -28), {"name": "Halden Shields", "hidden": true, "order": {"kind": "assault", "to": "tunnel_mouth"}}),
			_p("slings_wave", &"basin_slingers", FOE, 10, 4, Vector2(-4, -58), {"name": "Basin Slingers", "hidden": true, "order": {"kind": "assault", "to": "tunnel_mouth"}}),
		],
		"interactables": [
			{"id": "seal", "pos": Vector2(-44, -34), "label": "Speak the sealing word", "duration": 4.0, "hidden": true},
		],
		"objectives": [
			{"id": "camp", "text": "Reach the miners' camp", "type": "reach", "who": "hero", "zone": "camp"},
			{"id": "tunnel", "text": "Lead the miners to the tunnel mouth", "type": "reach", "who": "miners", "zone": "tunnel_mouth", "hidden": true},
			{"id": "miners", "text": "The miners must survive", "type": "protect", "who": ["miners"], "fail_text": "The miners were cut down before they reached the tunnels."},
			{"id": "hold", "text": "Hold the tunnel mouth while they pass", "type": "hold", "seconds": 60.0, "zone": "tunnel_mouth", "overrun": 10, "hidden": true},
			{"id": "seal", "text": "Seal the tunnel at the standing stone", "type": "interact", "who": "seal", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "sova", "Orrun is restless. It heard them ask for water, and it answered. We get the miners out before the armies decide what they are worth."],
				["say", "bryn", "Halden's rearguard holds the camp. The Orcs are coming down from the plateau."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Sova."]]},
			{"if": {"done": "camp"}, "do": [
				["objective", "tunnel"],
				["order", "miners", {"kind": "path", "points": [Vector2(-26, -48), Vector2(-36, -44), Vector2(-46, -40)], "wait_for_hero": 14.0}],
				["say", "sova", "We are Listeners from the Cairnspine. Follow me, and stay close. The tunnels know the way out."],
				["say", "miner", "The Orcs took Edrin. Our foreman. We couldn't stop them."],
			]},
			{"if": {"done": "tunnel"}, "do": [
				["objective", "hold"], ["spawn", "orc_wave"], ["spawn", "human_wave"], ["spawn", "slings_wave"],
				["order", "miners", {"kind": "move", "to": Vector2(-52, -40)}],
				["say", "bryn", "Both armies are coming for the tunnel. They've noticed the camp is empty."],
				["say", "sova", "Then we hold the mouth. Every miner through before the stone is sealed."],
			]},
			{"if": {"done": "hold"}, "do": [
				["reveal", "seal"], ["objective", "seal"],
				["say", "sova", "They are through. Now the stone."],
			]},
			{"if": {"done": "seal"}, "do": [
				["despawn", "miners"],
				["say", "sova", "The way is closed. They will find nothing but rock."],
				["victory", "The miners escaped through the listening tunnels."],
			]},
		],
	}


static func _sova_2() -> Dictionary:
	return {
		"id": "sova_2",
		"title": "The Reading at Hollow Stones",
		"year": "Year Two · Midsummer",
		"briefing": "Sova has called the Keepers to Hollow Stones to read the sealed record of the first command aloud. Keeper Orla Thane would rather burn it than let the other peoples learn who drowned the Elven coast. Protect the three listening stones until the reading is finished.",
		"epilogue": "The record was read in full. Long ago, Sova’s ancestors told Orrun to make the mountains hold. The Cairnspine rose, the Elven coast sank, and the Red Basin lost its sea. At the end of the reading, a stranger stepped into the circle: Tide Speaker Ilyra Venn, who had come with a chart from the risen ruins of Seliath. “You drowned my city,” she said, “and kept the receipt.” Sova gave her a copy.",
		"map": Maps.hollow_stones(),
		"hero": {"pos": Vector2(0, 6), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"structures": [
			{"id": "stone_west", "kind": &"stone", "team": ALLY, "pos": Vector2(-9, 6), "name": "Western listening stone"},
			{"id": "stone_east", "kind": &"stone", "team": ALLY, "pos": Vector2(9, 6), "name": "Eastern listening stone"},
			{"id": "stone_north", "kind": &"stone", "team": ALLY, "pos": Vector2(0, -10), "name": "Northern listening stone"},
		],
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 16, 8, Vector2(-6, -2), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "hold"}}),
			_p("callers", &"stonecallers", ALLY, 10, 8, Vector2(4, 2), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "hold"}}),
			_p("valley_guard", &"cairn_wardens", ALLY, 14, 7, Vector2(6, -4), {"name": "Valley Guard", "persist": "valley", "order": {"kind": "follow"}}),
			_p("north_band", &"dissenting_wardens", FOE, 16, 8, Vector2(0, -44), {"name": "Thane's Wardens", "order": {"kind": "assault", "to": Vector2(0, -10)}}),
			_p("west_band", &"dissenting_wardens", FOE, 16, 8, Vector2(-44, 0), {"name": "Moorland Wardens", "hidden": true, "facing": Vector2(1, 0), "order": {"kind": "assault", "to": Vector2(-9, 6)}}),
			_p("east_callers", &"stonecallers", FOE, 10, 8, Vector2(44, -4), {"name": "Dissenting Callers", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "assault", "to": Vector2(9, 6)}}),
			_p("east_band", &"dissenting_wardens", FOE, 16, 9, Vector2(46, 2), {"name": "Eastvale Wardens", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "assault", "to": Vector2(9, 6)}}),
			_hero("orla", &"orla", FOE, 12, Vector2(0, -44), {"name": "Keeper Orla Thane", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("orla_guard", &"dissenting_wardens", FOE, 16, 10, Vector2(4, -46), {"name": "Thane's Hearthguard", "hidden": true, "order": {"kind": "assault", "to": Vector2(0, -10)}}),
			_hero("ilyra", &"ilyra", ALLY, 10, Vector2(0, 46), {"name": "Ilyra Venn", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
			_p("ilyra_archers", &"tide_archers", ALLY, 10, 9, Vector2(4, 46), {"name": "Tide Archers", "hidden": true, "commandable": false, "order": {"kind": "move", "to": Vector2(0, 22)}}),
		],
		"objectives": [
			{"id": "stones", "text": "Protect the three listening stones", "type": "protect", "who": ["stone_west", "stone_east", "stone_north"], "fail_text": "A listening stone fell. The reading was broken."},
			{"id": "reading", "text": "Complete the reading", "type": "hold", "seconds": 200.0},
			{"id": "orla", "text": "Defeat Keeper Orla Thane", "type": "defeat", "who": ["orla"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "sova", "Keepers, witnesses. This record was sealed by Listeners before me. Today it is read aloud, all of it."],
				["say", "orla", "Some debts should stay buried, First Listener. If you will not stop, my wardens will stop you."],
			]},
			{"if": {"time": 30.0}, "do": [
				["spawn", "west_band"],
				["say", "bryn", "Wardens on the west moor. Orla brought more valleys than we thought."],
			]},
			{"if": {"time": 60.0}, "do": [
				["say", "voice", "“…and the Listener said to the sleeper: make the mountains hold…”"],
			]},
			{"if": {"time": 75.0}, "do": [
				["spawn", "east_band"], ["spawn", "east_callers"],
				["say", "sova", "Eastvale too. Hold the stones. The record is half read."],
			]},
			{"if": {"time": 110.0}, "do": [
				["spawn", "orla"], ["spawn", "orla_guard"], ["objective", "orla"],
				["say", "voice", "“…the coast went under the sea, and the inland water fled the Basin…”"],
				["say", "orla", "Enough! The other peoples will hang us with our own words!"],
			]},
			{"if": {"time": 150.0}, "do": [
				["spawn", "ilyra"], ["spawn", "ilyra_archers"],
				["say", "ilyra", "Keep reading, Druid. I crossed half of Vareth to hear the end of that sentence."],
			]},
			{"if": {"dead": "orla"}, "do": [
				["say", "orla", "I yield. I only wanted to keep the valleys whole."],
				["say", "sova", "So do I. That is why they must know what we owe."],
			]},
			{"if": {"done": ["reading", "orla"]}, "delay": 1.5, "do": [
				["say", "ilyra", "You drowned my city and kept the receipt. I want a copy."],
				["say", "sova", "You shall have one. And a place beside me, when the time comes to answer for it."],
				["victory", "The sealed record was read aloud."],
			]},
		],
	}


static func _sova_3() -> Dictionary:
	return {
		"id": "sova_3",
		"title": "The Listening Chamber",
		"year": "Year Five · The Last Command",
		"briefing": "The six leaders have reached the Vault where Sova’s ancestors spoke the first command. While the armies hold the approaches, Sova must wake the four ward stones of the Listening Chamber so that the command can be spoken together. Isolde’s knights and the restless dead are already inside the outer court.",
		"epilogue": "Sova woke the last ward stone and stepped aside. He did not speak first. When the others had named what they would lose, he named what the Druids had already taken, and only then did he add his voice. Keeper Orla Thane stood witness, as the oath ceremonies require, and named who would bear the cost: everyone.",
		"map": Maps.vault(),
		"hero": {"pos": Vector2(0, -46), "facing": Vector2(0, -1)},
		"hero_level": 18,
		"structures": [
			{"id": "gate", "kind": &"gate", "team": ALLY, "pos": Vector2(0, -67), "name": "Vault door"},
		],
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 18, 16, Vector2(-8, -50), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}}),
			_p("callers", &"stonecallers", ALLY, 12, 16, Vector2(8, -50), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "follow"}}),
			_p("valley_guard", &"cairn_wardens", ALLY, 16, 15, Vector2(0, -60), {"name": "Valley Guard", "persist": "valley", "order": {"kind": "hold"}}),
			_hero("orla", &"orla", ALLY, 16, Vector2(-4, -60), {"name": "Keeper Orla Thane", "commandable": false, "order": {"kind": "guard", "who": "gate"}}),
			_p("knights_east", &"lowmarch_knights", FOE, 18, 17, Vector2(24, -36), {"name": "Lowmarch Knights", "order": {"kind": "assault", "to": "vault_gate"}}),
			_p("restless_west", &"restless_dead", FOE, 16, 15, Vector2(-24, -36), {"name": "Restless Dead", "order": {"kind": "assault", "to": "vault_gate"}}),
			_p("wave_bows", &"lowmarch_crossbows", FOE, 12, 17, Vector2(0, -24), {"name": "Lowmarch Crossbows", "hidden": true, "order": {"kind": "assault", "to": "chamber"}}),
			_p("wave_restless", &"restless_dead", FOE, 16, 16, Vector2(-22, -30), {"name": "Restless Dead", "hidden": true, "order": {"kind": "assault", "to": "vault_gate"}}),
			_p("wave_knights", &"lowmarch_knights", FOE, 16, 16, Vector2(22, -30), {"name": "Lowmarch Knights", "hidden": true, "order": {"kind": "assault", "to": "vault_gate"}}),
			_p("last_restless", &"restless_dead", FOE, 18, 16, Vector2(0, -26), {"name": "Restless Dead", "hidden": true, "order": {"kind": "assault", "to": "vault_gate"}}),
		],
		"interactables": [
			{"id": "ward_nw", "pos": Vector2(-14, -58), "label": "Wake the ward stone", "duration": 3.5},
			{"id": "ward_ne", "pos": Vector2(14, -58), "label": "Wake the ward stone", "duration": 3.5},
			{"id": "ward_sw", "pos": Vector2(-14, -44), "label": "Wake the ward stone", "duration": 3.5},
			{"id": "ward_se", "pos": Vector2(14, -44), "label": "Wake the ward stone", "duration": 3.5},
		],
		"objectives": [
			{"id": "wards", "text": "Wake the four ward stones", "type": "interact", "who": ["ward_nw", "ward_ne", "ward_sw", "ward_se"]},
			{"id": "gate", "text": "The vault door must hold", "type": "protect", "who": ["gate"], "fail_text": "The vault door was breached."},
			{"id": "hold", "text": "Hold the chamber while the six prepare", "type": "hold", "seconds": 60.0, "zone": "chamber", "overrun": 14, "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "sova", "Four stones, four words. When they wake, the chamber will carry six voices to Orrun at once."],
				["say", "orla", "I will stand at the door, First Listener. Someone has to witness this."],
			]},
			{"if": {"interact": "ward_nw"}, "do": [["say", "voice", "“…make the mountains hold…”"]]},
			{"if": {"interact": "ward_ne"}, "do": [["spawn", "wave_bows"], ["say", "bryn", "Crossbows in the court!"]]},
			{"if": {"interact": "ward_sw"}, "do": [["spawn", "wave_restless"], ["say", "sova", "The dead hear the stones waking. They want to be remembered too."]]},
			{"if": {"done": "wards"}, "do": [
				["objective", "hold"], ["spawn", "wave_knights"], ["spawn", "last_restless"],
				["say", "sova", "The chamber is awake. Hold until the six are inside."],
				["say", "mara", "Halden holds the causeway. Raska's companies are coming up the spillway."],
			]},
			{"if": {"done": "hold"}, "delay": 1.0, "do": [
				["say", "ilyra", "We are all here, Sova. Say the first word."],
				["say", "sova", "No. The first word was ours five hundred years ago. This time we speak last."],
				["victory", "The Listening Chamber woke."],
			]},
		],
		"ending": LAST_COMMAND,
	}


# ====================================================================== ILYRA


static func _ilyra_1() -> Dictionary:
	return {
		"id": "ilyra_1",
		"title": "Low Tide at Seliath",
		"year": "Year Two · Spring",
		"briefing": "Overnight the sea drew back from Old Seliath, the harbor district that sank before Ilyra was grown. Two league ships are stranded on the risen streets. Lowmarch privateers have come to loot the ruins, and the pilots of Brineholt, whose village just lost its harbor, are watching to see whom the Tide Speaker protects.",
		"epilogue": "The chart Ilyra pulled from the drowned archive was older than the city. It marked a vault high in the Cairnspine and a single line in old Elvish: “Here the coast was spoken under.” Maren Tull, the pilot from Brineholt, read it over her shoulder. “Raise Seliath,” she said, “and you sink us.” Ilyra did not answer. She went to find the Druids.",
		"map": Maps.seliath(),
		"hero": {"pos": Vector2(-24, 0), "facing": Vector2(1, 0)},
		"hero_level": 5,
		"structures": [
			{"id": "ship_north", "kind": &"ship", "team": ALLY, "pos": Vector2(-33, -22), "name": "The Gull's Reckoning"},
			{"id": "ship_south", "kind": &"ship", "team": ALLY, "pos": Vector2(-33, 20), "name": "The Moonwash"},
		],
		"platoons": [
			_p("wavecutters", &"wavecutters", ALLY, 18, 3, Vector2(-24, -6), {"name": "Seliath Wavecutters", "persist": "wavecutters", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("archers", &"tide_archers", ALLY, 12, 3, Vector2(-26, 6), {"name": "Tide Archers", "persist": "tide_archers", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("looters_n", &"lowmarch_knights", FOE, 14, 3, Vector2(10, -28), {"name": "Rook's Boarders", "aggro": 16.0}),
			_p("looters_s", &"marcher_infantry", FOE, 16, 3, Vector2(4, 28), {"name": "Privateer Crew", "order": {"kind": "assault", "to": "ship_south"}}),
			_p("bows", &"lowmarch_crossbows", FOE, 10, 3, Vector2(18, 4), {"name": "Privateer Crossbows", "aggro": 18.0}),
			_p("wave_n", &"marcher_infantry", FOE, 16, 4, Vector2(28, -46), {"name": "Privateer Crew", "hidden": true, "order": {"kind": "assault", "to": "ship_north"}}),
			_p("wave_s", &"marcher_infantry", FOE, 16, 4, Vector2(-8, 50), {"name": "Privateer Crew", "hidden": true, "order": {"kind": "assault", "to": "ship_south"}}),
			_hero("rook", &"rook", FOE, 6, Vector2(24, -46), {"name": "Captain Wystan Rook", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("rook_crew", &"lowmarch_knights", FOE, 14, 5, Vector2(28, -44), {"name": "Rook's Boarders", "hidden": true, "order": {"kind": "hunt"}}),
			_p("pilots", &"pilots", ALLY, 10, 3, Vector2(44, 2), {"name": "Brineholt Pilots", "hidden": true, "commandable": false, "order": {"kind": "move", "to": Vector2(-20, 0)}}),
		],
		"interactables": [
			{"id": "chart", "pos": Vector2(6, -38), "label": "Search the drowned archive", "duration": 4.0},
		],
		"objectives": [
			{"id": "ships", "text": "Protect the stranded ships", "type": "protect", "who": ["ship_north", "ship_south"], "fail_text": "A league ship was burned on the seabed."},
			{"id": "looters", "text": "Drive the privateers from the ruins", "type": "defeat", "who": ["looters_n", "looters_s", "bows", "wave_n", "wave_s"]},
			{"id": "chart", "text": "Recover the chart from the drowned archive", "type": "interact", "who": "chart"},
			{"id": "rook", "text": "Defeat Captain Wystan Rook", "type": "defeat", "who": ["rook"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "ilyra", "I walked these streets when I was a child. Now there are Lowmarch boots on them."],
				["say", "maren", "Tide Speaker! Privateers are going for the Moonwash. Brineholt can't lose another ship."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Ilyra."]]},
			{"if": {"time": 40.0}, "do": [
				["spawn", "wave_s"],
				["say", "maren", "More crew coming up the south beach!"],
			]},
			{"if": {"time": 75.0}, "do": [["spawn", "wave_n"], ["say", "ilyra", "They came for the archive. Whatever is in there is worth a war to someone."]]},
			{"if": {"done": "chart"}, "do": [
				["spawn", "rook"], ["spawn", "rook_crew"], ["objective", "rook"],
				["say", "rook", "That chart belongs to Queen Isolde, Elf. She paid for it before your sea gave it back."],
				["say", "ilyra", "Then she paid a thief. Wavecutters, with me."],
			]},
			{"if": {"done": ["looters", "chart", "rook"]}, "do": [
				["spawn", "pilots"],
				["say", "maren", "Brineholt saw what you did. We'll pilot for you, Tide Speaker. For now."],
				["victory", "Old Seliath was cleared of privateers."],
			]},
		],
	}


static func _ilyra_2() -> Dictionary:
	return {
		"id": "ilyra_2",
		"title": "The Drowned Road",
		"year": "Year Three · Autumn",
		"briefing": "Corvin Ashe betrayed King Mara and carried the Godbridle to Queen Isolde. Her column now drives it along the coast road toward the Lowmarch shore, where she means to call the sea back to her lands. The sea will come through Brineholt first. Get the pilots to their boats, and stop the column.",
		"epilogue": "Sereth Vale took the bridle from Corvin’s wagon before Ilyra could reach it. For a long moment, Elves and Undead stood on the coast road with their weapons drawn. Then Ilyra spoke: “Swear you will bring it to all six peoples. Not to your court. Not to me.” The High Executor swore by the empty chair at his sister’s table. Brineholt kept its harbor.",
		"map": Maps.drowned_road(),
		"hero": {"pos": Vector2(-44, -2), "facing": Vector2(1, 0)},
		"hero_level": 11,
		"platoons": [
			_p("wavecutters", &"wavecutters", ALLY, 18, 8, Vector2(-40, 4), {"name": "Seliath Wavecutters", "persist": "wavecutters", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("archers", &"tide_archers", ALLY, 12, 8, Vector2(-46, 8), {"name": "Tide Archers", "persist": "tide_archers", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("harbor_guard", &"wavecutters", ALLY, 16, 7, Vector2(-50, -12), {"name": "Harbor Guard", "persist": "harbor_guard", "order": {"kind": "hold"}, "facing": Vector2(1, 0)}),
			_p("pilots", &"pilots", ALLY, 10, 5, Vector2(-52, 2), {"name": "Brineholt Pilots", "commandable": false, "order": {"kind": "hold"}}),
			_p("vanguard", &"lowmarch_knights", FOE, 18, 9, Vector2(-6, 0), {"name": "Lowmarch Vanguard", "order": {"kind": "assault", "to": "brineholt"}, "facing": Vector2(-1, 0)}),
			_p("vanguard_bows", &"lowmarch_crossbows", FOE, 12, 9, Vector2(4, -4), {"name": "Lowmarch Crossbows", "order": {"kind": "move", "to": Vector2(-18, -2)}, "aggro": 18.0, "facing": Vector2(-1, 0)}),
			_p("column", &"lowmarch_knights", FOE, 18, 10, Vector2(28, 2), {"name": "Column Guard", "aggro": 16.0, "facing": Vector2(-1, 0)}),
			_p("column_bows", &"lowmarch_crossbows", FOE, 12, 10, Vector2(42, -8), {"name": "Column Crossbows", "aggro": 18.0, "facing": Vector2(-1, 0)}),
			_hero("corvin", &"corvin", FOE, 12, Vector2(38, -2), {"name": "Corvin Ashe", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_hero("sereth", &"sereth", ALLY, 11, Vector2(0, 44), {"name": "Sereth Vale", "hidden": true, "commandable": false, "order": {"kind": "assault", "to": "wagon"}}),
			_p("ossuary", &"ossuary_guard", ALLY, 16, 9, Vector2(4, 46), {"name": "Ossuary Guard", "hidden": true, "commandable": false, "order": {"kind": "assault", "to": "wagon"}}),
		],
		"objectives": [
			{"id": "docks", "text": "Lead the Brineholt pilots to the docks", "type": "reach", "who": "pilots", "zone": "docks"},
			{"id": "pilots", "text": "The pilots must survive", "type": "protect", "who": ["pilots"], "fail_text": "The Brineholt pilots were cut down in their own village."},
			{"id": "vanguard", "text": "Break the Lowmarch vanguard", "type": "defeat", "who": ["vanguard", "vanguard_bows"]},
			{"id": "corvin", "text": "Defeat Corvin Ashe at the bridle wagon", "type": "defeat", "who": ["corvin"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "maren", "Isolde's column is on the coast road. If she calls the sea, it comes through here first."],
				["say", "ilyra", "Then Brineholt goes to its boats. Pilots, follow me to the docks."],
				["order", "pilots", {"kind": "path", "points": [Vector2(-52, -10), Vector2(-56, -20), Vector2(-56, -27)], "wait_for_hero": 14.0}],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Ilyra."]]},
			{"if": {"done": "docks"}, "do": [
				["say", "maren", "The boats are full. Go, Tide Speaker. Stop that wagon."],
				["order", "pilots", {"kind": "hold"}],
			]},
			{"if": {"done": ["docks", "vanguard"]}, "do": [
				["spawn", "corvin"], ["objective", "corvin"],
				["say", "corvin", "Mara would have wasted it on an oath. Isolde will use it. Turn back, Elf."],
			]},
			{"if": {"after": ["vanguard", 10.0]}, "do": [
				["spawn", "sereth"], ["spawn", "ossuary"],
				["say", "sereth", "The Still Kingdom has a claim on that wagon, Tide Speaker. Our dead woke when Isolde last used it."],
				["say", "ilyra", "Then help me take it, and we will argue about whose it is afterward."],
			]},
			{"if": {"done": "corvin"}, "delay": 1.5, "do": [
				["say", "sereth", "The bridle is in my hands. My court will want it brought home."],
				["say", "ilyra", "Swear you will bring it before all six peoples. Not your court. Not me."],
				["say", "sereth", "I swear it by the empty chair at my sister's table."],
				["victory", "The Lowmarch column was broken on the Drowned Road."],
			]},
		],
	}


static func _ilyra_3() -> Dictionary:
	return {
		"id": "ilyra_3",
		"title": "The Tide Stair",
		"year": "Year Five · The Last Command",
		"briefing": "Captain Rook leads Isolde’s marines up the Tide Stair on the Vault’s western cliffs. If they take the stair, they flank the Listening Chamber. Brineholt’s pilots have answered Ilyra’s call. Keep their signal fire burning so the ships offshore know where to land their crews, and hold the stair.",
		"epilogue": "Rook went over the cliff with the signal fire still burning behind him. In the Listening Chamber, Ilyra named every street of Old Seliath she remembered, so they would be recorded somewhere. Then she named Brineholt, and its harbor, and Maren Tull. She did not ask the god for her coast back.",
		"map": Maps.vault(),
		"hero": {"pos": Vector2(-56, 8), "facing": Vector2(0, 1)},
		"hero_level": 18,
		"structures": [
			{"id": "signal", "kind": &"signal_fire", "team": ALLY, "pos": Vector2(-58, 0), "name": "Signal fire"},
		],
		"platoons": [
			_p("wavecutters", &"wavecutters", ALLY, 18, 16, Vector2(-60, 12), {"name": "Seliath Wavecutters", "persist": "wavecutters", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("archers", &"tide_archers", ALLY, 12, 16, Vector2(-54, 4), {"name": "Tide Archers", "persist": "tide_archers", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("harbor_guard", &"wavecutters", ALLY, 16, 15, Vector2(-66, 8), {"name": "Harbor Guard", "persist": "harbor_guard", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("marines_a", &"lowmarch_knights", FOE, 18, 16, Vector2(-62, 64), {"name": "Lowmarch Marines", "order": {"kind": "assault", "to": "stair"}}),
			_p("marines_bows", &"lowmarch_crossbows", FOE, 12, 16, Vector2(-56, 66), {"name": "Marine Crossbows", "order": {"kind": "assault", "to": "stair"}}),
			_p("marines_b", &"marcher_infantry", FOE, 20, 17, Vector2(-66, 70), {"name": "Lowmarch Levies", "hidden": true, "order": {"kind": "assault", "to": Vector2(-58, 0)}}),
			_p("marines_c", &"lowmarch_knights", FOE, 18, 17, Vector2(-40, 64), {"name": "Lowmarch Marines", "hidden": true, "order": {"kind": "assault", "to": "stair"}}),
			_hero("rook", &"rook", FOE, 19, Vector2(-62, 72), {"name": "Captain Wystan Rook", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("rook_guard", &"lowmarch_knights", FOE, 16, 18, Vector2(-58, 74), {"name": "Rook's Boarders", "hidden": true, "order": {"kind": "hunt"}}),
			_p("pilots", &"wavecutters", ALLY, 16, 14, Vector2(-74, 18), {"name": "Brineholt Crews", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
		],
		"objectives": [
			{"id": "signal", "text": "Keep the signal fire burning", "type": "protect", "who": ["signal"], "fail_text": "The signal fire went out. The ships could not land."},
			{"id": "hold", "text": "Hold the Tide Stair", "type": "hold", "seconds": 140.0, "zone": "stair", "overrun": 12, "fail_text": "The marines took the stair and flanked the chamber."},
			{"id": "rook", "text": "Defeat Captain Wystan Rook", "type": "defeat", "who": ["rook"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "ilyra", "The chamber is above us. Nothing climbs this stair while the six are speaking."],
				["say", "maren", "We see your fire, Tide Speaker! Keep it lit and we'll find the beach."],
			]},
			{"if": {"time": 40.0}, "do": [["spawn", "marines_b"], ["say", "ilyra", "Levies on the lower steps. They are going for the fire."]]},
			{"if": {"time": 70.0}, "do": [["spawn", "pilots"], ["say", "maren", "Brineholt is ashore! Where do you want us?"], ["say", "ilyra", "Anywhere there is a Lowmarch shield."]]},
			{"if": {"time": 95.0}, "do": [["spawn", "marines_c"]]},
			{"if": {"done": "hold"}, "do": [
				["spawn", "rook"], ["spawn", "rook_guard"], ["objective", "rook"],
				["say", "rook", "Seliath stole my prize. I'll take the stair for Isolde and then the chart back."],
			]},
			{"if": {"done": "rook"}, "delay": 1.5, "do": [
				["say", "ilyra", "The stair is ours. Maren, keep the fire lit. I have somewhere to be."],
				["victory", "The Tide Stair held."],
			]},
		],
		"ending": LAST_COMMAND,
	}


# ===================================================================== SERETH


static func _sereth_1() -> Dictionary:
	return {
		"id": "sereth_1",
		"title": "The Voices of Marrowfen",
		"year": "Year Three · Spring",
		"briefing": "Somewhere in Vareth, someone gave Orrun a new command, and the low fens of Marrowfen flooded overnight. Now the village hears its unburied dead calling from the water. Those dead never received the rites, and they are angry. Protect the villagers, and perform the rites at the three grave cairns.",
		"epilogue": "The restless were older than the Still Kingdom. They had drowned when the coast went under, five centuries ago, and the water had carried their bones inland. In the third cairn, Sereth found a scrap of paper in a hand he had not seen in two hundred years: “If they ever call me back, ask Sereth first. He will know.” It ended there. The court’s orders arrived the next morning: secure the Godbridle, whoever holds it.",
		"map": Maps.marrowfen(),
		"hero": {"pos": Vector2(0, 14), "facing": Vector2(0, -1)},
		"hero_level": 5,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 3, Vector2(-6, 8), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 3, Vector2(6, 8), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_p("villagers", &"villagers", ALLY, 10, 4, Vector2(0, 26), {"name": "Marrowfen Villagers", "commandable": false, "order": {"kind": "hold"}}),
			_p("restless_w", &"restless_dead", FOE, 18, 3, Vector2(-30, -20), {"name": "Restless Dead", "aggro": 14.0}),
			_p("restless_e", &"restless_dead", FOE, 18, 3, Vector2(28, -24), {"name": "Restless Dead", "aggro": 14.0}),
			_p("restless_n", &"restless_dead", FOE, 18, 4, Vector2(0, -40), {"name": "Restless Dead", "aggro": 14.0}),
			_p("drift_w", &"restless_dead", FOE, 16, 3, Vector2(-48, -10), {"name": "Drifting Dead", "hidden": true, "facing": Vector2(1, 0), "order": {"kind": "assault", "to": "village"}}),
			_p("drift_e", &"restless_dead", FOE, 16, 3, Vector2(48, -6), {"name": "Drifting Dead", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "assault", "to": "village"}}),
			_hero("choir", &"drowned_choir", FOE, 6, Vector2(0, -48), {"name": "The Drowned Choir", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("choir_dead", &"restless_dead", FOE, 18, 5, Vector2(4, -50), {"name": "Choir of the Drowned", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
		],
		"interactables": [
			{"id": "cairn_w", "pos": Vector2(-30, -25), "label": "Perform the rites", "duration": 4.0},
			{"id": "cairn_e", "pos": Vector2(28, -30), "label": "Perform the rites", "duration": 4.0},
			{"id": "cairn_n", "pos": Vector2(0, -46), "label": "Perform the rites", "duration": 4.0},
		],
		"objectives": [
			{"id": "villagers", "text": "The villagers must survive", "type": "protect", "who": ["villagers"], "fail_text": "The restless dead overran Marrowfen."},
			{"id": "rites", "text": "Perform the rites at the three grave cairns", "type": "interact", "who": ["cairn_w", "cairn_e", "cairn_n"]},
			{"id": "choir", "text": "Lay the Drowned Choir to rest", "type": "defeat", "who": ["choir"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "The villagers say the voices started the night the fen flooded. They are calling for family, High Executor."],
				["say", "sereth", "Then they never had the rites. We will give them what they were owed. Guard the village."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Sereth."]]},
			{"if": {"time": 35.0}, "do": [["spawn", "drift_w"], ["say", "aurel", "More of them drifting in from the west fen!"]]},
			{"if": {"time": 80.0}, "do": [["spawn", "drift_e"], ["say", "aurel", "And the east! They're drawn to the living."]]},
			{"if": {"interact": "cairn_w"}, "do": [
				["kill", "restless_w"],
				["say", "sereth", "Rest. Your names will be written, even if we must guess them."],
			]},
			{"if": {"interact": "cairn_e"}, "do": [
				["kill", "restless_e"],
				["say", "voice", "“…the water came over the walls… the Listener said the mountains must hold…”"],
			]},
			{"if": {"interact": "cairn_n"}, "do": [
				["kill", "restless_n"],
				["say", "sereth", "There is a letter in this cairn. That handwriting… Liesl?"],
			]},
			{"if": {"done": "rites"}, "do": [
				["spawn", "choir"], ["spawn", "choir_dead"], ["objective", "choir"],
				["say", "choir", "WE WERE NOT ASKED. WE WERE NEVER ASKED."],
				["say", "sereth", "I know. That is the whole of my life's work. Let me finish it."],
			]},
			{"if": {"done": "choir"}, "delay": 1.5, "do": [
				["say", "sereth", "“If they ever call me back, ask Sereth first.” She wrote that before the rites existed."],
				["say", "aurel", "A rider from the court, High Executor. They want the Godbridle secured. Whoever holds it."],
				["victory", "The dead of Marrowfen were laid to rest."],
			]},
		],
	}


static func _sereth_2() -> Dictionary:
	return {
		"id": "sereth_2",
		"title": "The Drowned Road",
		"year": "Year Three · Autumn",
		"briefing": "The Godbridle is in a Lowmarch wagon on the coast road, guarded by the traitor Corvin Ashe. The court has ordered Sereth to seize it. Elven ships have been seen off Brineholt, and the Tide Speaker will not let that wagon pass her village either. Break the column and take the bridle before anyone else can.",
		"epilogue": "Sereth lifted the Godbridle from Corvin’s wagon and felt the god turn in its sleep, listening. The court wanted it brought home. The Tide Speaker wanted it nowhere at all. Sereth thought of a letter that ended in the middle of a sentence and gave Ilyra his oath: the bridle would go before all six peoples, and no one would speak to Orrun alone.",
		"map": Maps.drowned_road(),
		"hero": {"pos": Vector2(0, 38), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 8, Vector2(-6, 42), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 8, Vector2(6, 42), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_p("pallbearers", &"ossuary_guard", ALLY, 16, 7, Vector2(0, 46), {"name": "Pallbearers", "persist": "pallbearers", "order": {"kind": "follow"}}),
			_p("road_guard", &"lowmarch_knights", FOE, 18, 9, Vector2(4, 4), {"name": "Road Guard", "aggro": 18.0}),
			_p("road_bows", &"lowmarch_crossbows", FOE, 12, 9, Vector2(14, -6), {"name": "Lowmarch Crossbows", "aggro": 20.0}),
			_p("column", &"lowmarch_knights", FOE, 18, 10, Vector2(30, 0), {"name": "Column Guard", "aggro": 16.0, "facing": Vector2(-1, 0)}),
			_p("column_bows", &"lowmarch_crossbows", FOE, 12, 10, Vector2(44, -8), {"name": "Column Crossbows", "aggro": 18.0, "facing": Vector2(-1, 0)}),
			_p("rear", &"lowmarch_knights", FOE, 18, 10, Vector2(62, 2), {"name": "Column Rearguard", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "hunt"}}),
			_hero("corvin", &"corvin", FOE, 12, Vector2(38, -3), {"name": "Corvin Ashe", "order": {"kind": "hold"}, "aggro": 12.0}),
			_hero("ilyra", &"ilyra", ALLY, 11, Vector2(-50, -4), {"name": "Ilyra Venn", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
			_p("wavecutters", &"wavecutters", ALLY, 16, 9, Vector2(-46, 2), {"name": "Seliath Wavecutters", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
		],
		"interactables": [
			{"id": "bridle", "pos": Vector2(36, -1), "label": "Take the Godbridle", "duration": 3.0, "hidden": true},
		],
		"objectives": [
			{"id": "guard", "text": "Break the road guard", "type": "defeat", "who": ["road_guard", "road_bows"]},
			{"id": "corvin", "text": "Defeat Corvin Ashe", "type": "defeat", "who": ["corvin"]},
			{"id": "bridle", "text": "Take the Godbridle from the wagon", "type": "interact", "who": "bridle", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "sereth", "The court wants it home. I want it out of Isolde's hands. Today those are the same thing."],
				["say", "aurel", "Elven ships off Brineholt, High Executor. The Tide Speaker is here."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Sereth."]]},
			{"if": {"done": "guard"}, "do": [
				["spawn", "ilyra"], ["spawn", "wavecutters"], ["spawn", "rear"],
				["say", "ilyra", "Undead on the coast road. If you are here for the wagon, Executor, you will have to share the fight."],
				["say", "sereth", "Gladly. Arguments can wait for the living."],
				["say", "corvin", "Rearguard, forward! Nobody touches the wagon."],
			]},
			{"if": {"done": "corvin"}, "do": [
				["reveal", "bridle"], ["objective", "bridle"],
				["say", "corvin", "Isolde… will only send more…"],
			]},
			{"if": {"done": "bridle"}, "delay": 1.0, "do": [
				["say", "sereth", "It is listening. I can feel the god turn toward my hand."],
				["say", "ilyra", "Swear you will bring it before all six peoples. Not to your court. Not to me."],
				["say", "sereth", "By the empty chair at my sister's table, I swear it."],
				["victory", "The Godbridle was taken from the Lowmarch column."],
			]},
		],
	}


static func _sereth_3() -> Dictionary:
	return {
		"id": "sereth_3",
		"title": "The Empty Chair",
		"year": "Year Five · The Last Command",
		"briefing": "Sereth has kept his oath for two years. Now he carries the Godbridle up the eastern road to the Vault, while Isolde’s attack wakes the drowned dead along the way. They are drawn to the bridle in his hands. Reach the vault door, and lay down whatever stands in the road.",
		"epilogue": "At the vault door the stones spoke in a voice Sereth had not heard in two hundred years. “Leave my chair empty,” his sister said. “But keep setting the table.” In the Listening Chamber, he placed the Godbridle in the center of the six and stepped back. He asked Orrun for nothing. He only added his voice to theirs.",
		"map": Maps.vault(),
		"hero": {"pos": Vector2(70, -62), "facing": Vector2(-1, 0)},
		"hero_level": 18,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 16, Vector2(72, -56), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 16, Vector2(74, -66), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_p("pallbearers", &"ossuary_guard", ALLY, 16, 15, Vector2(76, -60), {"name": "Pallbearers", "persist": "pallbearers", "order": {"kind": "follow"}}),
			_p("restless_a", &"restless_dead", FOE, 22, 16, Vector2(50, -46), {"name": "Restless Dead", "aggro": 18.0}),
			_p("restless_b", &"restless_dead", FOE, 22, 16, Vector2(30, -44), {"name": "Restless Dead", "aggro": 18.0}),
			_p("knights", &"lowmarch_knights", FOE, 18, 17, Vector2(36, -30), {"name": "Lowmarch Knights", "aggro": 20.0}),
			_p("restless_c", &"restless_dead", FOE, 22, 17, Vector2(14, -52), {"name": "Restless Dead", "aggro": 16.0}),
			_p("drift", &"restless_dead", FOE, 20, 16, Vector2(60, -30), {"name": "Drifting Dead", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_hero("choir", &"drowned_choir", FOE, 20, Vector2(6, -56), {"name": "The Drowned Choir", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("choir_dead", &"restless_dead", FOE, 22, 18, Vector2(-6, -54), {"name": "Choir of the Drowned", "hidden": true, "order": {"kind": "hunt"}}),
		],
		"objectives": [
			{"id": "road", "text": "Carry the Godbridle up the restless road", "type": "reach", "who": "hero", "zone": "restless_road"},
			{"id": "gate", "text": "Reach the vault door", "type": "reach", "who": "hero", "zone": "vault_gate", "hidden": true},
			{"id": "choir", "text": "Lay the Drowned Choir to rest", "type": "defeat", "who": ["choir"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "sereth", "Two years I have carried it. I will carry it a little further."],
				["say", "aurel", "The dead are rising all along the road, High Executor. They follow the bridle."],
			]},
			{"if": {"done": "road"}, "do": [
				["objective", "gate"], ["spawn", "drift"],
				["say", "sereth", "They do not want to harm it. They want to be heard by it. So did I, once."],
			]},
			{"if": {"any": [{"done": "gate"}, {"zone": ["hero", "chamber"]}]}, "do": [
				["spawn", "choir"], ["spawn", "choir_dead"], ["objective", "choir"],
				["say", "choir", "WE WERE NOT ASKED."],
				["say", "sereth", "You will be. Everyone will be. That is what the six came here to promise."],
			]},
			{"if": {"done": ["gate", "choir"]}, "delay": 1.5, "do": [
				["say", "voice", "Sereth. Leave my chair empty. But keep setting the table."],
				["say", "sereth", "…I will, Liesl. I always have."],
				["victory", "The Godbridle reached the vault."],
			]},
		],
		"ending": LAST_COMMAND,
	}


# ====================================================================== NERIS


static func _neris_1() -> Dictionary:
	return {
		"id": "neris_1",
		"title": "Ashgrove’s Promise",
		"year": "Year Four · Spring",
		"briefing": "Ashgrove, the oldest grove outside the Deepwood, grows in the square of the Human town of Thornbury, which took it in three hundred years ago. Gorrum Saltjaw’s raiders have broken from the Orc assembly, and they are burning far groves they claim drink the Basin’s water. Protect the heart trees and the town that sheltered them.",
		"epilogue": "Ashgrove survived, scorched on one side. Its people sent Neris a single instruction through the roots: keep the promise. If she used the bridle to root the far groves back to the Deepwood, the roots would pass under Thornbury and take its wells. Neris understood that the grove would rather fail than break its word. Raska’s runner left with a message for the War Marshal: the Dryads would answer for Gorrum’s fires at the convocation, and so would he.",
		"map": Maps.thornbury(),
		"hero": {"pos": Vector2(0, -12), "facing": Vector2(0, -1)},
		"hero_level": 5,
		"structures": [
			{"id": "tree_west", "kind": &"heart_tree", "team": ALLY, "pos": Vector2(-8, -3), "name": "Western heart tree"},
			{"id": "tree_east", "kind": &"heart_tree", "team": ALLY, "pos": Vector2(8, -3), "name": "Eastern heart tree"},
			{"id": "tree_south", "kind": &"heart_tree", "team": ALLY, "pos": Vector2(0, 10), "name": "Ashgrove heart"},
		],
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 3, Vector2(-4, -16), {"name": "Ashgrove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 3, Vector2(6, -16), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("townsfolk", &"villagers", ALLY, 12, 3, Vector2(12, 8), {"name": "Thornbury Watch", "commandable": false, "order": {"kind": "hold"}}),
			_p("raiders_n", &"saltjaw_raiders", FOE, 16, 3, Vector2(0, -52), {"name": "Saltjaw Raiders", "order": {"kind": "assault", "to": "grove"}}),
			_p("raiders_e", &"saltjaw_raiders", FOE, 16, 3, Vector2(54, -6), {"name": "Saltjaw Raiders", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "assault", "to": "grove"}}),
			_p("slingers", &"basin_slingers", FOE, 10, 3, Vector2(52, 0), {"name": "Saltjaw Slingers", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "assault", "to": "grove"}}),
			_p("raiders_w", &"saltjaw_raiders", FOE, 16, 4, Vector2(-54, 8), {"name": "Saltjaw Raiders", "hidden": true, "facing": Vector2(1, 0), "order": {"kind": "assault", "to": "grove"}}),
			_hero("skarn", &"skarn", FOE, 6, Vector2(0, -54), {"name": "Skarn Emberhand", "hidden": true, "order": {"kind": "assault", "to": "grove"}}),
			_p("skarn_band", &"saltjaw_raiders", FOE, 16, 5, Vector2(4, -56), {"name": "Emberhand's Band", "hidden": true, "order": {"kind": "assault", "to": "grove"}}),
			_p("runners", &"basin_warriors", ALLY, 12, 4, Vector2(52, -8), {"name": "Raska's Runners", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
		],
		"objectives": [
			{"id": "trees", "text": "Protect Ashgrove's heart trees", "type": "protect", "who": ["tree_west", "tree_east", "tree_south"], "fail_text": "A heart tree burned. Its Dryads felt it die."},
			{"id": "raiders", "text": "Drive the raiders out of Thornbury", "type": "defeat", "who": ["raiders_n", "raiders_e", "slingers", "raiders_w"]},
			{"id": "skarn", "text": "Defeat Skarn Emberhand", "type": "defeat", "who": ["skarn"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "hollis", "Rootspeaker! Raiders on the north road with torches. They say the grove is drinking the Basin dry."],
				["say", "neris", "Ashgrove has lived in your square for three hundred years, Reeve. It will not burn in it."],
			]},
			{"if": {"time": 9.0}, "do": [["say", "narrator", "Hold L2 or Tab to command your platoons. Release to return to Neris."]]},
			{"if": {"time": 40.0}, "do": [["spawn", "raiders_e"], ["spawn", "slingers"], ["say", "hollis", "East gate! They're coming over the wall."]]},
			{"if": {"time": 80.0}, "do": [["spawn", "raiders_w"], ["say", "neris", "The western fields. They mean to surround the grove."]]},
			{"if": {"time": 100.0}, "do": [
				["spawn", "runners"],
				["say", "narrator", "Orc runners under the assembly's banner arrive at the east gate."],
				["say", "raska", "(message) The assembly disowns Saltjaw. My runners fight for Thornbury. — Raska Vennor"],
			]},
			{"if": {"done": "raiders"}, "do": [
				["spawn", "skarn"], ["spawn", "skarn_band"], ["objective", "skarn"],
				["say", "skarn", "Gorrum says every tree in Vareth is drinking our sea. I'll start with this one."],
			]},
			{"if": {"done": "skarn"}, "delay": 1.5, "do": [
				["say", "ashgrove", "Keep the promise."],
				["say", "neris", "Even if it means you fail? …Yes. I hear you."],
				["victory", "Ashgrove and Thornbury were saved."],
			]},
		],
	}


static func _neris_2() -> Dictionary:
	return {
		"id": "neris_2",
		"title": "The Thornwall",
		"year": "Year Four · Autumn",
		"briefing": "Sereth has sent word to all six peoples: bring your leaders to the Vault of the First Command in the spring. Isolde and Gorrum have joined forces and are marching to take Briar Pass, the last road to the Cairnspine. Plant four thorn saplings across the pass and hold until the groves can raise a living wall.",
		"epilogue": "The Thornwall rose in a single night, a hedge of living briar forty feet high. Isolde’s army would have to march the long way around the Cairnspine and arrive at the vault in spring, as tired as everyone else. Every grove in the Deepwood had assented to the planting. It was the first time in a hundred years that they had agreed on anything.",
		"map": Maps.briar_pass(),
		"hero": {"pos": Vector2(0, 6), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 8, Vector2(-6, 10), {"name": "Ashgrove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 8, Vector2(6, 12), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("deepwood", &"thornkin", ALLY, 16, 7, Vector2(0, 18), {"name": "Deepwood Kin", "persist": "deepwood", "order": {"kind": "hold"}}),
			_p("vanguard", &"lowmarch_knights", FOE, 18, 9, Vector2(0, -40), {"name": "Lowmarch Vanguard", "order": {"kind": "assault", "to": "pass"}}),
			_p("vanguard_bows", &"lowmarch_crossbows", FOE, 12, 9, Vector2(6, -50), {"name": "Lowmarch Crossbows", "order": {"kind": "assault", "to": "pass"}}),
			_p("raiders_a", &"saltjaw_raiders", FOE, 18, 9, Vector2(-4, -60), {"name": "Saltjaw Raiders", "hidden": true, "order": {"kind": "assault", "to": "pass"}}),
			_p("knights_b", &"lowmarch_knights", FOE, 18, 10, Vector2(4, -60), {"name": "Lowmarch Knights", "hidden": true, "order": {"kind": "assault", "to": "pass"}}),
			_p("raiders_b", &"saltjaw_raiders", FOE, 18, 10, Vector2(0, -62), {"name": "Saltjaw Raiders", "hidden": true, "order": {"kind": "assault", "to": "pass"}}),
			_p("bows_b", &"lowmarch_crossbows", FOE, 12, 10, Vector2(-6, -62), {"name": "Lowmarch Crossbows", "hidden": true, "order": {"kind": "assault", "to": "pass"}}),
		],
		"interactables": [
			{"id": "sapling_1", "pos": Vector2(-12, -4), "label": "Plant a thorn sapling", "duration": 3.0},
			{"id": "sapling_2", "pos": Vector2(-4, -4), "label": "Plant a thorn sapling", "duration": 3.0},
			{"id": "sapling_3", "pos": Vector2(4, -4), "label": "Plant a thorn sapling", "duration": 3.0},
			{"id": "sapling_4", "pos": Vector2(12, -4), "label": "Plant a thorn sapling", "duration": 3.0},
		],
		"objectives": [
			{"id": "plant", "text": "Plant thorn saplings across the pass", "type": "interact", "who": ["sapling_1", "sapling_2", "sapling_3", "sapling_4"]},
			{"id": "grow", "text": "Hold Briar Pass while the Thornwall grows", "type": "hold", "seconds": 120.0, "zone": "pass", "overrun": 12, "hidden": true, "fail_text": "The enemy trampled the saplings and took the pass."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "Four saplings, and every grove in the Deepwood singing to them. Then this pass belongs to the briars."],
				["say", "hollis", "Thornbury sent what it could, Rootspeaker. We owe Ashgrove that much."],
			]},
			{"if": {"interact": "sapling_2"}, "do": [["spawn", "raiders_a"], ["say", "neris", "Saltjaw's raiders. Gorrum sends the torches first."]]},
			{"if": {"done": "plant"}, "do": [
				["objective", "grow"], ["spawn", "knights_b"],
				["say", "neris", "They are planted. Now the groves must agree, all of them at once. Hold the pass!"],
			]},
			{"if": {"after": ["plant", 45.0]}, "do": [["spawn", "raiders_b"], ["spawn", "bows_b"], ["say", "gorrum", "Burn the hedge before it grows! The sea is on the other side of these mountains!"]]},
			{"if": {"after": ["plant", 70.0]}, "do": [["say", "ashgrove", "Assent."], ["say", "neris", "Ashgrove assents. The far groves are answering."]]},
			{"if": {"done": "grow"}, "do": [
				["raise", "thornwall"],
				["say", "neris", "Every grove assents. Rise."],
				["victory", "The Thornwall closed Briar Pass."],
			]},
		],
	}


static func _neris_3() -> Dictionary:
	return {
		"id": "neris_3",
		"title": "Roots of the Vault",
		"year": "Year Five · The Last Command",
		"briefing": "The northwest approach to the Vault crosses a chasm, and the only bridge is a span of living roots that the Dryads grew over the winter. If Isolde’s sappers cut it, the Undead and Druid columns on the far ledge cannot reach the Listening Chamber. Guard both ends of the root bridge.",
		"epilogue": "The bridge held, and the last of the columns crossed it. In the Listening Chamber, Neris spoke for the groves that were failing far from home, and for the town that had taken one of them in. She asked Orrun for nothing. Afterward the far groves would have to be saved slowly, by seed envoys walking the old roads, and by neighbors.",
		"map": Maps.vault(),
		"hero": {"pos": Vector2(-50, -28), "facing": Vector2(0, -1)},
		"hero_level": 18,
		"structures": [
			{"id": "root_south", "kind": &"root_bridge", "team": ALLY, "pos": Vector2(-50, -32), "name": "Southern bridge root", "hp": 52000.0},
			{"id": "root_north", "kind": &"root_bridge", "team": ALLY, "pos": Vector2(-50, -48), "name": "Northern bridge root", "hp": 52000.0},
		],
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 16, Vector2(-44, -26), {"name": "Ashgrove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 16, Vector2(-56, -26), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("deepwood", &"thornkin", ALLY, 18, 16, Vector2(-50, -54), {"name": "Deepwood Kin", "persist": "deepwood", "order": {"kind": "guard", "who": "root_north"}}),
			_p("sappers_s", &"lowmarch_knights", FOE, 16, 15, Vector2(-26, -4), {"name": "Lowmarch Sappers", "order": {"kind": "assault", "to": Vector2(-50, -32)}}),
			_p("bows_s", &"lowmarch_crossbows", FOE, 12, 16, Vector2(-62, -6), {"name": "Lowmarch Crossbows", "order": {"kind": "assault", "to": "bridge_south"}}),
			_p("raiders_n", &"saltjaw_raiders", FOE, 16, 15, Vector2(-62, -66), {"name": "Saltjaw Raiders", "hidden": true, "order": {"kind": "assault", "to": Vector2(-50, -48)}}),
			_p("sappers_b", &"lowmarch_knights", FOE, 16, 16, Vector2(-34, -4), {"name": "Lowmarch Sappers", "hidden": true, "order": {"kind": "assault", "to": Vector2(-50, -32)}}),
			_p("raiders_s", &"saltjaw_raiders", FOE, 16, 16, Vector2(-66, -4), {"name": "Saltjaw Raiders", "hidden": true, "order": {"kind": "assault", "to": Vector2(-50, -32)}}),
			_hero("brannoc", &"brannoc", FOE, 19, Vector2(-40, -2), {"name": "Ser Brannoc Hale", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("brannoc_guard", &"lowmarch_knights", FOE, 16, 18, Vector2(-44, 0), {"name": "Hale's Lances", "hidden": true, "order": {"kind": "assault", "to": Vector2(-50, -32)}}),
			_hero("sereth", &"sereth", ALLY, 18, Vector2(-50, -66), {"name": "Sereth Vale", "hidden": true, "commandable": false, "order": {"kind": "hunt"}}),
		],
		"objectives": [
			{"id": "roots", "text": "Protect both ends of the root bridge", "type": "protect", "who": ["root_south", "root_north"], "fail_text": "The root bridge was cut. The columns could not cross."},
			{"id": "hold", "text": "Keep the bridge open while the columns cross", "type": "hold", "seconds": 150.0},
			{"id": "brannoc", "text": "Defeat Ser Brannoc Hale", "type": "defeat", "who": ["brannoc"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "The roots took all winter to cross. They will not be cut in a morning."],
				["say", "bryn", "The Druid column is on the far ledge, Rootspeaker. The Undead behind them."],
			]},
			{"if": {"time": 30.0}, "do": [["spawn", "raiders_n"], ["say", "neris", "Raiders on the northern ledge. Deepwood Kin, hold that root."]]},
			{"if": {"time": 70.0}, "do": [["spawn", "sappers_b"], ["say", "neris", "More sappers from the south. Kin, stand on the roots."]]},
			{"if": {"time": 100.0}, "do": [["spawn", "raiders_s"]]},
			{"if": {"time": 90.0}, "do": [
				["spawn", "sereth"],
				["say", "sereth", "I am on your bridge, Rootspeaker, with something in my hands that must not fall. Keep it standing."],
			]},
			{"if": {"done": "hold"}, "do": [
				["spawn", "brannoc"], ["spawn", "brannoc_guard"], ["objective", "brannoc"],
				["say", "brannoc", "The Queen wants that bridge in the chasm, Dryad. I don't fail her twice."],
			]},
			{"if": {"done": ["hold", "brannoc"]}, "delay": 1.5, "do": [
				["say", "neris", "Everyone is across. The roots can rest."],
				["victory", "The root bridge held."],
			]},
		],
		"ending": LAST_COMMAND,
	}
