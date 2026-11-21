extends RefCounted
## Shared simulation. Neither camera owns or recreates the field or its orders.

enum Order { HOLD, MOVE, BLOCKED, ATTACK, DEFEATED, EXTRACTED }

## Explicit Move/Hold requests, not the Hold produced by reaching a destination.
signal formation_commanded(index: int)

const FLAT_BOUNDS := Rect2(-17.0, -12.0, 34.0, 24.0)
const HERO_SPEED := 5.5
const FORMATION_SPEED := 3.0


class Formation:
	signal order_changed(next_order: Order)

	var title: String
	var position: Vector2
	var destination: Vector2
	var heading := Vector2.UP
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
		var next := position.move_toward(destination, FORMATION_SPEED * delta)
		if can_move.is_valid() and not can_move.call(position, next, true):
			order = Order.BLOCKED
			return
		position = next
		if position == destination:
			hold()


var bounds := FLAT_BOUNDS
var hero_position := Vector2(0.0, 7.0)
var hero_heading := Vector2.UP
var formations: Array[Formation] = [
	Formation.new("Shield Infantry", Vector2(-6.0, -4.0)),
	Formation.new("Archers", Vector2(6.0, -3.0)),
]


func clamp_to_field(point: Vector2) -> Vector2:
	return point.clamp(bounds.position, bounds.end)


func order_move(index: int, point: Vector2) -> void:
	var formation := formations[index]
	if not formation.can_receive_orders():
		return
	formation.destination = clamp_to_field(point)
	formation.order = Order.MOVE
	formation_commanded.emit(index)


func order_hold(index: int) -> void:
	var formation := formations[index]
	if formation.can_receive_orders():
		formation.hold()
		formation_commanded.emit(index)


func step(delta: float, hero_direction: Vector2, can_move := Callable()) -> void:
	if hero_direction != Vector2.ZERO:
		hero_heading = hero_direction.normalized()
		move_hero(hero_direction.limit_length() * HERO_SPEED * delta, can_move)
	for formation in formations:
		formation.advance(delta, can_move)


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
