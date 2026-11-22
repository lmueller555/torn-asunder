extends RefCounted
# Optional authored pack; this is not a profile authority.
const FLAG:="torn_asunder/neris_3d_overworld"
const PRESENTER:="res://game/overworld/neris/normal_presenter.gd"
const ROOT:="res://assets/overworld/marches/"
const REQUIRED:={
	"PackedScene":[
		"res://game/overworld/neris/grove_relief.tscn",
		"res://game/overworld/neris/cairnspine_relief.tscn",
		"res://game/overworld/neris/neris_greyhollow_sector.tscn",
		ROOT+"marches-corridor.glb",
		ROOT+"greyhollow-mine.glb",
		ROOT+"marches-copse-near.glb"
	],
	"Texture2D":[ROOT+"detail/marches-surface-detail.png"],
	"Shader":[ROOT+"detail/marches_surface.gdshader"]
}
static func requested()->bool:
	var value:Variant=ProjectSettings.get_setting(FLAG,false)
	return value is bool and value

static func open_presenter(host:Control)->RefCounted:
	for kind:String in REQUIRED:
		for path:String in REQUIRED[kind]:
			if not ResourceLoader.exists(path,kind):
				return null
	var implementation:=load(PRESENTER) as Script
	return implementation.new(host) if implementation and implementation.can_instantiate() else null
