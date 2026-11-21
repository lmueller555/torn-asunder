extends SceneTree

const Store := preload("res://game/profile_store.gd")
const World := preload("res://game/campaign_world.gd")
const Training := preload("res://game/combat/mara_subordinate_training.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const MINE := "mara_mine_escort"
const QUAY := "mara_moonwash_quay"
const SLOT := Training.SHIELD_INFANTRY_SLOT

var _path: String
var _failures := 0


func _initialize() -> void:
	_path = OS.get_temp_dir().path_join("torn-mara-lead-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	_check_one_point_and_existing_profile()
	_check_invalid_records()
	_check_fresh_validation_and_rollback()
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	if _failures == 0:
		print("Mara lead melee profile: optional one-point investment, campaign isolation, stale and invalid saves, replay, atomic rollback and independent Shield drill passed.")
	quit(0 if _failures == 0 else 1)


func _check_one_point_and_existing_profile() -> void:
	var blank := Store.new(_path)
	_check(not blank.mara_lead_melee_invested() and blank.invest_mara_lead_melee_point() == ERR_UNAUTHORIZED
		and not FileAccess.file_exists(_path), "Reading or requesting training on a blank profile must not create a save.")
	var world := blank.load_campaign_world("mara")
	_check(blank.mark_played("mara") == OK and blank.set_setting("fullscreen", false) == OK
		and world.travel_to("year_one_mine", PackedStringArray()) == World.TravelResult.ARRIVED
		and blank.record_world_waypoint(world) == OK, "Create a normal profile and visit the Mine without clearing.")
	var visited := FileAccess.get_file_as_bytes(_path)
	_check(blank.invest_mara_lead_melee_point() == ERR_UNAUTHORIZED
		and FileAccess.get_file_as_bytes(_path) == visited, "Visits alone must not earn the point.")
	var legacy := Store.new(_path)
	_check(legacy.record_mission_clear("mara", MINE) == OK
		and legacy.record_ilyra_moonwash_clear(Moonwash.CARGO_RECOVERED) == OK,
		"Save the first Mine clear and an independent result through the existing APIs.")
	var prior := FileAccess.get_file_as_bytes(_path)
	_check(not legacy.mara_lead_melee_invested() and not Store.new(_path).mara_lead_melee_invested()
		and FileAccess.get_file_as_bytes(_path) == prior, "Neither first clear nor reopening a legacy save should spend automatically.")

	var latest := _read()
	latest.set_value(Store.SETTINGS, "fullscreen", true)
	latest.set_value(Store.LEAD_TRAINING, "future_field", ["retain", 9])
	_check(latest.save(_path) == OK, "Seed newer existing settings and an unknown field in the same section.")
	# This instance opened before the real clear or the new setting; investment must read the current file.
	_check(blank.invest_mara_lead_melee_point() == OK and blank.mara_lead_melee_invested()
		and blank.setting("fullscreen"), "Saving after exactly one confirmed Mine clear must retain a newer snapshot.")
	var persisted := _read()
	_check(persisted.get_value(Store.LEAD_TRAINING, Store.MARA_LEAD_MELEE, false) == true,
		"The sole new save value records a literal one-point choice.")
	persisted.erase_section_key(Store.LEAD_TRAINING, Store.MARA_LEAD_MELEE)
	_check(persisted.encode_to_text() == latest.encode_to_text(), "The transaction must not modify any other saved data.")

	var reopened := Store.new(_path)
	var training := reopened.mara_shield_infantry_training()
	_check(reopened.mara_lead_melee_invested() and reopened.load_campaign_world("mara").current_waypoint_id() == "year_one_mine"
		and reopened.ilyra_moonwash_clear_result() == Moonwash.CARGO_RECOVERED
		and training.available_drill_credit(SLOT) == 1 and training.formation_drill_rank(SLOT) == 1,
		"The choice survives reopening and neither consumes nor grants Shield Infantry training.")
	var saved := FileAccess.get_file_as_bytes(_path)
	_check(blank.invest_mara_lead_melee_point() == ERR_ALREADY_IN_USE
		and legacy.invest_mara_lead_melee_point() == ERR_ALREADY_IN_USE
		and reopened.record_mission_clear("mara", MINE) == OK
		and FileAccess.get_file_as_bytes(_path) == saved, "Repeated requests (including a stale instance) and replay must not write or grant again.")

	_check(reopened.purchase_mara_shield_infantry_drill() == OK
		and reopened.record_grain_clear(Grain.SEED_ONLY) == OK and reopened.record_mission_clear("mara", QUAY) == OK,
		"Independent Shield training and later first clears still write normally.")
	var finished := Store.new(_path)
	_check(finished.mara_lead_melee_invested() and finished.grain_clear_result() == Grain.SEED_ONLY
		and finished.mara_shield_infantry_training().formation_drill_rank(SLOT) == 2
		and finished.invest_mara_lead_melee_point() == ERR_ALREADY_IN_USE,
		"Neither Shield training nor later chapter budget expands this one-point path.")


func _check_invalid_records() -> void:
	for clears: Variant in [MINE, [MINE], PackedStringArray([Grain.MISSION_ID, QUAY, " " + MINE, MINE.to_upper()])]:
		var forged := ConfigFile.new()
		forged.set_value(Store.MISSION_PROGRESS, "mara", clears)
		forged.set_value(Store.MISSION_PROGRESS, "raska", PackedStringArray([MINE]))
		forged.set_value(Store.LEAD_TRAINING, Store.MARA_LEAD_MELEE, true)
		_check(forged.save(_path) == OK, "Seed an unqualified record even though a foreign route or marker exists.")
		var before := FileAccess.get_file_as_bytes(_path)
		var profile := Store.new(_path)
		_check(not profile.mara_lead_melee_invested() and profile.invest_mara_lead_melee_point() == ERR_UNAUTHORIZED
			and FileAccess.get_file_as_bytes(_path) == before, "Foreign, out-of-order and malformed clears cannot authorize or restore a point.")
	for marker: Variant in ["true", 1, 2, [true]]:
		var malformed := _eligible_record()
		malformed.set_value(Store.LEAD_TRAINING, Store.MARA_LEAD_MELEE, marker)
		_check(malformed.save(_path) == OK, "Seed an invalid stored investment value.")
		var before := FileAccess.get_file_as_bytes(_path)
		var profile := Store.new(_path)
		_check(not profile.mara_lead_melee_invested() and profile.invest_mara_lead_melee_point() == ERR_INVALID_DATA
			and FileAccess.get_file_as_bytes(_path) == before, "Do not restore or silently normalize an invalid investment.")


func _check_fresh_validation_and_rollback() -> void:
	var eligible := _eligible_record()
	_check(eligible.save(_path) == OK, "Save an eligible start for the stale-profile test.")
	var stale := Store.new(_path)
	var replacement := ConfigFile.new()
	replacement.set_value(Store.MISSION_PROGRESS, "mara", PackedStringArray([QUAY]))
	_check(replacement.save(_path) == OK, "Replace the profile with one without the real Mine clear.")
	var before := FileAccess.get_file_as_bytes(_path)
	_check(stale.invest_mara_lead_melee_point() == ERR_UNAUTHORIZED and FileAccess.get_file_as_bytes(_path) == before,
		"A stale cached Mine clear must not authorize a point in a replaced profile.")
	_check(eligible.save(_path) == OK and DirAccess.make_dir_absolute(_path + ".tmp") == OK,
		"Restore clear but make the atomic temporary path unwritable.")
	before = FileAccess.get_file_as_bytes(_path)
	_check(stale.invest_mara_lead_melee_point() != OK and not stale.mara_lead_melee_invested()
		and not Store.new(_path).mara_lead_melee_invested() and FileAccess.get_file_as_bytes(_path) == before,
		"Failed atomic write must leave memory and the current profile unchanged.")
	_check(DirAccess.remove_absolute(_path + ".tmp") == OK and stale.invest_mara_lead_melee_point() == OK
		and Store.new(_path).mara_lead_melee_invested(), "An explicit retry can succeed once the save is writable.")
	replacement.set_value(Store.LEAD_TRAINING, Store.MARA_LEAD_MELEE, true)
	_check(replacement.save(_path) == OK and not stale.mara_lead_melee_invested(),
		"Replacing an invested profile must not leave a valid-looking choice in a previously opened reader.")


func _eligible_record() -> ConfigFile:
	var saved := ConfigFile.new()
	saved.set_value(Store.MISSION_PROGRESS, "mara", PackedStringArray([MINE]))
	saved.set_value(Store.SETTINGS, "fullscreen", false)
	return saved


func _read() -> ConfigFile:
	var saved := ConfigFile.new()
	_check(saved.load(_path) == OK, "Reload the fixture config.")
	return saved


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
