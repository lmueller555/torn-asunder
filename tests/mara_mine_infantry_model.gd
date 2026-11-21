extends SceneTree

const Deployment := preload("res://game/campaign_deployments.gd")
const Standalone := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const ASSET := "res://assets/models/human_infantry.glb"
const DT := 1.0 / 60.0


class MissingArt extends Mission:
	func _infantry_model_scene() -> PackedScene:
		return null


var _mission: Mission
var _capture_dir := ""


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture-dir":
		_capture_dir = arguments[1]
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = Deployment.for_mission("mara_mine_escort").scene
	_mission = scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _check_model_instances() and _approach_and_frame_hero()
	if passed:
		passed = await _capture("mara-mine-infantry-hero")
	if passed:
		passed = _check_march_and_command_view()
	if passed:
		passed = await _capture("mara-mine-infantry-command")
	if passed:
		passed = _check_defeat_and_retry()
	_mission.queue_free()
	await process_frame
	if passed:
		passed = await _check_original_and_fallback()
	if passed:
		print("Mara Mine infantry: catalog GLB, authored scale/facing, terrain-following movement, two camera views, real retaliation loss, retry and visual fallback passed.")
	quit(0 if passed else 1)


func _check_model_instances() -> bool:
	if not _mission.render_shield_infantry or Catalog.TYPES[Catalog.HUMAN_INFANTRY].model.resource_path != ASSET \
			or _mission._formation_members[0].size() != 12 or _mission._infantry_animators.size() != 12:
		return _fail("The deployed campaign did not load the twelve catalog infantry models into the existing formation.")
	for member: Node3D in _mission._formation_members[0]:
		var model := member.get_node_or_null("HumanInfantryModel") as Node3D
		if not model or member.get_child_count() != 1 or model.scene_file_path != ASSET \
				or not model.scale.is_equal_approx(Vector3.ONE) or not model.position.is_zero_approx() \
				or model.find_children("*", "Skeleton3D", true, false).is_empty():
			return _fail("A member was still a box or lost the catalog rig, authored scale or ground anchor.")
		var player := model.get_node("AnimationPlayer") as AnimationPlayer
		if player.current_animation != &"Idle" or not player.has_animation(&"Run"):
			return _fail("The actual rig did not provide its existing Idle and Run clips.")
	if not _anchors_match_motion() or not _uses_boxes(_mission._formation_members[1]) \
			or _mission._hero.find_child("HumanInfantryModel", true, false) \
			or _mission._enemy_visual.find_child("HumanInfantryModel", true, false):
		return _fail("Another formation, Mara or the road guard was changed, or initial infantry facing was wrong.")
	var model: Node3D = _mission._formation_members[0][0].get_node("HumanInfantryModel")
	var model_bounds := _mesh_bounds(model)
	return (model_bounds.size.y >= 1.6 and model_bounds.size.y <= 2.3 and absf(model_bounds.position.y) < 0.15) \
		or _fail("The imported mesh no longer reads as a grounded, human-scale figure: %s." % model_bounds)


func _approach_and_frame_hero() -> bool:
	var infantry := _mission.battle.formations[0]
	var target := infantry.position + Vector2(-8.0, -4.0)
	for _step in range(600):
		var toward := target - _mission.battle.hero_position
		if toward.length() < 0.13:
			break
		var stick := toward.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, stick.x)
		_axis(JOY_AXIS_LEFT_Y, stick.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	return (_mission.battle.hero_position.distance_to(target) < 0.14 and root.get_camera_3d() == _mission._hero_camera \
		and _framed_members(30.0) >= 8) or _fail("Hero view could not physically reach and frame the infantry figures.")


func _check_march_and_command_view() -> bool:
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	if root.get_camera_3d() != _mission._command_camera or _mission._sector.overview or _framed_members(5.0) != 12:
		return _fail("The unchanged local command-sector camera did not frame all infantry models.")
	var infantry := _mission.battle.formations[0]
	var first := infantry.position
	var target := _mission.battlefield_marker(^"Markers/Routes/WestAssembly").global_position
	var plane := Vector2(target.x, target.z)
	var event := InputEventMouseMotion.new()
	event.position = root.get_camera_3d().unproject_position(target)
	root.push_input(event, true)
	_joy(JOY_BUTTON_X)
	_tick(6)
	if infantry.order != Battle.Order.MOVE or infantry.position.distance_to(first) < 0.1 \
			or infantry.destination.distance_to(plane) > 0.045 or not _anchors_match_motion():
		return _fail("A real projected move did not physically carry and face the existing rigged feet anchors.")
	for player in _mission._infantry_animators:
		if player.current_animation != &"Run" or player.get_playing_speed() <= 1.0:
			return _fail("Movement did not use the authored in-place Run rate synced to battlefield speed.")
	_tick(160)
	if infantry.order != Battle.Order.HOLD or infantry.position.distance_to(plane) > 0.045 \
			or not _anchors_match_motion() or _framed_members(5.0) != 12:
		return _fail("The same rendered soldiers failed to arrive on the terrain in command view.")
	for player in _mission._infantry_animators:
		if player.current_animation != &"Idle":
			return _fail("A stopped formation did not return to its original Idle.")
	return true


func _check_defeat_and_retry() -> bool:
	var infantry := _mission.battle.formations[0]
	var rig: Node3D = _mission._formation_members[0][0].get_node("HumanInfantryModel")
	var fight := _mission.encounter
	# Arrange the existing guard in reach for a short presentation test. The
	# unchanged enemy AI, attack orders and combat damage decide formation loss.
	fight.enemy_position = infantry.position + Vector2(1.3, 0.0)
	fight.enemy_phase = Encounter.EnemyPhase.WATCHING
	_mission.cursor = fight.enemy_position
	_joy(JOY_BUTTON_Y)
	for _step in range(500):
		if infantry.order == Battle.Order.DEFEATED:
			break
		_tick()
	if infantry.order != Battle.Order.DEFEATED or fight.infantry_attack.attacker.is_alive() \
			or rig.is_visible_in_tree() or _mission._formation_models[0].visible \
			or not _mission._formation_models[1].visible:
		return _fail("Actual battle defeat did not hide just the correct infantry formation models.")
	_joy(JOY_BUTTON_START)
	return (_mission.battle.formations[0].order == Battle.Order.HOLD and rig.is_visible_in_tree() \
		and _mission._infantry_animators[0].current_animation == &"Idle" and _anchors_match_motion()) \
		or _fail("Retry did not restore the same anchored models and their ready animation.")


func _check_original_and_fallback() -> bool:
	var prototype := Standalone.instantiate() as Mission
	root.add_child(prototype)
	prototype.set_physics_process(false)
	await physics_frame
	var original := _uses_boxes(prototype._formation_members[0]) and _uses_boxes(prototype._formation_members[1])
	prototype.queue_free()
	await process_frame
	var no_art := Standalone.instantiate() as Mission
	var field := no_art.battlefield_scene
	var hero := no_art.hero_spawn
	var formations := no_art.formation_spawns
	no_art.set_script(MissingArt)
	no_art.battlefield_scene = field
	no_art.hero_spawn = hero
	no_art.formation_spawns = formations
	no_art.render_shield_infantry = true
	root.add_child(no_art)
	no_art.set_physics_process(false)
	await physics_frame
	var fallback := _uses_boxes(no_art._formation_members[0]) and _uses_boxes(no_art._formation_members[1]) \
		and no_art._infantry_animators.is_empty()
	no_art.queue_free()
	await process_frame
	return (original and fallback) or _fail("The standalone or missing-catalog-art path lost its original block presentation.")


func _anchors_match_motion() -> bool:
	var infantry := _mission.battle.formations[0]
	var group := _mission._formation_models[0]
	if not group.position.is_equal_approx(_mission._ground(infantry.position)):
		return false
	for member: Node3D in _mission._formation_members[0]:
		var model: Node3D = member.get_node("HumanInfantryModel")
		var ground: Vector3 = _mission.to_local(member.global_position)
		var forward := model.global_basis.z
		if Vector2(forward.x, forward.z).normalized().dot(infantry.heading) < 0.999 \
				or not is_equal_approx(ground.y, _mission._terrain.ground_height(Vector2(ground.x, ground.z))):
			return false
	return true


func _mesh_bounds(model: Node3D) -> AABB:
	var combined := AABB()
	var inverse := model.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		combined = bounds if combined == AABB() else combined.merge(bounds)
	return combined


func _framed_members(minimum_pixels: float) -> int:
	var camera := root.get_camera_3d()
	var visible_rect := root.get_visible_rect()
	var count := 0
	for member: Node3D in _mission._formation_members[0]:
		var feet := member.global_position + Vector3.UP * 0.05
		var crown := member.global_position + Vector3.UP * 1.8
		if not camera.is_position_in_frustum(feet) or not camera.is_position_in_frustum(crown):
			continue
		var projected_crown := camera.unproject_position(crown)
		var projected_feet := camera.unproject_position(feet)
		# Compare at the project's nominal 720p play window even in headless mode.
		var height := absf(projected_crown.y - projected_feet.y) / visible_rect.size.y * 720.0
		if height >= minimum_pixels and _mission._terrain.clear_ranged_lane(camera.position, crown):
			count += 1
	return count


func _uses_boxes(anchors: Array) -> bool:
	if anchors.size() != 12:
		return false
	for member: Node3D in anchors:
		if member.get_child_count() != 2:
			return false
		for child in member.get_children():
			if not child is MeshInstance3D or not child.mesh is BoxMesh:
				return false
	return true


func _capture(name: String) -> bool:
	if _capture_dir.is_empty():
		return true
	if DisplayServer.get_name() == "headless":
		return _fail("Capture needs a running Godot renderer.")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return (image and image.save_png(_capture_dir.path_join(name + ".png")) == OK) \
		or _fail("Could not save %s camera capture." % name)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _tick(count := 1) -> void:
	for _step in range(count):
		_mission._physics_process(DT)


func _fail(message: String) -> bool:
	push_error(message)
	return false
