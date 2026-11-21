extends RefCounted
## Queue/physical Move bridge shared by the development command previews.
## Input scope, selected platoon, terrain validation and feedback are caller-owned.

const Battle := preload("res://game/battlefield/command_battle.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")

var _routes: Array[Queue] = []


func reset(battle: Battle) -> void:
	_routes.clear()
	for _formation in battle.formations:
		_routes.append(Queue.new())


func snapshot(index: int) -> PackedVector2Array:
	return _routes[index].snapshot() if index >= 0 and index < _routes.size() else PackedVector2Array()


func issue(battle: Battle, index: int, point: Vector2, append: bool, validator: Callable) -> Queue.Result:
	if index < 0 or index >= mini(_routes.size(), battle.formations.size()) or not battle.formations[index].can_receive_orders():
		return Queue.Result.INVALID_FOR_BATTLEFIELD
	var route := _routes[index]
	var was_empty := route.count() == 0
	var result := route.add_waypoint(point, validator) if append else route.set_destination(point, validator)
	if result == Queue.Result.ACCEPTED and (not append or was_empty):
		battle.order_move(index, point)
	return result


func clear(index: int) -> void:
	if index >= 0 and index < _routes.size():
		_routes[index].clear()


## Run only after the battlefield has advanced, not on cursor or camera input.
func advance(battle: Battle) -> void:
	for index in mini(_routes.size(), battle.formations.size()):
		var route := _routes[index]
		var formation := battle.formations[index]
		if not formation.can_receive_orders():
			route.clear()
			continue
		# Do not consume a target when a formation is merely nearby or Blocked.
		if formation.order != Battle.Order.HOLD or not route.consume_if_arrived(formation.position):
			continue
		var following: Variant = route.next_waypoint()
		if following != null:
			battle.order_move(index, following)
