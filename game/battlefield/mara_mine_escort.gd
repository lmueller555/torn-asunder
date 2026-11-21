extends "res://game/battlefield/command_harness.gd"

const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const PICKUP_RADIUS := 2.2
const EXIT_RADIUS := 2.7
const WARM_LIGHT := Color("#ffd382")
const EXIT_LIGHT := Color("#8de5d1")

var objective := Escort.new()
var _pickup: Marker3D
var _exit: Marker3D
var _pickup_beacon: Node3D
var _exit_beacon: Node3D
var _bridle: Node3D
var _interact_requested := false
var _hero_incapacitated := false
var _bridle_lost := false

@onready var _goal_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _instructions_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _restart_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_pickup = battlefield_marker(^"Markers/Objectives/GodbridlePickup")
	_exit = battlefield_marker(^"Markers/Objectives/GodbridleExit")
	_pickup_beacon = _beacon(_pickup, PICKUP_RADIUS, WARM_LIGHT, "GODBRIDLE")
	_exit_beacon = _beacon(_exit, EXIT_RADIUS, EXIT_LIGHT, "EAST ROAD EXIT")
	_bridle = _make_bridle()
	_restart_button.pressed.connect(restart_mission)
	_refresh_objective_view(hero_world_position())


func _physics_process(delta: float) -> void:
	if _finished():
		return
	if not _hero_incapacitated:
		super._physics_process(delta)
	var feet := hero_world_position()
	var observation := Escort.Observation.new()
	observation.interact_pressed = _interact_requested and not command_view
	observation.hero_in_pickup_zone = feet.distance_to(_pickup.global_position) <= PICKUP_RADIUS
	# In this prototype the hero is the sole carrier; units entering the exit never count.
	observation.carrier_in_road_exit = objective.phase == Escort.Phase.ESCORTING \
		and not _hero_incapacitated and feet.distance_to(_exit.global_position) <= EXIT_RADIUS
	observation.hero_incapacitated = _hero_incapacitated
	observation.bridle_lost = _bridle_lost
	_interact_requested = false
	objective.advance(observation)
	_refresh_objective_view(feet)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_interact_requested = not _finished() and not command_view
			return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START and _uses_joypad(event.device):
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view and _uses_joypad(event.device):
			_interact_requested = not _finished()
			return
	if not _finished():
		super._unhandled_input(event)


## Called by future combat when the hero is no longer able to carry the Godbridle.
func report_hero_incapacitated() -> void:
	_hero_incapacitated = true


## Called by future encounter rules if the bridle is definitively lost.
func report_bridle_lost() -> void:
	_bridle_lost = true


func restart_mission() -> void:
	objective.restart()
	_hero_incapacitated = false
	_bridle_lost = false
	_interact_requested = false
	_restart_button.release_focus()
	restart_battle()
	_refresh_objective_view(hero_world_position())


func _finished() -> bool:
	return objective.phase in [Escort.Phase.SUCCEEDED, Escort.Phase.FAILED]


func _refresh_objective_view(feet: Vector3) -> void:
	var awaiting := objective.phase == Escort.Phase.AWAITING_PICKUP
	var carrying := objective.phase == Escort.Phase.ESCORTING
	_pickup_beacon.visible = awaiting
	_exit_beacon.visible = carrying
	_bridle.visible = awaiting or carrying
	if awaiting:
		_bridle.global_position = _pickup.global_position + Vector3.UP * 0.75
		_bridle.rotation.y = PI / 2.0
	else:
		_bridle.global_position = _hero.to_global(Vector3(0.46, 0.89, 0.06))
		_bridle.rotation.y = _hero.rotation.y
	match objective.phase:
		Escort.Phase.AWAITING_PICKUP:
			var distance := feet.distance_to(_pickup.global_position)
			_goal_label.text = "Recover the Godbridle  ·  %d m" % ceili(distance)
			if distance > PICKUP_RADIUS:
				_instructions_label.text = "Follow the gold marker. Use Cross or Space when close."
			elif command_view:
				_instructions_label.text = "Release L2 or Shift to return to your hero and pick it up."
			else:
				_instructions_label.text = "Press Cross or Space to pick up the Godbridle."
		Escort.Phase.ESCORTING:
			_goal_label.text = "Escort the Godbridle to the east road exit  ·  %d m" % ceili(feet.distance_to(_exit.global_position))
			_instructions_label.text = "You are carrying the Godbridle. Follow the road to the east."
		Escort.Phase.SUCCEEDED:
			_goal_label.text = "Escort complete"
			_instructions_label.text = "The hero delivered the Godbridle. Restart to replay the route."
		Escort.Phase.FAILED:
			_goal_label.text = "Escort failed"
			var reason := "The Godbridle was lost." if objective.failure == Escort.Failure.BRIDLE_LOST else "The hero was incapacitated."
			_instructions_label.text = "%s Restart to try again." % reason


func _beacon(marker: Marker3D, radius: float, color: Color, title: String) -> Node3D:
	var beacon := Node3D.new()
	add_child(beacon)
	beacon.global_position = marker.global_position
	var material := _material(color, true)
	_mesh(beacon, _ring(radius - 0.11, radius), material, Vector3.UP * 0.055)
	_mesh(beacon, _box(Vector3(0.09, 2.6, 0.09)), material, Vector3.UP * 1.34)
	var label := Label3D.new()
	label.text = title
	label.modulate = color
	label.font_size = 42
	label.outline_size = 12
	label.pixel_size = 0.024
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 3.0
	beacon.add_child(label)
	return beacon


func _make_bridle() -> Node3D:
	var prop := Node3D.new()
	add_child(prop)
	var leather := _material(Color("#a05d37"))
	var brass := _material(WARM_LIGHT, true)
	var loop := _mesh(prop, _ring(0.15, 0.19), leather, Vector3(0.0, 0.10, 0.0))
	loop.rotation.x = PI / 2.0
	loop.scale.y = 1.22
	_mesh(prop, _box(Vector3(0.44, 0.06, 0.06)), brass)
	for x in [-0.21, 0.21]:
		var buckle := _mesh(prop, _ring(0.044, 0.07), brass, Vector3(x, 0.0, 0.0))
		buckle.rotation.x = PI / 2.0
	return prop
