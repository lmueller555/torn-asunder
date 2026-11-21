extends Node3D
## Inspection views only. No input map, campaigns, combat or shared camera changes.

@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroRoad]
@onready var _caption: Label = $Legend/Caption

const TITLES := [
	"VALLEY OVERVIEW  /  360 × 260 m",
	"PASS COMMAND SECTOR  /  116 m viewing height",
	"ROAD CUT  /  65° hero view",
]


func _ready() -> void:
	$Overview.look_at(Vector3(0, 0, 2))
	$CommandSector.look_at(Vector3(91, 0, -15))
	$HeroRoad.look_at(Vector3(65, 1.8, -7))
	_unit(Vector3(45.5, 0, -2.8), Color(0.25, 0.55, 0.76), 0.42)
	for i in range(6):
		_unit(Vector3(59 + (i % 3) * 2.4, 0, -6 + floori(i / 3.0) * 2.3), Color(0.37, 0.58, 0.79), 0.35)
		_unit(Vector3(110 + (i % 3) * 2.4, 0, -20 + floori(i / 3.0) * 2.3), Color(0.70, 0.39, 0.22), 0.35)
	var view := 0
	var args := OS.get_cmdline_user_args()
	if "--command" in args:
		view = 1
	elif "--hero" in args:
		view = 2
	_set_view(view)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "YEAR ONE MINE  ·  " + TITLES[view] + "\n[1] Valley   [2] Command sector   [3] Hero roadway  |  Static graybox, not a mission"


func _unit(position_on_ground: Vector3, color: Color, radius: float) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var marker := MeshInstance3D.new()
	marker.mesh = capsule
	marker.material_override = material
	marker.position = position_on_ground + Vector3.UP * 0.9
	add_child(marker)
