extends RefCounted

const World := preload("res://game/campaign_world.gd")
const Beats := preload("res://game/campaign_dialogues.gd")
const Training := preload("res://game/combat/mara_subordinate_training.gd")
const LeadProgress := preload("res://game/combat/campaign_platoon_progress.gd")
const MissionXP := preload("res://game/combat/campaign_mission_experience.gd")
const MaraStarting := preload("res://game/combat/mara_campaign_starting_platoons.gd")
const LeadAllocation := preload("res://game/combat/campaign_stat_allocation.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")

const PATH := "user://profile.cfg"
const CAMPAIGNS := "campaigns"
const CAMPAIGN_STARTING_LOADOUT := "campaign_starting_loadout"
const MARA_STARTING_LOADOUT_V1 := 1
const MISSION_PROGRESS := "mission_progress"
const MISSION_RESULTS := "mission_results"
const CAMPAIGN_INTERMISSIONS := "campaign_intermissions"
const SUBORDINATE_TRAINING := "subordinate_training"
const MARA_SHIELD_DRILL := "mara_shield_infantry_formation_drill"
const SUBORDINATE_STAT_ALLOCATIONS := "subordinate_stat_allocations"
const MARA_SHIELD_MELEE := "mara_shield_infantry_melee_point"
const LEAD_TRAINING := "lead_training"
const MARA_LEAD_MELEE := "mara_mine_melee_point"
const MARA := "mara"
const MARA_MINE := "mara_mine_escort"
const GREYHOLLOW_REVEAL_PENDING := "greyhollow_reveal_pending"
const CAMPAIGN_COMBAT_XP := "campaign_combat_xp"
const GREYHOLLOW_XP_RECAP := "greyhollow_xp_recap"
const CAMPAIGN_WAYPOINTS := "campaign_waypoints"
const SETTINGS := "settings"
const ILYRA := "ilyra"

enum MaraLeadMeleeStatus { LOCKED, AVAILABLE, INVESTED, UNAVAILABLE }
enum MaraShieldMeleeStatus { LOCKED, AVAILABLE, INVESTED, UNAVAILABLE }


class MaraShieldBarracksState:
	var error: Error = OK
	var confirmed_clears := PackedStringArray()
	var training: Training
	var heavy_authorized := false
	var reveal_completed := false
	var total_xp := 0
	var level := 1
	var xp_in_level := 0
	var next_level_xp := Unit.FIRST_LEVEL_XP
	var melee_rating := Unit.MIN_RATING
	var remaining_melee_points := 0
	var melee_status := MaraShieldMeleeStatus.LOCKED

var _config := ConfigFile.new()
var _path: String


func _init(path: String = PATH) -> void:
	_path = path
	var result := _config.load(_path)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		push_warning("Could not read the Torn Asunder profile (error %d)." % result)
		_config.clear()


func saved_campaigns(catalog: Array[Dictionary]) -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for campaign in catalog:
		if _config.has_section_key(CAMPAIGNS, campaign.id):
			saves.append(campaign)
	saves.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _saved_order(first.id) > _saved_order(second.id)
	)
	return saves


func mark_played(id: String, begin_new := false) -> Error:
	# Selection and the versioned starting build are one save transaction.
	# A re-opened title or a replay cannot retrofit an existing save.
	var latest := ConfigFile.new()
	var read := latest.load(_path)
	if read not in [OK, ERR_FILE_NOT_FOUND]:
		return read
	var sequence := 0
	if latest.has_section(CAMPAIGNS):
		for key in latest.get_section_keys(CAMPAIGNS):
			var order: Variant = latest.get_value(CAMPAIGNS, key)
			if order is int:
				sequence = maxi(sequence, order)
	var values := {CAMPAIGNS: {id: sequence + 1}}
	if begin_new and id == MARA and not _has_mara_campaign_record(latest):
		values[CAMPAIGN_STARTING_LOADOUT] = {MARA: MARA_STARTING_LOADOUT_V1}
	return _set_values(values, latest)


func _has_mara_campaign_record(config: ConfigFile) -> bool:
	return config.has_section_key(CAMPAIGNS, MARA) \
		or config.has_section_key(CAMPAIGN_STARTING_LOADOUT, MARA) \
		or config.has_section_key(MISSION_PROGRESS, MARA) \
		or config.has_section_key(CAMPAIGN_WAYPOINTS, MARA) \
		or config.has_section_key(CAMPAIGN_INTERMISSIONS, MARA) \
		or config.has_section_key(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING) \
		or config.has_section_key(CAMPAIGN_COMBAT_XP, MARA) \
		or config.has_section_key(MISSION_RESULTS, Grain.MISSION_ID) \
		or config.has_section_key(SUBORDINATE_TRAINING, MARA_SHIELD_DRILL) \
		or config.has_section_key(SUBORDINATE_STAT_ALLOCATIONS, MARA_SHIELD_MELEE) \
		or config.has_section_key(LEAD_TRAINING, MARA_LEAD_MELEE)


func mara_uses_starting_platoons() -> bool:
	return _mara_uses_starting_platoons(_config)


func _mara_uses_starting_platoons(config: ConfigFile) -> bool:
	var value: Variant = config.get_value(CAMPAIGN_STARTING_LOADOUT, MARA, 0)
	return value is int and value == MARA_STARTING_LOADOUT_V1

## Mission IDs are independent of the campaign's last-played sequence.
func completed_missions(id: String) -> PackedStringArray:
	return _confirmed_missions(_config, id)


func _confirmed_missions(config: ConfigFile, id: String) -> PackedStringArray:
	var value: Variant = config.get_value(MISSION_PROGRESS, id, PackedStringArray())
	if value is PackedStringArray:
		return value.duplicate()
	return PackedStringArray()


## Call only when that mission is cleared. Replaying a clear does not rewrite the profile.
func record_mission_clear(id: String, mission_id: String) -> Error:
	if id.strip_edges().is_empty() or mission_id.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	# These clears need their result in the same transaction.
	if mission_id in [Grain.MISSION_ID, Moonwash.MISSION_ID]:
		return ERR_INVALID_PARAMETER
	var completed := completed_missions(id)
	if completed.has(mission_id):
		return OK
	completed.append(mission_id)
	return _set_value(MISSION_PROGRESS, id, completed)


## The new rescue and its mandatory reveal are one save transaction. A legacy
## escort clear uses record_mission_clear and never queues this cutscene.
func record_greyhollow_rescue_clear() -> Error:
	var cleared := completed_missions(MARA)
	# A particularly old escort save has the same clear ID but lacks this
	# acknowledgement. Its first actual rescue can still queue the scene.
	var recorded: Variant = _config.get_value(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING, "")
	if cleared.has(MARA_MINE) and recorded is bool:
		return OK
	if not cleared.has(MARA_MINE):
		cleared.append(MARA_MINE)
	return _set_values({
		MISSION_PROGRESS: {MARA: cleared},
		MISSION_RESULTS: {GREYHOLLOW_REVEAL_PENDING: true},
	})


## The registered Mine owner can report at most its one genuine combat unit.
## Save clear, bonus, recap, and mandatory reveal in a single transaction.
## Replays (including existing clear records without bonus data) earn nothing.
func commit_greyhollow_victory(defeated: int) -> MissionXP.Receipt:
	if defeated not in [0, 1]:
		return MissionXP.Receipt.new(ERR_INVALID_DATA, defeated, 0, 0, false)
	var latest := ConfigFile.new()
	var load_error := latest.load(_path)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		return MissionXP.Receipt.new(load_error, defeated, 0, 0, false)
	var clears := _confirmed_missions(latest, MARA)
	if clears.has(MARA_MINE):
		_config = latest
		var replay_error := record_greyhollow_rescue_clear()
		return MissionXP.Receipt.new(replay_error, defeated, 0, 0, false)
	var ledger: Variant = latest.get_value(CAMPAIGN_COMBAT_XP, MARA, {})
	if not ledger is Dictionary or ledger.has(MARA_MINE):
		return MissionXP.Receipt.new(ERR_INVALID_DATA, defeated, 0, 0, false)
	var receipt := MissionXP.Receipt.new(OK, defeated, LeadProgress.XP_PER_FIRST_CLEAR,
		defeated * MissionXP.XP_PER_DEFEATED_COMBAT_UNIT, true)
	clears.append(MARA_MINE)
	var updated: Dictionary = ledger.duplicate()
	updated[MARA_MINE] = receipt.combat_xp
	var saved := _set_values({
		MISSION_PROGRESS: {MARA: clears},
		MISSION_RESULTS: {GREYHOLLOW_REVEAL_PENDING: true, GREYHOLLOW_XP_RECAP: receipt.stored()},
		CAMPAIGN_COMBAT_XP: {MARA: updated},
	}, latest)
	return receipt if saved == OK else MissionXP.Receipt.new(saved, defeated, 0, 0, false)


func campaign_combat_xp(campaign_id: String) -> Dictionary:
	return _campaign_combat_xp(_config, campaign_id)


func _campaign_combat_xp(config: ConfigFile, campaign_id: String) -> Dictionary:
	var value: Variant = config.get_value(CAMPAIGN_COMBAT_XP, campaign_id, {})
	return value.duplicate() if value is Dictionary else {}


func greyhollow_pending_xp_recap() -> MissionXP.Receipt:
	if not greyhollow_reveal_pending():
		return null
	var receipt := MissionXP.restore(_config.get_value(MISSION_RESULTS, GREYHOLLOW_XP_RECAP, {}))
	if not receipt or receipt.defeated not in [0, 1] \
			or _campaign_combat_xp(_config, MARA).get(MARA_MINE, -1) != receipt.combat_xp:
		return null
	return receipt


func acknowledge_greyhollow_xp_recap() -> Error:
	var latest := ConfigFile.new()
	var load_error := latest.load(_path)
	if load_error != OK:
		return load_error
	if not latest.has_section_key(MISSION_RESULTS, GREYHOLLOW_XP_RECAP):
		_config = latest
		return OK
	if MissionXP.restore(latest.get_value(MISSION_RESULTS, GREYHOLLOW_XP_RECAP)) == null:
		return ERR_INVALID_DATA
	return _set_values({MISSION_RESULTS: {GREYHOLLOW_XP_RECAP: null}}, latest)


func greyhollow_reveal_pending() -> bool:
	var pending: Variant = _config.get_value(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING, false)
	return pending is bool and pending and completed_missions(MARA).has(MARA_MINE)


## Saves with a clear but no reveal record must still complete the actual reveal.
func greyhollow_reveal_completed() -> bool:
	var pending: Variant = _config.get_value(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING, "")
	return pending is bool and not pending and completed_missions(MARA).has(MARA_MINE)


func finish_greyhollow_reveal() -> Error:
	var latest := ConfigFile.new()
	var load_error := latest.load(_path)
	if load_error != OK:
		return OK if load_error == ERR_FILE_NOT_FOUND else load_error
	var pending: Variant = latest.get_value(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING, false)
	if not pending is bool or not pending or not _confirmed_missions(latest, MARA).has(MARA_MINE):
		_config = latest
		return OK
	return _set_values({MISSION_RESULTS: {GREYHOLLOW_REVEAL_PENDING: false}}, latest)

## Detached plan for the one Human slot. Old saves without the marker are
## untrained; a marker without the qualifying clear cannot restore a purchase.
func mara_shield_infantry_training() -> Training:
	return _mara_training_plan(_config)


## Explicit, voluntary purchase. No caller-supplied clear, rank, or roster ID.
## Re-read the current file so another store's completed changes are preserved
## and an old in-memory clear cannot authorize a spend on a replaced profile.
func purchase_mara_shield_infantry_drill() -> Error:
	var latest := ConfigFile.new()
	var result := latest.load(_path)
	if result != OK:
		return ERR_UNAUTHORIZED if result == ERR_FILE_NOT_FOUND else result
	var plan := Training.new(MARA, _confirmed_missions(latest, MARA))
	if not plan.train_formation_drill(Training.SHIELD_INFANTRY_SLOT):
		return ERR_UNAUTHORIZED
	var purchased: Variant = latest.get_value(SUBORDINATE_TRAINING, MARA_SHIELD_DRILL, false)
	if not purchased is bool:
		return ERR_INVALID_DATA
	if purchased:
		return ERR_ALREADY_IN_USE
	return _set_values({SUBORDINATE_TRAINING: {MARA_SHIELD_DRILL: true}}, latest)


func _mara_training_plan(config: ConfigFile) -> Training:
	var plan := Training.new(MARA, _confirmed_missions(config, MARA))
	var purchased: Variant = config.get_value(SUBORDINATE_TRAINING, MARA_SHIELD_DRILL, false)
	if purchased is bool and purchased:
		plan.train_formation_drill(Training.SHIELD_INFANTRY_SLOT)
	return plan


## Detached barracks state for the one supported campaign slot. The clear,
## drill rank, and spent point come from one fresh read, so a briefing cannot
## authorize a stale branch or rating on deploy.
func mara_shield_barracks_state() -> MaraShieldBarracksState:
	var latest := ConfigFile.new()
	var read := latest.load(_path)
	var state := _mara_shield_barracks_state(latest if read == OK else ConfigFile.new())
	state.error = read
	if read not in [OK, ERR_FILE_NOT_FOUND]:
		state.melee_status = MaraShieldMeleeStatus.UNAVAILABLE
	return state


## Spend the Mine rescue's one Shield Infantry point on Melee Power. Callers
## cannot name a different slot, rating, or amount. This is not drill credit.
func invest_mara_shield_melee_point() -> Error:
	var latest := ConfigFile.new()
	var read := latest.load(_path)
	if read != OK:
		return ERR_UNAUTHORIZED if read == ERR_FILE_NOT_FOUND else read
	match _mara_shield_barracks_state(latest).melee_status:
		MaraShieldMeleeStatus.AVAILABLE:
			return _set_values({SUBORDINATE_STAT_ALLOCATIONS: {MARA_SHIELD_MELEE: true}}, latest)
		MaraShieldMeleeStatus.INVESTED:
			return ERR_ALREADY_IN_USE
		MaraShieldMeleeStatus.UNAVAILABLE:
			return ERR_INVALID_DATA
	return ERR_UNAUTHORIZED


func _mara_shield_barracks_state(config: ConfigFile) -> MaraShieldBarracksState:
	var state := MaraShieldBarracksState.new()
	state.confirmed_clears = _confirmed_missions(config, MARA)
	state.training = _mara_training_plan(config)
	state.heavy_authorized = state.training.qualifies_for_branch(Training.SHIELD_INFANTRY_SLOT, Training.BRANCH_UNIT)
	var reveal: Variant = config.get_value(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING, "")
	# Archived escort clears preserve Drill entitlement without rescue XP.
	var completed_rescue := state.confirmed_clears.has(MARA_MINE) and reveal is bool
	state.reveal_completed = completed_rescue and not reveal
	state.total_xp = LeadProgress.XP_PER_FIRST_CLEAR if completed_rescue else 0
	var progress := MaraStarting.infantry_progress(state.total_xp) if _mara_uses_starting_platoons(config) else Unit.new()
	if not _mara_uses_starting_platoons(config):
		progress.award_experience(state.total_xp)
	state.level = progress.level
	state.xp_in_level = progress.experience
	state.next_level_xp = progress.experience_for_next_level()
	state.melee_rating = progress.rating(Unit.Damage.MELEE)
	if not state.reveal_completed or progress.stat_points < 1:
		return state
	var invested: Variant = config.get_value(SUBORDINATE_STAT_ALLOCATIONS, MARA_SHIELD_MELEE, false)
	if not invested is bool:
		state.melee_status = MaraShieldMeleeStatus.UNAVAILABLE
		return state
	if invested:
		progress.spend_stat_point(Unit.Damage.MELEE)
	state.melee_rating = progress.rating(Unit.Damage.MELEE)
	state.remaining_melee_points = progress.stat_points
	state.melee_status = MaraShieldMeleeStatus.INVESTED if invested else MaraShieldMeleeStatus.AVAILABLE
	return state


## Read the current saved choice without granting it or trusting a cached clear.
func mara_lead_melee_invested() -> bool:
	return mara_lead_melee_status() == MaraLeadMeleeStatus.INVESTED


func mara_lead_melee_status() -> MaraLeadMeleeStatus:
	var latest := ConfigFile.new()
	var result := latest.load(_path)
	if result != OK:
		return MaraLeadMeleeStatus.LOCKED if result == ERR_FILE_NOT_FOUND else MaraLeadMeleeStatus.UNAVAILABLE
	return _mara_lead_melee_status(latest)


## Optional one-point spend from confirmed Human clears, not the Shield Infantry drill credit.
## The caller cannot supply an amount, clear, rating or troop slot.
func invest_mara_lead_melee_point() -> Error:
	var latest := ConfigFile.new()
	var result := latest.load(_path)
	if result != OK:
		return ERR_UNAUTHORIZED if result == ERR_FILE_NOT_FOUND else result
	match _mara_lead_melee_status(latest):
		MaraLeadMeleeStatus.AVAILABLE:
			return _set_values({LEAD_TRAINING: {MARA_LEAD_MELEE: true}}, latest)
		MaraLeadMeleeStatus.INVESTED:
			return ERR_ALREADY_IN_USE
		MaraLeadMeleeStatus.UNAVAILABLE:
			return ERR_INVALID_DATA
	return ERR_UNAUTHORIZED


func _mara_lead_melee_status(config: ConfigFile) -> MaraLeadMeleeStatus:
	var clears := _confirmed_missions(config, MARA)
	if not clears.has(MARA_MINE):
		return MaraLeadMeleeStatus.LOCKED
	if _mara_uses_starting_platoons(config):
		var progress := MaraStarting.infantry_progress(LeadProgress.inspect(MARA, clears, _campaign_combat_xp(config, MARA)).total_xp)
		if progress.stat_points == 0:
			return MaraLeadMeleeStatus.LOCKED
	else:
		var allocation := LeadAllocation.new(MARA, clears)
		if not allocation.can_invest(Unit.Damage.MELEE):
			return MaraLeadMeleeStatus.LOCKED
	var invested: Variant = config.get_value(LEAD_TRAINING, MARA_LEAD_MELEE, false)
	if not invested is bool:
		return MaraLeadMeleeStatus.UNAVAILABLE
	return MaraLeadMeleeStatus.INVESTED if invested else MaraLeadMeleeStatus.AVAILABLE


## The saved council outcome, not the latest attempt. Legacy clears may have no result.
func grain_clear_result() -> StringName:
	var result := _saved_mission_result(MARA, Grain.MISSION_ID)
	return result if _is_grain_result(result) else &""


## Call only on the Grain objective's successful terminal event.
func record_grain_clear(result: StringName) -> Error:
	if not _is_grain_result(result):
		return ERR_INVALID_PARAMETER
	return _record_first_result_clear(MARA, Grain.MISSION_ID, result)


## The provisions carried into Ilyra's survey come from the original rescue.
func ilyra_moonwash_clear_result() -> StringName:
	var result := _saved_mission_result(ILYRA, Moonwash.MISSION_ID)
	return result if _is_moonwash_result(result) else &""


## Call only on Ilyra's rescue objective's successful terminal event.
func record_ilyra_moonwash_clear(result: StringName) -> Error:
	if not _is_moonwash_result(result):
		return ERR_INVALID_PARAMETER
	return _record_first_result_clear(ILYRA, Moonwash.MISSION_ID, result)


func _saved_mission_result(id: String, mission_id: StringName) -> StringName:
	if not completed_missions(id).has(mission_id):
		return &""
	var stored: Variant = _config.get_value(MISSION_RESULTS, mission_id, "")
	return StringName(stored) if stored is String or stored is StringName else &""


# Keep the first result, including an unknown result on a pre-existing legacy clear.
func _record_first_result_clear(id: String, mission_id: StringName, result: StringName) -> Error:
	var completed := completed_missions(id)
	if completed.has(mission_id):
		return OK
	completed.append(mission_id)
	return _set_values({
		MISSION_PROGRESS: {id: completed},
		MISSION_RESULTS: {String(mission_id): String(result)},
	})


func _is_moonwash_result(result: StringName) -> bool:
	return result in [Moonwash.CREWS_ONLY, Moonwash.CARGO_RECOVERED]


func _is_grain_result(result: StringName) -> bool:
	return result in [Grain.SEED_ONLY, Grain.BREAD_ONLY, Grain.BOTH]


## Intermissions are story presentation, not mission clears or outcomes.
func has_seen_intermission(campaign_id: String, beat: StringName) -> bool:
	var seen: Variant = _config.get_value(CAMPAIGN_INTERMISSIONS, campaign_id, PackedStringArray())
	return seen is PackedStringArray and seen.has(String(beat))


## Mark after the player finishes or deliberately skips an intermission.
func record_intermission_seen(campaign_id: String, beat: StringName) -> Error:
	return _record_intermission_seen(campaign_id, beat, _config)


func _record_intermission_seen(campaign_id: String, beat: StringName, config: ConfigFile) -> Error:
	if campaign_id.is_empty() or beat == &"":
		return ERR_INVALID_PARAMETER
	var saved: Variant = config.get_value(CAMPAIGN_INTERMISSIONS, campaign_id, PackedStringArray())
	var seen: PackedStringArray = saved.duplicate() if saved is PackedStringArray else PackedStringArray()
	if seen.has(String(beat)):
		_config = config
		return OK
	seen.append(String(beat))
	return _set_values({CAMPAIGN_INTERMISSIONS: {campaign_id: seen}}, config)


## Development coast rollout only; never acknowledge an unsaved or stale arrival.
func record_mara_water_request_seen_at(waypoint_id: String) -> Error:
	if waypoint_id not in ["moonwash_road", "moonwash_harbor"]:
		return ERR_INVALID_PARAMETER
	var latest := ConfigFile.new()
	var result := latest.load(_path)
	if result != OK:
		return result
	if latest.get_value(CAMPAIGN_WAYPOINTS, MARA, "") != waypoint_id:
		return ERR_BUSY
	var clears := _confirmed_missions(latest, MARA)
	if not clears.has(Grain.MISSION_ID) or World.new(MARA, waypoint_id, clears).current_waypoint_id() != waypoint_id:
		return ERR_UNAUTHORIZED
	if latest.get_value(MISSION_RESULTS, GREYHOLLOW_REVEAL_PENDING, false) == true:
		return ERR_UNAUTHORIZED
	return _record_intermission_seen(MARA, Beats.MARA_WATER_REQUEST, latest)


## Restore only position. An invalid/old save falls back to the authored start without a write.
func load_campaign_world(id: String) -> World:
	var stored: Variant = _config.get_value(CAMPAIGN_WAYPOINTS, id, "")
	var waypoint_id: String = stored if stored is String else ""
	return World.new(id, waypoint_id, completed_missions(id))


## Call after arrival. Validate against the stored clears, not caller-supplied travel flags.
func record_world_waypoint(world: World) -> Error:
	if world == null:
		return ERR_INVALID_PARAMETER
	var id := world.campaign_id()
	var waypoint_id := world.current_waypoint_id()
	if not world.is_waypoint_reachable(waypoint_id, completed_missions(id)):
		return ERR_INVALID_PARAMETER
	if _config.get_value(CAMPAIGN_WAYPOINTS, id, "") == waypoint_id:
		return OK
	return _set_value(CAMPAIGN_WAYPOINTS, id, waypoint_id)


func setting(key: String) -> bool:
	return bool(_config.get_value(SETTINGS, key, key == "fullscreen"))


func set_setting(key: String, enabled: bool) -> Error:
	return _set_value(SETTINGS, key, enabled)


func _saved_order(id: String) -> int:
	return int(_config.get_value(CAMPAIGNS, id, 0))


func _set_value(section: String, key: String, value: Variant) -> Error:
	return _set_values({section: {key: value}})


# All changed keys share the existing temp-file/rename transaction and rollback.
func _set_values(values: Dictionary, snapshot: ConfigFile = null) -> Error:
	var config := snapshot if snapshot != null else _config
	var previous: Array[Dictionary] = []
	for section: String in values:
		for key: String in values[section]:
			var existed := config.has_section_key(section, key)
			previous.append({
				"section": section, "key": key, "existed": existed,
				"value": config.get_value(section, key) if existed else null,
			})
			config.set_value(section, key, values[section][key])

	var temporary := _path + ".tmp"
	var result := config.save(temporary)
	if result == OK:
		result = DirAccess.rename_absolute(temporary, _path)
	if result == OK:
		_config = config
	else:
		for entry in previous:
			if entry.existed:
				config.set_value(entry.section, entry.key, entry.value)
			else:
				config.erase_section_key(entry.section, entry.key)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
	return result


class EdgeCommit:
	var error: Error
	var world: World

	func _init(result: Error, candidate: World = null) -> void:
		error = result
		world = candidate


## Persist an adjacent move without moving the active session. Resolve against the
## current disk snapshot so a stale store can't overwrite newer progress or travel.
func commit_world_edge(origin: World, destination: String) -> EdgeCommit:
	if origin == null or origin.get_script() != World or destination.is_empty():
		return EdgeCommit.new(ERR_INVALID_PARAMETER)
	var latest := ConfigFile.new()
	var read := latest.load(_path)
	if read != OK:
		return EdgeCommit.new(read)
	var id := origin.campaign_id()
	var stored: Variant = latest.get_value(CAMPAIGN_WAYPOINTS, id, null)
	if not stored is String or stored != origin.current_waypoint_id():
		return EdgeCommit.new(ERR_BUSY)
	var clears := _confirmed_missions(latest, id)
	var reachable_origin := World.new(id, stored, clears)
	if reachable_origin.current_waypoint_id() != stored:
		return EdgeCommit.new(ERR_UNAUTHORIZED)
	var candidate := origin.fork_for_travel() as World
	if candidate == null or candidate.travel_to(destination, clears) != World.TravelResult.ARRIVED:
		return EdgeCommit.new(ERR_UNAUTHORIZED)
	var written := _set_values({CAMPAIGN_WAYPOINTS: {id: destination}}, latest)
	if written != OK:
		return EdgeCommit.new(written)
	return EdgeCommit.new(OK, candidate)
