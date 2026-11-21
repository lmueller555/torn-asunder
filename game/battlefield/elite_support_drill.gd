extends "res://game/battlefield/command_harness.gd"
## Development-only adapter using the existing terrain and command harness.

const Pulse := preload("res://game/combat/elite_support_pulse.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const SOURCE := 0
const OPPOSING := 1
const CONTACT_RANGE := 2.4

var _pool: Points
var _pulse: Pulse
var _beast: Platoon
var _opponent: Platoon
var _tell: MeshInstance3D
var _tell_text: Label3D
var _feedback := ""

@onready var _team_status: Label = $DrillHUD/Panel/Margin/Rows/Team
@onready var _role_status: Label = $DrillHUD/Panel/Margin/Rows/Role
@onready var _response: Label = $DrillHUD/Panel/Margin/Rows/Response
@onready var _restart: Button = $DrillHUD/Panel/Margin/Rows/Restart


func _ready() -> void:
	super._ready()
	# Reuse the harness's debug ring. No pulse VFX or model assets are added.
	_tell = _mesh(self, _cursor_marker.mesh, _cursor_marker.material_override)
	var ring_scale := Pulse.RADIUS / (_cursor_marker.mesh.get_aabb().size.x / 2.0)
	_tell.scale = Vector3(ring_scale, 1.0, ring_scale)
	_tell_text = Label3D.new()
	_tell_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tell_text.pixel_size = 0.014
	_tell_text.outline_size = 9
	add_child(_tell_text)
	_restart.pressed.connect(_reset_drill)
	_reset_drill()


func _build_placeholders() -> void:
	_name_roles()
	super._build_placeholders()


func _name_roles() -> void:
	battle.formations[SOURCE].title = "Support proxy"
	battle.formations[OPPOSING].title = "Opposing foot"


func _reset_drill() -> void:
	_restart.release_focus()
	restart_battle()
	_name_roles()
	_pool = Points.new()
	_beast = Platoon.new([Unit.new()], {Platoon.Skill.BEAST_HANDLING: Pulse.BEAST_HANDLING})
	_opponent = Platoon.new([Unit.new()])
	_pulse = Pulse.new(_beast, _pool)
	_feedback = "Hold Support, place the pulse, then switch to Opposing foot to test a response."
	_sync_view()
	_refresh_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_BACKSPACE:
				_reset_drill()
				return
			KEY_C:
				_try_pulse()
				return
			KEY_W, KEY_A, KEY_S, KEY_D:
				_mouse_cursor_active = false
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		match event.button_index:
			JOY_BUTTON_START:
				_reset_drill()
				return
			JOY_BUTTON_Y:
				_try_pulse()
				return
	elif event is InputEventJoypadMotion and _uses_joypad(event.device) \
			and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) > STICK_DEADZONE:
		_mouse_cursor_active = false
	super._unhandled_input(event)
	_refresh_readout()


func _try_pulse() -> void:
	var origin := battle.formations[SOURCE].position
	if not command_view or selected_index != SOURCE:
		_feedback = "Pulse denied: select Support proxy in command view."
	elif _pulse.phase == Pulse.Phase.ANNOUNCED:
		_feedback = "A tell is already committed to its ground point."
	elif battle.formations[SOURCE].order != Battle.Order.HOLD:
		_feedback = "Pulse denied: Support must Hold."
	elif _in_contact():
		_feedback = "Pulse denied: opposing foot already in contact."
	elif (_mouse_cursor_active and not _point_cursor(_mouse_position, false)) or not _ground_available(cursor):
		_feedback = "Pulse denied: aim at walkable ground."
	elif origin.distance_to(cursor) > Pulse.PLACEMENT_RANGE:
		_feedback = "Pulse denied: ground must be within %.0f m of Support." % Pulse.PLACEMENT_RANGE
	elif not _lane_clear(origin, cursor):
		_feedback = "Pulse denied: terrain blocks the lane."
	elif not _pool.can_afford(Pulse.COST):
		_feedback = "Pulse denied: insufficient shared BP."
	else:
		if _pulse.phase != Pulse.Phase.IDLE:
			_pulse.reset_after_terminal()
		if _pulse.begin(origin, cursor, true, true):
			_feedback = "Pulse announced. Move Opposing foot away or into contact before release."
	_refresh_readout()


func _after_battle_step(delta: float) -> void:
	if _pulse.phase == Pulse.Phase.ANNOUNCED:
		var source := battle.formations[SOURCE]
		var enemy := battle.formations[OPPOSING].position
		var contact := _in_contact()
		var phase := _pulse.advance(delta, source.position, _ground_available(_pulse.center),
			_lane_clear(source.position, _pulse.center), [
				Pulse.Contact.new(_opponent, enemy, true, _lane_clear(_pulse.center, enemy)),
			], contact or source.order != Battle.Order.HOLD)
		if phase == Pulse.Phase.INTERRUPTED:
			_feedback = "Interrupted by %s. Committed BP not refunded." % ("opposing contact" if contact else "lost Hold or lane")
		elif phase == Pulse.Phase.RESOLVED:
			var pressure := _pulse.pressure_dealt(_opponent)
			_feedback = "Landed: opposing foot lost %.0f cohesion." % pressure if pressure > 0.0 \
				else "Evaded: no exposed opponent inside the pulse."
	_refresh_readout()


func _in_contact() -> bool:
	var origin := battle.formations[SOURCE].position
	var enemy := battle.formations[OPPOSING].position
	return origin.distance_to(enemy) <= CONTACT_RANGE and _terrain.clear_melee_contact(origin, enemy)


func _ground_available(point: Vector2) -> bool:
	if not point.is_finite() or not battle.bounds.has_point(point):
		return false
	# Cast from above to reject walls even if the command cursor was last valid.
	var picked: Variant = _terrain.destination_from_ray(_world(point, 20.0), _world(point, -8.0))
	return picked is Vector2 and picked.is_equal_approx(point) \
		and _terrain.can_move(point + Vector2(0.02, 0.0), point, false)


func _lane_clear(from: Vector2, to: Vector2) -> bool:
	return from.is_equal_approx(to) or _terrain.clear_ranged_lane(_ground(from, 0.8), _ground(to, 0.8))


func _refresh_readout() -> void:
	if not _pulse:
		return
	var source := battle.formations[SOURCE]
	_team_status.text = "Shared team BP: %d / %d  ·  Pulse: %d BP  ·  Opposing cohesion: %.0f" % [
		_pool.balance, _pool.capacity, Pulse.COST, _opponent.cohesion,
	]
	_role_status.text = "Selected: %s  ·  Support: %s  ·  Beast Handling: %d" % [
		battle.formations[selected_index].title, "Holding" if source.order == Battle.Order.HOLD else "Not holding",
		_beast.rank(Platoon.Skill.BEAST_HANDLING),
	]
	_response.text = _feedback
	_tell.visible = _pulse.phase == Pulse.Phase.ANNOUNCED
	_tell_text.visible = _tell.visible
	if _tell.visible:
		_tell.position = _ground(_pulse.center, 0.14)
		_tell_text.position = _ground(_pulse.center, 2.0)
		_tell_text.text = "PULSE · %.2f s" % _pulse.tell_remaining
