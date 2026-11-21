extends "res://game/battlefield/command_harness.gd"
## Standalone Human withdrawal using the shared, fixed post-rise harbor.

signal mission_finished(won: bool)

const Levy := preload("res://game/battlefield/moonwash_levy_patrol.gd")
const Patrol := preload("res://game/battlefield/patrol_detection_policy.gd")
const Quay := preload("res://game/battlefield/mara_moonwash_quay.gd")
const EXIT_RADIUS := 3.8
const CUE_RADIUS := 12.0
const LANDING_RADIUS := 8.0
const FOLLOW_MAX_SHIFT := 14.0
const FOLLOW_SPEED := 24.0
const AIM_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_R, KEY_F]
const SAFE_COLOR := Color("#a3ebda")
const HAZARD_COLOR := Color("#ffb179")
const SAFE_ROUTE := ["QuaySafeTurn", "InlandBypass", "InlandApproach", "InlandStairTop", "UpperQuay", "UpperQuayExit"]

@export var levy_enabled := true

var objective := Quay.new()
var levy: Levy
var _levy_visual: Node3D
var _levy_label: Label3D
var _levy_ring: MeshInstance3D
var _exit: Marker3D
var _landing: Marker3D
var _foot: Marker3D
var _fracture: Marker3D
var _gate: Marker3D
var _gate_box: AABB
var _blocker: StaticBody3D
var _rubble: Node3D
var _cracks: Node3D
var _checked_bypass := false
var _bypass_open := false
var _landing_reached := false
var _warned_in_prior_step := false
var _hero_down := false
var _follow_shift := Vector3.ZERO

@onready var _goal: Label = $WithdrawalHUD/Panel/Margin/Readout/Goal
@onready var _roster: Label = $WithdrawalHUD/Panel/Margin/Readout/Roster
@onready var _levy_status: Label = $WithdrawalHUD/Panel/Margin/Readout/Levy
@onready var _route: Label = $WithdrawalHUD/Panel/Margin/Readout/Route
@onready var _restart: Button = $WithdrawalHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_exit = battlefield_marker(^"Markers/Objectives/UpperQuayExit")
	_landing = _route_marker("UpperStairLanding")
	_foot = _route_marker("UpperStairFoot")
	_fracture = battlefield_marker(^"Markers/PhaseZones/FracturedSlab")
	_gate = battlefield_marker(^"Markers/PhaseZones/LowerStairClosure")
	_build_hazard()
	_build_levy_visual()
	_reset_levy()
	_signpost(_exit, "UPPER QUAY EXIT", SAFE_COLOR, EXIT_RADIUS)
	_signpost(_landing, "STAIR LANDING", SAFE_COLOR)
	_signpost(_route_marker("QuaySafeTurn"), "INLAND BYPASS", SAFE_COLOR)
	_signpost(_route_marker("InlandApproach"), "INLAND STAIRS", SAFE_COLOR)
	objective.platoon_extracted.connect(_lock_platoon)
	objective.lower_quay_warned.connect(func() -> void: _cracks.show())
	objective.lower_quay_closed.connect(func() -> void: _set_gate_closed(true))
	_restart.pressed.connect(restart_mission)
	_refresh_withdrawal()


func _physics_process(delta: float) -> void:
	if objective.phase != Quay.Phase.WITHDRAWING:
		return
	super._physics_process(delta)
	var observation := Quay.Observation.new()
	observation.hero_defeated = _hero_down
	observation.hero_crossed_upper_exit = not _hero_down and _in_exit(hero_world_position())
	observation.first = _platoon_observation(Quay.Platoon.FIRST)
	observation.second = _platoon_observation(Quay.Platoon.SECOND)
	observation.lower_quay_cracking = _any_active_near(_fracture.global_position, CUE_RADIUS) \
		or _any_active_near(_foot.global_position, CUE_RADIUS)
	_landing_reached = _landing_reached or _any_active_near(_landing.global_position, LANDING_RADIUS)
	observation.lower_quay_closure_requested = _warned_in_prior_step and _landing_reached and _gate_unoccupied()
	if objective.lower_quay == Quay.LowerQuay.WARNED and observation.lower_quay_closure_requested:
		if not _checked_bypass:
			_bypass_open = _inland_route_is_open()
			_checked_bypass = true
		observation.inland_route_open = _bypass_open
	objective.advance(observation)
	# A warning and a physical closure must not happen in the same update.
	_warned_in_prior_step = objective.lower_quay == Quay.LowerQuay.WARNED
	_refresh_withdrawal()
	_frame_levy_follow(delta)
	if objective.phase != Quay.Phase.WITHDRAWING:
		_levy_status.hide()
		mission_finished.emit(objective.phase == Quay.Phase.SUCCEEDED)


func _frame_levy_follow(delta: float) -> void:
	# Called only after the harness writes its normal orthographic pose.
	# Follow changes that frame's camera position, never the sector state.
	var previous := _follow_shift
	_follow_shift = Vector3.ZERO
	if not command_view or not _sector or _sector.overview or not _command_camera.is_current() \
			or objective.phase != Quay.Phase.WITHDRAWING or not levy or _mouse_cursor_active:
		return
	var group := battle.formations[selected_index]
	# ENGAGE is the levy adapter's current, unobstructed same-level body
	# contact, not a pursuit or memory. No follow for hero or another platoon.
	if not group.can_receive_orders() or levy.decision.intent != Patrol.Intent.ENGAGE \
			or levy.decision.contact_id != StringName(group.title):
		return
	if not _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).is_zero_approx() \
			or not _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).is_zero_approx():
		return
	for key: int in AIM_KEYS:
		if _keys.has(key):
			return
	var window := get_viewport().get_visible_rect()
	if not window.has_area():
		return
	var safe := window.grow(-0.06 * minf(window.size.x, window.size.y))
	var camera := _command_camera
	var normal := camera.position
	var toward := (group.position - _sector.view_center()).limit_length(FOLLOW_MAX_SHIFT)
	var offset := previous.move_toward(Vector3(toward.x, 0, toward.y), FOLLOW_SPEED * delta)
	camera.position = normal + offset
	for point: Vector2 in [cursor, group.position, levy.position]:
		var at := to_global(_ground(point))
		if camera.is_position_behind(at) or not safe.has_point(camera.unproject_position(at)):
			camera.position = normal
			return
	_follow_shift = offset


func _restore_levy_follow() -> void:
	if _follow_shift != Vector3.ZERO:
		_follow_shift = Vector3.ZERO
		_update_cameras()


func _input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if _follow_shift == Vector3.ZERO:
		return
	if event is InputEventMouse or event is InputEventKey:
		_restore_levy_follow()
	elif event is InputEventJoypadButton and event.pressed and event.device == _input_device:
		_restore_levy_follow()
	elif event is InputEventJoypadMotion and event.device == _input_device:
		var axis: JoyAxis = event.axis
		if axis == JOY_AXIS_TRIGGER_LEFT:
			if event.axis_value <= L2_RELEASE:
				_restore_levy_follow()
		elif axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			# Use the same radial deadzone for the incoming stick pair. Do not
			# bounce off the follow lens on neutral stick noise.
			var x_axis := JOY_AXIS_LEFT_X if axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else JOY_AXIS_RIGHT_X
			var y_axis := JOY_AXIS_LEFT_Y if x_axis == JOY_AXIS_LEFT_X else JOY_AXIS_RIGHT_Y
			var input := Vector2(event.axis_value, _axis(y_axis)) if axis == x_axis \
				else Vector2(_axis(x_axis), event.axis_value)
			if input.length() > STICK_DEADZONE:
				_restore_levy_follow()
	# Do not consume anything: inherited ray picking and inputs remain in charge.


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED] and is_node_ready():
		_restore_levy_follow()
	super._notification(what)


func _after_battle_step(delta: float) -> void:
	if levy:
		levy.advance(delta, battle, not _hero_down and not objective.hero_extracted)
		_refresh_levy()


func _movement_check() -> Callable:
	return _can_pass_levy if levy else super._movement_check()


func _can_pass_levy(from: Vector2, to: Vector2, is_formation: bool) -> bool:
	return not levy.blocks_move(from, to, is_formation) and _terrain.can_move(from, to, is_formation)


func _reset_levy() -> void:
	var start := battlefield_marker(^"Markers/Spawns/LocalLevy")
	var turnaround := _route_marker("FracturedQuay")
	levy = Levy.new(PackedVector2Array([_marker_position(start), _marker_position(turnaround)]), _terrain) \
		if levy_enabled and start and turnaround else null
	_refresh_levy()


func _build_levy_visual() -> void:
	_levy_visual = Node3D.new()
	_levy_visual.name = "LocalLevy"
	add_child(_levy_visual)
	var coat := _material(Color("#a4845b"))
	var iron := _material(Color("#89786d"))
	_mesh(_levy_visual, _box(Vector3(0.72, 1.02, 0.50)), coat, Vector3(0, 0.79, 0))
	_mesh(_levy_visual, _box(Vector3(0.51, 0.43, 0.45)), iron, Vector3(0, 1.52, 0))
	_mesh(_levy_visual, _box(Vector3(0.63, 0.60, 0.15)), iron, Vector3(0, 0.88, -0.32))
	_levy_ring = _mesh(_levy_visual, _ring(0.62, 0.78), _material(HAZARD_COLOR, true), Vector3.UP * 0.075)
	_levy_label = Label3D.new()
	_levy_label.position.y = 2.48
	_levy_label.pixel_size = 0.022
	_levy_label.font_size = 44
	_levy_label.outline_size = 11
	_levy_label.modulate = HAZARD_COLOR
	_levy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_levy_visual.add_child(_levy_label)


func _refresh_levy() -> void:
	_levy_visual.visible = levy != null
	_levy_status.visible = false
	if not levy:
		return
	_levy_visual.position = _ground(levy.position)
	_levy_visual.rotation.y = atan2(-levy.heading.x, -levy.heading.y)
	var known := not levy.decision.visible_contacts.is_empty()
	_levy_label.visible = known
	_levy_ring.visible = known
	_levy_label.text = "LEVY · CONTACT" if levy.decision.intent == Patrol.Intent.ENGAGE else "LEVY · ALERT"
	match levy.decision.intent:
		Patrol.Intent.ENGAGE:
			_levy_status.text = "%s is in contact with the levy. Make room or take the inland bypass." % levy.decision.contact_id
			for group in battle.formations:
				if StringName(group.title) == levy.decision.contact_id and group.order == Battle.Order.HOLD:
					_levy_status.text = "%s is screening the levy. Move the others around." % group.title
					break
		Patrol.Intent.PURSUE:
			_levy_status.text = "The levy spotted %s. Withdraw uphill or break sight." % levy.decision.contact_id
		Patrol.Intent.INVESTIGATE:
			_levy_status.text = "The levy is checking the last contact." if known \
				else "The levy lost sight and is checking the last contact."
		_:
			if known:
				_levy_status.text = "The levy sees movement but is holding its patrol ground."
	_levy_status.visible = known or levy.decision.intent == Patrol.Intent.INVESTIGATE


func _platoon_observation(slot: Quay.Platoon) -> Quay.PlatoonObservation:
	if objective.is_platoon_extracted(slot):
		return null
	var state := Quay.PlatoonObservation.new()
	if battle.formations[slot].order == Battle.Order.DEFEATED:
		return state
	for index in range(_formation_members[slot].size()):
		var member: Node3D = _formation_members[slot][index]
		var id := str(index)
		# The placeholders are all alive unless the living group has been wiped.
		# Keeping past crossers in the live roster supports a staggered exit.
		state.living_members.append(id)
		if member.visible and _in_exit(member.global_position):
			state.crossed_upper_exit.append(id)
			member.hide()
	return state


func _in_exit(feet: Vector3) -> bool:
	var offset := feet - _exit.global_position
	return absf(offset.y) <= 1.0 and Vector2(offset.x, offset.z).length_squared() <= EXIT_RADIUS * EXIT_RADIUS


func _lock_platoon(slot: Quay.Platoon) -> void:
	battle.formations[slot].extract()
	_sync_view()


func _hero_move_factor() -> float:
	return 0.0 if objective.hero_extracted or _hero_down else 1.0


func _build_placeholders() -> void:
	_name_platoons()
	super._build_placeholders()


func _name_platoons() -> void:
	battle.formations[0].title = "Royal Vanguard"
	battle.formations[1].title = "Royal Rear Guard"


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_BACKSPACE:
		restart_mission()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and _uses_joypad(event.device):
		restart_mission()
		return
	if objective.phase == Quay.Phase.WITHDRAWING:
		super._unhandled_input(event)


func report_hero_defeated() -> void:
	if not objective.hero_extracted:
		_hero_down = true


func report_platoon_wiped(slot: Quay.Platoon) -> void:
	if objective.can_order_platoon(slot):
		battle.formations[slot].defeat()


func restart_mission() -> void:
	_restore_levy_follow()
	objective.restart()
	_hero_down = false
	_checked_bypass = false
	_bypass_open = false
	_landing_reached = false
	_warned_in_prior_step = false
	_set_gate_closed(false)
	_cracks.hide()
	_restart.release_focus()
	restart_battle()
	_name_platoons()
	_reset_levy()
	for group in _formation_members:
		for member: Node3D in group:
			member.show()
	_sync_view()
	_refresh_withdrawal()


func _route_marker(id: String) -> Marker3D:
	return battlefield_marker(NodePath("Markers/Routes/" + id))


func _any_active_near(world: Vector3, radius: float) -> bool:
	if not objective.hero_extracted and not _hero_down and hero_world_position().distance_to(world) <= radius:
		return true
	for group in battle.formations:
		if group.can_receive_orders() and to_global(_ground(group.position)).distance_to(world) <= radius:
			return true
	return false


func _gate_unoccupied() -> bool:
	var margin := 1.75
	var space := _gate_box.grow(margin)
	if not objective.hero_extracted and not _hero_down and space.has_point(to_local(hero_world_position())):
		return false
	for group in battle.formations:
		if group.can_receive_orders() and space.has_point(_ground(group.position)):
			return false
	return true


func _inland_route_is_open() -> bool:
	var gate_margin := _gate_box.grow(1.75)
	for index in range(1, SAFE_ROUTE.size()):
		var first := _safe_marker(SAFE_ROUTE[index - 1])
		var second := _safe_marker(SAFE_ROUTE[index])
		if not first or not second:
			return false
		var start := _marker_position(first)
		var finish := _marker_position(second)
		var steps := maxi(1, ceili(start.distance_to(finish) / 0.25))
		var previous := start
		for step in range(steps + 1):
			var point := start.lerp(finish, float(step) / steps)
			if gate_margin.has_point(_ground(point)) or (step > 0 and not _terrain.can_move(previous, point, true)):
				return false
			previous = point
	return true


func _safe_marker(id: String) -> Marker3D:
	return _exit if id == "UpperQuayExit" else _route_marker(id)


func _build_hazard() -> void:
	var dimensions: Vector3 = _gate.get_meta("box_size")
	var center := to_local(_gate.global_position)
	_gate_box = AABB(center - dimensions * 0.5, dimensions)
	_blocker = StaticBody3D.new()
	_blocker.name = "ScenarioLowerStairClosure"
	_blocker.position = center
	_blocker.collision_mask = 0
	add_child(_blocker)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collision.shape = box
	_blocker.add_child(collision)
	_rubble = Node3D.new()
	_blocker.add_child(_rubble)
	var stone := _material(Color("#85605a"))
	_mesh(_rubble, _box(dimensions), stone)
	_signpost(_gate, "LOWER STAIR CLOSED", HAZARD_COLOR).reparent(_rubble, true)

	_cracks = Node3D.new()
	add_child(_cracks)
	_cracks.position = to_local(_fracture.global_position) - Vector3.UP * (float(_fracture.get_meta("box_size").y) * 0.5 - 0.065)
	var bright := _material(HAZARD_COLOR, true)
	for index in range(5):
		var mark := _mesh(_cracks, _box(Vector3(4.5, 0.025, 0.10)), bright, Vector3((index - 2) * 3.4, 0, 0))
		mark.rotation.y = 0.36 if index % 2 == 0 else -0.38
	var warning := _signpost(_gate, "CRACKING LOWER STAIR", HAZARD_COLOR)
	warning.reparent(_cracks, true)
	_cracks.hide()
	_set_gate_closed(false)


func _set_gate_closed(closed: bool) -> void:
	_blocker.collision_layer = 1 if closed else 0
	_rubble.visible = closed
	if closed:
		_cracks.hide()


func _signpost(anchor: Marker3D, text: String, color: Color, radius := 0.0) -> Node3D:
	var sign := Node3D.new()
	add_child(sign)
	sign.global_position = anchor.global_position
	var material := _material(color, true)
	if radius > 0.0:
		_mesh(sign, _ring(radius - 0.13, radius), material, Vector3.UP * 0.08)
	_mesh(sign, _box(Vector3(0.075, 2.4, 0.075)), material, Vector3.UP * 1.20)
	var label := Label3D.new()
	label.text = text
	label.position.y = 3.0
	label.pixel_size = 0.025
	label.font_size = 44
	label.outline_size = 11
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.add_child(label)
	return sign


func _refresh_withdrawal() -> void:
	var status := PackedStringArray()
	var hero_state := "Safe" if objective.hero_extracted else ("Lost" if _hero_down else "Withdrawing")
	status.append("Hero: " + hero_state)
	for index in range(battle.formations.size()):
		var group := battle.formations[index]
		var state := "Withdrawing"
		if group.order == Battle.Order.EXTRACTED:
			state = "Extracted"
		elif group.order == Battle.Order.DEFEATED:
			state = "Lost"
		status.append("%s: %s" % [group.title, state])
	_roster.text = "  ·  ".join(status)
	match objective.phase:
		Quay.Phase.SUCCEEDED:
			_goal.text = "Withdrawal complete"
			_route.text = "The hero and surviving members of both platoons reached the upper exit."
		Quay.Phase.FAILED:
			_goal.text = "Withdrawal failed"
			match objective.failure:
				Quay.Failure.HERO_DEFEATED: _route.text = "The hero was defeated. Restart to try again."
				Quay.Failure.FIRST_PLATOON_LOST: _route.text = "The Royal Vanguard was lost before extraction."
				Quay.Failure.SECOND_PLATOON_LOST: _route.text = "The Royal Rear Guard was lost before extraction."
		Quay.Phase.WITHDRAWING:
			_goal.text = "Withdraw the hero and both royal platoons"
			if objective.lower_quay == Quay.LowerQuay.CLOSED:
				_route.text = "Lower stair closed. Units still below can take the marked inland bypass."
			elif objective.lower_quay == Quay.LowerQuay.WARNED:
				_route.text = "The lower stair is cracking. Use the inland bypass if still below."
			else:
				_route.text = "Take the flagged stair or inland bypass. Hold the landing to cover the retreat."


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return PackedVector2Array([levy.position]) if levy else PackedVector2Array()
