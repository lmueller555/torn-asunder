extends SceneTree

const Elemental := preload("res://game/combat/elemental_affinity.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Ice := preload("res://game/combat/targeted_ice_cast.gd")
const Points := preload("res://game/combat/battle_points.gd")
const BASE := 45.0

var _failures := 0


func _initialize() -> void:
	_check_affinity_and_ratings()
	_check_field_effect_in_motion()
	_check_target_and_terrain_admission()
	if _failures == 0:
		print("Elemental affinity: one typed counter, existing ratings and HP, living-target saturated-ground drag, actual movement/expiry and ordinary caster isolation passed.")
	quit(0 if _failures == 0 else 1)


func _check_affinity_and_ratings() -> void:
	var caster := Unit.new(Unit.STARTING_HP, {Unit.Damage.ICE: 25, Unit.Damage.NATURE: 100})
	var caster_hp := caster.hp
	var ratings := {Unit.Damage.ICE: 40, Unit.Damage.NATURE: 100}
	var ordinary := Unit.new(Unit.STARTING_HP, ratings)
	var elemental := Unit.new(Unit.STARTING_HP, ratings)
	for unit in [caster, ordinary, elemental]:
		unit.award_experience(640)
	var dry := _facts(Elemental.Ground.DRY)
	var expected := ordinary.damage_from(caster, {Unit.Damage.ICE: BASE})
	var baseline := Elemental.resolve(caster, Elemental.Subject.new(ordinary), Unit.Damage.ICE, BASE, dry)
	var counter := Elemental.resolve(caster, Elemental.Subject.new(elemental, Elemental.Affinity.ROOT), Unit.Damage.ICE, BASE, dry)
	_check(not baseline.affinity_counter and is_equal_approx(baseline.damage_done, expected)
		and counter.affinity_counter and is_equal_approx(counter.damage_done, expected * Elemental.ROOT_ICE_MULTIPLIER)
		and not counter.root_drag and is_equal_approx(elemental.max_hp - elemental.hp, counter.damage_done),
		"Ice must preserve existing ratings and damage scaling, adding only the Root multiplier.")
	_check(is_equal_approx(caster.hp / caster.max_hp, caster_hp / Unit.STARTING_HP), "The source is not affected by its own hit.")
	var weak_defense := Unit.new()
	var strong_defense := Unit.new(Unit.STARTING_HP, {Unit.Damage.ICE: 100})
	var low := Elemental.resolve(caster, Elemental.Subject.new(weak_defense, Elemental.Affinity.ROOT), Unit.Damage.ICE, BASE, dry)
	var high := Elemental.resolve(caster, Elemental.Subject.new(strong_defense, Elemental.Affinity.ROOT), Unit.Damage.ICE, BASE, dry)
	_check(low.damage_done > high.damage_done, "Affinity cannot erase the defender's actual Ice rating.")
	var root := Unit.new()
	var ordinary_type := Elemental.resolve(caster, Elemental.Subject.new(root, Elemental.Affinity.ROOT),
		Unit.Damage.NATURE, BASE, _facts(Elemental.Ground.SATURATED))
	_check(not ordinary_type.affinity_counter and not ordinary_type.root_drag
		and is_equal_approx(ordinary_type.damage_done, root.damage_from(caster, {Unit.Damage.NATURE: BASE})),
		"Other damage elements neither invent counters nor trigger the terrain effect.")


func _check_field_effect_in_motion() -> void:
	var caster := Unit.new(Unit.STARTING_HP, {Unit.Damage.ICE: 25})
	var body := Unit.new()
	var wet := _facts(Elemental.Ground.SATURATED)
	var hit := Elemental.resolve(caster, Elemental.Subject.new(body, Elemental.Affinity.ROOT), Unit.Damage.ICE, BASE, wet)
	if not hit.root_drag:
		_check(false, "A living root elemental hit by Ice on saturated ground should get drag.")
		return
	var drag := hit.root_drag
	var battle := Battle.new()
	battle.hero_position = Vector2.ZERO
	# Drag applies to the leader steered directly in combat.
	battle.lead_engaged = true
	drag.advance(NAN)
	drag.advance(-1.0)
	_check(drag.remaining == Elemental.ROOT_DRAG_SECONDS and drag.movement_scale == Elemental.ROOT_DRAG_MOVEMENT,
		"Invalid time cannot run the temporary effect down.")
	# A future scene consumes the temporary scale; compare actual CommandBattle
	# movement under it to full speed once the same effect expires.
	battle.step(1.0, Vector2.RIGHT * drag.movement_scale)
	drag.advance(1.0)
	_check(is_equal_approx(battle.hero_position.x, Battle.HERO_SPEED * Elemental.ROOT_DRAG_MOVEMENT)
		and drag.remaining > 0.0, "The temporary modifier must reduce observed movement while active.")
	drag.advance(1.0)
	var before := battle.hero_position.x
	battle.step(1.0, Vector2.RIGHT * drag.movement_scale)
	_check(drag.remaining == 0.0 and is_equal_approx(battle.hero_position.x - before, Battle.HERO_SPEED),
		"Expiration restores ordinary movement without changing the unit's ratings.")

	var non_elemental := Unit.new(Unit.STARTING_HP, {Unit.Damage.NATURE: 100, Unit.Damage.ICE: 100})
	var ordinary_hit := Elemental.resolve(caster, Elemental.Subject.new(non_elemental), Unit.Damage.ICE, BASE, wet)
	_check(not ordinary_hit.affinity_counter and not ordinary_hit.root_drag,
		"An ordinary high-rated caster does not turn into a root elemental on saturated ground.")
	var spell := Ice.new(Points.new())
	_check(spell.begin(non_elemental, body, 5.0, true)
		and spell.advance(Ice.WINDUP_SECONDS, 5.0, true) == Ice.Phase.RELEASED
		and spell.damage_done > 0.0, "That same ordinary caster can use the existing Ice model without elemental identity.")


func _check_target_and_terrain_admission() -> void:
	var attacker := Unit.new()
	var defender := Unit.new()
	var root := Elemental.Subject.new(defender, Elemental.Affinity.ROOT)
	var wet := _facts(Elemental.Ground.SATURATED)
	var blocked := _facts(Elemental.Ground.SATURATED)
	blocked.lane_clear = false
	var allied := _facts(Elemental.Ground.SATURATED)
	allied.opposing = false
	for facts in [blocked, allied, null]:
		var miss := Elemental.resolve(attacker, root, Unit.Damage.ICE, BASE, facts)
		_check(miss.damage_done == 0.0 and not miss.affinity_counter and not miss.root_drag,
			"Blocked, allied and missing hit observations must not produce a counter or an effect.")
	for invalid in [NAN, INF, -1.0, 0.0]:
		_check(Elemental.resolve(attacker, root, Unit.Damage.ICE, invalid, wet).damage_done == 0.0,
			"A non-finite or non-positive base hit must be harmless.")
	_check(defender.hp == defender.max_hp and Elemental.resolve(defender, root, Unit.Damage.ICE, BASE, wet).damage_done == 0.0,
		"No rejected hit or self-targeting may change health.")
	var unclear := Elemental.resolve(attacker, root, Unit.Damage.ICE, BASE, _facts(Elemental.Ground.UNKNOWN))
	_check(unclear.affinity_counter and not unclear.root_drag, "Unknown ground cannot stand in for a saturated tile.")
	defender.receive_damage(defender.hp - 1.0)
	var fatal := Elemental.resolve(attacker, root, Unit.Damage.ICE, BASE, wet)
	_check(fatal.damage_done == 1.0 and not defender.is_alive() and fatal.affinity_counter and not fatal.root_drag,
		"A lethal counter caps damage at remaining HP without giving a fallen unit a movement effect.")
	_check(Elemental.resolve(attacker, root, Unit.Damage.ICE, BASE, wet).damage_done == 0.0,
		"A defeated target cannot trigger a follow-up counter.")


func _facts(ground: Elemental.Ground) -> Elemental.HitFacts:
	var facts := Elemental.HitFacts.new()
	facts.opposing = true
	facts.lane_clear = true
	facts.defender_ground = ground
	return facts


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
