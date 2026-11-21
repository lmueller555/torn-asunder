extends "res://game/battlefield/command_harness.gd"
## Opening graybox: one scripted raiding party, not the final mounted encounter.

signal mission_finished(won: bool)

const Cut := preload("res://game/battlefield/sereth_voices_at_the_cut.gd")
const CommandMinimap := preload("res://game/battlefield/sereth_cut_command_minimap.gd")
const Bundle := Cut.BundleStatus
const Account := Cut.AccountStatus
const Action := Cut.Interaction
const INTERACT_RADIUS := 2.25
const SCREEN_RADIUS := 7.5
const RAID_WARNING_SECONDS := 8.0
const APPROACH_SPEED := 3.3
const CARRIER_SPEED := 3.7
const UNSCREENED_CONTACT_SECONDS := 4.0
const NAMES := ["Household Guard", "Stair Guard"]
const AMBER := Color("#efca87")
const MINT := Color("#a8d8bf")
const RED := Color("#ef9477")

const START_TO_RECORDS := ["Routes/CemeteryStairFoot", "Routes/GraveCutApproach", "Objectives/ExposedRecords"]
const CUT_TO_GATE := ["Routes/GraveCutApproach", "Routes/CemeteryStairFoot", "Routes/CemeteryStairTop",
	"Routes/CemeteryHold", "Routes/GateOuterTurn", "Routes/GateInnerTurn"]
const GATE_TO_ROOM := ["Routes/LaneWestTurn", "Routes/LaneSouthTurn", "Routes/LaneSecurityBend",
	"Routes/LaneEastTurn", "Routes/LaneClerkTurn", "Routes/ClerkYard", "Routes/RecordRoomDoor", "Routes/RecordRoomInside"]
const GATE_TO_ROAD := ["Routes/WestLaneEntrance", "Routes/WestLaneRoadJunction", "Routes/RoadBrace",
	"Routes/RoadTownGate", "Routes/RoadRecordFork"]
const ROOM_TO_ROAD := ["Routes/RecordRoomInside", "Routes/RecordRoomDoor", "Routes/RecordEntryBend",
	"Objectives/DroppedBundleRecovery", "Routes/OpenRecordApproach", "Routes/RoadRecordFork"]
const EAST_EXIT := ["Routes/RoadEastReveal", "Objectives/EnemyRetreatExit"]

enum Raid { WAITING, WARNING, APPROACH_CUT, APPROACH_ROOM, AT_ROOM, TAKE_IN_ROOM, EXTRACTING, DISPERSED, RETREATING_EMPTY }

@export var enable_command_minimap := false

var objective := Cut.new()
var _iren: Node3D
var _clerk: Node3D
var _bundle: Node3D
var _raider: Node3D
var _raider_label: Label3D
var _witness_beacon: Node3D
var _entry_beacon: Node3D
var _secure_beacon: Node3D
var _exit_beacon: Node3D
var _witness_at: Vector3
var _entry_at: Vector3
var _clerk_at: Vector3
var _exposed_at: Vector3
var _secure_at: Vector3
var _drop_at: Vector3
var _retreat_at: Vector3
var _contest: AABB
var _raid := Raid.WAITING
var _warning_left := 0.0
var _contact_time := 0.0
var _raid_route := PackedVector3Array()
var _raid_stop := 0
var _interact := false

@onready var _account_readout: Label = $ObjectiveHUD/Panel/Margin/Readout/Account
@onready var _bundle_readout: Label = $ObjectiveHUD/Panel/Margin/Readout/Bundle
@onready var _pressure: Label = $ObjectiveHUD/Panel/Margin/Readout/Pressure
@onready var _hint: Label = $ObjectiveHUD/Panel/Margin/Readout/Hint
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart
@onready var _command_minimap: CommandMinimap = $ObjectiveHUD/CommandMinimap


func _ready() -> void:
	super._ready()
	_witness_at = _point("Objectives/WitnessAccount")
	_entry_at = _point("Objectives/AccountEntry")
	_clerk_at = _point("Spawns/VillageClerk")
	_exposed_at = _point("Objectives/ExposedRecords")
	_secure_at = _point("Objectives/BundleSecure")
	_retreat_at = _point("Objectives/EnemyRetreatExit")
	var zone := battlefield_marker(^"Markers/PhaseZones/RecordRoomContest")
	var size: Vector3 = zone.get_meta(&"box_size")
	_contest = AABB(zone.global_position - size / 2.0, size)
	_iren = _party("Iren", MINT, 1)
	_iren.global_position = _point("Spawns/Iren")
	_clerk = _party("Village clerk", MINT, 1)
	_clerk.global_position = _clerk_at
	_bundle = Node3D.new()
	add_child(_bundle)
	_mesh(_bundle, _box(Vector3(0.96, 0.35, 0.66)), _material(Color("#a76f47")), Vector3.UP * 0.20)
	_mesh(_bundle, _box(Vector3(0.12, 0.39, 0.68)), _material(Color("#ead3ac")), Vector3.UP * 0.20)
	_sign(_bundle, "Records bundle", AMBER, 1.25)
	_raider = _party("March records party", RED, 3)
	_raider_label = _raider.get_node("Sign")
	_witness_beacon = _beacon(_witness_at, "WITNESS ACCOUNT", MINT)
	_entry_beacon = _beacon(_entry_at, "ACCOUNT ENTRY", MINT)
	_secure_beacon = _beacon(_secure_at, "SECURE RECORDS", AMBER)
	_exit_beacon = _beacon(_retreat_at, "ENEMY RETREAT", RED)
	_beacon(_point("Routes/CemeteryHold"), "STAIR HOLD", MINT)
	_beacon(_point("Routes/RecordRoomDoor"), "RECORD ROOM DOOR", AMBER)
	_restart.pressed.connect(restart_mission)
	_reset_scene()


func _physics_process(delta: float) -> void:
	if objective.outcome == Cut.Outcome.ACTIVE:
		super._physics_process(delta)
	elif objective.outcome == Cut.Outcome.SUCCEEDED and _raid == Raid.RETREATING_EMPTY:
		# A standalone victory can finish before the empty party leaves. Only
		# its presentation continues, not input, interactions or objectives.
		_step_empty_retreat(delta)


func _after_battle_step(delta: float) -> void:
	var hero := hero_world_position()
	var frame := Cut.Observation.new()
	if _interact and not command_view:
		frame.hero_interaction = _interaction_at(hero)
		frame.sereth_at_witness_account = frame.hero_interaction == Action.LISTEN_TO_IREN
		frame.sereth_at_account_entry = frame.hero_interaction == Action.RELAY_ACCOUNT
		frame.sereth_at_bundle = frame.hero_interaction == Action.PICK_UP_BUNDLE
		frame.sereth_at_bundle_secure = frame.hero_interaction == Action.SECURE_BUNDLE
	frame.clerk_at_entry = _near(_clerk.global_position, _clerk_at)
	_step_raider(delta, hero, frame)
	frame.record_room_contested = _room_contested()
	_interact = false
	objective.advance(frame)
	if _raid == Raid.WAITING and (objective.account_status != Account.UNHEARD or objective.bundle_status == Bundle.WITH_SERETH):
		_warning_left = RAID_WARNING_SECONDS
		_raid = Raid.WARNING
		_raider.show()
	_sync_bundle(hero)
	_refresh_readout()
	if objective.outcome != Cut.Outcome.ACTIVE:
		mission_finished.emit(objective.outcome == Cut.Outcome.SUCCEEDED)
	elif enable_command_minimap:
		_command_minimap.advance_routes()


func _interaction_at(hero: Vector3) -> Cut.Interaction:
	if objective.account_status == Account.UNHEARD and _near(hero, _witness_at):
		return Action.LISTEN_TO_IREN
	if objective.account_status == Account.HEARD and _near(hero, _entry_at):
		return Action.RELAY_ACCOUNT
	if objective.bundle_status in [Bundle.EXPOSED, Bundle.DROPPED] and _near(hero, _bundle.global_position):
		return Action.PICK_UP_BUNDLE
	if objective.bundle_status == Bundle.WITH_SERETH and _near(hero, _secure_at):
		return Action.SECURE_BUNDLE
	return Action.NONE


func _step_raider(delta: float, hero: Vector3, frame: Cut.Observation) -> void:
	match _raid:
		Raid.WAITING, Raid.DISPERSED:
			return
		Raid.RETREATING_EMPTY:
			_step_empty_retreat(delta)
			return
		Raid.WARNING:
			_warning_left = maxf(0.0, _warning_left - delta)
			if _warning_left == 0.0:
				_start_route(Raid.APPROACH_CUT, START_TO_RECORDS)
			return

	var raider_feet := _raider.global_position
	if _screened():
		_contact_time = 0.0
		if _interact and not command_view and _near(hero, raider_feet):
			frame.hero_interaction = Action.NONE
			_drop_at = raider_feet
			frame.enemy_dropped_bundle = objective.bundle_status == Bundle.WITH_ENEMY
			if frame.enemy_dropped_bundle and _raid == Raid.EXTRACTING:
				# Keep this actor's current route/cursor; the dropped bundle
				# stays at contact while the now-unarmed party withdraws.
				_raid = Raid.RETREATING_EMPTY
			else:
				_raid = Raid.DISPERSED
				_raider.hide()
		return
	if _near(hero, raider_feet):
		_contact_time += delta
		frame.sereth_fell = _contact_time >= UNSCREENED_CONTACT_SECONDS
	else:
		_contact_time = 0.0
	if frame.sereth_fell:
		return

	match _raid:
		Raid.APPROACH_CUT:
			if _walk_raider(APPROACH_SPEED * delta):
				if objective.bundle_status == Bundle.EXPOSED and frame.hero_interaction != Action.PICK_UP_BUNDLE:
					frame.enemy_took_bundle = true
					_start_route(Raid.EXTRACTING, CUT_TO_GATE + GATE_TO_ROAD + EAST_EXIT)
				else:
					_start_route(Raid.APPROACH_ROOM, CUT_TO_GATE + GATE_TO_ROOM)
		Raid.APPROACH_ROOM:
			if _walk_raider(APPROACH_SPEED * delta):
				_raid = Raid.AT_ROOM
		Raid.AT_ROOM:
			if objective.bundle_status == Bundle.SECURED:
				_start_route(Raid.TAKE_IN_ROOM, ["Objectives/BundleSecure"])
		Raid.TAKE_IN_ROOM:
			if _walk_raider(APPROACH_SPEED * delta) and objective.bundle_status == Bundle.SECURED:
				frame.enemy_took_bundle = true
				_start_route(Raid.EXTRACTING, ROOM_TO_ROAD + EAST_EXIT)
		Raid.EXTRACTING:
			frame.enemy_carrier_at_retreat_exit = _walk_raider(CARRIER_SPEED * delta) \
				and _raider.global_position.is_equal_approx(_retreat_at)


func _step_empty_retreat(delta: float) -> void:
	if _walk_raider(CARRIER_SPEED * delta):
		_raid = Raid.DISPERSED
		_raider.hide()


func _room_contested() -> bool:
	return _raid in [Raid.APPROACH_ROOM, Raid.AT_ROOM, Raid.TAKE_IN_ROOM, Raid.EXTRACTING] \
		and _contest.has_point(_raider.global_position + Vector3.UP * 0.8) and not _screened()


func _screened() -> bool:
	for formation in battle.formations:
		if formation.order != Battle.Order.HOLD:
			continue
		var raider_position := _local_xz(_raider.global_position)
		if formation.position.distance_to(raider_position) <= SCREEN_RADIUS \
				and _terrain.clear_melee_contact(formation.position, raider_position):
			return true
	return false


func _start_route(stage: Raid, markers: Array) -> void:
	_raid = stage
	_raid_stop = 0
	_raid_route.clear()
	for id: String in markers:
		_raid_route.append(_point(id))


func _walk_raider(budget: float) -> bool:
	while _raid_stop < _raid_route.size() and budget > 0.0:
		var point := _raid_route[_raid_stop]
		var from := _local_xz(_raider.global_position)
		var target := _local_xz(point)
		var next := from.move_toward(target, budget)
		if not _terrain.can_move(from, next, false):
			return false
		var direction := next - from
		if not direction.is_zero_approx():
			_raider.rotation.y = atan2(-direction.x, -direction.y)
		_raider.global_position = to_global(_ground(next))
		budget -= direction.length()
		if not next.is_equal_approx(target):
			break
		_raider.global_position = point
		_raid_stop += 1
	return _raid_stop == _raid_route.size()


func _sync_bundle(hero: Vector3) -> void:
	match objective.bundle_status:
		Bundle.EXPOSED: _bundle.global_position = _exposed_at
		Bundle.WITH_SERETH: _bundle.global_position = hero + Vector3(-0.5, 0.91, 0.0)
		Bundle.WITH_ENEMY: _bundle.global_position = _raider.global_position + Vector3(0.4, 0.91, 0.0)
		Bundle.DROPPED: _bundle.global_position = _drop_at
		Bundle.SECURED: _bundle.global_position = _secure_at
		Bundle.EXTRACTED: _bundle.hide()


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_interact = not command_view
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact = true
			return
	if objective.outcome == Cut.Outcome.ACTIVE:
		super._unhandled_input(event)


func _sync_view() -> void:
	super._sync_view()
	if _command_minimap:
		_command_minimap.refresh(self, enable_command_minimap and objective.outcome == Cut.Outcome.ACTIVE)


func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_interact = false


func _build_placeholders() -> void:
	_name_guards()
	super._build_placeholders()


func _name_guards() -> void:
	for index in range(NAMES.size()):
		battle.formations[index].title = NAMES[index]


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	_name_guards()
	_sync_view()
	_reset_scene()


func _reset_scene() -> void:
	_interact = false
	_raid = Raid.WAITING
	_warning_left = 0.0
	_contact_time = 0.0
	_raid_route.clear()
	_raid_stop = 0
	_raider.global_position = _point("Spawns/MarchStairParty")
	_raider_label.text = "March records party"
	_raider.hide()
	_bundle.show()
	_sync_bundle(hero_world_position())
	_refresh_readout()


func _refresh_readout() -> void:
	_witness_beacon.visible = objective.account_status == Account.UNHEARD
	_entry_beacon.visible = objective.account_status in [Account.HEARD, Account.RELAYED]
	_secure_beacon.visible = objective.bundle_status == Bundle.WITH_SERETH
	_exit_beacon.visible = objective.bundle_status == Bundle.WITH_ENEMY
	_account_readout.text = "Iren's account  ·  " + [
		"Unheard at cemetery stair", "Heard: “I heard my name. I recognized the voice.”",
		"Relayed to the clerk", "Filed as Iren's firsthand account",
	][objective.account_status]
	_bundle_readout.text = "Records bundle  ·  " + [
		"Exposed below the cemetery stair", "Carried by Sereth", "Taken by March party",
		"Dropped and recoverable", "Secured in the record room", "Taken through the east retreat",
	][objective.bundle_status]
	_pressure.text = ""
	_hint.text = "Approach a marked objective in hero view and use Cross / Space."
	if objective.outcome == Cut.Outcome.SUCCEEDED:
		_pressure.text = "Account filed and records secured"
		_hint.text = "The clerk will catalog the records."
		return
	if objective.outcome == Cut.Outcome.FAILED:
		_pressure.text = "Sereth fell" if objective.failure == Cut.Failure.SERETH_FELL else "Records extracted"
		_hint.text = "Restart to screen the party before its escape."
		return
	if _raid == Raid.WAITING:
		return
	if _raid == Raid.WARNING:
		_pressure.text = "March party approaching the records in %d s" % ceili(_warning_left)
		return
	if _raid == Raid.DISPERSED:
		_pressure.text = "March party driven back"
		return
	if _raid == Raid.RETREATING_EMPTY:
		_raider_label.text = "Retreating"
		_pressure.text = "March party withdrawing without the records."
		if objective.bundle_status == Bundle.DROPPED:
			_hint.text = "Recover the dropped bundle here. There is no need to pursue."
		return
	if _screened():
		_raider_label.text = "March records party · screened"
		_pressure.text = "March party stalled"
		_hint.text = "Approach the screened party as Sereth and use Cross / Space to drive it back."
	elif _contact_time > 0.0:
		_raider_label.text = "March records party · threatening Sereth"
		_pressure.text = "Sereth is exposed. Back away or order a nearby guard to Hold."
	elif _room_contested():
		_raider_label.text = "March records party · contesting room"
		_pressure.text = "Record room contested. Filing and securing the records are paused."
		_hint.text = "Screen the party with a guard on Hold, then approach it as Sereth."
	elif _raid == Raid.EXTRACTING:
		_raider_label.text = "March records party · carrying records"
		_pressure.text = "Enemy carrier withdrawing east. Intercept before the marked retreat."
	else:
		_raider_label.text = "March records party"
		_pressure.text = "March party advancing. A guard on Hold can stall it."


func _near(from: Vector3, to: Vector3) -> bool:
	return from.distance_to(to) <= INTERACT_RADIUS \
		and _terrain.clear_melee_contact(_local_xz(from), _local_xz(to))


func _local_xz(world: Vector3) -> Vector2:
	var at := to_local(world)
	return Vector2(at.x, at.z)


func _point(id: String) -> Vector3:
	return battlefield_marker(NodePath("Markers/" + id)).global_position


func _beacon(point: Vector3, title: String, color: Color) -> Node3D:
	var marker := Node3D.new()
	add_child(marker)
	marker.global_position = point
	_mesh(marker, _ring(1.14, 1.26), _material(color, true), Vector3.UP * 0.06)
	_sign(marker, title, color, 2.65)
	return marker


func _party(title: String, color: Color, count: int) -> Node3D:
	var party := Node3D.new()
	add_child(party)
	var material := _material(color)
	for index in range(count):
		var at := Vector3((index - (count - 1) / 2.0) * 0.64, 0.0, 0.0)
		_mesh(party, _box(Vector3(0.43, 1.14, 0.34)), material, at + Vector3.UP * 0.62)
		_mesh(party, _box(Vector3(0.28, 0.32, 0.27)), material, at + Vector3.UP * 1.37)
	_sign(party, title, color, 1.92)
	return party


func _sign(parent: Node3D, title: String, color: Color, height: float) -> void:
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = title
	sign.modulate = color
	sign.outline_size = 9
	sign.pixel_size = 0.024
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = height
	parent.add_child(sign)


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions([_raider])
