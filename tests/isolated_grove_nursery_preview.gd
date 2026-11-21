extends Node3D
## Static inspection cameras with a scale-only trunk and root-ball sled.

const TITLES := [
	"GROVE OVERVIEW  /  320 × 220 m",
	"ROAD AND LOW TRACK  /  136 m sector",
	"LOADING YARD  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroYard]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, 0, 0))
	$CommandSector.look_at(Vector3(-32, 0, 22))
	$HeroYard.look_at(Vector3(-96, 5.1, 10))
	_figure(Vector3(-118.9, 3, 11.5), Color(0.34, 0.61, 0.71))
	_sled(Vector3(-104, 3, 7.8))
	for i in range(6):
		var row := floori(i / 3.0)
		_figure(Vector3(-84 + (i % 3) * 2.3, 3, 7 + row * 1.7), Color(0.34, 0.61, 0.71))
		_figure(Vector3(17 + (i % 3) * 2.4, -2.5, 70 + row * 1.7), Color(0.67, 0.38, 0.24))
	var args := OS.get_cmdline_user_args()
	_set_view(2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "ISOLATED GROVE AND NURSERY  ·  " + TITLES[view] + "\n[1] Grove   [2] Command sector   [3] Hero yard  |  Static graybox, not a mission"


func _sled(point: Vector3) -> void:
	var base := BoxMesh.new()
	base.size = Vector3(7.5, 0.75, 4.8)
	_prop(base, point + Vector3.UP * 0.38, Color(0.58, 0.39, 0.21))
	var ball := SphereMesh.new()
	ball.radius = 1.75
	ball.height = 2.6
	ball.radial_segments = 10
	_prop(ball, point + Vector3.UP * 1.85, Color(0.31, 0.22, 0.14))
	var trunk := BoxMesh.new()
	trunk.size = Vector3(0.64, 4.4, 0.65)
	_prop(trunk, point + Vector3.UP * 4.5, Color(0.48, 0.32, 0.17))
	var crown := CylinderMesh.new()
	crown.top_radius = 1.24
	crown.bottom_radius = 2.4
	crown.height = 2.2
	crown.radial_segments = 7
	_prop(crown, point + Vector3.UP * 6.2, Color(0.42, 0.54, 0.29))


func _figure(point: Vector3, color: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.40
	body.height = 1.8
	_prop(body, point + Vector3.UP * 0.90, color)


func _prop(body: Mesh, point: Vector3, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var item := MeshInstance3D.new()
	item.mesh = body
	item.material_override = material
	item.position = point
	add_child(item)
