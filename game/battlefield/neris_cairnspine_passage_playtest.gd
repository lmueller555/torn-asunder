extends "res://game/battlefield/command_harness.gd"

const Passage := preload("res://game/battlefield/neris_cairnspine_passage.gd")
const Route := Passage.Route
const Group := Passage.Group
const Status := Passage.Status
const Outcome := Passage.Outcome

const SHELF := ["ShelfDecision", "ShelfFoot", "ShelfClimb", "ShelfHold", "ShelfRejoin"]
const SIDE := [
	"SideDecision", "SideApproach", "SideTurn", "SideRampFoot", "SideBlindBend",
	"SideRampTurn", "SideNorthToe", "SideHighBend", "SideRejoin",
]
const TERRACE := ["Forecourt", "TerraceApproach", "TerraceEntry"]
const GROUP_NAMES := ["Refugees", "Witnesses"]
const STAGING := ["RefugeeStaging", "WitnessStaging"]
const SAFETY := ["RefugeeSafety", "AttestingWitnesses"]
const GUARD_NAMES := ["Shelf Volunteers", "Side Volunteers"]
const ROUTE_NAMES := ["", "Shelf", "Side path"]
const READY := Color("#a7ebce")
const SHELTER := Color("#f1cb82")
const RISK := Color("#ff9b83")
const INTERACT_RADIUS := 2.2
const SCREEN_RADIUS := 4.8
const PARTY_SPEED := 6.5
const RIVAL_SPEED := 11.2

signal mission_finished(won: bool)

class Party:
	var actor: Node3D
	var label: Label3D
	var position := Vector2.ZERO
	var path := PackedVector2Array()
	var next := 0

	func next_stop() -> Vector2:
		return path[next] if next < path.size() else position

	func last_safe() -> Vector2:
		return path[maxi(next - 1, 0)] if not path.is_empty() else position


class Patrol:
	var actor: Node3D
	var label: Label3D
	var path := PackedVector2Array()
	var position := Vector2.ZERO
	var next := 1
	var active := false
	var screened := false

	func choke() -> Vector2:
		return path[-1]

	func contests() -> bool:
		return active and position.distance_to(choke()) <= 6.0


var objective := Passage.new()
var _parties: Array[Party] = []
var _patrols: Array[Patrol] = []
var _terrace: AABB
var _interact := false
var _neris_fell := false
var _lost := [false, false]
var _notice := ""

@onready var _goal: Label = $PassageHUD/Panel/Margin/Readout/Goal
@onready var _refugees_label: Label = $PassageHUD/Panel/Margin/Readout/Refugees
@onready var _witnesses_label: Label = $PassageHUD/Panel/Margin/Readout/Witnesses
@onready var _pressure_label: Label = $PassageHUD/Panel/Margin/Readout/Pressure
@onready var _orders: Label = $PassageHUD/Panel/Margin/Readout/Orders
@onready var _restart: Button = $PassageHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	var zone := battlefield_marker(^"Markers/PhaseZones/TerraceSafeZone")
	var size: Vector3 = zone.get_meta(&"box_size")
	_terrace = AABB(zone.global_position - size * 0.5, size)
	for index in GROUP_NAMES.size():
		var party := Party.new()
		var tint := SHELTER if index == Group.REFUGEES else Color("#a8caef")
		party.actor = _make_debug_party(GROUP_NAMES[index], 4, 1)
		party.label = _sign(party.actor, Vector3.UP * 2.2, GROUP_NAMES[index], tint)
		_parties.append(party)
	_make_patrol("Rival shelf company", [
		_spot("Spawns", "RivalReserve"), _route("RivalReserveCorner"), _route("RivalReserveReveal"),
		_route("Forecourt"), _route("ShelfRejoin"),
	])
	_make_patrol("Side detachment", [
		_spot("Spawns", "SidePressure"), _route("SideRampTurn"), _route("SideNorthToe"),
		_route("SideHighBend"), _route("SideRejoin"),
	])
	_pin(_route("RefugeeStaging"), "REFUGEE GUIDE", SHELTER)
	_pin(_route("WitnessStaging"), "WITNESS GUIDE", Color("#a8caef"))
	_pin(_route("ShelfDecision"), "CONFIRM SHELF ROUTE", SHELTER)
	_pin(_route("SideDecision"), "CONFIRM SIDE ROUTE", READY)
	_pin(_route("ShelfRejoin"), "SHELF SCREEN · HOLD", READY)
	_pin(_route("SideRejoin"), "SIDE REJOIN · HOLD", READY)
	_pin(_spot("Objectives", "WitnessTerrace"), "WITNESS TERRACE · SAFE", READY)
	_pin(_spot("Objectives", "CustodyLine"), "VAULT ESCORT ROUTE · NOT OUR OBJECTIVE", Color("#bec5c9"))
	_restart.pressed.connect(restart_mission)
	_reset_attempt()
	_refresh_objective()


func _physics_process(delta: float) -> void:
	if objective.outcome == Outcome.ACTIVE:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	for patrol in _patrols:
		_step_patrol(patrol, delta)
	var frame := Passage.Observation.new()
	frame.neris_fell = _neris_fell
	_sample_party(frame.refugees, Group.REFUGEES)
	_sample_party(frame.witnesses, Group.WITNESSES)
	var prior := [objective.group_route(Group.REFUGEES), objective.group_route(Group.WITNESSES)]
	if _interact and not command_view:
		_read_interaction(frame)
	_interact = false
	objective.advance(frame)
	for group: Group in [Group.REFUGEES, Group.WITNESSES]:
		var route := objective.group_route(group)
		var party := _parties[group]
		if route != prior[group]:
			_plan_route(party, group, route, prior[group])
			_patrols[route - 1].active = true
		if objective.may_advance(group):
			_move_party(party, party.next_stop(), delta, true)
		elif objective.group_status(group) == Status.BLOCKED:
			# Under pressure the party falls back to the last cleared marker.
			_move_party(party, party.last_safe(), delta, false)
		party.actor.visible = objective.group_status(group) != Status.LOST
	_refresh_objective()
	if objective.outcome != Outcome.ACTIVE:
		mission_finished.emit(objective.outcome == Outcome.SUCCEEDED)


func _sample_party(observation: Passage.GroupObservation, group: Group) -> void:
	var party := _parties[group]
	observation.shelf_open = _next_segment_open(party, Route.SHELF)
	observation.side_open = _next_segment_open(party, Route.SIDE)
	observation.terrace_reached = not party.path.is_empty() and party.next == party.path.size() \
		and _terrace.has_point(to_global(_ground(party.position, 0.8)))
	observation.lost = _lost[group]


func _next_segment_open(party: Party, route: Route) -> bool:
	var patrol := _patrols[route - 1]
	return not (party.next_stop().is_equal_approx(patrol.choke()) and patrol.contests())


func _read_interaction(frame: Passage.Observation) -> void:
	var at := battle.hero_position
	if at.distance_to(_route("RefugeeStaging")) <= INTERACT_RADIUS and objective.group_status(Group.REFUGEES) == Status.STAGED:
		frame.refugee_guide_met = true
		_notice = ""
		return
	if at.distance_to(_route("WitnessStaging")) <= INTERACT_RADIUS and objective.group_status(Group.WITNESSES) == Status.STAGED:
		frame.witness_guide_signaled = true
		_notice = "" if objective.group_status(Group.REFUGEES) != Status.STAGED else "Meet the refugee guide first."
		return
	var route := _decision_at(at)
	var group := _candidate_for(route)
	if group == -1:
		_notice = "No party can take an order here. Use a guide or a marked route decision."
		return
	if group == Group.REFUGEES:
		frame.refugees.route_confirmed = route
	else:
		frame.witnesses.route_confirmed = route
	_notice = ""


func _decision_at(at: Vector2) -> Route:
	if at.distance_to(_route("ShelfDecision")) <= INTERACT_RADIUS:
		return Route.SHELF
	if at.distance_to(_route("SideDecision")) <= INTERACT_RADIUS:
		return Route.SIDE
	return Route.NONE


func _candidate_for(route: Route) -> int:
	if route == Route.NONE:
		return -1
	# An unassigned party goes first; a subsequent fresh press can turn back
	# a blocked party once its feet are at its last safe marker.
	for index in _parties.size():
		if objective.group_status(index) == Status.WAITING:
			return index
	for index in _parties.size():
		var party := _parties[index]
		if objective.group_status(index) == Status.BLOCKED and route != objective.group_route(index) \
				and party.position.is_equal_approx(party.last_safe()):
			return index
	return -1


func _plan_route(party: Party, group: Group, route: Route, old: Route) -> void:
	var plan := PackedVector2Array()
	if old != Route.NONE:
		# A lane change uses the safe half of the old route in reverse,
		# never a shortcut across the rock wall or teleport to the fork.
		var old_path := _branch(old)
		var last := old_path.find(party.last_safe())
		for index in range(last - 1, -1, -1):
			plan.append(old_path[index])
	var branch := _branch(route)
	if not plan.is_empty() and plan[-1] == branch[0]:
		branch.remove_at(0)
	# Preserve the actual origin as the first safe waypoint of the new order.
	party.path = PackedVector2Array([party.position])
	party.path.append_array(plan)
	party.path.append_array(branch)
	for marker: String in TERRACE:
		party.path.append(_route(marker))
	party.path.append(_spot("Objectives", SAFETY[group]))
	party.next = 1


func _branch(route: Route) -> PackedVector2Array:
	var points := PackedVector2Array([_route("SafeStaging")])
	for marker: String in SHELF if route == Route.SHELF else SIDE:
		points.append(_route(marker))
	return points


func _move_party(party: Party, target: Vector2, delta: float, advance: bool) -> void:
	party.position = _walk_actor(party.actor, party.position, target, PARTY_SPEED * delta, false)
	if advance and party.next < party.path.size() and party.position == target:
		party.next += 1


func _step_patrol(patrol: Patrol, delta: float) -> void:
	if not patrol.active:
		return
	patrol.actor.visible = true
	patrol.screened = _guard_holds(patrol.choke())
	var target: Vector2
	var last := patrol.path.size() - 1
	if patrol.screened and patrol.next >= last:
		target = patrol.path[last - 1]
		patrol.position = _walk_actor(patrol.actor, patrol.position, target, RIVAL_SPEED * delta, true)
		patrol.next = last
	elif patrol.next < patrol.path.size():
		target = patrol.path[patrol.next]
		patrol.position = _walk_actor(patrol.actor, patrol.position, target, RIVAL_SPEED * delta, true)
		if patrol.position == target:
			patrol.next += 1


func _guard_holds(choke: Vector2) -> bool:
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD and formation.can_receive_orders() \
				and formation.position.distance_to(choke) <= SCREEN_RADIUS \
				and absf(_ground(formation.position).y - _ground(choke).y) <= 1.5:
			return true
	return false


func _walk_actor(actor: Node3D, from: Vector2, target: Vector2, step: float, formation: bool) -> Vector2:
	var next := from.move_toward(target, step)
	if next == from or not _terrain.can_move(from, next, formation):
		return from
	var heading := next - from
	actor.rotation.y = atan2(-heading.x, -heading.y)
	actor.position = _ground(next)
	return next


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_BACKSPACE:
				restart_mission()
				return
			KEY_SPACE:
				if not command_view:
					_interact = true
					return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact = true
			return
	if objective.outcome == Outcome.ACTIVE:
		super._unhandled_input(event)


## Hooks for real encounter results; the graybox patrols only contest movement.
func report_neris_fell() -> void:
	_neris_fell = true


func report_group_lost(group: Group) -> void:
	_lost[group] = true


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_guards()
	_sync_view()
	_reset_attempt()
	_refresh_objective()


func _reset_attempt() -> void:
	_interact = false
	_neris_fell = false
	_lost = [false, false]
	_notice = ""
	for index in _parties.size():
		var party := _parties[index]
		party.position = _route(STAGING[index])
		party.path.clear()
		party.next = 0
		party.actor.position = _ground(party.position)
		party.actor.rotation = Vector3.ZERO
		party.actor.visible = true
	for patrol in _patrols:
		patrol.position = patrol.path[0]
		patrol.next = 1
		patrol.active = false
		patrol.screened = false
		patrol.actor.position = _ground(patrol.position)
		patrol.actor.rotation = Vector3.ZERO
		patrol.actor.visible = false


func _build_placeholders() -> void:
	_name_guards()
	super._build_placeholders()


func _name_guards() -> void:
	for index in GUARD_NAMES.size():
		battle.formations[index].title = GUARD_NAMES[index]


func _make_patrol(group_name: String, path: Array[Vector2]) -> void:
	var patrol := Patrol.new()
	patrol.path = PackedVector2Array(path)
	patrol.actor = _make_debug_party(group_name, 6, 0)
	patrol.label = _sign(patrol.actor, Vector3.UP * 2.6, group_name, RISK)
	_patrols.append(patrol)


## Reuse the harness's existing debug formation members and materials.
## Civilian and rival identities come from the objective readout, not new art.
func _make_debug_party(group_name: String, count: int, template_index: int) -> Node3D:
	var actor := Node3D.new()
	actor.name = group_name.to_pascal_case()
	add_child(actor)
	var template: Node3D = _formation_members[template_index][0]
	for index in count:
		var member := template.duplicate(0) as Node3D
		actor.add_child(member)
		member.position = Vector3(float(index % 3) * 0.72 - 0.72, 0.0, floorf(float(index) / 3.0) * 0.68 - 0.36)
	return actor

func _refresh_objective() -> void:
	_refugees_label.text = _party_status(Group.REFUGEES)
	_witnesses_label.text = _party_status(Group.WITNESSES)
	for index in _parties.size():
		var group: Group = index
		var status := objective.group_status(group)
		_parties[index].label.modulate = RISK if status in [Status.BLOCKED, Status.LOST] else (READY if status == Status.SAFE else SHELTER)
	var pressures := PackedStringArray()
	for index in _patrols.size():
		var patrol := _patrols[index]
		if patrol.contests():
			pressures.append(ROUTE_NAMES[index + 1] + " contested")
		elif patrol.active:
			pressures.append(ROUTE_NAMES[index + 1] + (" screened" if patrol.screened else " rival approaching"))
		patrol.label.text = ("Rival shelf company" if index == 0 else "Side detachment") + (" · falling back" if patrol.screened else "")
	_pressure_label.text = "Pressure: " + (" · ".join(pressures) if not pressures.is_empty() else "No rival movement yet")
	match objective.outcome:
		Outcome.SUCCEEDED:
			_goal.text = "Both groups are safe on the witness terrace."
			_orders.text = "The guides will speak for their own people. The vault is not ours to close."
		Outcome.FAILED:
			_goal.text = "The passage has failed."
			_orders.text = "Neris fell." if _neris_fell else "The passage lost a group before reaching safety."
		_:
			_goal.text = "Escort the refugees and witnesses to the terrace."
			_orders.text = _current_prompt()


func _party_status(group: Group) -> String:
	var status := objective.group_status(group)
	var route := objective.group_route(group)
	return GROUP_NAMES[group] + ": " + (Status.keys()[status] as String).capitalize() \
		+ (" · " + ROUTE_NAMES[route] if route != Route.NONE else "")


func _current_prompt() -> String:
	var hero := battle.hero_position
	if command_view:
		return "Move a volunteer formation to a marked screen. Hold the rejoin to drive the rivals back."
	if hero.distance_to(_route("RefugeeStaging")) <= INTERACT_RADIUS and objective.group_status(Group.REFUGEES) == Status.STAGED:
		return "Cross / Space: speak with the refugee guide."
	if hero.distance_to(_route("WitnessStaging")) <= INTERACT_RADIUS and objective.group_status(Group.WITNESSES) == Status.STAGED:
		return "Cross / Space: signal the witness guide."
	var route := _decision_at(hero)
	var index := _candidate_for(route)
	if index != -1:
		return "Cross / Space: confirm %s for the %s." % [ROUTE_NAMES[route], GROUP_NAMES[index].to_lower()]
	if not _notice.is_empty():
		return _notice
	return "Meet the guides, then confirm a lane at either marker. Blocked groups wait in cover."


func _pin(point: Vector2, caption: String, tint: Color) -> void:
	_sign(self, _ground(point, 2.4), caption, tint)


func _sign(parent: Node3D, at: Vector3, caption: String, tint: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.016
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	parent.add_child(label)
	label.position = at
	return label


func _route(id: String) -> Vector2:
	return _spot("Routes", id)


func _spot(folder: String, id: String) -> Vector2:
	return _marker_position(battlefield_marker(NodePath("Markers/%s/%s" % [folder, id])))


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	for patrol in _patrols:
		if patrol.active:
			result.append(patrol.position)
	return result
