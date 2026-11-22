extends RefCounted
## Default-off optional normal title entry. Never imports private renderer on opt-out.
const SWITCH:="torn_asunder/raska_3d_overworld"
const FACTORY:="res://game/overworld/raska/raska_shared.gd"
const FALLBACK_MESSAGE:="Raska's 3D map could not be loaded. Using the campaign chart."
const SCENES:=[
	"res://game/overworld/raska/basin_camp.tscn",
	"res://game/overworld/raska/greyhollow_context.tscn",
	"res://game/overworld/raska/well_road.tscn",
	"res://game/overworld/raska/spanwater_north.tscn",
	"res://assets/overworld/marches/marches-corridor.glb",
	"res://assets/overworld/marches/greyhollow-mine.glb",
	"res://assets/overworld/marches/marches-copse-near.glb"]

static func requested()->bool:
	var value:Variant=ProjectSettings.get_setting(SWITCH,false)
	return value is bool and value

static func open_map(world:RefCounted,profile:RefCounted)->Control:
	for scene in SCENES:
		if not ResourceLoader.exists(scene,"PackedScene"): return null
	if not ResourceLoader.exists(FACTORY,"GDScript"): return null
	var program:=load(FACTORY) as GDScript
	if not program or not program.can_instantiate(): return null
	var map:=program.new() as Control
	if not map: return null
	if not map.build_for_raska(world,profile):
		map.free()
		return null
	return map
