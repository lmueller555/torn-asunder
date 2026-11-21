extends "res://game/battlefield/command_harness.gd"

const Return := preload("res://game/battlefield/sova_vault_return.gd")
const INTERACT_RADIUS := 1.95
const CLOSE_SECONDS := 3.2
const RIVAL_SPEED := 9.6
const SCREEN_RADIUS := 4.7
const MOBILIZE_RADIUS := 9.0
const GUARD_NAMES := ["Shelf Guard", "Side Guard"]
const GOLD := Color("#ffd38a")
const CLEAR := Color("#a6ebd7")
const PRESSURE := Color("#ff927f")

signal mission_finished(won: bool)

var objective := Return.new()
var _vault: Vector3
var _closure: AABB
var _branch_ends := PackedVector3Array()
var _rival_route := PackedVector3Array()
var _reserve_next_index := 0
var _reserve_active := false
var _reserve_screened := false
var _return_pressed := false
var _key_held := false
var _cross_held := false
var _sova_fell := false
var _blocked_material: StandardMaterial3D
var _reserve: Node3D
var _reserve_billboard: Label3D
var _vault_label: Label3D
var _bridle: Node3D

@onready var _goal: Label = $VaultHUD/Panel/Margin/Readout/Goal
@onready var _detail: Label = $VaultHUD/Panel/Margin/Readout/Detail
@onready var _reserve_status: Label = $VaultHUD/Panel/Margin/Readout/Reserve
@onready var _progress: ProgressBar = $VaultHUD/Panel/Margin/Readout/Progress
@onready var _restart_button: Button = $VaultHUD/Panel/Margin/Readout/Restart


func _ready() -> void:
	super._ready()
	_vault = _point(Return.RETURN_MARKER)
	var zone := battlefield_marker(Return.CLOSURE_ZONE)
	var size: Vector3 = zone.get_meta(&"box_size")
	_closure = AABB(zone.global_position - size * 0.5, size)
	_branch_ends = PackedVector3Array([_route("ShelfRejoin"), _route("SideRejoin"), _route("Forecourt")])
	_rival_route = PackedVector3Array([
		_point(^"Markers/Spawns/RivalReserve"), _route("RivalReserveCorner"),
		_route("RivalReserveReveal"), _route("Forecourt"),
		_point(^"Markers/Objectives/CustodyLine"), _point(^"Markers/Objectives/VaultEntrance"),
	])
	_breadcrumb(_route("ShelfDecision"), "NARROW SHELF", GOLD)
	_breadcrumb(_route("SideDecision"), "WIDER SIDE PATH", CLEAR)
	_breadcrumb(_rival_route[-2], "GUARD SCREEN", CLEAR)
	_breadcrumb(_point(^"Markers/Objectives/WitnessTerrace"), "WITNESS TERRACE · SEPARATE", Color("#cad5ed"))
	_vault_label = _sign(self, _vault + Vector3.UP * 2.35, "VAULT RETURN", GOLD)
	_build_closure_edge()
	_reserve = _make_reserve()
	_bridle = _make_bridle()
	_restart_button.pressed.connect(restart_mission)
	_reset_attempt()
	_refresh_objective()


func _physics_process(delta: float) -> void:
	if objective.phase not in [Return.Phase.SUCCEEDED, Return.Phase.FAILED]:
		super._physics_process(delta)


func _after_battle_step(delta: float) -> void:
	var hero := hero_world_position()
	if not _reserve_active:
		for branch_end in _branch_ends:
			if branch_end.distance_to(hero) <= MOBILIZE_RADIUS:
				_reserve_active = true
				break
	_step_reserve(delta)
	var frame := Return.Observation.new()
	frame.sova_in_closure_zone = _closure.has_point(hero + Vector3.UP * 0.8)
	frame.sova_at_return_marker = hero.distance_to(_vault) <= INTERACT_RADIUS
	frame.return_pressed = _return_pressed and not command_view
	frame.hostile_in_closure_zone = _reserve_contests()
	frame.sova_fell = _sova_fell
	if not command_view and (_key_held or _cross_held):
		frame.closure_credit = maxf(delta, 0.0) / CLOSE_SECONDS
	_return_pressed = false
	objective.advance(frame)
	_refresh_objective()
	if objective.phase == Return.Phase.SUCCEEDED:
		mission_finished.emit(true)
	elif objective.phase == Return.Phase.FAILED:
		mission_finished.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_BACKSPACE and event.pressed:
			restart_mission()
			return
		if event.physical_keycode == KEY_SPACE:
			_key_held = event.pressed and not command_view
			_return_pressed = _return_pressed or _key_held
			return
	elif event is InputEventJoypadButton and _uses_joypad(event.device):
		if event.button_index == JOY_BUTTON_START and event.pressed:
			restart_mission()
			return
		if event.button_index == JOY_BUTTON_A:
			_cross_held = event.pressed and not command_view
			_return_pressed = _return_pressed or _cross_held
			if not command_view:
				return
	if objective.phase not in [Return.Phase.SUCCEEDED, Return.Phase.FAILED]:
		super._unhandled_input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_return_pressed = false
		_key_held = false
		_cross_held = false


## Hook for a real battle encounter. This prototype never fabricates a casualty.
func report_sova_fell() -> void:
	_sova_fell = true


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
	_reset_attempt()
	_refresh_objective()


func _reset_attempt() -> void:
	_reserve.global_position = _rival_route[0]
	_reserve.rotation = Vector3.ZERO
	_reserve_active = false
	_reserve_screened = false
	_reserve_next_index = 1
	_return_pressed = false
	_key_held = false
	_cross_held = false
	_sova_fell = false


func _step_reserve(delta: float) -> void:
	if not _reserve_active:
		return
	_reserve_screened = _has_guard_screen()
	var last := _rival_route.size() - 1
	if _reserve_screened and _reserve_next_index >= last:
		# Hold controls the marked approach, not a global timer. An enemy already
		# in the zone must physically back out before it stops contesting closure.
		_move_reserve(_rival_route[last - 1], RIVAL_SPEED * delta)
		_reserve_next_index = last
		return
	if _reserve_next_index < _rival_route.size() and _move_reserve(_rival_route[_reserve_next_index], RIVAL_SPEED * delta):
		_reserve_next_index += 1


func _move_reserve(target: Vector3, distance: float) -> bool:
	var location := _reserve.global_position
	var next := location.move_toward(target, distance)
	if not _terrain.can_move(_flat(location), _flat(next), true):
		return false
	var facing := next - location
	if facing.length_squared() > 0.00001:
		_reserve.rotation.y = atan2(-facing.x, -facing.z)
	_reserve.global_position = next
	return next == target


func _has_guard_screen() -> bool:
	var approach := _rival_route[-2]
	var start := _flat(approach)
	var finish := _flat(_rival_route[-1])
	for formation in battle.formations:
		if formation.order != Battle.Order.HOLD:
			continue
		var feet := to_global(_ground(formation.position))
		if absf(feet.y - approach.y) > 2.0:
			continue
		var horizontal := _flat(feet)
		if horizontal.distance_to(Geometry2D.get_closest_point_to_segment(horizontal, start, finish)) <= SCREEN_RADIUS:
			return true
	return false


func _reserve_contests() -> bool:
	return _reserve_active and _closure.has_point(_reserve.global_position + Vector3.UP * 0.8)


func _refresh_objective() -> void:
	var contested := _reserve_contests()
	_blocked_material.albedo_color = PRESSURE if contested else CLEAR
	_vault_label.text = "VAULT CONTESTED" if contested else "VAULT RETURN"
	_vault_label.modulate = PRESSURE if contested else GOLD
	_reserve.visible = _reserve_active
	_reserve_billboard.text = "Rival reserve · Falling back" if _reserve_screened else "Rival reserve"
	_progress.value = objective.closure_progress
	_progress.visible = objective.phase not in [Return.Phase.SUCCEEDED, Return.Phase.FAILED]
	_bridle.visible = objective.phase != Return.Phase.FAILED
	_bridle.global_position = _vault + Vector3.UP * 1.12 if objective.phase == Return.Phase.SUCCEEDED else _hero.to_global(Vector3(0.52, 0.99, 0.12))
	var reserve_hint := ""
	if _reserve_active:
		if contested:
			reserve_hint = "The rival reserve occupies the closure zone. Hold a guard at the marked approach."
		elif _reserve_screened:
			reserve_hint = "An allied guard screens the approach. The rival reserve cannot enter."
		else:
			reserve_hint = "A rival reserve is moving to the vault from the north."
	_reserve_status.text = reserve_hint
	match objective.phase:
		Return.Phase.SUCCEEDED:
			_goal.text = "The Godbridle is back in the vault"
			_detail.text = "Sova returns it without speaking a command."
			_reserve_status.text = ""
		Return.Phase.FAILED:
			_goal.text = "The carrier fell"
			_detail.text = "Restart to attempt the return again."
		_:
			_goal.text = "Return the Godbridle to the vault"
			if contested:
				_detail.text = "Closure cannot advance until the rival physically leaves the zone."
			elif hero_world_position().distance_to(_vault) > INTERACT_RADIUS:
				_detail.text = "Take either the shelf or side path. Only the marked vault can accept the bridle."
			elif command_view:
				_detail.text = "Release L2 / Shift to return to Sova. Guard orders keep running."
			elif objective.pause_reason == Return.PauseReason.RETURN_INTERACTION_REQUIRED:
				_detail.text = "Press Cross / Space again at the vault, then hold to resume."
			elif objective.phase == Return.Phase.CARRYING:
				_detail.text = "Press Cross / Space at the marked vault, then hold to return the bridle."
			else:
				_detail.text = "Hold Cross / Space to close the vault."


func _make_reserve() -> Node3D:
	var formation := Node3D.new()
	add_child(formation)
	var uniform := _material(Color("#af5e57"))
	var shield := _material(Color("#db8770"))
	for x in [-0.77, 0.0, 0.77]:
		for z in [-0.55, 0.55]:
			_mesh(formation, _box(Vector3(0.45, 1.12, 0.40)), uniform, Vector3(x, 0.63, z))
			_mesh(formation, _box(Vector3(0.28, 0.26, 0.28)), shield, Vector3(x, 1.30, z))
			_mesh(formation, _box(Vector3(0.38, 0.55, 0.10)), shield, Vector3(x, 0.72, z - 0.24))
	_reserve_billboard = _sign(formation, formation.global_position + Vector3.UP * 2.12, "Rival reserve", PRESSURE)
	return formation


func _make_bridle() -> Node3D:
	var bridle := Node3D.new()
	add_child(bridle)
	var gold := _material(GOLD, true)
	var leather := _material(Color("#9a5136"))
	_mesh(bridle, _ring(0.23, 0.28), leather).rotation.x = PI / 2.0
	_mesh(bridle, _box(Vector3(0.54, 0.07, 0.08)), gold)
	for x in [-0.27, 0.27]:
		_mesh(bridle, _ring(0.05, 0.08), gold, Vector3(x, 0.0, 0.0)).rotation.x = PI / 2.0
	return bridle


func _build_closure_edge() -> void:
	var size := _closure.size
	var center := _closure.get_center()
	center.y = _vault.y + 0.06
	_blocked_material = _material(CLEAR, true)
	for direction in [-1.0, 1.0]:
		_mark(_box(Vector3(size.x, 0.04, 0.13)), _blocked_material, center + Vector3(0.0, 0.0, direction * size.z * 0.5))
		_mark(_box(Vector3(0.13, 0.04, size.z)), _blocked_material, center + Vector3(direction * size.x * 0.5, 0.0, 0.0))


func _breadcrumb(world: Vector3, caption: String, tone: Color) -> void:
	_mark(_ring(1.21, 1.32), _material(tone, true), world + Vector3.UP * 0.06)
	_sign(self, world + Vector3.UP * 2.3, caption, tone)


func _mark(mesh: Mesh, material: Material, world: Vector3) -> void:
	_mesh(self, mesh, material).global_position = world


func _sign(parent: Node3D, world: Vector3, caption: String, tone: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.modulate = tone
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.027
	label.outline_size = 10
	parent.add_child(label)
	label.global_position = world
	return label


func _route(name: String) -> Vector3:
	return _point(NodePath("Markers/Routes/" + name))


func _point(path: NodePath) -> Vector3:
	return battlefield_marker(path).global_position


func _flat(world: Vector3) -> Vector2:
	var local_point := to_local(world)
	return Vector2(local_point.x, local_point.z)


## Enemies that can engage the leader's platoon and switch to direct control.
func _hostile_positions() -> PackedVector2Array:
	return _visible_node_positions([_reserve]) if _reserve_active else PackedVector2Array()
