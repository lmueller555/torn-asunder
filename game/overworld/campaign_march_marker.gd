extends Node3D
## Map-scale formation of five articulated infantry silhouettes. Not a battle asset.
## Authored stationary party art stays mounted; this appears only while marching.
var _ranks: Array[Node3D] = []
var _phase := 0.0


func build(campaign_id: String) -> void:
	var pigment: Color = {
		"mara": Color("#985144"), "ilyra": Color("#447e70"),
		"neris": Color("#a2a356"), "sereth": Color("#686995"),
		"sova": Color("#647b90"), "raska": Color("#925b71"),
	}.get(campaign_id, Color("#9a8150"))
	var cloth := _material(pigment.lightened(0.14), 0.8)
	var textile := _material(pigment.darkened(0.35), 0.89)
	var metal := _material(Color("#858a81"), 0.49)
	var edge := _material(Color("#c2b49a"), 0.47)
	var leather := _material(Color("#383831"), 0.94)
	var face := _material(Color("#9f836a"), 0.9)
	for spot in [Vector2(0.0,-3.8), Vector2(-2.9,-0.6), Vector2(2.9,-0.6),
			Vector2(-1.8,3.1), Vector2(1.8,3.1)]:
		var figure := Node3D.new()
		figure.position = Vector3(spot.x, 0.0, spot.y)
		add_child(figure)
		_ranks.append(figure)
		_solid(figure, Vector3(0, 2.54, 0), Vector3(1.87, 2.55, 1.29), textile)
		_solid(figure, Vector3(0, 3.7, 0.08), Vector3(2.18, 0.70, 1.43), metal)
		_solid(figure, Vector3(0, 4.21, -0.15), Vector3(0.77, 0.79, 0.77), face)
		var helm := SphereMesh.new()
		helm.radius = 0.55
		helm.height = 0.88
		helm.radial_segments = 10
		helm.rings = 5
		_part(figure, Vector3(0.0, 4.67, -0.02), helm, metal)
		_solid(figure, Vector3(0, 4.5, -0.23), Vector3(1.04, 0.16, 0.96), edge)
		var shield := CylinderMesh.new()
		shield.top_radius = 0.78
		shield.bottom_radius = 0.78
		shield.height = 0.24
		shield.radial_segments = 9
		var buckler := _part(figure, Vector3(-0.78, 2.63, -0.81), shield, cloth)
		buckler.rotation.x = PI * 0.5
		_solid(figure, Vector3(-0.78, 2.64, -0.95), Vector3(0.26, 0.47, 0.13), edge)
		var spear := _solid(figure, Vector3(0.92, 3.15, -0.59), Vector3(0.13, 5.1, 0.14), leather)
		spear.rotation.x = 0.14
		var point := _solid(figure, Vector3(0.92, 5.77, -0.23), Vector3(0.25, 0.53, 0.23), edge)
		point.rotation.x = 0.14
		_solid(figure, Vector3(-0.49, 0.82, 0), Vector3(0.68, 1.64, 0.78), leather, "Left")
		_solid(figure, Vector3(0.49, 0.82, 0), Vector3(0.68, 1.64, 0.78), leather, "Right")
	_solid(self, Vector3(0.2, 5.05, -3.85), Vector3(0.22, 7.7, 0.22), leather)
	_solid(self, Vector3(0.2, 8.95, -3.85), Vector3(0.43, 0.36, 0.43), edge)
	# The cloth crosses both screen axes, so it reads from either road heading.
	var banner := _solid(self, Vector3(0.94, 7.54, -2.89), Vector3(0.17, 1.94, 2.88), cloth)
	banner.rotation.y = 0.63
	var hem := _solid(self, Vector3(0.94, 6.61, -2.89), Vector3(0.20, 0.18, 2.88), textile)
	hem.rotation.y = banner.rotation.y
	for spot in [Vector3(1.17,7.55,-2.6), Vector3(0.74,7.55,-3.19)]:
		var stripe := _solid(self, spot, Vector3(0.23, 0.85, 0.18), edge)
		stripe.rotation.y = banner.rotation.y


func step(delta: float) -> void:
	_phase += delta * TAU * 3.1
	for i in _ranks.size():
		var stride := sin(_phase + i * 1.91)
		_ranks[i].get_node("Left").position.z = stride * 0.66
		_ranks[i].get_node("Right").position.z = -stride * 0.66
		_ranks[i].position.y = absf(stride) * 0.15


func _material(tint: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	return material


func _solid(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material, part_name := "") -> MeshInstance3D:
	var volume := BoxMesh.new()
	volume.size = dimensions
	var part := _part(parent, at, volume, surface)
	if not part_name.is_empty():
		part.name = part_name
	return part


func _part(parent: Node3D, at: Vector3, geometry: Mesh, surface: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = geometry
	part.material_override = surface
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = at
	parent.add_child(part)
	return part
