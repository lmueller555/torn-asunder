extends SceneTree

const Sequence := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const SPECIAL := Sequence.Attack.SUNDERING_STRIKE
const LIGHT := Sequence.Attack.LIGHT
const HEAVY := Sequence.Attack.HEAVY


func _initialize() -> void:
	var passed := _check_exact_payment_and_damage()
	passed = _check_rejections_and_basic_attacks() and passed
	passed = _check_miss_and_cancellation() and passed
	passed = _check_defense_admission() and passed
	if passed:
		print("Verified Sundering Strike payment, no self-funding, and unchanged basic/defense admission.")
	quit(0 if passed else 1)


func _check_exact_payment_and_damage() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	var profile: Dictionary = Sequence.PROFILES[SPECIAL]
	var heavy_profile: Dictionary = Sequence.PROFILES[HEAVY]
	if profile.damage <= heavy_profile.damage or profile.windup <= heavy_profile.windup:
		return _fail("The paid special lacked a distinct strike profile.")
	var cost: int = profile.bp_cost
	pool.try_spend(pool.balance - cost, true)
	if not sequence.start(SPECIAL, true) or pool.balance != 0:
		return _fail("The exact cost did not commit at the start of the windup.")
	if _advance(sequence, profile.windup * 0.5, enemy) or enemy.hp != enemy.max_hp:
		return _fail("Paid damage resolved before contact.")
	var hit := _advance(sequence, profile.windup * 0.5, enemy)
	var expected := enemy.damage_from(hero, {Unit.Damage.MELEE: profile.damage})
	if not hit or hit.attack != SPECIAL or not is_equal_approx(hit.hp_lost, expected):
		return _fail("The special failed to resolve its damage through the existing rules.")
	if hit.bp_credited != 0 or pool.balance != 0:
		return _fail("The special funded itself from its own confirmed contact.")
	var hp := enemy.hp
	if _advance(sequence, profile.recovery, enemy) or enemy.hp != hp or sequence.phase != Sequence.Phase.IDLE:
		return _fail("The special repeated damage or failed to finish recovery.")
	return true


func _check_rejections_and_basic_attacks() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	var cost: int = Sequence.PROFILES[SPECIAL].bp_cost
	var start := pool.balance
	if sequence.start(SPECIAL, false) or pool.balance != start:
		return _fail("A special spent points after battle end.")
	if Sequence.new(hero, 0, null).start(SPECIAL, true):
		return _fail("A paid special was admitted without a shared pool.")
	if not sequence.start(LIGHT, true) or pool.balance != start:
		return _fail("Light attack began spending BP.")
	if sequence.start(SPECIAL, true) or pool.balance != start:
		return _fail("A rejected special spent BP during another windup.")
	_advance(sequence, 2.0, enemy)
	pool.try_spend(pool.balance - cost + 1, true)
	if sequence.start(SPECIAL, true) or sequence.phase != Sequence.Phase.IDLE or pool.balance != cost - 1:
		return _fail("A special with insufficient BP mutated the sequence or pool.")
	if not sequence.start(HEAVY, true) or pool.balance != cost - 1:
		return _fail("Low BP gated or charged the free heavy attack.")
	var heavy := _advance(sequence, 2.0, enemy)
	if not heavy or heavy.bp_credited != Sequence.PROFILES[HEAVY].bp:
		return _fail("A confirmed basic attack stopped earning BP.")
	return true


func _check_miss_and_cancellation() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	var cost: int = Sequence.PROFILES[SPECIAL].bp_cost
	var balance := pool.balance
	if not sequence.start(SPECIAL, true) or sequence.start(SPECIAL, true) or pool.balance != balance - cost:
		return _fail("Repeated special input charged more than one admission.")
	var miss := sequence.advance(2.0, true, Vector2.ZERO, Vector2.RIGHT, enemy, 1, Vector2(10, 0))
	if not miss or miss.hp_lost != 0.0 or miss.bp_credited != 0 or pool.balance != balance - cost:
		return _fail("A miss changed the prepaid cost, earned BP or damaged the target.")
	if not sequence.start(SPECIAL, true):
		return _fail("A fresh special was not admitted after the miss.")
	var result := sequence.advance(2.0, false, Vector2.ZERO, Vector2.RIGHT, enemy, 1, Vector2.RIGHT)
	if result or sequence.phase != Sequence.Phase.IDLE or pool.balance != balance - 2 * cost or enemy.hp != enemy.max_hp:
		return _fail("Battle end allowed a prepaid swing to hit or changed its payment.")
	return true


func _check_defense_admission() -> bool:
	var pool := Points.new()
	var defense := Defense.new(Unit.new(), 0, pool)
	var start := pool.balance
	if not defense.set_guard(true, true) or defense.start_attack(SPECIAL, true) or pool.balance != start:
		return _fail("Guard did not reject the special before charging points.")
	defense.set_guard(false, true)
	if not defense.start_dodge(Vector2.RIGHT, true) or defense.start_attack(SPECIAL, true) or pool.balance != start:
		return _fail("Dodge did not reject the special before charging points.")
	defense.advance_defense(2.0, true)
	if not defense.start_attack(SPECIAL, true) or pool.balance != start - Sequence.PROFILES[SPECIAL].bp_cost:
		return _fail("Special admission did not return after dodge or failed to spend BP.")
	if defense.start_dodge(Vector2.RIGHT, true) or defense.set_guard(true, true):
		return _fail("Defense was able to cancel the special windup.")
	return true


func _advance(sequence: Sequence, delta: float, enemy: Unit) -> Sequence.Contact:
	return sequence.advance(delta, true, Vector2.ZERO, Vector2.RIGHT, enemy, 1, Vector2.RIGHT)


func _fail(message: String) -> bool:
	push_error(message)
	return false
