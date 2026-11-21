extends Node3D
## One stationary camera, one player-moved caster and one moving target.

const Ice := preload("res://game/combat/targeted_ice_cast.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Points := preload("res://game/combat/battle_points.gd")

const CASTER_START := Vector2(-19.0, 11.0)
# The existing Works Shed blocks sight as the target moves west of its wall.
const TARGET_OPEN := Vector2(-39.3, 12.7)
const TARGET_COVER := Vector2(-39.3, 17.0)
const CASTER_SPEED := 5.5
const TARGET_SPEED := 5.2

var caster: Unit
var target: Unit
var pool: Points
var spell: Ice
var caster_position := CASTER_START
var target_position := TARGET_OPEN
var _terrain: Terrain
var _falling_back := false
var _keys: Dictionary[Key, bool] = {}
var _stick := Vector2.ZERO
var _r2_down := false
var _joypad := -1
var _feedback := ""
var _caster_marker: Label3D
var _target_marker: Label3D

@onready var _readout: Label = $HUD/Panel/Margin/Readout


func _ready() -> void:
	_terrain = Terrain.new($Mine)
	$Camera.look_at(to_global(Vector3(-29, 0, 13)))
	_caster_marker = _marker("Caster ▼", Color("#bce9fa"))
	_target_marker = _marker("Target ▼", Color("#ffc0a7"))
	_joy_changed(-1, false)
	Input.joy_connection_changed.connect(_joy_changed)
	_reset()


func _reset() -> void:
	caster = Unit.new()
	# Arrive with earned, unspent points; allocation still uses the normal
	# level/stat APIs and pressing Train spends only one of them.
	for i in range(Ice.ICE_RATING - Unit.MIN_RATING):
		caster.award_experience(caster.experience_for_next_level())
	target = Unit.new()
	pool = Points.new(caster.level)
	spell = Ice.new(pool)
	caster_position = CASTER_START
	target_position = TARGET_OPEN
	_falling_back = false
	_feedback = "Allocate Ice, then walk toward the target to bring it into range."
	_refresh()


func _physics_process(delta: float) -> void:
	var motion := _movement()
	if not motion.is_zero_approx():
		var next := (caster_position + motion * CASTER_SPEED * delta).clamp(Vector2(-43, 4), Vector2(-15, 23))
		if _terrain.can_move(caster_position, next, false):
			caster_position = next
	var destination := TARGET_COVER if _falling_back else TARGET_OPEN
	var next_target := target_position.move_toward(destination, TARGET_SPEED * delta)
	if _terrain.can_move(target_position, next_target, false):
		target_position = next_target
	var distance := _distance()
	var clear := _clear_lane()
	if spell.locked_target() == target:
		match spell.advance(delta, distance, clear):
			Ice.Phase.RELEASED:
				_feedback = "Released: %.1f Ice damage. No BP earned." % spell.damage_done
			Ice.Phase.INTERRUPTED:
				var cause := "Target is now out of range" if distance > Ice.RANGE else "Cover broke sight"
				_feedback = "%s. The committed BP were not refunded." % cause
	_refresh(distance, clear)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: Key = event.physical_keycode
		if code in [KEY_W, KEY_A, KEY_S, KEY_D]:
			if event.pressed:
				_keys[code] = true
			else:
				_keys.erase(code)
		elif event.pressed:
			match code:
				KEY_P: _train()
				KEY_V: _cast()
				KEY_T: _toggle_fallback()
				KEY_BACKSPACE: _reset()
	elif _joypad < 0 or event.device == _joypad:
		if event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_LEFT_X:
				_stick.x = event.axis_value
			elif event.axis == JOY_AXIS_LEFT_Y:
				_stick.y = event.axis_value
			elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
				var was_down := _r2_down
				_r2_down = event.axis_value > 0.30 if was_down else event.axis_value >= 0.48
				if _r2_down and not was_down:
					_cast()
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_RIGHT_SHOULDER: _train()
				JOY_BUTTON_Y: _toggle_fallback()
				JOY_BUTTON_START: _reset()


func _joy_changed(device: int, connected: bool) -> void:
	if connected and _joypad >= 0:
		return
	if not connected and device >= 0 and device != _joypad:
		return
	var pads := Input.get_connected_joypads()
	_joypad = pads[0] if not pads.is_empty() else -1
	_stick = Vector2.ZERO
	_r2_down = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_keys.clear()
		_stick = Vector2.ZERO
		_r2_down = false


func _movement() -> Vector2:
	var digital := Vector2(float(_keys.has(KEY_D)) - float(_keys.has(KEY_A)),
		float(_keys.has(KEY_S)) - float(_keys.has(KEY_W)))
	return digital.limit_length() if not digital.is_zero_approx() \
		else (_stick.limit_length() if _stick.length() >= 0.18 else Vector2.ZERO)


func _toggle_fallback() -> void:
	_falling_back = not _falling_back


func _train() -> void:
	if caster.spend_stat_point(Unit.Damage.ICE):
		_feedback = "One earned stat point allocated to Ice."
	else:
		_feedback = "No unspent stat points."


func _cast() -> void:
	if spell.phase == Ice.Phase.WINDUP:
		return
	var distance := _distance()
	var clear := _clear_lane()
	if caster.rating(Unit.Damage.ICE) < Ice.ICE_RATING:
		_feedback = "Cast denied: requires Ice %d." % Ice.ICE_RATING
	elif distance > Ice.RANGE:
		_feedback = "Cast denied: target is out of range."
	elif not clear:
		_feedback = "Cast denied: terrain blocks sight."
	elif not pool.can_afford(Ice.COST):
		_feedback = "Cast denied: not enough Battle Points."
	else:
		spell.reset_after_terminal()
		if spell.begin(caster, target, distance, clear):
			_feedback = "Winding up: target locked, %d BP committed." % Ice.COST


func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, _terrain.ground_height(point), point.y)


func _distance() -> float:
	return _ground(caster_position).distance_to(_ground(target_position))


func _clear_lane() -> bool:
	return _terrain.clear_ranged_lane(_ground(caster_position) + Vector3.UP * 1.45,
		_ground(target_position) + Vector3.UP * 0.90)


func _marker(caption: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.023
	label.outline_size = 9
	label.no_depth_test = true  # Trace the diagnostic marker even behind the shed.
	add_child(label)
	return label


func _refresh(distance := -1.0, clear := false) -> void:
	if distance < 0.0:
		distance = _distance()
		clear = _clear_lane()
	_caster_marker.position = _ground(caster_position) + Vector3.UP * 1.2
	_target_marker.position = _ground(target_position) + Vector3.UP * 1.2
	_readout.text = "Ice cast · Development playtest\nIce %d / %d · Unspent stat points %d · Battle Points %d / %d\n" % [
		caster.rating(Unit.Damage.ICE), Ice.ICE_RATING, caster.stat_points, pool.balance, pool.capacity]
	_readout.text += "Target %.1f m / %.0f m · Sight: %s · Target HP %.1f\n" % [
		distance, Ice.RANGE, "clear" if clear else "blocked", target.hp]
	_readout.text += "%s\n" % _feedback
	_readout.text += "WASD / Left stick: move caster · P / R1: allocate Ice · V / R2: cast\n"
	_readout.text += "T / Triangle: send target to cover or back · Backspace / Options: reset"
