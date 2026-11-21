extends RefCounted
## Optional Crossing material study. No altered vertices, UVs, owners, route samples, or gameplay state.
static func mount(crossing: Node3D, water_shader: Shader, restored_tributary: Texture2D) -> Dictionary:
	if not is_instance_valid(crossing) or not is_instance_valid(water_shader) or not is_instance_valid(restored_tributary):
		return {"error":"Crossing look inputs missing."}
	var water:=crossing.find_child("CrossingRiver",true,false) as MeshInstance3D
	var bridge_structure:=crossing.find_child("NorthernBridgeStructure",true,false) as MeshInstance3D
	var bridge_planks:=crossing.find_child("NorthernBridgePlanks",true,false) as MeshInstance3D
	if not water or not bridge_structure or not bridge_planks:
		return {"error":"Expected locked Crossing mesh nodes."}
	var original:=water.get_active_material(0) as StandardMaterial3D
	if not original or not original.albedo_texture:
		return {"error":"Expected original water pigment."}
	var changed: Dictionary = {}
	var timber_overrides: Dictionary = {}
	for part in [bridge_structure,bridge_planks]:
		var source:=part.get_active_material(0) as StandardMaterial3D
		if not source or part.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]==null:
			return {"error":"Expected locked original corner colors on bridge."}
		var instance:=source.duplicate() as StandardMaterial3D
		instance.vertex_color_use_as_albedo=true
		instance.vertex_color_is_srgb=false
		instance.albedo_color=Color(1.28,1.32,1.27,1.0)
		timber_overrides[part]=instance
	for part in [water,bridge_structure,bridge_planks]:
		changed[part]=part.get_surface_override_material(0)
	var new_water:=ShaderMaterial.new()
	new_water.shader=water_shader
	new_water.set_shader_parameter("original_water",original.albedo_texture)
	new_water.set_shader_parameter("tributary_water",restored_tributary)
	water.set_surface_override_material(0,new_water)
	for part in timber_overrides:
		part.set_surface_override_material(0,timber_overrides[part])
	return {"previous":changed}

static func unmount(receipt: Dictionary) -> void:
	for part in receipt.get("previous",{}):
		if is_instance_valid(part):
			part.set_surface_override_material(0,receipt.previous[part])
