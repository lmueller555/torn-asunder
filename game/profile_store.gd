extends RefCounted

const World := preload("res://game/campaign_world.gd")

const PATH := "user://profile.cfg"
const CAMPAIGNS := "campaigns"
const MISSION_PROGRESS := "mission_progress"
const CAMPAIGN_WAYPOINTS := "campaign_waypoints"
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
