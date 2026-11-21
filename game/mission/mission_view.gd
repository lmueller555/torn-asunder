extends Node3D
## Plays a campaign mission from game/mission/missions.gd on a large 3D battlefield.
##
## The hero camera follows the leader. Hold L2 (Tab) for the command view, where the
## cursor picks a destination or an enemy platoon for the selected unit. Every rule
## lives in MissionBattle; this node renders it and turns input into orders.

signal mission_finished(won: bool)

const Battle := preload("res://game/mission/mission_battle.gd")
const Missions := preload("res://game/mission/missions.gd")
const Units := preload("res://game/mission/mission_units.gd")
const ControllerSupport := preload("res://game/controller.gd")
const World := preload("res://game/mission/mission_world.gd")
const Hud := preload("res://game/mission/mission_hud.gd")
const MODEL := preload("res://assets/models/human_infantry.glb")
const CAMPAIGNS := ["mara", "raska", "sova", "ilyra", "neris", "sereth"]

const TEAM_COLORS := [Color("#74cddc"), Color("#e0664f"), Color("#d8d2a8")]
const AI_ALLY_COLOR := Color("#9fd08a")
const HERO_COLOR := Color("#f2c46d")
const CLIPS := {
	Battle.State.IDLE: &"Idle",
	Battle.State.WALK: &"Walk",
	Battle.State.RUN: &"Run",
	Battle.State.ATTACK: &"Sword Slash",
	Battle.State.RAISE: &"Shield Raise",
	Battle.State.GUARD: &"Shield Guard",
	Battle.State.LOWER: &"Shield Lower",
	Battle.State.RECOIL: &"Sword Recoil",
	Battle.State.BLOCKED: &"Blocked Hit Stagger",
	Battle.State.STAGGER: &"Hit Stagger",
	Battle.State.KNOCKDOWN: &"Backward Knockdown",
	Battle.State.GET_UP: &"Get Up",
	Battle.State.DEAD: &"Death Fall",
	Battle.State.CHEER: &"Sword Cheer",
	Battle.State.DODGE: &"Run",
	Battle.State.CAST: &"Sword Cheer",
}
const CORPSE_SECONDS := 14.0

## Flags from the most recent finished mission, read by its debrief.
static var last_flags: Dictionary = {}

@export var mission_id := ""
@export var campaign_id := ""

var battle: Battle
var mission: Dictionary
var command_mode := false
var cursor := Vector2.ZERO
var selected := 0
var paused := false
var outcome_shown := false

var _world: World
var _camera: Camera3D
var _hud: Hud
var _models: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _markers: Array[MeshInstance3D] = []
var _shown_state: PackedInt32Array = PackedInt32Array()
var _marker_team: PackedInt32Array = PackedInt32Array()
var _structures: Dictionary = {}
var _projectiles: Array[MeshInstance3D] = []
var _effect_nodes: Dictionary = {}
var _hazard_nodes: Dictionary = {}
var _materials: Dictionary = {}
var _marker_materials: Dictionary = {}
var _cursor_ring: MeshInstance3D
var _selection_ring: MeshInstance3D
var _yaw := 0.0
var _pitch := -0.5
var _distance := 12.0
var _command_blend := 0.0
var _previous: Dictionary = {}
var _mouse_moved := false
var _raised_shown: Array[String] = []
var _outcome_timer := 0.0


func _ready() -> void:
	start()


func start() -> void:
	for child in get_children():
		child.queue_free()
	_models.clear()
	_players.clear()
	_markers.clear()
	_structures.clear()
	_projectiles.clear()
	_effect_nodes.clear()
	_hazard_nodes.clear()
	_raised_shown.clear()
	outcome_shown = false
	_outcome_timer = 0.0
	command_mode = false
	battle = null
	mission = {} if mission_id.is_empty() else Missions.find(mission_id)
	if mission.is_empty():
		push_warning("The development-only generic mission view requires an explicit, known mission_id. No mission started.")
		return
	if campaign_id.is_empty():
		for id in CAMPAIGNS:
			for entry: Dictionary in Missions.for_campaign(id):
				if entry.id == mission_id:
					campaign_id = id
	battle = Battle.new(mission, StringName(campaign_id), int(mission.get("hero_level", 5)), {}, hash(mission_id))
	_world = World.new()
	add_child(_world)
	_world.build(mission.map, battle.interactables)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.far = 900.0
	_camera.current = true
	add_child(_camera)
	_yaw = atan2(-battle.hero.facing.x, -battle.hero.facing.y)
	cursor = battle.hero.position
	_cursor_ring = _world.ring_marker(2.2, Color(1.0, 0.86, 0.5, 0.9))
	_selection_ring = _world.ring_marker(6.0, Color(0.55, 0.9, 1.0, 0.8))
	_build_models()
	_hud = Hud.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_hud)
	_hud.setup(self)
	_sync(0.0)
	_update_camera(0.0, true)


func restart() -> void:
	start()


# ---------------------------------------------------------------- models


func _build_models() -> void:
	for fighter in battle.fighters:
		_add_model(fighter)


func _add_model(fighter: Battle.Fighter) -> void:
	if fighter.kind == Battle.Kind.STRUCTURE:
		var node := _world.structure_node(fighter.structure_kind, fighter.position, fighter.facing)
		_structures[fighter.index] = node
		_models.append(null)
		_players.append(null)
		_markers.append(null)
		_shown_state.append(-1)
		_marker_team.append(-1)
		return
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	var size: float = fighter.info.get("scale", 1.0)
	model.scale = Vector3.ONE * size
	_tint(model, fighter)
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var slash := player.get_animation(&"Sword Slash")
	for track in range(slash.get_track_count()):
		if slash.track_get_type(track) == Animation.TYPE_POSITION_3D and slash.track_get_path(track).get_concatenated_subnames() == "Root":
			player.root_motion_track = slash.track_get_path(track)
			break
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	var radius := 0.42 if fighter.kind == Battle.Kind.SOLDIER else 0.85
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 16
	marker.mesh = disc
	marker.position.y = 0.02
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(marker)
	if fighter.kind == Battle.Kind.HERO:
		var label := Label3D.new()
		label.text = fighter.name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 10
		label.pixel_size = 0.008
		label.position.y = 2.35
		label.no_depth_test = true
		label.modulate = HERO_COLOR if fighter.team == Battle.PLAYER_TEAM else (TEAM_COLORS[fighter.team])
		model.add_child(label)
	_models.append(model)
	_players.append(player)
	_markers.append(marker)
	_shown_state.append(-1)
	_marker_team.append(-1)


func _tint(model: Node3D, fighter: Battle.Fighter) -> void:
	var tint: Color = fighter.info.get("tint", Color.WHITE)
	var key := tint.to_html()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Eyes":
			continue
		var base := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if base == null:
			continue
		var material_key := key + str(base.get_instance_id())
		if not _materials.has(material_key):
			var material := base.duplicate() as StandardMaterial3D
			material.albedo_color = base.albedo_color * tint
			_materials[material_key] = material
		mesh.material_override = _materials[material_key]


func _marker_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _marker_materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_marker_materials[key] = material
	return _marker_materials[key]


func _marker_color(fighter: Battle.Fighter) -> Color:
	if fighter.controlled:
		return HERO_COLOR
	if fighter.team == Battle.PLAYER_TEAM and fighter.platoon >= 0 and not battle.squads[fighter.platoon].commandable:
		return AI_ALLY_COLOR
	return TEAM_COLORS[fighter.team]


# ---------------------------------------------------------------- frame loop


func _physics_process(delta: float) -> void:
	if battle == null:
		return
	if not paused:
		_handle_input(delta)
		battle.step(delta)
	_sync(delta)
	_update_camera(delta, false)
	if battle.outcome != Battle.Outcome.LIVE:
		_outcome_timer += delta
		if not outcome_shown and _outcome_timer > 2.5:
			outcome_shown = true
			_hud.show_outcome(battle.outcome == Battle.Outcome.VICTORY, battle.outcome_reason)


func finish(won: bool) -> void:
	last_flags = battle.flags.duplicate()
	mission_finished.emit(won)


func _sync(delta: float) -> void:
	# Spawned platoons and new structures add fighters after setup.
	while _models.size() < battle.fighters.size():
		_add_model(battle.fighters[_models.size()])
	for index in range(battle.fighters.size()):
		var fighter := battle.fighters[index]
		if fighter.kind == Battle.Kind.STRUCTURE:
			var node: Node3D = _structures[index]
			node.position = Vector3(fighter.position.x, 0, fighter.position.y)
			node.rotation.y = atan2(fighter.facing.x, fighter.facing.y)
			node.visible = fighter.is_alive() or fighter.structure_kind == &"gate"
			continue
		var model := _models[index]
		if fighter.removed or (not fighter.unit.is_alive() and fighter.state == Battle.State.DEAD and fighter.time >= Battle.DURATIONS[Battle.State.DEAD] and battle.elapsed - fighter.last_hurt > CORPSE_SECONDS):
			model.visible = false
			continue
		model.visible = true
		model.position = Vector3(fighter.position.x, 0, fighter.position.y)
		model.rotation.y = atan2(fighter.facing.x, fighter.facing.y)
		var marker := _markers[index]
		marker.visible = fighter.is_alive()
		var team_key := fighter.team * 4 + (1 if fighter.controlled else 0) + (2 if fighter.platoon >= 0 and battle.squads[fighter.platoon].commandable else 0)
		if _marker_team[index] != team_key:
			_marker_team[index] = team_key
			marker.material_override = _marker_material(_marker_color(fighter))
		var player := _players[index]
		if _shown_state[index] != fighter.state:
			_shown_state[index] = fighter.state
			if fighter.state != Battle.State.DOWN:
				var clip: StringName = CLIPS[fighter.state]
				var speed := 1.0
				var length := player.get_animation(clip).length
				match fighter.state:
					Battle.State.ATTACK, Battle.State.CAST:
						speed = length / maxf(0.1, fighter.action_duration)
					Battle.State.RUN:
						speed = fighter.speed / 2.7
					Battle.State.DODGE:
						speed = 2.2
					Battle.State.WALK, Battle.State.IDLE, Battle.State.GUARD:
						speed = 1.0
					_:
						if Battle.DURATIONS.has(fighter.state):
							speed = length / Battle.DURATIONS[fighter.state]
				player.play(clip, 0.08 if delta > 0.0 else 0.0, speed)
		if fighter.state != Battle.State.DOWN:
			player.advance(delta)
	_sync_projectiles()
	_sync_effects()
	_sync_markers()
	for id in battle.raised:
		if not _raised_shown.has(id):
			_raised_shown.append(id)
			_world.raise_obstacle(id)
	if _hud:
		_hud.refresh()


func _sync_projectiles() -> void:
	while _projectiles.size() < battle.projectiles.size():
		var shot := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.7
		shot.mesh = mesh
		shot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shot)
		_projectiles.append(shot)
	for i in range(_projectiles.size()):
		var node := _projectiles[i]
		if i >= battle.projectiles.size():
			node.visible = false
			continue
		var data: Dictionary = battle.projectiles[i]
		node.visible = true
		var previous := node.position
		node.position = data.pos
		node.material_override = _marker_material(data.color)
		var direction: Vector3 = node.position - previous
		if direction.length() > 0.01:
			node.look_at(node.position + direction, Vector3.UP)
			node.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _sync_effects() -> void:
	var live := {}
	for effect in battle.effects:
		live[effect.id] = true
		if not _effect_nodes.has(effect.id):
			var node := _world.burst(effect.radius, effect.color, effect.facing if effect.kind == "cone" else Vector2.ZERO)
			node.position = Vector3(effect.pos.x, 0.12, effect.pos.y)
			_effect_nodes[effect.id] = node
		var material := (_effect_nodes[effect.id] as MeshInstance3D).material_override as ShaderMaterial
		material.set_shader_parameter("progress", clampf(effect.age / effect.life, 0.0, 1.0))
	for effect in _effect_nodes.keys():
		if not live.has(effect):
			_effect_nodes[effect].queue_free()
			_effect_nodes.erase(effect)
	var hazards := {}
	for hazard in battle.hazards:
		hazards[hazard.id] = true
		if not _hazard_nodes.has(hazard.id):
			var node := _world.ring_marker(hazard.radius, Color(1.0, 0.35, 0.2, 0.9))
			node.position = Vector3(hazard.pos.x, 0.09, hazard.pos.y)
			_hazard_nodes[hazard.id] = node
		var warning: bool = battle.hazard_phase(hazard) == "warning"
		var ring := _hazard_nodes[hazard.id] as MeshInstance3D
		(ring.material_override as ShaderMaterial).set_shader_parameter("thickness", 0.12 if warning else 1.0)
	for hazard in _hazard_nodes.keys():
		if not hazards.has(hazard):
			_hazard_nodes[hazard].queue_free()
			_hazard_nodes.erase(hazard)


func _sync_markers() -> void:
	for i in range(battle.interactables.size()):
		var item := battle.interactables[i]
		_world.show_interactable(i, item.active and not item.done, item.pos)
	var shown := {}
	for item in battle.objectives:
		if item.status != "active":
			continue
		if item.has("zone"):
			shown[item.zone] = true
		if item.type == "deliveries":
			for cart_id in item.carts:
				shown[item.carts[cart_id]] = true
	for zone_id in battle.zones:
		_world.show_zone(zone_id, shown.has(zone_id))
	_cursor_ring.visible = command_mode
	_cursor_ring.position = Vector3(cursor.x, 0.1, cursor.y)
	var entry := selected_entry()
	_selection_ring.visible = command_mode and not entry.is_empty()
	if _selection_ring.visible:
		var at: Vector2 = entry.position
		_selection_ring.position = Vector3(at.x, 0.11, at.y)


# ---------------------------------------------------------------- command list


## Commandable platoons first, then commandable carts.
func command_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for squad in battle.commandable_squads():
		if squad.alive_count(battle) > 0 and not squad.departed:
			entries.append({"kind": "squad", "squad": squad, "name": squad.name, "position": squad.centroid(battle)})
	for cart in battle.commandable_structures():
		if cart.is_alive() and not cart.delivered and not cart.turned_back:
			entries.append({"kind": "cart", "cart": cart, "name": cart.name, "position": cart.position})
	return entries


func selected_entry() -> Dictionary:
	var entries := command_entries()
	if entries.is_empty():
		return {}
	selected = clampi(selected, 0, entries.size() - 1)
	return entries[selected]


func _order_move() -> void:
	var entry := selected_entry()
	if entry.is_empty():
		return
	if entry.kind == "cart":
		battle.command_structure(entry.cart.structure_id, "advance", cursor)
		return
	var enemy := _enemy_squad_near(cursor, 6.0)
	if enemy:
		battle.command(entry.squad.index, {"kind": "attack", "target": enemy.id})
	else:
		battle.command(entry.squad.index, {"kind": "move", "to": cursor})


func _order_attack() -> void:
	var entry := selected_entry()
	if entry.is_empty() or entry.kind == "cart":
		return
	var enemy := _enemy_squad_near(cursor, 40.0)
	if enemy:
		battle.command(entry.squad.index, {"kind": "attack", "target": enemy.id})


func _order_hold() -> void:
	var entry := selected_entry()
	if entry.is_empty():
		return
	if entry.kind == "cart":
		battle.command_structure(entry.cart.structure_id, "halt")
	else:
		battle.command(entry.squad.index, {"kind": "hold"})


func _order_clear() -> void:
	var entry := selected_entry()
	if entry.is_empty():
		return
	if entry.kind == "cart":
		battle.command_structure(entry.cart.structure_id, "turn_back")
	else:
		battle.command(entry.squad.index, {"kind": "follow"})


func _enemy_squad_near(point: Vector2, radius: float) -> Battle.Squad:
	var best: Battle.Squad = null
	var nearest := radius
	for squad in battle.squads:
		if squad.team != Battle.ENEMY_TEAM or not squad.spawned or squad.alive_count(battle) == 0:
			continue
		var distance := squad.centroid(battle).distance_to(point)
		if distance < nearest:
			nearest = distance
			best = squad
	return best


# ---------------------------------------------------------------- input


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_moved = true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_yaw -= event.relative.x * 0.006
			_pitch = clampf(_pitch - event.relative.y * 0.004, -1.2, -0.15)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(6.0, _distance - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(24.0, _distance + 1.0)
		elif command_mode and event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_cursor()
			_order_move()
		elif command_mode and event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_cursor()
			_order_attack()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			selected = event.physical_keycode - KEY_1
		elif event.physical_keycode == KEY_P:
			paused = not paused


func _held(name: String, pressed: bool) -> bool:
	var was: bool = _previous.get(name, false)
	_previous[name] = pressed
	return pressed and not was


func _handle_input(delta: float) -> void:
	if outcome_shown:
		return
	var device: int = ControllerSupport.device()
	var stick := Vector2.ZERO
	var look := Vector2.ZERO
	var trigger := 0.0
	if device >= 0:
		stick = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		look = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		trigger = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		if stick.length() < 0.18:
			stick = Vector2.ZERO
		if look.length() < 0.18:
			look = Vector2.ZERO
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var move := stick if stick != Vector2.ZERO else keys.limit_length(1.0)
	var joy := func(button: JoyButton) -> bool: return device >= 0 and Input.is_joy_button_pressed(device, button)
	var key := func(code: Key) -> bool: return Input.is_physical_key_pressed(code)
	var mouse := func(button: MouseButton) -> bool: return Input.is_mouse_button_pressed(button)
	look.x += float(key.call(KEY_RIGHT)) - float(key.call(KEY_LEFT))
	look.y += float(key.call(KEY_DOWN)) - float(key.call(KEY_UP))
	_yaw -= look.x * 2.4 * delta
	_pitch = clampf(_pitch - look.y * 1.4 * delta, -1.2, -0.15)
	command_mode = key.call(KEY_TAB) or trigger > 0.5
	var entries := command_entries()
	var prev_unit: bool = _held("prev", joy.call(JOY_BUTTON_DPAD_LEFT) or (command_mode and key.call(KEY_Q)))
	var next_unit: bool = _held("next", joy.call(JOY_BUTTON_DPAD_RIGHT) or (command_mode and key.call(KEY_E)))
	if not entries.is_empty():
		if prev_unit:
			selected = posmod(selected - 1, entries.size())
		if next_unit:
			selected = posmod(selected + 1, entries.size())
	var forward := Vector2(-sin(_yaw), -cos(_yaw))
	var right := Vector2(-forward.y, forward.x)
	if command_mode:
		var speed := 46.0
		cursor += (right * move.x - forward * move.y) * speed * delta
		if _mouse_moved:
			_mouse_cursor()
		cursor = cursor.clamp(battle.bounds.position, battle.bounds.end)
		battle.set_hero_input({"move": Vector2.ZERO})
		if _held("c_move", joy.call(JOY_BUTTON_X) or key.call(KEY_J)):
			_order_move()
		if _held("c_attack", joy.call(JOY_BUTTON_Y) or key.call(KEY_K)):
			_order_attack()
		if _held("c_hold", joy.call(JOY_BUTTON_A) or key.call(KEY_SPACE) or key.call(KEY_H)):
			_order_hold()
		if _held("c_clear", joy.call(JOY_BUTTON_B) or key.call(KEY_F)):
			_order_clear()
		return
	_mouse_moved = false
	cursor = cursor.lerp(battle.hero.position, minf(1.0, 4.0 * delta))
	var world_move := right * move.x - forward * move.y
	if key.call(KEY_CTRL):
		world_move *= 0.5
	battle.set_hero_input({
		"move": world_move,
		"light": _held("light", joy.call(JOY_BUTTON_X) or key.call(KEY_J) or mouse.call(MOUSE_BUTTON_LEFT)),
		"heavy": _held("heavy", joy.call(JOY_BUTTON_Y) or key.call(KEY_K) or mouse.call(MOUSE_BUTTON_RIGHT)),
		"dodge": _held("dodge", joy.call(JOY_BUTTON_B) or key.call(KEY_SPACE)),
		"guard": joy.call(JOY_BUTTON_LEFT_SHOULDER) or key.call(KEY_SHIFT) or key.call(KEY_L),
		"interact": joy.call(JOY_BUTTON_A) or key.call(KEY_E),
		"ability": _held("ability", joy.call(JOY_BUTTON_RIGHT_SHOULDER) or key.call(KEY_Q)),
	})


func _mouse_cursor() -> void:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.001:
		return
	var t := -origin.y / direction.y
	if t > 0.0:
		var hit := origin + direction * t
		cursor = Vector2(hit.x, hit.z).clamp(battle.bounds.position, battle.bounds.end)


# ---------------------------------------------------------------- camera


func _update_camera(delta: float, snap: bool) -> void:
	var goal_blend := 1.0 if command_mode else 0.0
	_command_blend = goal_blend if snap else move_toward(_command_blend, goal_blend, delta * 3.5)
	var blend := smoothstep(0.0, 1.0, _command_blend)
	var hero_at := Vector3(battle.hero.position.x, 1.4, battle.hero.position.y)
	var orbit := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var hero_eye := hero_at + orbit * Vector3(0, 0, _distance)
	var focus := Vector3(cursor.x, 0, cursor.y)
	var command_orbit := Basis.from_euler(Vector3(-1.08, _yaw, 0.0))
	var command_eye := focus + command_orbit * Vector3(0, 0, 78.0)
	var eye := hero_eye.lerp(command_eye, blend)
	var target := hero_at.lerp(focus, blend)
	if snap:
		_camera.position = eye
	else:
		_camera.position = _camera.position.lerp(eye, minf(1.0, 10.0 * delta))
	_camera.look_at(target, Vector3.UP)
