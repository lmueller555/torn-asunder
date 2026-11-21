extends "res://game/battlefield/command_harness.gd"

const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const PICKUP_RADIUS := 2.2
const EXIT_RADIUS := 2.7
const WARM_LIGHT := Color("#ffd382")
const EXIT_LIGHT := Color("#8de5d1")

@export var opposition_enabled := true
@export var road_guard_spawn: NodePath = ^"Markers/Spawns/MaraRoadGuard"

var objective := Escort.new()
var encounter: Encounter
var _pickup: Marker3D
var _exit: Marker3D
var _pickup_beacon: Node3D
var _exit_beacon: Node3D
var _bridle: Node3D
var _interact_requested := false
var _hero_incapacitated := false
var _bridle_lost := false
var _guard_key := false
var _guard_pad := false
var _enemy_visual: Node3D
var _enemy_weapon: MeshInstance3D
var _enemy_warning: MeshInstance3D
var _enemy_target_ring: MeshInstance3D
var _enemy_status: Label3D
var _hero_weapon: MeshInstance3D
var _hero_guard: MeshInstance3D

@onready var _goal_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _instructions_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _combat_panel: PanelContainer = $CombatHUD/Panel
@onready var _combat_hp: Label = $CombatHUD/Panel/Margin/Readout/Health
@onready var _combat_tell: Label = $CombatHUD/Panel/Margin/Readout/Tell
@onready var _restart_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_pickup = battlefield_marker(^"Markers/Objectives/GodbridlePickup")
	_exit = battlefield_marker(^"Markers/Objectives/GodbridleExit")
	_pickup_beacon = _beacon(_pickup, PICKUP_RADIUS, WARM_LIGHT, "GODBRIDLE")
	_exit_beacon = _beacon(_exit, EXIT_RADIUS, EXIT_LIGHT, "EAST ROAD EXIT")
	_bridle = _make_bridle()
	_restart_button.pressed.connect(restart_mission)
	_build_combat_visuals()
	_reset_encounter()
	_refresh_objective_view(hero_world_position())


func _physics_process(delta: float) -> void:
	if _finished():
		return
	if not _hero_incapacitated:
		if encounter:
			encounter.defense.set_guard(not command_view and (_guard_key or _guard_pad), true)
			var dodge := encounter.defense.advance_defense(delta, true)
			battle.move_hero(dodge, _movement_check())
		super._physics_process(delta)
		if encounter:
			_refresh_combat_view()
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


func _after_battle_step(delta: float) -> void:
	if encounter:
		encounter.advance(delta, battle, _terrain.clear_melee_contact, _terrain.can_move)
		if not encounter.hero.is_alive():
			report_hero_incapacitated()


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
		if encounter and _handle_combat_input(event):
			return
		super._unhandled_input(event)


func _hero_move_factor() -> float:
	if not encounter:
		return 1.0
	match encounter.defense.phase:
		Defense.Phase.FREE:
			return 1.0 if encounter.defense.attack_phase == Attack.Phase.IDLE else 0.50
		Defense.Phase.GUARD:
			return 0.45
		_:
			return 0.0


func _movement_check() -> Callable:
	return _body_can_move if encounter and encounter.enemy.is_alive() else super._movement_check()


func _body_can_move(from: Vector2, to: Vector2, is_formation: bool) -> bool:
	if not is_formation:
		var toward := to.distance_to(encounter.enemy_position)
		if toward < Encounter.BODY_CLEARANCE and toward < from.distance_to(encounter.enemy_position):
			return false
	return _terrain.can_move(from, to, is_formation)


func _handle_combat_input(event: InputEvent) -> bool:
	var key := 0
	if event is InputEventKey and not event.echo:
		key = event.physical_keycode
		if key == KEY_U:
			_guard_key = event.pressed
			return true
		if not event.pressed:
			return false
	elif event is InputEventJoypadButton and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_guard_pad = event.pressed
			return true
		if not event.pressed:
			return false
		match event.button_index:
			JOY_BUTTON_X: key = KEY_J
			JOY_BUTTON_Y: key = KEY_K
			JOY_BUTTON_B: key = KEY_L
	if command_view:
		if key != KEY_K:
			return false
		if encounter.order_infantry_attack(battle, selected_index, cursor):
			_sync_view()
		return true
	if _hero_incapacitated:
		return false
	var guard := _guard_key or _guard_pad
	encounter.defense.set_guard(guard, true)
	match key:
		KEY_J: encounter.defense.start_attack(Attack.Attack.LIGHT, true)
		KEY_K: encounter.defense.start_attack(Attack.Attack.HEAVY, true)
		KEY_L:
			var direction := _movement_input().rotated(-_hero_yaw)
			encounter.defense.start_dodge(battle.hero_heading if direction.is_zero_approx() else direction, true)
		_: return false
	return true


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		_guard_key = false
		_guard_pad = false
		_interact_requested = false


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if device == _input_device and not connected:
		_guard_pad = false
	super._on_joy_connection_changed(device, connected)


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
	_reset_encounter()
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


func _reset_encounter() -> void:
	_guard_key = false
	_guard_pad = false
	var guard_marker := battlefield_marker(road_guard_spawn)
	if not guard_marker:
		guard_marker = battlefield_marker(^"Markers/Routes/EastPass")
	encounter = Encounter.new(_marker_position(guard_marker)) if opposition_enabled and guard_marker else null
	_refresh_combat_view()


func _build_combat_visuals() -> void:
	_enemy_visual = Node3D.new()
	add_child(_enemy_visual)
	var rust := _material(Color("#b45e4c"))
	var iron := _material(Color("#c4b2a5"))
	_mesh(_enemy_visual, _box(Vector3(0.83, 1.26, 0.58)), rust, Vector3(0, 0.81, 0))
	_mesh(_enemy_visual, _box(Vector3(0.58, 0.44, 0.50)), rust, Vector3(0, 1.58, 0))
	_enemy_weapon = _mesh(_enemy_visual, _box(Vector3(0.15, 1.02, 0.16)), iron, Vector3(-0.60, 0.92, -0.24))
	_enemy_warning = _mesh(_enemy_visual, _ring(1.73, 1.89), _material(Color("#ff8a6d"), true), Vector3.UP * 0.08)
	_enemy_target_ring = _mesh(_enemy_visual, _ring(0.88, 1.03), _material(Color("#ffd07d"), true), Vector3.UP * 0.11)
	_enemy_status = Label3D.new()
	_enemy_status.position.y = 2.45
	_enemy_status.pixel_size = 0.021
	_enemy_status.font_size = 40
	_enemy_status.outline_size = 11
	_enemy_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_enemy_visual.add_child(_enemy_status)
	_hero_weapon = _mesh(_hero, _box(Vector3(0.11, 0.82, 0.12)), _material(Color("#e7ded0")), Vector3(-0.48, 0.88, -0.29))
	_hero_guard = _mesh(_hero, _box(Vector3(0.69, 0.68, 0.14)), _material(Color("#88cde2")), Vector3(0.0, 0.93, -0.45))


func _refresh_combat_view() -> void:
	_combat_panel.visible = encounter != null
	_enemy_visual.visible = encounter != null and encounter.enemy.is_alive()
	_hero_weapon.visible = encounter != null
	_hero_guard.visible = encounter != null and encounter.defense.phase == Defense.Phase.GUARD
	if not encounter:
		return
	_enemy_visual.position = _ground(encounter.enemy_position)
	_enemy_visual.rotation.y = atan2(-encounter.enemy_heading.x, -encounter.enemy_heading.y)
	_enemy_warning.visible = encounter.enemy_phase == Encounter.EnemyPhase.WINDUP
	var infantry := battle.formations[InfantryAttack.INFANTRY_INDEX]
	var target_selected := command_view and selected_index == InfantryAttack.INFANTRY_INDEX and encounter.target_at(cursor)
	_enemy_target_ring.visible = command_view and (target_selected or infantry.order == Battle.Order.ATTACK)
	_enemy_weapon.rotation.x = -1.15 if _enemy_warning.visible else 0.3
	_enemy_status.text = "WINDUP" if _enemy_warning.visible else "%sROAD GUARD  ·  %d HP" % [
		"TARGET: " if target_selected else "", ceili(encounter.enemy.hp),
	]
	_enemy_status.modulate = Color("#ff9e8a") if _enemy_warning.visible else Color.WHITE
	var attack_phase := encounter.defense.attack_phase
	_hero_weapon.rotation.x = -0.9 if attack_phase == Attack.Phase.WINDUP else (0.9 if attack_phase == Attack.Phase.RECOVERY else 0.15)
	_combat_hp.text = "Mara %d / %d HP    ·    Team %d / %d BP" % [
		ceili(encounter.hero.hp), roundi(encounter.hero.max_hp), encounter.points.balance, encounter.points.capacity,
	]
	if not encounter.hero.is_alive():
		_combat_tell.text = "Mara is incapacitated"
	elif not encounter.enemy.is_alive():
		_combat_tell.text = "Road guard defeated"
	elif _enemy_warning.visible:
		_combat_tell.text = "Road guard winding up!  Face it and guard, or dodge."
	elif not encounter.active_feedback().is_empty():
		_combat_tell.text = encounter.active_feedback()
	elif attack_phase == Attack.Phase.WINDUP:
		_combat_tell.text = "Mara winding up a %s attack" % ("light" if encounter.defense.attack_kind == Attack.Attack.LIGHT else "heavy")
	elif target_selected:
		_combat_tell.text = "Triangle / K: order Shield Infantry to attack"
	elif infantry.order == Battle.Order.ATTACK:
		_combat_tell.text = "Shield Infantry attacking the road guard"
	else:
		_combat_tell.text = "Road guard %d / %d HP" % [ceili(encounter.enemy.hp), roundi(encounter.enemy.max_hp)]
