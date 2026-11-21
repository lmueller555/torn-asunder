extends SceneTree

const Title := preload("res://game/title_screen.gd")
const Scene := preload("res://game/title_screen.tscn")
const Map := preload("res://game/overworld/marches_overworld_view.gd")
const Profile := preload("res://game/profile_store.gd")
const World := preload("res://game/campaign_world.gd")
const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const MINE := "mara_mine_escort"
const ROAD := "marches_road"
const CROSS := "marches_crossing"
var title: Title
var profile: Profile
var _path := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_path = OS.get_temp_dir().path_join("torn-crossing-%s-%s.cfg" % [OS.get_process_id(),Time.get_ticks_usec()])
	profile = Profile.new(_path)
	profile.set_setting("reduced_motion", false)
	profile.set_setting("fullscreen", false)
	profile.record_greyhollow_rescue_clear()
	profile.finish_greyhollow_reveal()
	profile.mark_played("mara")
	profile.record_world_waypoint(World.new("mara", ROAD, PackedStringArray([MINE])))
	title = Scene.instantiate()
	title._profile = profile
	title.set_development_overworld_factory(_factory)
	root.add_child(title)
	if not _press("Continue"):
		_fail("No title Continue")
		return
	var map := title._stage.get_child(0) as Map
	await process_frame
	await physics_frame
	await physics_frame
	if not map or map._renderer._groves.size()!=29:
		_fail("Crossing terrain and all six grounded grove groups must be present.")
		return
	_key(KEY_RIGHT)
	if map._navigation.selected_waypoint_id()!=CROSS:
		_key(KEY_RIGHT)
	if not map or not map._renderer._crossing or map._navigation.selected_waypoint_id()!=CROSS:
		_fail("Crossing asset or directional selection unavailable.")
		return
	if not _key(KEY_Z) or not map._renderer._zoomed:
		_fail("Zoom failed on Crossing")
		return
	_key(KEY_Z)
	_key(KEY_ENTER)
	if not map._navigation.is_travelling() or profile.load_campaign_world("mara").current_waypoint_id()!=ROAD:
		_fail("First confirm did not travel without save advance")
		return
	map.set_process(false)
	map._renderer.set_process(false)
	var curve := map._curve_for(ROAD,CROSS)
	var duration := curve.get_baked_length()/map._pace
	map._process(duration*0.235)
	for i in range(18):
		map._renderer._process(1.0/30.0)
	var mid := Vector3(737,7.5,-78.5)
	var at_bridge := curve.get_closest_offset(mid)/map._pace
	map._process(at_bridge-duration*0.235)
	var pos: Vector3 = map._party.global_position
	var ray := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*6.0, pos-Vector3.UP*10.0)
	var hit := map._party.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.collider.name != "NorthernBridgeWalkProxy" or absf(hit.position.y-pos.y)>.01:
		_fail("Native bridge walk collision not at party feet: %s" % [hit])
		return
	if pos.distance_to(mid)>0.24:
		_fail("Curve doesn't cross the deck: %s" % [pos])
		return
	for i in range(18):
		map._renderer._process(1.0/30.0)
	map._process(duration-at_bridge+0.1)
	if title._page!=Title.Page.WORLD_MAP or profile.load_campaign_world("mara").current_waypoint_id()!=CROSS 			or profile.completed_missions("mara")!=PackedStringArray([MINE]):
		_fail("Arrival must save corresponding waypoint without auto-opening a briefing, awarding story progress, or entering battle")
		return
	_key(KEY_LEFT)
	if map._navigation.selected_waypoint_id()!=ROAD:
		_fail("Controller-equivalent left must select the return route.")
		return
	_key(KEY_ENTER)
	if not map._navigation.is_travelling():
		_fail("Return must animate on the existing curve.")
		return
	map._process(duration*0.25)
	if profile.load_campaign_world("mara").current_waypoint_id()!=CROSS:
		_fail("Reverse travel saved before arrival.")
		return
	_key(KEY_ESCAPE)
	if map._navigation.is_travelling() or not map._party.global_position.is_equal_approx(Vector3(827,10.6,-57)):
		_fail("Cancel did not restore the Crossing anchor.")
		return
	if not map.select_waypoint(CROSS):
		_fail("Cannot refocus current Crossing anchor.")
		return

	_key(KEY_ENTER)
	if title._page!=Title.Page.MISSION_BRIEFING or title._campaign_battle:
		_fail("Second confirm should open the real mission briefing, not battlefield")
		return
	if not _press("Confirm Deployment") or not title._campaign_battle is Grain:
		_fail("Could not deploy to actual Grain on Credit")
		return
	await physics_frame
	_key(KEY_ESCAPE)
	if not PauseTest.confirm_leave(title._pause_menu) or title._campaign_battle 			or title._page!=Title.Page.WORLD_MAP or not title._stage.get_child(0) is Map 			or profile.completed_missions("mara")!=PackedStringArray([MINE]) 			or profile.load_campaign_world("mara").current_waypoint_id()!=CROSS:
		_fail("Retreat erased the saved Crossing waypoint or altered campaign progress.")
		return
	print("PASS: title Continue, exact Crossing mount, zoom, travel across west terrain seam and physical bridge center, saved arrival, reverse/cancel, briefing, actual Grain on Credit deployment and retreat. Route m=", curve.get_baked_length())
	_exit_test(0)

func _factory(_world: World) -> Map:
	var map := Map.new()
	if map.build():
		return map
	map.free()
	return null

func _key(code: Key) -> bool:
	var input := InputEventKey.new()
	input.keycode=code
	input.pressed=true
	root.push_input(input,true)
	return true

func _press(label: String) -> bool:
	for node in title.find_children("*","Button",true,false):
		if node.text==label and node.is_visible_in_tree() and not node.disabled:
			node.pressed.emit()
			return true
	return false

func _fail(reason: String) -> void:
	push_error(reason)
	_exit_test(1)


func _exit_test(result: int) -> void:
	for path in [_path,_path+".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	quit(result)
