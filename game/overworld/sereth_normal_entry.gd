extends RefCounted
## Lazy and fail-closed. The exact five source bytes are pinned before export.
const Neutral := preload("res://game/overworld/sereth_neutral_contract.gd")
const SWITCH := "torn_asunder/sereth_3d_overworld"
const PRESENTER := "res://game/overworld/sereth/sereth_normal_presenter.gd"
const REQUIRED := {
	"PackedScene": ["res://game/overworld/sereth/cut_relief.tscn",
		"res://game/overworld/sereth/keeper_relief.tscn",
		"res://game/overworld/sereth/sereth_y5_renderer.tscn"],
}

static func requested() -> bool:
	var value: Variant = ProjectSettings.get_setting(SWITCH,false)
	return value is bool and value

static func open_presenter(host: Control) -> RefCounted:
	for kind: String in REQUIRED:
		for path: String in REQUIRED[kind]:
			if not ResourceLoader.exists(path,kind):
				return null
	if not Neutral.available():
		return null
	var script := load(PRESENTER) as GDScript
	return script.new(host) as RefCounted if script and script.can_instantiate() else null
