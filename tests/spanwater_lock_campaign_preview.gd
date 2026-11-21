extends Node3D
## Static terrain inspection. These cameras don't change any battle controller.

const TITLES := [
	"LOCK BASIN OVERVIEW  /  360 × 240 m",
	"LOCK COMMAND SECTOR  /  132 m tall",
	"SPILLWAY APPROACH  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroDeck]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, 0, 0))
	$CommandSector.look_at(Vector3(-17, 3, -12))
	$HeroDeck.look_at(Vector3(-33, 5.5, -13))
	_unit(Vector3(-43, 5, -28), Color(0.25, 0.55, 0.76))
	for i in range(6):
		var row := floori(i / 3.0)
		_unit(Vector3(-46 + (i % 3) * 2.15, 5, -39 - row * 2.0), Color(0.37, 0.58, 0.79))
		_unit(Vector3(-3 + (i % 3) * 2.15, 5, -37 - row * 2.0), Color(0.70, 0.39, 0.22))
	var args := OS.get_cmdline_user_args()
	_set_view(2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "SPANWATER LOCK  ·  " + TITLES[view] + "\n[1] Basin   [2] Command sector   [3] Hero deck  |  Static graybox, not a mission"


func _unit(at: Vector3, color: Color) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.40
	capsule.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var mark := MeshInstance3D.new()
	mark.mesh = capsule
	mark.material_override = material
	mark.position = at + Vector3.UP * 0.9
	add_child(mark)
