extends RefCounted
## Queue/physical Move bridge for opted-in command views.
## Input scope, selected platoon, terrain validation and feedback are caller-owned.

const Battle := preload("res://game/battlefield/command_battle.gd")
const Queue := preload("res://game/battlefield/platoon_waypoint_queue.gd")

var _routes: Array[Queue] = []
## The leader's own platoon (Battle.LEAD_INDEX) keeps its route here.
var _lead_route := Queue.new()


func reset(battle: Battle) -> void:
	_routes.clear()
	_lead_route = Queue.new()
	for _formation in battle.formations:
		_routes.append(Queue.new())


func _route(index: int) -> Queue:
	if index == Battle.LEAD_INDEX:
		return _lead_route
	return _routes[index] if index >= 0 and index < _routes.size() else null


func snapshot(index: int) -> PackedVector2Array:
	var route := _route(index)
	return route.snapshot() if route else PackedVector2Array()


func issue(battle: Battle, index: int, point: Vector2, append: bool, validator: Callable) -> Queue.Result:
	var route := _route(index)
	var formation := battle.formation_at(index)
	if route == null or formation == null or not formation.can_receive_orders():
		return Queue.Result.INVALID_FOR_BATTLEFIELD
	# Waypoints steer the leader's platoon only outside combat.
	if index == Battle.LEAD_INDEX and battle.direct_hero_control():
		return Queue.Result.INVALID_FOR_BATTLEFIELD
	var was_empty := route.count() == 0
	var result := route.add_waypoint(point, validator) if append else route.set_destination(point, validator)
	if result == Queue.Result.ACCEPTED and (not append or was_empty):
		battle.order_move(index, point)
	return result


func clear(index: int) -> void:
	var route := _route(index)
	if route:
		route.clear()


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
	# Combat cancels the leader's march; the player re-plots it afterwards.
	if battle.direct_hero_control():
		_lead_route.clear()
	elif battle.lead.order == Battle.Order.HOLD and _lead_route.consume_if_arrived(battle.lead.position):
		var lead_next: Variant = _lead_route.next_waypoint()
		if lead_next != null:
			battle.order_move(Battle.LEAD_INDEX, lead_next)
