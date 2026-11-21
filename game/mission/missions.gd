extends RefCounted
## The eighteen campaign missions of the five-year war.
##
## Mara, Raska and Ilyra follow their specifications in docs/campaigns. Sova, Neris and
## Sereth follow their windows in docs/war-timeline.md and the specifications written
## alongside these missions. Shared battlefields keep one layout; only starts, orders and
## objectives differ by campaign.

const Aggro := preload("res://game/combat/enemy_aggro.gd")
const Units := preload("res://game/mission/mission_units.gd")
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


## Scales map geometry and scripted distances. Combat aggro is a fixed world radius.
static func _scale(value: Variant, k: float, key: String = "") -> Variant:
	if key == "facing":
		return value
	if key == "radius" and (value is float or value is int):
		return value * sqrt(k)
	if key == "aggro" and (value is float or value is int):
		return Aggro.configured(float(value))
	if (key == "wait_for_hero" or key == "pause_if_threatened") and (value is float or value is int):
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
	# Preserve authored frontage unless the author supplied explicit columns.
	# Large regular platoons gain ranks without widening a narrow route.
	if not entry.has("columns") and Units.platoon_count(type,count)!=count:
		entry["columns"]=clampi(ceili(sqrt(count*1.4)),1,8)
	entry["count"]=Units.platoon_count(type,int(entry.get("count",count)))
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
		"id": "sova_mine_tunnels",
		"title": "The Workers' Way Out",
		"year": "Year One",
		"briefing": "Sova’s survey puts the new spring on the same night as the river’s disappearance. Mara’s escort is moving on the pass; fighting it would leave the workers where both armies can reach them. Fellow Druids hold the tunnel mouth. Check the outlet, then release the two work groups from tunnel cover, one at a time or together, and send them to Druid safety down the western trail.",
		"debrief": "Mara’s carrier reached the road with the Godbridle. Sova’s workers came out through the tunnels, and the miner who had volunteered walked to the Orc rally on her own terms once she had seen the others safe. A copy of her testimony travelled home with Sova’s survey.\n\nHearing what one unrecorded request for water had done, Sova decided he must read the older, deliberate command in public, including the names his predecessors had withheld.",
		"map": Maps.greyhollow(),
		"hero": {"pos": Vector2(-44, 32), "facing": Vector2(1, 0)},
		"hero_level": 5,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 16, 3, Vector2(-38, 40), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("callers", &"stonecallers", ALLY, 10, 3, Vector2(-46, 40), {"name": "Survey Volunteers", "persist": "callers", "order": {"kind": "follow"}, "facing": Vector2(1, 0)}),
			_p("group_one", &"miners", ALLY, 10, 2, Vector2(-50, 24), {"name": "First work group", "order": {"kind": "hold"}}),
			_p("group_two", &"miners", ALLY, 10, 2, Vector2(-51, 16), {"name": "Second work group", "order": {"kind": "hold"}}),
			_hero("marit", &"witness", NEUTRAL, 4, Vector2(-46, 26), {"name": "Marit Holm", "commandable": false}),
			_p("detachment", &"marcher_infantry", FOE, 16, 3, Vector2(-2, -4), {"name": "Halden Rear Detachment", "hidden": true, "order": {"kind": "assault", "to": "outlet_approach"}}),
			_p("detachment_two", &"marcher_infantry", FOE, 14, 4, Vector2(4, 4), {"name": "Halden Rear Detachment", "hidden": true, "order": {"kind": "assault", "to": "outlet_approach"}}),
			_hero("raska", &"raska", NEUTRAL, 6, Vector2(30, 46), {"name": "Raska Vennor", "hidden": true, "commandable": false}),
		],
		"objectives": [
			{"id": "group_one", "text": "Send the first work group to Druid safety", "type": "reach", "who": "group_one", "zone": "druid_trail"},
			{"id": "group_two", "text": "Send the second work group to Druid safety", "type": "reach", "who": "group_two", "zone": "druid_trail"},
			{"id": "safe", "text": "Both work groups must survive", "type": "protect", "who": ["group_one", "group_two"], "fail_text": "A work group was cut down before it reached safety."},
			{"id": "approach", "text": "Keep the outlet approach open", "type": "hold", "zone": "outlet_approach", "contest": true, "seconds": INF, "overrun_time": 15.0, "fail_text": "The Halden rear detachment held the outlet approach until the last escape window closed."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "bryn", "Both groups are in tunnel cover, First Listener. The first is at the mouth; the second waits at the bend, screened from the ridge."],
				["say", "sova", "Then we release them in stages. Nothing moves until we know the approach is clear."],
			]},
			{"if": {"time": 22.0}, "do": [
				["spawn", "detachment"],
				["say", "bryn", "Halden rear detachment coming down from the pass. They want the outlet approach."],
			]},
			{"if": {"time": 90.0}, "do": [
				["spawn", "detachment_two"],
				["say", "narrator", "Final escape window: a second detachment is committing to the outlet approach."],
			]},
			{"if": {"done": "group_one"}, "do": [["despawn", "group_one"], ["say", "sova", "The first group is on the trail."]]},
			{"if": {"done": "group_two"}, "do": [["despawn", "group_two"]]},
			{"if": {"done": ["group_one", "group_two"]}, "do": [
				["complete", "approach"], ["spawn", "raska"],
				["say", "marit", "They're safe. I'll go to the Orc rally now. I said I would."],
				["say", "sova", "On your own terms. We will not stop you."],
				["victory", "The workers got out through the tunnels."],
			]},
		],
	}


static func _sova_2() -> Dictionary:
	return {
		"id": "sova_public_record",
		"title": "Let Them Walk Out",
		"year": "Year Two",
		"briefing": "After the reports from Moonwash, Sova brings the sealed record to the valley assembly to read the command that raised the Cairnspine, who gave it, and what it cost the coast and the Basin. Several Keepers will leave rather than hear it. Armed spoilers want to stop the reading and take the record. Choose a lectern, then read all three passages with a scribe present. Hold the perimeter outside the ring, and keep the public exit open: walking out is not an attack.",
		"debrief": "Sova finished the reading. Several Keepers left anyway. A scribe made copies for Ilyra and the other peoples, and no single Keeper could put the record back under seal.\n\nA guard asked whether to stop the departing Keepers. Sova let them pass: consent to fight for the vault could not come from people held at spearpoint.\n\nIn Year Four, after the breach at Spanwater, Mara handed the Godbridle to Sova in sight of Orc and Elven witnesses. The seal was opened only to verify what changed hands. In Year Five, enough Keepers pledged guards for the vault road once Sova read the full account into the terms of custody. Rival crowns and the Still Kingdom had not accepted those terms.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(0, 72), "facing": Vector2(0, -1)},
		"hero_level": 9,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 16, 7, Vector2(-8, 50), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "hold"}}),
			_p("callers", &"stonecallers", ALLY, 10, 7, Vector2(10, 52), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "hold"}}),
			_p("valley", &"cairn_wardens", ALLY, 14, 7, Vector2(0, 34), {"name": "Valley Guard", "persist": "valley", "order": {"kind": "hold"}}),
			_p("scribes", &"households", ALLY, 6, 12, Vector2(4, 76), {"name": "Public scribes", "commandable": false, "order": {"kind": "hold"}}),
			_p("keepers", &"cairn_wardens", NEUTRAL, 10, 6, Vector2(-6, 62), {"name": "Departing Keepers", "commandable": false, "order": {"kind": "hold"}}),
			_p("spoilers_shelf", &"dissenting_wardens", FOE, 12, 7, Vector2(0, 26), {"name": "Armed Spoilers", "hidden": true, "order": {"kind": "assault", "to": "ring"}}),
			_p("spoilers_east", &"dissenting_wardens", FOE, 12, 7, Vector2(64, 40), {"name": "Armed Spoilers", "hidden": true, "order": {"kind": "assault", "to": "ring"}}),
			_p("spoilers_exit", &"dissenting_wardens", FOE, 14, 8, Vector2(-64, 50), {"name": "Armed Spoilers", "hidden": true, "order": {"kind": "assault", "to": "public_exit"}}),
			_p("spoilers_last", &"dissenting_wardens", FOE, 16, 8, Vector2(62, 44), {"name": "Armed Spoilers", "hidden": true, "order": {"kind": "assault", "to": "ring"}}),
		],
		"interactables": [
			{"id": "choose_dais", "pos": Vector2(-14, 58), "label": "Read from the open dais", "duration": 1.5},
			{"id": "choose_recess", "pos": Vector2(18, 70), "label": "Read from the recessed lectern", "duration": 1.5},
			{"id": "dais_1", "pos": Vector2(-14, 58), "label": "Read the first passage", "duration": 18.0, "hidden": true, "clear_zone": "ring"},
			{"id": "dais_2", "pos": Vector2(-14, 58), "label": "Read the second passage", "duration": 18.0, "hidden": true, "clear_zone": "ring"},
			{"id": "dais_3", "pos": Vector2(-14, 58), "label": "Read the third passage", "duration": 18.0, "hidden": true, "clear_zone": "ring"},
			{"id": "recess_1", "pos": Vector2(18, 70), "label": "Read the first passage", "duration": 18.0, "hidden": true, "clear_zone": "ring"},
			{"id": "recess_2", "pos": Vector2(18, 70), "label": "Read the second passage", "duration": 18.0, "hidden": true, "clear_zone": "ring"},
			{"id": "recess_3", "pos": Vector2(18, 70), "label": "Read the third passage", "duration": 18.0, "hidden": true, "clear_zone": "ring"},
		],
		"objectives": [
			{"id": "lectern", "text": "Choose a lectern for the hearing", "type": "interact", "who": ["choose_dais", "choose_recess"]},
			{"id": "passages", "text": "Read all three passages of the record", "type": "manual", "hidden": true},
			{"id": "scribes", "text": "Keep at least one public scribe present", "type": "protect", "who": ["scribes"], "fail_text": "No scribe remained to witness the reading."},
			{"id": "record", "text": "Keep the spoilers from seizing the record", "type": "hold", "zone": "ring", "contest": true, "seconds": INF, "overrun_time": 12.0, "fail_text": "Armed spoilers seized the record from the lectern."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "bryn", "The assembly is gathered. Some of them have already turned toward the exit."],
				["say", "sova", "Let them. Leaving is an answer. Choose where I read, and keep the ring clear."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "The open dais faces two approaches. The recessed lectern has cover and one approach, but sits closer to the public exit."]]},
			{"if": {"interact": "choose_dais", "no_flag": "recess"}, "do": [["flag", "dais"], ["complete", "lectern"], ["objective", "passages"], ["reveal", "dais_1"], ["hide_interact", "choose_recess"]]},
			{"if": {"interact": "choose_recess", "no_flag": "dais"}, "do": [["flag", "recess"], ["complete", "lectern"], ["objective", "passages"], ["reveal", "recess_1"], ["hide_interact", "choose_dais"]]},
			{"if": {"done": "lectern"}, "do": [
				["spawn", "spoilers_shelf"], ["spawn", "spoilers_east"], ["leave", "keepers", "west_track"],
				["say", "sova", "“In the year the mountains rose, the First Listener spoke to the sleeper…”"],
				["say", "bryn", "Keepers walking out by the public exit. And spoilers coming down the shelf."],
			]},
			{"if": {"any": [{"interact": "dais_1"}, {"interact": "recess_1"}]}, "do": [
				["spawn", "spoilers_east"],
				["say", "sova", "“…and the coast went under the sea, and the Basin lost its water…”"],
			]},
			{"if": {"interact": "dais_1"}, "do": [["reveal", "dais_2"]]},
			{"if": {"interact": "recess_1"}, "do": [["reveal", "recess_2"]]},
			{"if": {"any": [{"interact": "dais_2"}, {"interact": "recess_2"}]}, "do": [
				["spawn", "spoilers_exit"],
				["say", "bryn", "They're going for the public exit now!"],
			]},
			{"if": {"interact": "dais_2"}, "do": [["reveal", "dais_3"], ["spawn", "spoilers_last"]]},
			{"if": {"interact": "recess_2"}, "do": [["reveal", "recess_3"], ["spawn", "spoilers_last"]]},
			{"if": {"any": [{"interact": "dais_3"}, {"interact": "recess_3"}]}, "do": [
				["complete", "passages"], ["complete", "record"],
				["say", "sova", "“…and these are the names of those who gave the command.” It is read. All of it."],
				["victory", "The sealed record was read in public."],
			]},
		],
	}


static func _sova_3() -> Dictionary:
	return {
		"id": "sova_vault_return",
		"title": "No New Command",
		"year": "Year Five",
		"briefing": "The vault lies beyond the narrow shelf. A side path rejoins the shelf route at the vault forecourt, and the witness terrace has its own entry. Carry the Godbridle from the valley assembly to the forecourt, clear the approach, and return it to the vault. Neither Sova nor his guards may speak a command into it. A hostile unit in the closure zone pauses the return.",
		"debrief": "Sova returned the Godbridle without speaking a command. From the separate terrace, Orc, Elven and Human witnesses attested to what happened. The Godbridle was out of the war; Orrun was still carrying out Mara’s order.\n\nSova’s last order was that the vault’s record stay where any valley could read it, even when the people reading it had reason to blame him.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(0, 74), "facing": Vector2(0, -1)},
		"hero_level": 17,
		"platoons": [
			_p("wardens", &"cairn_wardens", ALLY, 18, 15, Vector2(-6, 70), {"name": "Cairn Wardens", "persist": "wardens", "order": {"kind": "follow"}}),
			_p("callers", &"stonecallers", ALLY, 12, 15, Vector2(8, 72), {"name": "Stonecallers", "persist": "callers", "order": {"kind": "follow"}}),
			_p("valley", &"cairn_wardens", ALLY, 16, 14, Vector2(4, 80), {"name": "Valley Guard", "persist": "valley", "order": {"kind": "hold"}}),
			_p("witnesses", &"villagers", NEUTRAL, 8, 8, Vector2(-50, -58), {"name": "Witnesses on the terrace", "commandable": false}),
			_p("shelf_company", &"march_levy", FOE, 16, 15, Vector2(0, -14), {"name": "Claimant Company", "aggro": 14.0}),
			_p("forecourt_guard", &"march_levy", FOE, 14, 15, Vector2(6, -52), {"name": "Claimant Pickets", "aggro": 14.0}),
			_p("side_bows", &"march_bows", FOE, 12, 15, Vector2(37, -20), {"name": "Claimant Bowmen", "aggro": 18.0}),
			_p("reserve", &"march_riders", FOE, 14, 16, Vector2(66, 40), {"name": "Claimant Reserve", "hidden": true, "order": {"kind": "assault", "to": "forecourt"}}),
		],
		"interactables": [
			{"id": "close", "pos": Vector2(0, -70), "label": "Return the Godbridle to the vault", "duration": 6.0, "hidden": true, "clear_zone": "closure"},
		],
		"objectives": [
			{"id": "forecourt", "text": "Carry the Godbridle to the vault forecourt", "type": "reach", "who": "hero", "zone": "forecourt"},
			{"id": "close", "text": "Return it to the vault without a command", "type": "interact", "who": "close", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "bryn", "The shelf is short, but there's no room to reform on it. The side path is longer and rejoins at the forecourt."],
				["say", "sova", "Then one of us holds the shelf, and one of us goes around. I carry it either way."],
			]},
			{"if": {"any": [{"zone": ["hero", "shelf"]}, {"zone": ["hero", "side_path"]}, {"time": 60.0}]}, "do": [
				["spawn", "reserve"],
				["say", "bryn", "A mounted reserve is turning toward the forecourt from the east track."],
			]},
			{"if": {"done": "forecourt"}, "do": [
				["reveal", "close"], ["objective", "close"],
				["say", "sova", "Clear the closure zone. Nothing else is asked of us."],
			]},
			{"if": {"done": "close"}, "delay": 1.0, "do": [
				["say", "sova", "Returned. No new command. Let the witnesses write down exactly that."],
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
		"id": "neris_failing_grove",
		"title": "What We Planted Here",
		"year": "Year Three",
		"briefing": "The river’s new cut has left the oldest isolated grove dry. The town offers a watered nursery plot if the grove helps keep the old feeder open. The grove withholds assent for a root crossing under the town’s wells, and asks Neris to help with its first transplant instead. Speak with the envoy, call the crew from shelter, keep the loading yard clear while they secure the tree, then escort the sled along the raised road to the nursery.",
		"debrief": "The nursery had room to start a transplant, not to move the whole grove at once. The volunteers would come back for the remaining trees; the old planting place stayed dry.\n\nNeris honored the refusal and committed crews to the feeder. She still sought custody of the Godbridle as insurance for other groves. The town’s offer was not permission for a new crossing.",
		"map": Maps.grove_nursery(),
		"hero": {"pos": Vector2(-36, -12), "facing": Vector2(1, 0)},
		"hero_level": 5,
		"structures": [
			{"id": "sled", "kind": &"cart", "team": ALLY, "name": "Root sled", "pos": Vector2(-38, -2), "speed": 1.4, "escort_radius": 0.0,
				"path": [Vector2(-20, -8), Vector2(20, -10), Vector2(46, -4)]},
		],
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 16, 3, Vector2(-30, -8), {"name": "Grove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 10, 3, Vector2(-30, 4), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("crew", &"villagers", ALLY, 8, 3, Vector2(-36, 12), {"name": "Volunteer crew", "hidden": true, "commandable": false, "order": {"kind": "hold"}}),
			_p("foragers_road", &"salvagers", FOE, 14, 3, Vector2(35, -44), {"name": "Armed Foragers", "hidden": true, "order": {"kind": "assault", "to": "road"}}),
			_p("foragers_track", &"salvagers", FOE, 14, 3, Vector2(10, 46), {"name": "Armed Foragers", "hidden": true, "order": {"kind": "assault", "to": "yard"}}),
			_p("foragers_late", &"salvagers", FOE, 14, 4, Vector2(-39, -45), {"name": "Armed Foragers", "hidden": true, "order": {"kind": "attack", "target": "hero"}}),
		],
		"interactables": [
			{"id": "envoy", "pos": Vector2(-40, -6), "label": "Speak with the grove's envoy", "duration": 2.0},
			{"id": "call", "pos": Vector2(-36, 12), "label": "Call the crew from shelter", "duration": 2.0, "hidden": true},
			{"id": "settle", "pos": Vector2(46, -2), "label": "Help settle the root ball", "duration": 4.0, "hidden": true},
		],
		"objectives": [
			{"id": "envoy", "text": "Speak with the grove's envoy", "type": "interact", "who": "envoy"},
			{"id": "call", "text": "Call the volunteer crew out from shelter", "type": "interact", "who": "call", "hidden": true},
			{"id": "load", "text": "Keep the loading yard clear while the crew secures the tree", "type": "hold", "zone": "yard", "contest": true, "seconds": 40.0, "overrun_time": INF, "hidden": true},
			{"id": "nursery", "text": "Bring the root sled to the nursery", "type": "reach", "who": "sled", "zone": "nursery", "hidden": true},
			{"id": "settle", "text": "Help the crew settle the root ball", "type": "interact", "who": "settle", "hidden": true},
			{"id": "sled", "text": "The root sled must survive", "type": "protect", "who": ["sled"], "fail_text": "The root sled was destroyed before the transplant."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "I can bring the Deepwood's roots here in a season."],
				["say", "grove", "Not under their wells. Help us with the first tree instead."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "Hold one platoon on the raised road and screen the sunken track with the other."]]},
			{"if": {"done": "envoy"}, "do": [["reveal", "call"], ["objective", "call"]]},
			{"if": {"done": "call"}, "do": [
				["spawn", "crew"], ["order", "crew", {"kind": "move", "to": "yard"}], ["objective", "load"],
				["spawn", "foragers_track"],
				["say", "reeve", "Foragers on the sunken track, after the yard's water."],
			]},
			{"if": {"after": ["call", 20.0]}, "do": [["spawn", "foragers_road"], ["say", "neris", "More on the road. Move the road screen before the sled goes."]]},
			{"if": {"done": "load"}, "do": [
				["objective", "nursery"], ["move_structure", "sled", true], ["order", "crew", {"kind": "follow"}],
				["say", "reeve", "The loading cloth is off. The tree's on the sled. It stops if anyone gets near it."],
			]},
			{"if": {"after": ["load", 25.0]}, "do": [["spawn", "foragers_late"]]},
			{"if": {"done": "nursery"}, "do": [["reveal", "settle"], ["objective", "settle"]]},
			{"if": {"done": "settle"}, "delay": 1.0, "do": [
				["say", "grove", "Upright. In wet soil."],
				["say", "neris", "One tree. The rest when you are ready, and not before."],
				["victory", "The first tree stands in the nursery."],
			]},
		],
	}


static func _neris_2() -> Dictionary:
	return {
		"id": "neris_spanwater_feeder",
		"title": "Water at the Town Gauge",
		"year": "Year Four",
		"briefing": "Raska will open the spillway to the old Basin riverbed and keep the sea gate shut. The first rush can bury the town feeder in silt. Clear the inlet rack, protect the town workers while they fit the guide boards, and keep the maintenance lane open through the release until the town gauge reaches its mark.",
		"debrief": "Neris stayed with the feeder instead of sending her platoons after the Godbridle. The volunteers handed the working gauge over to the town, which kept its wells and the nursery.\n\nOn the high bank Mara handed the Godbridle to Sova. It did not come into Neris’s keeping, and she did not ask for it.",
		"map": Maps.spanwater(),
		"hero": {"pos": Vector2(-50, -20), "facing": Vector2(1, 0)},
		"hero_level": 11,
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 9, Vector2(-44, -20), {"name": "Grove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 9, Vector2(-54, -16), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("workers", &"villagers", ALLY, 8, 6, Vector2(-30, -26), {"name": "Town workers", "commandable": false, "order": {"kind": "hold"}}),
			_p("march_a", &"march_levy", FOE, 16, 9, Vector2(6, -16), {"name": "March Defenders", "hidden": true, "order": {"kind": "assault", "to": "headgate"}}),
			_p("march_b", &"march_levy", FOE, 16, 10, Vector2(-36, 40), {"name": "March Defenders", "hidden": true, "order": {"kind": "attack", "target": "workers"}}),
			_p("march_c", &"march_riders", FOE, 12, 10, Vector2(20, -14), {"name": "March Riders", "hidden": true, "order": {"kind": "assault", "to": "headgate"}}),
			_hero("raska", &"raska", NEUTRAL, 15, Vector2(-8, -22), {"name": "Raska Vennor", "commandable": false}),
			_p("orcs", &"basin_warriors", NEUTRAL, 14, 12, Vector2(2, -20), {"name": "Saltwell Company", "commandable": false}),
		],
		"interactables": [
			{"id": "rack", "pos": Vector2(-24, -28), "label": "Clear the inlet rack", "duration": 3.0},
			{"id": "rack_again", "pos": Vector2(-24, -28), "label": "Clear the fresh blockage", "duration": 3.0, "hidden": true},
		],
		"objectives": [
			{"id": "rack", "text": "Clear the feeder's inlet rack", "type": "interact", "who": "rack"},
			{"id": "boards", "text": "Protect the workers fitting the guide boards", "type": "hold", "zone": "headgate", "contest": true, "seconds": 45.0, "overrun_time": INF, "hidden": true},
			{"id": "workers", "text": "The town workers must survive", "type": "protect", "who": ["workers"], "fail_text": "The town workers were lost on the feeder."},
			{"id": "jam", "text": "Clear the fresh blockage at the rack", "type": "interact", "who": "rack_again", "hidden": true},
			{"id": "gauge", "text": "Keep the feeder flowing until the town gauge reaches its mark", "type": "hold", "seconds": 60.0, "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "The nursery needs water through the feeder after the release, not just water in the main channel."],
				["say", "reeve", "Clear the rack and we'll set the boards. Raska won't wait for us."],
			]},
			{"if": {"done": "rack"}, "do": [
				["objective", "boards"], ["spawn", "march_a"],
				["say", "reeve", "Boards going in. March troops on the apron, coming our way."],
			]},
			{"if": {"time": 70.0}, "do": [["say", "narrator", "Raska's release begins in fifteen seconds. The low crossing will flood."]]},
			{"if": {"time": 85.0}, "do": [
				["raise", "flood"], ["reveal", "rack_again"], ["objective", "jam"], ["spawn", "march_b"],
				["say", "raska", "(from the wheel) Spillway open. River only."],
				["say", "neris", "The rush is piling debris on the rack. Clear it before the crest!"],
			]},
			{"if": {"time": 110.0}, "do": [["spawn", "march_c"]]},
			{"if": {"done": ["boards", "jam"]}, "do": [
				["objective", "gauge"],
				["say", "reeve", "Boards set, rack clear. Watch the gauge."],
			]},
			{"if": {"time": 150.0, "any": [{"not_done": "boards"}, {"not_done": "jam"}]}, "do": [
				["defeat", "The crest buried the feeder before the boards were set and the rack was clear."],
			]},
			{"if": {"time": 135.0}, "do": [["say", "narrator", "The crest reaches the feeder in fifteen seconds."]]},
			{"if": {"done": "gauge"}, "do": [
				["say", "reeve", "The gauge is at the mark. Water at the town end."],
				["say", "neris", "Then the nursery drinks. That was the whole of our job."],
				["victory", "Water reached the town gauge."],
			]},
		],
	}


static func _neris_3() -> Dictionary:
	return {
		"id": "neris_cairnspine_passage",
		"title": "A Road We Can Share",
		"year": "Year Five",
		"briefing": "The groves have refused a continent-wide crossing. Nearby groves have sent volunteers instead, to keep people moving while Sova takes the bridle to the vault. Clear and hold the route to the witness terrace. Meet the guide at staging to bring the refugees forward, then signal the second guide to bring the witnesses. Groups stop at the last safe point if the route ahead is threatened.",
		"debrief": "Both groups reached the terrace, and the witnesses went on to attest the closure. The last volunteers had been committed to the witnesses, not to a bid for the artifact.\n\nThe guides decided which refugees they could take back with them. The nursery still needed tending. No root crossing was declared, no grove was bound by another grove’s answer, and Neris gave no command to Orrun.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(-6, 76), "facing": Vector2(0, -1)},
		"hero_level": 17,
		"platoons": [
			_p("thornkin", &"thornkin", ALLY, 18, 15, Vector2(-10, 70), {"name": "Grove Kin", "persist": "thornkin", "order": {"kind": "follow"}}),
			_p("spores", &"sporecasters", ALLY, 12, 15, Vector2(6, 72), {"name": "Sporecasters", "persist": "spores", "order": {"kind": "follow"}}),
			_p("volunteers", &"thornkin", ALLY, 16, 14, Vector2(0, 60), {"name": "Grove Volunteers", "persist": "volunteers", "order": {"kind": "hold"}}),
			_p("refugees", &"households", ALLY, 10, 14, Vector2(-4, 82), {"name": "Refugees", "commandable": false, "order": {"kind": "hold"}}),
			_p("witnesses", &"well_keeper", ALLY, 8, 14, Vector2(6, 84), {"name": "Witnesses", "commandable": false, "order": {"kind": "hold"}}),
			_p("rival_shelf", &"march_levy", FOE, 16, 15, Vector2(0, -20), {"name": "Rival Company", "hidden": true, "order": {"kind": "assault", "to": "shelf"}}),
			_p("rival_side", &"march_levy", FOE, 14, 15, Vector2(40, -36), {"name": "Rival Detachment", "hidden": true, "order": {"kind": "assault", "to": "rejoin"}}),
			_p("rival_bows", &"march_bows", FOE, 10, 15, Vector2(12, -58), {"name": "Rival Bowmen", "aggro": 14.0}),
			_p("rival_late", &"march_riders", FOE, 12, 15, Vector2(66, 40), {"name": "Rival Riders", "hidden": true, "order": {"kind": "assault", "to": "rejoin"}}),
		],
		"interactables": [
			{"id": "guide", "pos": Vector2(-2, 80), "label": "Meet the local guide", "duration": 2.0},
			{"id": "signal", "pos": Vector2(0, 4), "label": "Signal the second guide", "duration": 2.0, "hidden": true},
		],
		"objectives": [
			{"id": "guide", "text": "Meet the local guide at staging", "type": "interact", "who": "guide"},
			{"id": "refugees", "text": "Bring the refugees safely to the terrace", "type": "reach", "who": "refugees", "zone": "terrace", "hidden": true},
			{"id": "signal", "text": "Signal the second guide from the shelf", "type": "interact", "who": "signal", "hidden": true},
			{"id": "witnesses", "text": "Bring the witnesses safely to the terrace", "type": "reach", "who": "witnesses", "zone": "terrace", "hidden": true},
			{"id": "safe", "text": "Both groups must survive", "type": "protect", "who": ["refugees", "witnesses"], "fail_text": "Rival troops cut down a group on the road."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "neris", "No crossing. Just a road, kept open long enough for people to walk it."],
				["say", "reeve", "Our guide is at the staging tents. The second waits for your signal."],
			]},
			{"if": {"done": "guide"}, "do": [
				["objective", "refugees"], ["reveal", "signal"], ["objective", "signal"],
				["order", "refugees", {"kind": "path", "points": [Vector2(-2, 40), Vector2(0, 0), Vector2(0, -42), Vector2(-24, -52), Vector2(-48, -56)], "wait_for_hero": 26.0, "pause_if_threatened": 10.0}],
				["spawn", "rival_shelf"],
				["say", "reeve", "Refugees moving. A rival company is on the shelf."],
			]},
			{"if": {"done": "signal"}, "do": [
				["order", "witnesses", {"kind": "path", "points": [Vector2(8, 40), Vector2(0, 0), Vector2(0, -42), Vector2(-24, -52), Vector2(-48, -56)], "pause_if_threatened": 10.0}],
				["objective", "witnesses"], ["spawn", "rival_side"],
				["say", "neris", "Witnesses, come up. A detachment is going for the side-path rejoin; hold it."],
			]},
			{"if": {"after": ["signal", 30.0]}, "do": [["spawn", "rival_late"]]},
			{"if": {"done": "refugees"}, "do": [["despawn", "refugees"]]},
			{"if": {"done": "witnesses"}, "do": [["despawn", "witnesses"]]},
			{"if": {"done": ["refugees", "witnesses"]}, "do": [
				["say", "neris", "Everyone who walked is on the terrace."],
				["victory", "Both groups reached the witness terrace."],
			]},
		],
	}


# ===================================================================== SERETH
# Undead · Years Three–Five · docs/campaigns/undead.md


static func _sereth_1() -> Dictionary:
	return {
		"id": "sereth_voices_at_the_cut",
		"title": "The Names at the Cut",
		"year": "Year Three",
		"briefing": "After a riverbank collapsed beside the oldest graves, villagers began hearing voices address living people by name. Hold the village while its clerk takes accounts and recovers the exposed records. Speak to Iren by the cemetery stair, then enter her account in the record room and keep the room secure while the clerk prepares the recovered bundle. The stair is a narrow hold; the road lets riders charge.",
		"debrief": "Sereth sealed the records for cataloging instead of giving the court a list of names to recall. Iren’s account was entered as hers: she heard her own name and recognized the voice. That was all it established.\n\nSereth left under commission to secure the Godbridle, before anyone had found his sister’s letter.",
		"map": Maps.cut_village(),
		"hero": {"pos": Vector2(-4, 10), "facing": Vector2(0, -1)},
		"hero_level": 5,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 3, Vector2(-6, -24), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "hold"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 3, Vector2(20, 24), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "hold"}}),
			_p("clerk", &"villagers", ALLY, 1, 4, Vector2(-14, 28), {"name": "The clerk", "commandable": false, "order": {"kind": "hold"}}),
			_p("iren", &"villagers", NEUTRAL, 1, 4, Vector2(-6, -28), {"name": "Iren", "commandable": false}),
			_p("stair_party", &"march_levy", FOE, 14, 3, Vector2(-30, -30), {"name": "March Troops", "hidden": true, "order": {"kind": "assault", "to": "stair"}}),
			_p("road_riders", &"march_riders", FOE, 12, 3, Vector2(58, 32), {"name": "March Riders", "hidden": true, "order": {"kind": "assault", "to": "record_room"}}),
			_p("road_levy", &"march_levy", FOE, 14, 4, Vector2(58, 36), {"name": "March Troops", "hidden": true, "order": {"kind": "assault", "to": "record_room"}}),
		],
		"interactables": [
			{"id": "iren", "pos": Vector2(-6, -28), "label": "Speak with Iren", "duration": 2.5},
			{"id": "account", "pos": Vector2(-13, 26), "label": "Enter Iren's account", "duration": 3.0, "hidden": true},
		],
		"objectives": [
			{"id": "iren", "text": "Speak with Iren by the cemetery stair", "type": "interact", "who": "iren"},
			{"id": "account", "text": "Enter her account in the record room", "type": "interact", "who": "account", "hidden": true},
			{"id": "bundle", "text": "Keep the record room secure while the clerk prepares the bundle", "type": "hold", "zone": "record_room", "contest": true, "seconds": 45.0, "overrun_time": 15.0, "hidden": true, "fail_text": "March troops carried the record bundle off down the road."},
			{"id": "clerk", "text": "The clerk must survive", "type": "protect", "who": ["clerk"], "fail_text": "The clerk was killed."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "The clerk is in the record room. The woman who heard her name is down by the stair."],
				["say", "sereth", "Then we take her account first, as hers. Nothing more."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "The guard holds the stair; the casters cover the road. Sereth can cross by the walled lanes."]]},
			{"if": {"time": 20.0}, "do": [["spawn", "stair_party"], ["say", "aurel", "March troops on the cemetery stair."]]},
			{"if": {"done": "iren"}, "do": [
				["reveal", "account"], ["objective", "account"],
				["say", "voice", "Iren. Iren, the gate."],
				["say", "sereth", "You heard your own name, and you knew the voice. That is what I will write. Not what it was."],
			]},
			{"if": {"done": "account"}, "do": [
				["objective", "bundle"], ["spawn", "road_riders"], ["spawn", "road_levy"],
				["say", "aurel", "Riders on the road! They want the records gone before anyone can blame their crown for the cut."],
			]},
			{"if": {"done": "bundle"}, "do": [
				["say", "aurel", "The bundle is secured. Sealed for cataloging."],
				["say", "sereth", "Good. The court can have a catalog. Not a list of names to recall."],
				["victory", "The account and the records are secure."],
			]},
		],
	}


static func _sereth_2() -> Dictionary:
	return {
		"id": "sereth_pass_writ",
		"title": "An Audience, Not a Seizure",
		"year": "Year Four",
		"briefing": "Mara has already handed the bridle to Sova. The court sends a writ requesting an audience before the vault is closed. A rival March patrol wants to stop it reaching the Keeper at the boundary post. The open road gives their mounted reserve room to charge; the sunken sheep track is covered but only foot troops can take it, and a lookout at the road bend watches for anyone leaving it. Carry the writ to the Keeper, then withdraw to the rally marker.",
		"debrief": "The Keeper accepted the writ: the court could present its claim at the valley assembly, not enter the vault or use the bridle.\n\nKeeping the court’s claim alive committed Sereth in its eyes. At the next briefing the court named its own speaker and ordered Sereth to escort that official from the assembly to the vault. The writ never granted the speaker consent from the dead.",
		"map": Maps.boundary_post(),
		"hero": {"pos": Vector2(-12, 48), "facing": Vector2(0, -1)},
		"hero_level": 11,
		"platoons": [
			_p("ossuary", &"ossuary_guard", ALLY, 18, 9, Vector2(-18, 52), {"name": "Ossuary Guard", "persist": "ossuary", "order": {"kind": "follow"}}),
			_p("casters", &"vigil_casters", ALLY, 12, 9, Vector2(-6, 54), {"name": "Vigil Casters", "persist": "casters", "order": {"kind": "follow"}}),
			_hero("keeper", &"aldric", NEUTRAL, 9, Vector2(0, -40), {"name": "The Keeper", "commandable": false}),
			_p("lookout", &"march_bows", FOE, 3, 9, Vector2(22, 6), {"name": "Lookout", "order": {"kind": "hold"}, "aggro": 8.0}),
			_p("patrol", &"march_levy", FOE, 16, 9, Vector2(14, -10), {"name": "March Patrol", "aggro": 12.0}),
			_p("reserve", &"march_riders", FOE, 14, 10, Vector2(44, 44), {"name": "Mounted Reserve", "order": {"kind": "hold"}}),
			_p("occupiers", &"march_levy", FOE, 14, 10, Vector2(40, -40), {"name": "March Patrol", "hidden": true, "order": {"kind": "assault", "to": "post"}}),
		],
		"interactables": [
			{"id": "writ", "pos": Vector2(0, -38), "label": "Hand the writ to the Keeper", "duration": 3.0},
		],
		"objectives": [
			{"id": "writ", "text": "Carry the court's writ to the Keeper at the boundary post", "type": "interact", "who": "writ"},
			{"id": "post", "text": "Don't let the patrol drive the Keeper from the post", "type": "hold", "zone": "post", "contest": true, "seconds": INF, "overrun_time": 15.0, "fail_text": "The patrol occupied the post and drove the Keeper away."},
			{"id": "rally", "text": "Withdraw to the rally marker", "type": "reach", "who": "hero", "zone": "start", "hidden": true},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "The writ asks for an audience, Executor. Not the bridle. I've read it three times."],
				["say", "sereth", "Then it gets delivered exactly as written."],
			]},
			{"if": {"time": 5.0}, "do": [["say", "narrator", "Spot the lookout from the higher bank, or draw the reserve onto the road with a visible screen."]]},
			{"if": {"any": [{"all": [{"zone": ["hero", "track_exit"]}, {"no_flag": "lookout_gone"}]}, {"zone": ["hero", "road_bend"]}, {"time": 120.0}]}, "id": "alarm", "do": [
				["order", "reserve", {"kind": "attack", "target": "hero"}],
				["say", "narrator", "A signal horn sounds at the road bend. The mounted reserve commits."],
			]},
			{"if": {"dead": "lookout"}, "do": [["flag", "lookout_gone"], ["say", "aurel", "The lookout is down. They won't see us leave the track."]]},
			{"if": {"time": 60.0}, "do": [["spawn", "occupiers"], ["say", "aurel", "Patrol moving on the post from the north."]]},
			{"if": {"done": "writ"}, "do": [
				["complete", "post"], ["objective", "rally"],
				["say", "sereth", "From the court of the Still Kingdom. An audience, before the vault is closed."],
				["say", "narrator", "The Keeper accepts the writ: a hearing at the valley assembly, nothing more."],
			]},
			{"if": {"done": "rally"}, "do": [["victory", "The writ was delivered."]]},
		],
	}


static func _sereth_3() -> Dictionary:
	return {
		"id": "sereth_no_proxy",
		"title": "The Lamp in the Window",
		"year": "Year Five",
		"briefing": "At the valley assembly a clerk brings a letter found in the cataloged village records. Sereth’s sister asks him to leave a lamp in the window after she dies. She says nothing about returning. The court’s speaker still means to ask Orrun on behalf of people who left no such permission. Refuse the escort order in front of the witnesses, screen the terrace, and challenge the speaker before he crosses the custody line.",
		"debrief": "The court stripped Sereth of his commission for refusing its order. The bridle went back into the vault without a new command.\n\nIn the coda Sereth left the lamp his sister asked for. Neither the letter nor the light suggested that she consented, refused, answered or returned.",
		"map": Maps.cairnspine_road(),
		"hero": {"pos": Vector2(4, 70), "facing": Vector2(0, -1)},
		"hero_level": 17,
		"platoons": [
			_p("household", &"ossuary_guard", ALLY, 16, 15, Vector2(-6, 72), {"name": "Household Guard", "persist": "household", "order": {"kind": "follow"}}),
			_p("court_a", &"court_guard", ALLY, 14, 15, Vector2(10, 74), {"name": "Court Troops", "commandable": false, "order": {"kind": "hold"}}),
			_p("court_b", &"vigil_casters", ALLY, 10, 15, Vector2(14, 80), {"name": "Court Casters", "commandable": false, "order": {"kind": "hold"}}),
			_hero("pyre", &"pyre", NEUTRAL, 17, Vector2(16, 76), {"name": "Speaker Aldous Pyre", "commandable": false}),
			_p("witnesses", &"villagers", NEUTRAL, 8, 8, Vector2(-10, 82), {"name": "Witnesses", "commandable": false}),
			_p("rival", &"march_levy", FOE, 16, 15, Vector2(-66, -48), {"name": "Rival Company", "hidden": true, "order": {"kind": "assault", "to": "terrace_entry"}}),
			_p("rival_two", &"march_riders", FOE, 12, 15, Vector2(40, -40), {"name": "Rival Riders", "hidden": true, "order": {"kind": "assault", "to": "terrace_entry"}}),
		],
		"interactables": [
			{"id": "refuse", "pos": Vector2(4, 66), "label": "Refuse the escort order", "duration": 2.0},
			{"id": "challenge", "pos": Vector2(16, 76), "label": "Challenge the speaker", "duration": 2.5, "hidden": true, "attach": "pyre"},
		],
		"objectives": [
			{"id": "refuse", "text": "Refuse the escort order before the witnesses", "type": "interact", "who": "refuse"},
			{"id": "stall", "text": "Stall the speaker's escort", "type": "defeat", "who": ["court_a"], "hidden": true},
			{"id": "challenge", "text": "Challenge the speaker before the custody line", "type": "interact", "who": "challenge", "hidden": true},
			{"id": "terrace", "text": "Keep the terrace approach clear for the witnesses", "type": "hold", "zone": "terrace_entry", "contest": true, "seconds": INF, "overrun_time": 15.0, "hidden": true, "fail_text": "Rival troops took the witnesses' safe position."},
		],
		"events": [
			{"if": {"time": 1.0}, "do": [
				["say", "aurel", "The clerk found this among Hollowmere's records. It's in your sister's hand."],
				["say", "sereth", "“Leave a lamp in the window when I'm gone.” That's all. Nothing about coming back."],
				["say", "pyre", "High Executor. You will escort me to the vault. The dead are owed a hearing."],
			]},
			{"if": {"done": "refuse"}, "do": [
				["say", "sereth", "No. I helped write the rule that a person must consent. I won't escort you past it."],
				["say", "pyre", "Then the court's troops come with me."],
				["say", "narrator", "The court troops leave Sereth's command. Some of them form the speaker's escort."],
				["leave", "court_b", "west_track"], ["turn", "court_a", {"kind": "guard", "who": "pyre"}],
				["turn", "pyre", {"kind": "path", "speed": 1.7, "points": [Vector2(10, 40), Vector2(37, 26), Vector2(37, -36), Vector2(12, -50), Vector2(0, -64)]}],
				["objective", "stall"], ["objective", "challenge"], ["objective", "terrace"],
				["spawn", "rival"],
				["say", "aurel", "He's taking the side path. And a rival company is moving on the terrace."],
			]},
			{"if": {"after": ["refuse", 40.0]}, "do": [["spawn", "rival_two"]]},
			{"if": {"done": "refuse", "alive_below": [["court_a"], 3]}, "do": [
				["reveal", "challenge"],
				["say", "aurel", "His escort is broken. Reach the speaker, Executor."],
			]},
			{"if": {"zone": ["pyre", "custody_line"]}, "do": [["defeat", "The speaker crossed the custody line before he was challenged."]]},
			{"if": {"done": "challenge"}, "do": [
				["say", "sereth", "You have no one's consent, Speaker. Not one letter. Turn back."],
				["say", "pyre", "…The court will hear of this, Vale."],
				["despawn", "pyre"], ["leave", "court_a", "east_track"], ["complete", "terrace"],
			]},
			{"if": {"done": "challenge"}, "delay": 2.0, "do": [
				["say", "aurel", "They'll take your commission."],
				["say", "sereth", "Let them. I have a lamp to light."],
				["victory", "The bid to speak for the dead was stopped."],
			]},
		],
	}
