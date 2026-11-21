extends "res://game/battlefield/command_harness.gd"
## Manual drills around one real mounted pass. No campaign state or art dependencies
## beyond the existing Well Road terrain and debug reserves/infantry.

const Encounter := preload("res://game/combat/mounted_brace_encounter.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

enum Drill { EAST, WEST, WASH }

const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const DRILL_NAMES := ["East approach", "West approach", "Covered wash"]
const PHASE_NAMES := ["Staged", "Charging", "Running out", "Regrouping"]
const RESULT_NAMES := [
	"", "Charge hit · brace not facing the riders or not ready.",
	"Repelled · frontal brace stopped the riders.",
	"Miss · the infantry were clear of the lane.",
	"Blocked · terrain prevented contact.",
	"No impact · not enough run-up.", "No impact · not enough clear ground beyond the line.",
	"Pass cancelled.",
]

var encounter: Encounter
var drill := Drill.EAST
var _riders: Platoon
var _infantry: Platoon
var _lane_end: Vector2
var _explicit_hold := false
var _launched := false
var _banner: Label3D

@onready var _rider_models: Node3D = $Riders


func _ready() -> void:
	super._ready()
	# Reuse only the reserve's existing debug visuals, not its cart-screen rules.
	for child in _rider_models.get_children():
		if child is Label3D:
			_banner = child
			break
	_stage()


func _place_at_spawns() -> void:
	battle.formations.resize(1)
	battle.formations[0].title = "Brace Infantry"
	super._place_at_spawns()


func _stage() -> void:
	restart_battle()
	var start := _point("MountedChargeStart")
	var line := _point("SaltChargeGate")
	_lane_end = _point("MountedRunout")
	match drill:
		Drill.WEST:
			var east := start
			start = _lane_end
			_lane_end = east
		Drill.WASH:
			start = _point("SaltRoadWest")
			line = _point("WashReedBend")
			_lane_end = line + (line - start).normalized() * 12.0

	var formation := battle.formations[0]
	formation.position = line
	# Keep the initial facing east in each drill so West exposes the rear.
	formation.heading = Vector2.RIGHT
	formation.hold()
	battle.hero_position = line + Vector2(0, 4)
	battle.hero_heading = Vector2.UP
	_hero_yaw = 0.0
	_sector.center_on(line)
	cursor = line
	_explicit_hold = false
	_launched = false
	_riders = _platoon()
	_infantry = _platoon()
	var brace_family: StringName = Catalog.faction_roster().unit(Catalog.ORC_BRACE_INFANTRY).primary_family
	encounter = Encounter.new(_riders, _infantry, start, brace_family,
		_terrain.can_move.bind(true), _terrain.clear_melee_contact)
	encounter.observe_defender(line, formation.heading, false, 0.0)
	_sync_riders((_lane_end - start).normalized())
	_update_cameras()
	_sync_view()


func _point(route: String) -> Vector2:
	return _marker_position(battlefield_marker(NodePath("Markers/Routes/" + route)))


func _platoon() -> Platoon:
	var units: Array[Unit] = [Unit.new()]
	return Platoon.new(units, {})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _select_drill(Drill.EAST); return
			KEY_2: _select_drill(Drill.WEST); return
			KEY_3: _select_drill(Drill.WASH); return
			KEY_G: _launch(); return
			KEY_BACKSPACE: _stage(); return
	elif event is InputEventJoypadButton and event.pressed and _uses_joypad(event.device):
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: _select_drill(posmod(drill - 1, DRILL_NAMES.size())); return
			JOY_BUTTON_DPAD_RIGHT: _select_drill(posmod(drill + 1, DRILL_NAMES.size())); return
			JOY_BUTTON_RIGHT_SHOULDER: _launch(); return
			JOY_BUTTON_START: _stage(); return
	super._unhandled_input(event)


func _select_drill(next: Drill) -> void:
	drill = next
	_stage()


func _move_selected() -> void:
	if command_view:
		_explicit_hold = false
	super._move_selected()


func _hold_selected() -> void:
	if command_view:
		var formation := battle.formations[0]
		var facing := cursor - formation.position
		if facing.length_squared() > 0.25:
			formation.heading = facing.normalized()
		_explicit_hold = true
	super._hold_selected()


func _launch() -> void:
	if _launched:
		return
	_launched = encounter.order_pass(_lane_end)


func _after_battle_step(delta: float) -> void:
	var formation := battle.formations[0]
	encounter.observe_defender(formation.position, formation.heading,
		_explicit_hold and formation.order == Battle.Order.HOLD, delta)
	encounter.advance(delta)
	_sync_riders(encounter.travel_direction)


func _sync_riders(heading: Vector2) -> void:
	_rider_models.position = _ground(encounter.rider_position)
	if not heading.is_zero_approx():
		_rider_models.rotation.y = atan2(-heading.x, -heading.y)
	_banner.text = "Riders · " + PHASE_NAMES[encounter.phase]


func _sync_view() -> void:
	super._sync_view()
	if not encounter:
		return
	var facing := battle.formations[0].heading
	var bearing: String = COMPASS[posmod(roundi(atan2(facing.x, -facing.y) / (PI / 4.0)), 8)]
	var brace := "READY" if encounter.brace_ready else ("Setting" if _explicit_hold else "Not ordered")
	var status: String = PHASE_NAMES[encounter.phase]
	if _launched and encounter.phase == Encounter.Phase.READY:
		status = "Reset to stage again"
	_mode_label.text = "Mounted brace · Development playtest"
	_formation_label.text = "%s | %s | Infantry faces %s · Brace: %s" % [DRILL_NAMES[drill], status, bearing, brace]
	var cue: String = RESULT_NAMES[encounter.result]
	if cue.is_empty():
		cue = "Aim toward the riders, Hold to brace, then launch the pass."
	_controls_label.text = "%s\nCohesion: Riders %.0f · Infantry %.0f\n" % [cue, _riders.cohesion, _infantry.cohesion]
	_controls_label.text += "L2 / Shift: command · Square / right click: Move · Cross / H: Hold toward cursor\n"
	_controls_label.text += "R1 / G: launch pass · D-pad L/R / 1–3: drills · Options / Backspace: reset\n"
	_controls_label.text += "Left stick / WASD / mouse: aim or move · R3 / M: overview"
