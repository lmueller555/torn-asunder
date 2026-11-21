extends "res://game/battlefield/command_harness.gd"
## Development adapter; the shell is a deterministic diagnostic, not a projectile.

const Preparation := preload("res://game/combat/siege_preparation.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

const CREW := 0
const OPPOSING := 1
const CONTACT_RANGE := 2.4
const ARC_LIFT := 2.6
const ARC_SEGMENTS := 8
const DRILL_SIEGECRAFT := 4
const DEPLOYMENT := NodePath("Markers/Spawns/OrcVanguard")
const CLEAR_TARGET := NodePath("Markers/Routes/ServiceCauseway")
const PHASE_NAMES := ["Stowed", "Setting up", "Ready", "Reloading"]

var _setup: Preparation
var _holding := false
var _last_shot: Preparation.Shot
var _accepted_shots := 0
var _feedback := ""
var _impact: MeshInstance3D
var _impact_label: Label3D

@onready var _crew_readout: Label = $PracticeHUD/Panel/Margin/Rows/Crew
@onready var _response: Label = $PracticeHUD/Panel/Margin/Rows/Response
@onready var _restart: Button = $PracticeHUD/Panel/Margin/Rows/Restart


func _ready() -> void:
	super._ready()
	# Reuse the command cursor exactly; the overlays are developer labels only.
	_impact = _mesh(self, _cursor_marker.mesh, _cursor_marker.material_override)
	_impact_label = _text_marker()
	_mark_site(battlefield_marker(DEPLOYMENT), "Practice position")
	_mark_site(battlefield_marker(CLEAR_TARGET), "Clear target")
	_restart.pressed.connect(_reset_practice)
	_reset_practice()


func _build_placeholders() -> void:
	_name_roles()
	super._build_placeholders()


func _name_roles() -> void:
	battle.formations[CREW].title = "Siege crew proxy"
	battle.formations[OPPOSING].title = "Opposing foot"


func _reset_practice() -> void:
	_restart.release_focus()
	restart_battle()
	_name_roles()
	_setup = Preparation.new(Platoon.new([Unit.new()], {Platoon.Skill.SIEGECRAFT: DRILL_SIEGECRAFT}))
	_holding = false
	_last_shot = null
	_accepted_shots = 0
	_feedback = "Move to the practice position, then give Hold. Arrival alone does not deploy the crew."
	_sync_view()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_BACKSPACE:
				_reset_practice()
				return
			KEY_C:
				_try_fire()
				return
			KEY_W, KEY_A, KEY_S, KEY_D:
				_mouse_cursor_active = false
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		match event.button_index:
			JOY_BUTTON_START:
				_reset_practice()
				return
			JOY_BUTTON_Y:
				_try_fire()
				return
	elif event is InputEventJoypadMotion and _uses_joypad(event.device) \
			and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) > STICK_DEADZONE:
		_mouse_cursor_active = false
	super._unhandled_input(event)
	_refresh()


func _move_selected() -> void:
	super._move_selected()
	if command_view and selected_index == CREW:
		_holding = false
		_update_crew(0.0)
		_feedback = "Crew stowed on Move. Give Hold at the next position."


func _hold_selected() -> void:
	super._hold_selected()
	if command_view and selected_index == CREW:
		_holding = true
		_update_crew(0.0)
		_feedback = "Crew cannot set up in contact." if _in_contact() else "Crew holding. Wait for Ready."


func _after_battle_step(delta: float) -> void:
	_update_crew(delta)
	_refresh()


func _update_crew(delta: float) -> void:
	var crew := battle.formations[CREW]
	var contact := _in_contact()
	var previous := _setup.phase
	_setup.advance(delta, crew.position, _holding and crew.order == Battle.Order.HOLD, crew.can_receive_orders(), contact)
	if contact and previous != Preparation.Phase.STOWED:
		_feedback = "Opposing contact stowed the crew. Clear contact before settling again."
	elif previous != Preparation.Phase.READY and _setup.phase == Preparation.Phase.READY:
		_feedback = "Crew ready. Aim at walkable ground and fire."


func _try_fire() -> void:
	var crew := battle.formations[CREW]
	if not command_view or selected_index != CREW:
		_feedback = "Select the Siege crew proxy in command view to fire."
	elif _in_contact():
		_feedback = "Cannot fire: opposing foot in contact."
	elif _setup.phase != Preparation.Phase.READY:
		_feedback = "Cannot fire while %s." % _phase_name().to_lower()
	elif (_mouse_cursor_active and not _point_cursor(_mouse_position, false)) or not _ground_available(cursor):
		_feedback = "Invalid target: aim at walkable ground, not a roof or wall."
	else:
		var distance := crew.position.distance_to(cursor)
		if distance < Preparation.MIN_RANGE:
			_feedback = "Too close: %.1f m; minimum %.0f m." % [distance, Preparation.MIN_RANGE]
		elif distance > Preparation.MAX_RANGE:
			_feedback = "Out of range: %.1f m; maximum %.0f m." % [distance, Preparation.MAX_RANGE]
		elif not _arc_clear(crew.position, cursor):
			_feedback = "Blocked arc: solid terrain shelters this ground."
		else:
			# Alternating fixed rolls expose both outcomes on every repeatable reset.
			var roll := 0.25 if _accepted_shots % 2 == 0 else 0.95
			var shot := _setup.fire(cursor, true, roll)
			if shot:
				_last_shot = shot
				_accepted_shots += 1
				_feedback = "On target. Reloading." if shot.on_target else "Miss. The crew still has to reload."
	_refresh()


func _in_contact() -> bool:
	var origin := battle.formations[CREW].position
	var enemy := battle.formations[OPPOSING]
	return enemy.can_receive_orders() and origin.distance_to(enemy.position) <= CONTACT_RANGE \
		and _terrain.clear_melee_contact(origin, enemy.position)


func _ground_available(point: Vector2) -> bool:
	if not point.is_finite() or not battle.bounds.has_point(point):
		return false
	var picked: Variant = _terrain.destination_from_ray(_world(point, 20.0), _world(point, -8.0))
	return picked is Vector2 and picked.is_equal_approx(point) \
		and _terrain.can_move(point + Vector2(0.02, 0.0), point, false)


func _arc_clear(from: Vector2, to: Vector2) -> bool:
	# Query the playable arc against real solids, including intermediate cover.
	var start := _ground(from, 1.0)
	var end := _ground(to, 0.35)
	var previous := start
	for index in range(1, ARC_SEGMENTS + 1):
		var fraction := float(index) / ARC_SEGMENTS
		var point := start.lerp(end, fraction) + Vector3.UP * (4.0 * ARC_LIFT * fraction * (1.0 - fraction))
		if not _terrain.clear_ranged_lane(previous, point):
			return false
		previous = point
	return true


func _phase_name() -> String:
	return PHASE_NAMES[_setup.phase]


func _refresh() -> void:
	if not _setup:
		return
	var remaining := " · %.1f s" % _setup.remaining if _setup.remaining > 0.0 else ""
	_crew_readout.text = "%s%s  ·  Range %.0f–%.0f m  ·  Siegecraft %d" % [
		_phase_name(), remaining, Preparation.MIN_RANGE, Preparation.MAX_RANGE, DRILL_SIEGECRAFT,
	]
	_response.text = _feedback
	_impact.visible = _last_shot != null
	_impact_label.visible = _impact.visible
	if _last_shot:
		_impact.position = _ground(_last_shot.target, 0.14)
		_impact_label.position = _ground(_last_shot.target, 1.5)
		_impact_label.text = "ON TARGET" if _last_shot.on_target else "MISS · AIM POINT"


func _mark_site(site: Marker3D, title: String) -> void:
	var label := _text_marker()
	label.global_position = site.global_position + Vector3.UP * 0.7
	label.text = title


func _text_marker() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.04
	label.outline_size = 9
	add_child(label)
	return label
