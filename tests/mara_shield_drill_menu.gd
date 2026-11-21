extends "res://tests/mara_campaign_flow.gd"
## Reuse the real Mine traverse from the campaign flow. Menu actions use actual
## viewport keyboard/controller input; training is never seeded into the save.

const DrillTraining := preload("res://game/combat/mara_subordinate_training.gd")
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
		print("Mara shield drill menu: real Mine clear, locked/offered/qualified flow, keyboard/controller focus, save/retry and foreign scope passed.")
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
	if not _state(1, 0, "Clear The Pass Below the Mine", false) or not _focused("Back"):
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
	if mission.objective.phase != Escort.Phase.FAILED or FileAccess.get_file_as_string(_profile_path) != at_mine:
		return _fail("Defeat granted a campaign clear or changed the arrived profile.")
	_tap_key(KEY_BACKSPACE)
	if not _mine_budget(mission, 1, 700) or not _win_escort():
		return false
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or _saved_clears() != PackedStringArray([CLEAR_ID]):
		return _fail("A real first delivery did not grant the saved Mine clear.")
	_tap_joy(JOY_BUTTON_B)
	if not _on_map(MINE) or not _map().select_waypoint(CAMP):
		return _fail("The Mine debrief did not return to the world map.")
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
		return _fail("Confirm did not persist training, return safe focus, or leave equip unavailable.")
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
	if not await _deploy_mine(2, 720):
		return false
	mission = _title._campaign_battle as Mission
	var before_retry := FileAccess.get_file_as_string(_profile_path)
	_tap_key(KEY_BACKSPACE)
	if not _mine_budget(mission, 2, 720) or mission.encounter.infantry_attack.attacker.max_hp != 310.0 \
			or FileAccess.get_file_as_string(_profile_path) != before_retry or not _win_escort():
		return _fail("Training altered the deployment profile, ordinary combat roster, or retry.")
	await process_frame
	if not _is_dialogue(Beats.MARA_MINE_DEBRIEF) or before_retry != FileAccess.get_file_as_string(_profile_path):
		return _fail("Replay must not mint another credit or rewrite the outcome.")
	_tap_joy(JOY_BUTTON_B)
	_tap_joy(JOY_BUTTON_B)
	_tap_key(KEY_ENTER)
	for _offset in range(3):
		_tap_joy(JOY_BUTTON_DPAD_RIGHT)
	_tap_key(KEY_ENTER)
	if not _map() or _title._campaign_world.campaign_id() != "raska":
		return _fail("Foreign comparison did not open Raska's live campaign.")
	_tap_joy(JOY_BUTTON_A)
	return (_title._page == Title.Page.BRIEFING and not _button(DRILL) and not _button(CONFIRM)
		and _button("Combat Drills") != null and _button("Unit Progression") != null
		and _button("Read Dispatch") != null) or _fail("Human training leaked into another faction's Camp Operations.")


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


func _deploy_mine(level: int, capacity: int) -> bool:
	if not _on_map(CAMP) or not _map().select_waypoint(MINE):
		return _fail("The camp did not connect to the real Mine waypoint.")
	_tap_joy(JOY_BUTTON_A)
	if not _on_briefing():
		return _fail("World-map confirmation did not open the Mine briefing.")
	_tap_key(KEY_DOWN)
	_tap_key(KEY_ENTER)
	var mission := _title._campaign_battle as Mission
	if not mission:
		return _fail("Keyboard did not explicitly deploy from the Mine briefing.")
	mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	return _mine_budget(mission, level, capacity) or _fail("The original Mine lead level and Battle Point budget changed.")


func _state(rank: int, credit: int, summary: String, can_confirm: bool) -> bool:
	var button := _button(CONFIRM)
	return _title._page == Title.Page.MARA_SHIELD_DRILL \
		and _text("ShieldDrillRank") == "Formation Drill: Rank %d" % rank \
		and _text("ShieldDrillCredit") == "Available drill credit: %d" % credit \
		and _text("ShieldDrillStatus").contains(summary) \
		and _text("ShieldDrillAvailability").contains("cannot be deployed") \
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
