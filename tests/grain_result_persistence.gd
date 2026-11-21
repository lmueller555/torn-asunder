extends SceneTree

const Profile := preload("res://game/profile_store.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const MARA := "mara"
const MINE := "mara_mine_escort"


func _initialize() -> void:
	var base := OS.get_temp_dir().path_join("torn-grain-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var passed := _check_first_result(base + "-seed.cfg")
	passed = _check_bread_and_rejection(base + "-bread.cfg") and passed
	passed = _check_failed_commit(base + "-failure.cfg") and passed
	passed = _check_legacy_and_orphan(base + "-legacy.cfg") and passed
	for suffix in ["-seed.cfg", "-bread.cfg", "-failure.cfg", "-legacy.cfg"]:
		var path: String = base + suffix
		for candidate in [path, path + ".tmp", path + ".bak"]:
			if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
				DirAccess.remove_absolute(candidate)
	if passed:
		print("Verified first Grain result, independent replays, valid loads, legacy data, and atomic rollback.")
	quit(0 if passed else 1)


func _check_first_result(path: String) -> bool:
	var profile := Profile.new(path)
	if profile.record_mission_clear(MARA, MINE) != OK or profile.set_setting("reduced_motion", true) != OK:
		return _fail("Could not initialize an existing Mara save.")
	if profile.record_grain_clear(_grain_result(true, false)) != OK:
		return _fail("The original seed-only result was not committed.")
	var first_file := FileAccess.get_file_as_string(path)
	profile = Profile.new(path)
	if profile.grain_clear_result() != Grain.SEED_ONLY or profile.completed_missions(MARA) != PackedStringArray([MINE, Grain.MISSION_ID]):
		return _fail("Reload did not contain both the original result and its clear.")
	if not profile.setting("reduced_motion") or not profile.completed_missions("raska").is_empty():
		return _fail("The first result changed settings or another campaign.")
	if profile.record_grain_clear(_grain_result(true, true)) != OK or profile.grain_clear_result() != Grain.SEED_ONLY:
		return _fail("Replaying with both loads replaced the original seed-only result.")
	if Profile.new(path).grain_clear_result() != Grain.SEED_ONLY or FileAccess.get_file_as_string(path) != first_file:
		return _fail("A different-result replay rewrote the campaign on disk.")
	return true


func _check_bread_and_rejection(path: String) -> bool:
	var profile := Profile.new(path)
	for invalid: StringName in [&"unknown", &"refused", &"BOTH", _grain_result(false, false)]:
		if profile.record_grain_clear(invalid) != ERR_INVALID_PARAMETER:
			return _fail("An unknown, cancelled, or no-delivery result was accepted.")
	if profile.record_mission_clear(MARA, Grain.MISSION_ID) != ERR_INVALID_PARAMETER:
		return _fail("The generic mission method allowed a new clear without its delivery result.")
	if FileAccess.file_exists(path) or not profile.completed_missions(MARA).is_empty() or profile.grain_clear_result() != &"":
		return _fail("A rejected Grain result changed memory or created a profile file.")
	if profile.record_grain_clear(_grain_result(false, true)) != OK:
		return _fail("A fresh bread-only run could not be persisted.")
	profile = Profile.new(path)
	if profile.grain_clear_result() != Grain.BREAD_ONLY or profile.completed_missions(MARA) != PackedStringArray([Grain.MISSION_ID]):
		return _fail("Bread-only did not reload distinctly on its own profile.")
	return true


func _check_failed_commit(path: String) -> bool:
	var profile := Profile.new(path)
	if profile.record_mission_clear(MARA, MINE) != OK or profile.set_setting("fullscreen", false) != OK:
		return _fail("Could not initialize a profile for the rollback test.")
	var first_file := FileAccess.get_file_as_string(path)
	if DirAccess.rename_absolute(path, path + ".bak") != OK or DirAccess.make_dir_absolute(path) != OK:
		return _fail("Could not arrange for the final rename to fail.")
	var result := profile.record_grain_clear(Grain.BOTH)
	if result == OK or FileAccess.file_exists(path + ".tmp"):
		return _fail("A failed commit succeeded or left a temporary file.")
	if profile.completed_missions(MARA) != PackedStringArray([MINE]) or profile.grain_clear_result() != &"" or profile.setting("fullscreen"):
		return _fail("A failed commit left a partial clear, result or setting change in memory.")
	if DirAccess.remove_absolute(path) != OK or DirAccess.rename_absolute(path + ".bak", path) != OK:
		return _fail("Could not restore the isolated original file.")
	if FileAccess.get_file_as_string(path) != first_file or Profile.new(path).grain_clear_result() != &"":
		return _fail("A failed commit changed the original profile on disk.")
	if profile.set_setting("reduced_motion", true) != OK:
		return _fail("An unrelated settings save failed after rollback.")
	var disk := ConfigFile.new()
	if disk.load(path) != OK or disk.has_section_key(Profile.MISSION_RESULTS, Grain.MISSION_ID):
		return _fail("A failed write left an orphan result for a later save to publish.")
	if profile.record_grain_clear(Grain.BOTH) != OK or Profile.new(path).grain_clear_result() != Grain.BOTH:
		return _fail("A failed write prevented a later successful retry.")
	return true


func _check_legacy_and_orphan(path: String) -> bool:
	var fixture := ConfigFile.new()
	fixture.set_value(Profile.MISSION_PROGRESS, MARA, PackedStringArray([Grain.MISSION_ID]))
	if fixture.save(path) != OK:
		return _fail("Could not make the legacy profile.")
	var before := FileAccess.get_file_as_string(path)
	var profile := Profile.new(path)
	if profile.grain_clear_result() != &"" or not profile.completed_missions(MARA).has(Grain.MISSION_ID):
		return _fail("A legacy clear was invalidated or assigned a fabricated result.")
	if profile.record_grain_clear(Grain.BOTH) != OK or FileAccess.get_file_as_string(path) != before:
		return _fail("A replay fabricated the missing result for a legacy clear.")
	fixture.erase_section(Profile.MISSION_PROGRESS)
	fixture.set_value(Profile.MISSION_RESULTS, Grain.MISSION_ID, "both")
	if fixture.save(path) != OK or Profile.new(path).grain_clear_result() != &"":
		return _fail("A result key without a mission clear was treated as valid saved history.")
	return true


func _grain_result(seed_delivers: bool, bread_delivers: bool) -> StringName:
	var model := Grain.new()
	var dispatch := Grain.Observation.new()
	dispatch.seed.dispatch_ordered = true
	dispatch.bread.dispatch_ordered = true
	model.advance(dispatch)
	var resolved := Grain.Observation.new()
	resolved.seed.at_receiving_yard = seed_delivers
	resolved.seed.turn_back_ordered = not seed_delivers
	resolved.bread.at_receiving_yard = bread_delivers
	resolved.bread.turn_back_ordered = not bread_delivers
	model.advance(resolved)
	return model.clear_result


func _fail(message: String) -> bool:
	push_error(message)
	return false
