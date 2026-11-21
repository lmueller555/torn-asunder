extends SceneTree

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Siege := preload("res://game/combat/siege_preparation.gd")

var _failures := 0


func _initialize() -> void:
	var crew := Platoon.new([Unit.new()], {Platoon.Skill.SIEGECRAFT: 3})
	var siege := Siege.new(crew)
	var anchor := Vector2(4.0, -8.0)
	var target := anchor + Vector2(40.0, 0.0)
	_check(siege.fire(target, true, 0.0) == null, "A moving or stowed crew cannot fire.")
	siege.advance(0.1, anchor, true, true, false)
	var delay := crew.siege_setup_seconds()
	_check(siege.phase == Siege.Phase.SETTING_UP and siege.remaining == delay,
			"Stopping on Hold starts a full trained setup at the observed position.")
	siege.advance(delay - 0.2, anchor, true, true, false)
	_check(siege.phase == Siege.Phase.SETTING_UP and siege.fire(target, true, 0.0) == null,
			"An almost ready crew cannot fire prematurely.")
	siege.advance(0.2, anchor, true, true, true)
	_check(siege.phase == Siege.Phase.STOWED and siege.remaining == 0.0,
			"Melee interruption defeats same-tick setup completion.")
	siege.advance(0.0, anchor, true, true, false)
	siege.advance(delay, anchor, true, true, false)
	_check(siege.phase == Siege.Phase.READY, "A fresh uninterrupted setup reaches Ready.")
	_check(siege.fire(target, false, 0.0) == null and siege.fire(target, true, 1.0) == null
			and siege.fire(anchor + Vector2(5.0, 0.0), true, 0.0) == null
			and siege.fire(anchor + Vector2(55.0, 0.0), true, 0.0) == null
			and siege.phase == Siege.Phase.READY, "Blocked or out-of-range requests do not spend a shot.")
	var hit := siege.fire(target, true, 0.70)
	_check(hit != null and hit.on_target and hit.origin == anchor and hit.target == target,
			"A legal shot returns its locked origin and target and uses Siegecraft accuracy.")
	_check(siege.phase == Siege.Phase.RELOADING and siege.remaining == crew.siege_reload_seconds()
			and siege.fire(target, true, 0.0) == null, "The accepted hit is followed by one trained reload.")
	siege.advance(crew.siege_reload_seconds(), anchor, true, true, false)
	var miss := siege.fire(target, true, 0.99)
	_check(miss != null and not miss.on_target and siege.phase == Siege.Phase.RELOADING,
			"A committed miss also reloads.")
	siege.advance(100.0, anchor + Vector2(0.5, 0.0), true, true, false)
	_check(siege.phase == Siege.Phase.SETTING_UP and siege.remaining == delay,
			"Actual movement resets the emplacement, not merely the old reload time.")
	siege.advance(delay, anchor, false, true, false)
	_check(siege.phase == Siege.Phase.STOWED, "An active Move order stows the crew immediately.")
	siege.advance(1.0, anchor, true, false, false)
	_check(siege.phase == Siege.Phase.STOWED, "A defeated crew cannot quietly begin setup.")
	if _failures == 0:
		print("Siege preparation: stationary setup, melee interruption, target admission, trained accuracy and reload passed.")
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
