extends Node3D
## Play the same pure sortie against live positions; text markers only.

const Sortie := preload("res://game/combat/flying_sortie.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Role := Sortie.Role

enum Drill { BOMBING, ANTI_AIR, INTERCEPTION, ESCORT }

const TITLES := ["Bombing and canopy", "Ground anti-air", "Fighter interception", "Fighter escort"]
const OUTCOMES := [
	"", "Hit", "Canopy sheltered the ground target", "Terrain blocked the shot", "Target moved clear",
	"Target lost", "Defender drove off the flyer", "Flyer lost", "Terrain blocked the flight",
]
const MOVE_SPEED := 3.6
const AIR_MOVE_SPEED := 7.0

var drill := Drill.BOMBING
var sortie: Sortie
var _flyer: Sortie.Actor
var _target: Sortie.Actor
var _defender: Sortie.Actor
var _controlled: Sortie.Actor
var _terrain: Terrain
var _canopies: Array[Node3D] = []
var _open_site: Vector3
var _keys: Dictionary[Key, bool] = {}
var _stick := Vector2.ZERO
var _cross_down := false
var _joypad := -1
var _flyer_marker: Label3D
var _target_marker: Label3D
var _escort_marker: Label3D
var _notice := ""

@onready var _map: Node3D = $Marches
@onready var _camera: Camera3D = $Camera
@onready var _readout: Label = $HUD/Panel/Margin/Readout


func _ready() -> void:
	_terrain = Terrain.new(_map)
	_canopies.assign(_map.get_node("Cover").find_children("Canopy*", "MeshInstance3D", false, false))
	var canopy: MeshInstance3D = _map.get_node("Cover/Canopy00")
	# Just outside the existing canopy, but close enough to walk under it
	# without also leaving the pass's footprint.
	_open_site = to_local(canopy.global_position) + Vector3(2, 0, 0)
	var center := Vector3(_open_site.x, 4, _open_site.z + 11)
	_camera.position = center + Vector3(0, 38, 28)
	_camera.look_at(to_global(center))
	_flyer_marker = _marker(Color("#ffc0a7"))
	_target_marker = _marker(Color("#bce9fa"))
	# Keep the diagnostic position label legible beneath existing leaves.
	_target_marker.no_depth_test = true
	_escort_marker = _marker(Color("#b6e9c9"))
	Input.joy_connection_changed.connect(_joy_changed)
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		_joypad = connected[0]
	_stage(Drill.BOMBING)


func _stage(next: Drill) -> void:
	drill = next
	_notice = ""
	var land := _open_site
	land.y = _height(land)
	var air := land + Vector3.UP * 12.0
	var air_target := drill in [Drill.INTERCEPTION, Drill.ESCORT]
	_flyer = _actor(Role.FIGHTER if air_target else Role.BOMBER, 0, air + Vector3.BACK * 24.0)
	_target = _actor(Role.BOMBER if air_target else Role.GROUND, 1, air if air_target else land)
	_defender = null
	if drill == Drill.ANTI_AIR:
		_defender = _target
		_defender.anti_air_equipped = true
	elif drill == Drill.ESCORT:
		_defender = _actor(Role.FIGHTER, 1, air + Vector3(5, 0, 3))
	_controlled = _defender if _defender else _target
	if _defender:
		_defender.response_ready = false
	sortie = Sortie.new(_clear_lane, _ground_covered)
	_escort_marker.visible = drill == Drill.ESCORT
	_refresh()


func _physics_process(delta: float) -> void:
	var motion := _movement()
	if not motion.is_zero_approx():
		var point := _controlled.position
		var velocity := MOVE_SPEED if _controlled.role == Role.GROUND else AIR_MOVE_SPEED
		var next := point + Vector3(motion.x, 0, motion.y) * velocity * delta
		# Keep the diagnostic target inside the visible test site.
		next.x = clampf(next.x, _open_site.x - 9.0, _open_site.x + 9.0)
		next.z = clampf(next.z, _open_site.z - 7.0, _open_site.z + 11.0)
		if _controlled.role == Role.GROUND:
			var from := _map.to_local(to_global(point))
			var to := _map.to_local(to_global(next))
			if _terrain.can_move(Vector2(from.x, from.z), Vector2(to.x, to.z), false):
				next.y = _height(next)
				_controlled.position = next
		elif _clear_lane(point, next):
			_controlled.position = next
	if _defender:
		_defender.response_ready = (_keys.has(KEY_H) or _cross_down) and motion.is_zero_approx()
	sortie.advance(delta)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: Key = event.physical_keycode
		if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_H]:
			if event.pressed:
				_keys[code] = true
			else:
				_keys.erase(code)
		elif event.pressed:
			match code:
				KEY_G: _launch()
				KEY_BACKSPACE: _stage(drill)
				KEY_1: _stage(Drill.BOMBING)
				KEY_2: _stage(Drill.ANTI_AIR)
				KEY_3: _stage(Drill.INTERCEPTION)
				KEY_4: _stage(Drill.ESCORT)
	elif _joypad < 0 or _joypad == event.device:
		if event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_LEFT_X:
				_stick.x = event.axis_value
			elif event.axis == JOY_AXIS_LEFT_Y:
				_stick.y = event.axis_value
		elif event is InputEventJoypadButton:
			if event.button_index == JOY_BUTTON_A:
				_cross_down = event.pressed
			elif event.pressed:
				match event.button_index:
					JOY_BUTTON_RIGHT_SHOULDER: _launch()
					JOY_BUTTON_START: _stage(drill)
					JOY_BUTTON_DPAD_LEFT: _stage(posmod(drill - 1, TITLES.size()))
					JOY_BUTTON_DPAD_RIGHT: _stage(posmod(drill + 1, TITLES.size()))


func _joy_changed(device: int, connected: bool) -> void:
	if connected and _joypad < 0:
		_joypad = device
	elif not connected and _joypad == device:
		var connected_pads := Input.get_connected_joypads()
		_joypad = connected_pads[0] if not connected_pads.is_empty() else -1
		_stick = Vector2.ZERO
		_cross_down = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_keys.clear()
		_stick = Vector2.ZERO
		_cross_down = false


func _launch() -> void:
	if sortie.phase == Sortie.Phase.READY and sortie.order(_flyer, _target, _defender) != Sortie.Admission.READY:
		_notice = "No viable approach here. Reset and try again."


func _movement() -> Vector2:
	var direction := Vector2(float(_keys.has(KEY_D)) - float(_keys.has(KEY_A)),
		float(_keys.has(KEY_S)) - float(_keys.has(KEY_W)))
	return direction.limit_length() if not direction.is_zero_approx() \
		else (_stick.limit_length() if _stick.length() >= 0.18 else Vector2.ZERO)


func _actor(role: Role, team: int, point: Vector3) -> Sortie.Actor:
	return Sortie.Actor.new(Unit.new(), team, role, point)


func _height(point: Vector3) -> float:
	var local := _map.to_local(to_global(point))
	return to_local(_map.to_global(Vector3(local.x, _terrain.ground_height(Vector2(local.x, local.z)), local.z))).y


func _clear_lane(from: Vector3, to: Vector3) -> bool:
	return _terrain.clear_ranged_lane(_map.to_local(to_global(from)), _map.to_local(to_global(to)))


func _ground_covered(point: Vector3) -> bool:
	for canopy: MeshInstance3D in _canopies:
		var local := canopy.to_local(to_global(point))
		var bounds := canopy.get_aabb()
		if local.y < bounds.end.y and local.x >= bounds.position.x and local.x <= bounds.end.x \
				and local.z >= bounds.position.z and local.z <= bounds.end.z:
			return true
	return false


func _marker(color: Color) -> Label3D:
	var label := Label3D.new()
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.023
	label.outline_size = 9
	add_child(label)
	return label


func _refresh() -> void:
	var inbound := sortie.phase != Sortie.Phase.READY
	var flight := sortie.flight_position if inbound else _flyer.position
	_flyer_marker.position = flight + Vector3.UP * 0.7
	_flyer_marker.text = "Fighter ▼" if _flyer.role == Role.FIGHTER else "Bomber ▼"
	_target_marker.position = _target.position + Vector3.UP * 0.7
	_target_marker.text = "Ground target ▼" if _target.role == Role.GROUND else "Air target ▼"
	if _escort_marker.visible:
		_escort_marker.position = _defender.position + Vector3.UP * 0.7
		_escort_marker.text = "Escort ▼"
	var state: String = "Staged" if not inbound else ("Approaching" if sortie.result == Sortie.Result.NONE else OUTCOMES[sortie.result])
	var contact := "Canopy" if _target.role == Role.GROUND and _ground_covered(_target.position) else "Open"
	var response := "No response available" if not _defender else ("Holding contact" if _defender.response_ready else "Not holding")
	_readout.text = "Flying sortie · Development playtest\n%s | %s\nTarget: %s · %s · Flight distance %.1f m\n" % [
		TITLES[drill], state, contact, response, _flyer.position.distance_to(flight)]
	_readout.text += "Target HP lost: %.1f · Flyer HP lost: %.1f\n" % [sortie.target_hp_lost, sortie.flyer_hp_lost]
	_readout.text += "WASD / Left stick: move target or escort · H / Cross: hold response\n"
	_readout.text += "G / R1: launch · 1–4 / D-pad L/R: drills · Backspace / Options: reset"
	if not _notice.is_empty():
		_readout.text += "\n" + _notice
