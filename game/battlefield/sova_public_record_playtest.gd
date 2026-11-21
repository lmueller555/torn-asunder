extends "res://game/battlefield/command_harness.gd"

const Hearing := preload("res://game/battlefield/sova_public_record.gd")
const LECTERN_RADIUS := 2.0
const EXIT_CLEARANCE := 4.3
const SECONDS_PER_PASSAGE := 2.8
const WALK_SPEED := 2.3
const VENUE_NAMES := ["", "Open dais", "Recessed dais"]
const VENUE_PREFIX := ["", "Open", "Recessed"]
const COLORS := [Color.WHITE, Color("#ffd08a"), Color("#9de6d9")]
const PASSAGE_NAMES := ["The command", "Who gave it", "Who bore the cost"]
const GUARD_NAMES := ["North Perimeter", "South Perimeter"]

signal mission_cleared
signal mission_finished(won: bool)

class VenueLayout:
	var lectern: Vector3
	var ring_center: Vector3
	var public_exit: Vector3
	var scribe_at: Vector3
	var footprint: AABB
	var visuals: Node3D
	var scribe: Node3D
	var record_prop: Node3D
	var exit_label: Label3D
	var departing: Array[Node3D] = []

var objective := Hearing.new()
var _layouts: Array[VenueLayout] = [null]
var _key_read := false
var _button_read := false
var _choose_requested := false
var _keepers_departing := false
var _scribes_alive := 1
var _confirmed_loss := false
var _sova_fell := false

@onready var _goal: Label = $HearingHUD/Panel/Margin/Readout/Goal
@onready var _detail: Label = $HearingHUD/Panel/Margin/Readout/Detail
@onready var _conditions: Label = $HearingHUD/Panel/Margin/Readout/Conditions
@onready var _progress: ProgressBar = $HearingHUD/Panel/Margin/Readout/Passage
@onready var _restart_button: Button = $HearingHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	for id in [Hearing.Venue.OPEN, Hearing.Venue.RECESSED]:
		_layouts.append(_make_venue(id))
	_restart_button.pressed.connect(restart_mission)
	_reset_hearing()
	_refresh_hearing()


func _physics_process(delta: float) -> void:
	if objective.phase not in [Hearing.Phase.SUCCEEDED, Hearing.Phase.FAILED]:
		super._physics_process(delta)
	elif objective.phase == Hearing.Phase.SUCCEEDED:
		# A clear does not stop civilians who are already walking out.
		_step_departures(delta)


func _after_battle_step(delta: float) -> void:
	var frame := Hearing.Observation.new()
	var hero := hero_world_position()
	if _choose_requested and not command_view:
		frame.requested_venue = _nearby_lectern(hero)
	_choose_requested = false
	_fill_report(frame.open, _layouts[Hearing.Venue.OPEN], hero, delta)
	_fill_report(frame.recessed, _layouts[Hearing.Venue.RECESSED], hero, delta)
	frame.surviving_scribes = _scribes_alive
	frame.record_seized = _confirmed_loss
	frame.sova_fell = _sova_fell
	objective.advance(frame)
	_keepers_departing = objective.passages_read >= 1
	_step_departures(delta)
	_refresh_hearing()
	if objective.phase == Hearing.Phase.SUCCEEDED:
		mission_cleared.emit()
		mission_finished.emit(true)
	elif objective.phase == Hearing.Phase.FAILED:
		mission_finished.emit(false)


func _fill_report(report: Hearing.VenueReport, layout: VenueLayout, hero: Vector3, delta: float) -> void:
	report.sova_at_lectern = hero.distance_to(layout.lectern) <= LECTERN_RADIUS
	report.record_at_lectern = not _confirmed_loss
	report.scribe_present = _scribes_alive > 0
	report.ring_contested = _armed_in_ring(layout)
	report.public_exit_blocked = _exit_blocked(layout)
	if not command_view and (_key_read or _button_read):
		report.reading_credit = maxf(delta, 0.0) / SECONDS_PER_PASSAGE


func _unhandled_input(event: InputEvent) -> void:
	event = GameplayBindings.translate(event)
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE and event.pressed:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_key_read = event.pressed and not command_view
			_choose_requested = _choose_requested or _key_read
			return
	elif event is InputEventJoypadButton and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START and event.pressed:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A:
			_button_read = event.pressed and not command_view
			_choose_requested = _choose_requested or _button_read
			if not command_view:
				return
	if objective.phase not in [Hearing.Phase.SUCCEEDED, Hearing.Phase.FAILED]:
		super._unhandled_input(event)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_key_read = false
		_button_read = false
		_choose_requested = false


## Hooks for later real encounters. This playtest does not invent casualties or a seizure deadline.
func report_sova_fell() -> void:
	_sova_fell = true


func report_record_seized() -> void:
	_confirmed_loss = true


func report_surviving_scribes(count: int) -> void:
	_scribes_alive = maxi(count, 0)


func _build_placeholders() -> void:
	_name_guards()
	super._build_placeholders()


func _name_guards() -> void:
	for index in range(GUARD_NAMES.size()):
		battle.formations[index].title = GUARD_NAMES[index]


func restart_mission() -> void:
	objective.restart()
	restart_battle()
	_name_guards()
	_sync_view()
	_reset_hearing()
	_refresh_hearing()


func _reset_hearing() -> void:
	_key_read = false
	_button_read = false
	_choose_requested = false
	_keepers_departing = false
	_scribes_alive = 1
	_confirmed_loss = false
	_sova_fell = false
	for id in [Hearing.Venue.OPEN, Hearing.Venue.RECESSED]:
		var layout := _layouts[id]
		for index in range(layout.departing.size()):
			var listener := layout.departing[index]
			listener.global_position = layout.ring_center + Vector3(-1.0, 0.0, (index - 1) * 1.5)
			listener.show()


func _make_venue(id: Hearing.Venue) -> VenueLayout:
	var name: String = VENUE_PREFIX[id]
	var layout := VenueLayout.new()
	layout.lectern = _hearing_marker(name + "Lectern")
	layout.ring_center = _hearing_marker(name + "RingCenter")
	layout.public_exit = _hearing_marker(name + "PublicExit")
	layout.scribe_at = _hearing_marker(name + "Scribe")
	var zone := battlefield_marker(NodePath("Markers/PhaseZones/" + name + "HearingRing"))
	var size: Vector3 = zone.get_meta(&"box_size")
	layout.footprint = AABB(zone.global_position - size * 0.5, size)
	layout.visuals = Node3D.new()
	add_child(layout.visuals)
	var color: Color = COLORS[id]
	var paint := _material(color, true)
	var mid := layout.footprint.get_center()
	mid.y = layout.lectern.y + 0.07
	for side in [-1.0, 1.0]:
		_fixed_mesh(layout.visuals, _box(Vector3(size.x, 0.04, 0.16)), paint, mid + Vector3(0.0, 0.0, size.z * 0.5 * side))
		_fixed_mesh(layout.visuals, _box(Vector3(0.16, 0.04, size.z)), paint, mid + Vector3(size.x * 0.5 * side, 0.0, 0.0))
	_fixed_mesh(layout.visuals, _ring(1.37, 1.48), paint, layout.public_exit + Vector3.UP * 0.06)
	_sign(layout.visuals, layout.lectern + Vector3.UP * 2.45, VENUE_NAMES[id] + " lectern", color)
	layout.exit_label = _sign(layout.visuals, layout.public_exit + Vector3.UP * 2.7, "Public exit", color)
	layout.scribe = _civilian(layout.visuals, Color("#eedc9c"))
	layout.scribe.global_position = layout.scribe_at
	_sign(layout.scribe, layout.scribe_at + Vector3.UP * 1.95, "Public scribe", Color("#eedc9c"))
	layout.record_prop = Node3D.new()
	layout.visuals.add_child(layout.record_prop)
	var lectern_stone := _field.get_node_or_null("Geometry/Hearing/" + name + "LecternStone") as Node3D
	var book_at := lectern_stone.global_position + Vector3.UP * 0.75 if lectern_stone else layout.lectern + Vector3.UP
	layout.record_prop.global_position = book_at
	_mesh(layout.record_prop, _box(Vector3(0.55, 0.14, 0.41)), _material(Color("#865935")))
	_mesh(layout.record_prop, _box(Vector3(0.49, 0.06, 0.35)), _material(Color("#f0e1af")), Vector3.UP * 0.085)
	for index in range(3):
		var keeper := _civilian(layout.visuals, Color("#aabaaf"))
		if index == 1:
			_sign(keeper, keeper.global_position + Vector3.UP * 1.88, "Keepers · Neutral", Color("#d5e1d4"))
		layout.departing.append(keeper)
	return layout


func _step_departures(delta: float) -> void:
	if not _keepers_departing or objective.venue == Hearing.Venue.NONE:
		return
	var layout := _layouts[objective.venue]
	if _exit_blocked(layout):
		return
	# A short fan-in to the same authored public exit. These aren't battle units,
	# so no targeting, order, or enemy pressure is produced by their movement.
	for listener in layout.departing:
		if not listener.visible:
			continue
		var from := listener.global_position
		var next := from.move_toward(layout.public_exit, WALK_SPEED * delta)
		if _terrain.can_move(_point_from_world(from), _point_from_world(next), false):
			var facing := next - from
			listener.rotation.y = atan2(-facing.x, -facing.z)
			listener.global_position = next
			if next == layout.public_exit:
				listener.hide()


func _armed_in_ring(layout: VenueLayout) -> bool:
	for formation in battle.formations:
		if formation.order == Battle.Order.DEFEATED:
			continue
		var feet := to_global(_ground(formation.position))
		if layout.footprint.has_point(feet + Vector3.UP * 0.8):
			return true
	return false


func _exit_blocked(layout: VenueLayout) -> bool:
	for formation in battle.formations:
		if formation.order != Battle.Order.DEFEATED and to_global(_ground(formation.position)).distance_to(layout.public_exit) <= EXIT_CLEARANCE:
			return true
	return false


func _nearby_lectern(hero: Vector3) -> Hearing.Venue:
	for id in [Hearing.Venue.OPEN, Hearing.Venue.RECESSED]:
		if hero.distance_to(_layouts[id].lectern) <= LECTERN_RADIUS:
			return id
	return Hearing.Venue.NONE


func _refresh_hearing() -> void:
	for id in [Hearing.Venue.OPEN, Hearing.Venue.RECESSED]:
		var layout := _layouts[id]
		layout.visuals.visible = objective.venue == Hearing.Venue.NONE or objective.venue == id
		layout.scribe.visible = _scribes_alive > 0
		layout.record_prop.visible = objective.venue == id and not _confirmed_loss
		if layout.visuals.visible:
			layout.exit_label.text = "Public exit · Blocked" if _exit_blocked(layout) else "Public exit · Open"
	var selected := objective.venue
	_progress.value = objective.passage_progress
	_progress.visible = selected != Hearing.Venue.NONE and objective.phase not in [Hearing.Phase.SUCCEEDED, Hearing.Phase.FAILED]
	_conditions.text = "Keepers are neutral. Armed formations must stay outside the ring and clear of the public exit."
	match objective.phase:
		Hearing.Phase.CHOOSING_VENUE:
			_goal.text = "Choose the open or recessed lectern"
			_detail.text = "Inspect the two marked rings and public exits. Press Cross / Space at a lectern to commit."
		Hearing.Phase.SUCCEEDED:
			_goal.text = "The record is public"
			_detail.text = "All three passages are read. The public scribe may copy the account."
		Hearing.Phase.FAILED:
			_goal.text = "The hearing did not finish"
			_detail.text = ["", "Sova fell.", "The record was seized.", "No public scribe remains."][objective.failure]
		_:
			var read := objective.passages_read
			_goal.text = "%s  ·  %d of 3 passages read" % [VENUE_NAMES[selected], read]
			if objective.phase == Hearing.Phase.INTERRUPTED:
				_detail.text = ["", "Return to the lectern to reread this passage.", "Clear armed formations from the ring to reread this passage.", "Clear the public exit to resume this passage.", "Return the record to the lectern.", "A public scribe must be present."][objective.interruption]
			elif command_view:
				_detail.text = "Release L2 / Shift to return to Sova. Formation orders keep running."
			else:
				_detail.text = "Hold Cross / Space to read: %s." % PASSAGE_NAMES[read]


func _hearing_marker(id: String) -> Vector3:
	return battlefield_marker(NodePath("Markers/Hearing/" + id)).global_position


func _point_from_world(world: Vector3) -> Vector2:
	var point := to_local(world)
	return Vector2(point.x, point.z)


func _fixed_mesh(parent: Node3D, mesh: Mesh, material: Material, world: Vector3) -> void:
	_mesh(parent, mesh, material).global_position = world


func _civilian(parent: Node3D, color: Color) -> Node3D:
	var figure := Node3D.new()
	parent.add_child(figure)
	var robe := _material(color)
	_mesh(figure, _box(Vector3(0.44, 1.18, 0.37)), robe, Vector3.UP * 0.63)
	_mesh(figure, _box(Vector3(0.29, 0.27, 0.28)), _material(Color("#dfa98a")), Vector3.UP * 1.37)
	return figure


func _sign(parent: Node3D, world: Vector3, title: String, color: Color) -> Label3D:
	var sign := Label3D.new()
	sign.text = title
	sign.modulate = color
	sign.pixel_size = 0.024
	sign.outline_size = 9
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(sign)
	sign.global_position = world
	return sign
