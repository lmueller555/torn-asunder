extends RefCounted
## Selects the camera and input context; rendering, orbits, threats and orders
## stay with the battlefield. Only the selected platoon's engagement is relevant.

enum Mode { TACTICAL, PLATOON_FOLLOW, HERO_ACTION }

var _hero_id: StringName
var _selected_id: StringName
var _active: Array[StringName] = []
var _engaged: Dictionary[StringName, bool] = {}
var _cursor := Vector2.ZERO


func _init(hero_platoon_id: StringName) -> void:
	_hero_id = hero_platoon_id


func set_active_platoons(roster: Array[StringName]) -> void:
	_active.clear()
	for id in roster:
		if not id.is_empty() and id not in _active:
			_active.append(id)
	for id in _engaged.keys():
		if id not in _active:
			_engaged.erase(id)
	if _selected_id not in _active:
		_selected_id = _active[0] if not _active.is_empty() else &""


func select(id: StringName) -> bool:
	if id not in _active:
		return false
	_selected_id = id
	return true


func cycle(step: int) -> void:
	if _active.is_empty() or step == 0:
		return
	_selected_id = _active[posmod(_active.find(_selected_id) + (1 if step > 0 else -1), _active.size())]


func observe_engaged(id: StringName, engaged: bool) -> void:
	if id in _active:
		_engaged[id] = engaged


func set_tactical_cursor(world_xz: Vector2) -> void:
	if world_xz.is_finite():
		_cursor = world_xz


func selected_id() -> StringName:
	return _selected_id


func tactical_cursor() -> Vector2:
	return _cursor


func mode() -> Mode:
	if not _engaged.get(_selected_id, false):
		return Mode.TACTICAL
	return Mode.HERO_ACTION if _selected_id == _hero_id else Mode.PLATOON_FOLLOW


## Tactical view has no follow platoon: pan from the independently held cursor.
func follow_platoon() -> StringName:
	return &"" if mode() == Mode.TACTICAL else _selected_id


func accepts_formation_orders() -> bool:
	return not _selected_id.is_empty() and mode() != Mode.HERO_ACTION


func accepts_direct_hero_input() -> bool:
	return mode() == Mode.HERO_ACTION
