extends SceneTree
## Run the ordinary title with isolated XDG directories; GDScript errors are
## also a test failure even when the engine's process would otherwise exit 0.
const Main := preload("res://game/title_screen.tscn")
const Host := preload("res://game/overworld/mara_sector_title.gd")
const Title := preload("res://game/title_screen.gd")
const Profile := preload("res://game/profile_store.gd")
const Campaigns := preload("res://game/campaigns.gd")
const World := preload("res://game/campaign_world.gd")
const NerisMap := preload("res://game/overworld/neris/approach_map.gd")
const SLOT := "user://neris-rapid-cancel-test.cfg"
const POST := "cairnspine_boundary_post"
const RASKA_CAMP := "basin_camp"
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ", message)
		quit(1)
	assert(ok, message)
	checks += 1

func campaign(id: String) -> Dictionary:
	for entry in Campaigns.ALL:
		if entry.id == id:
			return entry
	return {}

func run() -> void:
	DirAccess.remove_absolute(SLOT)
	var save := Profile.new(SLOT)
	check(save.record_mission_clear("neris", "neris_failing_grove") == OK, "unlock only Neris's Boundary route")
	for pair in [["neris", POST], ["raska", RASKA_CAMP]]:
		check(save.mark_played(pair[0]) == OK and save.record_world_waypoint(World.new(pair[0], pair[1], save.completed_missions(pair[0]))) == OK, "seed each independent campaign")
	var initial := Main.instantiate() as Title
	root.add_child(initial)
	current_scene = initial
	for i in 15:
		await process_frame
		if current_scene is Host: break
	var host := current_scene as Host
	check(host != null and host.NormalNerisEntry.requested() and host.NormalRaskaEntry.requested(), "stock title and both shipping maps on")
	host._profile = Profile.new(SLOT)
	host._show_title()
	var before := FileAccess.get_file_as_bytes(SLOT)
	host._open_campaign(campaign("neris"))
	check(host._neris_resume_played_pending and host._neris_presenter != null, "cold Neris shows loading before mounting")
	var canceled: WeakRef = weakref(host._neris_presenter)
	var panel: Control = host._neris_presenter._panel
	await process_frame
	check(panel.back.has_focus(), "rapid Cancel is already focused")
	panel.back.pressed.emit()
	check(host._page == Title.Page.TITLE and host._neris_presenter == null and not host._neris_resume_played_pending, "return to title clears the pending presenter")
	check(FileAccess.get_file_as_bytes(SLOT) == before, "cancel writes no save bytes")
	host._open_campaign(campaign("raska"))
	check(host._stage.get_node_or_null("RaskaOverworld") != null, "same-frame Raska opens native map")
	for i in 4: await process_frame
	check(canceled.get_ref() == null and host._stage.get_node_or_null("RaskaOverworld") != null, "abandoned Neris is released without remounting over Raska")
	check(host._profile.load_campaign_world("neris").current_waypoint_id() == POST and host._profile.load_campaign_world("raska").current_waypoint_id() == RASKA_CAMP, "separate saved waypoints survive")
	host._show_title()
	host._open_campaign(campaign("neris"))
	for i in 350:
		await process_frame
		if host._stage.get_child_count() and host._stage.get_child(0) is NerisMap:
			break
	check(host._stage.get_child_count() and host._stage.get_child(0) is NerisMap, "fresh retry adopts the correct native Neris Boundary")
	check(host._neris_presenter._physical_builds == 1 and not host._neris_resume_played_pending, "single adopted retry completes its own resume")
	check(host._profile.load_campaign_world("neris").current_waypoint_id() == POST and host._profile.load_campaign_world("raska").current_waypoint_id() == RASKA_CAMP, "successful retry does not change campaign ownership")
	print("Neris rapid cancel: %d/%d." % [checks, checks])
	quit()
