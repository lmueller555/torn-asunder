class_name UnitModelStudio
extends Node3D

var animation_player: AnimationPlayer
var _unit: Node
var _headroom := 0.0
var _face_view := false

@onready var _pivot: Node3D = $Model
@onready var _camera: Camera3D = $Camera3D
@onready var _wide_transform := _camera.transform
@onready var _wide_size := _camera.size


func set_unit_model(model: PackedScene) -> void:
	if is_instance_valid(_unit):
		_pivot.remove_child(_unit)
		_unit.queue_free()
	_unit = model.instantiate()
	_pivot.add_child(_unit)
	var players := _unit.find_children("*", "AnimationPlayer", true, false)
	animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	set_preview_headroom(0.0)


func set_preview_headroom(height: float) -> void:
	_headroom = height
	if not _face_view:
		_frame_body()


func show_body(angle: float) -> void:
	_face_view = false
	_pivot.rotation_degrees.y = angle
	_frame_body()


func _frame_body() -> void:
	_camera.transform = _wide_transform
	_camera.position.y += _headroom * 0.5
	_camera.size = _wide_size + _headroom


func show_face() -> void:
	_face_view = true
	_pivot.rotation_degrees.y = 12.0
	_camera.position = Vector3(0, 1.651, 4.0)
	_camera.rotation = Vector3.ZERO
	_camera.size = 0.46
