extends SceneTree

const Pulse := preload("res://game/combat/elite_support_pulse.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Ice := preload("res://game/combat/targeted_ice_cast.gd")
const Siege := preload("res://game/combat/siege_preparation.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

const ORIGIN := Vector2(1.0, 0.0)
const CENTER := Vector2(6.0, 0.0)
var _failures := 0


func _initialize() -> void:
	_check_admission_and_shared_spend()
	_check_live_positions_and_one_impact()
	_check_disruption_and_reuse()
	_check_distinct_siege_use()
	if _failures == 0:
		print("Elite support: real Beast Handling/cohesion and shared BP, moving/covered counters, single cohesion impact, interruption and Siege contrast passed.")
	quit(0 if _failures == 0 else 1)


func _check_admission_and_shared_spend() -> void:
	var points := Points.new()
	var undertrained := Platoon.new([Unit.new()], {Platoon.Skill.BEAST_HANDLING: 1, Platoon.Skill.SIEGECRAFT: 5})
	_check(not Pulse.new(undertrained, points).begin(ORIGIN, CENTER, true, true),
		"An ordinary Siegecraft investment never substitutes for Beast Handling.")
	var beast := _beast()
	var support := Pulse.new(beast, points)
	beast.lose_cohesion(57.0)
	_check(not support.begin(ORIGIN, CENTER, true, true), "A beast below its trained order threshold cannot announce a pulse.")
	beast.rally_beasts(0.2)
	_check(not support.begin(ORIGIN, CENTER, false, true) and not support.begin(ORIGIN, CENTER, true, false)
		and not support.begin(ORIGIN, ORIGIN + Vector2(Pulse.PLACEMENT_RANGE + 0.01, 0.0), true, true)
		and not support.begin(Vector2(INF, 0.0), CENTER, true, true)
		and not support.begin(ORIGIN, Vector2(NAN, 0.0), true, true) and points.balance == Points.STARTING_BALANCE,
		"Invalid ground, range and visibility fail without BP spending.")
	var caster := Ice.new(points)
	_check(caster.begin(Unit.new(Unit.STARTING_HP, {Unit.Damage.ICE: 6}), Unit.new(), 4.0, true)
		and support.begin(ORIGIN, ORIGIN + Vector2(Pulse.PLACEMENT_RANGE, 0.0), true, true)
		and points.balance == Points.STARTING_BALANCE - Ice.COST - Pulse.COST,
		"An Ice cast and the exact-range pulse debit the same team pool.")
	var locked := support.center
	_check(not support.begin(ORIGIN, CENTER, true, true) and support.center == locked
		and points.balance == Points.STARTING_BALANCE - Ice.COST - Pulse.COST,
		"A second order cannot move or recharge an announced ground tell.")
	var second := Pulse.new(_beast(), points)
	_check(second.begin(ORIGIN, CENTER, true, true) and points.balance == 0,
		"A second ability can commit only the remaining shared BP.")
	_check(not Pulse.new(_beast(), points).begin(ORIGIN, CENTER, true, true) and points.balance == 0,
		"Not enough BP cannot buy a tell or create any debt.")


func _check_live_positions_and_one_impact() -> void:
	var points := Points.new()
	var beast := _beast()
	var support := Pulse.new(beast, points)
	var field := Battle.new()
	var escaping := Platoon.new([Unit.new()])
	var holding := Platoon.new([Unit.new()])
	var covered := Platoon.new([Unit.new()])
	var allied := Platoon.new([Unit.new()])
	var downed := Platoon.new([Unit.new()])
	downed.apply_damage(0, Unit.STARTING_HP)
	var downed_cohesion := downed.cohesion
	var trained := Platoon.new([Unit.new()], {Platoon.Skill.FORMATION_DRILL: 5})
	field.formations[0].position = CENTER + Vector2(1.5, 0.0)
	field.formations[1].position = CENTER + Vector2(0.0, Pulse.RADIUS)
	_check(support.begin(ORIGIN, CENTER, true, true) and support.tell_remaining == Pulse.TELL_SECONDS,
		"The actual ground center must be announced for the complete tell.")
	_check(support.advance(NAN, ORIGIN, true, true) == Pulse.Phase.ANNOUNCED
		and support.tell_remaining == Pulse.TELL_SECONDS, "Malformed elapsed time must not skip a valid tell.")
	field.order_move(0, CENTER + Vector2(6.0, 0.0))
	var first_step := Pulse.TELL_SECONDS * 0.5
	field.step(first_step, Vector2.ZERO)
	support.advance(first_step, ORIGIN, true, true, [
		Pulse.Contact.new(escaping, field.formations[0].position, true, true),
		Pulse.Contact.new(holding, field.formations[1].position, true, true),
	])
	_check(support.tell_remaining > 0.0 and escaping.cohesion == 100.0 and holding.cohesion == 100.0,
		"The warning itself cannot deal pressure.")
	field.step(first_step, Vector2.ZERO)
	var contacts: Array[Pulse.Contact] = [
		Pulse.Contact.new(escaping, field.formations[0].position, true, true),
		Pulse.Contact.new(holding, field.formations[1].position, true, true),
		Pulse.Contact.new(holding, field.formations[1].position, true, true),
		Pulse.Contact.new(covered, CENTER, true, false),
		Pulse.Contact.new(allied, CENTER, false, true),
		Pulse.Contact.new(downed, CENTER, true, true),
		Pulse.Contact.new(beast, CENTER, true, true),
		Pulse.Contact.new(trained, CENTER, true, true),
		null,
	]
	_check(support.advance(first_step, ORIGIN, true, true, contacts) == Pulse.Phase.RESOLVED,
		"The actual split-step tell should resolve deterministically.")
	var reduced := Pulse.COHESION_PRESSURE / (1.0 + 0.12 * 5.0)
	_check(escaping.cohesion == 100.0 and covered.cohesion == 100.0 and allied.cohesion == 100.0 \
		and beast.cohesion == 100.0 and downed.cohesion == downed_cohesion,
		"A formation that moved out, gained cover, is allied, defeated, or the source gets no pressure.")
	_check(support.affected_count == 2 and holding.cohesion == 100.0 - Pulse.COHESION_PRESSURE
		and is_equal_approx(trained.cohesion, 100.0 - reduced)
		and is_equal_approx(support.pressure_dealt(trained), reduced),
		"Only living exposed enemies at release take one actual cohesion loss, reduced by Formation Drill.")
	support.advance(10.0, ORIGIN, true, true, contacts)
	_check(holding.health_fractions() == Vector3(1.0, 0.0, 0.0) and holding.cohesion == 100.0 - Pulse.COHESION_PRESSURE
		and points.balance == Points.STARTING_BALANCE - Pulse.COST,
		"A resolved tell never repeats, deals health damage, or farms BP.")


func _check_disruption_and_reuse() -> void:
	for cause in ["moved", "lane", "site", "cohesion", "dead", "disrupted"]:
		var beast_unit := Unit.new()
		var beast := Platoon.new([beast_unit], {Platoon.Skill.BEAST_HANDLING: 2})
		var points := Points.new()
		var support := Pulse.new(beast, points)
		var defender := Platoon.new([Unit.new()])
		_check(support.begin(ORIGIN, CENTER, true, true) and not support.reset_after_terminal(),
			"A new tell cannot be reset after BP commitment.")
		if cause == "cohesion":
			beast.lose_cohesion(57.0)
		elif cause == "dead":
			beast.apply_damage(0, Unit.STARTING_HP)
		var where := ORIGIN + Vector2(0.36, 0.0) if cause == "moved" else ORIGIN
		_check(support.advance(Pulse.TELL_SECONDS, where, cause != "site", cause != "lane",
			[Pulse.Contact.new(defender, CENTER, true, true)], cause == "disrupted") == Pulse.Phase.INTERRUPTED
			and support.affected_count == 0 and defender.cohesion == 100.0 and points.balance == Points.STARTING_BALANCE - Pulse.COST,
			"Disruption must beat same-tick impact without refund: %s." % cause)
		_check(support.reset_after_terminal() and support.phase == Pulse.Phase.IDLE and support.tell_remaining == 0.0,
			"Retry clears the old tell without touching shared BP.")
		if cause == "cohesion":
			beast.rally_beasts(0.2)
			_check(support.begin(ORIGIN, CENTER, true, true), "Trained rally can admit a new paid order after recovering.")


func _check_distinct_siege_use() -> void:
	var crew := Platoon.new([Unit.new()], {Platoon.Skill.SIEGECRAFT: 3})
	var siege := Siege.new(crew)
	siege.advance(0.0, ORIGIN, true, true, false)
	siege.advance(crew.siege_setup_seconds(), ORIGIN, true, true, false)
	var long_target := ORIGIN + Vector2(30.0, 0.0)
	var support := Pulse.new(_beast(), Points.new())
	_check(siege.fire(CENTER, true, 0.0) == null and not support.begin(ORIGIN, long_target, true, true),
		"The close pulse does not duplicate a long siege shot.")
	var shot := siege.fire(long_target, true, 0.0)
	_check(shot != null and shot.on_target and support.begin(ORIGIN, CENTER, true, true),
		"The existing prepared Siege shot and the short paid support tell each have their own lane.")


func _beast() -> Platoon:
	return Platoon.new([Unit.new()], {Platoon.Skill.BEAST_HANDLING: 2})


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
