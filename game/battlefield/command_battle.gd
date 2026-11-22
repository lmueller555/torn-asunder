extends RefCounted
## Shared simulation. Neither camera owns or recreates the field or its orders.

const PlatoonSize := preload("res://game/combat/platoon_size.gd")

enum Order { HOLD, MOVE, BLOCKED, ATTACK, DEFEATED, EXTRACTED }
enum FormationRole { UNSPECIFIED, REGULAR_MELEE, RANGED, SUPPORT }
## Melee platoons travel in one of three formations. Closed packs the soldiers in
## and halves their pace; Open spreads them out and moves half again as fast.
enum Spacing { CLOSED, NORMAL, OPEN }
const SPACING_NAMES: PackedStringArray = ["Closed", "Normal", "Open"]
const SPACING_SPEED: PackedFloat32Array = [0.5, 1.0, 1.5]
## How far apart the soldiers stand, relative to the Normal layout.
const SPACING_SPREAD: PackedFloat32Array = [0.66, 1.0, 1.65]
## Spread change per second while soldiers gather in or fan out.
const SPREAD_RATE := 1.4
## Platoons without an explicit role whose titles contain these are archers or
## civilians and keep one layout.
const NO_FORMATION_WORDS: PackedStringArray = ["archer", "bow", "sling", "refugee", "witness", "civilian", "miner"]

const LEGACY_AUTHORED_MEMBERS := 12
const AUTHORED_MELEE_FILES := 8


## An indexed deployment slot shared by feet, extraction and presentation.
## No new damage economy: scripted formation damage remains aggregate.
class Member:
	var index: int
	var offset: Vector2
	var crossed := false

	func _init(member_index: int, file_offset: Vector2) -> void:
		index = member_index
		offset = file_offset

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
	var role := FormationRole.UNSPECIFIED
	var members: Array[Member] = []
	var member_footprint_check := Callable()
	var footprint_padding := Vector2(0.44, 0.40)
	var spacing := Spacing.NORMAL
	## The current spread, easing toward the formation's target as soldiers move.
	var spread := 1.0
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
		configure_role(FormationRole.UNSPECIFIED)


	func configure_role(formation_role: FormationRole, melee_files := AUTHORED_MELEE_FILES, melee_spacing := Vector2(0.85, 0.78), melee_trailing_bias := 0.0) -> void:
		role = formation_role
		var melee := role == FormationRole.REGULAR_MELEE
		var count := PlatoonSize.count_for(LEGACY_AUTHORED_MEMBERS, melee)
		var files := AUTHORED_MELEE_FILES if melee and melee_files != 4 else 4
		var rows := ceili(float(count) / float(files))
		var spacing := melee_spacing if melee else Vector2(0.85, 0.78)
		var bias := melee_trailing_bias if melee else 0.0
		footprint_padding = Vector2(0.44, 0.40) if spacing.x >= 0.85 else Vector2(0.26, 0.34)
		members.clear()
		for file in range(files):
			for row in range(rows):
				if members.size() == count:
					break
				members.append(Member.new(members.size(),
					Vector2((file - (files - 1) * 0.5) * spacing.x, (row - (rows - 1) * 0.5) * spacing.y + bias)))


	## A soldier's place in the platoon, gathered in or fanned out by the formation.
	func member_offset(member: Member) -> Vector2:
		return member.offset * spread

	func member_position(member: Member) -> Vector2:
		var side := Vector2(-heading.y, heading.x)
		var offset := member_offset(member)
		return position + side * offset.x - heading * offset.y

	## Regular melee platoons (and untyped platoons that aren't archers or civilians)
	## change formation; ranged and support platoons do not.
	func uses_formations() -> bool:
		if role == FormationRole.REGULAR_MELEE:
			return true
		if role != FormationRole.UNSPECIFIED:
			return false
		var lowered := title.to_lower()
		for word in NO_FORMATION_WORDS:
			if lowered.contains(word):
				return false
		return true

	## Steps one formation tighter (-1) or wider (+1). Returns true if it changed.
	func step_spacing(direction: int) -> bool:
		if not uses_formations() or not can_receive_orders():
			return false
		var next := clampi(spacing + direction, Spacing.CLOSED, Spacing.OPEN) as Spacing
		if next == spacing:
			return false
		spacing = next
		return true

	func speed_factor() -> float:
		return SPACING_SPEED[spacing] if uses_formations() else 1.0

	func target_spread() -> float:
		return SPACING_SPREAD[spacing] if uses_formations() else 1.0

	func spacing_name() -> String:
		return SPACING_NAMES[spacing]

	func settle_spread(delta: float) -> void:
		spread = move_toward(spread, target_spread(), SPREAD_RATE * delta)


	func footprint_fits(center: Vector2) -> bool:
		return not member_footprint_check.is_valid() or member_footprint_check.call(self, center)

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
		var previous_heading := heading
		if travel.length_squared() > 0.0:
			heading = travel.normalized()
		var next := position.move_toward(destination, move_speed * speed_factor() * delta)
		if can_move.is_valid() and not can_move.call(position, next, true):
			if member_footprint_check.is_valid():
				heading = previous_heading
			order = Order.BLOCKED
			return
		if not footprint_fits(next):
			# A full column can back out of a choke it cannot turn around in.
			# Advance the same feet in the last legal facing; no refile or warp.
			heading = previous_heading
			if not footprint_fits(next):
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
signal formation_spacing_changed(index: int)

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
	lead.settle_spread(delta)
	for formation in formations:
		formation.advance(delta, can_move)
		formation.settle_spread(delta)


## Steps the indexed platoon's formation tighter (-1) or wider (+1).
func step_spacing(index: int, direction: int) -> bool:
	var formation := formation_at(index)
	if formation == null or not formation.step_spacing(direction):
		return false
	formation_spacing_changed.emit(index)
	return true


## The leader walks at the head of the platoon toward its Move order. The platoon
## funnels behind them, so the march uses the leader's clearance and slides along
## walls exactly as direct movement does.
func _march_lead(delta: float, can_move: Callable) -> void:
	if lead.order == Order.MOVE:
		var travel := lead.destination - hero_position
		var pace := LEAD_SPEED * lead.speed_factor()
		if travel.length() <= pace * delta:
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
			move_hero(lead.heading * pace * delta, can_move)
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
