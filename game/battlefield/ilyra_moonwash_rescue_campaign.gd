extends "res://game/battlefield/command_harness.gd"
## The prototype's salvagers pressure the exposed fore transfer. An actual
## Marine Hold on the mooring screens them; neither side uses combat damage here.

signal mission_cleared(result: StringName)

const Rescue := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const CREW_SPEED := 2.8
const SALVAGER_SPEED := 5.8
const INTERACT_RADIUS := 2.1
const SCREEN_RADIUS := 5.2
const MARINES := 1
const HARBOR := "res://game/battlefields/moonwash_harbor_campaign.tscn"
const SIGNAL_SIDE_OFFSET := 1.1
const RESCUE_SIGNALS := [
	[^"ForwardSignal", ^"ForwardReceiverSignal"],
	[^"AftSignal", ^"AftReceiverSignal"],
]
const POINT_NAMES := ["Fore", "Aft"]
const COLORS := [Color("#eac781"), Color("#8de3ce")]
const SPAWN_PATHS := [^"Markers/Spawns/ForwardCrew", ^"Markers/Spawns/AftCrew"]
const TRANSFER_PATHS := [^"Markers/Objectives/ForwardTransfer", ^"Markers/Objectives/AftTransfer"]
const RECEIVER_PATHS := [^"Markers/Objectives/ForwardReceiver", ^"Markers/Objectives/AftReceiver"]

var objective := Rescue.new()
var _routes: Array[PackedVector3Array] = []
var _crews: Array[Node3D] = []
var _lines: Array[Node3D] = []
var _next_stop: Array[int] = [1, 1]
var _cargo: Node3D
var _cargo_origin: Vector3
var _receiving_deck: Vector3
var _cargo_carried := false
var _salvagers: Node3D
var _salvage_route := PackedVector3Array()
var _salvage_stop := 1
var _salvage_started := false
var _salvager_sign: Label3D
var _mooring_beacon: Node3D
var _interact_requested := false

@onready var _progress: Label = $ObjectiveHUD/Panel/Margin/Readout/Progress
@onready var _pressure: Label = $ObjectiveHUD/Panel/Margin/Readout/Pressure
@onready var _hint: Label = $ObjectiveHUD/Panel/Margin/Readout/Hint
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_clear_rescue_endpoints()
	for transfer in range(POINT_NAMES.size()):
		var start := _point(SPAWN_PATHS[transfer])
		var rig := _point(TRANSFER_PATHS[transfer])
		var deck := _point(RECEIVER_PATHS[transfer])
		_routes.append(PackedVector3Array([start, rig, deck]))
		var tint: Color = COLORS[transfer]
		_crews.append(_party(POINT_NAMES[transfer] + " crew", tint))
		_lines.append(_line(rig, deck, tint))
		_beacon(rig, POINT_NAMES[transfer].to_upper() + " RIG", tint)
		_beacon(deck, POINT_NAMES[transfer].to_upper() + " RECEIVER", tint.darkened(0.14))
	_cargo_origin = _point(^"Markers/Objectives/OptionalCargo")
	_receiving_deck = _point(^"Markers/Objectives/ReceivingDeck")
	_cargo = Node3D.new()
	add_child(_cargo)
	_mesh(_cargo, _box(Vector3(1.12, 0.60, 0.80)), _material(Color("#a67541")), Vector3.UP * 0.30)
	_mesh(_cargo, _box(Vector3(1.14, 0.10, 0.82)), _material(Color("#dac388")), Vector3.UP * 0.45)
	_sign(_cargo, "Optional cargo", Color("#f8deac"), 1.7)
	_beacon(_receiving_deck, "CARGO LANDING", Color("#f8deac"))
	_salvage_route = PackedVector3Array([
		_point(^"Markers/Spawns/ShoreSalvagers"), _cargo_origin,
		_point(^"Markers/Routes/OpenMooring"),
	])
	_salvagers = _party("Shore salvagers", Color("#e68768"))
	_salvager_sign = _salvagers.get_node("PartySign")
	_mooring_beacon = _beacon(_salvage_route[-1], "MARINES HOLD HERE", Color("#ed9b77"))
	_restart.pressed.connect(restart_mission)
	_reset_scene()
	_refresh_objective()


func _clear_rescue_endpoints() -> void:
	if not _field or _field.scene_file_path != HARBOR:
		return
	var ships := _field.get_node_or_null(^"Geometry/Ships")
	if not ships:
		return
	# Only this deployed Ilyra instance moves the original post assemblies.
	# Move each pair away from its crew's diagonal approach. The water gap,
	# transfer anchors, shared mesh resources, and actual rig stay untouched.
	for transfer in RESCUE_SIGNALS.size():
		var side := -1.0 if transfer == Rescue.Transfer.FORWARD else 1.0
		for path: NodePath in RESCUE_SIGNALS[transfer]:
			var post := ships.get_node_or_null(path) as StaticBody3D
			if post:
				post.position.x += side * SIGNAL_SIDE_OFFSET


func _physics_process(delta: float) -> void:
	if objective.outcome == Rescue.Outcome.ACTIVE:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var frame := Rescue.Observation.new()
	if _interact_requested and not command_view:
		_interact(frame)
	_interact_requested = false
	if frame.hero_rigged_transfer == Rescue.Transfer.FORWARD:
		_salvage_started = true
	if _salvage_started:
		_salvage_stop = _move_along(_salvagers, _salvage_route, _salvage_stop, SALVAGER_SPEED * delta)
	frame.forward.receiving_point_contested = _forward_contested()
	for transfer in range(POINT_NAMES.size()):
		var report: Rescue.TransferReport = frame.forward if transfer == Rescue.Transfer.FORWARD else frame.aft
		if objective.crew_status(transfer) == Rescue.CrewStatus.CROSSING and not report.receiving_point_contested:
			_next_stop[transfer] = _move_along(_crews[transfer], _routes[transfer], _next_stop[transfer], CREW_SPEED * delta)
		report.crew_at_receiving_deck = _next_stop[transfer] == _routes[transfer].size()
	objective.advance(frame)
	if _cargo_carried:
		_cargo.global_position = hero_world_position() + Vector3(-0.45, 0.9, 0.0)
	elif objective.cargo_recovered:
		_cargo.global_position = _receiving_deck + Vector3(0.95, 0.0, 0.4)
	_refresh_objective()
	if objective.outcome == Rescue.Outcome.SUCCEEDED:
		mission_cleared.emit(objective.clear_result)


func _interact(frame: Rescue.Observation) -> void:
	var target := _interaction_target()
	match target:
		"rig_0": frame.hero_rigged_transfer = Rescue.Transfer.FORWARD
		"rig_1": frame.hero_rigged_transfer = Rescue.Transfer.AFT
		"lift": _cargo_carried = true
		"load":
			_cargo_carried = false
			frame.cargo_at_receiving_deck = true


func _interaction_target() -> String:
	var feet := hero_world_position()
	for transfer in range(POINT_NAMES.size()):
		if not objective.line_is_rigged(transfer) and feet.distance_to(_routes[transfer][1]) <= INTERACT_RADIUS:
			return "rig_%d" % transfer
	if not objective.cargo_recovered:
		if not _cargo_carried and feet.distance_to(_cargo_origin) <= INTERACT_RADIUS:
			return "lift"
		if _cargo_carried and feet.distance_to(_receiving_deck) <= INTERACT_RADIUS:
			return "load"
	return ""


func _forward_contested() -> bool:
	return _salvage_started and _salvage_stop == _salvage_route.size() and not _marine_screen()


func _marine_screen() -> bool:
	var formation := battle.formations[MARINES]
	var local := to_local(_salvage_route[-1])
	return formation.order == Battle.Order.HOLD and formation.position.distance_to(Vector2(local.x, local.z)) <= SCREEN_RADIUS


func _move_along(actor: Node3D, path: PackedVector3Array, next: int, budget: float) -> int:
	while next < path.size() and budget > 0.0:
		var target := path[next]
		var offset := target - actor.global_position
		if offset.length_squared() > 0.000001:
			actor.rotation.y = atan2(-offset.x, -offset.z)
		actor.global_position = actor.global_position.move_toward(target, budget)
		if actor.global_position != target:
			break
		budget -= offset.length()
		next += 1
	return next


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_interact_requested = not command_view
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact_requested = true
			return
	if objective.outcome == Rescue.Outcome.ACTIVE:
		super._unhandled_input(event)


func _build_placeholders() -> void:
	_name_formations()
	super._build_placeholders()


func _name_formations() -> void:
	battle.formations[0].title = "Ship Archers"
	battle.formations[MARINES].title = "Shore Marines"


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	_name_formations()
	_sync_view()
	_reset_scene()
	_refresh_objective()


func _reset_scene() -> void:
	_interact_requested = false
	_cargo_carried = false
	_cargo.global_position = _cargo_origin
	_salvage_started = false
	_salvage_stop = 1
	_salvagers.global_position = _salvage_route[0]
	for transfer in range(POINT_NAMES.size()):
		_next_stop[transfer] = 1
		_crews[transfer].global_position = _routes[transfer][0]


func _refresh_objective() -> void:
	const STATES := ["Stranded", "Crossing", "Paused", "Safe", "Lost"]
	var status := PackedStringArray()
	for transfer in range(POINT_NAMES.size()):
		var rigged := objective.line_is_rigged(transfer)
		_lines[transfer].visible = rigged
		status.append("%s line: %s / crew: %s" % [
			POINT_NAMES[transfer], "Rigged" if rigged else "Unrigged", STATES[objective.crew_status(transfer)],
		])
	var cargo_status := "Aboard" if objective.cargo_recovered else "Carrying" if _cargo_carried else "On shore"
	_progress.text = "\n".join(status) + "\nCargo (optional): " + cargo_status
	_salvagers.visible = _salvage_started
	_mooring_beacon.visible = _salvage_started and objective.crew_status(Rescue.Transfer.FORWARD) != Rescue.CrewStatus.SAFE
	_salvager_sign.text = "Salvagers screened" if _marine_screen() else "Shore salvagers"
	if objective.outcome == Rescue.Outcome.SUCCEEDED:
		_pressure.text = "Rescue complete. Both crews have landed."
	elif _forward_contested():
		_pressure.text = "Fore receiver contested. Hold Shore Marines at the open mooring."
	elif _salvage_started and _salvage_stop < _salvage_route.size():
		_pressure.text = "Salvagers approaching the open mooring; the aft lane is still clear."
	elif _marine_screen():
		_pressure.text = "Shore Marines are screening the forward transfer."
	else:
		_pressure.text = "No pressure on either receiving point."
	if objective.outcome == Rescue.Outcome.SUCCEEDED:
		_hint.text = "Restart to replay the rescue."
	elif command_view:
		_hint.text = "Release L2 / Shift to rig lines or handle cargo as Ilyra."
	else:
		match _interaction_target():
			"rig_0": _hint.text = "Cross / Space: rig the fore line."
			"rig_1": _hint.text = "Cross / Space: rig the aft line."
			"lift": _hint.text = "Cross / Space: lift the optional cargo."
			"load": _hint.text = "Cross / Space: load the cargo on the receiving deck."
			_: _hint.text = "Use the pier gangways to reach the marked rigs on the stranded deck."


func _line(rig: Vector3, receiver: Vector3, tint: Color) -> Node3D:
	var line := Node3D.new()
	add_child(line)
	line.global_position = (rig + receiver) * 0.5 + Vector3.UP * 0.07
	line.look_at(receiver + Vector3.UP * 0.07, Vector3.UP)
	var length := rig.distance_to(receiver)
	_mesh(line, _box(Vector3(0.83, 0.10, length)), _material(tint.darkened(0.33)))
	for side in [-1.0, 1.0]:
		_mesh(line, _box(Vector3(0.05, 0.05, length)), _material(tint, true), Vector3(side * 0.41, 0.44, 0))
	return line


func _party(label: String, tint: Color) -> Node3D:
	var party := Node3D.new()
	add_child(party)
	var uniform := _material(tint)
	var skin := _material(tint.lightened(0.38))
	for index in range(3):
		var offset := Vector3(0, 0, -index * 0.90)
		_mesh(party, _box(Vector3(0.54, 0.95, 0.43)), uniform, offset + Vector3.UP * 0.7)
		_mesh(party, _box(Vector3(0.38, 0.39, 0.36)), skin, offset + Vector3.UP * 1.36)
	var sign := _sign(party, label, tint, 2.3)
	sign.name = "PartySign"
	return party


func _beacon(point: Vector3, label: String, tint: Color) -> Node3D:
	var beacon := Node3D.new()
	add_child(beacon)
	beacon.global_position = point
	_mesh(beacon, _ring(1.38, 1.52), _material(tint, true), Vector3.UP * 0.045)
	_sign(beacon, label, tint, 2.6)
	return beacon


func _sign(parent: Node3D, label: String, tint: Color, height: float) -> Label3D:
	var sign := Label3D.new()
	sign.text = label
	sign.modulate = tint
	sign.font_size = 42
	sign.outline_size = 11
	sign.pixel_size = 0.025
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = height
	parent.add_child(sign)
	return sign


func _point(path: NodePath) -> Vector3:
	return battlefield_marker(path).global_position
