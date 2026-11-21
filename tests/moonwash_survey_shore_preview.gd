extends Node3D
## Marker-only inspection aid. Nothing moves, signals, stops or contests a site here.

const TITLES := [
	"COAST OVERVIEW  /  360 × 244 m",
	"HEADLANDS AND SHOAL  /  128 m command sector",
	"EXPOSED BEACH  /  65° hero view",
	"RAISED SIGNAL  /  65° hero view",
]
@onready var _cameras: Array[Camera3D] = [$Overview, $CommandSector, $HeroBeach, $HeroHeadland]
@onready var _caption: Label = $Legend/Caption


func _ready() -> void:
	$Overview.look_at(Vector3(0, 0, 2))
	$CommandSector.look_at(Vector3(11, 0, 37))
	$HeroBeach.look_at(Vector3(-14, 2.8, 34))
	$HeroHeadland.look_at(Vector3(91, 8, 56))
	_figure(Vector3(-7, 1.2, 9), Color(0.25, 0.53, 0.66))
	_figure(Vector3(79, 7.2, 28), Color(0.25, 0.53, 0.66))
	for i in range(6):
		var row := floori(i / 3.0)
		_figure(Vector3(14 + (i % 3) * 2.0, 1.2, 7.7 + row * 1.75), Color(0.70, 0.35, 0.21))
	_draw_cutter_route()
	_cutter_proxy($BeachCutter, $Shore/Markers/BoatRoute/BeachHold.position, PI * 0.55)
	_cutter_proxy($HighCutter, $Shore/Markers/BoatRoute/HeadlandHold.position, PI * 0.7)
	var args := OS.get_cmdline_user_args()
	_set_view(3 if "--high" in args else 2 if "--hero" in args else 1 if "--command" in args else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		_set_view(key.keycode - KEY_1)


func _set_view(view: int) -> void:
	_cameras[view].make_current()
	_caption.text = "MOONWASH SURVEY SHORE  ·  " + TITLES[view] + "\n[1] Overview  [2] Command  [3] Beach  [4] Headland  |  Preview only: dotted loop, rings at holds"
	$Illustration.visible = view < 2
	$BeachCutter.visible = view == 2
	$HighCutter.visible = view == 3


func _draw_cutter_route() -> void:
	var route: Array[Node] = $Shore/Markers/BoatRoute.get_children()
	var water_ink := _material(Color(0.80, 0.94, 0.90))
	var hold_ink := _material(Color(0.98, 0.68, 0.37))
	for index in route.size():
		var anchor := route[index] as Marker3D
		var next := route[(index + 1) % route.size()] as Marker3D
		var start := anchor.position + Vector3.UP * 0.05
		var finish := next.position + Vector3.UP * 0.05
		var direction := start.direction_to(finish)
		var distance := start.distance_to(finish)
		for offset in range(4, floori(distance - 3.0), 7):
			var dash := BoxMesh.new()
			dash.size = Vector3(0.48, 0.04, 3.9)
			var piece := _illustration(dash, water_ink, start + direction * offset)
			piece.rotation.y = atan2(direction.x, direction.z)
		if anchor.name in [&"BeachHold", &"HeadlandHold"]:
			var ring := TorusMesh.new()
			ring.inner_radius = 2.9
			ring.outer_radius = 3.6
			_illustration(ring, hold_ink, start)


func _illustration(mesh: Mesh, material: Material, point: Vector3) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.position = point
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Illustration.add_child(item)
	return item


func _cutter_proxy(holder: Node3D, point: Vector3, heading: float) -> void:
	# The two hero views illustrate the same cutter at different stopping points.
	holder.position = point
	holder.rotation.y = heading
	var dark := _material(Color(0.29, 0.23, 0.17))
	var canvas := _material(Color(0.81, 0.66, 0.41))
	_preview_block(holder, Vector3(0.0, 0.36, 0.0), Vector3(4.2, 1.05, 11.8), dark)
	_preview_block(holder, Vector3(0.0, 0.96, -1.45), Vector3(3.55, 0.7, 3.2), canvas)
	_preview_block(holder, Vector3(0.0, 3.7, 0.9), Vector3(0.24, 5.85, 0.24), dark)
	_preview_block(holder, Vector3(0.0, 4.45, 0.9), Vector3(3.9, 2.65, 0.14), canvas)


func _preview_block(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> void:
	var block := BoxMesh.new()
	block.size = size
	var item := MeshInstance3D.new()
	item.mesh = block
	item.material_override = material
	item.position = point
	parent.add_child(item)


func _figure(point: Vector3, color: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.8
	var item := MeshInstance3D.new()
	item.mesh = body
	item.material_override = _material(color)
	item.position = point + Vector3.UP * 0.9
	add_child(item)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
