extends SceneTree

const Profile := preload("res://game/profile_store.gd")
const CATALOG: Array[Dictionary] = [{"id": "mara"}, {"id": "raska"}]
const LEGACY := "[campaigns]\nmara=2\nraska=1\n\n[settings]\nfullscreen=false\nreduced_motion=true\n"


func _initialize() -> void:
	var path := OS.get_temp_dir().path_join("torn-mission-progress-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	var passed := _check_progress(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")
	if passed:
		print("Verified mission progress persistence, replay idempotence, campaign isolation and legacy compatibility.")
	quit(0 if passed else 1)


func _check_progress(path: String) -> bool:
	var profile := Profile.new(path)
	if not profile.completed_missions("mara").is_empty() or FileAccess.file_exists(path):
		return _fail("Loading a fresh profile should not create a clear or write a file.")

	var fixture := FileAccess.open(path, FileAccess.WRITE)
	if fixture == null:
		return _fail("Failed to create the isolated legacy profile fixture.")
	fixture.store_string(LEGACY)
	fixture.close()
	profile = Profile.new(path)
	if not _check_legacy(profile):
		return _fail("A legacy profile no longer reads correctly.")
	if not profile.completed_missions("mara").is_empty():
		return _fail("Starting a campaign in the legacy data manufactured a mission clear.")

	if profile.mark_played("mara") != OK or not profile.completed_missions("mara").is_empty():
		return _fail("Opening a briefing manufactured a mission clear.")
	var before_clear := FileAccess.get_file_as_string(path)
	if profile.record_mission_clear("", "mine") != ERR_INVALID_PARAMETER:
		return _fail("Recording a clear without a campaign ID should be rejected.")
	if profile.record_mission_clear("mara", "  ") != ERR_INVALID_PARAMETER:
		return _fail("Recording a clear without a mission ID should be rejected.")
	if FileAccess.get_file_as_string(path) != before_clear:
		return _fail("An invalid clear changed the file.")

	if profile.record_mission_clear("mara", "mine") != OK:
		return _fail("The first explicit mission clear was not written.")
	var after_clear := FileAccess.get_file_as_string(path)
	if profile.record_mission_clear("mara", "mine") != OK or FileAccess.get_file_as_string(path) != after_clear:
		return _fail("Replaying a clear should not change the file.")
	if profile.completed_missions("mara") != PackedStringArray(["mine"]):
		return _fail("A replay added a duplicate clear.")
	if not profile.completed_missions("raska").is_empty():
		return _fail("A Human mission clear leaked into another campaign.")
	if profile.record_mission_clear("mara", "causeway") != OK or profile.record_mission_clear("raska", "mine") != OK:
		return _fail("An additional mission or another campaign's clear could not be stored.")

	profile = Profile.new(path)
	if not _check_legacy(profile):
		return _fail("Progress writes changed last-played ordering or settings.")
	if profile.completed_missions("mara") != PackedStringArray(["mine", "causeway"]):
		return _fail("The Human mission clears were not preserved when reopening the profile.")
	if profile.completed_missions("raska") != PackedStringArray(["mine"]):
		return _fail("The Orc mission clear was not preserved independently.")
	var returned := profile.completed_missions("mara")
	returned.append("not_cleared")
	if profile.completed_missions("mara").has("not_cleared"):
		return _fail("Mutating the returned list modified the profile's stored progress.")
	return true


func _check_legacy(profile: RefCounted) -> bool:
	return profile.saved_campaigns(CATALOG) == CATALOG and not profile.setting("fullscreen") and profile.setting("reduced_motion")


func _fail(message: String) -> bool:
	push_error(message)
	return false
