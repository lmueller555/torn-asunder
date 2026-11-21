extends Node3D

const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")

const TEAM_COLORS := [Color("#74cddc"), Color("#ecad67")]
const CLIPS := {
	Battle.State.IDLE: &"Idle",
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
}

# Use only motions authored for this rig. Other states use its own ready pose.
const HEAVY_CLIPS := {
	Battle.State.IDLE: &"Shield-Ready Idle",
	Battle.State.RUN: &"Combat Run",
	Battle.State.ATTACK: &"Advancing Diagonal Cut",
	Battle.State.RAISE: &"Shield Raise",
	Battle.State.GUARD: &"Shield Guard",
	Battle.State.LOWER: &"Shield Lower",
}
const CLIPS_BY_TYPE := {
	Catalog.HUMAN_INFANTRY: CLIPS,
	Catalog.HUMAN_HEAVY_INFANTRY: HEAVY_CLIPS,
}
const HEAVY_RUN_CLIP_SPEED := 2.2

signal updated

var battle: Battle
var paused := false

var _setup := Setup.new()
var _camera_depth := 25.0
var _models: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _clip_sets: Array[Dictionary] = []
var _markers: Array[MeshInstance3D] = []
var _displayed: Array[int] = []
var _last_display_second := -1
var _last_hits := -1
var _last_blocks := -1
var _last_waiting := -1

@onready var _camera: Camera3D = $Camera3D


func configure(setup: Setup) -> void:
	_setup = setup.copy()


func _ready() -> void:
	battle = Battle.new(8, _setup)
	_size_field()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.36
	marker_mesh.bottom_radius = 0.36
	marker_mesh.height = 0.008
	marker_mesh.radial_segments = 20
	var materials: Array[StandardMaterial3D] = []
	for color: Color in TEAM_COLORS:
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.32)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials.append(material)
	for soldier in battle.soldiers:
		var definition: Dictionary = Catalog.TYPES[soldier.unit_type]
		var model := definition.model.instantiate() as Node3D
		add_child(model)
		_models.append(model)
		var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var clips: Dictionary = CLIPS_BY_TYPE.get(soldier.unit_type, {})
		if player:
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			_set_root_motion(player, _valid_clip(player, clips, Battle.State.ATTACK))
		_players.append(player)
		_clip_sets.append(clips)

		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.material_override = materials[soldier.team]
		marker.position.y = 0.008
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(marker)
		_markers.append(marker)
		_displayed.append(-1)
	_sync_models(0.0)
	_frame_battle(0.0)


func restart() -> void:
	battle = Battle.new(8, _setup)
	paused = false
	_displayed.fill(-1)
	for player in _players:
		if player:
			player.stop()
	_sync_models(0.0)
	_frame_battle(0.0)
	updated.emit()


func _size_field() -> void:
	var field := $Field as MeshInstance3D
	var field_material := field.material_override as ShaderMaterial
	field_material.set_shader_parameter("arena_limit", battle.arena_limit)
	var radius: float = battle.arena_limit.length()
	var ground_size := maxf(100.0, radius * 4.0)
	field.scale = Vector3(ground_size / 100.0, 1.0, ground_size / 100.0)
	# Show neighboring platoons across the screen as formations grow wider.
	_camera.rotation.y *= Battle.ARENA_LIMIT.x / battle.arena_limit.x
	# Include the front and back ranks at this camera angle, even on the widest field.
	var axis := _camera.basis.z.abs()
	var depth := battle.arena_limit.dot(Vector2(axis.x, axis.z)) + axis.y * 2.6
	_camera_depth = maxf(25.0, depth + 12.0)
	_camera.far = maxf(66.0, _camera_depth + ground_size)
	($Key as DirectionalLight3D).directional_shadow_max_distance = _camera_depth + depth + 2.0


func _physics_process(delta: float) -> void:
	if paused:
		return
	battle.step(delta)
	_sync_models(delta)
	_frame_battle(delta)
	var second := floori(battle.elapsed)
	var waiting: int = battle.waiting_count()
	if second != _last_display_second or battle.hits != _last_hits or battle.blocks != _last_blocks or waiting != _last_waiting:
		_last_display_second = second
		_last_hits = battle.hits
		_last_blocks = battle.blocks
		_last_waiting = waiting
		updated.emit()


func _set_root_motion(player: AnimationPlayer, clip: StringName) -> void:
	if clip.is_empty():
		return
	var animation := player.get_animation(clip)
	for track in range(animation.get_track_count()):
		var path := animation.track_get_path(track)
		if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and path.get_concatenated_subnames() == "Root":
			# Let the simulation own translation even when the model has an advancing cut.
			player.root_motion_track = path
			return


func _valid_clip(player: AnimationPlayer, clips: Dictionary, state: Battle.State) -> StringName:
	var clip: StringName = clips.get(state, &"")
	return clip if player and not clip.is_empty() and player.has_animation(clip) else &""


func _sync_models(delta: float) -> void:
	for index in range(_models.size()):
		var soldier := battle.soldiers[index]
		var model := _models[index]
		var player := _players[index]
		var clips := _clip_sets[index]
		model.position = Vector3(soldier.position.x, 0, soldier.position.y)
		model.rotation.y = atan2(soldier.facing.x, soldier.facing.y)
		_markers[index].visible = soldier.unit.is_alive()
		# Only hold a downed pose when the rig actually has a knockdown animation.
		var hold_down := soldier.state == Battle.State.DOWN and not _valid_clip(player, clips, Battle.State.KNOCKDOWN).is_empty()
		if _displayed[index] != soldier.state:
			_displayed[index] = soldier.state
			var clip := _valid_clip(player, clips, soldier.state)
			# Heavy Infantry has no death clip; do not leave a standing corpse on the field.
			model.visible = soldier.state != Battle.State.DEAD or not clip.is_empty()
			if player and not hold_down and model.visible:
				var speed := 1.0
				if clip.is_empty():
					clip = _valid_clip(player, clips, Battle.State.IDLE)
				elif soldier.state == Battle.State.RUN and soldier.unit_type == Catalog.HUMAN_HEAVY_INFANTRY:
					speed = soldier.run_speed / HEAVY_RUN_CLIP_SPEED
				elif Battle.DURATIONS.has(soldier.state):
					speed = player.get_animation(clip).length / Battle.DURATIONS[soldier.state]
				if clip.is_empty():
					player.stop()
				else:
					player.play(clip, 0.075 if delta > 0.0 else 0.0, speed)
		if player and model.visible and not hold_down:
			# The attack is chosen at the end of the simulation step, with its clock still at zero.
			var attack_just_started := soldier.state == Battle.State.ATTACK and soldier.time == 0.0
			player.advance(0.0 if attack_just_started else delta)


func _frame_battle(delta: float) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for soldier in battle.soldiers:
		if not soldier.unit.is_alive() and soldier.time >= Battle.DURATIONS[Battle.State.DEAD]:
			continue
		var ground := Vector3(soldier.position.x, 0.0, soldier.position.y)
		var projected := Vector2(ground.dot(_camera.basis.x), ground.dot(_camera.basis.y))
		var height := 2.60 if soldier.state == Battle.State.CHEER else 1.95
		low = low.min(projected)
		high = high.max(projected + Vector2(0.0, height * _camera.basis.y.y))
	if not low.is_finite():
		return
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var span := high - low
	var width := maxf(11.0, maxf(span.x + 3.3, (span.y + 1.05) * aspect))
	var center := (low + high) * 0.5
	var position_goal := _camera.basis * Vector3(center.x, center.y, _camera_depth)
	var weight := 1.0 - exp(-3.5 * delta) if delta > 0.0 else 1.0
	_camera.position = _camera.position.lerp(position_goal, weight)
	_camera.size = lerpf(_camera.size, width, weight)
