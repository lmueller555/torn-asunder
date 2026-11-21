extends RefCounted

const World := preload("res://game/campaign_world.gd")
const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")

const PATH := "user://profile.cfg"
const CAMPAIGNS := "campaigns"
const MISSION_PROGRESS := "mission_progress"
const MISSION_RESULTS := "mission_results"
const MARA := "mara"
const CAMPAIGN_WAYPOINTS := "campaign_waypoints"
const SETTINGS := "settings"
const ILYRA := "ilyra"

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


func mark_played(id: String) -> Error:
	var sequence := 0
	if _config.has_section(CAMPAIGNS):
		for key in _config.get_section_keys(CAMPAIGNS):
			sequence = maxi(sequence, _saved_order(key))
	return _set_value(CAMPAIGNS, id, sequence + 1)


## Mission IDs are independent of the campaign's last-played sequence.
func completed_missions(id: String) -> PackedStringArray:
	var value: Variant = _config.get_value(MISSION_PROGRESS, id, PackedStringArray())
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
func _set_values(values: Dictionary) -> Error:
	var previous: Array[Dictionary] = []
	for section: String in values:
		for key: String in values[section]:
			var existed := _config.has_section_key(section, key)
			previous.append({
				"section": section, "key": key, "existed": existed,
				"value": _config.get_value(section, key) if existed else null,
			})
			_config.set_value(section, key, values[section][key])

	var temporary := _path + ".tmp"
	var result := _config.save(temporary)
	if result == OK:
		result = DirAccess.rename_absolute(temporary, _path)
	if result != OK:
		for entry in previous:
			if entry.existed:
				_config.set_value(entry.section, entry.key, entry.value)
			else:
				_config.erase_section_key(entry.section, entry.key)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
	return result
