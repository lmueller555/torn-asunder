extends RefCounted

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const PlatoonSize := preload("res://game/combat/platoon_size.gd")
const SMALL_EXAMPLE_SIZE := 10

const EXERCISES: Array[Dictionary] = [
	{
		"id": &"charge_brace",
		"name": "Charge & Brace",
		"description": "Hit a braced rank 2 platoon, then brace against that platoon’s charge. The table shows cohesion lost on impact.",
		"metrics": ["Enemy cohesion lost", "Your cohesion lost"],
	},
	{
		"id": &"mounted_training",
		"name": "Mounted Training",
		"description": "Time a cavalry platoon through a turn, a charge setup, and a regroup.",
		"metrics": ["Turn", "Set up charge", "Regroup"],
	},
	{
		"id": &"formation_drill",
		"name": "Formation Drill",
		"description": "Take one casualty in a %d-soldier infantry platoon, then spend two seconds reforming." % PlatoonSize.REGULAR_MELEE,
		"metrics": ["Cohesion after casualty", "Cohesion after reforming"],
	},
	{
		"id": &"scouting",
		"name": "Scouting",
		"description": "Spot a platoon sheltering in brush 40 metres away. The scouts have an unobstructed line of sight.",
		"metrics": ["Detection in the open", "Detection through brush", "Enemy at 40 m"],
	},
	{
		"id": &"siegecraft",
		"name": "Siegecraft",
		"description": "Deploy a siege engine, aim at a target within range, and reload.",
		"metrics": ["Setup time", "Hit chance", "Reload time"],
	},
	{
		"id": &"beast_handling",
		"name": "Beast Handling",
		"description": "Issue an order to scattered war beasts at 40% cohesion, then rally them for three seconds.",
		"metrics": ["Cohesion needed to obey", "Order at 40% cohesion", "Cohesion after rally"],
	},
	{
		"id": &"curse",
		"name": "Curse",
		"description": "Trade Curse attacks worth 40 base damage with a unit that has a Curse rating of 1.",
		"metrics": ["Damage you deal", "Damage you take"],
		"damage_rating": true,
	},
]


static func run(exercise: StringName, level: int) -> Array[String]:
	match exercise:
		&"charge_brace":
			var platoon := _platoon(Platoon.Skill.CHARGE_BRACE, level)
			var enemy := _platoon(Platoon.Skill.CHARGE_BRACE, 2)
			return ["%.0f" % platoon.charge(enemy, true), "%.0f" % enemy.charge(platoon, true)]
		&"mounted_training":
			var platoon := _platoon(Platoon.Skill.MOUNTED_TRAINING, level)
			return [
				"%.1f s" % platoon.mounted_maneuver_seconds(4.0),
				"%.1f s" % platoon.mounted_maneuver_seconds(6.0),
				"%.1f s" % platoon.mounted_maneuver_seconds(8.0),
			]
		&"formation_drill":
			var platoon := _formation_drill_platoon(level)
			platoon.hit_unit(0, Unit.new(), {Unit.Damage.MELEE: Unit.STARTING_HP})
			var after_casualty := platoon.cohesion
			platoon.reform(2.0)
			return ["%.1f%%" % after_casualty, "%.1f%%" % platoon.cohesion]
		&"scouting":
			var platoon := _platoon(Platoon.Skill.SCOUTING, level)
			return [
				"%.0f m" % platoon.detection_range(false),
				"%.0f m" % platoon.detection_range(true),
				"Spotted" if platoon.can_detect(40.0, true, true) else "Hidden",
			]
		&"siegecraft":
			var platoon := _platoon(Platoon.Skill.SIEGECRAFT, level)
			return [
				"%.1f s" % platoon.siege_setup_seconds(),
				"%.0f%%" % (platoon.siege_hit_chance() * 100.0),
				"%.1f s" % platoon.siege_reload_seconds(),
			]
		&"beast_handling":
			var platoon := _platoon(Platoon.Skill.BEAST_HANDLING, level)
			platoon.lose_cohesion(60.0)
			var accepts_order := platoon.beasts_follow_orders()
			platoon.rally_beasts(3.0)
			return [
				"%.0f%%" % platoon.beast_order_threshold(),
				"Obeys" if accepts_order else "Scattered",
				"%.0f%%" % platoon.cohesion,
			]
		&"curse":
			var unit := Unit.new(Unit.STARTING_HP, {Unit.Damage.CURSE: level})
			var enemy := Unit.new()
			var attack := {Unit.Damage.CURSE: 40.0}
			return ["%.1f HP" % enemy.receive_hit(unit, attack), "%.1f HP" % unit.receive_hit(enemy, attack)]
	return []


static func _formation_drill_platoon(training_rank: int) -> Platoon:
	return _platoon(Platoon.Skill.FORMATION_DRILL, training_rank, PlatoonSize.REGULAR_MELEE)


static func _platoon(skill: Platoon.Skill, training_rank: int, count: int = SMALL_EXAMPLE_SIZE) -> Platoon:
	var roster: Array[Unit] = []
	for index in range(count):
		roster.append(Unit.new())
	return Platoon.new(roster, {skill: training_rank})
