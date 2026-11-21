extends SceneTree

const TitleScene := preload("res://game/title_screen.tscn")
const SectorTitle := preload("res://game/overworld/mara_sector_title.gd")
const MarchesView := preload("res://game/overworld/marches_overworld_view.gd")
const CoastView := preload("res://game/overworld/moonwash/coast_map.gd")
const World := preload("res://game/campaign_world.gd")
const Profile := preload("res://game/profile_store.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const CoastRenderer := preload("res://game/overworld/moonwash/coast_renderer.gd")
const Coast := preload("res://game/overworld/moonwash/coast_route.gd")
const CROSSING := "marches_crossing"
const ROAD := "moonwash_road"
const HARBOR := "moonwash_harbor"

class FaultableTitle extends SectorTitle:
	var _fault_preflight := false

	func _boundary_preflight_allowed() -> bool:
		return not _fault_preflight


var _title: FaultableTitle
var _path: String
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_path = OS.get_temp_dir().path_join("actual-sector-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	await _exercise()
	if is_instance_valid(_title):
		_title.queue_free()
		await process_frame
	if DirAccess.dir_exists_absolute(_path + ".tmp"):
		DirAccess.remove_absolute(_path + ".tmp")
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	print("Actual Title 3D boundary, Crossing and Moonwash: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, name: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + name)
	return ok


func _profile() -> Profile:
	return Profile.new(_path)


func _saved() -> String:
	return _profile().load_campaign_world("mara").current_waypoint_id()


func _disk() -> String:
	return FileAccess.get_file_as_string(_path)


func _view() -> MarchesView:
	if _title._page != SectorTitle.Page.WORLD_MAP:
		return null
	return _title._stage.get_child(0) as MarchesView


func _dialogue() -> Dialogue:
	if _title._page != SectorTitle.Page.CAMPAIGN_DIALOGUE:
		return null
	return _title._stage.get_child(0) as Dialogue


func _button(name: String) -> Button:
	return _title._stage.find_child(name, true, false) as Button


func _press(name: String) -> bool:
	var button := _button(name)
	if not button or button.disabled:
		return false
	button.pressed.emit()
	return true


func _key(key: Key) -> void:
	var input := InputEventKey.new()
	input.keycode = key
	input.pressed = true
	root.push_input(input, true)


func _joy(key: JoyButton) -> void:
	var input := InputEventJoypadButton.new()
	input.button_index = key
	input.pressed = true
	root.push_input(input, true)


func _await_boundary() -> void:
	# Timers wait for actual deferred preflight + commit work.
	for i in range(6):
		await create_timer(0.18).timeout
		if _title._sector_token == 0:
			break


func _exercise() -> void:
	var profile := _profile()
	if not _check(profile.set_setting("fullscreen", false) == OK and profile.mark_played("mara") == OK \
			and profile.record_greyhollow_rescue_clear() == OK and profile.finish_greyhollow_reveal() == OK \
			and profile.record_mission_clear("raska", "orc_mine_witness") == OK, "seed actual profile before Grain"):
		return
	var initial := World.new("mara", CROSSING, profile.completed_missions("mara"))
	if not _check(profile.record_world_waypoint(initial) == OK, "save existing Crossing anchor"):
		return
	var stage := TitleScene.instantiate()
	stage.set_script(FaultableTitle)
	_title = stage as FaultableTitle
	_title._profile = profile
	_title.install_overworld_playtest()
	root.add_child(_title)
	await process_frame
	if not _check(_press("Continue") and _view() != null, "actual title Continue mounted Crossing"):
		return
	var west := _view()
	await process_frame
	_check(west._renderer.get_node_or_null("MarchesCrossingArt") != null and west._points[CROSSING].is_equal_approx(Vector3(827,10.6,-57)), "actual Crossing renderer & established mill")
	_check(west._boundary_button.visible and west._boundary_button.text.contains("Road to Moonwash"), "Crossing boundary selector visible")
	_check(not DirAccess.dir_exists_absolute("res://study") and not FileAccess.file_exists("res://override.cfg") and not DirAccess.dir_exists_absolute("res://art"), "Crossing mounts with no old study/art tree or Xorg/cache override")
	_check(west.edge_hint_from(CROSSING) and west.marker_bearing(CROSSING,90).y==17.0 and west.marker_bearing("marches_road_camp",90).y==17.0,
		"existing #286 Crossing return hint and #285 camp badge geometry retained")
	_joy(JOY_BUTTON_Y)
	_check(west._navigation.selected_waypoint_id() == ROAD and west.confirm_button.disabled \
			and west._navigation.action() == west.Navigation.Action.LOCKED, "section selection acknowledges existing locked Grain gate")
	_joy(JOY_BUTTON_A)
	_check(_title._sector_token == 0 and _saved() == CROSSING and west._curve_for(CROSSING, ROAD) == null, "locked confirm cannot transfer or invent a curve")
	_check(west.select_waypoint(CROSSING), "select actual Grain waypoint")
	_joy(JOY_BUTTON_A)
	if not _check(_press("Confirm Deployment") and _title._campaign_battle != null, "real stock Grain briefing and deployment"):
		return
	var battle := _title._campaign_battle
	# Exercise the normal success pipeline from a live scene; inject its
	# existing terminal result to avoid replaying Grain gameplay in this test.
	_title._on_campaign_result(Grain.BOTH, battle, "mara", Grain.MISSION_ID)
	await process_frame
	if not _check(_dialogue() != null and _profile().grain_clear_result() == Grain.BOTH, "normal Grain victory/debrief hook writes first result"):
		return
	_dialogue().cancel() # Stock optional debrief dismissal.
	west = _view()
	if not _check(west != null and _saved() == CROSSING and _dialogue() == null, "after Grain debrief exact Crossing scene stays at same anchor"):
		return
	await process_frame
	var stable := _disk()
	_joy(JOY_BUTTON_Y)
	_check(west.confirm_button.text == "Confirm Sector Transfer" and not west.confirm_button.disabled, "confirm becomes actionable after Grain")
	_joy(JOY_BUTTON_A)
	var pending := _title._sector_token
	_check(pending != 0 and west._boundary_pending and not west._navigation.is_travelling() and _saved() == CROSSING, "explicit confirm opens cancelable transfer, not curve movement")
	_joy(JOY_BUTTON_A)
	_check(_title._sector_token == pending, "repeated confirm cannot reenter")
	_joy(JOY_BUTTON_B)
	await create_timer(0.35).timeout
	_check(_title._sector_token == 0 and _view() == west and _disk() == stable and not west._boundary_pending, "controller cancellation and stale callback keep Crossing and bytes")
	# Cancel a destination after the hidden real renderer was already loaded.
	_key(KEY_ENTER)
	for i in range(14):
		if is_instance_valid(_title._prepared_map):
			break
		await create_timer(0.04).timeout
	var had_hidden_preview := is_instance_valid(_title._prepared_map) and not _title._prepared_map.visible
	_key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	_check(had_hidden_preview and _view() == west and _disk() == stable and not is_instance_valid(_title._prepared_map), "Escape after hidden target load discards preview without committing")
	_title._fault_preflight = true
	_key(KEY_ENTER)
	await _await_boundary()
	_check(_view() == west and west.status_label.text.contains("could not load") and _disk() == stable, "failed preflight stays at Crossing with explicit retry")
	_title._fault_preflight = false
	if not _check(DirAccess.make_dir_absolute(_path + ".tmp") == OK, "force real atomic save failure before transfer"):
		return
	_key(KEY_ENTER)
	await _await_boundary()
	_check(_view() == west and _saved() == CROSSING and west.status_label.text.contains("could not be saved") \
			and _disk() == stable and not is_instance_valid(_title._prepared_map), "failed save drops prepared scene and keeps old state")
	DirAccess.remove_absolute(_path + ".tmp")
	_key(KEY_ENTER)
	await _await_boundary()
	if not _check(_saved() == ROAD and _dialogue() != null and _dialogue()._beat_id == Beats.MARA_WATER_REQUEST, "verified transfer commits Road before canonical Water Request"):
		return
	_check(_view() == null and not _profile().has_seen_intermission("mara", Beats.MARA_WATER_REQUEST) \
			and is_instance_valid(_title._prepared_map) and not _title._prepared_map.visible, "coast hidden during mandatory pending beat")
	for i in range(25):
		if _dialogue() == null:
			break
		_joy(JOY_BUTTON_A)
	var coast := _view()
	if not _check(coast is CoastView and _profile().has_seen_intermission("mara", Beats.MARA_WATER_REQUEST), "explicitly completed Water Request persists before activating coast renderer"):
		return
	await process_frame
	var curve := coast._curve_for(ROAD, HARBOR)
	if not _check(curve != null and absf(curve.get_baked_length() - 485.076) < 0.3, "real authored 485 m coastal approach, not a gap proxy"):
		return
	_check(coast._renderer.find_child("MoonwashGround", true, false) != null \
			and coast._renderer.get_node_or_null("MarchesCrossingArt") == null \
			and coast._points[ROAD].is_equal_approx(Vector3(1060,32.9719,-57)), "only coast mounts and correct restored arrival")
	_check(coast._boundary_button.visible and coast._boundary_button.text.contains("Marches Crossing"), "coast return selector available")
	_check(coast._renderer._groves.size()==9, "baked Harbor LOD and all eight exact coast thickets are mounted before exposure")
	await _check_packaged_coast(coast._renderer as CoastRenderer)
	coast.set_process(false)
	_check(coast.select_waypoint(HARBOR), "select reachable High Quay separately")
	_joy(JOY_BUTTON_A)
	coast._process(curve.get_baked_length() / coast._pace * 0.5)
	_check(coast._navigation.is_travelling() and _saved() == ROAD and coast._party.position.distance_to(Coast.points()[0]) > 40.0, "native curve moves party while profile remains at Road")
	coast._process(curve.get_baked_length() / coast._pace)
	_check(_saved() == HARBOR and _button("Confirm Deployment") == null and _view() == coast, "coast arrival saves and never auto-deploys")
	_joy(JOY_BUTTON_RIGHT_SHOULDER)
	_check(coast._renderer._zoomed and coast.marker_bearing(HARBOR,92) == Vector2(154,-80) and coast.edge_hint_from(HARBOR)
		and coast._renderer._groves[0][1].visible and not coast._renderer._groves[0][2].visible,
		"ship-facing zoom uses exact baked near Harbor, offset marker and return hint")
	_joy(JOY_BUTTON_A)
	_check(_button("Confirm Deployment") != null and _title._campaign_battle == null, "existing Harbor briefing requires separate confirm")
	_title._go_back()
	coast = _view()
	if not _check(coast is CoastView and not coast._boundary_button.visible, "Harbor map cannot transfer directly"):
		return
	coast.set_process(false)
	coast.select_waypoint(ROAD)
	_joy(JOY_BUTTON_A)
	coast._process(45.0)
	if not _check(_saved() == ROAD and _view() == coast and _dialogue() == null and coast._boundary_button.visible, "return to road avoids duplicate beat"):
		return
	_key(KEY_TAB)
	_key(KEY_ENTER)
	await _await_boundary()
	west = _view()
	if not _check(west != null and not west is CoastView and _saved() == CROSSING and _dialogue() == null, "backward sector transfer remounts Crossing without reopening story"):
		return
	_check(west._renderer._groves.size() == 29, "reverse preflight preserves the original 29 grounded Crossing groves")
	_joy(JOY_BUTTON_Y)
	_joy(JOY_BUTTON_A)
	await _await_boundary()
	_check(_view() is CoastView and _saved() == ROAD and _dialogue() == null, "second forward transfer skips already-seen Water Request")
	var final := _profile()
	_check(final.grain_clear_result() == Grain.BOTH and final.completed_missions("raska") == PackedStringArray(["orc_mine_witness"]) \
			and not final.completed_missions("mara").has("mara_moonwash_quay"), "snapshot preserves foreign progress and original Grain result; no phantom High Quay clear")

func _check_packaged_coast(renderer: CoastRenderer) -> void:
	var data := renderer.data
	_check(renderer.mounted_for_play() and data.resource_path == Coast.SOURCE
		and renderer.coast_scene.resource_path.ends_with("/moonwash-coast.glb")
		and renderer.harbor_regional_scene.resource_path.ends_with("/moonwash-harbor-regional.glb")
		and renderer.harbor_near_scene.resource_path.ends_with("/moonwash-harbor-near.scn")
		and renderer.shoulder_returns_scene.resource_path.ends_with("/moonwash-shoulder-returns.glb"),
		"normal ResourceLoader dependencies use only the canonical packed Coast paths")
	var returns := renderer.get_node("MoonwashShoulderReturns") as Node3D
	var meshes := returns.find_children("*", "MeshInstance3D", true, false)
	var mineral_off := false
	var stone_on := false
	for mesh: MeshInstance3D in meshes:
		if str(mesh.name).begins_with("Mineral"):
			mineral_off = mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.visible
		elif str(mesh.name).begins_with("Dry"):
			stone_on = mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and mesh.visible
	_check(returns.position == Coast.COAST_OFFSET and returns.rotation == Vector3.ZERO and returns.scale == Vector3.ONE
		and meshes.size() == 2 and mineral_off and stone_on
		and returns.find_children("*","CollisionObject3D",true,false).is_empty(),
		"approved returns are visible with exact origin/scale and only mineral casting turned off")
	var harbor := renderer.get_node("MoonwashHarbor") as Node3D
	var near: Node3D = renderer._groves[0][1]
	var far: Node3D = renderer._groves[0][2]
	var surfaces := 0
	for mesh: MeshInstance3D in near.find_children("*", "MeshInstance3D", true, false):
		surfaces += mesh.mesh.get_surface_count()
	_check(harbor.position == Coast.COAST_OFFSET and near.transform == Transform3D.IDENTITY
		and far.transform == Transform3D.IDENTITY and near.visible != far.visible and surfaces == 71,
		"exact batched near Harbor retains 71 surfaces, origin, and single-tier visibility")
	await physics_frame
	var count := 0
	var max_error := 0.0
	for point: Vector3 in data.world_points():
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 70.0, point - Vector3.UP * 60.0)
		var hit := renderer.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider.get_parent() == renderer._ground:
			count += 1
			max_error = maxf(max_error, absf(point.y - hit.position.y))
	_check(count == 334 and max_error < 0.001, "all 334 native normal-import road points stay grounded")
	var native_thickets := 0
	for i in range(8):
		var expected := data.thicket_world_ground[i]
		var planted: Node3D = renderer._groves[i + 1][0]
		var pose := data.thicket_pose[i]
		if planted.name == StringName(data.thicket_labels[i].replace(" ", "_")) \
				and (planted.position + Vector3.UP * pose.z).distance_to(expected) < 0.003 \
				and planted.scale.is_equal_approx(Vector3.ONE * pose.x):
			native_thickets += 1
	_check(native_thickets == 8, "all eight canonical thicket identities, footing, burial and scale survive the live mount")
