extends RefCounted
## Keep Sova resources lazy and the owner-facing default off until release QA.
const SWITCH := "torn_asunder/sova_3d_overworld"
const PATH := "res://game/overworld/cairnspine/"
const PRESENTER := PATH+"sova_normal_presenter.gd"
const REQUIRED := [
	PATH+"sova_opener_renderer.tscn", PATH+"sova_assembly_renderer.tscn",
	PATH+"sova_vault_renderer.tscn",
	"res://assets/overworld/marches/marches-corridor.glb",
	"res://assets/overworld/marches/greyhollow-mine.glb",
]

static func requested() -> bool:
	var enable: Variant = ProjectSettings.get_setting(SWITCH,false)
	return enable is bool and enable


static func open_presenter(host: Control) -> RefCounted:
	for scene: String in REQUIRED:
		if not ResourceLoader.exists(scene,"PackedScene"):
			return null
	if not ResourceLoader.exists(PRESENTER,"GDScript"):
		return null
	var script := load(PRESENTER) as GDScript
	if not script or not script.can_instantiate():
		return null
	return script.new(host) as RefCounted
