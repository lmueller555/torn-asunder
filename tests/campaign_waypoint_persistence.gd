extends SceneTree

const Profile := preload("res://game/profile_store.gd")
const World := preload("res://game/campaign_world.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const ROAD := "marches_road"
const ESCORT := "mara_mine_escort"
const CATALOG: Array[Dictionary] = [{"id": "mara"}, {"id": "raska"}]
const OLD_FILE := "[campaigns]\nmara=2\nraska=1\n\n[settings]\nfullscreen=false\nreduced_motion=true\n"


func _initialize() -> void:
	var path := OS.get_temp_dir().path_join("torn-waypoint-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var passed := _check_fresh_and_legacy(path)
	passed = _check_arrival_and_reload(path) and passed
	passed = _check_failed_save(path) and passed
	passed = _check_invalid_and_foreign_records(path) and passed
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".tmp") or DirAccess.dir_exists_absolute(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")
	if passed:
		print("Verified legacy fallback, real arrival save/reload, locks, campaign isolation, and failed-write rollback.")
	quit(0 if passed else 1)


func _check_fresh_and_legacy(path: String) -> bool:
	var profile := Profile.new(path)
	var world := profile.load_campaign_world("mara")
	if world.current_waypoint_id() != CAMP or FileAccess.file_exists(path) or not profile.completed_missions("mara").is_empty():
		return _fail("A fresh profile must show the authored start without writing a file or clearing a mission.")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("Couldn't create the isolated legacy profile fixture.")
	file.store_string(OLD_FILE)
	file.close()
	profile = Profile.new(path)
	if profile.load_campaign_world("mara").current_waypoint_id() != CAMP or not _legacy_intact(profile):
		return _fail("A legacy profile without a waypoint did not preserve its campaign and settings.")
	if FileAccess.get_file_as_string(path) != OLD_FILE:
		return _fail("Loading a legacy waypoint fallback rewrote the original file.")
	return true


func _check_arrival_and_reload(path: String) -> bool:
	var profile := Profile.new(path)
	var world := profile.load_campaign_world("mara")
	var empty := PackedStringArray()
	if world.travel_to(MINE, empty) != World.TravelResult.ARRIVED or profile.record_world_waypoint(world) != OK:
		return _fail("An actual mine arrival could not be saved before a mission clear.")
	var mine_save := FileAccess.get_file_as_string(path)
	profile = Profile.new(path)
	world = profile.load_campaign_world("mara")
	if world.current_waypoint_id() != MINE or world.mission_at_current_waypoint() != ESCORT:
		return _fail("Reload did not resume at the last saved mine waypoint.")
	if not profile.completed_missions("mara").is_empty() or not _legacy_intact(profile):
		return _fail("Saving a waypoint changed progress, settings or last-played campaign order.")
	if world.travel_to(ROAD, empty) != World.TravelResult.LOCKED or profile.record_world_waypoint(world) != OK:
		return _fail("A locked move advanced or made the prior arrival unsavable.")
	if FileAccess.get_file_as_string(path) != mine_save:
		return _fail("A repeated checkpoint after a failed move rewrote the file.")

	# A caller that supplied false clear flags to map travel still cannot save a locked waypoint.
	var spoofed := World.new("mara")
	spoofed.travel_to(MINE, empty)
	spoofed.travel_to(ROAD, PackedStringArray([ESCORT]))
	if profile.record_world_waypoint(spoofed) != ERR_INVALID_PARAMETER or FileAccess.get_file_as_string(path) != mine_save:
		return _fail("A caller-supplied clear could save an otherwise locked waypoint.")
	if profile.record_mission_clear("mara", ESCORT) != OK or profile.load_campaign_world("mara").current_waypoint_id() != MINE:
		return _fail("Recording a mission clear moved the saved waypoint without an arrival.")
	if world.travel_to(ROAD, profile.completed_missions("mara")) != World.TravelResult.ARRIVED or profile.record_world_waypoint(world) != OK:
		return _fail("The properly unlocked road arrival could not be saved.")
	profile = Profile.new(path)
	world = profile.load_campaign_world("mara")
	if world.current_waypoint_id() != ROAD or world.visited_waypoint_ids() != PackedStringArray([CAMP, ROAD]):
		return _fail("Road reload failed or synthesized intermediate waypoint visits.")
	if profile.completed_missions("mara") != PackedStringArray([ESCORT]) or not _legacy_intact(profile):
		return _fail("The subsequent waypoint corrupted the explicit clear or legacy values.")
	return true


func _check_failed_save(path: String) -> bool:
	var profile := Profile.new(path)
	var world := profile.load_campaign_world("mara")
	var before := FileAccess.get_file_as_string(path)
	if world.travel_to(MINE, profile.completed_missions("mara")) != World.TravelResult.ARRIVED:
		return _fail("Couldn't prepare the failed-write fixture.")
	if DirAccess.make_dir_absolute(path + ".tmp") != OK:
		return _fail("Couldn't block the temporary profile write for the rollback test.")
	var result := profile.record_world_waypoint(world)
	DirAccess.remove_absolute(path + ".tmp")
	if result == OK or FileAccess.get_file_as_string(path) != before or profile.load_campaign_world("mara").current_waypoint_id() != ROAD:
		return _fail("A failed disk write changed the last persisted waypoint in memory or on disk.")
	if world.current_waypoint_id() != MINE:
		return _fail("A failed persistence write mutated the independent attempted travel session.")
	return true


func _check_invalid_and_foreign_records(path: String) -> bool:
	var fixture := ConfigFile.new()
	if fixture.load(path) != OK:
		return _fail("Couldn't reopen the profile for malformed saved values.")
	fixture.erase_section(Profile.MISSION_PROGRESS)
	fixture.set_value(Profile.CAMPAIGN_WAYPOINTS, "raska", MINE)
	for value in [ROAD, "foreign_waypoint", 17, ""]:
		fixture.set_value(Profile.CAMPAIGN_WAYPOINTS, "mara", value)
		if fixture.save(path) != OK:
			return _fail("Couldn't install an invalid saved value.")
		var before := FileAccess.get_file_as_string(path)
		var profile := Profile.new(path)
		var world := profile.load_campaign_world("mara")
		if world.current_waypoint_id() != CAMP or world.visited_waypoint_ids() != PackedStringArray([CAMP]):
			return _fail("A locked, unknown, malformed or blank save fabricated an arrival.")
		var foreign_world := profile.load_campaign_world("raska")
		if not foreign_world.current_waypoint_id().is_empty() or profile.record_world_waypoint(foreign_world) != ERR_INVALID_PARAMETER:
			return _fail("A campaign without a map inherited another campaign's waypoint.")
		if profile.record_world_waypoint(null) != ERR_INVALID_PARAMETER or FileAccess.get_file_as_string(path) != before:
			return _fail("Rejecting invalid or foreign state modified the profile.")
	var profile := Profile.new(path)
	var mara := profile.load_campaign_world("mara")
	mara.travel_to(MINE, PackedStringArray())
	if profile.record_world_waypoint(mara) != OK or fixture.load(path) != OK:
		return _fail("Saving a new legal waypoint after fallback failed.")
	if fixture.get_value(Profile.CAMPAIGN_WAYPOINTS, "raska", "") != MINE:
		return _fail("Mara's save overwrote another campaign key.")
	if not profile.completed_missions("raska").is_empty() or not profile.completed_missions("mara").is_empty():
		return _fail("A position fallback or save fabricated a campaign clear.")
	return true


func _legacy_intact(profile: Profile) -> bool:
	return profile.saved_campaigns(CATALOG) == CATALOG and not profile.setting("fullscreen") and profile.setting("reduced_motion")


func _fail(message: String) -> bool:
	push_error(message)
	return false
