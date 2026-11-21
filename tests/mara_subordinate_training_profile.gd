extends SceneTree

const Store := preload("res://game/profile_store.gd")
const Training := preload("res://game/combat/mara_subordinate_training.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const SLOT := Training.SHIELD_INFANTRY_SLOT
const MINE := "mara_mine_escort"
const QUAY := "mara_moonwash_quay"
const TEST_PATH := "user://test_mara_subordinate_training_profile_%d.cfg"
var _failures := 0
var _path: String


func _initialize() -> void:
	_path = TEST_PATH % OS.get_process_id()
	_cleanup()
	_check_purchase_restore_and_replay()
	_check_invalid_or_missing_clear()
	_check_malformed_marker()
	_check_fresh_validation_and_failure()
	_cleanup()
	if _failures == 0:
		print("Mara shield drill profile: voluntary purchase, atomic rollback, legacy/reopen, preserved profile and fail-closed clears passed.")
	quit(0 if _failures == 0 else 1)


func _check_purchase_restore_and_replay() -> void:
	var legacy := Store.new(_path)
	_check(legacy.purchase_mara_shield_infantry_drill() == ERR_UNAUTHORIZED
		and not FileAccess.file_exists(_path), "A new profile has no entitlement and is not written by a denied purchase.")
	_check(legacy.mark_played("mara") == OK and legacy.set_setting("fullscreen", false) == OK
		and legacy.record_mission_clear("mara", MINE) == OK
		and legacy.record_grain_clear(Grain.SEED_ONLY) == OK
		and legacy.record_ilyra_moonwash_clear(Moonwash.CARGO_RECOVERED) == OK
		and legacy.record_intermission_seen("mara", &"water_request") == OK, "Build an old profile with actual mission facts but no drill marker.")
	var before := FileAccess.get_file_as_string(_path)
	var reopened := Store.new(_path)
	var draft := reopened.mara_shield_infantry_training()
	_check(_untrained(reopened, 1) and draft.train_formation_drill(SLOT)
		and _untrained(reopened, 1) and before == FileAccess.get_file_as_string(_path),
		"Old save is eligible but untrained; detached plan and repeat inspect are never an implicit purchase.")
	# Another store already wrote a setting and future unknown section after
	# this instance was opened: purchasing may not overwrite either.
	var newer := Store.new(_path)
	_check(newer.set_setting("fullscreen", true) == OK, "Second open profile changes a setting.")
	var newer_config := _read()
	newer_config.set_value("future_section", "kept", ["future field", 5])
	_check(newer_config.save(_path) == OK, "Seed an unknown future field to preserve.")
	var prior_sections := _read().get_sections()
	_check(reopened.purchase_mara_shield_infantry_drill() == OK and _trained(reopened),
		"Explicit purchase records rank 2 and optional eligibility in the currently open profile.")
	var after := Store.new(_path)
	var config := _read()
	_check(_trained(after) and after.setting("fullscreen") and reopened.setting("fullscreen")
		and after.grain_clear_result() == Grain.SEED_ONLY and after.ilyra_moonwash_clear_result() == Moonwash.CARGO_RECOVERED
		and after.has_seen_intermission("mara", &"water_request") and after.completed_missions("mara") == PackedStringArray([MINE, Grain.MISSION_ID])
		and config.get_value("future_section", "kept") == ["future field", 5]
		and config.get_value(Store.SUBORDINATE_TRAINING, Store.MARA_SHIELD_DRILL) is bool
		and config.get_sections().size() == prior_sections.size() + 1,
		"Reopen restores the purchase and leaves the newer setting, both published outcomes, progress and unknown field intact.")
	var purchased := FileAccess.get_file_as_string(_path)
	_check(after.purchase_mara_shield_infantry_drill() == ERR_ALREADY_IN_USE
		and legacy.purchase_mara_shield_infantry_drill() == ERR_ALREADY_IN_USE
		and after.record_mission_clear("mara", MINE) == OK and after.record_grain_clear(Grain.BOTH) == OK
		and after.record_ilyra_moonwash_clear(Moonwash.CREWS_ONLY) == OK and _trained(after)
		and purchased == FileAccess.get_file_as_string(_path),
		"Repeated purchase from either store and replay of each cleared result are byte-for-byte no-ops.")
	_check(after.record_mission_clear("mara", QUAY) == OK and _trained(Store.new(_path)),
		"Finishing a later mission retains the purchase without granting a second credit.")


func _check_invalid_or_missing_clear() -> void:
	for malformed: Variant in [MINE, [MINE], true,
			PackedStringArray([" " + MINE, MINE.to_upper(), "unknown", QUAY, Grain.MISSION_ID])]:
		var config := ConfigFile.new()
		config.set_value(Store.MISSION_PROGRESS, Store.MARA, malformed)
		config.set_value(Store.MISSION_PROGRESS, "raska", PackedStringArray([MINE]))
		config.set_value(Store.SUBORDINATE_TRAINING, Store.MARA_SHIELD_DRILL, true)
		config.set_value(Store.SETTINGS, "fullscreen", false)
		_check(config.save(_path) == OK, "Seed a malformed/foreign lookalike clear and forged purchase marker.")
		var before := FileAccess.get_file_as_string(_path)
		var profile := Store.new(_path)
		_check(_untrained(profile, 0) and profile.purchase_mara_shield_infantry_drill() == ERR_UNAUTHORIZED
			and not profile.setting("fullscreen") and before == FileAccess.get_file_as_string(_path),
			"Wrong type/ID/campaign or an out-of-order later clear cannot qualify, even with a saved true marker.")


func _check_malformed_marker() -> void:
	for marker: Variant in ["true", 1, 2, [true]]:
		var config := ConfigFile.new()
		config.set_value(Store.MISSION_PROGRESS, Store.MARA, PackedStringArray([MINE]))
		config.set_value(Store.SUBORDINATE_TRAINING, Store.MARA_SHIELD_DRILL, marker)
		_check(config.save(_path) == OK, "Seed an invalid persisted purchase type.")
		var before := FileAccess.get_file_as_string(_path)
		var profile := Store.new(_path)
		_check(_untrained(profile, 1) and profile.purchase_mara_shield_infantry_drill() == ERR_INVALID_DATA
			and before == FileAccess.get_file_as_string(_path), "Only a literal bool validates; do not normalize malformed data via purchase.")


func _check_fresh_validation_and_failure() -> void:
	var good := ConfigFile.new()
	good.set_value(Store.MISSION_PROGRESS, Store.MARA, PackedStringArray([MINE]))
	good.set_value(Store.SETTINGS, "fullscreen", false)
	_check(good.save(_path) == OK, "Save a genuine credit.")
	var store := Store.new(_path)
	var changed := ConfigFile.new()
	changed.set_value(Store.MISSION_PROGRESS, Store.MARA, PackedStringArray([QUAY, "unknown"]))
	changed.set_value(Store.SETTINGS, "fullscreen", false)
	_check(changed.save(_path) == OK, "Another open profile removes the genuine clear.")
	var no_clear := FileAccess.get_file_as_string(_path)
	_check(store.purchase_mara_shield_infantry_drill() == ERR_UNAUTHORIZED
		and no_clear == FileAccess.get_file_as_string(_path), "Never buy from a stale in-memory clear after replacement.")
	var broken := FileAccess.open(_path, FileAccess.WRITE)
	broken.store_string("[unterminated section\n")
	broken.close()
	var corrupt := FileAccess.get_file_as_string(_path)
	_check(store.purchase_mara_shield_infantry_drill() != OK and corrupt == FileAccess.get_file_as_string(_path),
		"An unreadable profile cannot be overwritten by a cached clear.")
	_check(good.save(_path) == OK, "Restore a genuine clear and settings before failure check.")
	var before := FileAccess.get_file_as_string(_path)
	var temporary_dir := ProjectSettings.globalize_path(_path + ".tmp")
	_check(DirAccess.make_dir_absolute(temporary_dir) == OK, "Make the existing atomic temp destination unwritable.")
	_check(store.purchase_mara_shield_infantry_drill() != OK and _untrained(store, 1)
		and _untrained(Store.new(_path), 1) and before == FileAccess.get_file_as_string(_path),
		"Failed atomic write leaves disk and current in-memory credit unchanged.")
	_check(DirAccess.remove_absolute(temporary_dir) == OK
		and store.purchase_mara_shield_infantry_drill() == OK and _trained(Store.new(_path)),
		"The explicit purchase can succeed after the failed transaction is unblocked.")


func _read() -> ConfigFile:
	var config := ConfigFile.new()
	_check(config.load(_path) == OK, "Load the written test profile.")
	return config


func _trained(profile: Store) -> bool:
	var plan := profile.mara_shield_infantry_training()
	return plan.formation_drill_rank(SLOT) == 2 and plan.available_drill_credit(SLOT) == 0 \
		and plan.qualifies_for_branch(SLOT, Training.BRANCH_UNIT) and plan.default_unit_type(SLOT) == Training.DEFAULT_UNIT


func _untrained(profile: Store, credit: int) -> bool:
	var plan := profile.mara_shield_infantry_training()
	return plan.formation_drill_rank(SLOT) == 1 and plan.available_drill_credit(SLOT) == credit \
		and not plan.qualifies_for_branch(SLOT, Training.BRANCH_UNIT) and plan.default_unit_type(SLOT) == Training.DEFAULT_UNIT


func _cleanup() -> void:
	for entry in [_path, _path + ".tmp"]:
		var path := ProjectSettings.globalize_path(entry)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
