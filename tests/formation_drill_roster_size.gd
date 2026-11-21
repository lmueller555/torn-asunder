extends SceneTree

const Drills := preload("res://game/combat/drills.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const PlatoonSize := preload("res://game/combat/platoon_size.gd")
const Unit := preload("res://game/combat/combat_unit.gd")


func _initialize() -> void:
	var drill := Drills._formation_drill_platoon(1)
	var constructed := drill._roster.size() == PlatoonSize.REGULAR_MELEE
	var identities := {}
	for soldier in drill._roster:
		identities[soldier.get_instance_id()] = true
	drill.hit_unit(0, Unit.new(), {Unit.Damage.MELEE: Unit.STARTING_HP})
	var causal := not drill._roster[0].is_alive() and is_equal_approx(
		drill.health_fractions().z, 1.0 / PlatoonSize.REGULAR_MELEE)
	var after := drill.cohesion
	drill.reform(2.0)
	var metrics := Drills.run(&"formation_drill", 1) == ["%.1f%%" % after, "%.1f%%" % drill.cohesion]
	var old_examples := true
	for skill in [Platoon.Skill.CHARGE_BRACE, Platoon.Skill.MOUNTED_TRAINING, Platoon.Skill.SCOUTING,
			Platoon.Skill.SIEGECRAFT, Platoon.Skill.BEAST_HANDLING]:
		old_examples = old_examples and Drills._platoon(skill, 1)._roster.size() == 10
	var described := false
	for row in Drills.EXERCISES:
		if row.id == &"formation_drill":
			described = ("%d-soldier infantry platoon" % PlatoonSize.REGULAR_MELEE) in row.description
	var result := constructed and identities.size() == PlatoonSize.REGULAR_MELEE and causal and metrics and old_examples and described
	print("FORMATION DRILL ROSTER: ", "PASS" if result else "FAIL",
		" real infantry=", drill._roster.size(), " survivors=", identities.size() - int(causal), " other examples retain 10")
	quit(0 if result else 1)
