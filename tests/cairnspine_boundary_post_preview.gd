extends Node3D
## Static authoring review. Capsules are scale references, never active crews.

const TITLES := [
	"ROAD AND SHEEP TRACK  /  300 × 190 m",
	"LOOKOUT, EMERGENCE AND KEEPER POST  /  105 m command sector",
	"SUNKEN FOOT TRACK  /  65° hero view",
	"HIGH SCOUT BANK  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroTrack, $HeroScout]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, 0, 0))
	$CommandSector.look_at(Vector3(76, -0.5, -2))
	$HeroTrack.look_at(Vector3(4, -2.25, 23))
	$HeroScout.look_at(Vector3(90, 0.75, -7))
	var blue := Color(0.34, 0.55, 0.67)
	var neutral := Color(0.67, 0.63, 0.49)
	var rust := Color(0.70, 0.41, 0.24)
	_figure(Vector3(-14, -4, 23), blue)
	_figure(Vector3(42, 3.1, -36), blue)
	_figure(Vector3(92, 0, -3), rust)
	_figure(Vector3(111.4, 0, 4), neutral)
	for index in range(6):
		var row := floori(index / 3.0)
		_figure(Vector3(61 + (index % 3) * 2.1, 0, -13.4 + row * 2.1), rust)
		_figure(Vector3(-27 + (index % 3) * 2.1, 0, -13.4 + row * 2.1), blue)
	var args := OS.get_cmdline_user_args()
	_set_view(3 if "--scout" in args else 2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "CAIRNSPINE BOUNDARY POST  ·  " + TITLES[view] + "\n[1] Overview [2] Command [3] Track [4] Scout | Static graybox, not a mission"


func _figure(point: Vector3, color: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var item := MeshInstance3D.new()
	item.mesh = body
	item.material_override = material
	item.position = point + Vector3.UP * 0.9
	add_child(item)
