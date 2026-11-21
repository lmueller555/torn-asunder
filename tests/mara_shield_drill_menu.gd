extends "res://tests/mara_campaign_flow.gd"
## Reuse the real Greyhollow rescue from the campaign flow. Menu actions use actual
## viewport keyboard/controller input; training is never seeded into the save.

const DrillTraining := preload("res://game/combat/mara_subordinate_training.gd")
const Minimap := preload("res://game/battlefield/mara_campaign_minimap.gd")
const HEAVY := "Replay with Heavy Infantry"
const HEAVY_MODEL := "res://assets/models/human_heavy_infantry.glb"
const MapGlyphs := preload("res://game/battlefield/battlefield_minimap.gd")
const DRILL := "Shield Infantry Drill"
const CONFIRM := "Confirm Training (1 drill credit)"
const SLOT := DrillTraining.SHIELD_INFANTRY_SLOT
const DEFAULT_SIZE := Vector2i(1280, 720)
const REDUCED_SIZE := Vector2i(960, 540)


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-mara-drill-menu-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	])
	_title = TitleScene.instantiate()
	_title._profile = Profile.new(_profile_path)
	var configured := _title._profile.set_setting("fullscreen", false) == OK \
		and _title._profile.set_setting("reduced_motion", true) == OK
	root.add_child(_title)
	if DisplayServer.get_name() != "headless":
		root.size = DEFAULT_SIZE
	await process_frame
	var passed := configured and await _exercise_training_menu()
	_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Mara Shield Infantry: real Greyhollow clear, drill, guarded replay choice, queue, rescue HUD, regular default and save/BP isolation passed.")
	quit(0 if passed else 1)


func _exercise_training_menu() -> bool:
	_tap_key(KEY_ENTER) # Title New Game
	_tap_key(KEY_RIGHT)
	_tap_key(KEY_RIGHT)
	_tap_key(KEY_ENTER) # Vault: select Mara
	if not _on_map(CAMP):
		return _fail("Keyboard did not reach Mara's actual world map.")
	if not await _open_drill(false):
		return false
	var fresh := FileAccess.get_file_as_string(_profile_path)
	if not _state(1, 0, "Get Them Out", false) or not _focused("Back"):
		return _fail("The fresh menu did not show locked rank 1 and focus only Back.")
	await _capture("01-locked-default")
	_tap_key(KEY_DOWN)
	if not _focused("Back") or fresh != FileAccess.get_file_as_string(_profile_path):
		return _fail("Locked status moved into a phantom button or wrote the save.")
	_tap_joy(JOY_BUTTON_B)
	if _title._page != Title.Page.BRIEFING or not _focused(DRILL):
		return _fail("Controller Back did not return focus to the new camp entry.")
	_tap_key(KEY_UP)
	if not _focused("Unit Progression"):
		return _fail("The original Unit Progression action lost its directional focus.")
	_tap_key(KEY_LEFT)
	if not _focused("Combat Drills"):
		return _fail("The original Combat Drills action lost its directional focus.")
	_tap_key(KEY_DOWN)
	if not _focused("Read Dispatch"):
		return _fail("The original dispatch action lost its directional focus.")
	_tap_key(KEY_ESCAPE)

	if not await _deploy_mine(1, 700):
		return false
	var mission := _title._campaign_battle as Mission
	var at_mine := FileAccess.get_file_as_string(_profile_path)
	mission.report_hero_incapacitated()
	_tick()
	if mission.rescue_phase != Mission.Rescue.FAILED or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Defeat granted a campaign clear or changed the arrived profile.")
	_tap_key(KEY_BACKSPACE)
	if not _mine_budget(mission, 1, 700) or not _win_rescue():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR_ID]):
		return _fail("A real first rescue did not grant the saved Mine clear.")
	_tap_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or not _open_mine_briefing(false):
		return _fail("An untrained Mine replay did not hide the Heavy option.")
	_title._deploy_campaign_mission(CLEAR_ID, true)
	if not _on_briefing() or _title._campaign_battle:
		return _fail("A direct deployment request bypassed the missing drill.")
	_tap_key(KEY_ESCAPE)
	if not _on_map(MINE) or not _map().select_waypoint(CAMP):
		return _fail("The Mine briefing did not return to the world map.")
	_tap_joy(JOY_BUTTON_A)
	if not _on_map(CAMP) or not await _open_drill(true):
		return false
	var cleared := FileAccess.get_file_as_string(_profile_path)
	if not _state(1, 1, "Spend 1 drill credit", true) or not _focused("Back"):
		return _fail("A first clear should only offer the credit, with safe initial Back focus.")
	if DisplayServer.get_name() != "headless":
		root.size = REDUCED_SIZE
	await process_frame
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	if not _focused(CONFIRM) or not _fits(["Back", CONFIRM, "ShieldDrillStatus", "ShieldDrillAvailability"]):
		return _fail("Reduced-window controls do not fit or the confirm is not gamepad-reachable.")
	await _capture("02-confirm-reduced")
	if cleared != FileAccess.get_file_as_string(_profile_path):
		return _fail("Viewing or focusing the confirm changed the save before assent.")
	_tap_joy(JOY_BUTTON_A)
	if not _state(2, 0, "Qualified for Heavy Infantry.", false) or not _focused("Back"):
		return _fail("Confirm did not persist training, return safe focus, or explain the replay-only option.")
	var purchased := FileAccess.get_file_as_string(_profile_path)
	if purchased == cleared or Profile.new(_profile_path).mara_shield_infantry_training().formation_drill_rank(SLOT) != 2:
		return _fail("The UI confirmation did not survive reopening the saved profile.")
	await _capture("03-qualified-reduced")
	_tap_key(KEY_ESCAPE)
	if not _focused(DRILL):
		return _fail("Keyboard Back did not restore the Camp Operations entry focus.")
	_tap_key(KEY_ENTER)
	if not _state(2, 0, "Qualified for Heavy Infantry.", false) or FileAccess.get_file_as_string(_profile_path) != purchased:
		return _fail("Reopening trained status applied a second purchase.")
	_tap_key(KEY_ESCAPE)
	_tap_key(KEY_ESCAPE)
	if not await _deploy_mine(2, 720, true):
		return false
	mission = _title._campaign_battle as Mission
	var before_retry := FileAccess.get_file_as_string(_profile_path)
	if not await _heavy_queue_and_rescue_hud(mission):
		return false
	_tap_key(KEY_BACKSPACE)
	if not _mine_budget(mission, 2, 720) or not _heavy_active(mission) \
			or mission.rescue_phase != Mission.Rescue.RALLY \
			or mission._count(Mission.Miner.WAITING) != Mission.MINER_COUNT \
			or not _rescue_hud(mission, "Human miners", MapGlyphs.Icon.PICKUP, "HERO") \
			or FileAccess.get_file_as_string(_profile_path) != before_retry:
		return _fail("Per-attempt Retry did not keep the Heavy loadout and restore the original BP, crew, and rescue HUD.")
	if not _win_rescue():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or before_retry != FileAccess.get_file_as_string(_profile_path):
		return _fail("Heavy replay must not mint another credit or rewrite the outcome.")
	_tap_joy(JOY_BUTTON_B)
	if not await _deploy_mine(2, 720):
		return false
	mission = _title._campaign_battle as Mission
	if _heavy_active(mission) or mission.encounter.infantry_attack.attacker.max_hp != 310.0 \
			or mission.battle.formations[0].title != "Shield Infantry" or FileAccess.get_file_as_string(_profile_path) != before_retry:
		return _fail("The ordinary button did not reset to the regular roster after leaving the Heavy attempt.")
	_tap_key(KEY_ESCAPE)
	if not _on_map(MINE) or not _map().select_waypoint(ROAD):
		return _fail("The previous Heavy replay did not return through the normal campaign route.")
	_tap_joy(JOY_BUTTON_A)
	if not _on_map(ROAD) or not _map().select_waypoint(CROSSING):
		return _fail("The next regular chapter is no longer reachable after replay.")
	_tap_joy(JOY_BUTTON_A)
	if not _on_briefing() or _button(HEAVY) or not _button("Read Dispatch"):
		return _fail("Heavy was offered outside the Mine or replaced another chapter's dispatch.")
	_title._deploy_campaign_mission(GRAIN_ID, true)
	if not _on_briefing() or _title._campaign_battle:
		return _fail("A direct Heavy request bypassed the Mine-only scope at another Human battle.")
	_tap_key(KEY_ESCAPE)
	_tap_joy(JOY_BUTTON_B)
	_tap_key(KEY_ENTER)
	for _offset in range(3):
		_tap_joy(JOY_BUTTON_DPAD_RIGHT)
	_tap_key(KEY_ENTER)
	if not _map() or _title._campaign_world.campaign_id() != "raska":
		return _fail("Foreign comparison did not open Raska's live campaign.")
	_tap_joy(JOY_BUTTON_A)
	if _title._page != Title.Page.BRIEFING or _button(DRILL) or _button(CONFIRM) \
			or not _button("Combat Drills") or not _button("Unit Progression") or not _button("Read Dispatch"):
		return _fail("Human training leaked into another faction's Camp Operations.")
	_tap_key(KEY_ESCAPE)
	if not _map() or not _map().select_waypoint(MINE):
		return _fail("Could not select the shared Mine waypoint under the Orc campaign.")
	_tap_joy(JOY_BUTTON_A)
	if not _on_briefing() or _button(HEAVY):
		return _fail("Human replay choice leaked into the Orc view of the same Mine.")
	var foreign := FileAccess.get_file_as_string(_profile_path)
	_title._deploy_campaign_mission("orc_mine_witness", true)
	return (_on_briefing() and not _title._campaign_battle and FileAccess.get_file_as_string(_profile_path) == foreign) \
		or _fail("A direct foreign Heavy request changed the loaded battle or profile.")


func _open_drill(controller: bool) -> bool:
	_tap_joy(JOY_BUTTON_A)
	if _title._page != Title.Page.BRIEFING or not _focused("Back"):
		return _fail("Camp Operations did not open with its existing Back focus.")
	if controller:
		_tap_joy(JOY_BUTTON_DPAD_DOWN)
		_tap_joy(JOY_BUTTON_DPAD_RIGHT)
		_tap_joy(JOY_BUTTON_DPAD_DOWN)
		_tap_joy(JOY_BUTTON_DPAD_RIGHT)
	else:
		_tap_key(KEY_DOWN)
		_tap_key(KEY_DOWN)
		_tap_key(KEY_RIGHT)
	if not _focused(DRILL):
		return _fail("Arrow/D-pad did not reach the new action through the existing camp links.")
	if controller:
		_tap_joy(JOY_BUTTON_A)
	else:
		_tap_key(KEY_ENTER)
	await process_frame
	return _title._page == Title.Page.MARA_SHIELD_DRILL


func _open_mine_briefing(qualified: bool) -> bool:
	if not (_on_map(CAMP) or _on_map(MINE)) or not _map().select_waypoint(MINE):
		return _fail("Could not select the real Mine waypoint.")
	_tap_joy(JOY_BUTTON_A)
	return ((_on_briefing() and _focused("Back") and (_button(HEAVY) != null) == qualified)
		or _fail("Mine briefing did not respect eligibility or retain safe initial Back focus."))


func _deploy_mine(level: int, capacity: int, choose_heavy := false) -> bool:
	var qualified := _title._profile.mara_shield_infantry_training().qualifies_for_branch(SLOT, DrillTraining.BRANCH_UNIT)
	if not _open_mine_briefing(qualified):
		return false
	var before := FileAccess.get_file_as_string(_profile_path)
	if level == 1:
		_title._deploy_campaign_mission(CLEAR_ID, true)
		if not _on_briefing() or _title._campaign_battle or FileAccess.get_file_as_string(_profile_path) != before:
			return _fail("A fresh Mine briefing accepted a direct Heavy request.")
	if choose_heavy:
		if not _text("MineHeavyReplayTradeoff").contains("uses regular Shield Infantry") \
			or not _fits(["Confirm Deployment", HEAVY, "MineHeavyReplayTradeoff"]):
			return _fail("The optional loadout did not fit or explain the regular default.")
		_tap_joy(JOY_BUTTON_DPAD_DOWN)
		_tap_joy(JOY_BUTTON_DPAD_RIGHT)
		if not _focused(HEAVY):
			return _fail("Gamepad could not focus the optional loadout from the ordinary confirm.")
		# A stale visible control is not authorization. Replace its supplied
		# profile record with an independent unqualified one before real Accept.
		var trained := _title._profile
		_title._profile = Profile.new(_profile_path + ".untrained")
		_tap_joy(JOY_BUTTON_A)
		_title._profile = trained
		if not _on_briefing() or _title._campaign_battle or FileAccess.get_file_as_string(_profile_path) != before:
			return _fail("Deployment failed to recheck the current saved eligibility.")
		# Reopen to clear the rejected request notice before the native capture.
		_tap_key(KEY_ESCAPE)
		if not _open_mine_briefing(true):
			return false
		_tap_joy(JOY_BUTTON_DPAD_DOWN)
		_tap_joy(JOY_BUTTON_DPAD_RIGHT)
		await _capture("04-heavy-replay-choice-reduced")
		_tap_joy(JOY_BUTTON_A)
	else:
		_tap_key(KEY_DOWN)
		if not _focused("Confirm Deployment"):
			return _fail("The default deployment did not remain ordinary and keyboard-reachable.")
		_tap_key(KEY_ENTER)
	var mission := _title._campaign_battle as Mission
	if not mission or FileAccess.get_file_as_string(_profile_path) != before:
		return _fail("Deploying the selected loadout failed or rewrote the save.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	return ((_mine_budget(mission, level, capacity) and _heavy_active(mission) == choose_heavy)
		or _fail("Mine deployment used the wrong loadout or changed lead level/BP."))


func _heavy_active(mission: Mission) -> bool:
	var member := mission._formation_members[0][0].get_node_or_null("HeavyInfantryModel") as Node3D
	return (member != null and member.scene_file_path == HEAVY_MODEL
		and mission.encounter.infantry_attack.attacker.max_hp == Mission.HEAVY_HP
		and mission.battle.formations[0].move_speed == Mission.HEAVY_MOVE_SPEED
		and mission.battle.formations[0].title == "Heavy Infantry")


func _heavy_queue_and_rescue_hud(mission: Mission) -> bool:
	var hud := mission.get_node("MinimapHUD/Panel") as Minimap
	hud.set_physics_process(false)
	var group := mission.battle.formations[0]
	var destination := mission._marker_position(mission.battlefield_marker(^"Markers/Routes/WestAssembly"))
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	var mouse := InputEventMouseMotion.new()
	mouse.position = mission._command_camera.unproject_position(mission.to_global(mission._ground(destination)))
	root.push_input(mouse, true)
	_tap_joy(JOY_BUTTON_RIGHT_SHOULDER)
	if hud.pending_waypoints(0).size() != 1 or hud.pending_waypoints(0)[0].distance_to(destination) > 0.03:
		return _fail("The title-deployed Heavy formation did not accept a real tactical waypoint.")
	for _i in range(1100):
		if hud.pending_waypoints(0).is_empty():
			break
		_tick()
		hud._physics_process(DT)
	if group.position.distance_to(destination) > 0.06 or group.order != Battle.Order.HOLD \
		or not hud.pending_waypoints(0).is_empty() or mission.team_battle_points_frame().balance != 400:
		return _fail("The Heavy queue did not consume on physical arrival or changed BP.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	if not _rescue_hud(mission, "Human miners", MapGlyphs.Icon.PICKUP, "HERO"):
		return _fail("The replay did not show miners as the starting objective.")
	for point in [Vector2(-76, 21), Vector2(-61, 38), Vector2(-60.5, 51), Vector2(-60.5, 56)]:
		if not _drive_rescue(point):
			return false
	_tap_joy(JOY_BUTTON_A)
	_tick()
	if mission.rescue_phase != Mission.Rescue.ESCORT or mission._count(Mission.Miner.FOLLOWING) != Mission.MINER_COUNT \
			or not _rescue_hud(mission, "Safe hollow", MapGlyphs.Icon.EXIT, "HERO"):
		return _fail("Actual rally on the title-deployed Heavy replay did not show the evacuation objective.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	if not _rescue_hud(mission, "Safe hollow", MapGlyphs.Icon.EXIT, "SECTOR"):
		return _fail("The tactical view lost the evacuation objective or changed the Heavy roster.")
	await _capture("05-heavy-replay-rescue")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_tick()
	return true


func _rescue_hud(mission: Mission, place: StringName, icon: MapGlyphs.Icon, view: String) -> bool:
	var hud := mission.get_node("MinimapHUD/Panel") as Minimap
	hud.refresh()
	var objectives := PackedStringArray()
	var marker := Mission.RALLY_PATH if icon == MapGlyphs.Icon.PICKUP else Mission.SAFETY_PATH
	var target := mission._marker_position(mission.battlefield_marker(marker))
	var seen_heavy := false
	for glyph: MapGlyphs.Glyph in hud.map._glyphs:
		if glyph.icon in [MapGlyphs.Icon.PICKUP, MapGlyphs.Icon.EXIT, MapGlyphs.Icon.ALERT]:
			objectives.append(glyph.id if glyph.icon == icon and glyph.position == target else "wrong objective glyph")
		if glyph.id == &"Heavy Infantry" and glyph.icon == MapGlyphs.Icon.ALLY:
			seen_heavy = glyph.selected == (mission.selected_index == 0) \
				and glyph.position == mission.battle.formations[0].position
	return (mission._custody_case == null and mission.custody_case_scene == null
		and _no_pre_rescue_reveal(mission) and seen_heavy
		and root.get_camera_3d() == (mission._command_camera if view == "SECTOR" else mission._hero_camera)
		and hud._status.text == "GREYHOLLOW  /  " + view
		and objectives == PackedStringArray([place]))


func _state(rank: int, credit: int, summary: String, can_confirm: bool) -> bool:
	var button := _button(CONFIRM)
	return _title._page == Title.Page.MARA_SHIELD_DRILL \
		and _text("ShieldDrillRank") == "Formation Drill: Rank %d" % rank \
		and _text("ShieldDrillCredit") == "Available drill credit: %d" % credit \
		and _text("ShieldDrillStatus").contains(summary) \
		and _text("ShieldDrillAvailability").contains("Replay with Heavy Infantry" if rank == 2 else "Mine replays only") \
		and (button != null) == can_confirm and not _button("Promote to Heavy Infantry")


func _text(name: String) -> String:
	var label := _title._stage.get_node_or_null(name) as Label
	return label.text if label else ""


func _focused(name: String) -> bool:
	var selected := root.gui_get_focus_owner()
	return selected != null and selected.name == name


func _fits(nodes: Array[String]) -> bool:
	var viewport := root.get_visible_rect().grow(0.01)
	for name in nodes:
		var node := _title._stage.get_node_or_null(name) as Control
		if not node or not viewport.encloses(node.get_global_rect()) or node.size.x < node.get_minimum_size().x:
			return false
	return true


func _tap_key(code: Key) -> void:
	_key(code)
	_key(code, false)


func _tap_joy(code: JoyButton) -> void:
	_joy(code)
	var up := InputEventJoypadButton.new()
	up.button_index = code
	up.pressed = false
	root.push_input(up, true)


func _capture(stem: String) -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.save_png(args[0].path_join(stem + ".png")) != OK:
		push_error("Could not save native menu evidence: " + stem)
