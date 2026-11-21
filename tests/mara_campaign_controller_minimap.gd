extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Adapter := preload("res://game/battlefield/mara_campaign_minimap.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
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
	_hud.refresh()
	var passed := _confirm_move() and _reject_and_cancel() and _release_without_combat_leaks()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Mara campaign controller minimap: live projected Move, actual march, roof rejection, cancel and L2 release, held input quarantine and restored combat passed.")
	quit(0 if passed else 1)


func _confirm_move() -> bool:
	_button(JOY_BUTTON_DPAD_UP)
	if _hud._reticle.visible or _hud._draft_battle or _mission.command_view:
		return _fail("Hero view opened or acquired minimap focus.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_tick()
	var world_cursor := _mission.cursor
	var world_focus := _mission._sector.focus
	var index := _mission.selected_index
	var formation := _mission.battle.formations[index]
	_button(JOY_BUTTON_DPAD_UP)
	var target := _marker("RidgeWestApproach")
	if not _aim(target) or not _hud._reticle.pixel.is_equal_approx(_hud.map.project(target)) \
			or _mission.cursor != world_cursor or _mission._sector.focus != world_focus \
			or _mission.selected_index != index or formation.order != Battle.Order.HOLD:
		return _fail("D-pad aiming bypassed the separate fitted cursor or changed a live order or camera.")
	_joy(JOY_BUTTON_A, true)
	_joy(JOY_BUTTON_A, true) # A repeat after closing may not become command Hold.
	_joy(JOY_BUTTON_A, false)
	if _hud._draft_battle or _hud._reticle.visible or not _mission.command_view \
			or not _mission._command_camera.is_current() or formation.order != Battle.Order.MOVE \
			or formation.destination != target or _mission._sector.focus != target:
		return _fail("Confirmed map input did not issue exactly one real Move and keep L2 command view.")
	return true


func _reject_and_cancel() -> bool:
	var formation := _mission.battle.formations[_mission.selected_index]
	var destination := formation.destination
	var origin := formation.position
	var world_cursor := _mission.cursor
	var focus := _mission._sector.focus
	_button(JOY_BUTTON_DPAD_UP)
	var roof := Vector2(-63, 94)
	if not _aim(roof) or _mission._terrain.destination_from_ray(
		Vector3(roof.x, 30.0, roof.y), Vector3(roof.x, -12.0, roof.y)
	) != null:
		return _fail("The rejected position was not on the real tunnel roof.")
	_button(JOY_BUTTON_A)
	if not _hud._draft_battle or not _hud._key.text.contains("Not a walkable point") \
			or formation.destination != destination or formation.order != Battle.Order.MOVE:
		return _fail("An invalid overhead point closed the draft or escaped the real terrain rule.")
	# A GUI click during the scoped controller draft may not escape to the world.
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	mouse.position = _hud.map.get_global_rect().position + _hud.map.project(Vector2(-145, -24))
	root.push_input(mouse, true)
	_tick(5)
	_joy(JOY_BUTTON_B, true)
	var hero := _mission.battle.hero_position
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_joy(JOY_BUTTON_B, true)
	_joy(JOY_BUTTON_B, false)
	_tick(5)
	if _hud._draft_battle or _mission.command_view or _mission.cursor != world_cursor \
			or _mission._sector.focus != focus or formation.destination != destination or formation.position == origin \
			or _mission.battle.hero_position != hero or _mission.encounter.defense.phase != Defense.Phase.FREE:
		return _fail("Circle cancel did not preserve the earlier live march, camera or hero controls.")
	for _step in 320:
		if formation.order != Battle.Order.MOVE:
			break
		_tick()
	return (formation.position == destination and formation.order == Battle.Order.HOLD) \
		or _fail("The confirmed platoon did not physically arrive at the authored marker.")


func _release_without_combat_leaks() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_DPAD_UP)
	if not _hud._draft_battle:
		return _fail("The controller couldn't reopen the scoped minimap.")
	var start := _mission.battle.hero_position
	var points := _mission.encounter.points.balance
	var old_point := _hud._draft_point
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_Y, true)
	_joy(JOY_BUTTON_LEFT_SHOULDER, true)
	_tick(4)
	if _hud._draft_point == old_point or _mission.battle.hero_position != start:
		return _fail("Scope stick did not move the reticle independently.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	# Held controls that belonged to the map remain suppressed after L2 closes.
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_Y, true)
	_joy(JOY_BUTTON_LEFT_SHOULDER, true)
	_tick(10)
	if _hud._draft_battle or _hud._reticle.visible or _mission.command_view \
			or not _mission._hero_camera.is_current() or _mission.battle.hero_position != start \
			or _mission.encounter.defense.attack_phase != Attack.Phase.IDLE \
			or _mission.encounter.defense.phase != Defense.Phase.FREE \
			or _mission.encounter.points.balance != points:
		return _fail("Held move, light/heavy attack, guard, or Sundering input leaked out of minimap focus.")
	_joy(JOY_BUTTON_X, false)
	_joy(JOY_BUTTON_Y, false)
	_joy(JOY_BUTTON_LEFT_SHOULDER, false)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_tick(4)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	if _mission.battle.hero_position == start:
		return _fail("Neutral plus a fresh stick input did not recover ordinary hero movement.")
	_joy(JOY_BUTTON_LEFT_SHOULDER, true)
	_tick()
	if _mission.encounter.defense.phase != Defense.Phase.GUARD:
		return _fail("Fresh guard input did not recover after leaving the minimap.")
	_joy(JOY_BUTTON_LEFT_SHOULDER, false)
	_button(JOY_BUTTON_X)
	return _mission.encounter.defense.attack_phase == Attack.Phase.WINDUP \
		or _fail("Fresh hero attack input did not recover after leaving the minimap.")


func _aim(point: Vector2) -> bool:
	var offset := point - _hud._draft_point
	var nudge := Adapter.CURSOR_NUDGE
	for _step in absi(roundi(offset.x / nudge)):
		_button(JOY_BUTTON_DPAD_RIGHT if offset.x > 0.0 else JOY_BUTTON_DPAD_LEFT)
	for _step in absi(roundi(offset.y / nudge)):
		_button(JOY_BUTTON_DPAD_DOWN if offset.y > 0.0 else JOY_BUTTON_DPAD_UP)
	return (_hud._draft_battle != null and _hud._draft_point.is_equal_approx(point)) \
		or _fail("The scoped controller did not position the reticle at the requested map point.")


func _marker(id: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/Routes/" + id)))


func _tick(count := 1) -> void:
	for _step in count:
		_mission._physics_process(DT)
		_hud._physics_process(DT)


func _axis(axis: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	_joy(code, true)
	_joy(code, false)


func _joy(code: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = down
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
