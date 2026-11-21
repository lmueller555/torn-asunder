extends "res://game/battlefield/command_harness.gd"
## Isolated input preview. Live missions continue to use the inherited L2 behavior.

const Policy := preload("res://game/battlefield/engagement_camera_policy.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Mode := Policy.Mode
const HERO := 0
const SHIELDS := 1
const SCOUTS := 2
const ROSTER: Array[StringName] = [&"hero", &"shields", &"scouts"]
const CONTACT_RANGE := 2.8
const FOLLOW_SPAN := 15.0
const PATROL_START := Vector2(-8.0, -7.0)
const PATROL_END := Vector2(-8.0, -3.7)
const SPAR_POSITION := Vector2(4.0, 1.4)
const LABEL := Color("#ffd0a6")

var policy := Policy.new(&"hero")
var defense := Defense.new(Unit.new(), 0, null)
var _mode := Mode.TACTICAL
var _selection_id := &"hero"
var _positions: Array[Vector2] = [PATROL_START, SPAR_POSITION]
var _opponents: Array[Unit] = [Unit.new(180.0), Unit.new(180.0)]
var _opponent_actors: Array[Node3D] = []
var _guard_held := false
var _hero_report := ""


func _ready() -> void:
	battle.formations = [
		Battle.Formation.new("Hero Platoon", battle.hero_position),
		Battle.Formation.new("Shield Infantry", Vector2(-8.0, 4.0)),
		Battle.Formation.new("Scouts", Vector2(8.0, 5.0)),
	]
	policy.set_active_platoons(ROSTER)
	super._ready()
	_add_debug_opponent("Practice patrol", PATROL_START)
	_add_debug_opponent("Sparring opponent", SPAR_POSITION)
	_sync_view()


func _physics_process(delta: float) -> void:
	var hero_active := policy.accepts_direct_hero_input()
	defense.set_guard(hero_active and _guard_held, hero_active)
	if hero_active:
		battle.move_hero(defense.advance_defense(delta, true))
	super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var escort := battle.formations[HERO]
	if command_view:
		battle.hero_position = escort.position
		battle.hero_heading = escort.heading
	else:
		escort.position = battle.hero_position
		escort.heading = battle.hero_heading

	# Incoming patrol movement and each living opponent's actual proximity
	# supply the observations. No input directly sets an engagement flag.
	_positions[0] = _positions[0].move_toward(PATROL_END, delta * 1.8)
	var contact_id := _nearest_opponent(battle.hero_position)
	if contact_id != -1:
		var contact := defense.advance_attack(delta, true, battle.hero_position, battle.hero_heading,
			_opponents[contact_id], 1, _positions[contact_id])
		if contact:
			_hero_report = "Practice contact confirmed" if contact.hp_lost > 0.0 else "Swing missed"
	else:
		defense.advance_attack(delta, true, battle.hero_position, battle.hero_heading)

	for index in _opponent_actors.size():
		var actor := _opponent_actors[index]
		actor.position = _ground(_positions[index])
		actor.visible = _opponents[index].is_alive()
	for index in ROSTER.size():
		var position := battle.formations[index].position
		var nearest := _nearest_opponent(position)
		policy.observe_engaged(ROSTER[index], nearest != -1 \
			and position.distance_to(_positions[nearest]) <= CONTACT_RANGE)
	_apply_context()


func _nearest_opponent(position: Vector2) -> int:
	var best := INF
	var nearest := -1
	for index in _opponents.size():
		if _opponents[index].is_alive():
			var distance := position.distance_squared_to(_positions[index])
			if distance < best:
				best = distance
				nearest = index
	return nearest


func _update_mode() -> void:
	# Shift/L2 continue to be read by the base binder, but cannot override
	# the policy inside this scene. No live harness behavior is modified.
	_apply_context()


func _apply_context() -> void:
	var next := policy.mode()
	var selection := policy.selected_id()
	if next != _mode or selection != _selection_id:
		if _mode == Mode.TACTICAL:
			policy.set_tactical_cursor(cursor)
		if next == Mode.PLATOON_FOLLOW:
			cursor = battle.formations[selected_index].position
		elif next == Mode.TACTICAL:
			cursor = policy.tactical_cursor()
		elif next == Mode.HERO_ACTION:
			battle.formations[HERO].hold()
			_hero_report = ""
		if next != Mode.HERO_ACTION:
			_guard_held = false
			defense.set_guard(false, false)
		_mouse_cursor_active = false
	_mode = next
	_selection_id = selection
	command_view = policy.accepts_formation_orders()
	if command_view and not _command_camera.is_current():
		_command_camera.make_current()
	elif not command_view and not _hero_camera.is_current():
		_hero_camera.make_current()


func _select_relative(step: int) -> void:
	policy.cycle(step)
	_commit_selection()


func _select_at_cursor() -> void:
	var nearest := 2.2
	for index in ROSTER.size():
		var distance := battle.formations[index].position.distance_to(cursor)
		if distance < nearest:
			nearest = distance
			policy.select(ROSTER[index])
	_commit_selection()


func _commit_selection() -> void:
	selected_index = ROSTER.find(policy.selected_id())
	_apply_context()
	_update_cameras()
	_sync_view()


func _step_sector_cursor(movement: Vector2, delta: float) -> bool:
	if _mode != Mode.PLATOON_FOLLOW:
		return super._step_sector_cursor(movement, delta)
	if not movement.is_zero_approx():
		_mouse_cursor_active = false
		cursor = battle.clamp_to_field(cursor + movement.rotated(-_command_yaw) * CURSOR_SPEED * delta)
	return false


func _center_on_hero() -> void:
	if _mode == Mode.TACTICAL:
		super._center_on_hero()


func _toggle_overview() -> void:
	if _mode == Mode.TACTICAL:
		super._toggle_overview()


func _update_cameras() -> void:
	super._update_cameras()
	if _mode == Mode.PLATOON_FOLLOW:
		var target := _ground(battle.formations[selected_index].position, 0.70)
		var offset := Vector3(0.0, sin(_command_pitch), cos(_command_pitch)).rotated(Vector3.UP, _command_yaw)
		_command_camera.size = FOLLOW_SPAN
		_command_camera.position = target + offset * FOLLOW_SPAN
		_command_camera.look_at(to_global(target))


func _hero_move_factor() -> float:
	match defense.phase:
		Defense.Phase.FREE:
			return 1.0 if defense.attack_phase == Attack.Phase.IDLE else 0.5
		Defense.Phase.GUARD:
			return 0.45
		_:
			return 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _handle_hero_input(event):
		return
	super._unhandled_input(event)


func _handle_hero_input(event: InputEvent) -> bool:
	var action: int = 0
	if event is InputEventKey and not event.echo:
		action = event.physical_keycode
	elif event is InputEventJoypadButton and _uses_joypad(event.device):
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER: action = KEY_U
			JOY_BUTTON_X: action = KEY_J
			JOY_BUTTON_Y: action = KEY_K
			JOY_BUTTON_B: action = KEY_L
	if not policy.accepts_direct_hero_input() or action not in [KEY_U, KEY_J, KEY_K, KEY_L]:
		return false
	if action == KEY_U:
		_guard_held = event.pressed
		defense.set_guard(_guard_held, true)
	elif event.pressed:
		defense.set_guard(_guard_held, true)
		match action:
			KEY_J: defense.start_attack(Attack.Attack.LIGHT, true)
			KEY_K: defense.start_attack(Attack.Attack.HEAVY, true)
			KEY_L:
				var direction := _movement_input().rotated(-_hero_yaw)
				defense.start_dodge(battle.hero_heading if direction.is_zero_approx() else direction, true)
	_sync_view()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_guard_held = false
	super._notification(what)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if device == _input_device and not connected:
		_guard_held = false
	super._on_joy_connection_changed(device, connected)


func _sync_view() -> void:
	super._sync_view()
	var header := "ENGAGEMENT CONTEXTS  /  DEVELOPMENT PREVIEW"
	match _mode:
		Mode.TACTICAL:
			policy.set_tactical_cursor(cursor)
			_mode_label.text = header + "\nTACTICAL  /  TERRAIN CURSOR"
			_controls_label.text = "D-pad / Z X: cycle   ·   Left stick / mouse: cursor   ·   R3 / M: overview\nSquare / right-click: move   ·   Cross / H: hold\nMove a platoon toward a labeled practice opponent to see contact."
		Mode.PLATOON_FOLLOW:
			_mode_label.text = header + "\nALLY FOLLOW  /  FORMATION ORDERS"
			_controls_label.text = "D-pad / Z X: cycle   ·   Left stick / mouse: order cursor\nSquare / right-click: move   ·   Cross / H: hold\nMoving out of contact restores the earlier tactical cursor."
		Mode.HERO_ACTION:
			_mode_label.text = header + "\nHERO ACTION  /  DIRECT INPUT"
			_formation_label.text = "Hero Platoon  ·  " + ("Guarding" if _guard_held else "In contact")
			_controls_label.text = "D-pad / Z X: cycle   ·   Left stick / WASD: move\nSquare / J: light   ·   Triangle / K: heavy   ·   L1 / U: guard   ·   Circle / L: dodge"
			if not _hero_report.is_empty():
				_controls_label.text += "\n" + _hero_report


func _add_debug_opponent(title: String, point: Vector2) -> void:
	var actor := Node3D.new()
	add_child(actor)
	var sample: Node3D = _formation_members[SHIELDS][0]
	var copy := sample.duplicate(0) as Node3D
	actor.add_child(copy)
	copy.position = Vector3.ZERO
	var label := Label3D.new()
	label.text = title
	label.position.y = 2.0
	label.pixel_size = 0.025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 9
	label.modulate = LABEL
	actor.add_child(label)
	actor.position = _ground(point)
	_opponent_actors.append(actor)
