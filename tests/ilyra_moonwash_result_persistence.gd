extends SceneTree

const Profile := preload("res://game/profile_store.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const ILYRA := "ilyra"


func _initialize() -> void:
	var base := OS.get_temp_dir().path_join("torn-moonwash-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var passed := _check_first_result(base + "-first.cfg")
	passed = _check_failed_commit(base + "-failure.cfg") and passed
	passed = _check_legacy(base + "-legacy.cfg") and passed
	for suffix in ["-first.cfg", "-failure.cfg", "-legacy.cfg"]:
		var path: String = base + suffix
		for candidate in [path, path + ".tmp", path + ".bak"]:
			if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
				DirAccess.remove_absolute(candidate)
	if passed:
		print("Verified original Moonwash provisions, replay, validation, campaign isolation, and atomic rollback.")
	quit(0 if passed else 1)


func _check_first_result(path: String) -> bool:
	var profile := Profile.new(path)
	for invalid: StringName in [&"unknown", &"refused", Grain.BOTH, _moonwash_result(true, true)]:
		if profile.record_ilyra_moonwash_clear(invalid) != ERR_INVALID_PARAMETER:
			return _fail("An unknown or unsuccessful rescue result produced a saved clear.")
	if profile.record_mission_clear(ILYRA, Moonwash.MISSION_ID) != ERR_INVALID_PARAMETER or FileAccess.file_exists(path):
		return _fail("The generic clear admission bypassed Moonwash validation.")
	if profile.record_grain_clear(Grain.SEED_ONLY) != OK or profile.record_mission_clear("sova", "sova_mine_tunnels") != OK:
		return _fail("Could not prepare unrelated campaign progress.")
	if profile.ilyra_moonwash_clear_result() != &"" or not profile.completed_missions(ILYRA).is_empty():
		return _fail("Another campaign acquired a Moonwash result.")
	if profile.record_ilyra_moonwash_clear(_moonwash_result(false)) != OK:
		return _fail("Could not save the first crews-only clear.")
	var first_file := FileAccess.get_file_as_string(path)
	profile = Profile.new(path)
	if profile.ilyra_moonwash_clear_result() != Moonwash.CREWS_ONLY or profile.completed_missions(ILYRA) != PackedStringArray([Moonwash.MISSION_ID]):
		return _fail("Reload did not retain both the first clear and its original result.")
	if profile.record_ilyra_moonwash_clear(_moonwash_result(true)) != OK or profile.ilyra_moonwash_clear_result() != Moonwash.CREWS_ONLY:
		return _fail("Recovering cargo on replay replaced the original need to borrow stores.")
	if FileAccess.get_file_as_string(path) != first_file or Profile.new(path).ilyra_moonwash_clear_result() != Moonwash.CREWS_ONLY:
		return _fail("A different-result replay rewrote the saved mission.")
	if profile.grain_clear_result() != Grain.SEED_ONLY or profile.completed_missions("sova") != PackedStringArray(["sova_mine_tunnels"]):
		return _fail("Moonwash persistence changed another campaign's save.")
	return true


func _check_failed_commit(path: String) -> bool:
	var profile := Profile.new(path)
	if profile.set_setting("reduced_motion", true) != OK:
		return _fail("Could not prepare the failure fixture's unrelated setting.")
	var before := FileAccess.get_file_as_string(path)
	if DirAccess.rename_absolute(path, path + ".bak") != OK or DirAccess.make_dir_absolute(path) != OK:
		return _fail("Could not arrange for the profile's final rename to fail.")
	if profile.record_ilyra_moonwash_clear(_moonwash_result(true)) == OK or FileAccess.file_exists(path + ".tmp"):
		return _fail("A failed commit succeeded or left its temporary file.")
	if not profile.completed_missions(ILYRA).is_empty() or profile.ilyra_moonwash_clear_result() != &"" or not profile.setting("reduced_motion"):
		return _fail("The failed rename left a partial clear or altered unrelated settings.")
	if DirAccess.remove_absolute(path) != OK or DirAccess.rename_absolute(path + ".bak", path) != OK or FileAccess.get_file_as_string(path) != before:
		return _fail("The original profile did not survive the blocked commit.")
	if profile.set_setting("fullscreen", false) != OK:
		return _fail("An unrelated write failed after rolling back.")
	var disk := ConfigFile.new()
	if disk.load(path) != OK or disk.has_section_key(Profile.MISSION_RESULTS, Moonwash.MISSION_ID):
		return _fail("An unrelated later save published a stale Moonwash result.")
	if profile.record_ilyra_moonwash_clear(_moonwash_result(true)) != OK or Profile.new(path).ilyra_moonwash_clear_result() != Moonwash.CARGO_RECOVERED:
		return _fail("A fresh cargo-recovered outcome did not survive an independent save.")
	return true


func _check_legacy(path: String) -> bool:
	var legacy := ConfigFile.new()
	legacy.set_value(Profile.MISSION_PROGRESS, ILYRA, PackedStringArray([Moonwash.MISSION_ID]))
	if legacy.save(path) != OK:
		return _fail("Could not create the legacy cleared profile.")
	var before := FileAccess.get_file_as_string(path)
	var profile := Profile.new(path)
	if profile.ilyra_moonwash_clear_result() != &"" or not profile.completed_missions(ILYRA).has(Moonwash.MISSION_ID):
		return _fail("A missing legacy result fabricated provisions or erased the clear.")
	if profile.record_ilyra_moonwash_clear(Moonwash.CARGO_RECOVERED) != OK or FileAccess.get_file_as_string(path) != before:
		return _fail("A replay assigned an unknown original result to a legacy clear.")
	legacy.erase_section(Profile.MISSION_PROGRESS)
	legacy.set_value(Profile.MISSION_RESULTS, Moonwash.MISSION_ID, String(Moonwash.CARGO_RECOVERED))
	if legacy.save(path) != OK or Profile.new(path).ilyra_moonwash_clear_result() != &"":
		return _fail("An orphan result without an Ilyra clear was treated as valid history.")
	return true


func _moonwash_result(cargo: bool, hero_falls := false) -> StringName:
	var rescue := Moonwash.new()
	for transfer in [Moonwash.Transfer.FORWARD, Moonwash.Transfer.AFT]:
		var rig := Moonwash.Observation.new()
		rig.hero_rigged_transfer = transfer
		rescue.advance(rig)
	var arrival := Moonwash.Observation.new()
	arrival.forward.crew_at_receiving_deck = true
	arrival.aft.crew_at_receiving_deck = true
	arrival.cargo_at_receiving_deck = cargo
	arrival.hero_fell = hero_falls
	rescue.advance(arrival)
	return rescue.clear_result


func _fail(message: String) -> bool:
	push_error(message)
	return false
