extends Node3D
## Static map inspection. Markers do not stand in for evidence of who spoke.

const TITLES := [
	"RIVER CUT OVERVIEW  /  410 × 248 m",
	"VILLAGE AND RECORD ROOM  /  132 m sector",
	"CEMETERY STAIR  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroCut]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, -1, 0))
	$CommandSector.look_at(Vector3(-12, 0, 6))
	$HeroCut.look_at(Vector3(-82.3, -1.2, 45))
	_figure(Vector3(-83, -5, 66), Color(0.46, 0.59, 0.74))
	_figure(Vector3(-78, 0, 27.5), Color(0.65, 0.66, 0.48))
	for i in range(6):
		var row := floori(i / 3.0)
		_figure(Vector3(-19 + (i % 3) * 2.35, 0, -15 + row * 1.7), Color(0.40, 0.58, 0.72))
		_figure(Vector3(104 + (i % 3) * 2.35, 0, -15 + row * 1.7), Color(0.66, 0.39, 0.27))
	var args := OS.get_cmdline_user_args()
	_set_view(2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "STILL KINGDOM CUT  ·  " + TITLES[view] + "\n[1] Cut   [2] Command sector   [3] Hero stair  |  Static graybox, not a mission"


func _figure(point: Vector3, color: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.40
	body.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var item := MeshInstance3D.new()
	item.mesh = body
	item.material_override = material
	item.position = point + Vector3.UP * 0.90
	add_child(item)
