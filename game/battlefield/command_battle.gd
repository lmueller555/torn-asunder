extends RefCounted
## Shared simulation. Neither camera owns or recreates the field or its orders.

enum Order { HOLD, MOVE, BLOCKED, ATTACK, DEFEATED, EXTRACTED }

## Explicit Move/Hold requests, not the Hold produced by reaching a destination.
signal formation_commanded(index: int)

const FLAT_BOUNDS := Rect2(-17.0, -12.0, 34.0, 24.0)
const HERO_SPEED := 5.5
const FORMATION_SPEED := 3.0
## The leader marches at the head of their own platoon at this pace between fights.
const LEAD_SPEED := HERO_SPEED
## Command index for the leader's own platoon. It is never stored in `formations`,
## so existing formation indices keep their meaning.
const LEAD_INDEX := -1


class Formation:
	signal order_changed(next_order: Order)

	var title: String
	var position: Vector2
	var destination: Vector2
	var heading := Vector2.UP
	var move_speed := FORMATION_SPEED
	var order := Order.HOLD:
		set(value):
			if value == order:
				return
			order = value
			order_changed.emit(order)

	func _init(label: String, spawn: Vector2) -> void:
		title = label
		position = spawn
		destination = spawn

	func can_receive_orders() -> bool:
		return order != Order.DEFEATED and order != Order.EXTRACTED

	func hold() -> void:
		if can_receive_orders():
			order = Order.HOLD
			destination = position

	func defeat() -> void:
		if order != Order.EXTRACTED:
			order = Order.DEFEATED
			destination = position

	func extract() -> void:
		if can_receive_orders():
			order = Order.EXTRACTED
			destination = position

	func advance(delta: float, can_move: Callable) -> void:
		if order != Order.MOVE:
			return
		var travel := destination - position
		if travel.length_squared() > 0.0:
			heading = travel.normalized()
		var next := position.move_toward(destination, move_speed * delta)
		if can_move.is_valid() and not can_move.call(position, next, true):
			order = Order.BLOCKED
			return
		position = next
		if position == destination:
			hold()


var bounds := FLAT_BOUNDS
var hero_position := Vector2(0.0, 7.0)
var hero_heading := Vector2.UP
## The leader's platoon. Outside combat it takes Move and Hold orders and waypoints
## like any other platoon, and the leader travels at its head. During combat the
## player steers the leader directly and the platoon closes up around them.
var lead := Formation.new("Lead Platoon", hero_position)
## Set by the battlefield when an enemy engages the lead platoon.
var lead_engaged := false:
	set(value):
		if value == lead_engaged:
			return
		lead_engaged = value
		# Combat interrupts the march; the platoon re-forms where the fight ended.
		lead.position = hero_position
		lead.hold()
		lead_engagement_changed.emit(value)
## False restores the legacy free-walking leader for scenes that need it.
var lead_platoon_enabled := true

signal lead_engagement_changed(engaged: bool)

var _hero_synced := Vector2.INF
var formations: Array[Formation] = [
	Formation.new("Shield Infantry", Vector2(-6.0, -4.0)),
	Formation.new("Archers", Vector2(6.0, -3.0)),
]


func clamp_to_field(point: Vector2) -> Vector2:
	return point.clamp(bounds.position, bounds.end)


## The leader's platoon for LEAD_INDEX; otherwise the indexed formation, or null.
func formation_at(index: int) -> Formation:
	if index == LEAD_INDEX:
		return lead
	return formations[index] if index >= 0 and index < formations.size() else null


func is_valid_command_index(index: int) -> bool:
	return formation_at(index) != null


## True while stick or D-pad input steers the leader directly.
func direct_hero_control() -> bool:
	return lead_engaged or not lead_platoon_enabled


func order_move(index: int, point: Vector2) -> void:
	var formation := formation_at(index)
	if formation == null:
		return
	if not formation.can_receive_orders():
		return
	formation.destination = clamp_to_field(point)
	formation.order = Order.MOVE
	formation_commanded.emit(index)


func order_hold(index: int) -> void:
	var formation := formation_at(index)
	if formation and formation.can_receive_orders():
		formation.hold()
		formation_commanded.emit(index)


func step(delta: float, hero_direction: Vector2, can_move := Callable()) -> void:
	_sync_lead_to_external_moves()
	if direct_hero_control():
		if hero_direction != Vector2.ZERO:
			hero_heading = hero_direction.normalized()
			move_hero(hero_direction.limit_length() * HERO_SPEED * delta, can_move)
		# The platoon fights around its leader rather than holding a separate post.
		lead.position = hero_position
		lead.destination = hero_position
		lead.heading = hero_heading
	else:
		_march_lead(delta, can_move)
	_hero_synced = hero_position
	for formation in formations:
		formation.advance(delta, can_move)


## The leader walks at the head of the platoon toward its Move order. The platoon
## funnels behind them, so the march uses the leader's clearance and slides along
## walls exactly as direct movement does.
func _march_lead(delta: float, can_move: Callable) -> void:
	if lead.order == Order.MOVE:
		var travel := lead.destination - hero_position
		if travel.length() <= LEAD_SPEED * delta:
			var before := hero_position
			move_hero(travel, can_move)
			if hero_position == before and travel.length_squared() > 0.0:
				lead.order = Order.BLOCKED
			elif hero_position.is_equal_approx(lead.destination):
				hero_position = lead.destination
				lead.position = hero_position
				lead.hold()
		else:
			lead.heading = travel.normalized()
			hero_heading = lead.heading
			var before := hero_position
			move_hero(lead.heading * LEAD_SPEED * delta, can_move)
			if hero_position == before:
				lead.order = Order.BLOCKED
	lead.position = hero_position


## Scenes and scripted events place the leader directly (spawns, cutscenes, tests).
## The platoon re-forms on the leader instead of pulling them back.
func _sync_lead_to_external_moves() -> void:
	if hero_position == _hero_synced or hero_position == lead.position:
		return
	lead.position = hero_position
	lead.destination = hero_position
	if lead.order == Order.MOVE or lead.order == Order.BLOCKED:
		lead.hold()


func move_hero(displacement: Vector2, can_move := Callable()) -> void:
	var next := clamp_to_field(hero_position + displacement)
	if not can_move.is_valid() or can_move.call(hero_position, next, false):
		hero_position = next
	else:
		# Let the hero slide along an obstruction rather than stopping diagonal input.
		for axis_point in [Vector2(next.x, hero_position.y), Vector2(hero_position.x, next.y)]:
			if axis_point != hero_position and can_move.call(hero_position, axis_point, false):
				hero_position = axis_point
				break
