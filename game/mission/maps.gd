extends RefCounted
## Battlefields shared by the campaign missions.
##
## Coordinates are metres on the ground plane. Negative y is north. Several campaigns
## fight on the same field from different sides, so each map is defined once.


static func greyhollow() -> Dictionary:
	return {
		"name": "Greyhollow Mine",
		"theme": "mountain",
		"size": Vector2(110, 150),
		"obstacles": [
			{"kind": "cliff", "rect": Rect2(-55, -75, 110, 5)},
			{"kind": "cliff", "rect": Rect2(-55, -70, 10, 22)},
			{"kind": "cliff", "rect": Rect2(-55, -30, 33, 40)},
			{"kind": "cliff", "rect": Rect2(18, -30, 37, 18)},
			{"kind": "cliff", "rect": Rect2(18, -4, 37, 14)},
			{"kind": "rock", "circle": Vector3(-8, -16, 2.2)},
			{"kind": "rock", "circle": Vector3(10, 0, 2.5)},
			{"kind": "rock", "circle": Vector3(-30, 35, 5)},
			{"kind": "rock", "circle": Vector3(32, 40, 6)},
			{"kind": "rock", "circle": Vector3(-12, 26, 2.5)},
			{"kind": "rock", "circle": Vector3(20, 22, 3)},
			{"kind": "rock", "circle": Vector3(30, -56, 3)},
			{"kind": "rock", "circle": Vector3(40, -40, 2.5)},
		],
		"roads": [
			{"points": [Vector2(0, -66), Vector2(0, -30), Vector2(-2, 0), Vector2(0, 30), Vector2(0, 75)], "width": 7.0},
			{"points": [Vector2(55, -8), Vector2(20, -8), Vector2(4, -12)], "width": 6.0, "kind": "riverbed"},
			{"points": [Vector2(-50, -40), Vector2(-30, -46), Vector2(-18, -52)], "width": 4.0},
		],
		"decor": [
			{"kind": "mine", "pos": Vector2(0, -69)},
			{"kind": "tent", "pos": Vector2(-12, -48)},
			{"kind": "tent", "pos": Vector2(-21, -46), "rot": 30},
			{"kind": "tent", "pos": Vector2(-16, -59), "rot": -20},
			{"kind": "tent", "pos": Vector2(-27, -59), "rot": 10, "scale": 1.3},
			{"kind": "crates", "pos": Vector2(-8, -60)},
			{"kind": "crates", "pos": Vector2(7, -63)},
			{"kind": "tunnel", "pos": Vector2(-53, -40), "rot": 90},
			{"kind": "standing_stone", "pos": Vector2(-44, -33)},
			{"kind": "standing_stone", "pos": Vector2(-44, -47)},
			{"kind": "pine", "pos": Vector2(-36, 50)},
			{"kind": "pine", "pos": Vector2(-42, 58)},
			{"kind": "pine", "pos": Vector2(36, 58)},
			{"kind": "pine", "pos": Vector2(44, 52)},
			{"kind": "pine", "pos": Vector2(-20, 64)},
			{"kind": "dead_tree", "pos": Vector2(34, -10)},
			{"kind": "banner", "pos": Vector2(4, -56), "color": Color("#9b3b2a")},
		],
		"zones": {
			"mine": {"pos": Vector2(0, -62), "radius": 8.0, "label": "Mine"},
			"camp": {"pos": Vector2(-18, -52), "radius": 9.0, "label": "Miners' camp"},
			"foreman_tent": {"pos": Vector2(-27, -55), "radius": 4.0, "label": "Foreman's tent"},
			"tunnel_mouth": {"pos": Vector2(-46, -40), "radius": 8.0, "label": "Tunnel mouth"},
			"pass_top": {"pos": Vector2(0, -30), "radius": 12.0, "label": "Upper pass"},
			"lower_pass": {"pos": Vector2(0, 14), "radius": 12.0, "label": "Lower pass"},
			"pass_mouth": {"pos": Vector2(0, 64), "radius": 10.0, "label": "Marches road"},
			"east_ridge": {"pos": Vector2(46, -64), "radius": 9.0, "label": "East ridge"},
			"dry_gap": {"pos": Vector2(46, -8), "radius": 6.0, "label": "Dry riverbed"},
		},
	}


static func kingswell() -> Dictionary:
	return {
		"name": "Kingswell",
		"theme": "plains",
		"size": Vector2(110, 120),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-55, -38, 40, 5)},
			{"kind": "water", "rect": Rect2(-5, -38, 22, 5)},
			{"kind": "water", "rect": Rect2(27, -38, 28, 5)},
			{"kind": "trees", "circle": Vector3(-42, -12, 4)},
			{"kind": "trees", "circle": Vector3(-47, 3, 5)},
			{"kind": "trees", "circle": Vector3(-39, 17, 4)},
			{"kind": "rock", "circle": Vector3(40, -14, 4)},
			{"kind": "rock", "circle": Vector3(45, 8, 3)},
			{"kind": "rock", "circle": Vector3(-22, 42, 3)},
		],
		"roads": [
			{"points": [Vector2(38, 60), Vector2(30, 40), Vector2(8, 8), Vector2(0, 0)], "width": 6.0},
			{"points": [Vector2(0, 0), Vector2(-10, -40), Vector2(-12, -60)], "width": 5.0},
			{"points": [Vector2(0, 0), Vector2(22, -40), Vector2(24, -60)], "width": 5.0},
		],
		"decor": [
			{"kind": "well", "pos": Vector2(0, 0)},
			{"kind": "banner", "pos": Vector2(-7, -5), "color": Color("#9b3b2a")},
			{"kind": "banner", "pos": Vector2(7, -5), "color": Color("#2f5d8a")},
			{"kind": "banner", "pos": Vector2(-6, 7), "color": Color("#c49a3a")},
			{"kind": "banner", "pos": Vector2(6, 7), "color": Color("#5a7d3a")},
			{"kind": "tent", "pos": Vector2(-24, 20)},
			{"kind": "tent", "pos": Vector2(24, -18), "rot": 40},
			{"kind": "tree", "pos": Vector2(-30, -26)},
			{"kind": "tree", "pos": Vector2(32, 30)},
			{"kind": "tree", "pos": Vector2(-14, 50)},
			{"kind": "tree", "pos": Vector2(18, 52)},
			{"kind": "bridge", "pos": Vector2(-10, -35.5), "rot": 0},
			{"kind": "bridge", "pos": Vector2(22, -35.5), "rot": 0},
		],
		"zones": {
			"well": {"pos": Vector2(0, 0), "radius": 6.0, "label": "Kingswell"},
			"moot": {"pos": Vector2(0, 0), "radius": 16.0, "label": "The moot"},
			"north_fords": {"pos": Vector2(6, -48), "radius": 12.0, "label": "North fords"},
			"west_woods": {"pos": Vector2(-44, 0), "radius": 10.0, "label": "West woods"},
			"se_road": {"pos": Vector2(36, 46), "radius": 8.0, "label": "Basin road"},
			"approach": {"pos": Vector2(16, 22), "radius": 12.0, "label": "Moot approach"},
		},
	}


static func hollow_stones() -> Dictionary:
	var obstacles: Array = [
		{"kind": "rock", "circle": Vector3(-30, -30, 7)},
		{"kind": "rock", "circle": Vector3(30, -32, 6)},
		{"kind": "rock", "circle": Vector3(-34, 24, 6)},
		{"kind": "rock", "circle": Vector3(33, 26, 6)},
		{"kind": "rock", "circle": Vector3(0, 40, 4)},
	]
	var decor: Array = []
	for i in range(8):
		var angle := TAU * i / 8.0 + 0.2
		var at := Vector2(cos(angle), sin(angle)) * 17.0
		obstacles.append({"kind": "stone", "circle": Vector3(at.x, at.y, 0.7)})
		decor.append({"kind": "standing_stone", "pos": at})
	decor.append_array([
		{"kind": "fire", "pos": Vector2(0, 0)},
		{"kind": "pine", "pos": Vector2(-44, -10)},
		{"kind": "pine", "pos": Vector2(42, 12)},
		{"kind": "pine", "pos": Vector2(-18, -44)},
		{"kind": "pine", "pos": Vector2(20, 44)},
	])
	return {
		"name": "Hollow Stones",
		"theme": "highland",
		"size": Vector2(100, 100),
		"obstacles": obstacles,
		"roads": [{"points": [Vector2(0, 50), Vector2(0, 0), Vector2(0, -50)], "width": 4.0}],
		"decor": decor,
		"zones": {
			"circle": {"pos": Vector2(0, 0), "radius": 16.0, "label": "Stone circle"},
			"north": {"pos": Vector2(0, -42), "radius": 8.0, "label": "North track"},
			"west": {"pos": Vector2(-44, 0), "radius": 8.0, "label": "West moor"},
			"east": {"pos": Vector2(44, -4), "radius": 8.0, "label": "East moor"},
			"south": {"pos": Vector2(0, 44), "radius": 8.0, "label": "South track"},
		},
	}


static func seliath() -> Dictionary:
	return {
		"name": "Old Seliath",
		"theme": "coast",
		"size": Vector2(120, 110),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-60, -55, 22, 110)},
			{"kind": "ruin", "rect": Rect2(-18, -36, 14, 2)},
			{"kind": "ruin", "rect": Rect2(-6, -8, 2, 16)},
			{"kind": "ruin", "rect": Rect2(8, 10, 16, 2)},
			{"kind": "ruin", "rect": Rect2(-20, 20, 2, 14)},
			{"kind": "ruin", "rect": Rect2(14, -24, 2, 12)},
			{"kind": "ruin", "rect": Rect2(0, -48, 12, 8)},
			{"kind": "house", "rect": Rect2(34, -14, 6, 6)},
			{"kind": "house", "rect": Rect2(45, -5, 6, 6)},
			{"kind": "house", "rect": Rect2(36, 11, 6, 6)},
			{"kind": "house", "rect": Rect2(47, 19, 6, 6)},
		],
		"roads": [
			{"points": [Vector2(60, 4), Vector2(30, 2), Vector2(0, 0), Vector2(-30, 0)], "width": 5.0, "kind": "sand"},
		],
		"decor": [
			{"kind": "arch", "pos": Vector2(6, -39)},
			{"kind": "statue", "pos": Vector2(-10, 4)},
			{"kind": "statue", "pos": Vector2(20, -2)},
			{"kind": "boat", "pos": Vector2(-48, -36), "rot": 80},
			{"kind": "boat", "pos": Vector2(-50, 30), "rot": 100},
			{"kind": "dock", "pos": Vector2(-40, 0), "rot": 90},
			{"kind": "pine", "pos": Vector2(52, -30)},
			{"kind": "pine", "pos": Vector2(56, 36)},
			{"kind": "rocks", "pos": Vector2(-26, -44)},
			{"kind": "rocks", "pos": Vector2(-24, 44)},
		],
		"zones": {
			"ship_north": {"pos": Vector2(-32, -22), "radius": 8.0, "label": "Northern ship"},
			"ship_south": {"pos": Vector2(-32, 20), "radius": 8.0, "label": "Southern ship"},
			"archive": {"pos": Vector2(6, -37), "radius": 5.0, "label": "Archive"},
			"ruins": {"pos": Vector2(0, 0), "radius": 20.0, "label": "Risen ruins"},
			"village": {"pos": Vector2(42, 4), "radius": 12.0, "label": "Brineholt road"},
			"north_ruins": {"pos": Vector2(24, -44), "radius": 8.0, "label": "North ruins"},
			"south_beach": {"pos": Vector2(-10, 46), "radius": 8.0, "label": "South beach"},
		},
	}


static func marrowfen() -> Dictionary:
	return {
		"name": "Marrowfen",
		"theme": "fen",
		"size": Vector2(110, 110),
		"obstacles": [
			{"kind": "water", "circle": Vector3(-12, -10, 6)},
			{"kind": "water", "circle": Vector3(20, -8, 5)},
			{"kind": "water", "circle": Vector3(-34, 4, 5)},
			{"kind": "water", "circle": Vector3(34, 12, 6)},
			{"kind": "water", "circle": Vector3(-6, -30, 4)},
			{"kind": "water", "circle": Vector3(16, -48, 3)},
			{"kind": "water", "circle": Vector3(-44, -40, 5)},
			{"kind": "house", "rect": Rect2(-11, 14, 6, 5)},
			{"kind": "house", "rect": Rect2(6, 16, 6, 5)},
			{"kind": "house", "rect": Rect2(-4, 31, 6, 5)},
		],
		"roads": [
			{"points": [Vector2(0, 55), Vector2(0, 24), Vector2(-4, 0), Vector2(0, -45)], "width": 4.0, "kind": "boardwalk"},
		],
		"decor": [
			{"kind": "cairn", "pos": Vector2(-30, -25)},
			{"kind": "cairn", "pos": Vector2(28, -30)},
			{"kind": "cairn", "pos": Vector2(0, -46)},
			{"kind": "dead_tree", "pos": Vector2(-24, -6)},
			{"kind": "dead_tree", "pos": Vector2(40, -20)},
			{"kind": "dead_tree", "pos": Vector2(-40, 26)},
			{"kind": "dead_tree", "pos": Vector2(24, 40)},
			{"kind": "dead_tree", "pos": Vector2(8, -22)},
			{"kind": "fire", "pos": Vector2(0, 24)},
		],
		"zones": {
			"village": {"pos": Vector2(0, 24), "radius": 12.0, "label": "Marrowfen"},
			"cairn_west": {"pos": Vector2(-30, -25), "radius": 6.0, "label": "West cairn"},
			"cairn_east": {"pos": Vector2(28, -30), "radius": 6.0, "label": "East cairn"},
			"cairn_north": {"pos": Vector2(0, -46), "radius": 6.0, "label": "North cairn"},
			"fen_west": {"pos": Vector2(-48, -10), "radius": 6.0, "label": "West fen"},
			"fen_east": {"pos": Vector2(48, -6), "radius": 6.0, "label": "East fen"},
		},
	}


static func drowned_road() -> Dictionary:
	return {
		"name": "The Drowned Road",
		"theme": "coast",
		"size": Vector2(140, 100),
		"obstacles": [
			{"kind": "water", "rect": Rect2(-70, -50, 140, 18)},
			{"kind": "cliff", "rect": Rect2(-70, 30, 60, 20)},
			{"kind": "cliff", "rect": Rect2(10, 26, 60, 24)},
			{"kind": "rock", "circle": Vector3(-20, -18, 3)},
			{"kind": "rock", "circle": Vector3(24, 14, 3)},
			{"kind": "rock", "circle": Vector3(44, -20, 4)},
			{"kind": "house", "rect": Rect2(-63, -12, 6, 6)},
			{"kind": "house", "rect": Rect2(-54, 6, 6, 6)},
			{"kind": "house", "rect": Rect2(-46, -24, 6, 5)},
		],
		"roads": [
			{"points": [Vector2(70, 0), Vector2(30, -4), Vector2(0, 0), Vector2(-30, -2), Vector2(-56, 0)], "width": 6.0},
			{"points": [Vector2(-56, 0), Vector2(-56, -30)], "width": 4.0, "kind": "sand"},
		],
		"decor": [
			{"kind": "dock", "pos": Vector2(-56, -34), "rot": 0},
			{"kind": "boat", "pos": Vector2(-62, -40), "rot": 10},
			{"kind": "boat", "pos": Vector2(-48, -42), "rot": -20},
			{"kind": "wagon", "pos": Vector2(36, -3), "rot": 90},
			{"kind": "banner", "pos": Vector2(32, -8), "color": Color("#2f5d8a")},
			{"kind": "banner", "pos": Vector2(40, 2), "color": Color("#2f5d8a")},
			{"kind": "pine", "pos": Vector2(-30, 22)},
			{"kind": "pine", "pos": Vector2(50, 16)},
			{"kind": "rocks", "pos": Vector2(0, -28)},
		],
		"zones": {
			"brineholt": {"pos": Vector2(-50, -4), "radius": 12.0, "label": "Brineholt"},
			"docks": {"pos": Vector2(-56, -27), "radius": 6.0, "label": "Docks"},
			"road_mid": {"pos": Vector2(0, 0), "radius": 12.0, "label": "Coast road"},
			"wagon": {"pos": Vector2(36, -3), "radius": 5.0, "label": "Bridle wagon"},
			"south_gap": {"pos": Vector2(0, 40), "radius": 8.0, "label": "South gap"},
			"east_road": {"pos": Vector2(62, 0), "radius": 8.0, "label": "East road"},
		},
	}


static func thornbury() -> Dictionary:
	return {
		"name": "Thornbury",
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
			{"kind": "wall", "rect": Rect2(-47, -45, 2, 44)},
			{"kind": "wall", "rect": Rect2(-47, 15, 2, 30)},
		],
		"roads": [
			{"points": [Vector2(0, -55), Vector2(0, 0), Vector2(0, 55)], "width": 5.0},
			{"points": [Vector2(55, -5), Vector2(0, 0), Vector2(-55, 7)], "width": 5.0},
		],
		"decor": [
			{"kind": "tree", "pos": Vector2(-40, -54)},
			{"kind": "tree", "pos": Vector2(40, 52)},
			{"kind": "tree", "pos": Vector2(-50, 40)},
			{"kind": "tree", "pos": Vector2(52, -40)},
			{"kind": "tree", "pos": Vector2(-36, 34)},
			{"kind": "tree", "pos": Vector2(34, -36)},
			{"kind": "well", "pos": Vector2(14, 6)},
			{"kind": "crates", "pos": Vector2(-14, -16)},
		],
		"zones": {
			"grove": {"pos": Vector2(0, 0), "radius": 12.0, "label": "Ashgrove"},
			"north_gate": {"pos": Vector2(0, -50), "radius": 8.0, "label": "North gate"},
			"east_gate": {"pos": Vector2(52, -5), "radius": 8.0, "label": "East gate"},
			"west_gate": {"pos": Vector2(-52, 7), "radius": 8.0, "label": "West gate"},
			"square": {"pos": Vector2(0, 0), "radius": 22.0, "label": "Town square"},
		},
	}


static func briar_pass() -> Dictionary:
	return {
		"name": "Briar Pass",
		"theme": "forest",
		"size": Vector2(100, 130),
		"obstacles": [
			{"kind": "cliff", "rect": Rect2(-50, -65, 30, 40)},
			{"kind": "cliff", "rect": Rect2(-50, -25, 34, 30)},
			{"kind": "cliff", "rect": Rect2(-50, 5, 28, 60)},
			{"kind": "cliff", "rect": Rect2(20, -65, 30, 40)},
			{"kind": "cliff", "rect": Rect2(16, -25, 34, 30)},
			{"kind": "cliff", "rect": Rect2(22, 5, 28, 60)},
			{"kind": "rock", "circle": Vector3(-6, -40, 2.5)},
			{"kind": "rock", "circle": Vector3(9, 30, 2.5)},
		],
		"dynamic_obstacles": {
			"thornwall": {"kind": "thornwall", "rect": Rect2(-16, -9, 32, 3)},
		},
		"roads": [
			{"points": [Vector2(0, -65), Vector2(-2, -20), Vector2(0, 20), Vector2(0, 65)], "width": 5.0},
		],
		"decor": [
			{"kind": "pine", "pos": Vector2(-10, -56)},
			{"kind": "pine", "pos": Vector2(12, -52)},
			{"kind": "tree", "pos": Vector2(-12, 44)},
			{"kind": "tree", "pos": Vector2(14, 50)},
			{"kind": "tent", "pos": Vector2(-6, 54)},
			{"kind": "tent", "pos": Vector2(8, 58), "rot": 20},
		],
		"zones": {
			"pass": {"pos": Vector2(0, -4), "radius": 14.0, "label": "Briar Pass"},
			"north": {"pos": Vector2(0, -58), "radius": 10.0, "label": "North approach"},
			"south_camp": {"pos": Vector2(0, 52), "radius": 10.0, "label": "Convocation road"},
		},
	}


static func vault() -> Dictionary:
	return {
		"name": "The Vault of the First Command",
		"theme": "vault",
		"size": Vector2(160, 170),
		"obstacles": [
			{"kind": "cliff", "rect": Rect2(-80, -85, 160, 8)},
			{"kind": "wall", "rect": Rect2(-16, -77, 32, 7)},
			{"kind": "wall", "rect": Rect2(-30, -64, 2, 24)},
			{"kind": "wall", "rect": Rect2(28, -64, 2, 24)},
			{"kind": "chasm", "rect": Rect2(-80, -45, 26, 10)},
			{"kind": "chasm", "rect": Rect2(-46, -45, 16, 10)},
			{"kind": "water", "rect": Rect2(-62, 42, 52, 28)},
			{"kind": "water", "rect": Rect2(10, 42, 52, 28)},
			{"kind": "water", "rect": Rect2(-80, 0, 8, 40)},
			{"kind": "rock", "circle": Vector3(40, -52, 5)},
			{"kind": "rock", "circle": Vector3(58, -30, 4)},
			{"kind": "rock", "circle": Vector3(26, -34, 3)},
			{"kind": "rock", "circle": Vector3(46, 4, 4)},
			{"kind": "rock", "circle": Vector3(-44, 6, 4)},
			{"kind": "rock", "circle": Vector3(-24, 24, 3)},
			{"kind": "rock", "circle": Vector3(24, 24, 3)},
		],
		"roads": [
			{"points": [Vector2(0, 85), Vector2(0, 40), Vector2(0, -20), Vector2(0, -62)], "width": 7.0},
			{"points": [Vector2(72, -64), Vector2(44, -42), Vector2(16, -50), Vector2(0, -58)], "width": 4.0},
			{"points": [Vector2(-66, 20), Vector2(-40, 0), Vector2(0, -20)], "width": 4.0},
			{"points": [Vector2(64, 40), Vector2(60, 10), Vector2(30, -10), Vector2(0, -20)], "width": 4.0, "kind": "riverbed"},
		],
		"decor": [
			{"kind": "vault_door", "pos": Vector2(0, -70)},
			{"kind": "standing_stone", "pos": Vector2(-14, -58)},
			{"kind": "standing_stone", "pos": Vector2(14, -58)},
			{"kind": "standing_stone", "pos": Vector2(-14, -44)},
			{"kind": "standing_stone", "pos": Vector2(14, -44)},
			{"kind": "tent", "pos": Vector2(-10, -18)},
			{"kind": "tent", "pos": Vector2(10, -22), "rot": 30},
			{"kind": "banner", "pos": Vector2(-4, -26), "color": Color("#9b3b2a")},
			{"kind": "banner", "pos": Vector2(4, -26), "color": Color("#5a7d3a")},
			{"kind": "banner", "pos": Vector2(-8, -12), "color": Color("#6a8fa0")},
			{"kind": "banner", "pos": Vector2(8, -12), "color": Color("#7d6a8a")},
			{"kind": "root_bridge", "pos": Vector2(-50, -40)},
			{"kind": "tent", "pos": Vector2(64, -6), "rot": 15},
			{"kind": "tent", "pos": Vector2(66, 34), "rot": -15},
			{"kind": "tent", "pos": Vector2(70, 64)},
			{"kind": "cairn", "pos": Vector2(50, -44)},
			{"kind": "dead_tree", "pos": Vector2(62, -52)},
			{"kind": "pine", "pos": Vector2(-60, -20)},
			{"kind": "pine", "pos": Vector2(-66, -6)},
		],
		"zones": {
			"vault_gate": {"pos": Vector2(0, -60), "radius": 8.0, "label": "Vault door"},
			"chamber": {"pos": Vector2(0, -52), "radius": 14.0, "label": "Listening chamber"},
			"allied_camp": {"pos": Vector2(0, -18), "radius": 14.0, "label": "Convocation camp"},
			"causeway": {"pos": Vector2(0, 40), "radius": 12.0, "label": "King's causeway"},
			"causeway_south": {"pos": Vector2(0, 78), "radius": 8.0, "label": "Causeway foot"},
			"spillway": {"pos": Vector2(60, 20), "radius": 14.0, "label": "Dry spillway"},
			"camp_north": {"pos": Vector2(64, -6), "radius": 6.0, "label": "North camp"},
			"camp_south": {"pos": Vector2(66, 34), "radius": 6.0, "label": "South camp"},
			"camp_far": {"pos": Vector2(70, 64), "radius": 6.0, "label": "Far camp"},
			"stair": {"pos": Vector2(-62, 16), "radius": 10.0, "label": "Tide Stair"},
			"stair_foot": {"pos": Vector2(-64, 70), "radius": 8.0, "label": "Stair foot"},
			"root_bridge": {"pos": Vector2(-50, -40), "radius": 8.0, "label": "Root bridge"},
			"bridge_north": {"pos": Vector2(-50, -62), "radius": 8.0, "label": "Northern ledge"},
			"bridge_south": {"pos": Vector2(-50, -20), "radius": 8.0, "label": "Southern ledge"},
			"restless_road": {"pos": Vector2(44, -42), "radius": 10.0, "label": "Restless road"},
			"east_start": {"pos": Vector2(72, -64), "radius": 6.0, "label": "Eastern track"},
		},
	}
