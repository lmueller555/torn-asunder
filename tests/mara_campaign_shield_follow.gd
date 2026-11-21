extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Adapter := preload("res://game/battlefield/mara_campaign_minimap.gd")
const Follow := preload("res://game/battlefield/mara_shield_follow_camera.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Fight := preload("res://game/battlefield/mara_mine_encounter.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
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
	var passed := _stage_real_escort() and await _check_lens()
	_mission.queue_free()
	await process_frame
	if passed:
		print("Mara Shield follow: actual approach/contact, retained cursor and queue, overview/minimap/manual suppression and restored hero inputs passed.")
	quit(0 if passed else 1)


func _stage_real_escort() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	var foot := _mission.battle.formations[0]
	for id in ["WestAssembly", "QuarryTurn", "RoadWest", "RoadJunction", "RoadCut", "EastPass"]:
		_aim(_position("Routes/" + id))
		_button(JOY_BUTTON_RIGHT_SHOULDER)
	if _hud.pending_waypoints(0).size() != 6:
		return _fail("Existing controls did not queue the real infantry approach.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	for id in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard", "Objectives/GodbridlePickup"]:
		if not _walk(id):
			return false
	_button(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Escort.Phase.ESCORTING:
		return _fail("The actual Mine pickup did not start the escort.")
	for id in ["RoadWest", "RoadJunction", "RoadCut", "EastPass"]:
		if not _walk("Routes/" + id):
			return false
	var fight := _mission.encounter
	if not _until(func() -> bool: return foot.position.distance_to(_position("Routes/EastPass")) < 0.2 			and fight.enemy_phase == Fight.EnemyPhase.WATCHING, 6000):
		return _fail("The queued infantry or existing guard did not reach the actual pass.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_RIGHT_STICK)
	_button(JOY_BUTTON_DPAD_RIGHT)
	for id in ["RidgeWestApproach", "RidgeWestFoot", "RidgeWestCrest", "RidgeOverlook"]:
		_aim(_position("Routes/" + id))
		_button(JOY_BUTTON_RIGHT_SHOULDER)
	_button(JOY_BUTTON_DPAD_LEFT)
	_button(JOY_BUTTON_LEFT_STICK)
	_aim(fight.enemy_position)
	_button(JOY_BUTTON_Y)
	# The regular tactical cursor remains authoritative. A small stick pulse
	# switches from pointer aiming without changing the attack target.
	_axis(JOY_AXIS_LEFT_X, 0.30)
	_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	return (foot.order == Battle.Order.ATTACK and not _hud._shield_follow.active 		and _mission.objective.interception_triggered and _hud.pending_waypoints(1).size() == 4) 		or _fail("An approach stole the camera, bypassed real interception, or lost the other platoon's route.")


func _check_lens() -> bool:
	var camera := _mission._command_camera
	var fight := _mission.encounter
	var foot := _mission.battle.formations[0]
	var cursor := _mission.cursor
	var focus := _mission._sector.focus
	var tactical_position := camera.position
	var span := camera.size
	await _checkpoint("before-contact")
	if not _until(func() -> bool: return _hud._shield_follow.active, 400):
		return _fail("The real melee exchange did not reframe the selected unit.")
	var unchanged_bow_route := _hud.pending_waypoints(1)
	_tick(14)
	await _checkpoint("shield-contact")
	var bow_pending := _hud.pending_waypoints(1)
	# The first leg may finish during these frames. The remaining order must
	# continue naturally, never be replaced or cleared by a camera pan.
	var bow_order_kept := not bow_pending.is_empty() and unchanged_bow_route.slice(unchanged_bow_route.size() - bow_pending.size()) == bow_pending \
		and _mission.battle.formations[1].destination == bow_pending[0]
	if not _mission.command_view or camera != root.get_camera_3d() or camera.size != span 			or camera.position.distance_to(tactical_position) < 2.0 			or _mission.cursor != cursor or _mission._sector.focus != focus 			or not bow_order_kept or foot.order != Battle.Order.ATTACK:
		return _fail("Follow failed to render a real pan or rewrote the command cursor/sector/bow queue.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_tick()
	if _hud._shield_follow.active or _mission.selected_index != 1 or _mission.cursor != cursor 			or not camera.position.is_equal_approx(tactical_position):
		return _fail("Another selected platoon did not immediately restore the preceding tactical lens and cursor.")
	_button(JOY_BUTTON_DPAD_LEFT)
	_tick()
	if not _hud._shield_follow.active:
		return _fail("Reselecting the engaged Shield Infantry did not restore their follow lens.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_tick()
	await _checkpoint("overview")
	if _hud._shield_follow.active or not _mission._sector.overview or camera.size <= span 			or _mission.cursor != cursor:
		return _fail("An active melee follow interfered with native overview.")
	_button(JOY_BUTTON_RIGHT_STICK)
	_tick()
	_button(JOY_BUTTON_DPAD_UP)
	_tick()
	_button(JOY_BUTTON_DPAD_RIGHT)
	await _checkpoint("minimap-cursor")
	if _hud._shield_follow.active or not _hud._reticle.visible or _mission.cursor != cursor 			or _mission.selected_index != 0:
		return _fail("The minimap draft did not keep ownership of D-pad without changing original world cursor.")
	_button(JOY_BUTTON_B)
	_tick()
	if not _hud._shield_follow.active:
		return _fail("Returning from a cancelled minimap draft did not resume contact follow.")
	_axis(JOY_AXIS_LEFT_X, 0.5)
	_tick()
	if _hud._shield_follow.active or _mission.cursor == cursor or _mission._sector.overview:
		return _fail("Stick aiming during contact did not regain the real tactical cursor.")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_tick()
	if not _hud._shield_follow.active:
		return _fail("Neutral stick did not allow the existing contact lens to resume.")
	# Send a baseline screen projection, not a point from the adjusted lens.
	var offset := _hud._shield_follow._shift
	var attempted := fight.enemy_position + Vector2(-2.0, 0.0)
	var pointer := camera.unproject_position(_mission.to_global(_mission._ground(attempted) + offset))
	var mouse := InputEventMouseMotion.new()
	mouse.position = pointer
	root.push_input(mouse, true)
	_tick()
	if _hud._shield_follow.active or _mission.cursor.distance_to(attempted) > 0.08:
		return _fail("The first mouse event used the follow projection rather than native tactical aiming.")
	await _checkpoint("world-cursor")

	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	await _checkpoint("hero-return")
	if _mission.command_view or _hud._shield_follow.active or root.get_camera_3d() != _mission._hero_camera:
		return _fail("L2 release did not immediately restore Mara's direct lens.")
	_button(JOY_BUTTON_B)
	_tick()
	if fight.defense.phase not in [Defense.Phase.DODGE_STARTUP, Defense.Phase.DODGE_ACTIVE]:
		return _fail("Circle did not immediately resume Mara's actual dodge.")
	_tick(45)
	_key(KEY_V)
	return (fight.defense.attack_phase == Attack.Phase.WINDUP 		and fight.defense.attack_kind == Attack.Attack.SUNDERING_STRIKE and foot.order == Battle.Order.ATTACK) 		or _fail("Mara's existing direct special or the already-issued infantry order was lost.")


func _checkpoint(_label: String) -> void:
	# Separate local renderer harness may override this without changing the test.
	pass


func _walk(id: String) -> bool:
	var at := _position(id)
	var cap := ceili(_mission.battle.hero_position.distance_to(at) / Battle.HERO_SPEED / DT) + 130
	var reached := false
	for i in cap:
		var offset := at - _mission.battle.hero_position
		if offset.length() < 0.14:
			reached = true
			break
		var axes := offset.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, axes.x)
		_axis(JOY_AXIS_LEFT_Y, axes.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return reached or _fail("Mara missed route marker: " + id)


func _position(id: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/" + id)))


func _aim(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _mission._command_camera.unproject_position(_mission.to_global(_mission._ground(point)))
	root.push_input(event, true)


func _until(condition: Callable, cap: int) -> bool:
	for i in cap:
		if condition.call():
			return true
		_tick()
	return condition.call()


func _tick(count := 1) -> void:
	for i in count:
		_mission._physics_process(DT)
		_hud._physics_process(DT)


func _button(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
