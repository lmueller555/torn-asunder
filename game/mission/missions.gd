extends RefCounted
## The eighteen campaign missions of the five-year war.
##
## Mara, Raska and Ilyra follow their specifications in docs/campaigns. Sova, Neris and
## Sereth follow their windows in docs/war-timeline.md and the specifications written
## alongside these missions. Shared battlefields keep one layout; only starts, orders and
## objectives differ by campaign.

const Maps := preload("res://game/mission/maps.gd")

## Battlefields are authored compactly and played at this scale.
const MAP_SCALE := 1.7

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
	"marit": "Marit Holm",
	"bryn": "Keeper Bryn Hollin",
	"vasha": "Captain Vasha Grem",
	"hadrik": "Lord Hadrik of Westmarch",
	"pilot": "Senna Ruel, pilot",
	"captain": "Port captain",
	"judge": "Judge Tamsin Orle",
	"ally": "Lord Ferran of Ashmarch",
	"aurel": "Advocate Aurel Mott",
	"reeve": "Reeve Hollis Bram",
	"pyre": "Speaker Aldous Pyre",
	"grove": "The grove",
	"voice": "A voice from the bank",
	"levy": "Moonwash levy captain",
	"miner": "A Greyhollow miner",
}

static var _cache: Dictionary = {}


static func for_campaign(id: String) -> Array:
	if _cache.is_empty():
		var raw := {
			"mara": [_mara_1(), _mara_2(), _mara_3()],
			"raska": [_raska_1(), _raska_2(), _raska_3()],
			"sova": [_sova_1(), _sova_2(), _sova_3()],
			"ilyra": [_ilyra_1(), _ilyra_2(), _ilyra_3()],
			"sereth": [_sereth_1(), _sereth_2(), _sereth_3()],
			"neris": [_neris_1(), _neris_2(), _neris_3()],
		}
		for campaign in raw:
			var scaled := []
			for mission: Dictionary in raw[campaign]:
				scaled.append(_scale(mission, MAP_SCALE))
			_cache[campaign] = scaled
	return _cache.get(id, [])


static func find(mission_id: String) -> Dictionary:
	for campaign in ["mara", "raska", "sova", "ilyra", "sereth", "neris"]:
		for mission: Dictionary in for_campaign(campaign):
			if mission.id == mission_id:
				return mission
	return {}


## Scales every position, route, rectangle and obstacle in a mission. Directions and radii do not scale.
static func _scale(value: Variant, k: float, key: String = "") -> Variant:
	if key == "facing":
		return value
	if key == "radius" and (value is float or value is int):
		return value * sqrt(k)
	if (key == "aggro" or key == "wait_for_hero") and (value is float or value is int):
		return value * k
	if value is Vector2:
		return value * k
	if value is Rect2:
		return Rect2(value.position * k, value.size * k)
	if value is Vector3 and key == "circle":
		return value * k
	if value is Dictionary:
		var result := {}
		for item_key in value:
			result[item_key] = _scale(value[item_key], k, str(item_key))
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_scale(item, k, key))
		return result
	return value


static func _p(id: String, type: StringName, team: int, count: int, level: int, pos: Variant, extra: Dictionary = {}) -> Dictionary:
	var entry := {"id": id, "type": type, "team": team, "count": count, "level": level, "pos": pos}
	entry.merge(extra, true)
	return entry


static func _hero(id: String, type: StringName, team: int, level: int, pos: Variant, extra: Dictionary = {}) -> Dictionary:
	return _p(id, type, team, 1, level, pos, extra)


const ALLY := 0
const FOE := 1
const NEUTRAL := 2


# ======================================================================= MARA
# Humans · Years One–Two · docs/campaigns/humans.md


static func _mara_1() -> Dictionary:
	return {
		"id": "mara_mine_escort",
		"title": "The Pass Below the Mine",
		"year": "Year One",
		"briefing": "The Basin has lost its river, and an Orc company is already moving toward the road. Mara puts the Godbridle under his seal and orders the escort to bring it through the pass. Take possession of the bridle at the mine, then carry it to the Marches road. Shield infantry can hold the narrows; archers can cover it from the ridge.",
		"debrief": "The royal seal reached the Marches on the artifact, not on the workers. Somewhere under the Cairnspine the miners walked out through tunnels no Human map recorded, and one of them left willingly with the Orc War Marshal.\n\nWeeks later a copy of her account reached Mara’s table. The spring at Greyhollow and the dry river in the Basin dated to the same night.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(4, -56), "facing": Vector2(0, -1)},
		"hero_level": 5,
		"platoons": [
			_p("shields", &"marcher_infantry", ALLY, 20, 3, Vector2(-5, -52), {"name": "Halden Shields", "persist": "shields", "order": {"kind": "follow"}, "facing": Vector2(0, 1)}),
			_p("archers", &"marcher_archers", ALLY, 12, 3, Vector2(9, -52), {"name": "Ridge Archers", "persist": "archers", "order": {"kind": "follow"}, "facing": Vector2(0, 1)}),
			_p("redwater", &"basin_warriors", FOE, 18, 3, Vector2(50, -8), {"name": "Redwater Company", "facing": Vector2(-1, 0), "order": {"kind": "hold"}, "aggro": 12.0}),
			_p("slingers", &"basin_slingers", FOE, 10, 3, Vector2(52, -5), {"name": "Basin Slingers", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "move", "to": Vector2(24, -8)}, "aggro": 18.0}),
			_hero("durga", &"durga", FOE, 6, Vector2(52, -10), {"name": "Durga Ashtusk", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("saltwell", &"basin_warriors", FOE, 16, 4, Vector2(50, -12), {"name": "Saltwell Company", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "attack", "target": "hero"}}),
		],
		"interactables": [
			{"id": "pickup", "pos": Vector2(2, -63), "label": "Take the Godbridle under seal", "duration": 2.5},
		],
		"objectives": [
			{"id": "pickup", "text": "Take possession of the Godbridle", "type": "interact", "who": "pickup"},
			{"id": "exit", "text": "Carry the Godbridle to the Marches road", "type": "reach", "who": "hero", "zone": "exit", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aldric", "The miners are gone, Majesty. Only the thing they used is left."],
				["say", "mara", "Then it leaves under my seal. Fetch it, and keep the road open."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "Hold L2 (or Tab) to command. Order the shields to hold the narrows and the archers to the ridge."]]},
			{"if": {"done": "pickup"}, "do": [
				["objective", "exit"], ["order", "redwater", {"kind": "assault", "to": "narrows"}], ["spawn", "slingers"],
				["say", "aldric", "Orc company in the dry riverbed, moving on the narrows."],
				["say", "mara", "Shields to the narrows. Archers to the ridge. I carry it through myself."],
			]},
			{"if": {"after": ["pickup", 20.0]}, "do": [
				["spawn", "durga"], ["spawn", "saltwell"],
				["say", "durga", "The Marshal wants a witness. I want the thing that stole our river. Break the escort!"],
			]},
			{"if": {"done": "exit"}, "do": [
				["say", "mara", "The Marches road. Seal the case. No one opens it but me."],
				["victory", "The Godbridle reached the Seven Marches."],
			]},
		],
	}


static func _mara_2() -> Dictionary:
	return {
		"id": "mara_grain_crossing",
		"title": "Grain on Credit",
		"year": "Year Two",
		"briefing": "Grain bought from an allied crown waits on the far bank. Rival levies mean to impound it before it reaches Mara’s towns, and the allied crown is threatening to recall its grain and troops unless Mara makes good on water. Two loads can get through: seed grain to the mill yard by the bridge, and bread grain to the town store above the lower ford. Order each cart forward in the command view, and keep a reserve for the second lane.",
		"debrief": "The council heard the petitions read. Even full carts could not carry the Marches through a second failed harvest.\n\nWith his allies threatening to leave, Mara went to the Godbridle and asked Orrun to return water to the dry headwater channels. Judge Tamsin Orle asked whose water could fill them. Mara believed his wording would spare the neighbors.",
		"debrief_flags": {
			"seed_cart_delivered": "Seed grain reached the mill yard. A planting can go ahead.",
			"bread_cart_delivered": "Bread grain reached the town store. The town keeps its ovens open this week.",
			"!seed_cart_delivered": "The seed grain never reached the mill yard. The petition read to Mara asks how anyone is to plant.",
			"!bread_cart_delivered": "The bread grain never reached the town store. The petition read to Mara asks why the ovens are cold.",
		},
		"map": Maps.marches_crossing(),
		"hero": {"pos": Vector2(0, -42), "facing": Vector2(0, 1)},
		"hero_level": 11,
		"structures": [
			{"id": "seed_cart", "kind": &"cart", "team": ALLY, "name": "Seed cart", "pos": Vector2(4, -50), "speed": 1.8,
				"commandable": true, "halted": true, "escort_radius": 0.0,
				"path": [Vector2(0, -32), Vector2(22, -22), Vector2(22, -4), Vector2(24, 22)]},
			{"id": "bread_cart", "kind": &"cart", "team": ALLY, "name": "Bread cart", "pos": Vector2(-4, -50), "speed": 1.6,
				"commandable": true, "halted": true, "escort_radius": 0.0,
				"path": [Vector2(0, -32), Vector2(-28, -22), Vector2(-28, -4), Vector2(-30, 34)]},
		],
		"platoons": [
			_p("shields", &"marcher_infantry", ALLY, 20, 8, Vector2(-6, -44), {"name": "Halden Shields", "persist": "shields", "order": {"kind": "follow"}, "facing": Vector2(0, 1)}),
			_p("archers", &"marcher_archers", ALLY, 12, 8, Vector2(8, -44), {"name": "Ridge Archers", "persist": "archers", "order": {"kind": "follow"}, "facing": Vector2(0, 1)}),
			_p("reserve", &"marcher_infantry", ALLY, 18, 7, Vector2(0, -28), {"name": "Rivergate Reserve", "persist": "reserve", "order": {"kind": "hold"}, "facing": Vector2(0, 1)}),
			_p("far_bows", &"march_bows", FOE, 12, 8, Vector2(38, -26), {"name": "Far-bank Bowmen", "aggro": 20.0, "facing": Vector2(-1, 0)}),
			_p("east_levy", &"march_levy", FOE, 18, 8, Vector2(52, 12), {"name": "Westmarch Levy", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "move", "to": Vector2(26, 8)}, "aggro": 14.0}),
			_p("west_levy", &"march_levy", FOE, 18, 8, Vector2(-52, 24), {"name": "Westmarch Levy", "hidden": true, "facing": Vector2(1, 0), "order": {"kind": "move", "to": Vector2(-28, 8)}, "aggro": 14.0}),
			_p("riders", &"march_riders", FOE, 12, 9, Vector2(52, 4), {"name": "Westmarch Riders", "hidden": true, "facing": Vector2(-1, 0), "order": {"kind": "hunt"}}),
		],
		"objectives": [
			{"id": "deliver", "text": "Get at least one grain cart to its receiving yard", "type": "deliveries", "carts": {"seed_cart": "mill_yard", "bread_cart": "town_store"}, "need": 1, "fail_text": "Both grain loads were lost before either arrived."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aldric", "Two carts, two roads. The bridge is short, but their bowmen on the rise can see every plank. The ford is slow and screened."],
				["say", "mara", "Then we choose which load matters more today. Hold the reserve at the fork."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "In the command view, select a cart and order it to move. Circle (or F) turns an exposed cart back."]]},
			{"if": {"time": 25.0}, "do": [
				["spawn", "east_levy"],
				["say", "aldric", "Levy on the east road, moving toward the bridge lane."],
			]},
			{"if": {"time": 70.0}, "do": [
				["spawn", "west_levy"],
				["say", "aldric", "A second levy on the west road. They're making for the ford."],
			]},
			{"if": {"time": 110.0}, "do": [
				["spawn", "riders"],
				["say", "hadrik", "Impound the carts in the name of Westmarch. Halden can pay his debts in water."],
			]},
			{"if": {"done": "deliver"}, "do": [
				["say", "mara", "Count what reached the yards. Then tell me what it buys us."],
				["victory", "The grain crossing is resolved."],
			]},
		],
	}


static func _mara_3() -> Dictionary:
	return {
		"id": "mara_moonwash_quay",
		"title": "The High Quay",
		"year": "Year Two",
		"briefing": "Mara sends his detachment to Moonwash to find where the reversed current began and to warn the harbor pilots. They arrive as buried walls push up beneath moored ships. The lower quay is fracturing, the upper stairs are still passable, and the Tide Speaker’s pilots are rigging lines to crews stranded on stone. Your orders are to pull back, not to claim the harbor or fight the fleet. Get the hero and both royal platoons through the upper-quay exit.",
		"debrief": "The detachment came home with firsthand testimony and left the waterline to the Tide Speaker, who stayed with her rescue rather than pursue the bridle.\n\nMara laid two reports side by side. Ships were still stranded on stone at Moonwash. Water had reached some Marches and missed others he had pledged it to. Lord Ferran of Ashmarch asked him to speak to Orrun again.\n\nMara left his seal on the case and ordered it shut.",
		"map": Maps.moonwash(),
		"hero": {"pos": Vector2(-22, -4), "facing": Vector2(1, 0)},
		"hero_level": 13,
		"platoons": [
			_p("shields", &"marcher_infantry", ALLY, 20, 11, Vector2(-24, 6), {"name": "Halden Shields", "persist": "shields", "order": {"kind": "hold"}, "facing": Vector2(1, 0)}),
			_p("archers", &"marcher_archers", ALLY, 12, 11, Vector2(-20, -10), {"name": "Ridge Archers", "persist": "archers", "order": {"kind": "hold"}, "facing": Vector2(1, 0)}),
			_hero("ilyra", &"ilyra", NEUTRAL, 10, Vector2(-38, -6), {"name": "Ilyra Venn", "commandable": false}),
			_p("rescuers", &"wavecutters", NEUTRAL, 14, 8, Vector2(-40, 6), {"name": "Elven rescue crews", "commandable": false}),
			_p("levy_north", &"moonwash_levy", FOE, 18, 10, Vector2(-24, -30), {"name": "Moonwash Levy", "order": {"kind": "path", "points": [Vector2(-22, -18), Vector2(-16, -8), Vector2(-8, -2)]}, "aggro": 9.0}),
			_p("levy_south", &"moonwash_levy", FOE, 18, 10, Vector2(-24, 34), {"name": "Moonwash Levy", "hidden": true, "order": {"kind": "path", "points": [Vector2(-24, 30), Vector2(-20, 12), Vector2(-12, 2)]}, "aggro": 9.0}),
			_p("levy_upper", &"moonwash_levy", FOE, 14, 11, Vector2(10, -40), {"name": "Quay Watch", "hidden": true, "order": {"kind": "path", "points": [Vector2(14, -20), Vector2(14, -6)]}, "aggro": 8.0}),
		],
		"objectives": [
			{"id": "withdraw", "text": "Bring Mara and both royal platoons through the upper-quay exit", "type": "extract", "zone": "upper_exit", "squads": ["shields", "archers"], "hero": true, "fail_text": "A royal platoon was wiped out before it reached the exit."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aldric", "The quay is breaking up under us. Those are the Tide Speaker's people at the waterline, Majesty."],
				["say", "mara", "Then the waterline is theirs. We are here to warn, not to take. Up the stairs."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "One platoon holds the narrow stair while the other climbs to the landing and turns to cover."]]},
			{"if": {"time": 14.0}, "do": [
				["say", "levy", "Armed outsiders off the lower stair! It is for the townspeople."],
				["hazard", "slab_north", 6.0, 14.0, 0.07],
				["say", "aldric", "The slab to the north is cracking. Move off it!"],
			]},
			{"if": {"time": 26.0}, "do": [
				["spawn", "levy_south"], ["hazard", "slab_south", 6.0, 14.0, 0.07],
				["say", "aldric", "More levy from the south quay, and the southern slab is going."],
			]},
			{"if": {"time": 40.0}, "do": [
				["hazard", "slab_stair", 6.0, 16.0, 0.07],
				["spawn", "levy_upper"],
				["say", "mara", "The stair foot is buckling. Rear guard, come up now."],
			]},
			{"if": {"done": "withdraw"}, "do": [
				["say", "mara", "Count who came up, and write down what we saw. Every ship."],
				["victory", "The detachment withdrew from Moonwash."],
			]},
		],
	}


# ====================================================================== RASKA
# Orcs · Years One–Four · docs/campaigns/orcs.md


static func _raska_1() -> Dictionary:
	return {
		"id": "orc_mine_witness",
		"title": "One Person to Ask",
		"year": "Year One",
		"briefing": "Capture someone who can account for the spring at the mine and the dry river in the Basin. The Godbridle is not the objective. Pin the Human rearguard where the pass narrows with one company, and send the other down the lower path behind the rock shoulder to hold the tunnel outlet approach.",
		"debrief": "Raska gave up the pursuit with the bridle still in sight. Marit Holm walked beside him all the way down into the Basin and told her story twice before they reached the first well.\n\nAt the assembly her account was set beside the survey the Druids sent after her. The spring and the loss of the river fell on the same night.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(46, -8), "facing": Vector2(-1, 0)},
		"hero_level": 5,
		"platoons": [
			_p("saltwell", &"basin_warriors", ALLY, 18, 3, Vector2(42, -4), {"name": "Saltwell Company", "persist": "saltwell", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("redwater", &"basin_warriors", ALLY, 18, 3, Vector2(44, -12), {"name": "Redwater Company", "persist": "redwater", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("rearguard", &"marcher_infantry", FOE, 18, 3, Vector2(0, -18), {"name": "Halden Rearguard", "aggro": 14.0, "facing": Vector2(0, 1)}),
			_p("ridge_archers", &"marcher_archers", FOE, 12, 3, Vector2(24, -40), {"name": "Ridge Archers", "aggro": 20.0, "facing": Vector2(0, 1)}),
			_p("detachment", &"marcher_infantry", FOE, 14, 3, Vector2(-2, -4), {"name": "Halden Detachment", "hidden": true, "order": {"kind": "move", "to": "outlet_approach"}, "aggro": 8.0}),
			_p("miners", &"miners", NEUTRAL, 12, 2, Vector2(-50, 26), {"name": "Greyhollow Miners", "hidden": true, "commandable": false, "order": {"kind": "hold"}}),
			_p("wardens", &"cairn_wardens", NEUTRAL, 10, 3, Vector2(-46, 30), {"name": "Cairn Wardens", "hidden": true, "commandable": false, "order": {"kind": "hold"}}),
			_hero("marit", &"witness", NEUTRAL, 4, Vector2(-44, 32), {"name": "Marit Holm", "hidden": true, "commandable": false, "order": {"kind": "hold"}}),
		],
		"interactables": [
			{"id": "terms", "pos": Vector2(-44, 34), "label": "Accept her terms", "duration": 2.5, "hidden": true},
		],
		"objectives": [
			{"id": "approach", "text": "Hold the outlet approach", "type": "hold", "zone": "outlet_approach", "contest": true, "seconds": INF, "overrun_time": 15.0, "fail_text": "The Human detachment sealed the outlet approach before the workers escaped."},
			{"id": "terms", "text": "Speak with the miner at the outlet", "type": "interact", "who": "terms", "hidden": true},
			{"id": "escort", "text": "Escort Marit Holm to the Orc rally point", "type": "reach", "who": "marit", "zone": "orc_rally", "hidden": true},
			{"id": "witness", "text": "Marit Holm must survive", "type": "protect", "who": ["marit"], "hidden": true, "fail_text": "The witness was killed."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "raska", "The bridle is leaving by the road. Let it. A box cannot tell the assembly what happened to our river."],
				["say", "durga", "Then who can, Marshal?"],
				["say", "raska", "Whoever was in that camp. Saltwell pins the rearguard at the narrows. Redwater, down the lower path to the outlet."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "Hold L2 (or Tab) to command. Order one company to the narrows and the other to the outlet approach."]]},
			{"if": {"time": 40.0}, "do": [
				["spawn", "detachment"],
				["say", "durga", "Human detachment slipping past the narrows. They're heading for the outlet."],
			]},
			{"if": {"time": 55.0}, "do": [
				["spawn", "miners"], ["spawn", "wardens"], ["spawn", "marit"], ["reveal", "terms"], ["objective", "terms"],
				["say", "narrator", "Workers stream out of the tunnel outlet behind grey-skinned Druid wardens. One woman stops and waits."],
				["say", "marit", "You want someone who saw it. I saw it. I'll tell your assembly everything, if the rest of them can go."],
			]},
			{"if": {"done": "terms"}, "do": [
				["say", "raska", "Agreed. No one touches the others."],
				["order", "miners", {"kind": "path", "points": [Vector2(-46, 44), Vector2(-50, 68)]}],
				["order", "wardens", {"kind": "path", "points": [Vector2(-46, 46), Vector2(-50, 70)]}],
			]},
			{"if": {"all": [{"done": "terms"}, {"zone": ["miners", "druid_trail"]}]}, "do": [
				["despawn", "miners"], ["despawn", "wardens"], ["complete", "approach"],
				["defect", "marit"], ["order", "marit", {"kind": "follow"}],
				["objective", "escort"], ["objective", "witness"],
				["say", "marit", "They're clear. I'm Marit Holm. Walk slowly, Marshal. I've been underground for a day."],
			]},
			{"if": {"done": "escort"}, "do": [
				["say", "raska", "Durga, pull Saltwell back. We have what we came for."],
				["victory", "Raska has a witness the assembly will believe."],
			]},
		],
	}


static func _raska_2() -> Dictionary:
	return {
		"id": "orc_well_road",
		"title": "The Second Bucket",
		"year": "Year Three",
		"briefing": "Reports say Mara moved the water again. The new cut has left the Basin’s well road carrying the traffic its river used to serve, and a rival March company is coming for the well carts after its own supply failed. Open the lower well’s storehouse to the households without a well right, then get both carts to the Basin exit. The salt road is short but gives riders a charge lane; the crooked wash breaks a charge, but its single ramp is a choke point.",
		"debrief": "Captain Vasha Grem lent her lower-town company for the escort and counted the last barrels onto the cart herself. When the carts were through, she asked Raska what his restored river would give the towns beyond its banks.\n\nHe could promise a river. He could not promise a sea.",
		"map": Maps.well_road(),
		"hero": {"pos": Vector2(2, -52), "facing": Vector2(0, 1)},
		"hero_level": 10,
		"structures": [
			{"id": "upper_cart", "kind": &"cart", "team": ALLY, "name": "Upper-well cart", "pos": Vector2(-20, -50), "speed": 1.8,
				"commandable": true, "halted": true, "escort_radius": 0.0, "routes": [
					[Vector2(0, -40), Vector2(14, -30), Vector2(28, 0), Vector2(28, 30), Vector2(10, 50), Vector2(0, 62)],
					[Vector2(-13, -30), Vector2(-13, -8), Vector2(-44, 0), Vector2(-44, 16), Vector2(-40, 26), Vector2(-40, 36), Vector2(-20, 46), Vector2(0, 62)],
				]},
			{"id": "lower_cart", "kind": &"cart", "team": ALLY, "name": "Lower-well cart", "pos": Vector2(18, -46), "speed": 1.7,
				"commandable": false, "halted": true, "escort_radius": 0.0, "routes": [
					[Vector2(14, -30), Vector2(28, 0), Vector2(28, 30), Vector2(10, 50), Vector2(0, 62)],
					[Vector2(0, -40), Vector2(-13, -30), Vector2(-13, -8), Vector2(-44, 0), Vector2(-44, 16), Vector2(-40, 26), Vector2(-40, 36), Vector2(-20, 46), Vector2(0, 62)],
				]},
		],
		"platoons": [
			_p("saltwell", &"basin_warriors", ALLY, 18, 8, Vector2(-4, -48), {"name": "Saltwell Company", "persist": "saltwell", "order": {"kind": "follow"}}),
			_p("redwater", &"basin_warriors", ALLY, 18, 8, Vector2(8, -48), {"name": "Redwater Company", "persist": "redwater", "order": {"kind": "follow"}}),
			_p("slingers", &"basin_slingers", ALLY, 12, 8, Vector2(2, -58), {"name": "Basin Slingers", "persist": "slingers", "order": {"kind": "follow"}}),
			_p("lowshore", &"basin_warriors", ALLY, 16, 7, Vector2(26, -48), {"name": "Lowshore Company", "order": {"kind": "hold"}}),
			_p("households", &"households", ALLY, 10, 3, Vector2(32, -52), {"name": "Households without a well", "commandable": false, "order": {"kind": "hold"}}),
			_p("riders", &"march_riders", FOE, 14, 9, Vector2(46, -16), {"name": "March Riders", "order": {"kind": "hold"}, "facing": Vector2(-1, 0)}),
			_p("riders_two", &"march_riders", FOE, 12, 9, Vector2(48, 20), {"name": "March Riders", "hidden": true, "order": {"kind": "hunt"}, "facing": Vector2(-1, 0)}),
			_p("wash_levy", &"march_levy", FOE, 16, 8, Vector2(-46, -40), {"name": "March Levy", "hidden": true, "order": {"kind": "move", "to": "ramp"}, "aggro": 12.0}),
			_p("bows", &"march_bows", FOE, 12, 8, Vector2(42, 34), {"name": "March Bowmen", "hidden": true, "order": {"kind": "move", "to": Vector2(34, 30)}, "aggro": 20.0}),
		],
		"interactables": [
			{"id": "storehouse", "pos": Vector2(31, -56), "label": "Open the storehouse", "duration": 2.5},
		],
		"objectives": [
			{"id": "storehouse", "text": "Open the lower well's storehouse", "type": "interact", "who": "storehouse"},
			{"id": "carts", "text": "Get both well carts to the Basin exit", "type": "deliveries", "carts": {"upper_cart": "exit", "lower_cart": "exit"}, "need": 2, "fail_text": "A well cart was destroyed on the road."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "vasha", "My company is yours for the road, Marshal. The barrels are another matter. Those are counted."],
				["say", "raska", "The upper cart can leave now. Watch the riders before you commit it."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "Order a cart forward in the command view. Point the cursor at the salt road or the wash to choose its route."]]},
			{"if": {"done": "storehouse"}, "do": [
				["order", "households", {"kind": "move", "to": Vector2(20, -50)}],
				["say", "raska", "Everyone without a well right rides on the lower cart. March refugees too."],
				["say", "vasha", "Even the Humans? …Fine. Get them aboard."],
			]},
			{"if": {"all": [{"done": "storehouse"}, {"zone": ["households", "lower_well"]}]}, "delay": 3.0, "do": [
				["despawn", "households"], ["cart_commandable", "lower_cart"],
				["say", "vasha", "They're aboard. The lower cart is ready to roll."],
			]},
			{"if": {"time": 40.0}, "do": [
				["order", "riders", {"kind": "hunt"}],
				["say", "durga", "Riders turning on the salt road! Brace, or take the wash."],
			]},
			{"if": {"time": 60.0}, "do": [["spawn", "wash_levy"], ["say", "durga", "Levy moving into the wash. They want the ramp."]]},
			{"if": {"time": 95.0}, "do": [["spawn", "riders_two"], ["spawn", "bows"], ["say", "durga", "Second rider wave forming up, bowmen behind them."]]},
			{"if": {"done": ["storehouse", "carts"]}, "do": [
				["say", "vasha", "Every barrel through. Now tell me, Marshal. What does your river give a town that isn't on its banks?"],
				["say", "raska", "A river. Not a sea."],
				["victory", "Both well carts reached the Basin exit."],
			]},
		],
	}


static func _raska_3() -> Dictionary:
	return {
		"id": "orc_spanwater_release",
		"title": "River, Not Sea",
		"year": "Year Four",
		"briefing": "The breach at Spanwater Lock lets the Basin take back some of the diverted water without the Godbridle. The spillway feeds the old Basin riverbed. The sea gate would fill the old seabed and drown the assembly town. Cross the service causeway, clear the spillway wheel, start the release, and hold the wheel until the river reaches its stage. The release will cut the low crossing.",
		"debrief": "The Basin got its river back, not its sea. The lower-town standards went home up the approach road, still friendly and no longer Raska’s, and the Marches lost part of their diverted water.\n\nOn the high bank, Raska watched King Mara hand the Godbridle to the First Listener in front of Orc and Elven witnesses. No one asked the War Marshal to take it, and he did not offer.",
		"map": Maps.spanwater(),
		"hero": {"pos": Vector2(62, -24), "facing": Vector2(-1, 0)},
		"hero_level": 15,
		"platoons": [
			_p("saltwell", &"basin_warriors", ALLY, 18, 13, Vector2(64, -18), {"name": "Saltwell Company", "persist": "saltwell", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("redwater", &"basin_warriors", ALLY, 18, 13, Vector2(66, -30), {"name": "Redwater Company", "persist": "redwater", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("slingers", &"basin_slingers", ALLY, 12, 13, Vector2(68, -24), {"name": "Basin Slingers", "persist": "slingers", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_p("lowshore", &"basin_warriors", ALLY, 16, 12, Vector2(60, -14), {"name": "Lowshore Company", "order": {"kind": "follow"}, "facing": Vector2(-1, 0)}),
			_hero("vasha", &"vasha", ALLY, 12, Vector2(58, -18), {"name": "Captain Vasha Grem", "commandable": false, "order": {"kind": "follow"}}),
			_p("apron_levy", &"march_levy", FOE, 18, 13, Vector2(22, -14), {"name": "Lock Defenders", "aggro": 16.0, "facing": Vector2(1, 0)}),
			_p("wheel_guard", &"march_levy", FOE, 16, 13, Vector2(-6, -22), {"name": "Wheel Guard", "aggro": 12.0, "facing": Vector2(1, 0)}),
			_p("lock_bows", &"march_bows", FOE, 12, 13, Vector2(4, -22), {"name": "Lock Bowmen", "aggro": 18.0, "facing": Vector2(1, 0)}),
			_p("counter_one", &"march_levy", FOE, 18, 13, Vector2(18, 60), {"name": "March Counterattack", "hidden": true, "order": {"kind": "assault", "to": "wheel"}}),
			_p("counter_riders", &"march_riders", FOE, 12, 13, Vector2(22, 62), {"name": "March Riders", "hidden": true, "order": {"kind": "assault", "to": "wheel"}}),
			_p("counter_two", &"march_levy", FOE, 18, 14, Vector2(60, -20), {"name": "March Counterattack", "hidden": true, "order": {"kind": "assault", "to": "wheel"}}),
			_p("feeder_kin", &"thornkin", NEUTRAL, 12, 10, Vector2(-26, -26), {"name": "Dryads at the feeder", "commandable": false}),
		],
		"interactables": [
			{"id": "release", "pos": Vector2(-8, -28), "label": "Turn the spillway wheel", "duration": 3.5, "hidden": true},
		],
		"objectives": [
			{"id": "clear", "text": "Clear the spillway wheel", "type": "defeat", "who": ["wheel_guard", "lock_bows"]},
			{"id": "release", "text": "Start the release at the spillway wheel", "type": "interact", "who": "release", "hidden": true},
			{"id": "stage", "text": "Hold the spillway clear until the river reaches its stage", "type": "hold", "zone": "wheel", "contest": true, "seconds": 90.0, "overrun_time": 12.0, "hidden": true, "fail_text": "March defenders shut the spillway before the river reached its stage."},
			{"id": "bank", "text": "Bring Raska to the high bank", "type": "reach", "who": "hero", "zone": "high_bank", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "raska", "Two controls on that lock. The spillway gives the Basin its river. The sea gate gives the lower towns their sea, and drowns the assembly town doing it."],
				["say", "vasha", "My companies came for both, Marshal. You know that."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "The lock stairs give infantry cover. The apron is open ground where defenders mass."]]},
			{"if": {"done": "clear"}, "do": [
				["reveal", "release"], ["objective", "release"],
				["say", "raska", "The wheel is ours. Spillway only."],
			]},
			{"if": {"done": "release"}, "do": [
				["objective", "stage"],
				["say", "vasha", "And the sea gate, Marshal?"],
				["say", "raska", "Stays shut. I was elected to bring back a river."],
				["say", "vasha", "Then the lower towns go home. No hard feelings. No more companies."],
				["leave", "lowshore", "upstream"], ["leave", "vasha", "upstream"],
				["spawn", "counter_one"], ["spawn", "counter_riders"],
				["say", "durga", "Counterattack from the south road!"],
			]},
			{"if": {"after": ["release", 20.0]}, "do": [
				["say", "narrator", "The release floods the low crossing in fifteen seconds. Use the high bank."],
			]},
			{"if": {"after": ["release", 35.0]}, "do": [
				["raise", "flood"],
				["say", "raska", "There it goes. The old riverbed is a river again."],
			]},
			{"if": {"after": ["release", 50.0]}, "do": [["spawn", "counter_two"], ["say", "durga", "More of them on the causeway. Without Lowshore we're thin."]]},
			{"if": {"done": "stage"}, "do": [
				["objective", "bank"],
				["say", "raska", "River stage. Now to the high bank. I want to see it run."],
			]},
			{"if": {"done": "bank"}, "do": [
				["victory", "The Basin has its river, and the sea gate stays shut."],
			]},
		],
	}


# ======================================================================= SOVA
# Druids · Years One–Five · docs/campaigns/druids.md


static func _sova_1() -> Dictionary:
	return {
		"id": "sova_tunnel_evacuation",
		"title": "The Listening Tunnels",
		"year": "Year One",
		"briefing": "The Druids heard Orrun stir and knew what the miners had asked for. Halden soldiers are securing the camp, and an Orc delegation is coming for anyone who can explain the dry river. Lead the workers into the old listening tunnels, then bring them out of the outlet and down the Druid trail.",
		"debrief": "The workers walked out under the Cairnspine. At the outlet, one of them, Marit Holm, chose to go with the Orc War Marshal, on the condition that he let the others leave. Sova let her choose.\n\nAt home he dated the change in Orrun’s dreams from the stones. It matched the night of the miners’ request, and it matched the oldest sealed record in the Cairnspine.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(-44, -48), "facing": Vector2(1, 0)},
		"hero_level": 5,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 16, 3, Vector2(-40, -44), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("callers", &"stonecallers", ALLY, 10, 3, Vector2(-46, -54), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("miners", &"miners", ALLY, 12, 2, Vector2(-20, -54), {"name": "Greyhollow Miners", "commandable": false, "order": {"kind": "hold"}}),
			_p("camp_guard", &"marcher_infantry", FOE, 14, 3, Vector2(-8, -46), {"name": "Halden Camp Guard", "aggro": 13.0, "facing": Vector2(-1, 0)}),
			_p("miners_out", &"miners", ALLY, 12, 2, Vector2(-50, 28), {"name": "Greyhollow Miners", "hidden": true, "commandable": false, "order": {"kind": "hold"}}),
			_p("detachment", &"marcher_infantry", FOE, 16, 3, Vector2(-6, 34), {"name": "Halden Detachment", "hidden": true, "order": {"kind": "attack", "target": "miners_out"}}),
			_hero("raska", &"raska", NEUTRAL, 6, Vector2(-30, 46), {"name": "Raska Vennor", "hidden": true, "commandable": false}),
			_p("redwater", &"basin_warriors", NEUTRAL, 16, 3, Vector2(-26, 50), {"name": "Redwater Company", "hidden": true, "commandable": false}),
		],
		"objectives": [
			{"id": "camp", "text": "Reach the miners' camp", "type": "reach", "who": "hero", "zone": "camp"},
			{"id": "tunnel", "text": "Lead the miners into the tunnel entrance", "type": "reach", "who": "miners", "zone": "tunnel", "hidden": true},
			{"id": "trail", "text": "Bring the miners from the outlet to the Druid trail", "type": "reach", "who": "miners_out", "zone": "druid_trail", "hidden": true},
			{"id": "safe", "text": "The miners must survive", "type": "protect", "who": ["miners", "miners_out"], "fail_text": "The miners were cut down before they reached safety."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "sova", "Orrun heard them ask for water, and it answered. Now the armies will decide what the miners are worth. We decide first."],
				["say", "bryn", "Halden's men hold the camp. They're more interested in the mine than the people."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "Hold L2 (or Tab) to command your platoons. Release to return to Sova."]]},
			{"if": {"done": "camp"}, "do": [
				["objective", "tunnel"],
				["order", "miners", {"kind": "path", "points": [Vector2(-30, -52), Vector2(-42, -50), Vector2(-50, -50)], "wait_for_hero": 14.0}],
				["say", "sova", "We are Listeners from the Cairnspine. Stay close. The tunnels know the way out."],
				["say", "miner", "Out where? Everyone up here wants us for something."],
			]},
			{"if": {"done": "tunnel"}, "delay": 1.0, "do": [
				["despawn", "miners"],
				["say", "narrator", "Through the listening tunnels, under the pass, to the outlet below the rock shoulder…"],
				["teleport", "hero", Vector2(-44, 30)], ["teleport", "wardens", Vector2(-42, 38)], ["teleport", "callers", Vector2(-46, 20)],
				["spawn", "miners_out"], ["spawn", "raska"], ["spawn", "redwater"], ["spawn", "detachment"],
				["objective", "trail"],
				["order", "miners_out", {"kind": "path", "points": [Vector2(-46, 44), Vector2(-50, 68)], "wait_for_hero": 16.0}],
			]},
			{"if": {"after": ["tunnel", 3.0]}, "do": [
				["say", "raska", "Listener. I am not here for your workers. I need one person who will tell my assembly what happened to our river."],
				["say", "marit", "I'll go. If he lets the rest of us leave."],
				["say", "sova", "Then it is her choice, War Marshal, not mine. Keep your word."],
				["say", "bryn", "Halden detachment coming round the shoulder!"],
			]},
			{"if": {"done": "trail"}, "do": [
				["despawn", "miners_out"],
				["say", "sova", "They are on the trail. No army follows a Druid trail for long."],
				["victory", "The miners escaped through the listening tunnels."],
			]},
		],
	}


static func _sova_2() -> Dictionary:
	return {
		"id": "sova_spanwater_handover",
		"title": "Custody, Not Ownership",
		"year": "Year Four",
		"briefing": "Two years ago Sova read the sealed record aloud: the Druids’ first command raised the Cairnspine, drowned the Moonwash coast and helped drain the Red Basin. Several Keepers walked out. Now, at Spanwater, King Mara has refused to give Orrun another order and offers the Godbridle into Sova’s keeping in front of Orc and Elven witnesses. Receive it on the high bank and carry it to the Cairnspine road. The rival crowns would rather it never got there.",
		"debrief": "The handover changed custody, not ownership by treaty. Orc and Elven witnesses saw King Mara give the Godbridle to the First Listener, and saw him carry it away without speaking a word to Orrun.\n\nThe rival crowns, and the Still Kingdom, still meant to claim it before it reached the vault.",
		"map": Maps.spanwater(),
		"hero": {"pos": Vector2(20, 58), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 16, 9, Vector2(14, 60), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}, "facing": Vector2(0, -1)}),
			_p("callers", &"stonecallers", ALLY, 10, 9, Vector2(26, 60), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "follow"}, "facing": Vector2(0, -1)}),
			_p("valley", &"cairn_wardens", ALLY, 14, 8, Vector2(20, 64), {"name": "Valley Guard", "persist": "valley", "order": {"kind": "follow"}, "facing": Vector2(0, -1)}),
			_hero("mara", &"mara", NEUTRAL, 13, Vector2(-30, -8), {"name": "Mara Halden", "commandable": false}),
			_p("halden", &"marcher_infantry", NEUTRAL, 16, 11, Vector2(-26, -14), {"name": "Halden Shields", "commandable": false}),
			_hero("raska", &"raska", NEUTRAL, 15, Vector2(-38, -16), {"name": "Raska Vennor", "commandable": false}),
			_hero("ilyra", &"ilyra", NEUTRAL, 13, Vector2(-38, 4), {"name": "Ilyra Venn", "commandable": false}),
			_hero("hadrik", &"hadrik", FOE, 13, Vector2(-56, 30), {"name": "Lord Hadrik of Westmarch", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("west_levy", &"march_levy", FOE, 18, 10, Vector2(-54, 8), {"name": "Westmarch Levy", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("west_riders", &"march_riders", FOE, 12, 10, Vector2(-40, 58), {"name": "Westmarch Riders", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("west_bows", &"march_bows", FOE, 12, 10, Vector2(-60, 22), {"name": "Westmarch Bowmen", "hidden": true, "order": {"kind": "hold"}, "aggro": 18.0}),
		],
		"interactables": [
			{"id": "receive", "pos": Vector2(-32, -2), "label": "Receive the Godbridle", "duration": 3.0},
		],
		"objectives": [
			{"id": "receive", "text": "Receive the Godbridle on the high bank", "type": "interact", "who": "receive"},
			{"id": "road", "text": "Carry the Godbridle to the Cairnspine road", "type": "reach", "who": "hero", "zone": "cairnspine_road", "hidden": true},
			{"id": "hadrik", "text": "Optional: drive off Lord Hadrik of Westmarch", "type": "defeat", "who": ["hadrik"], "hidden": true, "optional": true},
		],
		"events": [
			{"if": {"time": 0.1}, "do": [["raise", "flood"]]},
			{"if": {"time": 1.0}, "do": [
				["say", "bryn", "The release has already run, and the old riverbed is full. Cross on the lock top. King Halden waits on the high bank with the War Marshal and the Tide Speaker."],
				["say", "sova", "Witnesses on every side. Good. That is what this needs."],
			]},
			{"if": {"done": "receive"}, "do": [
				["objective", "road"], ["objective", "hadrik"],
				["say", "mara", "I promised water I had no right to give. I won't give a second order to fix the first. Take it, Listener. Keep it from all of us."],
				["say", "sova", "Into my keeping, not my ownership. The Cairnspine has done enough with this already."],
				["say", "raska", "The Basin witnesses it."],
				["say", "ilyra", "So does the coast."],
				["spawn", "hadrik"], ["spawn", "west_levy"], ["spawn", "west_riders"], ["spawn", "west_bows"],
				["say", "hadrik", "Halden gives away what the Marches paid for? Westmarch will take it back on the road."],
				["defect", "halden"],
				["say", "mara", "Shields, cover the Listener. Whatever else I've done, this I will see through."],
			]},
			{"if": {"dead": "hadrik"}, "do": [["say", "hadrik", "Fall back… This isn't over at the vault."]]},
			{"if": {"done": "road"}, "do": [
				["say", "sova", "The road home. Every valley will hear how this came to us."],
				["victory", "The Godbridle is in the First Listener's keeping."],
			]},
		],
	}


static func _sova_3() -> Dictionary:
	return {
		"id": "sova_vault_return",
		"title": "The Vault Closes",
		"year": "Year Five",
		"briefing": "Sova needed the valleys’ consent to guard the road to the vault. He won enough Keepers by reading the full record of Druid responsibility into the terms of custody, so that no First Listener can seal it away again. Now carry the Godbridle up the Cairnspine road while rival claimants make their last attempt, and close it in the vault before Orc, Elven and Human witnesses.",
		"debrief": "The Godbridle went back into the vault without a new command. Orc, Elven and Human witnesses attested that the First Listener closed it without claiming the right to use it.\n\nThe rival crowns lost their last chance at a quick seizure, and the Still Kingdom’s court recalled its remaining forces rather than send them alone against the Keepers. Orrun was still carrying out Mara’s order. The Basin had its river but not its sea, and the harbor at Moonwash stayed raised. That was the end of the war over the bridle, not of what it had done.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(0, 72), "facing": Vector2(0, -1)},
		"hero_level": 17,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 18, 15, Vector2(-6, 76), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}}),
			_p("callers", &"stonecallers", ALLY, 12, 15, Vector2(6, 78), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "follow"}}),
			_p("valley", &"cairn_wardens", ALLY, 16, 14, Vector2(0, 82), {"name": "Valley Guard", "persist": "valley", "order": {"kind": "follow"}}),
			_p("witness_orcs", &"well_keeper", NEUTRAL, 6, 8, Vector2(-8, -36), {"name": "Orc witnesses", "commandable": false}),
			_p("witness_elves", &"pilots", NEUTRAL, 6, 8, Vector2(8, -36), {"name": "Elven witnesses", "commandable": false}),
			_p("witness_humans", &"villagers", NEUTRAL, 6, 8, Vector2(0, -32), {"name": "Human witnesses", "commandable": false}),
			_p("switch_levy", &"march_levy", FOE, 18, 15, Vector2(-22, 22), {"name": "Claimant Levy", "aggro": 16.0}),
			_p("east_riders", &"march_riders", FOE, 14, 15, Vector2(66, 4), {"name": "Claimant Riders", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("road_bows", &"march_bows", FOE, 12, 15, Vector2(6, -8), {"name": "Claimant Bowmen", "aggro": 20.0}),
			_hero("hadrik", &"hadrik", FOE, 17, Vector2(-58, 4), {"name": "Lord Hadrik of Westmarch", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("hadrik_guard", &"march_levy", FOE, 18, 16, Vector2(-62, 8), {"name": "Westmarch Guard", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
		],
		"interactables": [
			{"id": "close", "pos": Vector2(0, -64), "label": "Close the Godbridle in the vault", "duration": 5.0, "hidden": true},
		],
		"objectives": [
			{"id": "gate", "text": "Carry the Godbridle to the vault door", "type": "reach", "who": "hero", "zone": "vault_gate"},
			{"id": "close", "text": "Close the vault before the witnesses", "type": "interact", "who": "close", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "bryn", "The valleys consented, First Listener. Not all of them gladly."],
				["say", "sova", "Gladly was never the price. The record is public now. That was the price."],
			]},
			{"if": {"zone": ["hero", "switchback"]}, "do": [
				["spawn", "east_riders"],
				["say", "bryn", "Riders on the east track! The crowns are making their last try."],
			]},
			{"if": {"zone": ["hero", "upper_road"]}, "do": [
				["spawn", "hadrik"], ["spawn", "hadrik_guard"],
				["say", "hadrik", "Westmarch paid for that water, Druid. Give me the bridle and the crowns will make you rich."],
				["say", "sova", "The crowns already made me a witness. That is enough."],
			]},
			{"if": {"done": "gate"}, "do": [
				["reveal", "close"], ["objective", "close"],
				["say", "sova", "Witnesses. Watch what I do, and watch what I do not do."],
			]},
			{"if": {"done": "close"}, "delay": 1.0, "do": [
				["say", "sova", "Closed. No new command. The old one is still running, and every people here knows whose it was."],
				["victory", "The Godbridle is back in the vault."],
			]},
		],
	}


# ====================================================================== ILYRA
# Elves · Years Two–Four · docs/campaigns/elves.md


static func _ilyra_1() -> Dictionary:
	return {
		"id": "ilyra_moonwash_rescue",
		"title": "Hulls on Stone",
		"year": "Year Two",
		"briefing": "Masts pitch as old walls rise beneath moored ships. Ilyra recognizes the corner of her childhood street beneath a stranded hull. One port signals that the pledged ships should pursue the artifact while the Marches are distracted. Ilyra keeps them in harbor. Rig lines at the forward and aft transfer points, in either order, and bring both stranded crews across to the receiving deck.",
		"debrief": "The fleet saved its crews. From a copy of Sova’s public account, Ilyra learned why the old coast had drowned. Her memories told her where to look. What she had seen at the harbor told her to count the people living there now.",
		"debrief_flags": {
			"cargo_loaded": "Recovered cargo keeps a few boats supplied for the coming survey.",
			"!cargo_loaded": "With the cargo left on the quay, the boats will borrow stores from the fishing villages.",
		},
		"map": Maps.moonwash(),
		"hero": {"pos": Vector2(-38, 0), "facing": Vector2(1, 0)},
		"hero_level": 5,
		"platoons": [
			_p("marines", &"wavecutters", ALLY, 18, 3, Vector2(-30, 4), {"name": "Moonwash Marines", "persist": "marines", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("archers", &"tide_archers", ALLY, 12, 3, Vector2(-42, -4), {"name": "Shipboard Archers", "persist": "archers", "order": {"kind": "hold"}, "facing": Vector2(1, 0)}),
			_p("crew_forward", &"pilots", ALLY, 8, 3, Vector2(-38, -27), {"name": "Forward crew", "commandable": false, "order": {"kind": "hold"}}),
			_p("crew_aft", &"pilots", ALLY, 8, 3, Vector2(-38, 29), {"name": "Aft crew", "commandable": false, "order": {"kind": "hold"}}),
			_p("salvage_north", &"salvagers", FOE, 14, 3, Vector2(-24, -54), {"name": "Salvage Crew", "order": {"kind": "assault", "to": Vector2(-24, -40)}}),
			_p("salvage_south", &"salvagers", FOE, 14, 3, Vector2(-24, 54), {"name": "Salvage Crew", "hidden": true, "order": {"kind": "assault", "to": Vector2(-24, 40)}}),
			_p("salvage_more", &"salvagers", FOE, 14, 4, Vector2(2, -46), {"name": "Salvage Crew", "hidden": true, "order": {"kind": "assault", "to": "forward"}}),
			_p("detachment", &"marcher_infantry", NEUTRAL, 16, 10, Vector2(-14, 2), {"name": "Human detachment", "commandable": false, "order": {"kind": "path", "points": [Vector2(-8, 0), Vector2(10, -2), Vector2(26, -4), Vector2(58, -4)]}}),
		],
		"interactables": [
			{"id": "rig_forward", "pos": Vector2(-33, -21), "label": "Rig the forward line", "duration": 3.0},
			{"id": "rig_aft", "pos": Vector2(-33, 23), "label": "Rig the aft line", "duration": 3.0},
			{"id": "cargo_north", "pos": Vector2(-24, -40), "label": "Load the cargo bundle", "duration": 2.5},
			{"id": "cargo_south", "pos": Vector2(-24, 40), "label": "Load the cargo bundle", "duration": 2.5},
		],
		"objectives": [
			{"id": "rig_forward", "text": "Rig a line at the forward transfer point", "type": "interact", "who": "rig_forward"},
			{"id": "rig_aft", "text": "Rig a line at the aft transfer point", "type": "interact", "who": "rig_aft"},
			{"id": "forward", "text": "Bring the forward crew to the receiving deck", "type": "reach", "who": "crew_forward", "zone": "deck"},
			{"id": "aft", "text": "Bring the aft crew to the receiving deck", "type": "reach", "who": "crew_aft", "zone": "deck"},
			{"id": "crews", "text": "Both crews must survive", "type": "protect", "who": ["crew_forward", "crew_aft"], "fail_text": "A stranded crew was lost before it reached the deck."},
			{"id": "cargo", "text": "Optional: load cargo bundles", "type": "interact", "who": ["cargo_north", "cargo_south"], "optional": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "captain", "Tide Speaker, the Marches are distracted. Send the pledged ships after the artifact!"],
				["say", "ilyra", "The ships stay. Their crews are on that stone. Rig the lines."],
				["say", "pilot", "Forward and aft transfer points, Speaker. You'll have to rig each one yourself."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "Shipboard archers cover the moorings but can't see past the risen wall. Put marines on the landward approach."]]},
			{"if": {"interact": "rig_forward"}, "do": [
				["order", "crew_forward", {"kind": "path", "points": [Vector2(-38, -14), Vector2(-42, -2)], "pause_zone": "deck"}],
				["say", "pilot", "Forward line is fast! They're coming across."],
			]},
			{"if": {"interact": "rig_aft"}, "do": [
				["order", "crew_aft", {"kind": "path", "points": [Vector2(-38, 14), Vector2(-42, 2)], "pause_zone": "deck"}],
				["say", "pilot", "Aft line holding. Bring them in."],
			]},
			{"if": {"time": 35.0}, "do": [["spawn", "salvage_south"], ["say", "pilot", "Salvagers on the south quay, after the cargo."]]},
			{"if": {"time": 80.0}, "do": [["spawn", "salvage_more"], ["say", "ilyra", "More of them over the wall. Keep them off the crews."]]},
			{"if": {"done": "forward"}, "do": [["despawn", "crew_forward"]]},
			{"if": {"done": "aft"}, "do": [["despawn", "crew_aft"]]},
			{"if": {"interact": "cargo_north"}, "do": [["flag", "cargo_loaded"]]},
			{"if": {"interact": "cargo_south"}, "do": [["flag", "cargo_loaded"]]},
			{"if": {"done": ["forward", "aft"]}, "do": [
				["say", "ilyra", "Every crew aboard. Mark where the old wall came up. I knew that corner."],
				["victory", "Both stranded crews reached the receiving deck."],
			]},
		],
	}


static func _ilyra_2() -> Dictionary:
	return {
		"id": "ilyra_coast_survey",
		"title": "Two Shorelines",
		"year": "Year Three",
		"briefing": "The ports want a chart that proves the old coast can be raised. Ilyra insists it mark both the drowned streets and the working harbors that would lose their water. Take readings at the ancestral stone and the fishing inlet, then relay both to the survey cutter from a signal point while it is in view. One port has sent armed crews to seize the chart.",
		"debrief": "Ilyra circulated the complete chart, drowned streets and living harbors on the same sheet, instead of a map that left out the working villages.\n\nThe ports still expected her to use the fleet to claim the Godbridle when a chance came. The pilots had seen her put their testimony on the record, and they volunteered to guide the shallow-draft boats up the new channel to Spanwater.",
		"map": Maps.coast_survey(),
		"hero": {"pos": Vector2(-8, 18), "facing": Vector2(0, -1)},
		"hero_level": 10,
		"structures": [
			{"id": "cutter", "kind": &"cutter", "team": ALLY, "name": "Survey cutter", "pos": Vector2(-60, -40), "moving": true, "speed": 3.2,
				"escort_radius": 0.0, "stop_when_threatened": false, "loop": true, "waits": {1: 16.0, 2: 16.0},
				"path": [Vector2(-60, -40), Vector2(-24, -38), Vector2(36, -38), Vector2(62, -42), Vector2(62, -47), Vector2(-62, -47)]},
		],
		"platoons": [
			_p("marines", &"wavecutters", ALLY, 18, 8, Vector2(-14, 22), {"name": "Moonwash Marines", "persist": "marines", "order": {"kind": "follow"}}),
			_p("archers", &"tide_archers", ALLY, 12, 8, Vector2(-2, 24), {"name": "Shipboard Archers", "persist": "archers", "order": {"kind": "follow"}}),
			_p("pilots", &"pilots", NEUTRAL, 8, 6, Vector2(2, 38), {"name": "Pilot village", "commandable": false}),
			_p("crews_one", &"port_crews", FOE, 16, 8, Vector2(-46, -26), {"name": "Port Crews", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
			_p("crews_archers", &"tide_archers", FOE, 10, 8, Vector2(-50, -24), {"name": "Port Archers", "hidden": true, "order": {"kind": "move", "to": Vector2(-30, -20)}, "aggro": 18.0}),
			_p("crews_two", &"port_crews", FOE, 16, 9, Vector2(56, -22), {"name": "Port Crews", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
		],
		"interactables": [
			{"id": "reading_stone", "pos": Vector2(-44, 12), "label": "Take a reading at the ancestral stone", "duration": 3.0},
			{"id": "reading_inlet", "pos": Vector2(33, 10), "label": "Take a reading at the fishing inlet", "duration": 3.0},
			{"id": "signal_beach", "pos": Vector2(-24, -22), "label": "Signal the cutter", "duration": 6.0, "hidden": true, "reset": true,
				"requires": {"structure": "cutter", "at": "beach_stop", "radius": 9.0}},
			{"id": "signal_headland", "pos": Vector2(30, -22), "label": "Signal the cutter", "duration": 6.0, "hidden": true, "reset": true,
				"requires": {"structure": "cutter", "at": "headland_stop", "radius": 9.0}},
		],
		"objectives": [
			{"id": "readings", "text": "Take readings at the ancestral stone and the fishing inlet", "type": "interact", "who": ["reading_stone", "reading_inlet"]},
			{"id": "signal", "text": "Signal both readings to the cutter while it is in view", "type": "manual", "hidden": true},
			{"id": "cutter", "text": "The survey cutter must stay afloat", "type": "protect", "who": ["cutter"], "fail_text": "The survey cutter was disabled."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "pilot", "The ports want the drowned streets. Put our soundings on the same chart and we'll help you, Speaker."],
				["say", "ilyra", "Both shorelines, on one sheet. That is the only chart I will sign."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "The headland blocks signals. The cutter pauses off the beach and off the headland on each pass."]]},
			{"if": {"time": 30.0}, "do": [
				["spawn", "crews_one"], ["spawn", "crews_archers"],
				["say", "captain", "That chart belongs to the ports' delegation, Speaker. Hand it over."],
			]},
			{"if": {"time": 75.0}, "do": [["spawn", "crews_two"], ["say", "pilot", "Another boat landing past the headland!"]]},
			{"if": {"done": "readings"}, "do": [
				["reveal", "signal_beach"], ["reveal", "signal_headland"], ["objective", "signal"],
				["say", "ilyra", "Both readings. Now the cutter has to see them."],
			]},
			{"if": {"any": [{"interact": "signal_beach"}, {"interact": "signal_headland"}]}, "do": [
				["complete", "signal"],
				["say", "pilot", "Acknowledged from the cutter! Both readings!"],
				["victory", "The survey carries both shorelines."],
			]},
		],
	}


static func _ilyra_3() -> Dictionary:
	return {
		"id": "ilyra_spanwater_evacuation",
		"title": "Last Boat at Spanwater",
		"year": "Year Four",
		"briefing": "Households caught on the low bank can reach the river landing but cannot cross the fighting on the causeway. Raska is moving to open the spillway into the old Basin riverbed. Two launches can use the landing, one at a time. Bring each household group down when a launch is docked, and get both loaded launches through the boat exit. The far group must cross the low crossing before the release floods it.",
		"debrief": "Ilyra carried the households out. Once the launches were clear, the ports that had ordered a pursuit withdrew their pledges.\n\nA departing captain asked who would take their place in the fleet. Ilyra asked him to take one family farther downriver before he went. An Elven witness stayed behind at Spanwater, and saw King Mara hand the Godbridle to the First Listener.",
		"map": Maps.spanwater(),
		"hero": {"pos": Vector2(18, 34), "facing": Vector2(-1, 0)},
		"hero_level": 15,
		"structures": [
			{"id": "launch_a", "kind": &"launch", "team": ALLY, "name": "First launch", "pos": Vector2(68, 58), "speed": 3.0,
				"escort_radius": 0.0, "stop_when_threatened": false, "moving": true, "path": [Vector2(52, 52), Vector2(32, 48)]},
			{"id": "launch_b", "kind": &"launch", "team": ALLY, "name": "Second launch", "pos": Vector2(69, 62), "speed": 3.0,
				"escort_radius": 0.0, "stop_when_threatened": false, "moving": false, "path": [Vector2(52, 54), Vector2(32, 48)]},
		],
		"platoons": [
			_p("marines", &"wavecutters", ALLY, 18, 13, Vector2(14, 28), {"name": "Moonwash Marines", "persist": "marines", "order": {"kind": "follow"}}),
			_p("archers", &"tide_archers", ALLY, 12, 13, Vector2(26, 30), {"name": "Shipboard Archers", "persist": "archers", "order": {"kind": "hold"}}),
			_p("harbor_guard", &"wavecutters", ALLY, 16, 12, Vector2(-26, 38), {"name": "Harbor Guard", "persist": "harbor_guard", "order": {"kind": "hold"}}),
			_p("near", &"households", ALLY, 10, 4, Vector2(12, 32), {"name": "Near households", "commandable": false, "order": {"kind": "hold"}}),
			_p("far", &"households", ALLY, 10, 4, Vector2(-34, 42), {"name": "Far households", "commandable": false, "order": {"kind": "hold"}}),
			_p("raiders_south", &"march_levy", FOE, 16, 13, Vector2(20, 64), {"name": "March Stragglers", "hidden": true, "order": {"kind": "assault", "to": "landing"}}),
			_p("raiders_west", &"march_levy", FOE, 16, 13, Vector2(-46, 62), {"name": "March Stragglers", "hidden": true, "order": {"kind": "attack", "target": "far"}}),
			_p("raiders_apron", &"march_riders", FOE, 12, 14, Vector2(30, -10), {"name": "March Riders", "hidden": true, "order": {"kind": "assault", "to": "landing"}}),
			_hero("raska", &"raska", NEUTRAL, 15, Vector2(-8, -22), {"name": "Raska Vennor", "commandable": false}),
		],
		"objectives": [
			{"id": "near", "text": "Embark the near households", "type": "manual"},
			{"id": "far", "text": "Embark the far households", "type": "manual"},
			{"id": "a_safe", "text": "First launch through the boat exit", "type": "reach", "who": "launch_a", "zone": "boat_exit", "hidden": true},
			{"id": "b_safe", "text": "Second launch through the boat exit", "type": "reach", "who": "launch_b", "zone": "boat_exit", "hidden": true},
			{"id": "people", "text": "The households and launches must survive", "type": "protect", "who": ["near", "far", "launch_a", "launch_b"], "fail_text": "A household group or a loaded launch was lost."},
			{"id": "boarding", "text": "Boarding closes", "type": "hold", "seconds": 240.0},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "pilot", "Two launches coming up the channel. Only one fits the landing at a time."],
				["say", "captain", "Speaker, the ports signal: break off and pursue the convoy."],
				["say", "ilyra", "The launches stay until every household is clear. Tell them that."],
			]},
			{"if": {"time": 4.0}, "do": [
				["order", "near", {"kind": "path", "points": [Vector2(18, 34), Vector2(24, 38)]}],
				["order", "far", {"kind": "path", "points": [Vector2(-22, 32), Vector2(-9, 22), Vector2(8, 30), Vector2(22, 38)], "wait_for_hero": 16.0}],
				["say", "narrator", "The far households move only while Ilyra is with them. The low crossing floods when the release begins."],
			]},
			{"if": {"zone": ["launch_a", "dock"]}, "do": [["flag", "a_docked"], ["say", "pilot", "First launch at the landing!"]]},
			{"if": {"all": [{"flag": "a_docked"}, {"zone": ["near", "landing"]}, {"no_flag": "a_loaded"}]}, "do": [
				["despawn", "near"], ["complete", "near"], ["flag", "a_loaded"], ["flag", "near_aboard"],
				["route", "launch_a", [Vector2(52, 52), Vector2(66, 56)]], ["objective", "a_safe"],
			]},
			{"if": {"all": [{"flag": "a_docked"}, {"zone": ["far", "landing"]}, {"no_flag": "a_loaded"}]}, "do": [
				["despawn", "far"], ["complete", "far"], ["flag", "a_loaded"], ["flag", "far_aboard"],
				["route", "launch_a", [Vector2(52, 52), Vector2(66, 56)]], ["objective", "a_safe"],
			]},
			{"if": {"flag": "a_loaded"}, "delay": 9.0, "do": [
				["move_structure", "launch_b", true],
				["say", "pilot", "Second launch coming in."],
			]},
			{"if": {"all": [{"flag": "a_loaded"}, {"zone": ["launch_b", "dock"]}]}, "do": [["flag", "b_docked"]]},
			{"if": {"all": [{"flag": "b_docked"}, {"zone": ["near", "landing"]}, {"no_flag": "near_aboard"}]}, "do": [
				["despawn", "near"], ["complete", "near"], ["flag", "near_aboard"],
				["route", "launch_b", [Vector2(52, 54), Vector2(66, 56)]], ["objective", "b_safe"],
			]},
			{"if": {"all": [{"flag": "b_docked"}, {"zone": ["far", "landing"]}, {"no_flag": "far_aboard"}]}, "do": [
				["despawn", "far"], ["complete", "far"], ["flag", "far_aboard"],
				["route", "launch_b", [Vector2(52, 54), Vector2(66, 56)]], ["objective", "b_safe"],
			]},
			{"if": {"time": 30.0}, "do": [["spawn", "raiders_west"], ["say", "pilot", "Stragglers on the far bank, near the households!"]]},
			{"if": {"time": 70.0}, "do": [["say", "narrator", "The spillway is opening. The low crossing floods in twenty seconds."]]},
			{"if": {"time": 90.0}, "do": [
				["raise", "flood"], ["spawn", "raiders_south"],
				["say", "raska", "(far off) Spillway only! Keep the sea gate shut!"],
				["say", "pilot", "The river's in the old bed. Launches will have to hold for the current on the way out."],
			]},
			{"if": {"time": 130.0}, "do": [["spawn", "raiders_apron"]]},
			{"if": {"time": 200.0}, "do": [["say", "pilot", "The landing steps are going under. Last boat soon, Speaker!"]]},
			{"if": {"all": [{"done": "boarding"}, {"any": [{"no_flag": "near_aboard"}, {"no_flag": "far_aboard"}]}]}, "do": [
				["defeat", "Boarding closed with households still ashore."],
			]},
			{"if": {"done": ["a_safe", "b_safe"]}, "do": [
				["say", "ilyra", "Both launches clear. Now the ports can withdraw, if they still want to."],
				["victory", "Every household got out by water."],
			]},
		],
	}


# ====================================================================== NERIS
# Dryads · Years Three–Five · docs/campaigns/dryads.md


static func _neris_1() -> Dictionary:
	return {
		"id": "neris_feeder_channel",
		"title": "The Grove That Refused",
		"year": "Year Three",
		"briefing": "The new cut has starved the oldest isolated Dryad grove of water. Neris could bring the Deepwood’s roots to it, but the grove withholds assent: the shortest crossing would run under the wells of Alderford, the town that sheltered it. The town has made another offer: room for a nursery, if the grove helps keep the old feeder channel open. A March levy has dammed that channel upstream for its own fields. Open the three sluices, then keep them open until water reaches the grove.",
		"debrief": "Water reached the grove by the old channel, not by a root crossing. The grove’s people had been ready to risk transplanting their trees rather than break their promise to the town. Neris had come to save them on her terms; they had their own.\n\nShe agreed to the town’s nursery and to the work of keeping the channel clear. She went on seeking custody of the Godbridle, in case other groves had no town to bargain with.",
		"map": Maps.grove_town(),
		"hero": {"pos": Vector2(0, -8), "facing": Vector2(0, -1)},
		"hero_level": 5,
		"structures": [
			{"id": "grove", "kind": &"heart_tree", "team": ALLY, "pos": Vector2(0, 2), "name": "The grove's oldest tree"},
		],
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 16, 3, Vector2(-6, -12), {"name": "Grove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 10, 3, Vector2(6, -12), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("diggers", &"villagers", ALLY, 10, 3, Vector2(10, 10), {"name": "Alderford Diggers", "commandable": false, "order": {"kind": "hold"}}),
			_p("dam_crew", &"march_levy", FOE, 16, 3, Vector2(-14, -56), {"name": "Dam Crew", "aggro": 14.0}),
			_p("west_crew", &"march_levy", FOE, 12, 3, Vector2(-48, -26), {"name": "Ditch Guard", "aggro": 12.0}),
			_p("counter", &"march_levy", FOE, 16, 4, Vector2(52, -6), {"name": "March Levy", "hidden": true, "order": {"kind": "assault", "to": "town_sluice"}}),
			_p("counter_bows", &"march_bows", FOE, 10, 4, Vector2(4, -56), {"name": "March Bowmen", "hidden": true, "order": {"kind": "assault", "to": "grove"}}),
		],
		"interactables": [
			{"id": "sluice_dam", "pos": Vector2(-12, -48), "label": "Open the upper sluice", "duration": 3.0},
			{"id": "sluice_west", "pos": Vector2(-42, -30), "label": "Open the west channel", "duration": 3.0},
			{"id": "sluice_town", "pos": Vector2(-22, -6), "label": "Open the town sluice", "duration": 3.0},
		],
		"objectives": [
			{"id": "sluices", "text": "Open the three sluices on the old feeder channel", "type": "interact", "who": ["sluice_dam", "sluice_west", "sluice_town"]},
			{"id": "flow", "text": "Keep the channel open until water reaches the grove", "type": "hold", "seconds": 60.0, "hidden": true},
			{"id": "keep", "text": "The grove and the diggers must survive", "type": "protect", "who": ["grove", "diggers"], "fail_text": "The grove or the town's diggers were lost."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "Let me bring the Deepwood to you. One season and your roots drink again."],
				["say", "grove", "No. The shortest way runs under the town's wells."],
				["say", "reeve", "We have another offer, Rootspeaker. Room for a nursery. Help us keep the old channel open, and the grove drinks from it."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "Hold L2 (or Tab) to command. Open each sluice by holding Cross (or E) beside it."]]},
			{"if": {"done": "sluices"}, "do": [
				["objective", "flow"], ["spawn", "counter"], ["spawn", "counter_bows"],
				["say", "reeve", "Water in the channel! And their levy coming back to shut it."],
			]},
			{"if": {"done": "flow"}, "do": [
				["say", "grove", "We drink. We keep our word."],
				["say", "neris", "And I keep mine. A nursery, then, and the channel kept clear."],
				["victory", "The old feeder channel runs to the grove."],
			]},
		],
	}


static func _neris_2() -> Dictionary:
	return {
		"id": "neris_spanwater_feeder",
		"title": "The Feeder Branch",
		"year": "Year Four",
		"briefing": "At Spanwater Lock, the War Marshal is about to open the spillway into the old Basin riverbed. The surge could choke Alderford’s feeder branch with debris, and March defenders want its headgate shut so more water stays in their own channel. Keep the headgate standing, clear the feeder when the surge comes, and hold it open through the release.",
		"debrief": "The feeder carried water to Alderford all through the release. Raska set the flow, the Tide Speaker’s launches carried households out by water, and the Dryads kept their part of the bargain without claiming any of the rest.\n\nOn the high bank, King Mara handed the Godbridle to the First Listener. Neris watched it go and felt relief, and was surprised by it.",
		"map": Maps.spanwater(),
		"hero": {"pos": Vector2(-46, -18), "facing": Vector2(1, 0)},
		"hero_level": 11,
		"structures": [
			{"id": "headgate", "kind": &"headgate", "team": ALLY, "pos": Vector2(-22, -30), "name": "Feeder headgate"},
		],
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 9, Vector2(-40, -20), {"name": "Grove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 9, Vector2(-50, -20), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("volunteers", &"thornkin", ALLY, 14, 8, Vector2(-26, -24), {"name": "Alderford Volunteers", "persist": "volunteers", "order": {"kind": "hold"}}),
			_p("gate_crew", &"march_levy", FOE, 16, 9, Vector2(-4, -16), {"name": "Headgate Crew", "order": {"kind": "assault", "to": "headgate"}}),
			_p("bows", &"march_bows", FOE, 12, 9, Vector2(10, -14), {"name": "Lock Bowmen", "aggro": 18.0}),
			_p("wave_two", &"march_levy", FOE, 16, 10, Vector2(-30, 40), {"name": "March Defenders", "hidden": true, "order": {"kind": "assault", "to": "headgate"}}),
			_p("wave_three", &"march_riders", FOE, 12, 10, Vector2(20, -14), {"name": "March Riders", "hidden": true, "order": {"kind": "assault", "to": "headgate"}}),
			_hero("raska", &"raska", NEUTRAL, 15, Vector2(-8, -22), {"name": "Raska Vennor", "commandable": false}),
			_p("orcs", &"basin_warriors", NEUTRAL, 16, 12, Vector2(2, -20), {"name": "Saltwell Company", "commandable": false}),
		],
		"interactables": [
			{"id": "debris_1", "pos": Vector2(-34, -28), "label": "Clear the debris", "duration": 2.5, "hidden": true},
			{"id": "debris_2", "pos": Vector2(-48, -28), "label": "Clear the debris", "duration": 2.5, "hidden": true},
			{"id": "debris_3", "pos": Vector2(-62, -28), "label": "Clear the debris", "duration": 2.5, "hidden": true},
		],
		"objectives": [
			{"id": "gate", "text": "Keep the feeder headgate standing", "type": "protect", "who": ["headgate"], "fail_text": "The headgate was smashed shut. Alderford lost its water."},
			{"id": "release", "text": "Hold the feeder open through the release", "type": "hold", "zone": "headgate", "contest": true, "seconds": 120.0, "overrun_time": 14.0, "fail_text": "March defenders shut the feeder headgate."},
			{"id": "debris", "text": "Clear the debris from the feeder", "type": "interact", "who": ["debris_1", "debris_2", "debris_3"], "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "The War Marshal sets the flow. We only need the feeder to carry its share."],
				["say", "reeve", "Their crew is going for the headgate, Rootspeaker."],
			]},
			{"if": {"time": 40.0}, "do": [
				["raise", "flood"], ["reveal", "debris_1"], ["reveal", "debris_2"], ["reveal", "debris_3"], ["objective", "debris"],
				["say", "raska", "(from the wheel) Spillway open. River only."],
				["say", "neris", "The surge is carrying half the riverbank into our channel. Clear it!"],
			]},
			{"if": {"time": 55.0}, "do": [["spawn", "wave_two"], ["say", "reeve", "Defenders from the south, cut off by the flood and angry about it."]]},
			{"if": {"time": 85.0}, "do": [["spawn", "wave_three"]]},
			{"if": {"done": ["release", "debris"]}, "do": [
				["say", "reeve", "Water all the way to Alderford."],
				["say", "neris", "Then we did what we came to do, and nothing more."],
				["victory", "Alderford's feeder ran through the release."],
			]},
		],
	}


static func _neris_3() -> Dictionary:
	return {
		"id": "neris_vault_road",
		"title": "The Road Kept Open",
		"year": "Year Five",
		"briefing": "The Dryad groves have refused a continent-wide crossing; no grove will be bound by a command spoken on its behalf. Neris has brought local volunteers to the Cairnspine road instead. Refugees and witnesses are climbing to the vault as rival claimants close in. Keep them moving and bring them to the witness camp.",
		"debrief": "The witnesses reached the vault and saw the First Listener close it without a command. The refugees found room in the Keepers’ valleys for the winter.\n\nNearby groves had chosen to work together, root to root where they agreed and no farther, and each kept the right to refuse a crossing. Nothing had been spoken over their heads. The far groves would have to be saved slowly, by seed envoys and neighbors.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(0, 70), "facing": Vector2(0, -1)},
		"hero_level": 17,
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 15, Vector2(-6, 72), {"name": "Grove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 15, Vector2(8, 74), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("volunteers", &"thornkin", ALLY, 16, 14, Vector2(0, 80), {"name": "Alderford Volunteers", "persist": "volunteers", "order": {"kind": "follow"}}),
			_p("refugees", &"households", ALLY, 12, 8, Vector2(-4, 78), {"name": "Refugees", "commandable": false, "order": {"kind": "hold"}}),
			_p("witnesses", &"well_keeper", ALLY, 8, 8, Vector2(4, 80), {"name": "Witnesses", "commandable": false, "order": {"kind": "hold"}}),
			_p("west_levy", &"march_levy", FOE, 18, 15, Vector2(-58, 6), {"name": "Claimant Levy", "hidden": true, "order": {"kind": "attack", "target": "refugees"}}),
			_p("east_riders", &"march_riders", FOE, 14, 15, Vector2(66, 4), {"name": "Claimant Riders", "hidden": true, "order": {"kind": "attack", "target": "witnesses"}}),
			_p("road_block", &"march_levy", FOE, 16, 15, Vector2(-16, 6), {"name": "Claimant Roadblock", "aggro": 15.0}),
			_p("road_bows", &"march_bows", FOE, 12, 15, Vector2(-26, 32), {"name": "Claimant Bowmen", "aggro": 20.0}),
			_p("late_levy", &"march_levy", FOE, 16, 16, Vector2(60, -58), {"name": "Claimant Levy", "hidden": true, "order": {"kind": "attack", "target": "witnesses"}}),
		],
		"objectives": [
			{"id": "refugees", "text": "Bring the refugees to the witness camp", "type": "reach", "who": "refugees", "zone": "witness_camp"},
			{"id": "witnesses", "text": "Bring the witnesses to the witness camp", "type": "reach", "who": "witnesses", "zone": "witness_camp"},
			{"id": "safe", "text": "The refugees and witnesses must survive", "type": "protect", "who": ["refugees", "witnesses"], "fail_text": "Claimants cut down the people on the road."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "The groves said no to the great crossing. So we walk, like everyone else."],
				["say", "reeve", "Alderford came because the grove's people asked. Point us where you need us."],
			]},
			{"if": {"time": 3.0}, "do": [
				["order", "refugees", {"kind": "path", "points": [Vector2(-6, 50), Vector2(-22, 30), Vector2(-14, 6), Vector2(0, -20), Vector2(-2, -36)], "wait_for_hero": 18.0}],
				["order", "witnesses", {"kind": "path", "points": [Vector2(-4, 52), Vector2(-20, 32), Vector2(-12, 8), Vector2(2, -20), Vector2(2, -36)], "wait_for_hero": 18.0}],
			]},
			{"if": {"zone": ["refugees", "switchback"]}, "do": [
				["spawn", "west_levy"], ["spawn", "east_riders"],
				["say", "reeve", "Claimants on both flanks! They're going for the witnesses, not the soldiers."],
			]},
			{"if": {"zone": ["witnesses", "upper_road"]}, "do": [["spawn", "late_levy"], ["say", "neris", "One more push from the northeast track. Keep walking."]]},
			{"if": {"done": "refugees"}, "do": [["despawn", "refugees"]]},
			{"if": {"done": "witnesses"}, "do": [["despawn", "witnesses"]]},
			{"if": {"done": ["refugees", "witnesses"]}, "do": [
				["say", "neris", "Everyone who walked is here. That is how groves should cross, too."],
				["victory", "The road to the vault stayed open."],
			]},
		],
	}


# ===================================================================== SERETH
# Undead · Years Three–Five · docs/campaigns/undead.md


static func _sereth_1() -> Dictionary:
	return {
		"id": "sereth_voices_cut",
		"title": "Voices from the Cut",
		"year": "Year Three",
		"briefing": "The diverted river has cut a new channel along the Still Kingdom’s border. Where the bank at Hollowmere falls away from its oldest graves, the village has begun to hear voices address the living by name. Salvagers from across the border have come for what the water uncovered. Record the names at the three grave sites before the bank collapses, then bring the villagers back from its edge.",
		"debrief": "No one at Hollowmere could say whether the voices were the dead themselves or their memories passing through Orrun’s dream. Sereth wrote down every name they spoke, and wrote beside each one that a voice is a reason to listen, not permission to bring anyone back.\n\nThe court did not wait for him to finish. It sent the High Executor to secure the Godbridle before another command could silence the voices, and left the question of consent for a later ruling.",
		"map": Maps.cut_village(),
		"hero": {"pos": Vector2(0, 8), "facing": Vector2(0, -1)},
		"hero_level": 5,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 3, Vector2(-6, 4), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 3, Vector2(6, 4), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_p("villagers", &"villagers", ALLY, 10, 4, Vector2(-6, -28), {"name": "Listening villagers", "commandable": false, "order": {"kind": "hold"}}),
			_p("salvage_east", &"salvagers", FOE, 14, 3, Vector2(50, 18), {"name": "Bone Salvagers", "order": {"kind": "assault", "to": "grave_east"}}),
			_p("salvage_west", &"salvagers", FOE, 14, 3, Vector2(-50, -18), {"name": "Bone Salvagers", "hidden": true, "order": {"kind": "assault", "to": "grave_west"}}),
			_p("salvage_late", &"salvagers", FOE, 16, 4, Vector2(50, 22), {"name": "Bone Salvagers", "hidden": true, "order": {"kind": "attack", "target": "villagers"}}),
		],
		"interactables": [
			{"id": "names_west", "pos": Vector2(-24, -32), "label": "Record the names", "duration": 3.5},
			{"id": "names_mid", "pos": Vector2(-6, -34), "label": "Record the names", "duration": 3.5},
			{"id": "names_east", "pos": Vector2(14, -32), "label": "Record the names", "duration": 3.5},
		],
		"objectives": [
			{"id": "names", "text": "Record the names at the three grave sites", "type": "interact", "who": ["names_west", "names_mid", "names_east"]},
			{"id": "back", "text": "Bring the villagers back to Hollowmere", "type": "reach", "who": "villagers", "zone": "village", "hidden": true},
			{"id": "villagers", "text": "The villagers must survive", "type": "protect", "who": ["villagers"], "fail_text": "The listening villagers were lost at the bank."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "They stand at the bank all night, High Executor. The voices call them by name."],
				["say", "sereth", "Then we listen too. Carefully. A voice is not a request."],
			]},
			{"if": {"time": 6.0}, "do": [["say", "narrator", "Hold L2 (or Tab) to command. The bank gives way after each site is recorded; watch for the warning."]]},
			{"if": {"time": 30.0}, "do": [["spawn", "salvage_west"], ["say", "aurel", "More salvagers on the west track."]]},
			{"if": {"interact": "names_west"}, "do": [
				["hazard", "grave_west", 4.0, 10.0, 0.08],
				["say", "voice", "Odile. Odile, you left the gate open."],
				["say", "sereth", "Written. The bank is going. Step back."],
			]},
			{"if": {"interact": "names_mid"}, "do": [
				["hazard", "grave_mid", 4.0, 10.0, 0.08],
				["say", "voice", "Is anyone keeping the lamps?"],
			]},
			{"if": {"interact": "names_east"}, "do": [
				["hazard", "grave_east", 4.0, 10.0, 0.08],
				["say", "aurel", "That voice asked for its brother by name, Executor. He's standing right here."],
				["say", "sereth", "And we still do not know whether it wants anything more than to be heard."],
			]},
			{"if": {"done": "names"}, "do": [
				["objective", "back"], ["spawn", "salvage_late"],
				["order", "villagers", {"kind": "path", "points": [Vector2(-6, -14), Vector2(-2, 8)], "wait_for_hero": 14.0}],
				["say", "sereth", "Come away from the edge. We have the names. They are not lost."],
			]},
			{"if": {"done": "back"}, "do": [
				["say", "aurel", "A rider from the court. You're to secure the Godbridle before anyone silences the voices."],
				["say", "sereth", "And the question of whether anyone may be brought back?"],
				["say", "aurel", "Deferred, Executor."],
				["victory", "The names at Hollowmere were recorded."],
			]},
		],
	}


static func _sereth_2() -> Dictionary:
	return {
		"id": "sereth_recovered_records",
		"title": "The Recovered Records",
		"year": "Year Four",
		"briefing": "The cut at Hollowmere is widening. The village record house, with its burial rolls, letters and testimony going back three centuries, will be underwater by nightfall, and a rival crown’s requisition company has come to commandeer the village’s boats. Recover the record chests, then escort the bearers to the high ground.",
		"debrief": "The records came out of Hollowmere wet but whole. Sereth did not read them. There was no time, and part of him was afraid of what he might find.\n\nWord came from Spanwater that King Mara had handed the Godbridle to the First Listener. The court sent new orders: the High Executor would escort the court’s speaker to the vault, to speak there for the dead.",
		"map": Maps.cut_village(),
		"hero": {"pos": Vector2(0, 40), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 9, Vector2(-6, 42), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 9, Vector2(6, 42), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_p("pallbearers", &"ossuary_guard", ALLY, 16, 8, Vector2(0, 46), {"name": "Pallbearers", "persist": "pallbearers", "order": {"kind": "follow"}}),
			_p("bearers", &"villagers", ALLY, 10, 5, Vector2(12, 34), {"name": "Record bearers", "commandable": false, "order": {"kind": "hold"}}),
			_p("requisition", &"march_levy", FOE, 18, 9, Vector2(48, 20), {"name": "Requisition Company", "order": {"kind": "assault", "to": "village"}}),
			_p("req_bows", &"march_bows", FOE, 12, 9, Vector2(46, 28), {"name": "Requisition Bowmen", "order": {"kind": "move", "to": Vector2(30, 24)}, "aggro": 18.0}),
			_p("req_two", &"march_levy", FOE, 18, 10, Vector2(-52, -16), {"name": "Requisition Company", "hidden": true, "order": {"kind": "attack", "target": "bearers"}}),
			_p("req_riders", &"march_riders", FOE, 12, 10, Vector2(50, 18), {"name": "Requisition Riders", "hidden": true, "order": {"kind": "attack", "target": "bearers"}}),
		],
		"interactables": [
			{"id": "chest_archive", "pos": Vector2(6, 31), "label": "Recover the record chest", "duration": 3.0},
			{"id": "chest_west", "pos": Vector2(-16, -2), "label": "Recover the record chest", "duration": 3.0},
			{"id": "chest_east", "pos": Vector2(16, -2), "label": "Recover the record chest", "duration": 3.0},
		],
		"objectives": [
			{"id": "chests", "text": "Recover the three record chests", "type": "interact", "who": ["chest_archive", "chest_west", "chest_east"]},
			{"id": "high", "text": "Escort the record bearers to the high ground", "type": "reach", "who": "bearers", "zone": "high_ground", "hidden": true},
			{"id": "bearers", "text": "The record bearers must survive", "type": "protect", "who": ["bearers"], "fail_text": "The record bearers were cut down and the records lost."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "Three chests. Burial rolls, letters, testimony. Three hundred years of Hollowmere."],
				["say", "sereth", "Then three hundred years leave with us. Bearers, stay by the record house."],
			]},
			{"if": {"time": 40.0}, "do": [
				["raise", "widened_cut"],
				["say", "aurel", "The bank gave way. The cut is into the lower lanes!"],
			]},
			{"if": {"time": 55.0}, "do": [["spawn", "req_two"], ["say", "aurel", "A second company on the west track. They want the boats, and they'll take the chests to pay for them."]]},
			{"if": {"done": "chests"}, "do": [
				["objective", "high"], ["spawn", "req_riders"],
				["order", "bearers", {"kind": "path", "points": [Vector2(-10, 32), Vector2(-28, 34), Vector2(-40, 38)], "wait_for_hero": 15.0}],
				["say", "sereth", "That is all of it. Up to the high ground."],
			]},
			{"if": {"done": "high"}, "do": [
				["say", "aurel", "Orders from the court. You are to escort Speaker Pyre to the vault."],
				["say", "sereth", "To speak for the dead. Which dead, Aurel? And who asked them?"],
				["victory", "Hollowmere's records were saved."],
			]},
		],
	}


static func _sereth_3() -> Dictionary:
	return {
		"id": "sereth_vault_witnesses",
		"title": "A Lamp in the Window",
		"year": "Year Five",
		"briefing": "Among Hollowmere’s recovered records, Sereth found his sister’s letter. She asked him to leave a lamp in the window after she died. She said nothing about coming back. Sereth has refused to escort the court’s speaker to the vault. Now the court’s guard is on the Cairnspine road, and it means to speak for the unconsenting dead. Protect the witnesses on their way to the camp, and turn back Speaker Aldous Pyre.",
		"debrief": "Speaker Pyre turned back at the vault court. The witnesses reached the camp and saw the First Listener close the vault without a new command.\n\nThe court stripped Sereth of his commission. He went home to the Still Kingdom as a private citizen and lit a lamp in his window. There would be no universal recall of the dead. The question of consent still stood, the way he had written it.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(6, 60), "facing": Vector2(0, -1)},
		"hero_level": 17,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 15, Vector2(0, 64), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 15, Vector2(10, 66), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_p("pallbearers", &"ossuary_guard", ALLY, 16, 14, Vector2(-6, 66), {"name": "Pallbearers", "persist": "pallbearers", "order": {"kind": "follow"}}),
			_p("witnesses", &"villagers", ALLY, 10, 8, Vector2(2, 74), {"name": "Hollowmere witnesses", "commandable": false, "order": {"kind": "hold"}}),
			_hero("pyre", &"pyre", FOE, 17, Vector2(62, -58), {"name": "Speaker Aldous Pyre", "order": {"kind": "assault", "to": "vault_court"}}),
			_p("court_guard", &"court_guard", FOE, 18, 15, Vector2(64, -54), {"name": "Court Guard", "order": {"kind": "assault", "to": "vault_court"}}),
			_p("court_casters", &"vigil_casters", FOE, 12, 15, Vector2(66, -62), {"name": "Court Casters", "order": {"kind": "assault", "to": "vault_court"}}),
			_p("court_intercept", &"court_guard", FOE, 16, 15, Vector2(64, 6), {"name": "Court Guard", "hidden": true, "order": {"kind": "attack", "target": "witnesses"}}),
			_p("court_late", &"court_guard", FOE, 16, 16, Vector2(62, -58), {"name": "Court Guard", "hidden": true, "order": {"kind": "assault", "to": "vault_court"}}),
		],
		"objectives": [
			{"id": "witnesses", "text": "Bring the Hollowmere witnesses to the witness camp", "type": "reach", "who": "witnesses", "zone": "witness_camp"},
			{"id": "safe", "text": "The witnesses must survive", "type": "protect", "who": ["witnesses"], "fail_text": "The court's guard cut down the witnesses."},
			{"id": "pyre", "text": "Turn back Speaker Aldous Pyre", "type": "defeat", "who": ["pyre"]},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "You are commanded to escort the Speaker, High Executor."],
				["say", "sereth", "I helped write the rule that a person must consent to return. My sister's letter asks for a lamp, not a summons. I will not escort him."],
				["say", "aurel", "Then I am to tell you the court will take your commission."],
				["say", "sereth", "Tell them. And then help me with these witnesses."],
			]},
			{"if": {"time": 3.0}, "do": [
				["order", "witnesses", {"kind": "path", "points": [Vector2(-6, 50), Vector2(-22, 30), Vector2(-14, 6), Vector2(0, -20), Vector2(0, -36)], "wait_for_hero": 18.0}],
			]},
			{"if": {"time": 45.0}, "do": [
				["spawn", "court_intercept"],
				["say", "pyre", "The dead have waited long enough for a hearing, Vale. The court will give them one."],
			]},
			{"if": {"zone": ["witnesses", "upper_road"]}, "do": [["spawn", "court_late"]]},
			{"if": {"done": "witnesses"}, "do": [["despawn", "witnesses"]]},
			{"if": {"dead": "pyre"}, "do": [
				["say", "pyre", "Enough. I will not fight the Keepers alone. The court will hear of this."],
				["despawn", "court_guard"], ["despawn", "court_casters"], ["despawn", "court_late"],
			]},
			{"if": {"done": ["witnesses", "pyre"]}, "do": [
				["say", "sereth", "No one spoke for the dead today. Not even me."],
				["victory", "The court turned back from the vault."],
			]},
		],
	}
