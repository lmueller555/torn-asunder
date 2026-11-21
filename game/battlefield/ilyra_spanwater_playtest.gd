extends "res://game/battlefield/command_harness.gd"
## Shared Spanwater terrain; local rescue actors and a visible, authored river rise.
## Marines screen an interdicting patrol. Moving text is debug actor display,
## and the flow/plank overlays reuse existing battlefield mesh/material resources.

signal mission_finished(won: bool)

const Rescue := preload("res://game/battlefield/ilyra_spanwater_evacuation.gd")

# Same provisional upstream release beat as the feeder view, not another save.
const RELEASE_AT := 32.0
const RIVER_SPEED := 13.0
const RISE_SPEED := 0.024
const WARNING_HEIGHT := 0.6
const CLOSED_HEIGHT := 1.5
const HOUSEHOLD_SPEED := 5.0
const BOARD_SPEED := 2.1
const BOAT_SPEED := 8.2
const PATROL_SPEED := 5.3
const HERO_REACH := 3.0
const GROUP_PATHS := [
	["Spawns/HouseholdsNear", "Routes/LandingApproach", "Routes/LandingFoot", "Objectives/LowLanding"],
	["Spawns/HouseholdsFar", "Routes/HouseholdScreenTurn", "Routes/LandingApproach", "Routes/LandingFoot", "Objectives/LowLanding"],
]
const HOUSEHOLD_NAMES := ["Near households", "Far households"]
const ALERT := Color("#ffbc82")
const SAFE := Color("#a4eacb")

enum BoatLeg { UPSTREAM, APPROACH, BERTH, OUTBOUND, CLEARED, RETURNING, DISABLED }


class Party:
	var view: Node3D
	var sign: Label3D
	var path := PackedVector2Array()
	var next := 1


class Boat:
	var view: Node3D
	var sign: Label3D
	var leg := BoatLeg.UPSTREAM
	var outflow_wait := false
	var disabled := false
	var starting_point := Vector3.ZERO


var objective := Rescue.new()
var _groups: Array[Party] = []
var _boats: Array[Boat] = []
var _patrol: Node3D
var _patrol_start: Vector2
var _screen_point: Vector2
var _approach_contested := false
var _interact := false
var _elapsed := 0.0
var _ilyra_fell := false
var _lost_groups: Array[Rescue.Group] = []
var _upstream: Vector3
var _hold: Vector3
var _berth: Vector3
var _outbound_hold: Vector3
var _boat_exit: Vector3
var _berth_sign: Label3D
var _hold_sign: Label3D
var _gangplank: MeshInstance3D
var _loading_group := Rescue.Group.NONE
var _loading_launch := Rescue.Launch.NONE
var _loading_distance := 0.0
var _landing: Vector3
var _landing_box: Rect2
var _ford_box: Rect2
var _flood_depth := 0.0
var _ford_closed := false
var _front_x := 0.0
var _sweep_start: Vector3
var _ford_x: float
var _river: MeshInstance3D
var _stairs_water: MeshInstance3D

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _status: Label = $ObjectiveHUD/Panel/Margin/Readout/Status
@onready var _cue: Label = $ObjectiveHUD/Panel/Margin/Readout/Cue
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_upstream = _location("BoatRoute/UpstreamHold")
	_hold = _location("BoatRoute/OutflowHold")
	_berth = _location("BoatRoute/BoatBerth")
	_boat_exit = _location("BoatRoute/BoatExit")
	# A loaded boat's hold point is on the tested berth-to-exit segment.
	_outbound_hold = _berth.lerp(_boat_exit, 0.30)
	_landing = _location("Objectives/LowLanding")
	_screen_point = _xz(_location("Routes/LandingApproach"))
	_patrol_start = _xz(_location("Routes/HouseholdScreenTurn"))
	_landing_box = _footprint("PhaseZones/LandingClosure")
	_ford_box = _footprint("PhaseZones/LowCrossingClosure")
	_sweep_start = _location("Routes/ReleaseSweepStart")
	_ford_x = _location("Routes/ReleaseSweepEnd").x
	_make_actors()
	_restart.pressed.connect(restart_mission)
	_reset_attempt()


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _name_formations() -> void:
	battle.formations[0].title = "Landing Marines"
	battle.formations[1].title = "Bank Guard"


func _physics_process(delta: float) -> void:
	if objective.outcome == Rescue.Outcome.ACTIVE:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var frame := Rescue.Observation.new()
	frame.hero_fell = _ilyra_fell
	frame.hero_called_group = _called_group() if _interact and not command_view else Rescue.Group.NONE
	_interact = false
	_step_river(delta, frame)
	_step_patrol(delta)
	frame.landing_contested = _approach_contested
	for group in Rescue.GROUPS:
		_step_group(group, delta, frame.near if group == Rescue.Group.NEAR else frame.far)
	for launch in Rescue.LAUNCHES:
		_step_boat(launch, delta, frame.first if launch == Rescue.Launch.FIRST else frame.second)
	if not frame.landing_closed_by_rise and not objective.landing_closed:
		_step_boarding(delta, frame)
	objective.advance(frame)
	_sync_actors()
	_refresh()
	if objective.outcome != Rescue.Outcome.ACTIVE:
		mission_finished.emit(objective.outcome == Rescue.Outcome.SUCCEEDED)


func _step_river(delta: float, frame: Rescue.Observation) -> void:
	var before := _elapsed
	_elapsed += delta
	if _elapsed < RELEASE_AT:
		return
	frame.spillway_release_started = before < RELEASE_AT
	var active := _elapsed - RELEASE_AT
	var front_limit := _boat_exit.x + 4.0
	_front_x = minf(front_limit, _sweep_start.x + active * RIVER_SPEED)
	_ford_closed = _front_x >= _ford_x
	var rise_start := (_landing.x - _sweep_start.x) / RIVER_SPEED
	_flood_depth = minf(CLOSED_HEIGHT, maxf(0.0, active - rise_start) * RISE_SPEED)
	frame.last_departure_warned = _flood_depth >= WARNING_HEIGHT
	frame.landing_closed_by_rise = _flood_depth >= CLOSED_HEIGHT


func _strong_current() -> bool:
	var travel_seconds := (_hold.x - _sweep_start.x) / RIVER_SPEED
	var since_front := _elapsed - RELEASE_AT - travel_seconds
	return since_front >= 0.0 and since_front < 23.0


func _step_patrol(delta: float) -> void:
	var screened := false
	for formation in battle.formations:
		if formation.order == Battle.Order.HOLD and formation.position.distance_to(_screen_point) <= 4.5:
			screened = true
			break
	_patrol.visible = _elapsed >= 5.0
	if _patrol.visible:
		_walk_actor(_patrol, _patrol_start if screened else _screen_point, PATROL_SPEED * delta)
	_approach_contested = _patrol.visible and _xz(_patrol.position).distance_to(_screen_point) < 4.6


func _step_group(group: Rescue.Group, delta: float, report: Rescue.GroupReport) -> void:
	var party := _groups[group - 1]
	var status := objective.group_status(group)
	report.definitively_lost = group in _lost_groups
	var at_approach := party.next >= party.path.size() - 2
	report.approach_contested = _approach_contested and at_approach
	if status in [Rescue.GroupStatus.APPROACHING, Rescue.GroupStatus.WAITING_AT_LANDING] 			and not report.approach_contested and party.next < party.path.size() and not objective.landing_closed:
		if _walk_actor(party.view, party.path[party.next], HOUSEHOLD_SPEED * delta):
			party.next += 1
	report.at_low_landing = party.next == party.path.size()


func _step_boat(launch: Rescue.Launch, delta: float, report: Rescue.LaunchReport) -> void:
	var boat := _boats[launch - 1]
	report.definitively_disabled = boat.disabled
	if boat.disabled:
		boat.leg = BoatLeg.DISABLED
		return
	boat.outflow_wait = false
	var distance := BOAT_SPEED * delta
	match boat.leg:
		BoatLeg.UPSTREAM:
			var delay := 5.0 if launch == Rescue.Launch.FIRST else 17.0
			if _elapsed >= delay and (_separated_at_hold(launch) or boat.view.position.distance_to(_hold) > 8.0):
				var target := _hold
				if not _separated_at_hold(launch):
					target = _hold.move_toward(_upstream, 8.0)
				if _sail(boat, target, distance) and target == _hold:
					boat.leg = BoatLeg.APPROACH
		BoatLeg.APPROACH:
			if _strong_current() and boat.view.position.distance_to(_hold) < 0.1:
				boat.outflow_wait = true
			elif not _berth_reserved(launch):
				if _sail(boat, _berth, distance):
					boat.leg = BoatLeg.BERTH
		BoatLeg.BERTH:
			if objective.passenger_group(launch) != Rescue.Group.NONE:
				boat.leg = BoatLeg.OUTBOUND
				_sail(boat, _outbound_hold, distance)
				report.departed_low_landing = true
		BoatLeg.OUTBOUND:
			if _strong_current() and boat.view.position.x <= _outbound_hold.x:
				boat.outflow_wait = _sail(boat, _outbound_hold, distance)
				report.held_at_outflow_by_current = boat.outflow_wait
			elif _sail(boat, _boat_exit, distance):
				boat.leg = BoatLeg.CLEARED
				report.crossed_boat_exit = true
		BoatLeg.CLEARED:
			var other := _boats[1 if launch == Rescue.Launch.FIRST else 0]
			if other.disabled and not objective.landing_closed and not _berth_reserved(launch):
				boat.leg = BoatLeg.RETURNING
		BoatLeg.RETURNING:
			if not _berth_reserved(launch) and _sail(boat, _berth, distance):
				boat.leg = BoatLeg.BERTH
	report.at_berth = boat.leg == BoatLeg.BERTH


func _step_boarding(delta: float, frame: Rescue.Observation) -> void:
	if _loading_group == Rescue.Group.NONE and not _approach_contested:
		for group in Rescue.GROUPS:
			if objective.group_status(group) != Rescue.GroupStatus.WAITING_AT_LANDING:
				continue
			for launch in Rescue.LAUNCHES:
				if _boats[launch - 1].leg == BoatLeg.BERTH and objective.passenger_group(launch) == Rescue.Group.NONE:
					_loading_group = group
					_loading_launch = launch
					break
			if _loading_launch != Rescue.Launch.NONE:
				break
	if _loading_group == Rescue.Group.NONE:
		return
	var party := _groups[_loading_group - 1]
	var boat := _boats[_loading_launch - 1]
	if boat.disabled or boat.leg != BoatLeg.BERTH:
		party.view.position = _landing
		_reset_boarding()
		return
	if _approach_contested:
		return
	var deck := boat.view.position + Vector3.UP * 0.75
	_loading_distance += BOARD_SPEED * delta
	party.view.position = _landing.move_toward(deck, _loading_distance)
	if party.view.position.distance_to(deck) <= 0.08:
		frame.boarded_group = _loading_group
		frame.boarding_launch = _loading_launch


func _berth_reserved(by: Rescue.Launch) -> bool:
	for other in Rescue.LAUNCHES:
		if other == by:
			continue
		var boat := _boats[other - 1]
		if boat.leg == BoatLeg.BERTH or (boat.leg == BoatLeg.APPROACH and boat.view.position.distance_to(_hold) > 0.1) 				or (boat.leg == BoatLeg.OUTBOUND and boat.view.position.distance_to(_berth) < 8.0):
			return true
	return false


func _separated_at_hold(by: Rescue.Launch) -> bool:
	var other := _boats[1 if by == Rescue.Launch.FIRST else 0]
	return other.disabled or other.view.position.distance_to(_hold) >= 8.0


func _sail(boat: Boat, target: Vector3, distance: float) -> bool:
	var next := boat.view.position.move_toward(target, distance)
	var heading := next - boat.view.position
	if heading.length_squared() > 0.000001:
		boat.view.rotation.y = atan2(-heading.x, -heading.z)
	boat.view.position = next
	return next == target


func _walk_actor(actor: Node3D, target: Vector2, travel: float) -> bool:
	var from := _xz(actor.position)
	while from != target and travel > 0.0:
		var step := minf(0.20, travel)
		var next := from.move_toward(target, step)
		if not _terrain.can_move(from, next, false):
			return false
		actor.position = _ground(next)
		from = next
		travel -= step
	return from == target


func _called_group() -> Rescue.Group:
	for group in Rescue.GROUPS:
		if objective.group_status(group) == Rescue.GroupStatus.SHELTERED 				and battle.hero_position.distance_to(_groups[group - 1].path[0]) <= HERO_REACH:
			return group
	return Rescue.Group.NONE


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view:
			_interact = true
			return
	if event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact = true
			return
	if objective.outcome == Rescue.Outcome.ACTIVE:
		super._unhandled_input(event)


func _movement_check() -> Callable:
	return _can_move


func _can_move(from: Vector2, to: Vector2, formation: bool) -> bool:
	if (_ford_closed and _enters_flood(from, to, _ford_box, 3.0)) 			or (objective.landing_closed and _enters_flood(from, to, _landing_box, CLOSED_HEIGHT + 0.15)):
		return false
	return _terrain.can_move(from, to, formation)


func _enters_flood(from: Vector2, to: Vector2, area: Rect2, waterline: float) -> bool:
	var depth := _rect_depth(to, area)
	return depth > 0.0 and depth >= _rect_depth(from, area) and _ground(to).y <= waterline


func _rect_depth(point: Vector2, area: Rect2) -> float:
	if not area.has_point(point):
		return 0.0
	return minf(minf(point.x - area.position.x, area.end.x - point.x), minf(point.y - area.position.y, area.end.y - point.y))


func report_launch_disabled(launch: Rescue.Launch) -> void:
	if launch in Rescue.LAUNCHES:
		_boats[launch - 1].disabled = true


func report_households_lost(group: Rescue.Group) -> void:
	if group in Rescue.GROUPS:
		_lost_groups.append(group)


func report_ilyra_fell() -> void:
	_ilyra_fell = true


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	_name_formations()
	_reset_attempt()
	_sync_view()


func _reset_attempt() -> void:
	_elapsed = 0.0
	_interact = false
	_ilyra_fell = false
	_lost_groups.clear()
	_approach_contested = false
	_ford_closed = false
	_flood_depth = 0.0
	_front_x = _sweep_start.x
	_reset_boarding()
	for party in _groups:
		party.next = 1
		party.view.position = _ground(party.path[0])
	for boat in _boats:
		boat.leg = BoatLeg.UPSTREAM
		boat.view.position = boat.starting_point
		boat.view.rotation.y = -PI / 2.0
		boat.disabled = false
		boat.outflow_wait = false
	_patrol.position = _ground(_patrol_start)
	_patrol.hide()
	_sync_actors()
	_refresh()


func _reset_boarding() -> void:
	_loading_group = Rescue.Group.NONE
	_loading_launch = Rescue.Launch.NONE
	_loading_distance = 0.0


func _sync_actors() -> void:
	for launch in Rescue.LAUNCHES:
		var group := objective.passenger_group(launch)
		if group != Rescue.Group.NONE:
			_groups[group - 1].view.position = _boats[launch - 1].view.position + Vector3.UP * 0.75
			if _loading_group == group:
				_reset_boarding()
	_gangplank.visible = not objective.landing_closed and (_boats[0].leg == BoatLeg.BERTH or _boats[1].leg == BoatLeg.BERTH)
	var length := _front_x - _sweep_start.x
	_river.visible = length > 0.0
	_river.position = _sweep_start + Vector3(length * 0.5, 0.19, 0.0)
	_river.scale.x = maxf(length, 0.005) / _river.mesh.get_aabb().size.x
	_stairs_water.visible = _flood_depth > 0.0
	_stairs_water.position.y = _landing.y + _flood_depth


func _refresh() -> void:
	var groups := PackedStringArray()
	var launches := PackedStringArray()
	for group in Rescue.GROUPS:
		var status := objective.group_status(group)
		var party := _groups[group - 1]
		var title: String = HOUSEHOLD_NAMES[group - 1]
		var state := ["", "Sheltering", "Walking", "At landing", "Aboard", "Safe", "Lost"][status] as String
		if status == Rescue.GroupStatus.APPROACHING and _approach_contested and party.next >= party.path.size() - 2:
			state = "Waiting for screen"
		party.view.visible = status != Rescue.GroupStatus.SAFE
		party.sign.text = "%s · %s" % [title, state]
		if status == Rescue.GroupStatus.SHELTERED:
			party.sign.text += " · Cross / Space"
		groups.append("%s: %s" % [title, state])
	for launch in Rescue.LAUNCHES:
		var boat := _boats[launch - 1]
		var state := ["Upstream", "Approaching", "Berthed", "Away", "Cleared", "Returning", "Disabled"][boat.leg] as String
		if boat.outflow_wait:
			state = "Held by current"
		boat.view.visible = launch == Rescue.Launch.FIRST or _elapsed >= 17.0
		boat.sign.text = "Launch %d · %s" % [launch, state]
		launches.append(boat.sign.text)
	_status.text = "    |    ".join(groups) + "\n" + "    |    ".join(launches)
	_goal.text = "Bring both household groups to the landing and get their launches through the boat exit."
	_cue.text = "Cross / Space at either household. Hold Marines at the landing approach to push back the patrol."
	if objective.landing_closed:
		_cue.text = "LANDING CLOSED · loaded launches can still cross the exit."
	elif objective.last_departure_warned:
		_cue.text = "LAST DEPARTURE · water is climbing the landing steps. Board before it reaches the top mark."
	elif _strong_current():
		_cue.text = "STRONG CURRENT · launches can wait at the outflow. Keep the landing screened."
	elif _approach_contested:
		_cue.text = "PATROL AT THE APPROACH · hold a formation at the marked rise to reopen the lane."
	elif objective.release_started:
		_cue.text = "SPILLWAY OPEN · river rising. The sea gate is shut; the landing has its own warning."
	elif _elapsed >= 23.0:
		_cue.text = "SPILLWAY RELEASE AHEAD · keep the boats on the evacuation lane."
	_berth_sign.text = "LANDING CLOSED" if objective.landing_closed else "LAST DEPARTURE" if objective.last_departure_warned else "LOW LANDING · ONE BERTH"
	_hold_sign.text = "OUTFLOW HOLD · STRONG CURRENT" if _strong_current() else "OUTFLOW HOLD"
	match objective.outcome:
		Rescue.Outcome.SUCCEEDED:
			_goal.text = "Both household groups are safe beyond the boat exit."
		Rescue.Outcome.FAILED:
			match objective.failure:
				Rescue.Failure.LANDING_CLOSED: _goal.text = "The landing closed with households still ashore."
				Rescue.Failure.OCCUPIED_LAUNCH_DISABLED: _goal.text = "An occupied launch was disabled before safety."
				Rescue.Failure.HOUSEHOLDS_LOST: _goal.text = "A required household group was lost."
				Rescue.Failure.HERO_FELL: _goal.text = "Ilyra fell before the rescue was complete."


func _make_actors() -> void:
	for group in Rescue.GROUPS:
		var party := Party.new()
		party.view = _debug_actor()
		party.sign = _sign(party.view, "", Vector3.UP * 2.0, SAFE)
		for path in GROUP_PATHS[group - 1]:
			party.path.append(_xz(_location(path)))
		_groups.append(party)
	for launch in Rescue.LAUNCHES:
		var boat := Boat.new()
		boat.view = _debug_actor()
		boat.sign = _sign(boat.view, "", Vector3.UP * 2.1, SAFE)
		boat.starting_point = _upstream
		_boats.append(boat)
	_patrol = _debug_actor()
	_sign(_patrol, "BANK PATROL", Vector3.UP * 2.1, ALERT)
	_sign(self, "HOLD HERE · SCREEN THE APPROACH", _ground(_screen_point, 2.6), ALERT)
	_berth_sign = _sign(self, "", _landing + Vector3.UP * 2.5, SAFE)
	_sign(self, "LAST SAFE STEP", _landing + Vector3(-4.0, CLOSED_HEIGHT, 7.0), ALERT)
	_hold_sign = _sign(self, "", _hold + Vector3.UP * 2.6, ALERT)
	_sign(self, "BOAT EXIT", _boat_exit + Vector3.UP * 2.7, SAFE)
	var deck := _berth + Vector3.UP * 0.65
	var existing_deck := _field.get_node("Geometry/Landing/LandingDeck") as MeshInstance3D
	var existing_water := _field.get_node("Geometry/Landing/LowBasinTint") as MeshInstance3D
	_gangplank = _overlay(existing_deck, Vector3(1.1, 0.08, _landing.distance_to(deck)))
	_gangplank.position = (_landing + deck) * 0.5
	var plank_scale := _gangplank.scale
	_gangplank.look_at(to_global(deck))
	_gangplank.scale = plank_scale
	_river = _overlay(existing_water, Vector3(1.0, 0.025, 12.0))
	_stairs_water = _overlay(existing_water, Vector3(_landing_box.size.x, 0.025, _landing_box.size.y))
	_stairs_water.position = Vector3(_landing_box.get_center().x, _landing.y, _landing_box.get_center().y)


func _overlay(source: MeshInstance3D, size: Vector3) -> MeshInstance3D:
	var view := _mesh(self, source.mesh, source.material_override)
	view.scale = size / source.mesh.get_aabb().size
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view


func _debug_actor() -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	return actor

func _sign(parent: Node3D, words: String, point: Vector3, tint: Color) -> Label3D:
	var sign := Label3D.new()
	parent.add_child(sign)
	sign.position = point
	sign.text = words
	sign.modulate = tint
	sign.font_size = 52
	sign.outline_size = 11
	sign.pixel_size = 0.013
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return sign


func _location(path: String) -> Vector3:
	return to_local(battlefield_marker(NodePath("Markers/" + path)).global_position)


func _footprint(path: String) -> Rect2:
	var marker := battlefield_marker(NodePath("Markers/" + path))
	var size: Vector3 = marker.get_meta("box_size")
	var footprint := Vector2(size.x, size.z)
	return Rect2(_xz(to_local(marker.global_position)) - footprint * 0.5, footprint)


static func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions([_patrol])
