extends SceneTree
const Gate:=preload("res://game/overworld/sereth_neutral_contract.gd")
const Scene:=preload("res://game/overworld/sereth/sereth_y5_renderer.tscn")
const World:=preload("res://game/campaign_world.gd")
const View:=preload("res://game/overworld/sereth/sereth_y5_view.gd")
const ExportTest:=preload("res://tests/native_sereth_release_smoke.gd")
var count:=0
var fails:=0

func _initialize()->void:
	run.call_deferred()

func check(valid:bool,label:String)->void:
	count+=1
	if not valid:
		fails+=1
		push_error(label)

func run()->void:
	var script:=ExportTest as GDScript
	check(script.can_instantiate() and not ProjectSettings.has_setting("autoload/NativeSerethSmoke"),
		"nondebug test compiles and has no stock autoload")
	check(Gate.available(),"exact typed neutral source resources")
	check(Gate._packed_script("res://absent/export-script.gd")==null
		and Gate._spatial_shader("res://absent/export-pigment.gdshader")==null,"absent remap fails closed")
	check(Gate._packed_script(Gate.GROUND_SHADER)==null and Gate._spatial_shader(Gate.RELIEF_SCRIPT)==null,
		"incorrect typed resource at an available path fails closed")
	var area:=Scene.instantiate()
	root.add_child(area)
	for i in 3:
		await physics_frame
	check(area.arrival_verified(),"court assets and arrival physically ready")
	var court:=area.relief.get_node("OpenAssemblyCourt") as MeshInstance3D
	var terrain:=area.bank.material_override as ShaderMaterial
	var original:=terrain.shader
	terrain.shader=Shader.new()
	check(not area.arrival_verified(),"wrong ground material prevents native arrival")
	terrain.shader=original
	var m:=court.mesh.surface_get_material(0) as ShaderMaterial
	var original_court:=m.shader
	m.shader=original
	check(not area.arrival_verified(),"wrong court shader prevents native arrival")
	m.shader=original_court
	var illegal:=Node3D.new()
	illegal.name="ForecourtAndClosedVault"
	area.relief.add_child(illegal)
	check(not area.arrival_verified(),"vault geometry disqualifies Sereth assembly")
	illegal.free()
	var view:=View.new()
	check(view.build(),"compiled shared view contract mounts")
	var sereth:=World.new("sereth","cairnspine_assembly",PackedStringArray(["sereth_voices_at_the_cut","sereth_pass_writ"]))
	var sova:=World.new("sova","cairnspine_assembly",PackedStringArray(["sova_mine_tunnels"]))
	check(view.can_present(sereth) and not view.can_present(sova),"actual No Proxy phase admitted, same Sova station rejected")
	view.free()
	print("Sereth compiled-resource contract source surrogate: %d/%d."%[count-fails,count])
	quit(0 if not fails else 1)
