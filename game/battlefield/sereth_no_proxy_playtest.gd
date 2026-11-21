extends "res://game/battlefield/command_harness.gd"
## Development playtest only. This stand never moves the witnesses or the bridle.

signal mission_finished(won: bool)

const Finale := preload("res://game/battlefield/sereth_no_proxy.gd")
const Phase := Finale.Phase
const Route := Finale.Route
const HOUSEHOLD := 0
const COURT := 1
const NAMES := ["Household Guard", "Court Escort"]
const SHELF := ["ShelfDecision", "ShelfFoot", "ShelfClimb", "ShelfHold", "ShelfRejoin"]
const SIDE := ["SideDecision", "SideApproach", "SideTurn", "SideRampFoot", "SideBlindBend",
	"SideRampTurn", "SideNorthToe", "SideHighBend", "SideRejoin"]
const TERRACE := ["Forecourt", "TerraceApproach", "TerraceEntry"]
const RIVAL_PATH := ["RivalReserveCorner", "RivalReserveReveal"] + TERRACE
const RIVAL_RETREAT_STOP := 1
const SPEAKER_SPEED := 2.15
const RIVAL_SPEED := 2.3
const SPLIT_NOTICE_SECONDS := 2.0
const SCREEN_SECONDS := 1.4
const HERO_DANGER_SECONDS := 4.0
const INTERACTION_RADIUS := 2.3
const SCREEN_RADIUS := 6.4
const AMBER := Color("#edc98b")
const SAFE := Color("#a6e0c7")
const DANGER := Color("#fa9a80")

class Actor:
	var marker: Node3D
	var label: Label3D
	var position := Vector2.ZERO
	var path := PackedVector2Array()
	var next := 0

var objective := Finale.new()
var _speaker: Actor
var _rival: Actor
var _assembly_witnesses: Actor
var _escort_route := Route.NONE
var _escort_stalled := false
var _split_left := 0.0
var _rival_active := false
var _rival_retreating := false
var _rival_cleared := false
var _rival_screen_time := 0.0
var _hero_danger := 0.0
var _custody_zone: AABB
var _terrace_zone: AABB
var _assembly: Vector2
var _forecourt: Vector2
var _terrace_approach: Vector2
var _terrace_entry: Vector2
var _interact := false

@onready var _goal: Label = $PlaytestHUD/Panel/Margin/Readout/Goal
@onready var _route_status: Label = $PlaytestHUD/Panel/Margin/Readout/Route
@onready var _pressure: Label = $PlaytestHUD/Panel/Margin/Readout/Pressure
@onready var _hint: Label = $PlaytestHUD/Panel/Margin/Readout/Hint
@onready var _restart: Button = $PlaytestHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_assembly = _route("ValleyAssembly")
	_forecourt = _route("Forecourt")
	_terrace_approach = _route("TerraceApproach")
	_terrace_entry = _route("TerraceEntry")
	_custody_zone = _zone("CustodyLineZone")
	_terrace_zone = _zone("TerraceSafeZone")
	_speaker = _make_actor("Court speaker and escort", COURT, 5, AMBER)
	_rival = _make_actor("Rival company", HOUSEHOLD, 5, DANGER)
	_assembly_witnesses = _make_actor("Assembly witnesses", HOUSEHOLD, 3, SAFE)
	_place(_assembly_witnesses, _assembly)
	_pin(_route("ShelfDecision"), "SHELF FORK", AMBER)
	_pin(_route("SideDecision"), "SIDE PATH", AMBER)
	_pin(_spot("Objectives/CustodyLine"), "CUSTODY LINE", DANGER)
	_pin(_terrace_entry, "TERRACE APPROACH", SAFE)
	_restart.pressed.connect(restart_mission)
	_reset_attempt()


func _physics_process(delta: float) -> void:
	if objective.phase not in [Phase.SUCCEEDED, Phase.FAILED]:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var before := objective.phase
	var frame := Finale.Observation.new()
	var hero := battle.hero_position
	var fresh_interaction := _interact and not command_view
	_interact = false
	match before:
		Phase.AT_ASSEMBLY:
			frame.refuse_escort = fresh_interaction
			frame.sereth_at_assembly = _near(hero, _assembly)
			frame.witnesses_present_at_refusal = _assembly_witnesses.marker.visible \
				and _near(_assembly_witnesses.position, _assembly)
		Phase.RELEASING_COURT_TROOPS:
			_split_left = maxf(0.0, _split_left - delta)
			if _split_left == 0.0:
				_detach_escort()
				frame.court_assignments_released = true
		Phase.INTERCEPTING, Phase.CLEARING_TERRACE:
			if before == Phase.INTERCEPTING:
				_step_escort(delta)
				frame.speaker_route = _escort_route
				frame.escort_stalled_on = _escort_route if _escort_stalled else Route.NONE
				frame.challenge_speaker = fresh_interaction
				frame.sereth_at_speaker = _near(hero, _speaker.position)
				frame.speaker_crossed_custody_line = _inside(_custody_zone, _speaker.position)
				frame.speaker_before_custody_line = not frame.speaker_crossed_custody_line
			_step_rival(delta, hero)
			frame.elapsed_seconds = delta
			frame.hostiles_control_witness_position = _rival_active and not _rival_retreating \
				and not _guard_holds(_rival.position) and _inside(_terrace_zone, _rival.position)
			frame.sereth_fell = _hero_danger >= HERO_DANGER_SECONDS
			frame.terrace_approach_clear = _rival_cleared and (_near(hero, _terrace_entry) or _inside(_terrace_zone, hero))
	objective.advance(frame)
	if before == Phase.AT_ASSEMBLY and objective.phase == Phase.RELEASING_COURT_TROOPS:
		_split_left = SPLIT_NOTICE_SECONDS
	_refresh_readout()
	if objective.phase in [Phase.SUCCEEDED, Phase.FAILED]:
		mission_finished.emit(objective.phase == Phase.SUCCEEDED)


func _detach_escort() -> void:
	var court := battle.formations[COURT]
	_place(_speaker, court.position)
	_speaker.marker.show()
	_speaker.path = _route_points(["ValleyAssembly", "SafeStaging"])
	_speaker.next = 0
	court.extract()
	selected_index = HOUSEHOLD


func _step_escort(delta: float) -> void:
	if _speaker.next == _speaker.path.size() and _escort_route == Route.NONE:
		# The fork and both continuations are existing walkable markers. A real
		# screen at the shelf decision sends the court onto the longer path.
		_escort_route = Route.SIDE if _guard_holds(_route("ShelfDecision")) else Route.SHELF
		_speaker.path = _route_points((SHELF if _escort_route == Route.SHELF else SIDE) + ["Forecourt"])
		_speaker.path.append(_spot("Objectives/CustodyLine"))
		_speaker.next = 0
	if _escort_route != Route.NONE and _guard_holds(_speaker.position):
		_escort_stalled = true
		return
	_step_forward(_speaker, SPEAKER_SPEED * delta)
	_escort_stalled = _escort_route != Route.NONE and _guard_holds(_speaker.position)


func _step_rival(delta: float, hero: Vector2) -> void:
	if not _rival_active:
		if _rival_cleared or (hero.distance_to(_forecourt) > 24.0 and hero.distance_to(_terrace_approach) > 16.0):
			return
		_rival_active = true
		_rival.marker.show()
		return
	if _rival_retreating:
		_walk_actor(_rival, _rival.path[_rival.next], RIVAL_SPEED * delta)
		if _rival.position == _rival.path[_rival.next]:
			if _rival.next <= RIVAL_RETREAT_STOP:
				_rival_active = false
				_rival_cleared = true
				_rival.marker.hide()
			else:
				_rival.next -= 1
		return
	if _guard_holds(_rival.position):
		_hero_danger = 0.0
		_rival_screen_time += delta
		if _rival_screen_time >= SCREEN_SECONDS:
			_rival_retreating = true
			_rival.next = maxi(0, _rival.next - 1)
		return
	_rival_screen_time = 0.0
	_step_forward(_rival, RIVAL_SPEED * delta)
	_hero_danger = _hero_danger + delta if _near(hero, _rival.position) else 0.0


func _guard_holds(point: Vector2) -> bool:
	var guard := battle.formations[HOUSEHOLD]
	return guard.order == Battle.Order.HOLD and guard.position.distance_to(point) <= SCREEN_RADIUS \
		and _terrain.clear_melee_contact(guard.position, point)


func _step_forward(actor: Actor, stride: float) -> void:
	if actor.next >= actor.path.size():
		return
	_walk_actor(actor, actor.path[actor.next], stride)
	if actor.position == actor.path[actor.next]:
		actor.next += 1


func _walk_actor(actor: Actor, target: Vector2, stride: float) -> void:
	var next := actor.position.move_toward(target, stride)
	if next == actor.position or not _terrain.can_move(actor.position, next, false):
		return
	var direction := next - actor.position
	actor.marker.rotation.y = atan2(-direction.x, -direction.y)
	_place(actor, next)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view:
			_interact = true
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact = true
			return
	if objective.phase not in [Phase.SUCCEEDED, Phase.FAILED]:
		super._unhandled_input(event)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_interact = false


func _hero_move_factor() -> float:
	return 0.0 if objective.phase == Phase.RELEASING_COURT_TROOPS else 1.0


func _move_selected() -> void:
	# Court troops remain at the assembly until they receive the split order.
	if selected_index == HOUSEHOLD and objective.phase != Phase.RELEASING_COURT_TROOPS:
		super._move_selected()


func _hold_selected() -> void:
	if selected_index == HOUSEHOLD and objective.phase != Phase.RELEASING_COURT_TROOPS:
		super._hold_selected()


func _build_placeholders() -> void:
	_name_guards()
	super._build_placeholders()


func _name_guards() -> void:
	for index in NAMES.size():
		battle.formations[index].title = NAMES[index]


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	_name_guards()
	_sync_view()
	_reset_attempt()


func _reset_attempt() -> void:
	_interact = false
	_escort_route = Route.NONE
	_escort_stalled = false
	_split_left = 0.0
	_place(_speaker, battle.formations[COURT].position)
	_speaker.path.clear()
	_speaker.next = 0
	_speaker.marker.hide()
	_rival_active = false
	_rival_retreating = false
	_rival_cleared = false
	_rival_screen_time = 0.0
	_hero_danger = 0.0
	_place(_rival, _spot("Spawns/RivalReserve"))
	_rival.path = _route_points(RIVAL_PATH)
	_rival.path.append(_spot("Objectives/WitnessTerrace"))
	_rival.next = 0
	_rival.marker.hide()
	_refresh_readout()


func _refresh_readout() -> void:
	var route: String = ["at the fork", "shelf", "side path"][_escort_route]
	_route_status.text = "Court escort: " + (route + (" · stalled" if _escort_stalled else " · advancing") if _speaker.marker.visible else "at the assembly")
	_speaker.label.text = "Court speaker · bid halted" if objective.bid_halted else ("Court speaker · stalled" if _escort_stalled else "Court speaker and escort")
	_pressure.text = ""
	if _hero_danger > 0.0:
		_pressure.text = "Sereth is exposed. Back away from the unscreened rival company."
	elif objective.occupation_warned:
		_pressure.text = "Hostile hold on the terrace. Break it in %.1f s." % (Finale.TERRACE_OCCUPATION_LIMIT_SECONDS - objective.occupation_seconds)
	elif _rival_cleared:
		_pressure.text = "Rival company driven back. The terrace approach is open."
	elif _rival_retreating:
		_pressure.text = "The rival company is falling back."
	elif _rival_active:
		_pressure.text = "Rival company moving on the terrace. Hold its approach with the Household Guard."
	_rival.label.text = "Rival company · withdrawing" if _rival_retreating else "Rival company"
	match objective.phase:
		Phase.AT_ASSEMBLY:
			_goal.text = "Refuse the court's escort order before the witnesses."
			_hint.text = "At the assembly, use Cross / Space as Sereth. Only the Household Guard can take field orders."
		Phase.RELEASING_COURT_TROOPS:
			_goal.text = "Court troops are leaving Sereth's command."
			_hint.text = "They will escort the speaker. The Household Guard stays with Sereth."
		Phase.INTERCEPTING:
			_goal.text = "Stop the court speaker before the custody line."
			_hint.text = "Hold the speaker's actual route with the Household Guard. Approach the stalled speaker and use Cross / Space."
		Phase.CLEARING_TERRACE:
			_route_status.text = "Court escort: bid halted on the " + route
			_goal.text = "Clear the approach to the witness terrace."
			_hint.text = "Drive back the rival company with a Hold, then reach the marked terrace approach as Sereth."
		Phase.SUCCEEDED:
			_goal.text = "The court's bid is halted; the terrace approach is clear."
			_hint.text = "The witnesses may proceed. The vault is not Sereth's to close."
		Phase.FAILED:
			_goal.text = ["", "Sereth fell.", "The court speaker crossed the custody line.", "The witness position was lost."][objective.failure]
			_hint.text = "Restart to change the screen or your approach."


func _near(from: Vector2, to: Vector2) -> bool:
	return from.distance_to(to) <= INTERACTION_RADIUS and _terrain.clear_melee_contact(from, to)


func _route_points(ids: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for id: String in ids:
		points.append(_route(id))
	return points


func _route(id: String) -> Vector2:
	return _spot("Routes/" + id)


func _spot(id: String) -> Vector2:
	return _marker_position(battlefield_marker(NodePath("Markers/" + id)))


func _place(actor: Actor, position: Vector2) -> void:
	actor.position = position
	actor.marker.position = _ground(position)


func _zone(id: String) -> AABB:
	var marker := battlefield_marker(NodePath("Markers/PhaseZones/" + id))
	var size: Vector3 = marker.get_meta(&"box_size")
	return AABB(marker.global_position - size * 0.5, size)


func _inside(zone: AABB, position: Vector2) -> bool:
	return zone.has_point(to_global(_ground(position, 0.8)))


func _make_actor(title: String, template_group: int, count: int, tint: Color) -> Actor:
	var actor := Actor.new()
	actor.marker = Node3D.new()
	actor.marker.name = title.to_pascal_case()
	add_child(actor.marker)
	var template: Node3D = _formation_members[template_group][0]
	for index in count:
		var copy := template.duplicate(0) as Node3D
		actor.marker.add_child(copy)
		copy.position = Vector3((index % 3 - 1) * 0.70, 0.0, floorf(index / 3.0) * 0.68)
	actor.label = _sign(actor.marker, Vector3.UP * 2.3, title, tint)
	return actor


func _pin(at: Vector2, title: String, tint: Color) -> void:
	_sign(self, _ground(at, 2.5), title, tint)


func _sign(parent: Node3D, at: Vector3, title: String, tint: Color) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.016
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	parent.add_child(label)
	label.position = at
	return label
