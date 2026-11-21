extends SceneTree

const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Ice := preload("res://game/combat/targeted_ice_cast.gd")

var _failures := 0


func _initialize() -> void:
	var pool := Points.new()
	var cast := Ice.new(pool)
	var novice := Unit.new()
	var trained := Unit.new(1200.0, {Unit.Damage.ICE: 6})
	var enemy := Unit.new(1200.0, {Unit.Damage.ICE: 26})
	var other := Unit.new()
	_check(not cast.begin(novice, enemy, 5.0, true) and not cast.begin(trained, trained, 0.0, true)
			and not cast.begin(trained, enemy, 16.01, true) and not cast.begin(trained, enemy, 5.0, false)
			and pool.balance == 400, "Missing training, an invalid target or blocked line never spends BP.")
	_check(cast.begin(trained, enemy, 16.0, true) and cast.locked_target() == enemy and pool.balance == 280,
			"An eligible cast spends the mission pool once and locks its actual target.")
	_check(not cast.begin(trained, other, 5.0, true) and not cast.reset_after_terminal() and pool.balance == 280,
			"Pending casts cannot be restarted, retargeted or charged again.")
	_check(cast.advance(NAN, 9.0, true) == Ice.Phase.WINDUP
			and cast.advance(0.5, 9.0, true) == Ice.Phase.WINDUP
			and enemy.hp == enemy.max_hp, "Invalid time and early windup cause no hit.")
	_check(cast.advance(0.2, 9.0, false) == Ice.Phase.INTERRUPTED
			and cast.locked_target() == null and enemy.hp == enemy.max_hp and pool.balance == 280,
			"Loss of the lane wins over completion and does not refund committed BP.")
	_check(cast.reset_after_terminal() and cast.begin(trained, enemy, 4.0, true),
			"A new valid cast can follow interruption.")
	var predicted := enemy.damage_from(trained, {Unit.Damage.ICE: Ice.BASE_ICE_DAMAGE})
	_check(cast.advance(0.7, 4.0, true) == Ice.Phase.RELEASED
			and is_equal_approx(cast.damage_done, predicted)
			and is_equal_approx(enemy.hp, enemy.max_hp - predicted) and other.hp == other.max_hp,
			"Release uses the target's actual Ice rating, hits only the locked unit and applies once.")
	cast.advance(20.0, 4.0, true)
	_check(is_equal_approx(enemy.hp, enemy.max_hp - predicted) and pool.balance == 160
			and cast.reset_after_terminal(), "Waiting on a released cast never hits or awards twice.")
	_check(cast.begin(trained, other, 4.0, true), "A third cast is affordable before its interruption.")
	trained.receive_damage(trained.hp)
	_check(cast.advance(1.0, 4.0, true) == Ice.Phase.INTERRUPTED
			and other.hp == other.max_hp and pool.balance == 40 and cast.reset_after_terminal(),
			"A caster defeated before release does not apply the effect.")
	var replacement := Unit.new(1200.0, {Unit.Damage.ICE: 8})
	_check(not cast.begin(replacement, other, 4.0, true) and pool.balance == 40 and cast.phase == Ice.Phase.IDLE,
			"Even a trained replacement cannot start without enough BP.")
	if _failures == 0:
		print("Targeted Ice cast: stat and BP gates, locked windup, line loss and caster defeat, actual scaled hit and repeat guards passed.")
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
