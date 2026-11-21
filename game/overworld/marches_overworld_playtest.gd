extends SceneTree
## Development entry point. Uses an isolated profile, never the game profile.
const TitleScene := preload("res://game/overworld/mara_sector_playtest_title.tscn")
const Title := preload("res://game/overworld/mara_sector_title.gd")
const Profile := preload("res://game/profile_store.gd")


func _initialize() -> void:
	_open_title.call_deferred()


func _open_title() -> void:
	if not OS.is_debug_build():
		push_error("The Marches overworld playtest requires a Godot debug build.")
		quit(1)
		return
	var title := TitleScene.instantiate() as Title
	title._profile = Profile.new("user://marches_overworld_playtest.cfg")
	root.title = "Torn Asunder | Mara 3D Overworld Playtest"
	title.install_overworld_playtest()
	root.add_child(title)
