extends SceneTree

const Size := preload("res://game/combat/platoon_size.gd")
const Arena := preload("res://game/combat/infantry_skirmish.gd")
const Battle := preload("res://game/mission/mission_battle.gd")
const Missions := preload("res://game/mission/missions.gd")
const Units := preload("res://game/mission/mission_units.gd")

var errors := PackedStringArray()

func _initialize() -> void:
	check(Size.count_for(6,true)==31 and Size.count_for(7,false)==7, "Canonical count")
	check(Arena.PLATOON_SIZE==31 and Arena.FORMATION_COLUMNS==5 and Size.REGULAR_MELEE_RANKS==6, "Existing arena count/shape")
	var scanned := 0
	var melee := 0
	var duplicate_starts := 0
	for campaign in ["mara","raska","sova","ilyra","sereth","neris"]:
		for data: Dictionary in Missions.for_campaign(campaign):
			scanned+=1
			var battle := Battle.new(data,StringName(campaign),4)
			for squad: Battle.Squad in battle.squads:
				if not squad.spawned:
					battle._spawn_squad(squad)
				var entry := squad.definition
				var regular := Units.is_regular_melee(squad.type_id)
				var expected: int = Size.PLATOON_WITH_LEADER if regular else entry.get("count",16)
				if regular:
					melee+=1
				check(squad.members.size()==expected,"%s/%s actual members %d, expected %d" % [data.id,squad.id,squad.members.size(),expected])
				var member_units := {}
				var positions := {}
				var walked: Array[Battle.Fighter] = []
				for id: int in squad.members:
					var fighter := battle.fighters[id]
					member_units[fighter.unit.get_instance_id()]=true
					positions[fighter.position]=true
					if regular:
						check(battle.bounds.grow(-fighter.radius).has_point(fighter.position) and not battle._blocked(fighter.position,fighter.radius),
							"Unsupported placement in "+squad.id)
						for other: Battle.Fighter in walked:
							check(fighter.position.distance_to(other.position)>.999*(fighter.radius+other.radius),
								"Overlapping melee body in "+squad.id)
						walked.append(fighter)
					check(fighter.unit.is_alive(),"Member spawned defeated in "+squad.id)
				check(member_units.size()==expected,"Members share their Unit state in "+squad.id)
				if regular and positions.size()!=expected:
					duplicate_starts+=1
					check(false,"Duplicate positions in "+squad.id)
					print("Duplicate at ",data.id,"/",squad.id,": ",expected-positions.size())
	print("Campaign checks: ",scanned," mission catalogs; ",melee," melee platoons; ",duplicate_starts," with overlapping positions on spawn.")
	for failure in errors:
		printerr(failure)
	quit(0 if errors.is_empty() else 1)


func check(ok: bool, note: String) -> void:
	if not ok:
		errors.append(note)
