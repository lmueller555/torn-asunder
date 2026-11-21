extends SceneTree

const TitleScene := preload("res://game/title_screen.tscn")
const View := preload("res://game/combat/infantry_skirmish_view.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const REGULAR := Catalog.HUMAN_INFANTRY
const HEAVY := Catalog.HUMAN_HEAVY_INFANTRY

var _title: Control


func _initialize() -> void:
	call_deferred("_check_menu")


func _check_menu() -> void:
	_title = TitleScene.instantiate()
	root.add_child(_title)
	var passed := _run_flow()
	_title.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _run_flow() -> bool:
	if not _press_all(["Unit Test", "AI Skirmish", "BlueCountPlus", "BluePlatoon2"]):
		return false
	var blue: Setup.PlatoonBuild = _title._skirmish_setup.sides[0][1]
	var amber: Setup.PlatoonBuild = _title._skirmish_setup.sides[1][0]
	var regular := _button("TypeInfantry")
	var heavy := _button("TypeHeavyInfantry")
	var status := _title.find_child("UnitTypeStatus", true, false) as Label
	if not regular or not heavy or not status or not regular.button_pressed or not heavy.disabled \
			or not status.text.contains("Melee Power 1 / 10"):
		return _fail("The new setup did not show Infantry and explain the locked Heavy choice.")
	heavy.pressed.emit()
	if blue.unit_type != REGULAR or not regular.button_pressed:
		return _fail("An ineligible click bypassed the actual rating gate.")
	regular.grab_focus()
	_key(KEY_TAB)
	if root.gui_get_focus_owner() == heavy:
		return _fail("Tab navigated to a locked option.")
	if status.get_rect().end.x > 1288.0 or status.position.y < heavy.position.y - 2.0:
		return _fail("The class readout does not fit the setup panel.")

	if not _press_all(["LevelPlusTen", "RatingStep5", "MeleePlus", "RatingStep1", "MeleePlus", "MeleePlus", "MeleePlus"]):
		return false
	if not heavy.disabled or not status.text.contains("Melee Power 9 / 10"):
		return _fail("Melee 9 unlocked Heavy Infantry.")
	if not _press_all(["MeleePlus"]):
		return false
	if heavy.disabled or not status.text.contains("Melee Power 10 / 10") or blue.remaining_points() != 1:
		return _fail("Melee 10 did not unlock the Heavy option while preserving the point budget.")
	regular.grab_focus()
	_key(KEY_TAB)
	if root.gui_get_focus_owner() != heavy:
		return _fail("Tab skipped the available Heavy Infantry choice.")
	regular.grab_focus()
	_joy(JOY_BUTTON_DPAD_RIGHT)
	if root.gui_get_focus_owner() != heavy:
		return _fail("The D-pad could not reach the available Heavy choice.")
	_joy(JOY_BUTTON_A)
	if blue.unit_type != HEAVY or not heavy.button_pressed or not status.text.contains("more HP") \
			or not _button("BluePlatoon2").text.contains("Heavy Infantry") or amber.unit_type != REGULAR:
		return _fail("Selecting Heavy did not update the chosen platoon and its readouts only.")
	if not _press_all(["MeleeMinus"]):
		return false
	if blue.unit_type != REGULAR or not heavy.disabled or not regular.button_pressed:
		return _fail("An ineligible build did not revert with the controls updating.")
	if not _press_all(["MeleePlus", "TypeHeavyInfantry", "AmberPlatoon1"]):
		return false
	if not heavy.disabled or not regular.button_pressed or blue.unit_type != HEAVY:
		return _fail("Switching armies leaked eligibility or discarded the other platoon’s class.")
	if not _press_all(["StartSkirmish"]):
		return false

	var view := _view()
	if not view:
		return _fail("The setup did not launch the AI Skirmish view.")
	view.set_physics_process(false)
	if not _check_models(view):
		return false
	if not _press_all(["Restart"]):
		return false
	var index := Battle.PLATOON_SIZE
	if view.battle.soldiers[index].unit_type != HEAVY or not view._models[index].visible \
			or view._players[index].assigned_animation != &"Shield-Ready Idle":
		return _fail("Restart did not retain and reset the Heavy model and profile.")
	_joy(JOY_BUTTON_B)
	if not _button("BluePlatoon2").text.contains("Heavy Infantry") or blue.rating(Unit.Damage.MELEE) != 10 \
			or blue.remaining_points() != 1 or blue.unit_type != HEAVY:
		return _fail("Back did not preserve the class and spent/unspent points for editing.")
	print("Verified class eligibility, real keyboard/controller selection, mixed models and fallbacks, restart, and Back.")
	return true


func _check_models(view: View) -> bool:
	var n := Battle.PLATOON_SIZE
	if view._models.size() != 3 * n:
		return _fail("The battle did not instantiate all soldiers in the mixed roster.")
	for index in range(3 * n):
		var expected := HEAVY if index >= n and index < 2 * n else REGULAR
		if view._models[index].scene_file_path != Catalog.TYPES[expected].model.resource_path \
				or view.battle.soldiers[index].unit_type != expected:
			return _fail("A soldier did not render the selected type’s actual model.")
	var heavy_player := view._players[n]
	var regular_player := view._players[0]
	if heavy_player.root_motion_track.is_empty() or regular_player.root_motion_track.is_empty():
		return _fail("A model's cut still contributes its own translation.")
	if not _clips_match(view, n, {
		Battle.State.IDLE: &"Shield-Ready Idle",
		Battle.State.RUN: &"Combat Run",
		Battle.State.ATTACK: &"Advancing Diagonal Cut",
		Battle.State.RAISE: &"Shield Raise",
		Battle.State.GUARD: &"Shield Guard",
		Battle.State.LOWER: &"Shield Lower",
		Battle.State.RECOIL: &"Shield-Ready Idle",
		Battle.State.BLOCKED: &"Shield-Ready Idle",
		Battle.State.STAGGER: &"Shield-Ready Idle",
		Battle.State.KNOCKDOWN: &"Shield-Ready Idle",
		Battle.State.DOWN: &"Shield-Ready Idle",
		Battle.State.GET_UP: &"Shield-Ready Idle",
		Battle.State.CHEER: &"Shield-Ready Idle",
	}):
		return false
	if not _clips_match(view, 0, {
		Battle.State.IDLE: &"Idle",
		Battle.State.RUN: &"Run",
		Battle.State.ATTACK: &"Sword Slash",
		Battle.State.KNOCKDOWN: &"Backward Knockdown",
		Battle.State.DOWN: &"Backward Knockdown",
		Battle.State.DEAD: &"Death Fall",
	}):
		return false
	var heavy := view.battle.soldiers[n]
	heavy.unit.receive_damage(heavy.unit.hp)
	heavy.state = Battle.State.DEAD
	view._sync_models(1.0 / 60.0)
	if view._models[n].visible or view._markers[n].visible or not view._models[0].visible:
		return _fail("A Heavy corpse with no death clip did not hide safely.")
	return true


func _clips_match(view: View, index: int, expected: Dictionary) -> bool:
	for state in expected:
		view.battle.soldiers[index].state = state
		view._sync_models(1.0 / 60.0)
		if view._players[index].assigned_animation != expected[state]:
			return _fail("Unexpected state %d clip for %s: %s vs %s." % [
				state, view.battle.soldiers[index].unit_type, view._players[index].assigned_animation, expected[state],
			])
	return true


func _view() -> View:
	return _title.find_child("InfantrySkirmish", true, false) as View


func _button(node_name: String) -> Button:
	return _title.find_child(node_name, true, false) as Button


func _press_all(names: Array) -> bool:
	for node_name: String in names:
		var button := _button(node_name)
		if not button or button.disabled or not button.is_visible_in_tree():
			return _fail("Missing or unavailable menu control: %s" % node_name)
		button.pressed.emit()
	return true


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	_push_press(event)


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_push_press(event)


func _push_press(event: InputEvent) -> void:
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEvent
	release.pressed = false
	root.push_input(release)


func _fail(message: String) -> bool:
	push_error(message)
	return false
