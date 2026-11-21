extends "res://game/battlefield/command_harness.gd"

const Evacuation := preload("res://game/battlefield/sova_mine_tunnels.gd")
const ROUTE_NAMES := ["TunnelEntrance", "TunnelMidpoint", "TunnelExit", "EvacuationTrail", "MinerEvacuation"]
const EXIT_WAYPOINT := 2
const RELEASE_RADIUS := 1.9
const WORKER_SPEED := 2.55
const GROUP_TITLES := ["Mouth group", "Bend group"]
const GROUP_COLORS := [Color("#f3c681"), Color("#a0e8d1")]
const GUARD_TITLES := ["Tunnel Guard", "Outlet Screen"]

var objective := Evacuation.new()
var _route := PackedVector3Array()
var _next_waypoints: Array[int] = [1, 2]
var _groups: Array[Node3D] = []
var _stages: Array[Node3D] = []
var _party_signs: Array[Label3D] = []
var _witness: Node3D
var _witness_at_truce := false
var _interact_requested := false

@onready var _goal_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _instructions_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _restart_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	for index in range(ROUTE_NAMES.size()):
		var prefix := "Markers/Objectives/" if index == ROUTE_NAMES.size() - 1 else "Markers/Routes/"
		var marker := battlefield_marker(NodePath(prefix + ROUTE_NAMES[index]))
		_route.append(marker.global_position)
	for group in range(GROUP_TITLES.size()):
		_stages.append(_stage_marker(group))
		_groups.append(_worker_group(group))
	var safety := Node3D.new()
	add_child(safety)
	safety.global_position = _route[-1]
	_mesh(safety, _ring(1.8, 1.9), _material(Color("#92d9a6"), true), Vector3.UP * 0.045)
	_sign(safety, "Druid safety", Color("#b3e8c0"), 2.55)
	_witness = _worker(self, Color("#cb9def"))
	_sign(_witness, "Willing witness", Color("#e3c8ff"), 1.85)
	_restart_button.pressed.connect(restart_mission)
	_reset_workers()
	_refresh_view()


func _physics_process(delta: float) -> void:
	if objective.outcome != Evacuation.Outcome.ACTIVE:
		return
	super._physics_process(delta)
	var selected_stage := _interactable_stage()
	var frame := Evacuation.Observation.new()
	for group in range(_groups.size()):
		_advance_workers(group, delta)
		var report: Evacuation.GroupReport = frame.mouth if group == Evacuation.Group.MOUTH else frame.bend
		report.in_staging_cover = _groups[group].global_position.is_equal_approx(_route[group])
		report.release_ordered = _interact_requested and not command_view and group == selected_stage
		report.at_druid_safety = _groups[group].global_position.is_equal_approx(_waypoint(group, _route.size() - 1))
	_interact_requested = false
	frame.witness_waiting_under_truce = _witness_at_truce
	objective.advance(frame)
	_refresh_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_interact_requested = not command_view
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact_requested = true
			return
	if objective.outcome == Evacuation.Outcome.ACTIVE:
		super._unhandled_input(event)


func _build_placeholders() -> void:
	_name_guards()
	super._build_placeholders()


func restart_mission() -> void:
	objective.restart()
	_interact_requested = false
	_restart_button.release_focus()
	restart_battle()
	_name_guards()
	_sync_view()
	_reset_workers()
	_refresh_view()


func _name_guards() -> void:
	for index in range(GUARD_TITLES.size()):
		battle.formations[index].title = GUARD_TITLES[index]


func _reset_workers() -> void:
	for group in range(_groups.size()):
		_groups[group].global_position = _route[group]
		_groups[group].rotation = Vector3(0.0, PI, 0.0)
		_next_waypoints[group] = group + 1
	_witness_at_truce = false
	_place_witness()


func _advance_workers(group: int, delta: float) -> void:
	if objective.group_status(group) != Evacuation.GroupStatus.MOVING:
		return
	var party := _groups[group]
	var remaining := WORKER_SPEED * delta
	while remaining > 0.0 and _next_waypoints[group] < _route.size():
		var waypoint := _next_waypoints[group]
		var target := _waypoint(group, waypoint)
		var offset := target - party.global_position
		var distance := offset.length()
		if distance > 0.0:
			party.rotation.y = atan2(-offset.x, -offset.z)
		party.global_position = party.global_position.move_toward(target, remaining)
		remaining -= distance
		if party.global_position != target:
			break
		_next_waypoints[group] += 1
		if group == Evacuation.Group.BEND and waypoint == EXIT_WAYPOINT:
			_witness_at_truce = true
	if group == Evacuation.Group.BEND:
		_place_witness()


func _waypoint(group: int, index: int) -> Vector3:
	# Use two nearby holding spots inside the same evacuation zone.
	if index == _route.size() - 1:
		return _route[index] + Vector3(0.0, 0.0, -0.9 if group == Evacuation.Group.MOUTH else 0.9)
	return _route[index]


func _place_witness() -> void:
	# The witness walks with the bend group and waits just off the outlet route under truce.
	var bend := _groups[Evacuation.Group.BEND]
	_witness.global_position = _route[EXIT_WAYPOINT] + Vector3(0.8, 0.0, 0.35) if _witness_at_truce \
		else bend.global_position + Vector3(0.8, 0.0, 0.1)


func _interactable_stage() -> int:
	var nearest := RELEASE_RADIUS
	var selected := -1
	var feet := hero_world_position()
	for group in range(_stages.size()):
		if objective.group_status(group) != Evacuation.GroupStatus.STAGED:
			continue
		var distance := feet.distance_to(_route[group])
		if distance <= nearest:
			nearest = distance
			selected = group
	return selected


func _refresh_view() -> void:
	var states := PackedStringArray()
	for group in range(_groups.size()):
		var state := objective.group_status(group)
		_stages[group].visible = state in [Evacuation.GroupStatus.STAGING, Evacuation.GroupStatus.STAGED]
		_party_signs[group].visible = not _stages[group].visible
		states.append("%s: %s" % [GROUP_TITLES[group], ["Staging", "Ready", "Moving", "Paused", "Safe"][state]])
	_goal_label.text = "Evacuation complete" if objective.outcome == Evacuation.Outcome.SUCCEEDED else "  ·  ".join(states)
	if objective.outcome == Evacuation.Outcome.SUCCEEDED:
		_instructions_label.text = "Both groups are safe. The witness is waiting under truce."
	elif command_view:
		_instructions_label.text = "Release L2 / Shift to return to Sova and release a work group."
	else:
		var stage := _interactable_stage()
		_instructions_label.text = "Cross / Space: release the %s" % GROUP_TITLES[stage].to_lower() if stage >= 0 \
			else "Follow the stage markers into the tunnel. Release each group with Cross / Space."


func _stage_marker(group: int) -> Node3D:
	var stage := Node3D.new()
	add_child(stage)
	stage.global_position = _route[group]
	var glow := _material(GROUP_COLORS[group], true)
	_mesh(stage, _ring(RELEASE_RADIUS - 0.08, RELEASE_RADIUS), glow, Vector3.UP * 0.045)
	_mesh(stage, _box(Vector3(0.06, 1.7, 0.06)), glow, Vector3.UP * 0.90)
	_sign(stage, GROUP_TITLES[group] + " stage", GROUP_COLORS[group], 2.2)
	return stage


func _worker_group(group: int) -> Node3D:
	var party := Node3D.new()
	add_child(party)
	for offset in [Vector3.ZERO, Vector3(-0.53, 0.0, 0.65), Vector3(0.46, 0.0, 1.12)]:
		var member := _worker(party, GROUP_COLORS[group])
		member.position = offset
	_party_signs.append(_sign(party, GROUP_TITLES[group], GROUP_COLORS[group], 1.75))
	return party


func _worker(parent: Node3D, color: Color) -> Node3D:
	var worker := Node3D.new()
	parent.add_child(worker)
	var coat := _material(color)
	_mesh(worker, _box(Vector3(0.43, 0.81, 0.35)), coat, Vector3.UP * 0.74)
	for x in [-0.11, 0.11]:
		_mesh(worker, _box(Vector3(0.14, 0.42, 0.26)), coat, Vector3(x, 0.24, 0.0))
	_mesh(worker, _box(Vector3(0.28, 0.29, 0.26)), _material(Color("#dcaa84")), Vector3.UP * 1.27)
	return worker


func _sign(parent: Node3D, title: String, color: Color, height: float) -> Label3D:
	var sign := Label3D.new()
	sign.text = title
	sign.modulate = color
	sign.position.y = height
	sign.pixel_size = 0.019
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(sign)
	return sign
