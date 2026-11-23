extends "res://game/battlefield/command_harness.gd"
## Greyhollow, Year Three: the Dryads lose the mine approach in every successful
## history. The player decides whether Neris can get her own people home.

signal mission_finished(won: bool)

enum Phase { APPROACH, CONTACT, SCREEN, RETREAT, SUCCEEDED, FAILED }

const PRESS := ^"Markers/Routes/MineYard"
const MINER_ROUTE: Array[NodePath] = [
	^"Markers/Objectives/MinerAssembly", ^"Markers/Routes/TunnelEntrance",
	^"Markers/Routes/TunnelMidpoint", ^"Markers/Routes/TunnelExit",
	^"Markers/Routes/EvacuationTurn", ^"Markers/Routes/EvacuationTrail",
	^"Markers/Objectives/MinerEvacuation",
]
const COVER := Vector2(-57.0, 18.0)
const STRIKE_TURN := Vector2(-52.0, 12.0)
## The screen must clear the cover shelf in Closed before it can widen and outrun pursuit.
const SCREEN_TURN := Vector2(-57.5, 16.0)
const FALLBACK := Vector2(-34.0, 10.0)
const NERIS_SPAWN := Vector2(-62.0, 17.0)
const STRIKE_SPAWN := Vector2(-64.0, 19.0)
const SCREEN_SPAWN := Vector2(-54.0, 15.0)
const PURSUIT_ROUTE := [
	Vector2(-69.0, 38.0), Vector2(-68.0, 31.0), Vector2(-64.0, 25.0),
	COVER, Vector2(-51.0, 16.0), Vector2(-44.0, 14.0), FALLBACK,
]
const STRIKE := 0
const SCREEN_PARTY := 1
const PRESS_RADIUS := 2.8
const COVER_RADIUS := 2.6
const FALLBACK_RADIUS := 4.2
const REARGUARD_RANGE := 9.0
const LOCK_RANGE := 5.0
const COVER_SECONDS := 3.0
const WINDOW_SECONDS := 38.0
const MAX_STRENGTH := 100.0
const ALLY_COLOR := Color("#a7e3ba")
const ALERT_COLOR := Color("#ffc18a")

var phase := Phase.APPROACH
var miners_beyond_reach := false
var miners_safe := false
var seconds_left := WINDOW_SECONDS
var cover_seconds := 0.0
var strength := PackedFloat32Array([MAX_STRENGTH, MAX_STRENGTH, MAX_STRENGTH])

var _press: Vector2
var _escape_path := PackedVector2Array()
var _miner_next := 1
var _escort_next := 0
var _pursuer_next := 1
var _covering := false
var _failure := ""
var _miners: Node3D
var _escort: Node3D
var _pursuer: Node3D
var _press_beacon: Node3D
var _cover_beacon: Node3D
var _fallback_beacon: Node3D
var _turn_beacon: Node3D
var _screen_turn_beacon: Node3D
var _cover_label: Label3D

@onready var _goal: Label = $ObjectiveHUD/Panel/Margin/Readout/Goal
@onready var _status: Label = $ObjectiveHUD/Panel/Margin/Readout/Status
@onready var _cue: Label = $ObjectiveHUD/Panel/Margin/Readout/Cue
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_press = _marker_position(battlefield_marker(PRESS))
	for path in MINER_ROUTE:
		_escape_path.append(_marker_position(battlefield_marker(path)))
	_miners = _party("MINERS", Color("#dcc7a0"), 3)
	_escort = _party("HUMAN RESCUE DETAIL", Color("#b8c7e6"), 3)
	_pursuer = _party("HUMAN REARGUARD", Color("#da9277"), 4)
	_press_beacon = _beacon(_press, "PRESS THE MINE YARD", PRESS_RADIUS, ALERT_COLOR)
	_cover_beacon = _beacon(COVER, "FALLBACK SCREEN", COVER_RADIUS, ALERT_COLOR)
	_cover_label = _cover_beacon.get_node("Label")
	_turn_beacon = _beacon(STRIKE_TURN, "STRIKE TURN", 1.4, ALLY_COLOR)
	_screen_turn_beacon = _beacon(SCREEN_TURN, "SCREEN TURN", 0.7, ALLY_COLOR)
	_fallback_beacon = _beacon(FALLBACK, "EAST FALLBACK", FALLBACK_RADIUS, ALLY_COLOR)
	_restart.pressed.connect(restart_mission)
	_reset_encounter()


func _place_at_spawns() -> void:
	battle.hero_position = NERIS_SPAWN
	battle.hero_heading = Vector2.DOWN
	battle.lead.position = NERIS_SPAWN
	battle.lead.heading = Vector2.DOWN
	battle.lead.hold()
	_hero_yaw = PI
	cursor = NERIS_SPAWN
	for index in [STRIKE, SCREEN_PARTY]:
		var group := battle.formations[index]
		group.position = STRIKE_SPAWN if index == STRIKE else SCREEN_SPAWN
		group.heading = Vector2.DOWN
		group.hold()
	_name_platoons()


func _name_platoons() -> void:
	battle.lead.title = "Neris & Lead Guard"
	battle.formations[STRIKE].title = "Strike Party"
	battle.formations[SCREEN_PARTY].title = "Screen Party"


func _physics_process(delta: float) -> void:
	if phase not in [Phase.SUCCEEDED, Phase.FAILED]:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	if phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return
	var lost := _required_unit_lost()
	if not lost.is_empty():
		_fail(lost)
	elif phase == Phase.APPROACH:
		var strike := battle.formations[STRIKE]
		if strike.order == Battle.Order.HOLD and strike.position.distance_to(_press) <= PRESS_RADIUS:
			phase = Phase.CONTACT
	elif phase == Phase.CONTACT:
		_step_rescue(delta)
		_apply_pressure(delta)
		if miners_beyond_reach and phase != Phase.FAILED:
			phase = Phase.SCREEN
	elif phase in [Phase.SCREEN, Phase.RETREAT]:
		_step_rescue(delta)
		var screen := battle.formations[SCREEN_PARTY]
		var screen_holding := phase == Phase.SCREEN and screen.order == Battle.Order.HOLD \
			and screen.position.distance_to(COVER) <= COVER_RADIUS
		var in_contact := _pursuer_next <= 4 and _xz(_pursuer).distance_to(COVER) <= REARGUARD_RANGE
		_covering = screen_holding and in_contact
		if not _covering and not _rearguard_engaged() and _pursuer_next < PURSUIT_ROUTE.size():
			var speed := 2.3 if phase == Phase.RETREAT else 3.8
			if _walk(_pursuer, PURSUIT_ROUTE[_pursuer_next], speed, delta):
				_pursuer_next += 1
		_apply_pressure(delta)
		if phase != Phase.FAILED:
			_step_fallback(delta)
	_refresh_objective()
	if phase in [Phase.SUCCEEDED, Phase.FAILED]:
		mission_finished.emit(phase == Phase.SUCCEEDED)


func _step_rescue(delta: float) -> void:
	# The rescue is never blocked, damaged, or rerouted by the Dryad player.
	# These are the same markers as the Human playable route.
	if _miner_next < _escape_path.size() and _walk(_miners, _escape_path[_miner_next], 5.6, delta):
		_miner_next += 1
	if _escort_next < _escape_path.size() and _walk(_escort, _escape_path[_escort_next], 5.6, delta):
		_escort_next += 1
	miners_beyond_reach = _miner_next >= 3
	miners_safe = _miner_next == _escape_path.size()
	if miners_safe:
		_miners.hide()
	if _escort_next == _escape_path.size():
		_escort.hide()


func _step_fallback(delta: float) -> void:
	seconds_left = maxf(0.0, seconds_left - delta)
	if seconds_left <= 0.0:
		_fail("The rearguard cut off the withdrawal before everyone was clear.")
		return
	if phase == Phase.SCREEN:
		cover_seconds = minf(cover_seconds + delta, COVER_SECONDS) if _covering else 0.0
		var strike := battle.formations[STRIKE]
		if cover_seconds >= COVER_SECONDS and _at_fallback(strike.position) and _at_fallback(battle.hero_position):
			strike.extract()
			battle.lead.extract()
			phase = Phase.RETREAT
	elif _at_fallback(battle.formations[SCREEN_PARTY].position):
		battle.formations[SCREEN_PARTY].extract()
		# All required Dryad units are safe. The miners already entered the
		# shielded tunnel; do not wait on timers or count this as taking the mine.
		phase = Phase.SUCCEEDED


func _rearguard_engaged() -> bool:
	var enemy := _xz(_pursuer)
	for index in range(Battle.LEAD_INDEX, battle.formations.size()):
		var platoon := battle.formation_at(index)
		var target := battle.hero_position if index == Battle.LEAD_INDEX else platoon.position
		if platoon.can_receive_orders() and enemy.distance_to(target) <= LOCK_RANGE \
				and _terrain.clear_melee_contact(enemy, target):
			return true
	return false


func _required_unit_lost() -> String:
	for index in range(Battle.LEAD_INDEX, battle.formations.size()):
		var platoon := battle.formation_at(index)
		if platoon.order == Battle.Order.DEFEATED:
			return "Neris fell." if index == Battle.LEAD_INDEX else "The %s was overrun." % platoon.title
	return ""


func _apply_pressure(delta: float) -> void:
	var enemy := _xz(_pursuer)
	for index in range(Battle.LEAD_INDEX, battle.formations.size()):
		var platoon := battle.formation_at(index)
		if not platoon.can_receive_orders():
			continue
		var target := battle.hero_position if index == Battle.LEAD_INDEX else platoon.position
		if enemy.distance_to(target) > REARGUARD_RANGE or not _terrain.clear_melee_contact(enemy, target):
			continue
		var damage := 4.0 if phase == Phase.CONTACT else 13.0
		if _covering:
			damage = 2.5 if index == SCREEN_PARTY else 0.0
		strength[index + 1] = maxf(0.0, strength[index + 1] - damage * delta)
		if strength[index + 1] <= 0.0:
			platoon.defeat()
			_fail("Neris fell." if index == Battle.LEAD_INDEX else "The %s was overrun." % platoon.title)
			return


func _at_fallback(point: Vector2) -> bool:
	return point.distance_to(FALLBACK) <= FALLBACK_RADIUS


func _hostile_positions() -> PackedVector2Array:
	# Only the rearguard can force Neris out of marching control; the rescue
	# detail and miners never do. The lead is no longer engaged after extract.
	if phase in [Phase.CONTACT, Phase.SCREEN, Phase.RETREAT] and battle.lead.can_receive_orders():
		return PackedVector2Array([_xz(_pursuer)])
	return PackedVector2Array()


func restart_mission() -> void:
	restart_battle()
	_reset_encounter()
	_sync_view()


func _reset_encounter() -> void:
	phase = Phase.APPROACH
	miners_beyond_reach = false
	miners_safe = false
	seconds_left = WINDOW_SECONDS
	cover_seconds = 0.0
	strength = PackedFloat32Array([MAX_STRENGTH, MAX_STRENGTH, MAX_STRENGTH])
	_miner_next = 1
	_escort_next = 0
	_pursuer_next = 1
	_covering = false
	_failure = ""
	_miners.position = _ground(_escape_path[0])
	_escort.position = _ground(_escape_path[0] + Vector2(0.0, -4.0))
	_pursuer.position = _ground(PURSUIT_ROUTE[0])
	for actor in [_miners, _escort, _pursuer]:
		actor.rotation.y = PI
		actor.show()
	_refresh_objective()


func _fail(reason: String) -> void:
	_failure = reason
	phase = Phase.FAILED


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_BACKSPACE:
		restart_mission()
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device) and event.button_index == JOY_BUTTON_START:
		restart_mission()
	elif phase not in [Phase.SUCCEEDED, Phase.FAILED]:
		super._unhandled_input(event)


func _refresh_objective() -> void:
	_press_beacon.visible = phase in [Phase.APPROACH, Phase.CONTACT]
	_cover_beacon.visible = phase in [Phase.SCREEN, Phase.RETREAT]
	_turn_beacon.visible = phase == Phase.SCREEN
	_screen_turn_beacon.visible = phase == Phase.RETREAT
	_fallback_beacon.visible = phase in [Phase.SCREEN, Phase.RETREAT]
	_cover_label.text = "SCREEN HOLDING" if _covering and phase == Phase.SCREEN else ("PULL SCREEN BACK" if phase == Phase.RETREAT else "HOLD HERE · SCREEN PARTY")
	_restart.visible = phase in [Phase.SUCCEEDED, Phase.FAILED]
	_status.text = "Neris %d%%   ·   Strike %d%%   ·   Screen %d%%" % [ceili(strength[0]), ceili(strength[1]), ceili(strength[2])]
	match phase:
		Phase.APPROACH:
			_goal.text = "Press the Mine Yard with the Strike Party."
			_cue.text = "Neris believes the Godbridle will end the world if the Humans reach it. She has ordered an attack to stop them."
		Phase.CONTACT:
			_goal.text = "Human troops are covering the miners."
			_cue.text = "The rescue detail is falling back into the mine tunnel. Don't follow it into the cut."
		Phase.SCREEN:
			_goal.text = "Hold with Screen Party. Get Neris and Strike Party east."
			_status.text += "   ·   %ds to withdraw" % ceili(seconds_left)
			_cue.text = "The miners are through. Route Strike via the marked turn. Keep Screen holding until Neris and Strike are inside the east ring."
		Phase.RETREAT:
			_goal.text = "Pull the Screen Party into the east fallback."
			_status.text += "   ·   %ds to withdraw" % ceili(seconds_left)
			_cue.text = "Take the Screen Party to the marked turn in Closed, then widen to Normal and move to the east fallback."
		Phase.SUCCEEDED:
			_goal.text = "Both Dryad parties withdrew."
			_cue.text = "The Human rescue broke through the tunnel. We did not stop them."
		Phase.FAILED:
			_goal.text = "Withdrawal failed."
			_cue.text = _failure


func _walk(actor: Node3D, target: Vector2, speed: float, delta: float) -> bool:
	var from := _xz(actor)
	var direction := (target - from).normalized()
	var remaining := maxf(0.0, delta) * speed
	while from != target and remaining > 0.0:
		var distance := minf(0.22, remaining)
		var next := from.move_toward(target, distance)
		if not _terrain.can_move(from, next, true):
			return false
		actor.position = _ground(next)
		actor.rotation.y = atan2(-direction.x, -direction.y)
		remaining -= distance
		from = next
	return from == target


func _party(text: String, color: Color, count: int) -> Node3D:
	var party := Node3D.new()
	add_child(party)
	var uniform := _material(color)
	var head := _material(color.lightened(0.38))
	for index in range(count):
		var x := (float(index) - float(count - 1) * 0.5) * 0.82
		_mesh(party, _box(Vector3(0.54, 1.11, 0.51)), uniform, Vector3(x, 0.59, 0.0))
		_mesh(party, _box(Vector3(0.37, 0.35, 0.38)), head, Vector3(x, 1.34, 0.0))
	_caption(party, text, color, 1.85)
	return party


func _beacon(point: Vector2, text: String, radius: float, color: Color) -> Node3D:
	var marker := Node3D.new()
	add_child(marker)
	marker.position = _ground(point, 0.07)
	_mesh(marker, _ring(radius - 0.17, radius), _material(color, true))
	_caption(marker, text, color, 2.6)
	return marker


func _caption(parent: Node3D, text: String, color: Color, height: float) -> void:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.position.y = height
	label.modulate = color
	label.font_size = 35
	label.outline_size = 10
	label.pixel_size = 0.025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


static func _xz(actor: Node3D) -> Vector2:
	return Vector2(actor.position.x, actor.position.z)
