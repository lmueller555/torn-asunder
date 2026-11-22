extends RefCounted
## Keep Ilyra dependency resolution outside the always-loaded Mara host.
const SWITCH := "torn_asunder/ilyra_3d_overworld"
const PRESENTER := "res://game/overworld/ilyra_normal_presenter.gd"
const REQUIRED := {
	"PackedScene": ["res://game/overworld/moonwash/ilyra_opener_renderer.tscn",
		"res://game/overworld/spanwater/ilyra_spanwater_renderer.tscn",
		"res://game/overworld/spanwater/spanwater_relief.tscn",
		"res://assets/overworld/moonwash/moonwash-coast.glb",
		"res://assets/overworld/moonwash/moonwash-harbor-near.scn",
		"res://assets/overworld/moonwash/moonwash-harbor-regional.glb",
		"res://assets/overworld/moonwash/moonwash-shoulder-returns.glb"],
	"Resource": ["res://assets/overworld/moonwash/moonwash-sector-data.tres"],
}


static func requested() -> bool:
	var enabled: Variant = ProjectSettings.get_setting(SWITCH, false)
	return enabled is bool and enabled


static func open_presenter(host: Control) -> RefCounted:
	for type: String in REQUIRED:
		for path: String in REQUIRED[type]:
			if not ResourceLoader.exists(path, type):
				return null
	if not ResourceLoader.exists(PRESENTER, "GDScript"):
		return null
	var factory := load(PRESENTER) as GDScript
	if not factory or not factory.can_instantiate():
		return null
	return factory.new(host) as RefCounted
