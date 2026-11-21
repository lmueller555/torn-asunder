extends RefCounted
## The High Quay's local levy. This adapter can move and hold physical contact,
## but does not spend BP, attack, inflict damage, or decide the withdrawal.

const Patrol := preload("res://game/battlefield/patrol_detection_policy.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")

# Local playtest values, not shared scouting/melee constants.
const SIGHT_RANGE := 21.5
const LEASH := 18.0
const MEMORY := 2.4
const PATROL_SPEED := 2.3
const PURSUIT_SPEED := 2.9
const LEVY_RADIUS := 0.48
const BODY_HEIGHT_TOLERANCE := 0.72
const CONTACT_SLOP := 0.13
const HERO_ID := &"Hero"

var position: Vector2
var heading := Vector2.LEFT
var decision := Patrol.Decision.new(Patrol.Intent.PATROL)
var _policy := Patrol.new(SIGHT_RANGE, LEASH, MEMORY)
var _terrain: Terrain
var _route: PackedVector2Array
var _leg := 1
var _anchor: Vector2
var _left_route := false
var _sightings: Array[Patrol.Sighting] = []


func _init(route: PackedVector2Array, terrain: Terrain) -> void:
	_route = route.duplicate()
	_terrain = terrain
	position = _route[0]
	_anchor = position
	if _route.size() >= 2:
		heading = (route[1] - route[0]).normalized()


func advance(delta: float, battle: Battle, hero_active: bool) -> void:
	var obs := Patrol.Observation.new()
	obs.authored_order = Patrol.AuthoredOrder.PATROL
	obs.patrol_position = position
	obs.leash_anchor = _anchor
	_sightings.clear()
	if hero_active:
		_add_sighting(HERO_ID, battle.hero_position, false)
	for group in battle.formations:
		if group.can_receive_orders():
			_add_sighting(StringName(group.title), group.position, true)
	obs.candidates = _sightings
	decision = _policy.advance(delta, obs)
	match decision.intent:
		Patrol.Intent.ENGAGE:
			_left_route = true
			_face(decision.destination)
		Patrol.Intent.PURSUE, Patrol.Intent.INVESTIGATE:
			_left_route = true
			_toward(decision.destination, PURSUIT_SPEED * delta)
		Patrol.Intent.PATROL:
			if _left_route:
				_toward(_anchor, PATROL_SPEED * delta)
				_left_route = not position.is_equal_approx(_anchor)
			elif _route.size() >= 2:
				_toward(_route[_leg], PATROL_SPEED * delta)
				_anchor = position
				if position == _route[_leg]:
					_leg = (_leg + 1) % _route.size()


func blocks_move(from: Vector2, to: Vector2, is_formation: bool) -> bool:
	var radius := body_clearance(is_formation)
	if to.distance_squared_to(position) >= radius * radius \
		or to.distance_squared_to(position) >= from.distance_squared_to(position):
		return false
	return _same_level(position, to)


static func body_clearance(is_formation: bool) -> float:
	return LEVY_RADIUS + (Terrain.FORMATION_RADIUS if is_formation else Terrain.HERO_RADIUS)


func _add_sighting(id: StringName, where: Vector2, is_formation: bool) -> void:
	var distance := position.distance_to(where)
	var line_clear := false
	var contact := false
	if distance <= SIGHT_RANGE:
		line_clear = _terrain.clear_ranged_lane(_at_height(position, 1.38), _at_height(where, 1.30))
		contact = line_clear and distance <= body_clearance(is_formation) + CONTACT_SLOP and _same_level(position, where)
	_sightings.append(Patrol.Sighting.new(id, where, line_clear, contact))


func _toward(target: Vector2, travel: float) -> void:
	_face(target)
	var next := position.move_toward(target, travel)
	if not _terrain.can_move(position, next, false):
		return
	for item in _sightings:
		var radius := body_clearance(item.id != HERO_ID)
		if next.distance_squared_to(item.position) < radius * radius \
			and next.distance_squared_to(item.position) < position.distance_squared_to(item.position) \
			and _same_level(next, item.position):
			return
	position = next


func _face(target: Vector2) -> void:
	var direction := target - position
	if not direction.is_zero_approx():
		heading = direction.normalized()


func _at_height(point: Vector2, offset: float) -> Vector3:
	return Vector3(point.x, _terrain.ground_height(point) + offset, point.y)


func _same_level(a: Vector2, b: Vector2) -> bool:
	return absf(_terrain.ground_height(a) - _terrain.ground_height(b)) <= BODY_HEIGHT_TOLERANCE
