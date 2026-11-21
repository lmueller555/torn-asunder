extends SceneTree

const Sequence := preload("res://game/combat/hero_attack_sequence.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const LIGHT := Sequence.Attack.LIGHT
const HEAVY := Sequence.Attack.HEAVY
const Ahead := Vector2(1.25, 0.0)


func _initialize() -> void:
	var passed := _check_light_lifecycle()
	passed = _check_heavy_and_large_step() and passed
	passed = _check_contact_rejections() and passed
	passed = _check_cancelled_actions() and passed
	if passed:
		print("Verified hero light/heavy timing, one contact, actual damage, and confirmed-hit Battle Points.")
	quit(0 if passed else 1)


func _check_light_lifecycle() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	var profile: Dictionary = Sequence.PROFILES[LIGHT]
	var half_windup: float = profile.windup * 0.5
	if sequence.phase != Sequence.Phase.IDLE or not sequence.start(LIGHT, true):
		return _fail("A living idle hero could not start their light attack.")
	if sequence.start(HEAVY, true) or sequence.phase != Sequence.Phase.WINDUP or sequence.attack != LIGHT:
		return _fail("A second input replaced an active windup.")
	if _advance(sequence, half_windup, enemy) or not is_equal_approx(sequence.phase_progress(), 0.5):
		return _fail("The windup hit early or did not expose progress for a telegraph.")
	if enemy.hp != enemy.max_hp or pool.balance != Points.STARTING_BALANCE:
		return _fail("Windup mutated HP or BP before contact.")
	var result := _advance(sequence, half_windup, enemy)
	var expected := enemy.damage_from(hero, {Unit.Damage.MELEE: profile.damage})
	if not result or result.attack != LIGHT or not is_equal_approx(result.hp_lost, expected):
		return _fail("Light contact did not use the existing damage calculation.")
	if result.bp_credited != profile.bp or pool.balance != Points.STARTING_BALANCE + profile.bp:
		return _fail("Confirmed hero contact did not credit the shared team pool.")
	if sequence.phase != Sequence.Phase.RECOVERY or sequence.start(LIGHT, true):
		return _fail("Contact skipped recovery or allowed a repeat before recovery.")
	var after := enemy.hp
	if _advance(sequence, profile.recovery * 0.5, enemy) or not is_equal_approx(sequence.phase_progress(), 0.5):
		return _fail("Recovery hit again or did not report progress.")
	if _advance(sequence, profile.recovery, enemy) or sequence.phase != Sequence.Phase.IDLE or enemy.hp != after:
		return _fail("Recovery did not end cleanly without causing a repeat contact.")
	return true


func _check_heavy_and_large_step() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	var light_profile: Dictionary = Sequence.PROFILES[LIGHT]
	var heavy_profile: Dictionary = Sequence.PROFILES[HEAVY]
	if heavy_profile.windup <= light_profile.windup or heavy_profile.recovery <= light_profile.recovery:
		return _fail("Heavy attack did not have a distinct, longer commitment.")
	var gap := Vector2(1.9, 0.0)
	sequence.start(LIGHT, true)
	var miss := _advance(sequence, 2.0, enemy, gap)
	if not miss or miss.hp_lost != 0.0 or miss.bp_credited != 0:
		return _fail("The target beyond light reach was not a clean miss.")
	sequence.start(HEAVY, true)
	pool.award_confirmed_hit(pool.capacity - pool.balance - 1)
	var heavy := _advance(sequence, 2.0, enemy, gap)
	var expected := enemy.damage_from(hero, {Unit.Damage.MELEE: heavy_profile.damage})
	if not heavy or heavy.attack != HEAVY or not is_equal_approx(heavy.hp_lost, expected):
		return _fail("One large tick did not resolve exactly one heavy hit in range.")
	if heavy.bp_credited != 1 or pool.balance != pool.capacity or sequence.phase != Sequence.Phase.IDLE:
		return _fail("A large tick did not honor cap and elapsed recovery.")
	var last_hp := enemy.hp
	if _advance(sequence, 2.0, enemy, gap) or enemy.hp != last_hp:
		return _fail("A later tick repeated the heavy contact.")
	enemy.receive_damage(enemy.hp - 1.0)
	sequence.start(HEAVY, true)
	var lethal := _advance(sequence, 2.0, enemy, gap)
	if not lethal or lethal.hp_lost != 1.0 or lethal.bp_credited != 0 or enemy.is_alive():
		return _fail("Lethal contact did not return actual HP lost or respect a full BP pool.")
	return true


func _check_contact_rejections() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var defeated := Unit.new()
	defeated.receive_damage(defeated.hp)
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	var cases := [
		[null, 1, Ahead, Vector2.RIGHT],
		[enemy, 0, Ahead, Vector2.RIGHT],
		[enemy, -1, Ahead, Vector2.RIGHT],
		[defeated, 1, Ahead, Vector2.RIGHT],
		[hero, 1, Ahead, Vector2.RIGHT],
		[enemy, 1, -Ahead, Vector2.RIGHT],
		[enemy, 1, Ahead, Vector2.ZERO],
		[enemy, 1, Vector2(INF, 0.0), Vector2.RIGHT],
	]
	for fixture: Array in cases:
		sequence.start(LIGHT, true)
		var result := sequence.advance(1.0, true, Vector2.ZERO, fixture[3], fixture[0], fixture[1], fixture[2])
		if not result or result.hp_lost != 0.0 or result.bp_credited != 0:
			return _fail("An invalid, defeated, allied, or out-of-arc target did not miss safely.")
	if enemy.hp != enemy.max_hp or hero.hp != hero.max_hp or pool.balance != Points.STARTING_BALANCE:
		return _fail("A rejected contact still mutated health or points.")

	sequence.start(LIGHT, true)
	_advance(sequence, 0.1, enemy)
	var miss := _advance(sequence, 0.2, enemy, Ahead * 10.0)
	if not miss or miss.hp_lost != 0.0 or pool.balance != Points.STARTING_BALANCE:
		return _fail("Reach was locked to the position at windup instead of checked at contact.")
	return true


func _check_cancelled_actions() -> bool:
	var hero := Unit.new()
	var enemy := Unit.new()
	var pool := Points.new()
	var sequence := Sequence.new(hero, 0, pool)
	if sequence.start(LIGHT, false) or sequence.start(99 as Sequence.Attack, true):
		return _fail("A finished battle or invalid attack began a swing.")
	sequence.start(HEAVY, true)
	if _advance(sequence, NAN, enemy) or _advance(sequence, -1.0, enemy) or sequence.phase_progress() != 0.0:
		return _fail("Non-finite or negative time incorrectly advanced a swing.")
	if sequence.advance(2.0, false, Vector2.ZERO, Vector2.RIGHT, enemy, 1, Ahead) or sequence.phase != Sequence.Phase.IDLE:
		return _fail("A swing did not cancel when the battle ended.")
	sequence.start(HEAVY, true)
	hero.receive_damage(hero.hp)
	if _advance(sequence, 2.0, enemy) or sequence.start(LIGHT, true) or sequence.phase != Sequence.Phase.IDLE:
		return _fail("A defeated hero continued or restarted an attack.")
	if enemy.hp != enemy.max_hp or pool.balance != Points.STARTING_BALANCE:
		return _fail("A cancelled attack changed HP or Battle Points.")
	return true


func _advance(sequence: Sequence, delta: float, enemy: Unit, location: Vector2 = Ahead) -> Sequence.Contact:
	return sequence.advance(delta, true, Vector2.ZERO, Vector2.RIGHT, enemy, 1, location)


func _fail(message: String) -> bool:
	push_error(message)
	return false
