extends RefCounted
## Battlefields shared by the campaign missions.
##
## Coordinates are metres on the ground plane, with negative y to the north. Several
## campaigns fight on the same field with different orders, so each map is defined once
## (see docs/war-timeline.md, "Where perspectives can overlap").


## Year One. The Human, Orc and Druid campaigns all open here.
static func greyhollow() -> Dictionary:
	return {
		"name": "Greyhollow Mine",
		"theme": "mountain",
		"size": Vector2(110, 150),
		"obstacles": [
			{"kind": "cliff", "rect": Rect2(-55, -75, 110, 5)},
			{"kind": "cliff", "rect": Rect2(-55, -30, 40, 36)},
			{"kind": "cliff", "rect": Rect2(15, -30, 40, 18)},
			{"kind": "cliff", "rect": Rect2(15, -4, 40, 10)},
			{"kind": "cliff", "rect": Rect2(-40, 12, 6, 24)},
			{"kind": "rock", "circle": Vector3(-6, -18, 2.2)},
			{"kind": "rock", "circle": Vector3(8, -2, 2.5)},
			{"kind": "rock", "circle": Vector3(20, 30, 4)},
			{"kind": "rock", "circle": Vector3(32, 52, 5)},
			{"kind": "rock", "circle": Vector3(-14, 50, 3)},
			{"kind": "rock", "circle": Vector3(34, -52, 3)},
			{"kind": "rock", "circle": Vector3(-32, -62, 2.5)},
		],
		"roads": [
			{"points": [Vector2(0, -66), Vector2(0, -30), Vector2(-2, 0), Vector2(0, 30), Vector2(0, 75)], "width": 7.0},
			{"points": [Vector2(55, -8), Vector2(16, -8), Vector2(2, -12)], "width": 6.0, "kind": "riverbed"},
			{"points": [Vector2(-52, -50), Vector2(-34, -52), Vector2(-20, -52)], "width": 4.0},
			{"points": [Vector2(-50, 26), Vector2(-44, 42), Vector2(-28, 48), Vector2(-6, 40)], "width": 3.5},
			{"points": [Vector2(-46, 42), Vector2(-50, 72)], "width": 3.5},
		],
		"decor": [
			{"kind": "mine", "pos": Vector2(0, -69)},
			{"kind": "tent", "pos": Vector2(-14, -48)},
			{"kind": "tent", "pos": Vector2(-23, -46), "rot": 30},
			{"kind": "tent", "pos": Vector2(-18, -59), "rot": -20},
			{"kind": "tent", "pos": Vector2(-28, -57), "rot": 10, "scale": 1.3},
			{"kind": "crates", "pos": Vector2(-8, -60)},
			{"kind": "crates", "pos": Vector2(8, -63)},
			{"kind": "tunnel", "pos": Vector2(-54, -50), "rot": 90},
			{"kind": "tunnel", "pos": Vector2(-54, 24), "rot": 90},
			{"kind": "standing_stone", "pos": Vector2(-50, -43)},
			{"kind": "standing_stone", "pos": Vector2(-50, -57)},
			{"kind": "standing_stone", "pos": Vector2(-50, 18)},
			{"kind": "pine", "pos": Vector2(-36, 58)},
			{"kind": "pine", "pos": Vector2(-24, 64)},
			{"kind": "pine", "pos": Vector2(38, 60)},
			{"kind": "pine", "pos": Vector2(44, 40)},
			{"kind": "pine", "pos": Vector2(-44, 64)},
			{"kind": "dead_tree", "pos": Vector2(36, -10)},
			{"kind": "banner", "pos": Vector2(5, -58), "color": Color("#9b3b2a")},
		],
		"zones": {
			"pickup": {"pos": Vector2(2, -63), "radius": 3.0, "label": "Godbridle"},
			"exit": {"pos": Vector2(0, 70), "radius": 8.0, "label": "Marches road"},
			"camp": {"pos": Vector2(-20, -52), "radius": 9.0, "label": "Miners' camp"},
			"tunnel": {"pos": Vector2(-50, -50), "radius": 7.0, "label": "Tunnel entrance"},
			"outlet": {"pos": Vector2(-49, 26), "radius": 6.0, "label": "Tunnel outlet"},
			"outlet_approach": {"pos": Vector2(-34, 44), "radius": 7.0, "label": "Outlet approach"},
			"druid_trail": {"pos": Vector2(-50, 68), "radius": 7.0, "label": "Druid trail"},
			"narrows": {"pos": Vector2(0, -10), "radius": 10.0, "label": "Pass narrows"},
			"ridge": {"pos": Vector2(24, -40), "radius": 6.0, "label": "Ridge"},
			"orc_rally": {"pos": Vector2(46, -8), "radius": 7.0, "label": "Orc rally point"},
		},
	}


## Year Two. Mara's grain crossing.
static func marches_crossing() -> Dictionary:
	return {
		"name": "The Marches Crossing",
		"theme": "plains",
		"size": Vector2(110, 120),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-55, -14, 21, 7)},
			{"kind": "water", "rect": Rect2(-22, -14, 40, 7)},
			{"kind": "water", "rect": Rect2(26, -14, 29, 7)},
			{"kind": "trees", "circle": Vector3(-44, -26, 4)},
			{"kind": "trees", "circle": Vector3(-14, -24, 3.5)},
			{"kind": "trees", "circle": Vector3(-44, 8, 4)},
			{"kind": "house", "rect": Rect2(29, 20, 7, 6)},
			{"kind": "house", "rect": Rect2(-40, 38, 7, 6)},
			{"kind": "rock", "circle": Vector3(46, -36, 3)},
			{"kind": "rock", "circle": Vector3(6, 40, 3)},
		],
		"roads": [
			{"points": [Vector2(0, -60), Vector2(0, -30)], "width": 5.0},
			{"points": [Vector2(0, -30), Vector2(22, -22), Vector2(22, -4), Vector2(24, 22)], "width": 5.0},
			{"points": [Vector2(0, -30), Vector2(-28, -22), Vector2(-28, -4), Vector2(-30, 34)], "width": 4.0},
			{"points": [Vector2(55, 12), Vector2(24, 18), Vector2(-30, 30), Vector2(-55, 24)], "width": 4.0},
		],
		"decor": [
			{"kind": "bridge", "pos": Vector2(22, -10.5)},
			{"kind": "ford", "pos": Vector2(-28, -10.5)},
			{"kind": "tent", "pos": Vector2(-8, -52)},
			{"kind": "tent", "pos": Vector2(8, -54), "rot": 20},
			{"kind": "banner", "pos": Vector2(2, -46), "color": Color("#9b3b2a")},
			{"kind": "crates", "pos": Vector2(28, 26)},
			{"kind": "crates", "pos": Vector2(-34, 44)},
			{"kind": "tree", "pos": Vector2(-50, -50)},
			{"kind": "tree", "pos": Vector2(44, 48)},
			{"kind": "tree", "pos": Vector2(-16, 52)},
		],
		"zones": {
			"start": {"pos": Vector2(0, -50), "radius": 6.0, "label": "Far bank"},
			"fork": {"pos": Vector2(0, -30), "radius": 6.0, "label": "Road fork"},
			"bridge": {"pos": Vector2(22, -10), "radius": 6.0, "label": "Bridge"},
			"ford": {"pos": Vector2(-28, -10), "radius": 6.0, "label": "Lower ford"},
			"mill_yard": {"pos": Vector2(24, 22), "radius": 6.0, "label": "Mill yard"},
			"town_store": {"pos": Vector2(-30, 34), "radius": 6.0, "label": "Town store"},
			"east_road": {"pos": Vector2(50, 12), "radius": 6.0, "label": "East road"},
			"west_road": {"pos": Vector2(-50, 24), "radius": 6.0, "label": "West road"},
			"far_bank_east": {"pos": Vector2(38, -26), "radius": 6.0, "label": "Far-bank rise"},
		},
	}


## Year Two. One post-rise harbor for the Human withdrawal and the Elven rescue.
static func moonwash() -> Dictionary:
	return {
		"name": "Moonwash Harbor",
		"theme": "coast",
		"size": Vector2(120, 120),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-60, -60, 16, 120)},
			{"kind": "ruin", "rect": Rect2(-36, -32, 2, 12)},
			{"kind": "ruin", "rect": Rect2(-36, 20, 2, 12)},
			{"kind": "ruin", "rect": Rect2(-30, -2, 8, 2)},
			{"kind": "wall", "rect": Rect2(-10, -60, 4, 50)},
			{"kind": "wall", "rect": Rect2(-10, 10, 4, 50)},
			{"kind": "wall", "rect": Rect2(24, -60, 4, 46)},
			{"kind": "wall", "rect": Rect2(24, 6, 4, 54)},
			{"kind": "house", "rect": Rect2(36, -40, 8, 8)},
			{"kind": "house", "rect": Rect2(40, 20, 8, 8)},
			{"kind": "house", "rect": Rect2(6, -44, 7, 6)},
			{"kind": "house", "rect": Rect2(8, 32, 7, 6)},
		],
		"roads": [
			{"points": [Vector2(-40, 0), Vector2(-8, 0), Vector2(26, -4), Vector2(60, -4)], "width": 5.0, "kind": "stone"},
			{"points": [Vector2(-40, -52), Vector2(-40, 52)], "width": 7.0, "kind": "lane"},
		],
		"decor": [
			{"kind": "ship_wreck", "pos": Vector2(-41, -24), "rot": 12},
			{"kind": "ship_wreck", "pos": Vector2(-41, 26), "rot": -8},
			{"kind": "ship_moored", "pos": Vector2(-52, 0)},
			{"kind": "crates", "pos": Vector2(-24, -40)},
			{"kind": "crates", "pos": Vector2(-24, 40)},
			{"kind": "statue", "pos": Vector2(-18, 0)},
			{"kind": "arch", "pos": Vector2(26, -4), "rot": 90},
			{"kind": "pine", "pos": Vector2(52, -30)},
			{"kind": "pine", "pos": Vector2(54, 40)},
			{"kind": "banner", "pos": Vector2(-4, -4), "color": Color("#6a8fa0")},
		],
		"zones": {
			"lower_quay": {"pos": Vector2(-24, 0), "radius": 10.0, "label": "Lower quay"},
			"lower_stair": {"pos": Vector2(-8, 0), "radius": 6.0, "label": "Lower stair"},
			"landing": {"pos": Vector2(10, -2), "radius": 7.0, "label": "Landing"},
			"upper_stair": {"pos": Vector2(26, -4), "radius": 6.0, "label": "Upper stair"},
			"upper_exit": {"pos": Vector2(54, -4), "radius": 8.0, "label": "Upper-quay exit"},
			"rescue_lane": {"pos": Vector2(-40, 0), "radius": 7.0, "label": "Elven rescue lane"},
			"deck": {"pos": Vector2(-42, 0), "radius": 5.0, "label": "Receiving deck"},
			"forward": {"pos": Vector2(-34, -22), "radius": 5.0, "label": "Forward transfer point"},
			"aft": {"pos": Vector2(-34, 24), "radius": 5.0, "label": "Aft transfer point"},
			"slab_north": {"pos": Vector2(-22, -16), "radius": 5.0, "label": "Buckling slab"},
			"slab_south": {"pos": Vector2(-22, 14), "radius": 5.0, "label": "Buckling slab"},
			"slab_stair": {"pos": Vector2(-16, 4), "radius": 4.0, "label": "Buckling slab"},
			"north_quay": {"pos": Vector2(-24, -52), "radius": 7.0, "label": "North quay"},
			"south_quay": {"pos": Vector2(-24, 52), "radius": 7.0, "label": "South quay"},
		},
	}


## Year Three. The Red Basin's well road.
static func well_road() -> Dictionary:
	return {
		"name": "The Basin Well Road",
		"theme": "salt",
		"size": Vector2(100, 140),
		"obstacles": [
			{"kind": "cliff", "rect": Rect2(-6, -34, 12, 74)},
			{"kind": "cliff", "rect": Rect2(-50, -14, 30, 4)},
			{"kind": "cliff", "rect": Rect2(-38, 6, 32, 4)},
			{"kind": "cliff", "rect": Rect2(-50, 28, 8, 4)},
			{"kind": "cliff", "rect": Rect2(-38, 28, 32, 4)},
			{"kind": "house", "rect": Rect2(28, -64, 8, 6)},
			{"kind": "rock", "circle": Vector3(36, -24, 2.0)},
			{"kind": "rock", "circle": Vector3(-30, -40, 2.5)},
		],
		"roads": [
			{"points": [Vector2(18, -46), Vector2(14, -30), Vector2(28, 0), Vector2(28, 30), Vector2(10, 50), Vector2(0, 66)], "width": 6.0, "kind": "salt"},
			{"points": [Vector2(-20, -50), Vector2(-13, -30), Vector2(-13, -8), Vector2(-44, 0), Vector2(-44, 16), Vector2(-40, 34), Vector2(-20, 46), Vector2(0, 66)], "width": 4.0, "kind": "riverbed"},
		],
		"decor": [
			{"kind": "well", "pos": Vector2(-26, -58)},
			{"kind": "well", "pos": Vector2(22, -60)},
			{"kind": "crates", "pos": Vector2(30, -56)},
			{"kind": "tent", "pos": Vector2(38, -52)},
			{"kind": "dead_tree", "pos": Vector2(40, 10)},
			{"kind": "dead_tree", "pos": Vector2(-30, -26)},
			{"kind": "banner", "pos": Vector2(-4, 60), "color": Color("#b0482c")},
		],
		"zones": {
			"upper_well": {"pos": Vector2(-24, -56), "radius": 7.0, "label": "Upper well"},
			"lower_well": {"pos": Vector2(22, -52), "radius": 7.0, "label": "Lower well"},
			"storehouse": {"pos": Vector2(31, -56), "radius": 3.0, "label": "Storehouse"},
			"salt_road": {"pos": Vector2(28, 10), "radius": 10.0, "label": "Salt road"},
			"wash": {"pos": Vector2(-30, -2), "radius": 10.0, "label": "Crooked wash"},
			"ramp": {"pos": Vector2(-40, 30), "radius": 4.0, "label": "Wash ramp"},
			"exit": {"pos": Vector2(0, 62), "radius": 9.0, "label": "Basin exit"},
			"rider_muster": {"pos": Vector2(44, -14), "radius": 6.0, "label": "Rider muster"},
		},
	}


## Year Three. A short shoreline for the Elven survey.
static func coast_survey() -> Dictionary:
	return {
		"name": "The Two Shorelines",
		"theme": "coast",
		"size": Vector2(130, 100),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-65, -50, 130, 22)},
			{"kind": "cliff", "rect": Rect2(6, -30, 18, 22)},
			{"kind": "water", "rect": Rect2(38, 0, 10, 16)},
			{"kind": "house", "rect": Rect2(-6, 26, 7, 6)},
			{"kind": "house", "rect": Rect2(8, 30, 7, 6)},
			{"kind": "rock", "circle": Vector3(-30, 0, 3)},
			{"kind": "rock", "circle": Vector3(50, -20, 3)},
		],
		"roads": [
			{"points": [Vector2(-60, 14), Vector2(-20, 18), Vector2(20, 22), Vector2(56, 24)], "width": 4.0, "kind": "sand"},
		],
		"decor": [
			{"kind": "standing_stone", "pos": Vector2(-46, 8)},
			{"kind": "boat", "pos": Vector2(43, 12), "rot": 10},
			{"kind": "boat", "pos": Vector2(42, 4), "rot": -6},
			{"kind": "dock", "pos": Vector2(36, 8), "rot": 90},
			{"kind": "beacon", "pos": Vector2(-24, -24)},
			{"kind": "beacon", "pos": Vector2(30, -24)},
			{"kind": "pine", "pos": Vector2(-56, 36)},
			{"kind": "pine", "pos": Vector2(56, 40)},
			{"kind": "rocks", "pos": Vector2(-50, -24)},
		],
		"zones": {
			"stone": {"pos": Vector2(-44, 10), "radius": 5.0, "label": "Ancestral stone"},
			"inlet": {"pos": Vector2(34, 10), "radius": 5.0, "label": "Fishing inlet"},
			"beach_signal": {"pos": Vector2(-24, -22), "radius": 4.0, "label": "Beach signal"},
			"headland_signal": {"pos": Vector2(30, -22), "radius": 4.0, "label": "Headland signal"},
			"beach_stop": {"pos": Vector2(-24, -38), "radius": 3.0, "label": "Beach stop"},
			"headland_stop": {"pos": Vector2(36, -38), "radius": 3.0, "label": "Headland stop"},
			"landing": {"pos": Vector2(-44, -24), "radius": 7.0, "label": "Landing beach"},
			"village": {"pos": Vector2(2, 30), "radius": 9.0, "label": "Pilot village"},
		},
	}


## Year Four. Spanwater Lock, shared by the Orc, Elven, Dryad and Druid campaigns.
static func spanwater() -> Dictionary:
	return {
		"name": "Spanwater Lock",
		"theme": "river",
		"size": Vector2(140, 130),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-70, -65, 140, 25)},
			{"kind": "wall", "rect": Rect2(-14, -40, 28, 8)},
			{"kind": "water", "rect": Rect2(-70, -34, 48, 3)},
			{"kind": "rock", "circle": Vector3(-20, -24, 2.0)},
			{"kind": "rock", "circle": Vector3(-22, -16, 1.8)},
			{"kind": "house", "rect": Rect2(-62, -22, 8, 6)},
			{"kind": "house", "rect": Rect2(-48, -14, 8, 6)},
			{"kind": "house", "rect": Rect2(-62, -4, 8, 6)},
			{"kind": "water", "rect": Rect2(28, 42, 42, 23)},
			{"kind": "rock", "circle": Vector3(40, 10, 3.0)},
			{"kind": "rock", "circle": Vector3(-40, 50, 3.0)},
		],
		"dynamic_obstacles": {
			"flood": {"kind": "water", "rect": Rect2(-15, -24, 14, 89)},
		},
		"roads": [
			{"points": [Vector2(70, -26), Vector2(14, -26)], "width": 5.0, "kind": "causeway"},
			{"points": [Vector2(-8, -30), Vector2(-8, 0), Vector2(-12, 40), Vector2(-14, 65)], "width": 12.0, "kind": "riverbed"},
			{"points": [Vector2(-22, -27), Vector2(-66, -27)], "width": 3.0},
			{"points": [Vector2(-30, -4), Vector2(-50, 4), Vector2(-66, 10)], "width": 4.0},
			{"points": [Vector2(-40, 40), Vector2(-10, 20), Vector2(12, 30), Vector2(24, 38)], "width": 3.5},
		],
		"decor": [
			{"kind": "wheel", "pos": Vector2(-8, -33)},
			{"kind": "sea_gate", "pos": Vector2(8, -33)},
			{"kind": "dock", "pos": Vector2(30, 44), "rot": 90},
			{"kind": "tent", "pos": Vector2(12, 28)},
			{"kind": "tent", "pos": Vector2(-34, 38), "rot": 20},
			{"kind": "banner", "pos": Vector2(-30, -8), "color": Color("#b0482c")},
			{"kind": "tree", "pos": Vector2(-44, 22)},
			{"kind": "tree", "pos": Vector2(52, -8)},
			{"kind": "pine", "pos": Vector2(60, 20)},
		],
		"zones": {
			"wheel": {"pos": Vector2(-8, -27), "radius": 6.0, "label": "Spillway wheel"},
			"lock_top": {"pos": Vector2(0, -28), "radius": 4.0, "label": "Lock top"},
			"sea_gate": {"pos": Vector2(8, -28), "radius": 4.0, "label": "Sea gate (shut)"},
			"apron": {"pos": Vector2(20, -14), "radius": 10.0, "label": "Lock apron"},
			"upstream": {"pos": Vector2(62, -26), "radius": 8.0, "label": "Upstream approach"},
			"high_bank": {"pos": Vector2(-32, -4), "radius": 5.0, "label": "High bank"},
			"low_crossing": {"pos": Vector2(-9, 22), "radius": 5.0, "label": "Low crossing"},
			"headgate": {"pos": Vector2(-22, -30), "radius": 5.0, "label": "Feeder headgate"},
			"feeder_town": {"pos": Vector2(-54, -10), "radius": 10.0, "label": "Feeder town"},
			"landing": {"pos": Vector2(24, 38), "radius": 5.0, "label": "Low landing"},
			"near_bank": {"pos": Vector2(12, 32), "radius": 6.0, "label": "Near households"},
			"far_bank": {"pos": Vector2(-34, 42), "radius": 6.0, "label": "Far households"},
			"boat_exit": {"pos": Vector2(66, 56), "radius": 6.0, "label": "Boat exit"},
			"dock": {"pos": Vector2(32, 48), "radius": 3.0, "label": "Launch dock"},
			"cairnspine_road": {"pos": Vector2(-64, 10), "radius": 7.0, "label": "Cairnspine road"},
			"south_road": {"pos": Vector2(20, 62), "radius": 6.0, "label": "South road"},
		},
	}


## Year Three. The Dryad grove sheltered by a Human town.
static func grove_town() -> Dictionary:
	return {
		"name": "Alderford",
		"theme": "forest",
		"size": Vector2(110, 110),
		"obstacles": [
			{"kind": "house", "rect": Rect2(-30, -30, 10, 8)},
			{"kind": "house", "rect": Rect2(18, -30, 10, 8)},
			{"kind": "house", "rect": Rect2(-32, 14, 10, 8)},
			{"kind": "house", "rect": Rect2(22, 16, 10, 8)},
			{"kind": "house", "rect": Rect2(-6, 26, 12, 6)},
			{"kind": "wall", "rect": Rect2(-45, -45, 30, 2)},
			{"kind": "wall", "rect": Rect2(15, -45, 30, 2)},
			{"kind": "wall", "rect": Rect2(45, -45, 2, 30)},
			{"kind": "wall", "rect": Rect2(45, 5, 2, 40)},
			{"kind": "water", "rect": Rect2(-55, -50, 12, 3)},
			{"kind": "water", "rect": Rect2(-14, -58, 3, 10)},
		],
		"roads": [
			{"points": [Vector2(0, -55), Vector2(0, 0), Vector2(0, 55)], "width": 5.0},
			{"points": [Vector2(55, -5), Vector2(0, 0), Vector2(-55, 7)], "width": 5.0},
			{"points": [Vector2(-12, -48), Vector2(-40, -36), Vector2(-50, -10), Vector2(-14, -4)], "width": 2.5, "kind": "channel"},
		],
		"decor": [
			{"kind": "tree", "pos": Vector2(-40, -54)},
			{"kind": "tree", "pos": Vector2(40, 52)},
			{"kind": "tree", "pos": Vector2(-50, 40)},
			{"kind": "tree", "pos": Vector2(52, -40)},
			{"kind": "well", "pos": Vector2(14, 6)},
			{"kind": "crates", "pos": Vector2(-14, -16)},
			{"kind": "sluice", "pos": Vector2(-12, -48)},
			{"kind": "sluice", "pos": Vector2(-44, -30)},
			{"kind": "sluice", "pos": Vector2(-24, -6)},
			{"kind": "nursery", "pos": Vector2(14, -12)},
		],
		"zones": {
			"grove": {"pos": Vector2(0, 0), "radius": 12.0, "label": "The grove"},
			"dam": {"pos": Vector2(-12, -52), "radius": 7.0, "label": "Upper sluice"},
			"west_channel": {"pos": Vector2(-44, -30), "radius": 6.0, "label": "West channel"},
			"town_sluice": {"pos": Vector2(-24, -6), "radius": 5.0, "label": "Town sluice"},
			"north_gate": {"pos": Vector2(0, -50), "radius": 8.0, "label": "North gate"},
			"east_gate": {"pos": Vector2(52, -5), "radius": 8.0, "label": "East gate"},
			"west_fields": {"pos": Vector2(-50, 12), "radius": 8.0, "label": "West fields"},
		},
	}


## Years Three and Four. The village above the new cut on the Still Kingdom's border.
static func cut_village() -> Dictionary:
	return {
		"name": "Hollowmere",
		"theme": "fen",
		"size": Vector2(110, 110),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-55, -55, 110, 14)},
			{"kind": "water", "rect": Rect2(30, -41, 12, 40)},
			{"kind": "house", "rect": Rect2(-20, 0, 7, 6)},
			{"kind": "house", "rect": Rect2(-4, 6, 7, 6)},
			{"kind": "house", "rect": Rect2(12, 0, 7, 6)},
			{"kind": "house", "rect": Rect2(-16, 18, 7, 6)},
			{"kind": "house", "rect": Rect2(2, 22, 9, 7)},
			{"kind": "water", "circle": Vector3(-36, 14, 4)},
			{"kind": "rock", "circle": Vector3(20, 40, 3)},
		],
		"dynamic_obstacles": {
			"widened_cut": {"kind": "water", "rect": Rect2(-55, -41, 85, 7)},
		},
		"roads": [
			{"points": [Vector2(0, 55), Vector2(0, 30), Vector2(-4, 10), Vector2(-6, -30)], "width": 4.0, "kind": "boardwalk"},
			{"points": [Vector2(-50, 36), Vector2(-20, 32), Vector2(0, 30)], "width": 3.0},
		],
		"decor": [
			{"kind": "cairn", "pos": Vector2(-24, -36)},
			{"kind": "cairn", "pos": Vector2(-6, -38)},
			{"kind": "cairn", "pos": Vector2(14, -36)},
			{"kind": "standing_stone", "pos": Vector2(-16, -32)},
			{"kind": "dead_tree", "pos": Vector2(-34, -20)},
			{"kind": "dead_tree", "pos": Vector2(44, 10)},
			{"kind": "dead_tree", "pos": Vector2(-44, 40)},
			{"kind": "lamp", "pos": Vector2(6, 31)},
			{"kind": "fire", "pos": Vector2(-2, 16)},
		],
		"zones": {
			"bank": {"pos": Vector2(-6, -32), "radius": 8.0, "label": "Grave bank"},
			"grave_west": {"pos": Vector2(-24, -34), "radius": 5.0, "label": "West graves"},
			"grave_mid": {"pos": Vector2(-6, -36), "radius": 5.0, "label": "Oldest graves"},
			"grave_east": {"pos": Vector2(14, -34), "radius": 5.0, "label": "East graves"},
			"village": {"pos": Vector2(0, 14), "radius": 12.0, "label": "Hollowmere"},
			"archive": {"pos": Vector2(6, 32), "radius": 4.0, "label": "Record house"},
			"high_ground": {"pos": Vector2(-40, 38), "radius": 8.0, "label": "High ground"},
			"east_ford": {"pos": Vector2(50, 20), "radius": 6.0, "label": "East ford"},
			"west_track": {"pos": Vector2(-50, -20), "radius": 6.0, "label": "West track"},
		},
	}


## Year Five. The road through the Cairnspine to the vault.
static func cairnspine_road() -> Dictionary:
	return {
		"name": "The Cairnspine Road",
		"theme": "vault",
		"size": Vector2(150, 170),
		"obstacles": [
			{"kind": "cliff", "rect": Rect2(-75, -85, 150, 8)},
			{"kind": "wall", "rect": Rect2(-16, -77, 32, 7)},
			{"kind": "wall", "rect": Rect2(-30, -64, 2, 24)},
			{"kind": "wall", "rect": Rect2(28, -64, 2, 24)},
			{"kind": "cliff", "rect": Rect2(-75, -30, 45, 14)},
			{"kind": "cliff", "rect": Rect2(30, -30, 45, 14)},
			{"kind": "cliff", "rect": Rect2(-75, 22, 30, 16)},
			{"kind": "cliff", "rect": Rect2(18, 22, 57, 16)},
			{"kind": "rock", "circle": Vector3(-10, 0, 3)},
			{"kind": "rock", "circle": Vector3(12, 52, 3)},
			{"kind": "rock", "circle": Vector3(-30, 60, 4)},
			{"kind": "rock", "circle": Vector3(40, -50, 4)},
			{"kind": "rock", "circle": Vector3(-44, -50, 4)},
		],
		"roads": [
			{"points": [Vector2(0, 85), Vector2(-6, 50), Vector2(-24, 30), Vector2(-14, 4), Vector2(0, -24), Vector2(0, -64)], "width": 7.0},
			{"points": [Vector2(72, 4), Vector2(40, 0), Vector2(0, -6)], "width": 4.0},
			{"points": [Vector2(70, -64), Vector2(44, -40), Vector2(16, -48)], "width": 4.0},
		],
		"decor": [
			{"kind": "vault_door", "pos": Vector2(0, -70)},
			{"kind": "standing_stone", "pos": Vector2(-14, -58)},
			{"kind": "standing_stone", "pos": Vector2(14, -58)},
			{"kind": "standing_stone", "pos": Vector2(-14, -44)},
			{"kind": "standing_stone", "pos": Vector2(14, -44)},
			{"kind": "tent", "pos": Vector2(-10, -38)},
			{"kind": "tent", "pos": Vector2(10, -40), "rot": 30},
			{"kind": "banner", "pos": Vector2(-6, -46), "color": Color("#acae8c")},
			{"kind": "banner", "pos": Vector2(6, -46), "color": Color("#d1a384")},
			{"kind": "banner", "pos": Vector2(0, -48), "color": Color("#a8bdc7")},
			{"kind": "pine", "pos": Vector2(-50, 0)},
			{"kind": "pine", "pos": Vector2(50, 10)},
			{"kind": "pine", "pos": Vector2(-56, 50)},
			{"kind": "pine", "pos": Vector2(40, 60)},
			{"kind": "cairn", "pos": Vector2(50, -46)},
			{"kind": "fire", "pos": Vector2(0, -40)},
		],
		"zones": {
			"vault_gate": {"pos": Vector2(0, -62), "radius": 6.0, "label": "Vault door"},
			"vault_court": {"pos": Vector2(0, -50), "radius": 12.0, "label": "Vault court"},
			"witness_camp": {"pos": Vector2(0, -38), "radius": 9.0, "label": "Witness camp"},
			"upper_road": {"pos": Vector2(0, -12), "radius": 9.0, "label": "Upper road"},
			"switchback": {"pos": Vector2(-20, 24), "radius": 9.0, "label": "Switchback"},
			"road_foot": {"pos": Vector2(0, 76), "radius": 8.0, "label": "Road foot"},
			"east_track": {"pos": Vector2(66, 4), "radius": 7.0, "label": "East track"},
			"northeast_track": {"pos": Vector2(62, -60), "radius": 7.0, "label": "Northeast track"},
			"west_ledge": {"pos": Vector2(-60, 4), "radius": 7.0, "label": "West ledge"},
		},
	}
