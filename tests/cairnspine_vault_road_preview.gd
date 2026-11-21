extends Node3D
## Static map inspection, not a mission or replacement for the live command camera.

const TITLES := [
	"PASS OVERVIEW  /  340 × 250 m",
	"FORECOURT SECTOR  /  132 m tall",
	"OUTER SHELF  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroShelf]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, 1, 0))
	$CommandSector.look_at(Vector3(80, 8, 15))
	$HeroShelf.look_at(Vector3(67, 13.0, -18.1))
	_unit(Vector3(24, 12, -18.0), Color(0.27, 0.58, 0.76))
	for i in range(6):
		var row := floori(i / 3.0)
		_unit(Vector3(48 + (i % 3) * 2.35, 12, -18.7 + row * 1.7), Color(0.37, 0.60, 0.80))
		_unit(Vector3(15 + (i % 3) * 2.35, 8, 60 + row * 2.4), Color(0.44, 0.71, 0.49))
		_unit(Vector3(91 + (i % 3) * 2.35, 12, -35 - row * 1.8), Color(0.70, 0.39, 0.22))
	var args := OS.get_cmdline_user_args()
	_set_view(2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "CAIRNSPINE VAULT ROAD  ·  " + TITLES[view] + "\n[1] Pass   [2] Command sector   [3] Hero shelf  |  Static graybox, not a mission"


func _unit(at: Vector3, color: Color) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.40
	capsule.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var figure := MeshInstance3D.new()
	figure.mesh = capsule
	figure.material_override = material
	figure.position = at + Vector3.UP * 0.9
	add_child(figure)
