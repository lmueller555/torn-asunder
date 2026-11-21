extends "res://game/battlefield/command_harness.gd"

const Witness := preload("res://game/battlefield/orc_mine_witness.gd")
const CREW_SPEED := 3.1
const DETACHMENT_SPEED := 1.55
const INTERACTION_RADIUS := 2.15
const SCREEN_RADIUS := 3.0
const RALLY_RADIUS := 2.4
const TRAIL_STEP := 0.40
const TITLES := ["Pass Screen", "Outlet Party"]
const OUTLET := ^"Markers/Routes/TunnelExit"
const BEND := ^"Markers/Routes/TunnelMidpoint"
const TRAIL := ^"Markers/Routes/EvacuationTrail"
const SAFETY := ^"Markers/Objectives/MinerEvacuation"
const RALLY := ^"Markers/Routes/OrcApproach"

var objective := Witness.new()
var _outlet: Vector3
var _rally: Vector3
var _screen_start: Vector3
var _screen_end: Vector3
var _crew_route := PackedVector3Array()
var _crew_waypoint := 1
var _witness: Node3D
var _crew: Node3D
var _detachment: Node3D
var _rally_beacon: Node3D
var _screen_beacon: Node3D
var _outlet_beacon: Node3D
var _window_started := false
var _screen_held := false
var _interact_requested := false
var _trail := PackedVector3Array()

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _hint: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_outlet = _marker(OUTLET)
	_rally = _marker(RALLY)
	_crew_route = PackedVector3Array([_marker(BEND), _outlet, _marker(TRAIL), _marker(SAFETY)])
	# The detachment advances on the exposed flank beside the workers' route, not through the tunnel.
	_screen_start = _marker(SAFETY) + Vector3(0.0, 0.0, 2.2)
	_screen_end = _outlet + Vector3(-3.2, 0.0, 1.8)
	_outlet_beacon = _beacon(_outlet, "TUNNEL OUTLET", Color("#afdcc6"))
	_screen_beacon = _beacon(_screen_end, "SCREEN THE APPROACH", Color("#ffc681"))
	_rally_beacon = _beacon(_rally, "ORC RALLY", Color("#9ee5a0"))
	_crew = _party("Workers headed to Druid safety", Color("#addcc6"), 3)
	_witness = _party("Willing witness", Color("#dec2f0"), 1)
	_detachment = _party("Human rear detachment", Color("#f78364"), 3)
	_restart.pressed.connect(restart_mission)
	_reset_route()
	_refresh_objective()


func _physics_process(delta: float) -> void:
	if _finished():
		return
	super._physics_process(delta)
	var raska := hero_world_position()
	if not _window_started and raska.distance_to(_outlet) <= 10.0:
		_window_started = true
	var previous_position := _detachment.global_position
	if _window_started and not _screen_held:
		_advance_detachment(raska, delta)
	var blocked := _window_started and not _screen_held and _detachment.global_position.distance_to(_screen_end) <= 1.5
	if _window_started and not blocked:
		_advance_crew(delta)

	var observation := Witness.Observation.new()
	observation.outlet_blocked = blocked
	observation.last_escape_window_closes = blocked and previous_position != _screen_end and _detachment.global_position == _screen_end
	observation.other_workers_clear = _crew_waypoint == _crew_route.size()
	observation.witness_offers_terms = observation.other_workers_clear and _witness.global_position.distance_to(_outlet) < 1.0
	observation.raska_accepts_terms = _interact_requested and not command_view and raska.distance_to(_witness.global_position) <= INTERACTION_RADIUS
	if objective.phase == Witness.Phase.ESCORTING:
		_follow_raska(raska, delta)
	observation.witness_at_orc_rally = _witness.global_position.distance_to(_rally) <= RALLY_RADIUS
	_interact_requested = false
	objective.advance(observation)
	_refresh_objective()


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
	if not _finished():
		super._unhandled_input(event)


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	_name_formations()
	_sync_view()
	_reset_route()
	_refresh_objective()


func _name_formations() -> void:
	for index in range(TITLES.size()):
		battle.formations[index].title = TITLES[index]


func _reset_route() -> void:
	_window_started = false
	_screen_held = false
	_interact_requested = false
	_crew_waypoint = 1
	_trail.clear()
	_crew.global_position = _crew_route[0]
	_witness.global_position = _crew_route[0] + Vector3.RIGHT * 0.7
	_detachment.global_position = _screen_start


func _advance_detachment(raska: Vector3, delta: float) -> void:
	var threat := _detachment.global_position
	if raska.distance_to(threat) <= SCREEN_RADIUS:
		_screen_held = true
		return
	for formation in battle.formations:
		if to_global(_ground(formation.position)).distance_to(threat) <= SCREEN_RADIUS:
			_screen_held = true
			return
	_detachment.global_position = threat.move_toward(_screen_end, DETACHMENT_SPEED * delta)


func _advance_crew(delta: float) -> void:
	if _crew_waypoint == _crew_route.size():
		return
	var target := _crew_route[_crew_waypoint]
	_crew.global_position = _crew.global_position.move_toward(target, CREW_SPEED * delta)
	if _crew_waypoint == 1:
		_witness.global_position = _crew.global_position + Vector3.RIGHT * 0.7
	if _crew.global_position == target:
		_crew_waypoint += 1


func _follow_raska(raska: Vector3, delta: float) -> void:
	# Follow the hero's already traversed ground route around cover and through the ramps.
	if _trail.is_empty() or raska.distance_to(_trail[-1]) >= TRAIL_STEP:
		_trail.append(raska)
	var remaining := (Battle.HERO_SPEED + 0.45) * delta
	while _trail.size() > 3 and remaining > 0.0:
		var next := _trail[0]
		var distance := _witness.global_position.distance_to(next)
		_witness.global_position = _witness.global_position.move_toward(next, remaining)
		remaining -= distance
		if _witness.global_position != next:
			break
		_trail.remove_at(0)


func _finished() -> bool:
	return objective.phase in [Witness.Phase.SUCCEEDED, Witness.Phase.FAILED]


func _refresh_objective() -> void:
	_outlet_beacon.visible = objective.phase < Witness.Phase.ESCORTING
	_screen_beacon.visible = _window_started and not _screen_held and not _finished()
	_detachment.visible = _window_started and not _screen_held
	_rally_beacon.visible = objective.phase == Witness.Phase.ESCORTING or objective.phase == Witness.Phase.SUCCEEDED
	match objective.phase:
		Witness.Phase.WAITING_FOR_OFFER:
			if not _window_started:
				_goal.text = "Reach the tunnel outlet"
				_hint.text = "Cross the ridge and head south through the mine tunnel. Protect the withdrawing workers."
			elif not _screen_held:
				_goal.text = "Stop the approaching detachment"
				_hint.text = "Reach the red detachment with Raska or one of his formations before it seals the outlet."
			else:
				_goal.text = "Outlet screened   ·   Workers withdrawing"
				_hint.text = "Wait at the tunnel outlet while the remaining workers reach Druid safety."
		Witness.Phase.TERMS_OFFERED:
			_goal.text = "The witness offers her terms"
			_hint.text = "She will testify if the others go free. Approach her and press Cross / Space to accept."
		Witness.Phase.WAITING_FOR_WORKERS:
			_goal.text = "Honor the witness’s terms"
			_hint.text = "The witness will follow once the other workers are safe."
		Witness.Phase.ESCORTING:
			_goal.text = "Escort the witness to the Orc rally   ·   %d m" % ceili(_witness.global_position.distance_to(_rally))
			_hint.text = "Walk the route back to the eastern rally. The witness follows the path you take."
		Witness.Phase.SUCCEEDED:
			_goal.text = "Witness safe at the Orc rally"
			_hint.text = "She will speak at the assembly. The other workers escaped with the Druids."
		Witness.Phase.FAILED:
			_goal.text = "The detachment sealed the outlet"
			_hint.text = "Restart and intercept its visible advance before it reaches the marked approach."


func _marker(path: NodePath) -> Vector3:
	return battlefield_marker(path).global_position


func _beacon(point: Vector3, title: String, color: Color) -> Node3D:
	var beacon := Node3D.new()
	add_child(beacon)
	beacon.global_position = point
	_mesh(beacon, _ring(1.15, 1.24), _material(color, true), Vector3.UP * 0.05)
	_mesh(beacon, _box(Vector3(0.07, 1.8, 0.07)), _material(color, true), Vector3.UP * 0.9)
	_sign(beacon, title, color, 2.5, true)
	return beacon


func _party(title: String, color: Color, count: int) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	var uniform := _material(color)
	var skin := _material(Color("#d7aa86"))
	for index in range(count):
		var offset := Vector3((index - (count - 1) / 2.0) * 0.58, 0.0, (index % 2) * 0.48)
		_mesh(group, _box(Vector3(0.42, 0.93, 0.40)), uniform, offset + Vector3.UP * 0.55)
		_mesh(group, _box(Vector3(0.28, 0.30, 0.27)), skin, offset + Vector3.UP * 1.18)
	_sign(group, title, color, 1.8)
	return group


func _sign(parent: Node3D, title: String, color: Color, height: float, marker := false) -> void:
	var sign := Label3D.new()
	sign.text = title
	sign.modulate = color
	sign.position.y = height
	sign.pixel_size = 0.020
	sign.outline_size = 10
	sign.no_depth_test = marker
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(sign)
