extends "res://game/battlefield/command_harness.gd"
## Standalone Two Shorelines. The cutter and port crews move on authored routes.
## The crews contest a relay, but this graybox has no damage or cutter combat.

signal mission_cleared(result: StringName)

const Survey := preload("res://game/battlefield/ilyra_coast_survey.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const CHART_CIRCULATED := &"chart_circulated"
const BEACH := Survey.SignalSite.BEACH
const HEADLAND := Survey.SignalSite.HEADLAND
const SITE_NAMES := ["Beach", "Headland"]
const READING_MARKERS := ["AncestralStone", "FishingInlet"]
const SIGNAL_MARKERS := ["BeachSignal", "HeadlandSignal"]
const READING_PINS: Array[StringName] = [&"ancestral_stone", &"fishing_inlet"]
const RELAY_PINS: Array[StringName] = [&"beach_relay", &"headland_relay"]
const INTERACT_RADIUS := 2.6
const HIDE_BEACH_BILLBOARDS_WITHIN := 7.5
const SHOW_BEACH_BILLBOARDS_BEYOND := 13.0
const HIDE_HEADLAND_BILLBOARDS_WITHIN := 7.5
const SHOW_HEADLAND_BILLBOARDS_BEYOND := 13.0
const STAFF_RADIUS := 4.0
const SCREEN_RADIUS := 8.0
const CONTEST_RADIUS := 4.5
const CUTTER_SPEED := 13.0
const STOP_SECONDS := 12.0
const SIGNAL_SECONDS := 3.0
const BOAT_LOOP := [
	"WestBlindPass", "WestRound", "BeachApproach", "BeachHold", "EastBlindPass",
	"ShoalReturnBend", "HeadlandApproach", "HeadlandHold", "EastOuterTurn", "OuterEast", "OuterWest",
]
const APPROACH_STOPS := [2, 6]
const HOLD_STOPS := [3, 7]

class RelayBillboard:
	var label: Label3D
	var face: Color
	var outline: Color
	var visible: bool

	func _init(node: Label3D) -> void:
		label = node
		face = node.modulate
		outline = node.outline_modulate
		visible = node.visible


var objective := Survey.new()
var _reading_points := PackedVector3Array()
var _signal_points := PackedVector3Array()
var _guard_points := PackedVector3Array()
var _cutter: Node3D
var _cutter_route := PackedVector3Array()
var _cutter_next := 1
var _dwell_left := 0.0
var _holding_site := Survey.SignalSite.NONE
var _cutter_launched := false
var _pressuring := false
var _crews: Array[Node3D] = []
var _crew_routes: Array[PackedVector3Array] = []
var _crew_next: Array[int] = [1, 1]
var _sea_guides: Node3D
var _signal_flags: Array[Node3D] = []
var _interact_requested := false
var _beach_billboards: Array[RelayBillboard] = []
var _beach_billboard_opacity := -1.0
var _headland_billboards: Array[RelayBillboard] = []
var _headland_billboard_opacity := -1.0

@onready var _chart: Label = $ObjectiveHUD/Panel/Margin/Readout/Chart
@onready var _shore: Label = $ObjectiveHUD/Panel/Margin/Readout/Shore
@onready var _hint: Label = $ObjectiveHUD/Panel/Margin/Readout/Hint
@onready var _restart: Button = $ObjectiveHUD/Panel/Margin/Readout/Restart
@onready var _minimap_panel: PanelContainer = get_node_or_null(^"ObjectiveHUD/TacticalMinimap")
@onready var _minimap: Minimap = get_node_or_null(^"ObjectiveHUD/TacticalMinimap/Margin/Readout/Map")


func _ready() -> void:
	super._ready()
	_sea_guides = Node3D.new()
	add_child(_sea_guides)
	for index in range(2):
		var reading := _point("Objectives/" + READING_MARKERS[index])
		var relay := _point("Objectives/" + SIGNAL_MARKERS[index])
		_reading_points.append(reading)
		_signal_points.append(relay)
		_beacon(reading, ["ANCESTRAL STONE", "FISHING INLET"][index], Color("#ffdc93"), self)
		_signal_flags.append(_beacon(relay, SITE_NAMES[index].to_upper() + " SIGNAL",
			Color("#85f0d7"), self, (index + 1) as Survey.SignalSite))
	for marker: String in ["BeachGuard", "HighGuard"]:
		var guard := _point("Routes/" + marker)
		_guard_points.append(guard)
		_beacon(guard, "DETACHMENT HOLD", Color("#98ccf8"), self)
	for label: String in BOAT_LOOP:
		_cutter_route.append(_point("BoatRoute/" + label))
	_build_cutter()
	_build_route_guides()
	_crew_routes.append(_route(["Spawns/LandingCrew", "Routes/LandingLine",
			"Routes/LandingWarning", "Objectives/BeachSignal"]))
	_crew_routes.append(_route(["Spawns/HeadlandPressure", "Routes/HeadlandReserveTurn",
			"Routes/HeadlandGuard", "Routes/HeadlandRampFoot", "Routes/HeadlandRampTop",
			"Routes/HeadlandApron", "Routes/HighGuard", "Objectives/HeadlandSignal"]))
	_crews.append(_build_crew("Port landing crew", BEACH))
	_crews.append(_build_crew("Landward port crew", HEADLAND))
	_restart.pressed.connect(restart_mission)
	_reset_runtime()
	_refresh_objective()


func _place_at_spawns() -> void:
	# Called by the harness before building models and again on restart.
	battle.formations.resize(1)
	battle.formations[0].title = "Shore Detachment"
	super._place_at_spawns()
	var trail := _marker_position(battlefield_marker(^"Markers/Routes/StoneTrailTurn"))
	battle.hero_heading = battle.hero_position.direction_to(trail)
	_hero_yaw = atan2(-battle.hero_heading.x, -battle.hero_heading.y)


func restart_mission() -> void:
	objective.restart()
	_restart.release_focus()
	restart_battle()
	if _sector:
		_sector.overview = false
		_sector.center_on(cursor)
	_sync_view()
	_reset_runtime()
	_refresh_objective()


func _reset_runtime() -> void:
	_cutter.global_position = _cutter_route[0]
	_face(_cutter, _cutter_route[1])
	_cutter_next = 1
	_dwell_left = 0.0
	_holding_site = Survey.SignalSite.NONE
	_cutter_launched = false
	_pressuring = false
	_interact_requested = false
	for index in range(2):
		_crew_next[index] = 1
		_crews[index].visible = false
		_crews[index].global_position = _crew_routes[index][0]
		_face(_crews[index], _crew_routes[index][1])


func _physics_process(delta: float) -> void:
	if objective.phase not in [Survey.Phase.SUCCEEDED, Survey.Phase.FAILED]:
		super._physics_process(delta)


func _update_mode() -> void:
	super._update_mode()
	_refresh_beach_billboards()
	_refresh_headland_billboards()


func _sync_view() -> void:
	super._sync_view()
	if not _minimap:
		return # The registered scene opts in with a passive HUD node.
	var active := command_view and objective.phase not in [Survey.Phase.SUCCEEDED, Survey.Phase.FAILED]
	if _minimap_panel.visible != active:
		_minimap_panel.visible = active
		if not active:
			_minimap.show_frame(null)
	if not active:
		return
	_minimap.set_field_bounds(battle.bounds)
	var frame := Minimap.Frame.new()
	frame.hero = Minimap.Marker.new(&"ilyra", battle.hero_position, battle.hero_heading)
	var detachment := battle.formations[0]
	if detachment.can_receive_orders():
		frame.allies.append(Minimap.Marker.new(&"shore_detachment", detachment.position, detachment.heading))
		frame.selected_ally = &"shore_detachment"
	for index in _reading_points.size():
		if objective.has_reading((index + 1) as Survey.Reading):
			_add_map_pin(frame, READING_PINS[index], _reading_points[index], Minimap.ObjectiveKind.PICKUP)
	# Both sites are chart options once the readings are ready. The map never
	# infers a current cutter contact, a hostile crew, or a usable signal window.
	if objective.phase in [Survey.Phase.WAITING_TO_SIGNAL, Survey.Phase.SIGNALING]:
		for index in _signal_points.size():
			_add_map_pin(frame, RELAY_PINS[index], _signal_points[index], Minimap.ObjectiveKind.EXIT)
	frame.camera_footprint = _minimap_footprint()
	_minimap.show_frame(frame)


func _add_map_pin(frame: Minimap.Frame, key: StringName, world_point: Vector3, kind: Minimap.ObjectiveKind) -> void:
	var at := to_local(world_point)
	frame.objectives.append(Minimap.Marker.new(key, Vector2(at.x, at.z), Vector2.UP, kind))


func _minimap_footprint() -> PackedVector2Array:
	var viewport := get_viewport().get_visible_rect()
	if get_viewport().get_camera_3d() != _command_camera or not viewport.has_area():
		return PackedVector2Array()
	var world_to_field := global_transform.affine_inverse()
	var corners := PackedVector2Array()
	for pixel in [viewport.position, Vector2(viewport.end.x, viewport.position.y),
			viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
		var origin := world_to_field * _command_camera.project_ray_origin(pixel)
		var direction := world_to_field.basis * _command_camera.project_ray_normal(pixel)
		var hit: Variant = FLOOR.intersects_ray(origin, direction)
		if hit == null:
			return PackedVector2Array()
		corners.append(Vector2(hit.x, hit.z))
	return corners


func _after_battle_step(delta: float) -> void:
	_advance_cutter(delta)
	if _pressuring:
		_advance_crews(delta)
	var frame := Survey.Observation.new()
	if _interact_requested and not command_view:
		frame.hero_at_reading = _near_reading()
		frame.hero_inspected_marker = frame.hero_at_reading != Survey.Reading.NONE
		frame.requested_signal = _near_site()
	_interact_requested = false
	_report_site(frame.beach, 0, delta)
	_report_site(frame.headland, 1, delta)
	objective.advance(frame)
	if frame.hero_inspected_marker and objective.has_reading(frame.hero_at_reading):
		_cutter_launched = true
	_pressuring = objective.phase != Survey.Phase.TAKING_READINGS
	_refresh_objective()
	if objective.phase == Survey.Phase.SUCCEEDED:
		mission_cleared.emit(CHART_CIRCULATED)


func _report_site(report: Survey.SignalReport, index: int, delta: float) -> void:
	var feet := hero_world_position()
	report.staffed = feet.distance_to(_signal_points[index]) <= INTERACT_RADIUS \
		or _detachment_holding_at(_signal_points[index], STAFF_RADIUS)
	report.contested = _contested(index)
	report.cutter_at_stop = _holding_site == index + 1 and _cutter.global_position.is_equal_approx(_cutter_route[HOLD_STOPS[index]])
	report.line_of_sight_clear = _clear_signal_ray(index)
	report.signal_credit = delta / SIGNAL_SECONDS


func _advance_cutter(delta: float) -> void:
	if not _cutter_launched:
		return
	if _dwell_left > 0.0:
		_dwell_left = maxf(0.0, _dwell_left - delta)
		if _dwell_left > 0.0:
			return
		_holding_site = Survey.SignalSite.NONE
	var target := _cutter_route[_cutter_next]
	_face(_cutter, target)
	_cutter.global_position = _cutter.global_position.move_toward(target, CUTTER_SPEED * delta)
	if _cutter.global_position == target:
		var stop := HOLD_STOPS.find(_cutter_next)
		if stop != -1:
			_dwell_left = STOP_SECONDS
			_holding_site = (stop + 1) as Survey.SignalSite
		_cutter_next = (_cutter_next + 1) % _cutter_route.size()


func _advance_crews(delta: float) -> void:
	for index in range(_crews.size()):
		var actor := _crews[index]
		actor.visible = true
		var next := _crew_next[index]
		var route := _crew_routes[index]
		if next >= route.size() or (_screened(index) and actor.global_position.distance_to(_guard_points[index]) <= SCREEN_RADIUS):
			continue
		var target := route[next]
		_face(actor, target)
		actor.global_position = actor.global_position.move_toward(target, (2.5 if index == 0 else 2.1) * delta)
		if actor.global_position == target:
			_crew_next[index] += 1


func _contested(index: int) -> bool:
	return _pressuring and not _screened(index) \
		and _crews[index].global_position.distance_to(_signal_points[index]) <= CONTEST_RADIUS


func _screened(index: int) -> bool:
	return _detachment_holding_at(_guard_points[index], STAFF_RADIUS) \
		or _detachment_holding_at(_signal_points[index], STAFF_RADIUS)


func _detachment_holding_at(target: Vector3, radius: float) -> bool:
	var section := battle.formations[0]
	var feet := to_global(_ground(section.position))
	if section.order != Battle.Order.HOLD or feet.distance_to(target) > radius:
		return false
	return _clear_ray(feet + Vector3.UP * 1.3, target + Vector3.UP * 1.3)


func _clear_signal_ray(index: int) -> bool:
	return _clear_ray(_signal_points[index] + Vector3.UP * 2.6, _cutter.global_position + Vector3.UP * 2.5)


func _clear_ray(from: Vector3, to: Vector3) -> bool:
	if from.is_equal_approx(to):
		return true
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Terrain.SOLID_MASK)).is_empty()


func _near_reading() -> Survey.Reading:
	var feet := hero_world_position()
	for index in range(2):
		if feet.distance_to(_reading_points[index]) <= INTERACT_RADIUS and not objective.has_reading((index + 1) as Survey.Reading):
			return (index + 1) as Survey.Reading
	return Survey.Reading.NONE


func _near_site() -> Survey.SignalSite:
	var feet := hero_world_position()
	for index in range(2):
		if feet.distance_to(_signal_points[index]) <= INTERACT_RADIUS:
			return (index + 1) as Survey.SignalSite
	return Survey.SignalSite.NONE


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE and not command_view:
			_interact_requested = true
			return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A and not command_view:
			_interact_requested = true
			return
	if objective.phase not in [Survey.Phase.SUCCEEDED, Survey.Phase.FAILED]:
		super._unhandled_input(event)


func _site_status(index: int) -> String:
	if not _cutter_launched:
		return "cutter awaiting first reading"
	if not _clear_signal_ray(index):
		return "sightline obstructed, relay contested" if _contested(index) else "sightline obstructed"
	if _holding_site == index + 1:
		return "cutter holding" if not _contested(index) else "cutter holding, relay contested"
	if _holding_site == Survey.SignalSite.NONE and _cutter_next in [APPROACH_STOPS[index], HOLD_STOPS[index]]:
		return "cutter approaching"
	if _contested(index):
		return "relay contested"
	return "cutter underway"


func _refresh_objective() -> void:
	_refresh_beach_billboards()
	_refresh_headland_billboards()
	_sea_guides.visible = command_view
	_chart.text = "Chart   ·   Ancestral stone: %s   /   Fishing inlet: %s" % [
		"recorded" if objective.has_reading(Survey.Reading.ANCESTRAL_STONE) else "unread",
		"recorded" if objective.has_reading(Survey.Reading.FISHING_INLET) else "unread",
	]
	for index in range(2):
		_signal_flags[index].scale.y = 1.6 if objective.signal_site == index + 1 else 1.0
	match objective.phase:
		Survey.Phase.SUCCEEDED:
			_shore.text = "Both readings acknowledged. Ilyra circulates the complete chart."
			_hint.text = "The drowned streets and the working village harbors both go on the record."
			return
		Survey.Phase.FAILED:
			_shore.text = "Survey failed."
			_hint.text = "Use Restart to sail again."
			return
		Survey.Phase.SIGNALING:
			_shore.text = "%s relay   ·   Signaling %d%%" % [SITE_NAMES[objective.signal_site - 1], floori(objective.signal_progress * 100.0)]
			_hint.text = "Keep the relay staffed and secure until the cutter acknowledges."
			return
		_:
			_shore.text = "Beach: %s   /   Headland: %s" % [_site_status(0), _site_status(1)]
	if command_view:
		_hint.text = "Move the detachment along marked trails, then Hold at a blue guard ring or relay."
	elif _near_reading() != Survey.Reading.NONE:
		_hint.text = "Cross / Space: record this reading for the village pilots."
	elif objective.phase == Survey.Phase.TAKING_READINGS:
		_hint.text = "First find the ancestral stone and fishing inlet. Inspect both as Ilyra."
	elif _near_site() != Survey.SignalSite.NONE:
		_hint.text = _relay_hint(_near_site() - 1)
	else:
		_hint.text = "Take the short beach turn or reach the headland from the inland ramp."


# Nearby in hero view, the original ring and objective HUD already show where
# to act and what's blocking the signal. Clear the two overlapping captions
# without touching the crew's parent visibility or any of the tactical cues.
func _refresh_beach_billboards() -> void:
	if _beach_billboards.is_empty():
		return
	var opacity := 1.0
	if not command_view:
		var distance := hero_world_position().distance_to(_signal_points[BEACH - 1])
		opacity = smoothstep(HIDE_BEACH_BILLBOARDS_WITHIN, SHOW_BEACH_BILLBOARDS_BEYOND, distance)
	if opacity == _beach_billboard_opacity:
		return
	_beach_billboard_opacity = opacity
	for style in _beach_billboards:
		style.label.visible = style.visible and opacity > 0.0
		style.label.modulate = Color(style.face, style.face.a * opacity)
		style.label.outline_modulate = Color(style.outline, style.outline.a * opacity)


# Match the Beach presentation at the high site. Only the relay's
# world label and the landward crew label are affected. The actual cue,
# status HUD, and crew visibility/movement stay in their own systems.
func _refresh_headland_billboards() -> void:
	if _headland_billboards.is_empty():
		return
	var opacity := 1.0
	if not command_view:
		var distance := hero_world_position().distance_to(_signal_points[HEADLAND - 1])
		opacity = smoothstep(HIDE_HEADLAND_BILLBOARDS_WITHIN, SHOW_HEADLAND_BILLBOARDS_BEYOND, distance)
	if opacity == _headland_billboard_opacity:
		return
	_headland_billboard_opacity = opacity
	for style in _headland_billboards:
		style.label.visible = style.visible and opacity > 0.0
		style.label.modulate = Color(style.face, style.face.a * opacity)
		style.label.outline_modulate = Color(style.outline, style.outline.a * opacity)


func _register_relay_billboard(label: Label3D, site: Survey.SignalSite) -> void:
	if site == BEACH:
		_beach_billboards.append(RelayBillboard.new(label))
	elif site == HEADLAND:
		_headland_billboards.append(RelayBillboard.new(label))


func _relay_hint(index: int) -> String:
	if _contested(index):
		return "Relay contested. Order the Shore Detachment to Hold at the blue guard ring."
	if not _clear_signal_ray(index):
		return "Headland or terrain obstructs the signal. Wait for the cutter to round it."
	if _holding_site != index + 1:
		return "Wait for the cutter to hold here. A missed pass will come around again."
	return "Cross / Space: transmit both readings while the cutter is holding in sight."


func _build_cutter() -> void:
	_cutter = Node3D.new()
	_cutter.name = "SurveyCutter"
	add_child(_cutter)
	_mesh(_cutter, _box(Vector3(4.2, 1.55, 8.4)), _material(Color("#473f36")), Vector3(0, 0.08, 0.6))
	_mesh(_cutter, _box(Vector3(3.25, 0.95, 2.1)), _material(Color("#75583f")), Vector3(0, 0.12, -4.12))
	_mesh(_cutter, _box(Vector3(3.7, 0.32, 7.8)), _material(Color("#8e7456")), Vector3(0, 0.92, 0.50))
	_mesh(_cutter, _box(Vector3(0.2, 3.0, 0.2)), _material(Color("#dfd1a8")), Vector3(0, 1.5, 0))
	_mesh(_cutter, _box(Vector3(1.65, 0.72, 0.10)), _material(Color("#8debd5"), true), Vector3(0.82, 2.5, 0))
	_sign(_cutter, "SURVEY CUTTER", Color("#9ff1db"), 3.8)


func _build_crew(label: String, fade_site: Survey.SignalSite = Survey.SignalSite.NONE) -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	for rank in range(3):
		_mesh(actor, _box(Vector3(0.63, 1.42, 0.57)), _material(Color("#ad5f4c")), Vector3((rank - 1) * 0.78, 0.77, rank % 2 * 0.85))
	var sign := _sign(actor, label, Color("#f6ba95"), 2.4)
	_register_relay_billboard(sign, fade_site)
	return actor


func _build_route_guides() -> void:
	var trails := [
		["Spawns/Ilyra", "Routes/StoneTrailTurn", "Objectives/AncestralStone", "Routes/StoneExit", "Routes/InletTrailTurn", "Objectives/FishingInlet"],
		["Objectives/FishingInlet", "Routes/InletBeachTurn", "Objectives/BeachSignal"],
		["Spawns/ShoreDetachment", "Routes/InlandJunction", "Routes/MidCoastLane", "Routes/InletFork", "Routes/InletBacktrack"],
		["Routes/InletBacktrack", "Routes/BeachGuard", "Objectives/BeachSignal"],
		["Objectives/FishingInlet", "Routes/InletBacktrack", "Routes/HeadlandInlandCut", "Routes/HeadlandLandwardTurn",
			"Routes/HeadlandRampFoot", "Routes/HeadlandRampTop", "Routes/HeadlandApron", "Routes/HighGuard", "Objectives/HeadlandSignal"],
		["Routes/MidCoastLane", "Routes/HeadlandRoadFork", "Routes/HeadlandLandwardTurn"],
	]
	for trail: Array in trails:
		_dotted(_route(trail), false)
	var loop := _cutter_route.duplicate()
	loop.append(loop[0])
	_dotted(loop, true)
	for index in range(2):
		_beacon(_cutter_route[HOLD_STOPS[index]], SITE_NAMES[index].to_upper() + " CUTTER STOP", Color("#8debd5"), _sea_guides)


func _dotted(path: PackedVector3Array, afloat: bool) -> void:
	var spacing := 10.0 if afloat else 5.0
	var tint := _material(Color("#84dfdb") if afloat else Color("#ecbf83"), true)
	var bead := _box(Vector3(0.62, 0.04, 0.62))
	for index in range(1, path.size()):
		var start := path[index - 1]
		var end := path[index]
		var count := maxi(1, ceili(start.distance_to(end) / spacing))
		for step in range(1, count):
			var position := to_local(start.lerp(end, float(step) / count))
			position.y = 0.09 if afloat else _ground(Vector2(position.x, position.z), 0.075).y
			_mesh(_sea_guides if afloat else self, bead, tint, position)


func _beacon(point: Vector3, label: String, tint: Color, parent: Node3D, fade_site: Survey.SignalSite = Survey.SignalSite.NONE) -> Node3D:
	var beacon := Node3D.new()
	parent.add_child(beacon)
	beacon.global_position = point
	var material := _material(tint, true)
	_mesh(beacon, _ring(1.48, 1.62), material, Vector3.UP * 0.11)
	_mesh(beacon, _box(Vector3(0.10, 1.76, 0.10)), material, Vector3.UP * 0.91)
	var sign := _sign(beacon, label, tint, 2.3)
	_register_relay_billboard(sign, fade_site)
	return beacon


func _sign(parent: Node3D, label: String, tint: Color, height: float) -> Label3D:
	var sign := Label3D.new()
	sign.text = label
	sign.modulate = tint
	sign.font_size = 42
	sign.outline_size = 10
	sign.pixel_size = 0.025
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = height
	parent.add_child(sign)
	return sign


func _point(path: String) -> Vector3:
	return battlefield_marker(NodePath("Markers/" + path)).global_position


func _route(paths: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for path: String in paths:
		points.append(_point(path))
	return points


func _face(actor: Node3D, point: Vector3) -> void:
	var offset := point - actor.global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.000001:
		actor.rotation.y = atan2(-offset.x, -offset.z)


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions(_crews)
