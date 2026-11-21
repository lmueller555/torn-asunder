extends RefCounted
## Shared simulation. Neither camera owns or recreates the field or its orders.

enum Order { HOLD, MOVE }

const LIMIT := Vector2(17.0, 12.0)
const HERO_SPEED := 5.5
const FORMATION_SPEED := 3.0


class Formation:
	var title: String
	var position: Vector2
	var destination: Vector2
	var heading := Vector2.UP
	var order := Order.HOLD

	func _init(label: String, spawn: Vector2) -> void:
		title = label
		position = spawn
		destination = spawn

	func hold() -> void:
		order = Order.HOLD
		destination = position

	func advance(delta: float) -> void:
		if order != Order.MOVE:
			return
		var travel := destination - position
		if travel.length_squared() > 0.0:
			heading = travel.normalized()
		position = position.move_toward(destination, FORMATION_SPEED * delta)
		if position == destination:
			hold()


var hero_position := Vector2(0.0, 7.0)
var hero_heading := Vector2.UP
var formations: Array[Formation] = [
	Formation.new("Shield Infantry", Vector2(-6.0, -4.0)),
	Formation.new("Archers", Vector2(6.0, -3.0)),
]


static func clamp_to_field(point: Vector2) -> Vector2:
	return point.clamp(-LIMIT, LIMIT)


func order_move(index: int, point: Vector2) -> void:
	var formation := formations[index]
	formation.destination = clamp_to_field(point)
	formation.order = Order.MOVE


func order_hold(index: int) -> void:
	formations[index].hold()


func step(delta: float, hero_direction: Vector2) -> void:
	if hero_direction != Vector2.ZERO:
		hero_heading = hero_direction.normalized()
		hero_position = clamp_to_field(hero_position + hero_direction.limit_length() * HERO_SPEED * delta)
	for formation in formations:
		formation.advance(delta)
