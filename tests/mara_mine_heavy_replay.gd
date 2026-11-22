extends SceneTree
## Opt-in replay proof. No title, profile, or campaign save is exercised or written.

const PlatoonSize := preload("res://game/combat/platoon_size.gd")

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Pocket := preload("res://game/battlefield/mara_mine_escort.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Adapter := preload("res://game/battlefield/mara_campaign_minimap.gd")
const Fight := preload("res://game/battlefield/mara_mine_encounter.gd")
const Inf := preload("res://game/battlefield/mara_infantry_attack.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const STEP := 1.0 / 60.0
const HEAVY_ASSET := "res://assets/models/human_heavy_infantry.glb"

var _mission: Mission
var _hud: Adapter


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pocket := Pocket.instantiate() as Mission
	var refused_pocket := not pocket.configure_replay_heavy_infantry(true, true)
	pocket.free()
	if not refused_pocket:
		_fail("The pocket accepts the Mine campaign-only proof.")
		quit(1)
		return
	var passed := await _exercise(false)
	if passed:
		passed = await _exercise(true)
	if passed:
		print("Mine Heavy replay: isolated authorization, approved active rig, equal-lane movement and combat, retry, cameras and unchanged custody passed.")
	quit(0 if passed else 1)


func _exercise(heavy: bool) -> bool:
	_mission = Scene.instantiate()
	_mission.configure_campaign_lead_level(2 if heavy else 1)
	if heavy:
		if _mission.configure_replay_heavy_infantry(true, false) or not _mission.configure_replay_heavy_infantry(true, true):
			return _fail("Heavy selection did not require separate replay and earned loadout authorization.")
	elif _mission.configure_replay_heavy_infantry(false, true):
		return _fail("Fresh launch accepted the trained flag despite no replay.")
	root.add_child(_mission)
	_mission.set_physics_process(false)
	_hud = _mission.get_node("MinimapHUD/Panel") as Adapter
	_hud.set_physics_process(false)
	await physics_frame
	await physics_frame
	var passed := _check_loadout(heavy) and not _mission.configure_replay_heavy_infantry(true, true)
	if passed and heavy:
		passed = await _capture_carry_and_rig()
	if passed:
		var ticks := _march_equal_lane(heavy)
		passed = ticks > 0 and await _equal_contact(heavy)
		if passed:
			print("%s: 54.571 m queued march in %.2f s (%d frames)." % [
				_mission.battle.formations[0].title, ticks * STEP, ticks,
			])
	if passed:
		_button(JOY_BUTTON_START)
		_tick()
		passed = _check_loadout(heavy) and _hud.pending_waypoints(0).is_empty() \
			and _mission.battle.formations[0].order == Battle.Order.HOLD \
			and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP \
			and _mission._formation_models[0].visible
	_mission.queue_free()
	await process_frame
	return passed or _fail("The isolated replay, fresh run or retry failed to keep its own loadout.")


func _check_loadout(heavy: bool) -> bool:
	var expected_hp := 380.0 if heavy else 310.0
	var expected_speed := 2.55 if heavy else 3.0
	var expected_title := "Heavy Infantry" if heavy else "Shield Infantry"
	var battle := _mission.battle
	if battle.formations[0].move_speed != expected_speed or battle.formations[1].move_speed != 3.0 \
			or battle.formations[0].title != expected_title or battle.formations.size() != 2 \
			or _mission.encounter.infantry_attack.attacker.hp != expected_hp \
			or not _mission._infantry_hp.text.contains(expected_title) \
			or _mission.encounter.hero.hp != Fight.HERO_HP or _mission.encounter.points.balance != 400 \
			or _mission.team_battle_points_frame().capacity != (720 if heavy else 700):
		return _fail("Loadout did not keep the real two formations, correct HP/speed, default Archer, Hero or BP.")
	var name := "HeavyInfantryModel" if heavy else "HumanInfantryModel"
	if _mission._formation_members[0].size() != PlatoonSize.PLATOON_WITH_LEADER \
			or _mission._infantry_animators.size() != PlatoonSize.PLATOON_WITH_LEADER:
		return _fail("Expected one checked native rig and animator for every regular melee member.")
	for member: Node3D in _mission._formation_members[0]:
		var model := member.get_node_or_null(name) as Node3D
		if not model or member.get_child_count() != 1 or not model.position.is_zero_approx() \
				or not model.scale.is_equal_approx(Vector3.ONE) or not is_equal_approx(absf(model.rotation.y), PI):
			return _fail("Wrong rig, facing, offset or duplicate fallback.")
		if heavy and model.scene_file_path != HEAVY_ASSET:
			return _fail("The Heavy formation did not use the approved catalog GLB.")
	if heavy and not _heavy_rig_stays_on_its_anchor(_mission._formation_members[0][0].get_node(name)):
		return _fail("The approved Heavy rig introduced a physical body, root translation, or unsafe scale.")
	return true


func _heavy_rig_stays_on_its_anchor(model: Node3D) -> bool:
	if not model.find_children("*", "CollisionObject3D", true, false).is_empty():
		return false
	var envelope := AABB()
	var inverse := model.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		envelope = bounds if envelope == AABB() else envelope.merge(bounds)
	if envelope.size.y < 1.6 or envelope.size.y > 2.3 or absf(envelope.position.y) > 0.05:
		return false
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	for clip in [&"Shield-Ready Idle", &"Combat Run"]:
		var anim := player.get_animation(clip)
		var root_checked := false
		for track in anim.get_track_count():
			if anim.track_get_type(track) != Animation.TYPE_POSITION_3D \
					or anim.track_get_path(track).get_concatenated_subnames() != "Root":
				continue
			root_checked = true
			for key in anim.track_get_key_count(track):
				var offset: Vector3 = anim.track_get_key_value(track, key)
				if not offset.is_zero_approx():
					return false
		if not root_checked:
			return false
	return true


func _capture_carry_and_rig() -> bool:
	# Staging is test-only. Cross still takes actual custody from its marker.
	_mission.battle.hero_position = _position("Objectives/GodbridlePickup")
	_button(JOY_BUTTON_A)
	_tick()
	if _mission.objective.phase != Escort.Phase.ESCORTING or not _mission._custody_case._case.is_visible_in_tree():
		return _fail("The approved case could not be actually picked up on the Heavy run.")
	_mission.battle.hero_position = _mission.battle.formations[0].position + Vector2(-7, -4)
	_tick()
	if root.get_camera_3d() != _mission._hero_camera or _framed_members(25.0) < 8 \
			or not _case_projects(false):
		return _fail("The real hero camera does not frame the approved Heavy rig.")
	await _checkpoint("01-heavy-hero-carry")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	if root.get_camera_3d() != _mission._command_camera or _framed_members(5.0) != PlatoonSize.PLATOON_WITH_LEADER \
			or not _case_projects(true):
		return _fail("The unchanged tactical view lost the Heavy rig or the approved carry LOD.")
	await _checkpoint("02-heavy-tactical-carry")
	_aim(_position("Routes/WestAssembly"))
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	# Back in hero view the camera follows the selected platoon's waypoint marker;
	# select Mara's own platoon so the marker, and the camera, start at her.
	_button(JOY_BUTTON_DPAD_LEFT)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_tick(12)
	if _mission._infantry_animators[0].current_animation != &"Combat Run" or not _case_projects(false):
		return _fail("The actual approved Heavy moving pose or carry disappeared on hero return.")
	await _checkpoint("04-heavy-running-carry")
	_button(JOY_BUTTON_START)
	_tick()
	return true


func _case_projects(tactical: bool) -> bool:
	var case_visual := _mission._custody_case
	var mesh: MeshInstance3D = case_visual._tactical_case if tactical else case_visual._case
	var alternate: MeshInstance3D = case_visual._case if tactical else case_visual._tactical_case
	var camera := root.get_camera_3d()
	return mesh.is_visible_in_tree() and not alternate.is_visible_in_tree() \
		and case_visual._keeper.is_visible_in_tree() != tactical \
		and not camera.is_position_behind(mesh.global_position) \
		and root.get_visible_rect().has_point(camera.unproject_position(mesh.global_position))


func _framed_members(min_pixels: float) -> int:
	var camera := root.get_camera_3d()
	var count := 0
	for member: Node3D in _mission._formation_members[0]:
		var foot := member.global_position
		var head := foot + Vector3.UP * 1.8
		if camera.is_position_behind(foot) or camera.is_position_behind(head):
			continue
		var a := camera.unproject_position(foot)
		var b := camera.unproject_position(head)
		if root.get_visible_rect().has_point(a) and root.get_visible_rect().has_point(b) and a.distance_to(b) >= min_pixels:
			count += 1
	return count


func _march_equal_lane(heavy: bool) -> int:
	var foot := _mission.battle.formations[0]
	var start := _position("Routes/RoadCut")
	var end := _position("Routes/EastPass")
	foot.position = start
	foot.hold()
	_mission.battle.hero_position = start + Vector2(-6, 0)
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	# Stick the destination at the same physical road midpoint and endpoint.
	# The existing HUD adds, consumes and activates both real queued moves.
	_aim(start.lerp(end, 0.5))
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_aim(end)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	if _hud.pending_waypoints(0).size() != 2:
		_fail("The real command cursor did not queue both supported lane points.")
		return -1
	var ticks := 0
	while not _hud.pending_waypoints(0).is_empty() and ticks < 1600:
		_tick()
		ticks += 1
		if not _mission._terrain.formation_fits_at(foot.position):
			_fail("The selected formation lost its terrain footprint on the same lane.")
			return -1
		if ticks == 4 and _mission._infantry_animators[0].current_animation != (&"Combat Run" if heavy else &"Run"):
			_fail("The approved rig did not use its native movement clip.")
			return -1
	if foot.position.distance_to(end) > 0.04 or foot.order != Battle.Order.HOLD \
			or (heavy and ticks not in range(1284, 1289)) or (not heavy and ticks not in range(1091, 1096)):
		_fail("Queue movement did not complete at the configured rate: %d frames, %s." % [ticks, foot.position])
		return -1
	return ticks


func _equal_contact(heavy: bool) -> bool:
	_button(JOY_BUTTON_START)
	_tick()
	var fight := _mission.encounter
	var foot := _mission.battle.formations[0]
	var start := _position("Routes/RoadCut")
	var end := _position("Routes/EastPass")
	# Same clear lane and stationary starting guard in both trials. None of
	# the ensuing movement, approach, windup, impacts, or losses are injected.
	foot.position = start
	foot.hold()
	_mission.battle.hero_position = start + Vector2(-6, 0)
	fight.enemy_position = end
	fight.enemy_phase = Fight.EnemyPhase.WATCHING
	_tick()
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_aim(end)
	_button(JOY_BUTTON_Y)
	_axis(JOY_AXIS_LEFT_X, 0.30)
	_tick()
	_axis(JOY_AXIS_LEFT_X, 0)
	_tick(59)
	var expected := 2.55 if heavy else 3.0
	if foot.order != Battle.Order.ATTACK or absf(foot.position.distance_to(start) - expected) > 0.02:
		return _fail("Attack approach did not use the same locomotion as Move.")
	var incoming := 0
	var hit_count := 0
	var hp_after_four := 0.0
	var followed := false
	var first_damage := 0.0
	for i in 2300:
		var hp := fight.infantry_attack.attacker.hp
		var guard := fight.enemy.hp
		_tick()
		if _hud._shield_follow.active and not followed:
			followed = true
			if heavy:
				if not _mission._mode_label.text.begins_with("HEAVY INFANTRY FOLLOW"):
					return _fail("The actual infantry follow still reads as the other rig.")
				await _checkpoint("03-heavy-contact-follow")
		if fight.enemy.hp < guard:
			hit_count += 1
			if hit_count == 1:
				first_damage = guard - fight.enemy.hp
		if fight.infantry_attack.attacker.hp < hp:
			incoming += 1
			if incoming == 4:
				hp_after_four = fight.infantry_attack.attacker.hp
		if foot.order == Battle.Order.DEFEATED:
			break
	if not followed or incoming != (5 if heavy else 4) \
			or not is_equal_approx(hp_after_four, 17.125748502994 if heavy else 0.0) \
			or not is_equal_approx(first_damage, (36.32 if heavy else 42.0) * Unit.damage_factor(1, 1)) \
			or not fight.enemy.is_alive() or not fight.hero.is_alive() or _mission._formation_models[0].visible \
			or fight.points.balance != 400 + hit_count * Inf.BP_PER_HIT:
		return _fail("Actual equal-lane retaliation, outgoing contact, follow or defeat diverged: %d hits, %d BP, %.2f HP at #4." % [
			incoming, fight.points.balance, hp_after_four,
		])
	print("%s: received %d guard hits, %.2f HP left after fourth; %.3f dealt per contact." % [
		foot.title, incoming, hp_after_four, first_damage,
	])
	var remaining := fight.enemy.hp
	var bp := fight.points.balance
	_tick(100)
	return (fight.enemy.hp == remaining and fight.points.balance == bp and not _hud._shield_follow.active) \
		or _fail("A defeated formation continued to damage, credit BP, or hold the follow lens.")


func _checkpoint(_label: String) -> void:
	pass


func _position(path: String) -> Vector2:
	return _mission._marker_position(_mission.battlefield_marker(NodePath("Markers/" + path)))


func _tick(count := 1) -> void:
	for i in count:
		_mission._physics_process(STEP)
		_hud._physics_process(STEP)


func _aim(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _mission._command_camera.unproject_position(_mission.to_global(_mission._ground(point)))
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _fail(message: String) -> bool:
	push_error(message)
	return false
