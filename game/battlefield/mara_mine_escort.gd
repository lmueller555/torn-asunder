extends "res://game/battlefield/command_harness.gd"

## Emitted once when an attempt reaches victory or defeat.
signal mission_finished(won: bool)

const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")
const ArcherAttack := preload("res://game/battlefield/mara_archer_attack.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Skirmish := preload("res://game/combat/infantry_skirmish.gd")
const Archer := preload("res://game/combat/human_archer_volley.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const CustodyCaseVisual := preload("res://assets/models/environment/godbridle_case_visual.gd")
const PICKUP_RADIUS := 2.2
const EXIT_RADIUS := 2.7
# PassRelease faces the exit. This corridor catches the uphill approach early
# enough for the guard to physically move from the reserve pocket into view.
const APPROACH_BEHIND := 61.0
const APPROACH_AHEAD := 4.0
const APPROACH_HALF_WIDTH := 9.0
const WARM_LIGHT := Color("#ffd382")
const EXIT_LIGHT := Color("#8de5d1")
const SUNDERING_COST: int = Attack.PROFILES[Attack.Attack.SUNDERING_STRIKE]["bp_cost"]
const SPECIAL_PRESS := 0.52
const SPECIAL_RELEASE := 0.32
const INFANTRY_IDLE := &"Idle"
const INFANTRY_RUN := &"Run"
const HEAVY_IDLE := &"Shield-Ready Idle"
const HEAVY_RUN := &"Combat Run"
const HEAVY_MODEL_RUN_SPEED := 2.2
# Local paired playtest values, not campaign training or skirmish stat changes.
const HEAVY_HP := 380.0
const HEAVY_CONTACT_BASE := 36.32
const HEAVY_MOVE_SPEED := 2.55
const CAMPAIGN_MINE := "res://game/battlefields/year_one_mine_campaign.tscn"

@export var opposition_enabled := true
@export var render_shield_infantry := false
@export var sundering_strike_enabled := false
@export var road_guard_spawn: NodePath = ^"Markers/Spawns/MaraRoadGuard"
@export var interception_approach: NodePath
@export var interception_route: Array[NodePath] = []
@export var custody_case_scene: PackedScene

var objective := Escort.new()
var encounter: Encounter
var _launch_lead_level := 1
var _launch_lead_melee_invested := false
var _heavy_replay_loadout := false
var _pickup: Marker3D
var _exit: Marker3D
var _pass_release: Marker3D
var _interception_started := false
var _pickup_beacon: Node3D
var _exit_beacon: Node3D
var _bridle: Node3D
var _custody_case: CustodyCaseVisual
var _interact_requested := false
var _hero_incapacitated := false
var _bridle_lost := false
var _guard_key := false
var _guard_pad := false
var _special_pad_down := false
var _enemy_visual: Node3D
var _enemy_weapon: MeshInstance3D
var _enemy_warning: MeshInstance3D
var _enemy_target_ring: MeshInstance3D
var _enemy_status: Label3D
var _hero_weapon: MeshInstance3D
var _hero_guard: MeshInstance3D
var _infantry_animators: Array[AnimationPlayer] = []

@onready var _goal_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _instructions_label: Label = $ObjectiveHUD/Panel/Margin/Readout/Instructions
@onready var _combat_panel: PanelContainer = $CombatHUD/Panel
@onready var _combat_hp: Label = $CombatHUD/Panel/Margin/Readout/Health
@onready var _infantry_hp: Label = $CombatHUD/Panel/Margin/Readout/Infantry
@onready var _archer_status: Label = $CombatHUD/Panel/Margin/Readout/Archers
@onready var _special_status: Label = $CombatHUD/Panel/Margin/Readout/Sundering
@onready var _combat_tell: Label = $CombatHUD/Panel/Margin/Readout/Tell
@onready var _combat_controls: Label = $CombatHUD/Panel/Margin/Readout/Controls
@onready var _restart_button: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


## Sampled from confirmed campaign clears at deployment, never read again
## during the attempt or on local retry. This sets the BP cap, not Mara's stats.
func configure_campaign_lead_level(level: int) -> void:
	if not is_inside_tree():
		_launch_lead_level = level


## The campaign caller supplies an already authorized snapshot, not a rating or a save reader.
func configure_campaign_lead_melee(invested: bool) -> void:
	if not is_inside_tree() and not is_node_ready() and battlefield_scene \
			and battlefield_scene.resource_path == CAMPAIGN_MINE:
		_launch_lead_melee_invested = invested


## Local proof hook only. A later deployment caller must authorize both a
## confirmed Mine replay and a separately earned Heavy detachment.
func configure_replay_heavy_infantry(replay: bool, trained_detachment: bool) -> bool:
	if is_inside_tree() or is_node_ready() or not replay or not trained_detachment \
			or not render_shield_infantry or not battlefield_scene \
			or battlefield_scene.resource_path != CAMPAIGN_MINE:
		return false
	var heavy := Catalog.TYPES[Catalog.HUMAN_HEAVY_INFANTRY].model as PackedScene
	if not heavy or not heavy.can_instantiate():
		return false
	var instance := heavy.instantiate()
	var player := instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var approved_rig_ready := instance is Node3D and player != null \
		and player.has_animation(HEAVY_IDLE) and player.has_animation(HEAVY_RUN)
	instance.free()
	_heavy_replay_loadout = approved_rig_ready
	return approved_rig_ready


func _ready() -> void:
	_apply_infantry_loadout()
	super._ready()
	if sundering_strike_enabled and _input_device >= 0:
		_special_pad_down = GameplayBindings.axis(_input_device, JOY_AXIS_TRIGGER_RIGHT) >= SPECIAL_PRESS
	_bind_objective()
	_restart_button.pressed.connect(restart_mission)
	if _mission_hud:
		$ObjectiveHUD.hide()
		$CombatHUD.hide()
	_build_combat_visuals()
	_reset_encounter()
	_refresh_objective_view(hero_world_position())
	_present_mission_hud()


func _bind_objective() -> void:
	_pickup = battlefield_marker(^"Markers/Objectives/GodbridlePickup")
	_exit = battlefield_marker(^"Markers/Objectives/GodbridleExit")
	_pass_release = battlefield_marker(interception_approach)
	objective.interception_requested.connect(_on_interception_requested)
	_pickup_beacon = _beacon(_pickup, PICKUP_RADIUS, WARM_LIGHT, "GODBRIDLE")
	_exit_beacon = _beacon(_exit, EXIT_RADIUS, EXIT_LIGHT, "EAST ROAD EXIT")
	_bridle = _make_bridle()


func _physics_process(delta: float) -> void:
	if _finished():
		return
	if not _hero_incapacitated:
		if encounter:
			encounter.defense.set_guard(hero_combat_active() and (_guard_key or _guard_pad), true)
			var dodge := encounter.defense.advance_defense(delta, true)
			battle.move_hero(dodge, _movement_check())
		super._physics_process(delta)
		if encounter:
			_refresh_combat_view()
	var feet := hero_world_position()
	_advance_objective(feet, delta)
	_refresh_objective_view(feet)
	_present_mission_hud()
	if _finished():
		if encounter:
			_refresh_sundering_readout(team_battle_points_frame())
		mission_finished.emit(_objective_won())


func _advance_objective(feet: Vector3, _delta: float) -> void:
	var observation := Escort.Observation.new()
	observation.interact_pressed = _interact_requested and not command_view
	observation.hero_in_pickup_zone = feet.distance_to(_pickup.global_position) <= PICKUP_RADIUS
	# In this prototype the hero is the sole carrier; units entering the exit never count.
	observation.carrier_in_road_exit = objective.phase == Escort.Phase.ESCORTING \
		and not _hero_incapacitated and feet.distance_to(_exit.global_position) <= EXIT_RADIUS
	observation.carrier_in_interception_approach = objective.phase == Escort.Phase.ESCORTING \
		and not _hero_incapacitated and encounter != null and encounter.enemy.is_alive() \
		and encounter.enemy_phase == Encounter.EnemyPhase.AT_RESERVE and _inside_pass_approach(feet)
	observation.hero_incapacitated = _hero_incapacitated
	observation.bridle_lost = _bridle_lost
	_interact_requested = false
	objective.advance(observation)


func _objective_won() -> bool:
	return objective.phase == Escort.Phase.SUCCEEDED


## Campaign variants can provide an alternate HUD landmark set.
func alternate_minimap_objective() -> Dictionary:
	return {}


func _inside_pass_approach(feet: Vector3) -> bool:
	if not _pass_release:
		return false
	var local := _pass_release.to_local(feet)
	return absf(local.x) <= APPROACH_HALF_WIDTH and absf(local.y) <= 2.0 \
		and local.z >= -APPROACH_AHEAD and local.z <= APPROACH_BEHIND


func _on_interception_requested() -> void:
	_interception_started = encounter != null and encounter.begin_interception()


func _after_battle_step(delta: float) -> void:
	if encounter:
		encounter.advance(delta, battle, _terrain.clear_melee_contact, _terrain.can_move)
		if not encounter.hero.is_alive():
			report_hero_incapacitated()
	_sync_infantry_animation()


func _add_formation_member_visual(member: Node3D, formation_index: int) -> bool:
	if not render_shield_infantry or formation_index != InfantryAttack.INFANTRY_INDEX:
		return false
	var scene := _infantry_model_scene()
	if not scene or not scene.can_instantiate():
		return false
	var instance := scene.instantiate()
	var model := instance as Node3D
	if not model:
		instance.free()
		return false
	model.name = "HeavyInfantryModel" if _heavy_replay_loadout else "HumanInfantryModel"
	# The imported skirmish model faces +Z. The battlefield feet anchor faces
	# -Z; turn the art once and keep its authored meter scale and zero foot offset.
	model.rotate_y(PI)
	member.add_child(model)
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var idle := HEAVY_IDLE if _heavy_replay_loadout else INFANTRY_IDLE
	if player and player.has_animation(idle):
		_infantry_animators.append(player)
		player.play(idle)
	return true


func _lead_member_scene() -> PackedScene:
	return _infantry_model_scene() if render_shield_infantry else null


func _infantry_model_scene() -> PackedScene:
	var unit := Catalog.HUMAN_HEAVY_INFANTRY if _heavy_replay_loadout else Catalog.HUMAN_INFANTRY
	var definition: Dictionary = Catalog.TYPES.get(unit, {})
	return definition.get("model") as PackedScene


func _sync_infantry_animation(reset := false) -> void:
	if _infantry_animators.is_empty():
		return
	var index := InfantryAttack.INFANTRY_INDEX
	var infantry := battle.formations[index]
	# The member anchors still follow the shared harness. This measures actual
	# movement this tick, including attack approach, not merely a requested order.
	var previous := _formation_models[index].position
	var moving := not Vector2(previous.x, previous.z).is_equal_approx(infantry.position)
	for player in _infantry_animators:
		if not infantry.can_receive_orders():
			if player.is_playing():
				player.pause()
			continue
		if reset:
			player.stop()
		var idle := HEAVY_IDLE if _heavy_replay_loadout else INFANTRY_IDLE
		var run := HEAVY_RUN if _heavy_replay_loadout else INFANTRY_RUN
		var clip := run if moving and not reset and player.has_animation(run) else idle
		if player.current_animation != clip or not player.is_playing():
			var clip_speed := HEAVY_MODEL_RUN_SPEED if _heavy_replay_loadout else Skirmish.RUN_SPEED
			var speed := infantry.move_speed / clip_speed if clip == run else 1.0
			player.play(clip, 0.0 if reset else 0.10, speed)


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if sundering_strike_enabled and event is InputEventJoypadMotion \
		and event.axis == JOY_AXIS_TRIGGER_RIGHT and _uses_joypad(event.device):
		var was_down := _special_pad_down
		_special_pad_down = event.axis_value > SPECIAL_RELEASE if was_down else event.axis_value >= SPECIAL_PRESS
		if hero_combat_active():
			if _special_pad_down and not was_down:
				_try_sundering_strike()
			return
		# Outside the fight R2 widens the selected platoon's formation.
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
	# Attacks, guard, dodge and the Sundering Strike exist only while Mara fights.
	# Marching (or commanding another platoon mid-fight) leaves these buttons to the
	# waypoint controls.
	if not command_view and not hero_combat_active():
		_release_guard()
		return false
	# In command view L1 changes the selected platoon's formation instead of guarding.
	if command_view and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		return false
	var key := 0
	if event is InputEventKey and not event.echo:
		key = event.physical_keycode
		if key == KEY_U:
			_guard_key = event.pressed
			return true
		if not event.pressed:
			return false
		if key == KEY_V and sundering_strike_enabled:
			_try_sundering_strike()
			return true
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
		if encounter.order_infantry_attack(battle, selected_index, cursor) \
			or encounter.order_archer_attack(battle, selected_index, cursor, _terrain.clear_melee_contact):
			_sync_view()
		_refresh_combat_view()
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


func _release_guard() -> void:
	if _guard_key or _guard_pad:
		_guard_key = false
		_guard_pad = false
		if encounter:
			encounter.defense.set_guard(false, true)


func _try_sundering_strike() -> void:
	if not encounter or not hero_combat_active() or _finished() or _hero_incapacitated:
		return
	encounter.defense.set_guard(_guard_key or _guard_pad, true)
	# HeroDefense admits the action; HeroAttackSequence alone charges the pool.
	if encounter.defense.start_attack(Attack.Attack.SUNDERING_STRIKE, true):
		_refresh_combat_view()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		_guard_key = false
		_guard_pad = false
		_special_pad_down = false
		_interact_requested = false


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if device == _input_device and not connected:
		_guard_pad = false
		_special_pad_down = false
	super._on_joy_connection_changed(device, connected)


## Called by future combat when the hero is no longer able to carry the Godbridle.
func report_hero_incapacitated() -> void:
	_hero_incapacitated = true


## Called by future encounter rules if the bridle is definitively lost.
func report_bridle_lost() -> void:
	_bridle_lost = true


func restart_mission() -> void:
	_reset_objective()
	_hero_incapacitated = false
	_bridle_lost = false
	_interact_requested = false
	_restart_button.release_focus()
	restart_battle()
	if _heavy_replay_loadout:
		_apply_infantry_loadout()
		_sync_view()
	_sync_infantry_animation(true)
	_reset_encounter()
	_refresh_objective_view(hero_world_position())
	_present_mission_hud()


func _reset_objective() -> void:
	objective.restart()


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
	if _custody_case and (awaiting or carrying):
		_custody_case.present(carrying, command_view)
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
			if _interception_started and encounter.enemy.is_alive():
				_instructions_label.text = "Orc movement ahead. Get the Godbridle through to the exit."
			else:
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
	if custody_case_scene:
		_custody_case = CustodyCaseVisual.new(custody_case_scene.instantiate() as Node3D)
		prop.add_child(_custody_case)
		return prop
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


func _apply_infantry_loadout() -> void:
	if _heavy_replay_loadout:
		var infantry := battle.formations[InfantryAttack.INFANTRY_INDEX]
		infantry.move_speed = HEAVY_MOVE_SPEED
		infantry.title = "Heavy Infantry"


func _reset_encounter() -> void:
	_interception_started = false
	_guard_key = false
	_guard_pad = false
	var guard_marker := battlefield_marker(road_guard_spawn)
	if not guard_marker:
		guard_marker = battlefield_marker(^"Markers/Routes/EastPass")
	var infantry: InfantryAttack = InfantryAttack.new(HEAVY_HP, HEAVY_CONTACT_BASE) if _heavy_replay_loadout else null
	encounter = Encounter.new(_marker_position(guard_marker), _ground, _terrain.clear_ranged_lane,
		_launch_lead_level, infantry, _launch_lead_melee_invested, _enemy_title()) \
		if opposition_enabled and guard_marker else null
	if encounter:
		encounter.aggro_sight = _clear_enemy_aggro_sight
		encounter.hold_story_lane = _pass_release != null
	if encounter and _pass_release:
		var route := PackedVector2Array()
		for path in interception_route:
			var waypoint := battlefield_marker(path)
			if not waypoint:
				route.clear()
				break
			route.append(_marker_position(waypoint))
		encounter.stage_interception(route)
	_refresh_combat_view()


func _clear_enemy_aggro_sight(from: Vector2, to: Vector2) -> bool:
	return from == to or _terrain.clear_ranged_lane(_ground(from, 1.38), _ground(to, 1.30))


func _enemy_color() -> Color:
	return Color("#b45e4c")


func _enemy_title() -> String:
	return "Road guard"


func _build_combat_visuals() -> void:
	_enemy_visual = Node3D.new()
	add_child(_enemy_visual)
	var rust := _material(_enemy_color())
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
	# Attack prompts only while Mara fights (or in command view, for formation attacks).
	_combat_controls.visible = (command_view or hero_combat_active()) and not _combat_controls.has_meta(&"tutorial_hidden")
	if not encounter:
		return
	_enemy_visual.position = _ground(encounter.enemy_position)
	_enemy_visual.rotation.y = atan2(-encounter.enemy_heading.x, -encounter.enemy_heading.y)
	_enemy_warning.visible = encounter.enemy_phase == Encounter.EnemyPhase.WINDUP
	var infantry := battle.formations[InfantryAttack.INFANTRY_INDEX]
	var archers := battle.formations[ArcherAttack.ARCHER_INDEX]
	var selected := battle.formation_at(selected_index)
	var target_selected := command_view and selected.order != Battle.Order.DEFEATED and encounter.target_at(cursor)
	_enemy_target_ring.visible = command_view and (target_selected or infantry.order == Battle.Order.ATTACK \
		or archers.order == Battle.Order.ATTACK)
	_enemy_weapon.rotation.x = -1.15 if _enemy_warning.visible else 0.3
	var targets_infantry := encounter.windup_target == Encounter.Target.INFANTRY
	var targets_archers := encounter.windup_target == Encounter.Target.ARCHERS
	var targets_civilian := encounter.windup_target == Encounter.Target.CIVILIAN
	var target_callout := " → INFANTRY" if targets_infantry else (" → ARCHERS" if targets_archers else "")
	if targets_civilian:
		target_callout = " → MINER"
	_enemy_status.text = "WINDUP" + target_callout if _enemy_warning.visible else "%s%s  ·  %d HP" % [
		"TARGET: " if target_selected else "", _enemy_title().to_upper(), ceili(encounter.enemy.hp),
	]
	_enemy_status.modulate = Color("#ff9e8a") if _enemy_warning.visible else Color.WHITE
	if _mission_hud:
		_enemy_status.hide()
	var attack_phase := encounter.defense.attack_phase
	var special := encounter.defense.attack_kind == Attack.Attack.SUNDERING_STRIKE
	match attack_phase:
		Attack.Phase.WINDUP: _hero_weapon.rotation.x = -1.40 if special else -0.90
		Attack.Phase.RECOVERY: _hero_weapon.rotation.x = 1.26 if special else 0.90
		_: _hero_weapon.rotation.x = 0.15
	var bp := team_battle_points_frame()
	_refresh_sundering_readout(bp)
	_combat_hp.text = "Mara %d / %d HP    ·    Team %d / %d BP (lead Lv %d)" % [
		ceili(encounter.hero.hp), roundi(encounter.hero.max_hp), bp.balance, bp.capacity, bp.lead_level,
	]
	var troops := encounter.infantry_attack.attacker
	_infantry_hp.text = "%s · %d / %d prototype HP%s" % [
		infantry.title, ceili(troops.hp), roundi(troops.max_hp), " · Defeated" if not troops.is_alive() else "",
	]
	_refresh_archer_readout()
	if not encounter.hero.is_alive():
		_combat_tell.text = "Mara is incapacitated"
	elif not encounter.enemy.is_alive():
		_combat_tell.text = "%s defeated" % _enemy_title()
	elif _enemy_warning.visible:
		if targets_civilian:
			_combat_tell.text = "%s is attacking a miner!" % _enemy_title()
		elif targets_infantry:
			_combat_tell.text = "%s winding up at %s!" % [_enemy_title(), infantry.title]
		elif targets_archers:
			_combat_tell.text = "%s winding up at Archers! Pull back." % _enemy_title()
		else:
			_combat_tell.text = "%s winding up!" % _enemy_title()
	elif not encounter.active_feedback().is_empty():
		_combat_tell.text = encounter.active_feedback()
	elif encounter.enemy_phase == Encounter.EnemyPhase.INTERCEPTING:
		_combat_tell.text = "Orc guard advancing onto the east road"
	elif encounter.enemy_phase == Encounter.EnemyPhase.AT_RESERVE:
		_combat_tell.text = _enemy_reserve_readout()
	elif attack_phase == Attack.Phase.WINDUP:
		if special:
			_combat_tell.text = "Mara winding up Sundering Strike"
		else:
			_combat_tell.text = "Mara winding up a %s attack" % ("light" if encounter.defense.attack_kind == Attack.Attack.LIGHT else "heavy")
	elif archers.order == Battle.Order.ATTACK and encounter.archer_attack.volley.phase == Archer.Phase.IDLE:
		_combat_tell.text = "Archers need distance. Move them away from the %s." % _enemy_title().to_lower().trim_prefix("road ")
	elif infantry.order == Battle.Order.ATTACK:
		_combat_tell.text = "%s attacking the %s" % [infantry.title, _enemy_title().to_lower()]
	elif encounter.enemy_phase == Encounter.EnemyPhase.ALERT:
		var spotted := "Mara"
		if encounter.alert_target == Encounter.Target.INFANTRY:
			spotted = infantry.title
		elif encounter.alert_target == Encounter.Target.ARCHERS:
			spotted = archers.title
		_combat_tell.text = "%s spotted %s and is holding position" % [_enemy_title(), spotted]
	else:
		_combat_tell.text = "%s %d / %d HP" % [_enemy_title(), ceili(encounter.enemy.hp), roundi(encounter.enemy.max_hp)]



func _mission_hud_state() -> Dictionary:
	var state := super._mission_hud_state()
	if not _goal_label.text.is_empty() and String(state.objective).is_empty():
		state.objective = _goal_label.text
		state.objective_visible = true
	if not _instructions_label.text.is_empty() and String(state.context).is_empty():
		state.context = _instructions_label.text
	if not encounter:
		return state
	var bp := team_battle_points_frame()
	state.bp = bp.balance
	state.bp_max = bp.capacity
	state.hero_hp = encounter.hero.hp
	state.hero_max_hp = encounter.hero.max_hp
	var infantry := encounter.infantry_attack.attacker
	var archers := encounter.archer_attack.attacker
	var hero := {
		"name": _mission_hero_name if not _mission_hero_name.is_empty() else "Mara Halden",
		"level": bp.lead_level,
		"hp": encounter.hero.hp,
		"max_hp": encounter.hero.max_hp,
		"selected": selected_index == Battle.LEAD_INDEX,
		"engaged": battle.lead_engaged,
	}
	state.roster = [
		hero,
		_mission_hud_entry(InfantryAttack.INFANTRY_INDEX, infantry.hp, infantry.max_hp),
		_mission_hud_entry(ArcherAttack.ARCHER_INDEX, archers.hp, archers.max_hp),
	]
	var enemy_anchor := _mission_hud_enemy_anchor()
	if enemy_anchor.is_finite():
		state.enemy = {"name": _enemy_title(), "level": 1, "hp": encounter.enemy.hp, "max_hp": encounter.enemy.max_hp}
		state.enemy_anchor = enemy_anchor
	if _finished():
		state.feedback = _instructions_label.text
	elif _enemy_warning.visible:
		state.feedback = _combat_tell.text
	elif not encounter.active_feedback().is_empty():
		state.feedback = encounter.active_feedback()
	return state


func _mission_hud_enemy_contact() -> bool:
	return _mission_hud_enemy_anchor().is_finite()


func _mission_hud_enemy_anchor() -> Vector2:
	if not encounter or not encounter.enemy.is_alive() or not _enemy_visual.visible \
			or not battle.lead_engaged or not hero_combat_active():
		return Vector2.INF
	if _terrain and not _terrain.clear_melee_contact(battle.hero_position, encounter.enemy_position):
		return Vector2.INF
	return _mission_hud_project(_enemy_visual.to_global(Vector3.UP * 1.12))


func _enemy_reserve_readout() -> String:
	return "No enemy on the escort road"


## Read-only encounter status. The scene and combat resolvers still use the live pool.
func team_battle_points_frame() -> Points.Frame:
	return encounter.points.frame() if encounter else null


func _refresh_sundering_readout(bp: Points.Frame) -> void:
	_special_status.visible = sundering_strike_enabled
	if not sundering_strike_enabled:
		return
	var defense := encounter.defense
	var status: String
	if _finished() or _hero_incapacitated or not encounter.hero.is_alive():
		status = "Unavailable"
	elif defense.attack_kind == Attack.Attack.SUNDERING_STRIKE and defense.attack_phase == Attack.Phase.WINDUP:
		status = "Windup %d%%" % floori(defense.attack_progress() * 100.0)
	elif defense.attack_kind == Attack.Attack.SUNDERING_STRIKE and defense.attack_phase == Attack.Phase.RECOVERY:
		status = "Recovering"
	elif command_view:
		status = "Hero view only"
	elif defense.phase != Defense.Phase.FREE or defense.attack_phase != Attack.Phase.IDLE:
		status = "Busy"
	elif bp.spend_status(SUNDERING_COST) == Points.SpendStatus.INSUFFICIENT:
		status = "Not enough BP"
	else:
		status = "Ready"
	_special_status.text = "Sundering Strike · R2 / V · %d BP · %s" % [SUNDERING_COST, status]


func _refresh_archer_readout() -> void:
	var archers := encounter.archer_attack.attacker
	var volley := encounter.archer_attack.volley
	var action := ""
	if not archers.is_alive():
		action = " · Defeated"
	elif volley.phase == Archer.Phase.WINDUP:
		action = " · Drawing %d%%" % floori(volley.phase_progress() * 100.0)
	elif volley.phase == Archer.Phase.RELOAD:
		action = " · Reloading"
	_archer_status.text = "Archers · %d / %d prototype HP%s" % [ceili(archers.hp), roundi(archers.max_hp), action]


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	if encounter and opposition_enabled and encounter.enemy.is_alive():
		return PackedVector2Array([encounter.enemy_position])
	return PackedVector2Array()
