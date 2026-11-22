extends SceneTree

const Store := preload("res://game/profile_store.gd")
const Training := preload("res://game/combat/mara_subordinate_training.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Progress := preload("res://game/combat/campaign_platoon_progress.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const MINE := Training.QUALIFYING_CLEAR
const SLOT := Training.SHIELD_INFANTRY_SLOT
const STATUS := Store.MaraShieldMeleeStatus

var _path: String
var _failures := 0


func _initialize() -> void:
	_path = OS.get_temp_dir().path_join("torn-shield-barracks-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	_check_legacy_and_real_first_win()
	_check_fresh_deploy_view()
	_check_failed_transaction()
	for entry in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(entry) or DirAccess.dir_exists_absolute(entry):
			DirAccess.remove_absolute(entry)
	if _failures == 0:
		print("Mara Shield Barracks: physical rescue, durable single point, legacy drill, coherent launch view, corrupt saves and rollback passed.")
	quit(0 if _failures == 0 else 1)


func _check_legacy_and_real_first_win() -> void:
	var store := Store.new(_path)
	var empty := store.mara_shield_barracks_state()
	_check(empty.error == ERR_FILE_NOT_FOUND and _unearned(empty)
		and not empty.heavy_authorized and store.invest_mara_shield_melee_point() == ERR_UNAUTHORIZED
		and not FileAccess.file_exists(_path), "Looking at a new Barracks or requesting a locked investment is read-only.")
	var world := store.load_campaign_world("mara")
	_check(store.mark_played("mara") == OK
		and world.travel_to("year_one_mine", PackedStringArray()) == world.TravelResult.ARRIVED
		and store.record_world_waypoint(world) == OK
		and store.record_mission_clear("raska", MINE) == OK,
		"Set up a visit and a foreign clear without any Human rescue.")
	_check(_unearned(store.mara_shield_barracks_state()), "A visit and foreign clear give no Shield XP.")

	_check(store.record_mission_clear("mara", MINE) == OK
		and store.purchase_mara_shield_infantry_drill() == OK,
		"An archived legacy clear still buys the existing independent drill.")
	var legacy := store.mara_shield_barracks_state()
	var legacy_bytes := FileAccess.get_file_as_bytes(_path)
	_check(_unearned(legacy) and legacy.heavy_authorized and legacy.training.formation_drill_rank(SLOT) == 2
		and store.invest_mara_shield_melee_point() == ERR_UNAUTHORIZED
		and FileAccess.get_file_as_bytes(_path) == legacy_bytes,
		"Legacy Heavy replay works, but the shared archived clear ID does not grant the new point.")

	_check(store.record_greyhollow_rescue_clear() == OK and store.greyhollow_reveal_pending(),
		"A first actual rescue on that legacy profile queues the rescue's reveal normally.")
	var pending := store.mara_shield_barracks_state()
	var pending_bytes := FileAccess.get_file_as_bytes(_path)
	_check(pending.total_xp == Progress.XP_PER_FIRST_CLEAR and pending.level == 2
		and pending.xp_in_level == 0 and pending.next_level_xp == Unit.FIRST_LEVEL_XP + Unit.LEVEL_XP_STEP
		and pending.heavy_authorized and pending.melee_status == STATUS.LOCKED
		and store.invest_mara_shield_melee_point() == ERR_UNAUTHORIZED
		and FileAccess.get_file_as_bytes(_path) == pending_bytes,
		"The real win grants XP once, but an unresolved reveal still prohibits a new allocation.")
	_check(store.finish_greyhollow_reveal() == OK and store.greyhollow_reveal_completed(),
		"Complete the reveal through the normal save API.")
	var ready := store.mara_shield_barracks_state()
	_check(ready.melee_status == STATUS.AVAILABLE and ready.melee_rating == Unit.MIN_RATING
		and ready.remaining_melee_points == 1 and ready.confirmed_clears == PackedStringArray([MINE]),
		"One earned point waits for a separate explicit choice.")

	var newer := _read()
	newer.set_value(Store.SETTINGS, "fullscreen", false)
	newer.set_value(Store.SUBORDINATE_STAT_ALLOCATIONS, "future_other_slot", [7, "keep"])
	_check(newer.save(_path) == OK and store.invest_mara_shield_melee_point() == OK,
		"Saving the point uses the current file even if an open instance predates later changes.")
	var reopened := Store.new(_path)
	var trained := reopened.mara_shield_barracks_state()
	var invested := _read()
	_check(_invested(trained) and trained.heavy_authorized and not reopened.setting("fullscreen")
		and invested.get_value(Store.SUBORDINATE_STAT_ALLOCATIONS, Store.MARA_SHIELD_MELEE, false) is bool
		and invested.get_value(Store.SUBORDINATE_STAT_ALLOCATIONS, Store.MARA_SHIELD_MELEE, false),
		"Reload restores the one saved Melee point, existing branch, and newer setting.")
	invested.erase_section_key(Store.SUBORDINATE_STAT_ALLOCATIONS, Store.MARA_SHIELD_MELEE)
	_check(invested.encode_to_text() == newer.encode_to_text(),
		"The investment adds exactly one durable key without rewriting other profile facts.")
	var committed := FileAccess.get_file_as_bytes(_path)
	_check(store.invest_mara_shield_melee_point() == ERR_ALREADY_IN_USE
		and reopened.invest_mara_shield_melee_point() == ERR_ALREADY_IN_USE
		and reopened.record_greyhollow_rescue_clear() == OK and reopened.finish_greyhollow_reveal() == OK
		and FileAccess.get_file_as_bytes(_path) == committed,
		"Repeat purchase, victory and reveal are byte-for-byte no-ops.")
	_check(reopened.record_grain_clear(Grain.SEED_ONLY) == OK
		and reopened.record_mission_clear("mara", "mara_moonwash_quay") == OK
		and _invested(reopened.mara_shield_barracks_state()),
		"Later missions do not identify the Mine platoon by formation index or mint another point.")
	trained.melee_rating = 99
	trained.confirmed_clears.clear()
	_check(_invested(reopened.mara_shield_barracks_state()), "Mutating one detached launch view cannot affect the next.")


func _check_fresh_deploy_view() -> void:
	var warm := Store.new(_path)
	var valid := _read()
	var first := warm.mara_shield_barracks_state()
	_check(first.heavy_authorized and _invested(first), "Start with the previously authorized branch and rating.")
	var replaced := _read()
	replaced.erase_section_key(Store.SUBORDINATE_TRAINING, Store.MARA_SHIELD_DRILL)
	replaced.set_value(Store.SUBORDINATE_STAT_ALLOCATIONS, Store.MARA_SHIELD_MELEE, "true")
	_check(replaced.save(_path) == OK, "Simulate a profile changed after the briefing showed the branch.")
	var bad_marker := warm.mara_shield_barracks_state()
	var before := FileAccess.get_file_as_bytes(_path)
	_check(not bad_marker.heavy_authorized and bad_marker.melee_rating == Unit.MIN_RATING
		and bad_marker.melee_status == STATUS.UNAVAILABLE
		and warm.invest_mara_shield_melee_point() == ERR_INVALID_DATA and FileAccess.get_file_as_bytes(_path) == before,
		"A fresh view refuses a removed branch and malformed point without repairing either.")
	replaced.set_value(Store.MISSION_PROGRESS, Store.MARA, PackedStringArray([Grain.MISSION_ID]))
	replaced.set_value(Store.SUBORDINATE_TRAINING, Store.MARA_SHIELD_DRILL, true)
	replaced.set_value(Store.SUBORDINATE_STAT_ALLOCATIONS, Store.MARA_SHIELD_MELEE, true)
	_check(replaced.save(_path) == OK, "Keep both markers and the reveal but remove the actual rescue clear.")
	var no_clear := warm.mara_shield_barracks_state()
	_check(_unearned(no_clear) and not no_clear.heavy_authorized
		and warm.invest_mara_shield_melee_point() == ERR_UNAUTHORIZED and _invested(first) and first.heavy_authorized,
		"Neither marker outranks a revoked clear; an already-started attempt keeps its detached view.")
	var broken := FileAccess.open(_path, FileAccess.WRITE)
	broken.store_string("[unterminated section\n")
	broken.close()
	before = FileAccess.get_file_as_bytes(_path)
	var unreadable := warm.mara_shield_barracks_state()
	_check(unreadable.error != OK and not unreadable.heavy_authorized
		and unreadable.melee_status == STATUS.UNAVAILABLE and unreadable.melee_rating == Unit.MIN_RATING
		and warm.invest_mara_shield_melee_point() != OK and FileAccess.get_file_as_bytes(_path) == before,
		"An unreadable profile fails closed and is not replaced from the warm cache.")
	_check(valid.save(_path) == OK, "Restore the profile for the atomic save check.")


func _check_failed_transaction() -> void:
	var clean := _read()
	clean.erase_section_key(Store.SUBORDINATE_STAT_ALLOCATIONS, Store.MARA_SHIELD_MELEE)
	_check(clean.save(_path) == OK and DirAccess.make_dir_absolute(_path + ".tmp") == OK,
		"Make an otherwise eligible profile unwritable to the atomic save path.")
	var store := Store.new(_path)
	var before := FileAccess.get_file_as_bytes(_path)
	_check(store.invest_mara_shield_melee_point() != OK
		and store.mara_shield_barracks_state().melee_status == STATUS.AVAILABLE
		and Store.new(_path).mara_shield_barracks_state().remaining_melee_points == 1
		and FileAccess.get_file_as_bytes(_path) == before,
		"An atomic write failure spends nothing in either the current or reopened profile.")
	_check(DirAccess.remove_absolute(_path + ".tmp") == OK and store.invest_mara_shield_melee_point() == OK
		and _invested(Store.new(_path).mara_shield_barracks_state()),
		"The same explicit choice can succeed when the profile is writable.")


func _unearned(state: Store.MaraShieldBarracksState) -> bool:
	return state.total_xp == 0 and state.level == 1 and state.melee_rating == Unit.MIN_RATING \
		and state.remaining_melee_points == 0 and state.melee_status == STATUS.LOCKED


func _invested(state: Store.MaraShieldBarracksState) -> bool:
	return state.total_xp == Progress.XP_PER_FIRST_CLEAR and state.level == 2 \
		and state.melee_rating == Unit.MIN_RATING + 1 and state.remaining_melee_points == 0 \
		and state.melee_status == STATUS.INVESTED


func _read() -> ConfigFile:
	var config := ConfigFile.new()
	_check(config.load(_path) == OK, "Read the test profile.")
	return config


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
