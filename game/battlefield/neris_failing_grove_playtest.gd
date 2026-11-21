extends "res://game/battlefield/command_harness.gd"
## Standalone work and escort playtest. The track patrol interdicts, not attacks.

signal mission_finished(won: bool)

const Grove := preload("res://game/battlefield/neris_failing_grove.gd")
const REACH := 2.8
const HIDE_WORK_LABELS_WITHIN := 7.5
const SHOW_WORK_LABELS_BEYOND := 13.0
const SLED_SPEED := 6.5
const WORKER_SPEED := 3.1
const PATROL_SPEED := 5.5
const LOAD_SECONDS := 7.0
const SCREEN_RADIUS := 4.0
const SLED_ROUTE := [
	"Routes/LoadingYard", "Routes/YardExit", "Routes/RaisedRoadWest", "Routes/RoadScreenHold",
	"Routes/RaisedRoadMiddle", "Routes/RaisedRoadEast", "Routes/NurseryApproach", "Objectives/TransplantBed",
]
const CREW_ROUTE := ["Objectives/VolunteerCall", "Objectives/RootBallLoad"]
const PATROL_ROUTE := ["Routes/LoadingScreenTop", "Routes/LoadingScreenHold", "Routes/LoadingYard"]
const ALLY_COLOR := Color("#9bdec0")
const ALERT_COLOR := Color("#f9ab82")

var objective := Grove.new()
var _interaction_requested := false
var _neris_fell := false
var _sled_destroyed := false
var _sled: Node3D
var _tree: Node3D
var _cloth: MeshInstance3D
var _crew: Node3D
var _patrol: Node3D
var _sled_path := PackedVector2Array()
var _crew_path := PackedVector2Array()
var _patrol_path := PackedVector2Array()
var _sled_next := 0
var _crew_next := 0
var _patrol_next := 1
var _patrol_screened := false
var _sled_at_load := false
var _envoy: Marker3D
var _call: Marker3D
var _load_pad: Marker3D
var _bed: Marker3D
var _yard_zone: Marker3D
var _nursery_zone: Marker3D
var _screen_beacon: Node3D
var _envoy_beacon: Node3D
var _call_beacon: Node3D
var _bed_beacon: Node3D
var _sled_banner: Label3D
var _crew_banner: Label3D
var _work_label_opacity := -1.0
var _work_label_outline: Color

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _status: Label = $ObjectiveHUD/Panel/Margin/Readout/Status
@onready var _cue: Label = $ObjectiveHUD/Panel/Margin/Readout/Cue
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_envoy = _mark("Objectives/GroveEnvoy")
	_call = _mark("Objectives/VolunteerCall")
	_load_pad = _mark("Objectives/RootBallLoad")
	_bed = _mark("Objectives/TransplantBed")
	_yard_zone = _mark("PhaseZones/LoadingZone")
	_nursery_zone = _mark("PhaseZones/NurseryReceiver")
	_sled_path = _marked_path(SLED_ROUTE)
	_crew_path = _marked_path(CREW_ROUTE)
	_patrol_path = _marked_path(PATROL_ROUTE)
	_make_actors()
	_envoy_beacon = _beacon(_envoy, "GROVE ENVOY", ALLY_COLOR)
	_call_beacon = _beacon(_call, "CALL VOLUNTEERS", ALLY_COLOR)
	_bed_beacon = _beacon(_bed, "NURSERY · TRANSPLANT BED", ALLY_COLOR)
	_screen_beacon = _beacon(_mark("Routes/LoadingScreenHold"), "HOLD HERE · TRACK SCREEN", ALERT_COLOR)
	_restart.pressed.connect(restart_mission)
	_reset_actors()
	_refresh_objective()


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _name_formations() -> void:
	battle.formations[0].title = "Loading Guard"
	battle.formations[1].title = "Track Screen"


func _physics_process(delta: float) -> void:
	if not _finished():
		super._physics_process(delta)


func _update_mode() -> void:
	super._update_mode()
	_refresh_work_labels()


func _after_battle_step(delta: float) -> void:
	var frame := Grove.Observation.new()
	var interacts := _interaction_requested and not command_view
	_interaction_requested = false
	frame.envoy_interaction_confirmed = interacts and _hero_near(_envoy)
	frame.volunteers_called = interacts and _hero_near(_call)
	frame.transplant_interaction_confirmed = interacts and _hero_near(_bed)
	frame.neris_fell = _neris_fell
	frame.sled_definitively_destroyed = _sled_destroyed
	if not _neris_fell and not _sled_destroyed:
		if objective.phase in [Grove.Phase.LOADING, Grove.Phase.ESCORTING]:
			_step_patrol(delta)
		frame.yard_contested = _patrol.visible and _in_zone(_patrol, _yard_zone)
		if objective.phase == Grove.Phase.LOADING and not frame.yard_contested:
			_step_loading(delta, frame)
		if objective.phase == Grove.Phase.ESCORTING:
			frame.sled_route_contested = _patrol.visible and _patrol.position.distance_to(_sled.position) < 5.5
			if not frame.sled_route_contested and _sled_next < _sled_path.size():
				var arrived := _step_actor(_sled, _sled_path[_sled_next], SLED_SPEED, delta, true)
				if arrived:
					_sled_next += 1
			if _sled_next > 0:
				_crew.position = _sled.position + _sled.basis * Vector3(-2.6, 0.0, 1.2)
		frame.sled_at_nursery = _sled_next == _sled_path.size() and _in_zone(_sled, _nursery_zone)
		frame.nursery_contested = _patrol.visible and _in_zone(_patrol, _nursery_zone)
	objective.advance(frame)
	_refresh_objective()
	if _finished():
		mission_finished.emit(objective.phase == Grove.Phase.SUCCEEDED)


func _step_loading(delta: float, frame: Grove.Observation) -> void:
	_sled_at_load = _step_actor(_sled, _marker_position(_load_pad), SLED_SPEED, delta, true)
	if _crew_next < _crew_path.size() and _step_actor(_crew, _crew_path[_crew_next], WORKER_SPEED, delta):
		_crew_next += 1
	if _sled_at_load and _crew_next == _crew_path.size() and _in_zone(_sled, _yard_zone) and _in_zone(_crew, _yard_zone):
		frame.loading_credit = delta / LOAD_SECONDS


func _step_patrol(delta: float) -> void:
	_patrol.visible = true
	_patrol_screened = false
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD and formation.position.distance_to(_patrol_path[1]) <= SCREEN_RADIUS:
			_patrol_screened = true
			break
	# A screened patrol physically falls back along the same stones. It stops
	# contesting the yard only when it has actually cleared that zone.
	if _patrol_screened:
		var previous := maxi(_patrol_next - 1, 0)
		if _step_actor(_patrol, _patrol_path[previous], PATROL_SPEED, delta):
			_patrol_next = maxi(_patrol_next - 1, 1)
	elif _patrol_next < _patrol_path.size():
		if _step_actor(_patrol, _patrol_path[_patrol_next], PATROL_SPEED, delta):
			_patrol_next += 1


func _step_actor(actor: Node3D, target: Vector2, speed: float, delta: float, sled := false) -> bool:
	var from := Vector2(actor.position.x, actor.position.z)
	var direction := (target - from).normalized()
	var remaining := maxf(delta, 0.0) * speed
	while from != target and remaining > 0.0:
		var step := minf(0.22, remaining)
		var next := from.move_toward(target, step)
		if not _terrain.can_move(from, next, sled) or (sled and not _sled_has_support(next, direction)):
			return false
		actor.position = _ground(next)
		actor.rotation.y = atan2(-direction.x, -direction.y)
		remaining -= step
		from = next
	return from == target


func _sled_has_support(at: Vector2, heading: Vector2) -> bool:
	# The complete hull clearance is checked along this fixed route by the
	# map test. Also check the axle support during the scene's actual movement.
	var floor := _terrain.ground_height(at)
	var lateral := Vector2(-heading.y, heading.x)
	for axle in [-2.85, 2.85]:
		for wheel in [-2.0, 2.0]:
			if absf(_terrain.ground_height(at + heading * axle + lateral * wheel) - floor) > 0.52:
				return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_interaction_requested = not command_view
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interaction_requested = true
			return
	if not _finished():
		super._unhandled_input(event)


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_formations()
	_reset_actors()
	_refresh_objective()
	_sync_view()


## Future combat can report genuine defeat; the patrol itself deals no damage.
func report_neris_fell() -> void:
	_neris_fell = true


func report_sled_destroyed() -> void:
	_sled_destroyed = true


func _reset_actors() -> void:
	_interaction_requested = false
	_neris_fell = false
	_sled_destroyed = false
	_sled_next = 0
	_crew_next = 0
	_patrol_next = 1
	_patrol_screened = false
	_sled_at_load = false
	_sled.global_transform = _mark("Spawns/RootSled").global_transform
	_crew.global_transform = _mark("Spawns/VolunteerCrew").global_transform
	_patrol.global_position = _mark(PATROL_ROUTE[0]).global_position
	_patrol.rotation.y = 0.0
	_patrol.hide()


func _refresh_objective() -> void:
	var phase := objective.phase
	_envoy_beacon.visible = phase == Grove.Phase.AWAITING_ENVOY
	_call_beacon.visible = phase == Grove.Phase.AWAITING_VOLUNTEERS
	_bed_beacon.visible = phase in [Grove.Phase.ESCORTING, Grove.Phase.AWAITING_TRANSPLANT]
	_screen_beacon.visible = _patrol.visible and not _finished()
	_sled.visible = not _sled_destroyed
	_crew.visible = phase in [Grove.Phase.LOADING, Grove.Phase.ESCORTING, Grove.Phase.AWAITING_TRANSPLANT]
	_cloth.visible = objective.loading_progress < 1.0
	var pad := to_local(_load_pad.global_position)
	_tree.position = pad.lerp(_sled.position + Vector3.UP * 0.58, objective.loading_progress)
	if phase == Grove.Phase.SUCCEEDED:
		var planted := _marker_position(_bed) + Vector2(3.0, -1.0)
		_tree.position = _ground(planted) - Vector3.UP * 0.30
	_tree.visible = not _sled_destroyed
	if phase == Grove.Phase.SUCCEEDED:
		_sled_banner.text = "EMPTY ROOT SLED"
	else:
		_sled_banner.text = "ROOT SLED" if objective.loading_progress < 1.0 else "LOADED ROOT SLED"
	_refresh_work_labels()

	_cue.text = ""
	match phase:
		Grove.Phase.AWAITING_ENVOY:
			_goal.text = "Speak to the grove envoy"
			_status.text = "The grove has refused the crossing. The town offers a nursery for the first tree."
			_cue.text = _prompt(_envoy, "hear the envoy")
		Grove.Phase.AWAITING_VOLUNTEERS:
			_goal.text = "Call the volunteers from shelter"
			_status.text = "Escort one tree by the raised road. The town well is untouched."
			_cue.text = _prompt(_call, "call the volunteers")
		Grove.Phase.LOADING:
			_goal.text = "Load the first tree  ·  %d%%" % floori(objective.loading_progress * 100.0)
			_status.text = "The crew and sled must reach the marked loading pad."
			if objective.interruption == Grove.Interruption.YARD_CONTESTED:
				_status.text = "Foragers in the yard. The volunteers stop work; loaded progress is safe."
		Grove.Phase.ESCORTING:
			_goal.text = "Escort the root sled along the raised road"
			_status.text = "Nursery  ·  %d m from sled" % ceili(_sled.global_position.distance_to(_bed.global_position))
			if objective.interruption == Grove.Interruption.SLED_ROUTE_CONTESTED:
				_status.text = "The sled is waiting under the screen while the foragers obstruct its road."
		Grove.Phase.AWAITING_TRANSPLANT:
			_goal.text = "Settle the tree in the nursery"
			_status.text = "The root sled has reached the receiving bed."
			_cue.text = _prompt(_bed, "transplant the tree")
		Grove.Phase.SUCCEEDED:
			_goal.text = "The first tree is planted"
			_status.text = "The rest of the grove stays where it is. The volunteers will return."
		Grove.Phase.FAILED:
			_goal.text = "The transplant failed"
			_status.text = "Neris fell." if objective.failure == Grove.Failure.NERIS_FELL else "The root sled was destroyed."
	if phase in [Grove.Phase.LOADING, Grove.Phase.ESCORTING]:
		if _patrol_screened:
			_cue.text = "Track screened. Foragers fall back."
		elif objective.interruption in [Grove.Interruption.YARD_CONTESTED, Grove.Interruption.SLED_ROUTE_CONTESTED]:
			_cue.text = "Hold a formation at the marked track screen to reopen the route."
		else:
			_cue.text = "Foragers are approaching from the low track. Hold a formation at the marked screen."


## The HUD and local markers remain in place. Only the two close work labels
## fade away together in hero view; tactical and distant identification stay.
func _refresh_work_labels() -> void:
	if not _sled_banner or not _crew_banner:
		return
	var opacity := 1.0
	if not command_view:
		var hero := hero_world_position()
		var distance := hero.distance_to(_sled.global_position)
		if _crew.visible:
			distance = minf(distance, hero.distance_to(_crew.global_position))
		opacity = smoothstep(HIDE_WORK_LABELS_WITHIN, SHOW_WORK_LABELS_BEYOND, distance)
	if opacity == _work_label_opacity:
		return
	_work_label_opacity = opacity
	for label: Label3D in [_sled_banner, _crew_banner]:
		label.visible = opacity > 0.0
		label.modulate = Color(ALLY_COLOR, ALLY_COLOR.a * opacity)
		label.outline_modulate = Color(_work_label_outline, _work_label_outline.a * opacity)


func _prompt(marker: Marker3D, action: String) -> String:
	if command_view:
		return "Release L2 / Shift to return to Neris and interact."
	if _hero_near(marker):
		return "Cross / Space: " + action
	return "Follow the marker  ·  %d m" % ceili(hero_world_position().distance_to(marker.global_position))


func _hero_near(marker: Marker3D) -> bool:
	return hero_world_position().distance_to(marker.global_position) <= REACH


func _in_zone(actor: Node3D, zone: Marker3D) -> bool:
	var half: Vector3 = zone.get_meta("box_size") * 0.5
	var local := zone.to_local(actor.global_position + Vector3.UP * 0.65)
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


func _finished() -> bool:
	return objective.phase in [Grove.Phase.SUCCEEDED, Grove.Phase.FAILED]


func _mark(path: String) -> Marker3D:
	return battlefield_marker(NodePath("Markers/" + path))


func _marked_path(names: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for path: String in names:
		result.append(_marker_position(_mark(path)))
	return result


func _make_actors() -> void:
	var envoy := _people("Grove envoy", ALLY_COLOR, 1)
	envoy.global_position = _envoy.global_position
	_crew = _people("", ALLY_COLOR, 3)
	_crew_banner = _sign(_crew, "Volunteer crew", ALLY_COLOR, 2.15)
	_work_label_outline = _crew_banner.outline_modulate
	_patrol = _people("Track foragers", ALERT_COLOR, 3)
	_sled = Node3D.new()
	_sled.name = "RootSledActor"
	add_child(_sled)
	var wood := _material(Color("#684930"))
	_mesh(_sled, _box(Vector3(4.55, 0.32, 7.3)), wood, Vector3.UP * 0.43)
	for side in [-1.64, 1.64]:
		_mesh(_sled, _box(Vector3(0.49, 0.38, 7.5)), wood, Vector3(side, 0.19, 0.0))
	_sled_banner = _sign(_sled, "ROOT SLED", ALLY_COLOR, 2.7)

	_tree = Node3D.new()
	_tree.name = "TransplantTree"
	add_child(_tree)
	_mesh(_tree, _box(Vector3(0.44, 3.25, 0.44)), wood, Vector3.UP * 1.68)
	var roots := SphereMesh.new()
	roots.radius = 1.25
	roots.height = 1.15
	_mesh(_tree, roots, _material(Color("#524031")), Vector3.UP * 0.55)
	_cloth = _mesh(_tree, _box(Vector3(2.4, 0.18, 2.25)), _material(Color("#ae9c74")), Vector3.UP * 1.10)
	var canopy := SphereMesh.new()
	canopy.radius = 1.5
	canopy.height = 2.0
	_mesh(_tree, canopy, _material(Color("#719769")), Vector3.UP * 3.2)


func _people(title: String, color: Color, count: int) -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	var clothes := _material(color)
	var cap := _material(color.lightened(0.35))
	for person in range(count):
		var offset := (person - (count - 1) * 0.5) * 0.86
		_mesh(actor, _box(Vector3(0.54, 1.15, 0.47)), clothes, Vector3(offset, 0.60, 0.0))
		_mesh(actor, _box(Vector3(0.36, 0.35, 0.35)), cap, Vector3(offset, 1.32, 0.0))
	if not title.is_empty():
		_sign(actor, title, color, 2.15)
	return actor


func _beacon(point: Marker3D, title: String, color: Color) -> Node3D:
	var marker := Node3D.new()
	add_child(marker)
	marker.global_position = point.global_position
	_mesh(marker, _ring(1.5, 1.64), _material(color, true), Vector3.UP * 0.065)
	_sign(marker, title, color, 3.0)
	return marker


func _sign(parent: Node3D, title: String, color: Color, height: float) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.modulate = color
	label.outline_size = 10
	label.pixel_size = 0.027
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position.y = height
	return label


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions([_patrol])
