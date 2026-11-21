extends SceneTree
## Development entry point. Uses an isolated profile, never the game profile.
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Marches := preload("res://game/overworld/marches_overworld_view.gd")
const World := preload("res://game/campaign_world.gd")


func _initialize() -> void:
	_open_title.call_deferred()


func _open_title() -> void:
	if not OS.is_debug_build():
		push_error("The Marches overworld playtest requires a Godot debug build.")
		quit(1)
		return
	var title := TitleScene.instantiate()
	var profile := Profile.new("user://marches_overworld_playtest.cfg")
	title._profile = profile
	root.title = "Torn Asunder | Marches 3D Development Playtest"
	title.set_development_overworld_factory(_make_marches_map)
	root.add_child(title)


func _make_marches_map(world: World) -> Marches:
	if world.campaign_id()!="mara":
		return null
	var map := Marches.new()
	if map.build():
		return map
	map.free()
	return null
