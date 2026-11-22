extends RefCounted
## Typed resource contract for the released/remapped player. Exact bytes
## of these five source files are separately verified before export.
const ROOT := "res://game/overworld/cairnspine/"
const TERRAIN_SCRIPT := ROOT+"pass_relief.gd"
const RELIEF_SCRIPT := ROOT+"sova_assembly_relief.gd"
const COURT_SCRIPT := ROOT+"sova_assembly_court.gd"
const GROUND_SHADER := ROOT+"pass_ground.gdshader"
const COURT_SHADER := ROOT+"sova_assembly_stone.gdshader"
const SCRIPTS := [TERRAIN_SCRIPT, RELIEF_SCRIPT, COURT_SCRIPT]
const SHADERS := [GROUND_SHADER, COURT_SHADER]

static func _packed_script(path: String) -> GDScript:
	if not ResourceLoader.exists(path):
		return null
	var value := ResourceLoader.load(path) as GDScript
	return value if value and value.can_instantiate() else null

static func _spatial_shader(path: String) -> Shader:
	if not ResourceLoader.exists(path):
		return null
	var value := ResourceLoader.load(path) as Shader
	return value if value and value.get_mode()==Shader.MODE_SPATIAL else null

static func available() -> bool:
	# Canonical res:// requests resolve through the pack's own remap table.
	# Do not hash source text or depend on the editor's .godot import cache.
	var terrain := _packed_script(TERRAIN_SCRIPT)
	var relief := _packed_script(RELIEF_SCRIPT)
	var court := _packed_script(COURT_SCRIPT)
	if not terrain or not relief or not court:
		return false
	for path: String in SHADERS:
		if not _spatial_shader(path):
			return false
	return relief.get_base_script()==terrain and terrain.get_instance_base_type()==&"Node3D" \
		and court.get_instance_base_type()==&"RefCounted"

static func mounted(relief: Node3D,ground: MeshInstance3D) -> bool:
	if not is_instance_valid(relief) or not is_instance_valid(ground) or not ground.mesh:
		return false
	var ground_material := ground.material_override as ShaderMaterial
	if not ground_material or ground_material.shader!=ResourceLoader.load(GROUND_SHADER,"Shader"):
		return false
	if relief.has_node("ForecourtAndClosedVault") or relief.has_node("WitnessTerrace"):
		return false
	var anchors := relief.get_node_or_null("SurveyAnchors")
	if not anchors or anchors.get_child_count()!=3:
		return false
	for id in ["ValleyApproach","Assembly","SafeStaging"]:
		if not anchors.get_node_or_null(id) is Marker3D:
			return false
	var court := relief.get_node_or_null("OpenAssemblyCourt") as MeshInstance3D
	if not court or not court.mesh or court.mesh.get_surface_count()!=1:
		return false
	var material := court.mesh.surface_get_material(0) as ShaderMaterial
	var contacts: Variant = court.get_meta(&"court_footing",PackedVector3Array())
	return material!=null and material.shader==ResourceLoader.load(COURT_SHADER,"Shader") \
		and contacts is PackedVector3Array and contacts.size()>=180 \
		and court.find_children("*","CollisionObject3D",true,false).is_empty()
