extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Adapter := preload("res://game/battlefield/mara_campaign_minimap.gd")
const LeadAction := preload("res://game/battlefield/mara_lead_action_camera.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Fight := preload("res://game/battlefield/mara_mine_encounter.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _hud: Adapter


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	_hud = _mission.get_node("MinimapHUD/Panel") as Adapter
	_hud.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _approach() and await _check_contact()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Mara action focus: real input and contact, native carry projections, minimap and continuing orders, attack/guard/dodge, separation, overrides and retry passed.")
	quit(0 if passed else 1)


func _approach() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	var cursor := _mission.cursor
	_button(JOY_BUTTON_DPAD_DOWN)
	_tick()
	if not _hud._lead_action.focused or _hud._lead_action.active or _mission.cursor != cursor \
			or root.get_camera_3d() != _mission._command_camera or _mission.battle.formations.size() != 2:
		return _fail("Focus in command changed orders, the cursor, or the real formation roster.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	for id in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard", "Objectives/GodbridlePickup"]:
		if not _walk(_position(id)):
			return _fail("Did not reach the actual Mine pickup via " + id)
	_button(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Escort.Phase.ESCORTING or _hud._lead_action.active:
		return _fail("The pickup did not start the real escort, or Mara entered action before contact.")
	for id in ["RoadWest", "RoadJunction", "RoadCut", "EastPass"]:
		if not _walk(_position("Routes/" + id)):
			return _fail("Did not reach the actual pass via " + id)
	# Orbit behind the real hero while the threat is still outside melee reach.
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	_tick(59)
	_axis(JOY_AXIS_RIGHT_X, 0)
	_tick()
	return (_mission.objective.interception_triggered and _hud._lead_action.focused \
		and not _hud._lead_action.active and _baseline_arm() and _carry_projects(false)) \
		or _fail("Reserve/interception or distant aggro replaced the normal lens, or carry was not visible.")


func _check_contact() -> bool:
	var camera := _mission._hero_camera
	var fight := _mission.encounter
	var initial_bp := fight.points.balance
	await _checkpoint("01-before-contact")
	for i in 600:
		if fight.enemy_phase == Fight.EnemyPhase.WATCHING:
			break
		_tick()
	if fight.enemy_phase != Fight.EnemyPhase.WATCHING:
		return _fail("The physical reserve did not reach its real road merge.")
	var contact := false
	for i in 400:
		if _hud._lead_action.active:
			contact = true
			break
		_move_toward(fight.enemy_position)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_LEFT_Y, 0)
	if not contact or fight.enemy_position.distance_to(_mission.battle.hero_position) > Fight.CONTACT_RANGE:
		return _fail("Mara did not enter action from actual clear melee contact.")
	# Guard while moving into the tightened lens, without consuming a command input.
	_button_event(JOY_BUTTON_LEFT_SHOULDER, true)
	_tick(22)
	await _checkpoint("02-real-contact-action")
	var pivot := _mission._ground(_mission.battle.hero_position, 1.15)
	if camera != root.get_camera_3d() or not _hud._lead_action.active \
			or not is_equal_approx(camera.position.distance_to(pivot), LeadAction.ACTION_ARM) \
			or not _mission._terrain.camera_position(pivot, camera.position).is_equal_approx(camera.position) \
			or fight.defense.phase != Defense.Phase.GUARD or not _carry_projects(false):
		return _fail("Contact missed the actual camera-safe tightened lens, direct guard, or approved carry.")
	_button_event(JOY_BUTTON_LEFT_SHOULDER, false)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	if root.get_camera_3d() != _mission._command_camera:
		return _fail("L2 did not immediately take priority over action framing.")
	_tick()
	await _checkpoint("03-same-contact-tactical")
	if _hud._lead_action.active or not _carry_projects(true):
		return _fail("Command retained the hero lens or lost the approved tactical carry.")
	var cursor := _mission.cursor
	var selected := _mission.selected_index
	_button(JOY_BUTTON_DPAD_UP)
	_tick()
	var draft := _hud._draft_point
	_button(JOY_BUTTON_DPAD_DOWN)
	_tick()
	if not _hud._reticle.visible or _hud._draft_point == draft or _mission.cursor != cursor \
			or _mission.selected_index != selected or not _hud._lead_action.focused:
		return _fail("Minimap Down changed lead focus or lost its separate draft cursor.")
	_button(JOY_BUTTON_B)
	_button(JOY_BUTTON_RIGHT_STICK)
	_tick()
	if _hud._reticle.visible or not _mission._sector.overview:
		return _fail("Cancelling the draft or opening native overview no longer works.")
	# Actually issue a waypoint from the existing battlefield cursor. Contact selected
	# Mara's own platoon; pick the infantry directly, since cycling with the D-pad in
	# command view deliberately clears Mara's focus.
	if selected == Battle.LEAD_INDEX:
		_mission.selected_index = 0
		_mission._sync_view()
		selected = 0
	var foot := _mission.battle.formations[selected]
	var before := foot.position
	var move := InputEventMouseMotion.new()
	var destination := _position("Routes/WestAssembly")
	move.position = _mission._command_camera.unproject_position(_mission.to_global(_mission._ground(destination)))
	root.push_input(move, true)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_tick(3)
	if _hud.pending_waypoints(selected).size() != 1 or foot.order != Battle.Order.MOVE or foot.position == before:
		return _fail("The existing selected formation could not receive or execute its real queue.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_tick()
	if not _hud._lead_action.active or root.get_camera_3d() != camera:
		return _fail("L2 release did not return to the still-focused actual contact.")
	_key(KEY_C)
	_tick()
	await _checkpoint("04-contact-with-focus-off")
	if _hud._lead_action.active or not _baseline_arm():
		return _fail("Keyboard opt-out did not restore the normal lens at the same contact.")
	_key(KEY_C)
	_tick()
	if not _hud._lead_action.active or fight.points.balance != initial_bp:
		return _fail("Keyboard focus did not restore action framing or spent Battle Points.")
	# Cycling allies in command explicitly leaves Mara focus; the focus binding
	# can arm it again without touching the selected platoon or its pending route.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_tick()
	if _hud._lead_action.focused or _mission.selected_index == selected or _hud.pending_waypoints(selected).size() != 1:
		return _fail("Explicit ally selection retained Mara focus or changed the previous route.")
	_button(JOY_BUTTON_DPAD_DOWN)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_tick()
	# Attacks belong to Mara's own platoon: D-pad back to her before swinging.
	for _step in 3:
		if _mission.selected_index == Battle.LEAD_INDEX:
			break
		_button(JOY_BUTTON_DPAD_LEFT)
		_tick()
	var guard_hp := fight.enemy.hp
	_button(JOY_BUTTON_X)
	_tick()
	if fight.defense.attack_kind != Attack.Attack.LIGHT or fight.defense.attack_phase != Attack.Phase.WINDUP:
		return _fail("Square did not keep the real direct attack binding during action framing.")
	_tick(32)
	if fight.enemy.hp >= guard_hp or fight.points.balance <= initial_bp:
		return _fail("Square did not connect and credit a real light attack from the contact lens.")
	var away := (_mission.battle.hero_position - fight.enemy_position).normalized()
	var before_dodge := _mission.battle.hero_position
	_move_toward(before_dodge + 8.0 * away)
	_button(JOY_BUTTON_B)
	_tick(12)
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_LEFT_Y, 0)
	if _mission.battle.hero_position.distance_to(before_dodge) < 0.5 or _hud._lead_action.active \
			or not _baseline_arm() or not _hud._lead_action.focused:
		return _fail("A genuine dodge did not create separation and restore ordinary framing.")
	await _checkpoint("05-separated-after-dodge")
	_button(JOY_BUTTON_START)
	_tick()
	return (not _hud._lead_action.focused and not _hud._lead_action.active and _baseline_arm() \
		and not _mission.command_view and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP) \
		or _fail("Retry retained an old focus or action frame.")


func _carry_projects(tactical: bool) -> bool:
	var case_node := _mission._custody_case
	var mesh: MeshInstance3D = case_node._tactical_case if tactical else case_node._case
	var other: MeshInstance3D = case_node._case if tactical else case_node._tactical_case
	var camera := root.get_camera_3d()
	return mesh.is_visible_in_tree() and not other.is_visible_in_tree() \
		and case_node._keeper.is_visible_in_tree() != tactical \
		and not camera.is_position_behind(mesh.global_position) \
		and root.get_visible_rect().has_point(camera.unproject_position(mesh.global_position))


func _baseline_arm() -> bool:
	var pivot := _mission._ground(_mission.battle.hero_position, 1.15)
	var desired := pivot + Vector3(0, sin(_mission._hero_pitch), cos(_mission._hero_pitch)) \
		.rotated(Vector3.UP, _mission._hero_yaw) * 6.1
	return _mission._hero_camera.position.is_equal_approx(_mission._terrain.camera_position(pivot, desired))


func _checkpoint(_label: String) -> void:
	# The same test can be exercised with a native rendering capture script.
	pass


func _position(id: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/" + id)))


func _walk(destination: Vector2) -> bool:
	var cap := ceili(_mission.battle.hero_position.distance_to(destination) / Battle.LEAD_SPEED / DT) + 130
	for i in cap:
		if _mission.battle.hero_position.distance_to(destination) < 0.14:
			_axis(JOY_AXIS_LEFT_X, 0)
			_axis(JOY_AXIS_LEFT_Y, 0)
			return true
		_move_toward(destination)
		_tick()
	return false


func _move_toward(destination: Vector2) -> void:
	var axes := (destination - _mission.battle.hero_position).normalized().rotated(_mission._hero_yaw)
	_march_lead(Vector2(axes.x, axes.y))


func _tick(count := 1) -> void:
	for i in count:
		_mission._physics_process(DT)
		_hud._physics_process(DT)


func _button(button: JoyButton) -> void:
	_button_event(button, true)
	_button_event(button, false)


func _button_event(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false


## Outside combat the leader travels with their platoon by Move orders, as the
## player sets them; in combat the stick steers the leader directly.
func _march_lead(aim: Vector2) -> void:
	var battle = _mission.battle
	if battle.direct_hero_control():
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		return
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	if aim.length_squared() > 0.0:
		battle.order_move(Battle.LEAD_INDEX, battle.hero_position + aim.normalized().rotated(-_mission._hero_yaw) * Battle.LEAD_SPEED * DT)
