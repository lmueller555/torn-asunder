extends RefCounted

const PATH := "user://profile.cfg"
const CAMPAIGNS := "campaigns"
const MISSION_PROGRESS := "mission_progress"
const SETTINGS := "settings"

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
	var completed := completed_missions(id)
	if completed.has(mission_id):
		return OK
	completed.append(mission_id)
	return _set_value(MISSION_PROGRESS, id, completed)


func setting(key: String) -> bool:
	return bool(_config.get_value(SETTINGS, key, key == "fullscreen"))


func set_setting(key: String, enabled: bool) -> Error:
	return _set_value(SETTINGS, key, enabled)


func _saved_order(id: String) -> int:
	return int(_config.get_value(CAMPAIGNS, id, 0))


func _set_value(section: String, key: String, value: Variant) -> Error:
	var existed := _config.has_section_key(section, key)
	var previous: Variant
	if existed:
		previous = _config.get_value(section, key)

	_config.set_value(section, key, value)
	var temporary := _path + ".tmp"
	var result := _config.save(temporary)
	if result == OK:
		result = DirAccess.rename_absolute(temporary, _path)
	if result != OK:
		if existed:
			_config.set_value(section, key, previous)
		else:
			_config.erase_section_key(section, key)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
	return result
