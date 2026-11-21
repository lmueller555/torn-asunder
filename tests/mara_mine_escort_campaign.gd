extends SceneTree

const Scene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Escort := preload("res://game/battlefield/mine_escort_objective.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const FIELD := Rect2(-160, -108, 320, 224)
const DT := 1.0 / 60.0

var _mission: Mission
var _failures := 0
var _interceptions := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.objective.interception_requested.connect(func() -> void: _interceptions += 1)
	_key(KEY_BACKSPACE)
	var spawn := _mission.battle.hero_position
	var archer := _mission.battle.formations[1]
	var field := _mission._field
	var hero_camera := root.get_camera_3d()
	var fight := _mission.encounter
	_check(field.name == &"YearOneMineCampaign" and _mission.battle.bounds == FIELD,
		"The Mara variant instantiates the campaign valley and its 320 × 224 m playable bounds.")
	_check(spawn.is_equal_approx(_xz(_marker("Spawns/HumanEscort")))
		and archer.position.is_equal_approx(_xz(_marker("Spawns/HumanArchers")))
		and _mission.battle.formations[0].position.is_equal_approx(_xz(_marker("Spawns/HumanInfantry"))),
		"Hero, infantry and archers start at their campaign-map markers.")
	var guard_spawn := _marker("Routes/EastReserve")
	var reserve := _xz(guard_spawn)
	_check(fight != null and fight.enemy_position.is_equal_approx(reserve)
		and fight.enemy_phase == Encounter.EnemyPhase.AT_RESERVE,
		"The existing Orc starts in the authored reserve pocket, not in the road.")
	_mission.battle.hero_position = _xz(_marker("Routes/PassRelease"))
	_tick(130)
	_check(_interceptions == 0 and not _mission.objective.interception_triggered and fight.enemy_position == reserve,
		"Exploring the pass and waiting there before pickup does not release the reserve.")
	_key(KEY_BACKSPACE)
	fight = _mission.encounter
	hero_camera = root.get_camera_3d()
	archer = _mission.battle.formations[1]
	_check(_mission.get_node("ObjectiveHUD/Panel/Margin/Readout/Title").text.contains("PROTOTYPE"),
		"The large-map one-guard encounter is explicitly labeled as a prototype.")

	# Real viewport input and orthographic projection, not direct destination writes.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_check(_mission.command_view and root.get_camera_3d() != hero_camera
		and is_equal_approx(root.get_camera_3d().size, 116.0)
		and _mission._mode_label.text.begins_with("TACTICAL SECTOR"),
		"L2 opens a close tactical sector at the actual hero spawn.")
	var projected_party := root.get_camera_3d().unproject_position(_marker("Spawns/HumanArchers").global_position)
	_check(root.get_visible_rect().has_point(projected_party),
		"The initial tactical sector contains the selected archers.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	var march := ["RidgeWestApproach", "RidgeWestFoot", "RidgeWestCrest", "RidgeOverlook"]
	for waypoint: String in march:
		if waypoint == "RidgeOverlook":
			_button(JOY_BUTTON_RIGHT_STICK)
			_check(_mission._sector.overview and _mission._mode_label.text.begins_with("FIELD OVERVIEW"),
				"R3 opens field overview for the distant ridge.")
			for endpoint: String in ["Spawns/HumanEscort", "Objectives/GodbridleExit", "Objectives/MinerEvacuation"]:
				var world := _marker(endpoint).global_position
				_check(root.get_visible_rect().has_point(root.get_camera_3d().unproject_position(world)),
					"The whole-field overview frames the separated %s landmark." % endpoint)
		var target := _marker("Routes/" + waypoint)
		_order_at(target)
		_check(archer.order == Battle.Order.MOVE and archer.destination.distance_to(_xz(target)) < 0.04,
			"Projected command input orders the archers toward %s." % waypoint)
		_finish_march(archer, _xz(target), waypoint)
	_check(_mission._formation_models[1].position.y > 9.9,
		"The archers actually climb the campaign ridge instead of stopping at base elevation.")
	_button(JOY_BUTTON_LEFT_STICK)
	_check(not _mission._sector.overview and _mission._sector.view_center().is_equal_approx(spawn)
		and is_equal_approx(root.get_camera_3d().size, 116.0),
		"L3 recenters the tactical view on Mara.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(root.get_camera_3d() == hero_camera and _mission._field == field,
		"Releasing L2 restores the hero and preserves the shared battlefield and archers.")

	_key(KEY_SPACE)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.AWAITING_PICKUP,
		"An interaction from the western start does not pick up the Godbridle.")
	for id: String in ["Routes/WestAssembly", "Routes/QuarryTurn", "Routes/RoadWest", "Routes/MineYard", "Objectives/GodbridlePickup"]:
		_drive_to(_marker(id))
	_button(JOY_BUTTON_A)
	_tick()
	_check(_mission.objective.phase == Escort.Phase.ESCORTING and _mission._exit_beacon.visible,
		"Moving continuously from the western start to the works makes the authored pickup reachable by Cross.")
	for id: String in ["Routes/MineYard", "Routes/RoadWest", "Routes/RoadJunction", "Routes/RoadCut"]:
		_drive_to(_marker(id))

	_check(_interceptions == 0 and fight.enemy_position == reserve,
		"Pickup and time on the western road do not trigger the interception.")
	var pass_marker := _marker("Routes/EastPass")
	_drive_to(pass_marker)
	var merge_point := _xz(_marker("Routes/InterceptRoadMerge"))
	_check(_interceptions == 1 and _mission.objective.interception_triggered
		and fight.enemy_position != reserve and fight.enemy_position.distance_to(merge_point) < reserve.distance_to(merge_point)
		and _mission._instructions_label.text.contains("Orc movement ahead"),
		"The living carrier entering the authored pass approach warns and advances the existing Orc without a pop spawn.")
	_drive_to(_marker("Routes/RoadCut"))
	_tick(60)
	_check(fight.enemy_position.distance_to(merge_point) < 0.02,
		"The Orc physically reaches the road merge as the carrier retreats west.")
	_check(_interceptions == 1 and _mission.objective.interception_triggered,
		"Retreat does not reset the interception.")
	_drive_to(pass_marker)
	_drive_to(_marker("Routes/InterceptRoadMerge"), true)
	_check(_interceptions == 1 and fight.enemy_phase == Encounter.EnemyPhase.WINDUP and _mission._enemy_warning.visible,
		"Re-entering the approach does not fire again, and the active guard still engages Mara.")
	var hp := fight.hero.hp
	_key(KEY_U)
	_tick(43)
	_key(KEY_U, false)
	_check(fight.last_contact.begins_with("Guarded") and fight.hero.hp < hp and fight.hero.hp > hp - 35.0,
		"The inherited directional guard works at the campaign-scale encounter.")
	_key(KEY_J)
	_tick(35)
	for i in range(2):
		_key(KEY_K)
		_tick(58)
	_check(not fight.enemy.is_alive() and fight.hero.is_alive() and fight.points.balance > 400,
		"Actual light/heavy inputs can defeat the real pass guard and earn Battle Points.")
	_check(_mission.objective.phase == Escort.Phase.ESCORTING,
		"Defeating the guard does not win the escort before the east exit.")
	for id: String in ["Routes/EastPass", "Routes/PassRelease", "Objectives/GodbridleExit"]:
		_drive_to(_marker(id))
	_check(_mission.objective.phase == Escort.Phase.SUCCEEDED and _mission._goal_label.text == "Escort complete",
		"The living carrier reaches the real east boundary and wins without teleporting.")
	_check(_mission.battle.hero_position.distance_to(spawn) > 290.0,
		"This was the large-valley route rather than the original route pocket.")
	_key(KEY_BACKSPACE)
	_check(_mission.battle.hero_position.is_equal_approx(spawn) and _mission.encounter != fight
		and _mission.objective.phase == Escort.Phase.AWAITING_PICKUP
		and not _mission.objective.interception_triggered and _mission.encounter.enemy_position == reserve
		and root.get_camera_3d() == hero_camera and _mission._field == field,
		"Restart resets the attempt, reserve position and one-shot flag without replacing the field.")

	# Start a new attempt at the mine pickup waypoint, then take the real southern
	# traverse and never attack. Combat is a pressure beat, not a success gate.
	_mission.battle.hero_position = _xz(_marker("Objectives/GodbridlePickup"))
	_button(JOY_BUTTON_A)
	_tick()
	for id: String in ["Routes/MineYard", "Routes/RoadWest", "Routes/RoadJunction", "Routes/SouthReserve",
		"Routes/SouthTraverse", "Routes/SouthFlankCut", "Routes/PassFallback", "Routes/PassRelease",
		"Objectives/GodbridleExit"]:
		_drive_to(_marker(id))
	_check(_interceptions == 2 and _mission.objective.phase == Escort.Phase.SUCCEEDED and _mission.encounter.enemy.is_alive()
		and _mission.encounter.points.balance == 400,
		"A fresh attempt can warn once and deliver at the real exit without ever killing the Orc.")

	_mission.queue_free()
	await process_frame
	if _failures == 0:
		print("Campaign Mara escort: live camera projections, real command/hero inputs, ridge movement, conditional Orc approach, combat, no-kill delivery and retry verified.")
	quit(0 if _failures == 0 else 1)


func _marker(relative_path: String) -> Marker3D:
	return _mission.battlefield_marker(NodePath("Markers/" + relative_path))


func _xz(mark: Marker3D) -> Vector2:
	var local := _mission.to_local(mark.global_position)
	return Vector2(local.x, local.z)


func _order_at(mark: Marker3D) -> void:
	var camera := root.get_camera_3d()
	var pointer := camera.unproject_position(mark.global_position)
	_check(root.get_visible_rect().has_point(pointer), "Waypoint %s is inside the command view." % mark.name)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = pointer
	root.push_input(event, true)


func _finish_march(formation: Battle.Formation, target: Vector2, name: String) -> void:
	var budget := ceili(formation.position.distance_to(target) / Battle.FORMATION_SPEED / DT) + 20
	for i in range(budget):
		if formation.order != Battle.Order.MOVE:
			break
		_tick()
	_check(formation.order == Battle.Order.HOLD and formation.position.distance_to(target) < 0.06,
		"The archers complete the ordered leg to %s without being blocked; got %s." % [name, formation.position])


func _drive_to(mark: Marker3D, until_windup := false) -> void:
	var target := _xz(mark)
	var budget := ceili(target.distance_to(_mission.battle.hero_position) / Battle.HERO_SPEED / DT) + 120
	var reached := false
	for i in range(budget):
		var remaining := target - _mission.battle.hero_position
		if (until_windup and _mission.encounter.enemy_phase == Encounter.EnemyPhase.WINDUP) \
			or (not until_windup and remaining.length() < (Mission.EXIT_RADIUS if mark.name == &"GodbridleExit" else 0.13)):
			reached = true
			break
		if _mission._finished():
			break
		var aim := remaining.normalized().rotated(_mission._hero_yaw)
		_axis(JOY_AXIS_LEFT_X, aim.x)
		_axis(JOY_AXIS_LEFT_Y, aim.y)
		_tick()
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(reached, "Hero movement reaches %s; got %s." % [mark.name, _mission.battle.hero_position])


func _tick(count := 1) -> void:
	for i in range(count):
		_mission._physics_process(DT)


func _key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func _axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
		push_error(text)
