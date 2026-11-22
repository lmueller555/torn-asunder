extends Node
## Added as an autoload only in the disposable native release CI checkout.
## The normal project main scene and the real ProfileStore own all actions.
const Title := preload("res://game/title_screen.gd")
const Overworld := preload("res://game/campaign_overworld_3d.gd")
const Profile := preload("res://game/profile_store.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const MARA := "mara"

var _title: Title
var _mode := ""
var _failures := 0


func _ready() -> void:
	_mode = OS.get_environment("TORN_RELEASE_SMOKE_MODE")
	if not _mode.is_empty():
		_run.call_deferred()


func _run() -> void:
	_check(not OS.is_debug_build() and not OS.has_feature("editor"), "real nondebug release executable")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/title_screen.tscn",
		"default project scene, not a debug launcher")
	_check(FileAccess.file_exists("res://assets/overworld/marches/anchors.json")
		and FileAccess.file_exists("res://assets/overworld/marches/camp/spur.json"), "both authored data files in package")
	_check(ResourceLoader.exists("res://game/overworld/moonwash/coast_renderer.tscn", "PackedScene")
		and ResourceLoader.exists("res://assets/overworld/moonwash/moonwash-sector-data.tres", "Resource"),
		"native Moonwash dependencies in package")
	await get_tree().process_frame
	await get_tree().process_frame
	for frame in range(120):
		_title = get_tree().current_scene as Title
		if _title and _title._page == Title.Page.TITLE and is_instance_valid(_title._stage):
			break
		await get_tree().process_frame
	if not _check(_title != null and _button("New Game") != null, "real title opened"):
		_finish()
		return
	if _mode == "continue":
		_check(_press("Continue"), "normal Continue clicked")
		await get_tree().process_frame
		_check(_title._active_campaign.get("id") == MARA and _at(MINE), "Continue reconstructed authored 3D Mine anchor")
		_check(Profile.new().completed_missions(MARA).is_empty(), "no unearned victory after reopening")
		_check(DisplayServer.get_name() != "headless", "Continue ran with a real renderer")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var view := _map()
			if view:
				var texture := view.render_viewport.get_texture()
				var capture := texture.get_image()
				_check(capture != null and not capture.is_empty(), "3D viewport rendered actual pixels")
		_finish()
		return
	if not _check(_mode == "new" and _press("New Game"), "normal New Game clicked"):
		_finish()
		return
	var hero := _title._stage.get_node_or_null(MARA) as Button
	if hero:
		hero.grab_focus()
	_check(hero != null and _title._portraits[_title._selected] == hero and _press("Begin Campaign"),
		"choose the normal Human campaign")
	await get_tree().process_frame
	if not _check(_at(CAMP), "ordinary New Game opened real 3D Marches Camp"):
		_finish()
		return
	var view := _map()
	_check(view._renderer.find_child("MarchesGround", true, false) is MeshInstance3D and view._party.is_visible_in_tree(),
		"live package mounted terrain and party")
	_check(view.select_waypoint(MINE), "normal first destination selectable")
	view.confirm_button.pressed.emit()
	var travel_timeout := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < travel_timeout and not _at(MINE):
		await get_tree().process_frame
	if not _check(_at(MINE), "native confirmed movement reached Greyhollow"):
		var current := _map()
		if current:
			printerr("Travel debug: site ", current._world.current_waypoint_id(),
				", travelling ", current._navigation.is_travelling(),
				", party ", current._party.position, ", camera current ", current._camera.is_current())
		_finish()
		return
	_check(Profile.new().load_campaign_world(MARA).current_waypoint_id() == MINE, "arrival durably saved")
	var arrived := _map()
	arrived.confirm_button.pressed.emit()
	_check(_title._page == Title.Page.MISSION_BRIEFING and _title._campaign_battle == null,
		"separate native mission confirmation")
	_check(_press("Confirm Deployment") and _title._campaign_battle != null, "normal Greyhollow mission deployed")
	await get_tree().process_frame
	_title._return_from_campaign_battle()
	await get_tree().process_frame
	_check(_at(MINE) and Profile.new().completed_missions(MARA).is_empty(),
		"return from actual deployment preserves the anchor without a win")
	_finish()


func _map() -> Overworld:
	if _title._stage.get_child_count() == 0:
		return null
	return _title._stage.get_child(0) as Overworld


func _at(id: String) -> bool:
	var view := _map()
	return view != null and view._world != null and view._world.current_waypoint_id() == id \
		and view._camera != null and view._camera.is_current() and view._party != null and view._points.has(id) \
		and view._party.position.distance_to(view._points[id]) < 0.04


func _button(label: String) -> Button:
	for child in _title._stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == label and not button.disabled:
			return button
	return null


func _press(label: String) -> bool:
	var button := _button(label)
	if not button:
		return false
	button.pressed.emit()
	return true


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		printerr("Native Mara smoke: ", detail)
		_failures += 1
	return ok


func _finish() -> void:
	print("Native Mara release smoke (%s): %s" % [_mode, "PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(0 if _failures == 0 else 1)
