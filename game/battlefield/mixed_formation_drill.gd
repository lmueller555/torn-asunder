extends "res://game/battlefield/command_harness.gd"
## Reuse the existing two formations and road-guard rules without an escort.

const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")

const GUARD_START := Vector2(9.0, -4.0)
const FOOT_START := Vector2(4.0, 0.0)
const ARCHER_START := Vector2(5.0, -4.0)
const TARGET_NAMES := {Encounter.Target.HERO: "observer", Encounter.Target.INFANTRY: "Shield Infantry",
	Encounter.Target.ARCHERS: "Archers"}
const DRAW_NAMES := ["Ready", "Drawing", "Reloading"]

var encounter: Encounter
var _guard_marker: Label3D


func _ready() -> void:
	super._ready()
	_guard_marker = Label3D.new()
	_guard_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_guard_marker.pixel_size = 0.024
	_guard_marker.outline_size = 9
	_guard_marker.modulate = Color("#ffc0a7")
	add_child(_guard_marker)
	_restart()


func _place_at_spawns() -> void:
	battle.hero_position = Vector2(-6, 10)
	battle.hero_heading = Vector2.UP
	battle.formations[0].position = FOOT_START
	battle.formations[1].position = ARCHER_START
	for group in battle.formations:
		group.heading = Vector2.RIGHT
		group.hold()


func _restart() -> void:
	restart_battle()
	encounter = Encounter.new(GUARD_START, _world_position, _clear_flat_shot)
	_sync_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_BACKSPACE:
				_restart()
				return
			KEY_K:
				_attack()
				return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		match event.button_index:
			JOY_BUTTON_START:
				_restart()
				return
			JOY_BUTTON_Y:
				_attack()
				return
	super._unhandled_input(event)


func _attack() -> void:
	if not command_view:
		return
	if selected_index == InfantryAttack.INFANTRY_INDEX:
		encounter.order_infantry_attack(battle, selected_index, cursor)
	else:
		encounter.order_archer_attack(battle, selected_index, cursor, _clear_flat_contact)
	_sync_view()


func _after_battle_step(delta: float) -> void:
	encounter.advance(delta, battle, _clear_flat_contact, _clear_flat_move)


func _world_position(point: Vector2) -> Vector3:
	return _ground(point)


# The inherited flat harness contains no intervening cover.
func _clear_flat_shot(_from: Vector3, _to: Vector3) -> bool:
	return true


func _clear_flat_contact(_from: Vector2, _to: Vector2) -> bool:
	return true


func _clear_flat_move(_from: Vector2, _to: Vector2, _wide: bool) -> bool:
	return true


func _sync_view() -> void:
	super._sync_view()
	if not encounter:
		return
	_guard_marker.position = _ground(encounter.enemy_position, 2.1)
	var next_target: String = TARGET_NAMES.get(encounter.windup_target, "")
	var guard := "Guard · %d HP" % ceili(encounter.enemy.hp)
	if not next_target.is_empty():
		guard = "Guard winding up at %s" % next_target
	elif not encounter.enemy.is_alive():
		guard = "Guard defeated"
	_guard_marker.text = guard
	var archers := encounter.archer_attack
	var infantry := encounter.infantry_attack
	var archer_state: String = DRAW_NAMES[archers.volley.phase]
	if not archers.attacker.is_alive():
		archer_state = "Defeated"
	elif encounter.enemy.is_alive() and battle.formations[1].position.distance_to(encounter.enemy_position) <= archers.PIN_RANGE:
		archer_state = "Pinned"
	var status := encounter.active_feedback()
	if status.is_empty():
		status = "Try Archers alone. Reset, move them back, and commit Shield Infantry first."
	_mode_label.text = "Mixed formations · Development playtest"
	_formation_label.text = "%s · Shield %d HP · Archers %d HP (%s) · Team %d BP" % [
		guard, ceili(infantry.attacker.hp), ceili(archers.attacker.hp), archer_state, encounter.points.balance]
	_controls_label.text = "Selected: %s · %s\n" % [battle.formation_at(selected_index).title, status]
	_controls_label.text += "L2 / Shift: command · D-pad / Z X: select · Triangle / K: attack at cursor\n"
	_controls_label.text += "Left stick / WASD / mouse: aim · Square / right click: Move · Cross / H: Hold\n"
	_controls_label.text += "Options / Backspace: reset"
