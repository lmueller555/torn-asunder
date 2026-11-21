extends Node3D
## Static camera comparison. The figures and cart sizes are graybox references.

const TITLES := [
	"BASIN OVERVIEW  /  340 × 240 m",
	"ROAD, WASH AND RESERVE  /  132 m sector",
	"ARCHER SHOULDER  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroShoulder]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, -1, 0))
	$CommandSector.look_at(Vector3(54, 0, 21))
	$HeroShoulder.look_at(Vector3(105, -0.5, 42))
	_figure(Vector3(84, 3.5, 23.9), Color(0.25, 0.55, 0.76))
	for i in range(6):
		var row := floori(i / 3.0)
		_figure(Vector3(53 + (i % 3) * 2.3, 0, -12 + row * 2.3), Color(0.37, 0.58, 0.79))
		_figure(Vector3(61 + (i % 3) * 2.3, 0, -39 - row * 2.3), Color(0.70, 0.39, 0.22))
	for i in range(3):
		_figure(Vector3(110 + (i - 1) * 1.9, -4, 43), Color(0.63, 0.70, 0.42))
	_cart(Vector3(-44, 0, -13), Color(0.76, 0.61, 0.39))
	_cart(Vector3(82, -4, 52.5), Color(0.76, 0.61, 0.39))
	var args := OS.get_cmdline_user_args()
	_set_view(2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "RED BASIN WELL ROAD  ·  " + TITLES[view] + "\n[1] Basin   [2] Command sector   [3] Hero shoulder  |  Static graybox, not a mission"


func _cart(point: Vector3, color: Color) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(4.6, 1.5, 2.6)
	_prop(body, point + Vector3.UP * 0.75, color)


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
