extends SceneTree

const Battle := preload("res://game/mission/mission_battle.gd")
const Missions := preload("res://game/mission/missions.gd")
const Size := preload("res://game/combat/platoon_size.gd")

var failures := 0


func _initialize() -> void:
	_check_non_regular_rosters()
	_check_formation_and_march()
	_check_terrain_fallback()
	_check_live_combat()
	if failures == 0:
		print("Generic platoons: five-by-six foot ranks and a separate fighter that marches, strikes, and falls; other rosters unchanged by the formation rule.")
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)


func _check_non_regular_rosters() -> void:
	var entries := [
		Missions._p("archers", &"marcher_archers", 0, 7, 4, Vector2(-20, 0), {"columns": 3}),
		Missions._p("riders", &"march_riders", 0, 12, 4, Vector2(20, 0)),
		Missions._p("civilians", &"miners", 2, 6, 4, Vector2(0, 20)),
		Missions._hero("officer", &"aldric", 0, 4, Vector2(0, -20)),
	]
	var battle := Battle.new({"platoons": entries}, &"mara", 4)
	for i in range(entries.size()):
		var squad := battle.squads[i]
		var expected: int = [7, 12, 6, 1][i]
		_expect(entries[i].count == expected and squad.alive_count(battle) == expected,
			"Wrong authored headcount: " + squad.id)
		for member in squad.members:
			_expect(not battle.fighters[member].is_platoon_leader,
				"Non-regular roster gained a leader: " + squad.id)
	_expect(entries[0].columns == 3, "Ranged formation lost authored frontage.")


func _check_formation_and_march() -> void:
	var entry := Missions._p("foot", &"marcher_infantry", 0, 8, 4, Vector2.ZERO, {"columns": 2})
	_expect(entry.count == 31 and entry.columns == 5, "Catalogue did not normalize the foot platoon.")
	# Raw authored dictionaries also get the same layout (including reinforcements).
	entry.count = 8
	entry.columns = 2
	entry.hidden = true
	entry.facing = Vector2.RIGHT
	var battle := Battle.new({"hero": {"pos": Vector2(-30, 0)}, "platoons": [entry]}, &"mara", 4)
	var squad := battle.squads[0]
	battle._spawn_squad(squad)
	_expect(squad.alive_count(battle) == 31, "Hidden squad failed to spawn a full platoon.")
	if squad.members.size() != 31:
		return
	var spacing := Battle.SLOT_SPACING
	var units := {}
	var right := Vector2(-squad.facing.y, squad.facing.x)
	for i in range(Size.REGULAR_MELEE):
		var troop := battle.fighters[squad.members[i]]
		var expected := Vector2(i % 5 - 2, -floori(float(i) / 5.0)) * spacing
		_expect(not troop.is_platoon_leader and troop.slot == expected,
			"Regular troop %d is not in its five-by-six slot." % i)
		var foot := squad.anchor + right * expected.x + squad.facing * expected.y
		_expect(troop.position.is_equal_approx(foot), "Open terrain should reproduce the ordered slots.")
		units[troop.unit.get_instance_id()] = true
	var leader := battle.fighters[squad.members.back()]
	_expect(leader.is_platoon_leader and leader.kind == Battle.Kind.SOLDIER
		and leader.slot == Vector2(0, spacing) and leader.position == Vector2(spacing, 0),
		"Last roster member must be a soldier centered a step forward of the first rank.")
	_expect(not units.has(leader.unit.get_instance_id()) and leader.unit.max_hp == battle.fighters[squad.members[0]].unit.max_hp,
		"Leader must have independent, ordinary soldier health.")
	battle.command(squad.index, {"kind": "move", "to": Vector2(13, 0)})
	for frame in range(8 * 60):
		battle.step(1.0 / 60.0)
	_expect(squad.anchor.is_equal_approx(Vector2(13, 0))
		and leader.position.distance_to(squad.anchor + Vector2(spacing, 0)) < 0.35
		and battle.fighters[squad.members.back()] == leader,
		"The same fighting leader should march in front and settle at its own slot.")


func _check_terrain_fallback() -> void:
	var entry := Missions._p("foot", &"marcher_infantry", 0, 10, 4, Vector2.ZERO)
	var obstacle := {"rect": Rect2(-2, -2, 4, 1)}
	var battle := Battle.new({"hero": {"pos": Vector2(-30, 0)}, "map": {"obstacles": [obstacle]},
		"platoons": [entry]}, &"mara", 4)
	var squad := battle.squads[0]
	_expect(squad.alive_count(battle) == 31, "Blocked leader slot must not truncate the roster.")
	var earlier: Array[Battle.Fighter] = []
	for index in squad.members:
		var fighter := battle.fighters[index]
		_expect(not battle._blocked(fighter.position, fighter.radius), "Fallback landed on blocked terrain.")
		for other in earlier:
			_expect(fighter.position.distance_to(other.position) + 0.001 >= fighter.radius + other.radius,
				"Fallback stacked two troop bodies.")
		earlier.append(fighter)


func _check_live_combat() -> void:
	var friendly := Missions._p("foot", &"marcher_infantry", 0, 10, 4, Vector2.ZERO)
	var hostile := Missions._p("foe", &"basin_warriors", 1, 10, 4, Vector2(0, -4.35))
	var battle := Battle.new({"hero": {"pos": Vector2(-30, 0)}, "platoons": [friendly, hostile]}, &"mara", 4)
	var blue := battle.squads[0]
	var red := battle.squads[1]
	if blue.members.size() != 31 or red.members.size() != 31:
		_expect(false, "Both combat formations require a full roster.")
		return
	for squad in battle.squads:
		for i in range(Size.REGULAR_MELEE):
			var troop := battle.fighters[squad.members[i]]
			troop.rooted_until = INF
			# Isolate the front-rank leaders so normal AI resolves the duel.
			troop.position.x += -24.0 if squad == blue else 24.0
	var leader := battle.fighters[blue.members.back()]
	var opponent := battle.fighters[red.members.back()]
	for frame in range(6 * 60):
		battle.step(1.0 / 60.0)
		if leader.unit.hp < leader.unit.max_hp and opponent.unit.hp < opponent.unit.max_hp:
			break
	_expect(leader.last_hurt >= 0 and opponent.last_hurt >= 0
		and leader.target == opponent.index and opponent.target == leader.index,
		"Leaders should target and damage each other in ordinary battle ticks.")
	leader.unit.receive_damage(leader.unit.hp - 1.0)
	for frame in range(12 * 60):
		battle.step(1.0 / 60.0)
		if not leader.is_alive():
			break
	_expect(not leader.is_alive() and leader.state == Battle.State.DEAD and blue.alive_count(battle) == 30
		and battle.player_losses == 1 and opponent.kills == 1 and blue.combat.health_fractions().z > 0.0
		and blue.combat.cohesion < 100.0,
		"A defeated leader must become a real casualty in the ordinary platoon roster.")
