extends Node3D

const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

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
}

signal updated

var battle := Battle.new()
var paused := false

var _models: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _markers: Array[MeshInstance3D] = []
var _displayed: Array[int] = []
var _last_display_second := -1
var _last_hits := -1
var _last_blocks := -1
var _last_waiting := -1

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	var definition: Dictionary = Catalog.TYPES[Catalog.HUMAN_INFANTRY]
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
		var model := definition.model.instantiate() as Node3D
		add_child(model)
		_models.append(model)
		var player := model.get_node("AnimationPlayer") as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var slash := player.get_animation(CLIPS[Battle.State.ATTACK])
		for track in range(slash.get_track_count()):
			var path := slash.track_get_path(track)
			if slash.track_get_type(track) == Animation.TYPE_POSITION_3D and path.get_concatenated_subnames() == "Root":
				# Let the simulation own movement and keep the embedded animation poses in place.
				player.root_motion_track = path
				break
		_players.append(player)

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
	battle = Battle.new()
	paused = false
	_displayed.fill(-1)
	for player in _players:
		player.stop()
	_sync_models(0.0)
	_frame_battle(0.0)
	updated.emit()


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


func _sync_models(delta: float) -> void:
	for index in range(_models.size()):
		var soldier := battle.soldiers[index]
		var model := _models[index]
		var player := _players[index]
		model.position = Vector3(soldier.position.x, 0, soldier.position.y)
		model.rotation.y = atan2(soldier.facing.x, soldier.facing.y)
		_markers[index].visible = soldier.unit.is_alive()
		if _displayed[index] != soldier.state:
			_displayed[index] = soldier.state
			if soldier.state != Battle.State.DOWN:
				var clip: StringName = CLIPS[soldier.state]
				var speed := 1.0
				if Battle.DURATIONS.has(soldier.state):
					speed = player.get_animation(clip).length / Battle.DURATIONS[soldier.state]
				player.play(clip, 0.075 if delta > 0.0 else 0.0, speed)
		if soldier.state != Battle.State.DOWN:
			player.advance(delta)


func _frame_battle(delta: float) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for soldier in battle.soldiers:
		if not soldier.unit.is_alive() and soldier.time >= Battle.DURATIONS[Battle.State.DEAD]:
			continue
		var ground := Vector3(soldier.position.x, 0.0, soldier.position.y)
		var projected := Vector2(ground.dot(_camera.basis.x), ground.dot(_camera.basis.y))
		low = low.min(projected)
		high = high.max(projected + Vector2(0.0, 1.95 * _camera.basis.y.y))
	if not low.is_finite():
		return
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var span := high - low
	var width := maxf(11.0, maxf(span.x + 3.3, (span.y + 1.05) * aspect))
	var center := (low + high) * 0.5
	var position_goal := _camera.basis * Vector3(center.x, center.y, 25.0)
	var weight := 1.0 - exp(-3.5 * delta) if delta > 0.0 else 1.0
	_camera.position = _camera.position.lerp(position_goal, weight)
	_camera.size = lerpf(_camera.size, width, weight)
