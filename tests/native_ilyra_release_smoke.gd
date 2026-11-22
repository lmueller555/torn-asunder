extends Node
## Autoload added only to disposable CI and local QA launch projects.
const Title := preload("res://game/title_screen.gd")
const Coast := preload("res://game/overworld/moonwash/ilyra_opener_map.gd")
const SOUTH_SCRIPT := "res://game/overworld/spanwater/ilyra_spanwater_map.gd"
const Nav := preload("res://game/campaign_overworld_navigation.gd")
const Campaigns := preload("res://game/campaigns.gd")
const Dialogue := preload("res://game/campaign_dialogue.gd")
const Missions := preload("res://game/campaign_missions.gd")
const PauseTest := preload("res://tests/pause_test_helpers.gd")
const Deploy := preload("res://game/campaign_deployments.gd")
const Profile := preload("res://game/profile_store.gd")
const World := preload("res://game/campaign_world.gd")
const Rescue := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const CAMP := "moonwash_camp"
const HARBOR := "moonwash_harbor"
const SHORE := "moonwash_survey_shore"
const LOCK := "spanwater_lock"
const ILYRA := "ilyra"
var title: Title
var mode: String
var misses := 0


func _ready() -> void:
	mode = OS.get_environment("ILYRA_SMOKE_MODE")
	if mode != "":
		run.call_deferred()


func check(value: bool, label: String) -> bool:
	if not value:
		misses += 1
		printerr("FAIL: ", label)
	return value


func run() -> void:
	var local := OS.get_environment("ILYRA_EDITOR_QA") == "1"
	if not local:
		check(not OS.is_debug_build() and not OS.has_feature("editor"), "native nondebug release, not the editor")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/title_screen.tscn", "actual main scene")
	check(FileAccess.file_exists("res://assets/overworld/marches/anchors.json")
		and FileAccess.file_exists("res://assets/overworld/marches/camp/spur.json"), "both raw Marches routes included")
	if mode != "missing":
		check(ResourceLoader.exists("res://assets/overworld/moonwash/moonwash-sector-data.tres", "Resource")
			and ResourceLoader.exists("res://game/overworld/moonwash/ilyra_opener_renderer.tscn", "PackedScene")
			and ResourceLoader.exists("res://game/overworld/spanwater/ilyra_spanwater_renderer.tscn", "PackedScene")
			and ResourceLoader.exists("res://game/overworld/spanwater/closed_cut_stone.gdshader", "Shader"),
			"typed Moonwash resources and Spanwater bundle are included")
	for frame in range(120):
		title = get_tree().current_scene as Title
		if title and title.get_script().resource_path == "res://game/overworld/mara_sector_title.gd" and title._page == Title.Page.TITLE:
			break
		await get_tree().process_frame
	if not check(title != null and button("New Game") != null, "normal title available"):
		finish()
		return
	if mode in ["off", "foreign", "missing", "mara"]:
		var campaign_id := OS.get_environment("ILYRA_TEST_CAMPAIGN")
		if not check(opening(ILYRA if campaign_id == "" else campaign_id) and PauseTest.leave_battle(title), "normal campaign opening and battle exit"):
			finish()
			return
		await get_tree().physics_frame
		var has_3d := title._stage.get_child(0) is Title.DevelopmentOverworld
		check(has_3d == (mode == "mara"), "only previously shipped Mara in 3D")
		if mode == "missing":
			check(title._stage.get_children().any(func(node): return node is Label and node.text.contains("3D overworld unavailable")), "missing package reports a visible fallback")
		finish()
		return
	if mode == "mara_harbor":
		if not check(load_campaign("mara"), "Load normal Mara save"):
			finish()
			return
		await get_tree().process_frame
		var m := title._stage.get_child(0) as Title.DevelopmentOverworld
		check(at(HARBOR) and m != null and m.get_script().resource_path == "res://game/overworld/moonwash/coast_map.gd"
			and title._campaign_world.mission_at_current_waypoint() == "mara_moonwash_quay", "shared Harbor uses Mara Upper Quay, never Ilyra Harbor")
		if m:
			await get_tree().physics_frame
			if DisplayServer.get_name() != "headless":
				await capture(m,"mara-upper-quay-release")
			m.confirm_button.pressed.emit()
			check(title._page == Title.Page.MISSION_BRIEFING and button("Confirm Deployment") != null, "real first Upper Quay briefing")
		finish()
		return
	if mode == "rendered":
		if not check(load_campaign(ILYRA), "ordinary Load list selects exact original Ilyra save"):
			finish()
			return
		await get_tree().process_frame
		if not check(at(LOCK) and title._stage.get_child(0).get_script().resource_path == SOUTH_SCRIPT, "cold profile resumes south Spanwater"):
			finish()
			return
		var south: Variant = title._stage.get_child(0)
		check(not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless", "resume has a real window")
		for frame in range(3):
			await get_tree().physics_frame
		check(south._renderer.probe_south_landing(), "loaded landing has measured footing")
		check(south._header.get_child(0).get_child(2).text == "Ilyra Venn · Tide Speaker"
			and south._party.position.is_equal_approx(Vector3(114,1.52,25)), "canonical campaign label and South Bank landing")
		check(south._renderer.has_node("DryClosedCutStrata/StratifiedSouthGully"), "exact approved wider context mounted")
		await capture(south,"spanwater-release-regional")
		south._renderer.toggle_zoom(south._renderer.LANDING_POINT)
		await capture(south,"spanwater-release-near")
		check(Profile.new().ilyra_moonwash_clear_result() == Rescue.CARGO_RECOVERED, "cold Load retains original cargo outcome")
		check(Profile.new().completed_missions("raska").is_empty(), "Spanwater needs no Orc victory")
		south.confirm_button.pressed.emit()
		check(title._page == Title.Page.MISSION_BRIEFING and button("Confirm Deployment") != null
			and str(Deploy.for_mission(title._campaign_world.mission_at_current_waypoint()).dispatch) == "ilyra_spanwater_dispatch",
			"normal South Bank Load opens actual first evacuation briefing")
		check(not Profile.new().completed_missions(ILYRA).has("ilyra_spanwater_evacuation"), "spanwater lock save does not imply mission clear")
		finish()
		return
	if mode == "old":
		if not check(press("Continue"), "legacy Continue"):
			finish()
			return
		await get_tree().process_frame
		check(at(HARBOR) and title._stage.get_child(0) is Coast, "old 2D Harbor save opens 3D at canonical station")
		check(Profile.new().completed_missions(ILYRA).is_empty(), "old Harbor does not acquire an unearned clear")
		var old := title._stage.get_child(0) as Coast
		if old:
			check(old._boundary_button == null and old.select_waypoint(SHORE) and old._navigation.action() == Nav.Action.LOCKED, "old uncleared profile cannot access Survey or Spanwater")
		finish()
		return
	if not check(mode == "travel" and opening(ILYRA), "normal New Game launches the actual Ilyra opening dispatch and rescue mission directly"):
		finish()
		return
	check(Profile.new().load_campaign_world(ILYRA).current_waypoint_id() == HARBOR
		and Profile.new().completed_missions(ILYRA).is_empty(), "first real mission persists Harbor without a false clear")
	if not check(PauseTest.leave_battle(title) and at(HARBOR) and title._stage.get_child(0) is Coast,
			"actual pause/leave enters 3D Harbor after combat without a clear"):
		finish()
		return
	var map := title._stage.get_child(0) as Coast
	# New Game no longer crosses Camp first. Exercise the real reversible coastal
	# road from post-battle Harbor instead, without direct time/world manipulation.
	check(map.select_waypoint(CAMP), "choose Camp from post-battle Harbor")
	map.confirm_button.pressed.emit()
	if not check(await wait_for(CAMP) and Profile.new().load_campaign_world(ILYRA).current_waypoint_id() == CAMP, "took and saved real Harbor-to-Camp route"):
		finish()
		return
	map = title._stage.get_child(0) as Coast
	check(map.select_waypoint(HARBOR), "choose Harbor from Camp")
	map.confirm_button.pressed.emit()
	if not check(await wait_for(HARBOR) and Profile.new().load_campaign_world(ILYRA).current_waypoint_id() == HARBOR, "took and saved real Camp-to-Harbor route"):
		finish()
		return
	map = title._stage.get_child(0) as Coast
	check(map._boundary_button == null and map.select_waypoint(SHORE) and map._navigation.action() == Nav.Action.LOCKED, "Survey locked before its actual rescue result")
	# This fixture covers overworld travel, not the full playable rescue/Survey fights.
	check(title._profile.record_ilyra_moonwash_clear(Rescue.CARGO_RECOVERED) == OK, "record rescue test fixture")
	title._show_world_map()
	map = title._stage.get_child(0) as Coast
	check(map.select_waypoint(SHORE), "legit Survey selection after rescue")
	map.confirm_button.pressed.emit()
	if not check(await wait_for(SHORE) and Profile.new().load_campaign_world(ILYRA).current_waypoint_id() == SHORE, "actual Survey arrival saved"):
		finish()
		return
	map = title._stage.get_child(0) as Coast
	check(map._boundary_button == null, "Spanwater boundary absent before Survey clear")
	check(title._profile.record_mission_clear(ILYRA,"ilyra_coast_survey") == OK, "record Survey test fixture")
	title._show_world_map()
	map = title._stage.get_child(0) as Coast
	if not check(map._boundary_button != null, "real current save unlocks inter-sector travel"):
		finish()
		return
	map._boundary_button.pressed.emit()
	map.confirm_button.pressed.emit()
	if not check(await wait_for(LOCK) and title._stage.get_child(0).get_script().resource_path == SOUTH_SCRIPT, "real Spanwater mounted after save"):
		finish()
		return
	check(Profile.new().load_campaign_world(ILYRA).current_waypoint_id() == LOCK, "lifecycle tested with canonical profile")
	var south: Variant = title._stage.get_child(0)
	south.confirm_button.pressed.emit()
	check(title._page == Title.Page.MISSION_BRIEFING and button("Confirm Deployment") != null, "real separate native evacuation briefing")
	title._show_world_map()
	south = title._stage.get_child(0)
	south._boundary_button.pressed.emit()
	south.confirm_button.pressed.emit()
	if not check(await wait_for(SHORE), "real reverse after the initial briefing"):
		finish()
		return
	check(title._profile.record_ilyra_moonwash_clear(Rescue.CREWS_ONLY) == OK
		and Profile.new().ilyra_moonwash_clear_result() == Rescue.CARGO_RECOVERED,
		"reverse and later crews-only clear cannot overwrite original cargo")
	map = title._stage.get_child(0) as Coast
	map._boundary_button.pressed.emit()
	map.confirm_button.pressed.emit()
	check(await wait_for(LOCK) and Profile.new().load_campaign_world(ILYRA).current_waypoint_id() == LOCK, "re-commit Spanwater for separate cold Load")
	finish()


func wait_for(point: String) -> bool:
	var limit := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < limit:
		if at(point):
			return true
		await get_tree().process_frame
	return false


func at(point: String) -> bool:
	return title._page == Title.Page.WORLD_MAP and title._campaign_world and title._campaign_world.current_waypoint_id() == point


func choose(id: String) -> bool:
	if not press("New Game"):
		return false
	var hero := button(id)
	if not hero:
		return false
	hero.grab_focus()
	return title._portraits[title._selected] == hero and press("Begin Campaign")


func opening(id: String) -> bool:
	if not choose(id):
		return false
	var initial := Missions.first_unplayed_mission_id(id,PackedStringArray())
	var deployment := Deploy.for_mission(initial)
	var scene := deployment.get("scene") as PackedScene
	var dialogue := title._stage.get_child(0) as Dialogue
	if not scene or title._page != Title.Page.CAMPAIGN_DIALOGUE or not dialogue or dialogue._beat_id != deployment.dispatch or title._campaign_battle:
		return false
	if not press("BackButton"):
		return false
	return title._page == Title.Page.CAMPAIGN_BATTLE and title._campaign_battle != null \
		and title._campaign_battle.scene_file_path == scene.resource_path \
		and title._campaign_world.mission_at_current_waypoint() == initial


func load_campaign(id: String) -> bool:
	if not press("Load"):
		return false
	for campaign in Campaigns.ALL:
		if campaign.id == id:
			return press("%s %s  ·  %s" % [campaign.title,campaign.name,campaign.faction])
	return false


func capture(view: Title.DevelopmentOverworld, label: String) -> void:
	for i in range(2):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := view.render_viewport.get_texture().get_image()
	check(image != null and not image.is_empty() and image.get_width() > 320,label + " rendered actual 3D pixels")
	var proof := OS.get_environment("ILYRA_CAPTURE")
	if proof != "":
		image = get_tree().root.get_texture().get_image()
		check(image.save_jpg(proof.path_join(label+".jpg"),.90) == OK,label + " full window recorded")


func button(label: String) -> Button:
	return title._stage.find_child(label, true, false) as Button


func press(label: String) -> bool:
	var btn := button(label)
	if not btn:
		return false
	btn.pressed.emit()
	return true


func finish() -> void:
	print("Native Ilyra launch smoke (%s): %s" % [mode, "PASS" if misses == 0 else "FAIL"])
	get_tree().quit(0 if misses == 0 else 1)
