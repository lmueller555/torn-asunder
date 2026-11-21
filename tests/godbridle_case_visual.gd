extends SceneTree

const Campaign := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Pocket := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const DT := 1.0 / 60.0

var _mission: Mission
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Campaign.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame

	var visual := _mission._custody_case
	_expect(visual != null, "The launched campaign scene uses the editor-imported case.")
	if not visual:
		quit(1)
		return
	var near := visual._case
	var far := visual._tactical_case
	var keeper := visual._keeper
	var marker_frame := _mission._pickup.global_transform
	var exit_frame := _mission._exit.global_transform
	var tri_counts := [5681, 404, 574]
	var meshes := [near, far, keeper]
	for i in range(meshes.size()):
		var mesh: ArrayMesh = meshes[i].mesh
		_expect(mesh.get_surface_count() == 1 and mesh.surface_get_array_index_len(0) == tri_counts[i] * 3,
			"Each imported mesh preserves its reviewed triangle count and single surface.")
	var mat := near.mesh.surface_get_material(0) as StandardMaterial3D
	_expect(mat != null and mat == far.mesh.surface_get_material(0) and mat == keeper.mesh.surface_get_material(0)
		and mat.normal_enabled and mat.albedo_texture != null and mat.metallic_texture != null
		and mat.roughness_texture != null and mat.normal_texture != null,
		"One imported material shares the packed color, normal and roughness/metallic maps.")
	_expect(near.is_visible_in_tree() and not far.is_visible_in_tree() and not keeper.is_visible_in_tree(),
		"Pickup starts with the case only, not the tactical or carried-only geometry.")
	var ground_frame := visual.global_transform
	_expect(absf(_minimum(near, _mission._pickup, 1)) < 0.005 and absf(_minimum(far, _mission._pickup, 1)) < 0.005,
		"Both alternate meshes stand on the existing marker surface.")
	_expect(_mission._pickup_beacon.visible and not _mission._exit_beacon.visible
		and _mission._bridle.global_position.is_equal_approx(_mission._pickup.global_position + Vector3.UP * 0.75),
		"The old objective anchor and marker effects are preserved.")
	for i in range(6):
		_command(true)
		_expect(_mission.command_view and far.is_visible_in_tree() and not near.is_visible_in_tree()
			and not keeper.is_visible_in_tree() and visual.global_transform.is_equal_approx(ground_frame),
			"Repeated command entry shows only the compact mesh with no transform oscillation.")
		_command(false)
		_expect(not _mission.command_view and near.is_visible_in_tree() and not far.is_visible_in_tree()
			and visual.global_transform.is_equal_approx(ground_frame),
			"Repeated hero return restores the full same-frame pickup with no position drift.")

	_key(KEY_SPACE, true)
	_tick()
	_expect(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP,
		"Space out of range remains rejected.")
	_mission.battle.hero_position = _mission._marker_position(_mission._pickup)
	_tick()
	_command(true)
	_key(KEY_SPACE, true)
	_tick()
	_expect(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP,
		"Space within reach remains rejected in tactical command mode.")
	_command(false)
	_key(KEY_SPACE, true)
	_tick()
	_expect(_mission.objective.phase == Escort.Phase.ESCORTING and near.is_visible_in_tree()
		and keeper.is_visible_in_tree() and not far.is_visible_in_tree(),
		"Actual hero pickup mounts the case and its keeper.")
	_expect(not _mission._pickup_beacon.visible and _mission._exit_beacon.visible
		and _mission._bridle.global_position.is_equal_approx(_mission._hero.to_global(Vector3(0.46, 0.89, 0.06))),
		"Pickup preserves the original gameplay mount and beacon swap.")
	_expect(_minimum(near, _mission._hero, 0) >= 0.36 and absf(_minimum(keeper, _mission._hero, 0) - 0.36) < 0.008,
		"The case clears the proxy carrier; only the keeper meets its edge.")
	var carry_frame := _mission._hero.global_transform.inverse() * visual.global_transform
	for i in range(6):
		_command(true)
		_expect(far.is_visible_in_tree() and not near.is_visible_in_tree() and not keeper.is_visible_in_tree(),
			"Carried tactical mode displays only the compact mesh.")
		_command(false)
		_expect(near.is_visible_in_tree() and keeper.is_visible_in_tree() and not far.is_visible_in_tree()
			and (_mission._hero.global_transform.inverse() * visual.global_transform).is_equal_approx(carry_frame),
			"The hero remount view is stable and never reruns pickup.")
	_mission.report_bridle_lost()
	_tick()
	_expect(_mission.objective.phase == Escort.Phase.FAILED and not _mission._bridle.visible
		and not near.is_visible_in_tree() and not far.is_visible_in_tree(),
		"The terminal loss path hides the entire prop.")
	_key(KEY_BACKSPACE, true)
	_expect(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP and near.is_visible_in_tree()
		and not keeper.is_visible_in_tree() and visual.global_transform.is_equal_approx(ground_frame)
		and _mission._pickup.global_transform == marker_frame and _mission._exit.global_transform == exit_frame,
		"Real restart restores the original pickup transform and both authored markers.")
	_mission.queue_free()
	await process_frame

	var pocket: Mission = Pocket.instantiate()
	root.add_child(pocket)
	_expect(pocket._custody_case == null and pocket._bridle.get_child_count() == 4,
		"The separate pocket retains its old proxy and does not opt into campaign art.")
	pocket.queue_free()
	await process_frame
	if _failures == 0:
		print("Mara custody case: real imported scene, measured contact, repeated camera switches, pickup/loss/retry and pocket isolation passed.")
	quit(_failures)


func _minimum(part: MeshInstance3D, space: Node3D, axis: int) -> float:
	var result := INF
	for point: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		result = minf(result, space.to_local(part.to_global(point))[axis])
	return result


func _command(on: bool) -> void:
	_key(KEY_SHIFT, on)
	_tick()


func _tick() -> void:
	_mission._physics_process(DT)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _expect(ok: bool, note: String) -> void:
	if not ok:
		_failures += 1
		printerr(note)
