extends SceneTree

const TitleScene := preload("res://game/title_screen.tscn")
const ProfileStore := preload("res://game/profile_store.gd")
const Studio := preload("res://game/combat/unit_model_studio.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

var _title: Control
var _profile_path: String


func _initialize() -> void:
	call_deferred("_check_menu")


func _check_menu() -> void:
	_profile_path = "user://promotion-menu-%d.cfg" % OS.get_process_id()
	_title = TitleScene.instantiate()
	_title._profile = ProfileStore.new(_profile_path)
	root.add_child(_title)
	var passed := _run_flow()
	_title.queue_free()
	await process_frame
	DirAccess.remove_absolute(_profile_path)
	quit(0 if passed else 1)


func _run_flow() -> bool:
	if not _press_all(["New Game", "mara", "ConfirmTravel"]):
		return false
	if _title._profile.record_mission_clear("mara", "mara_mine_escort") != OK:
		return _fail("Could not prepare the fixture campaign save.")
	var before := FileAccess.get_file_as_bytes(_profile_path)
	if before.is_empty() or not _press_all(["Unit Progression"]):
		return false

	var promote := _button("Promote to Heavy Infantry")
	var status := _title.find_child("Promotion Status", true, false) as Label
	if not promote or not promote.disabled or not status \
			or not status.text.contains("Melee Power 1 / 10") or not status.text.contains("+120 starting HP") \
			or not status.text.contains("5 less base sword damage") or not status.text.contains("Practice only"):
		return _fail("The fresh practice screen did not explain and lock the promotion.")
	if _title._training_stats.get_rect().end.y > status.position.y \
			or status.get_rect().end.y > _button("Award 100 XP").position.y \
			or status.get_rect().end.x > 523.0 \
			or _button("Inspect 3D Model").get_rect().end.y > _title._notice.position.y:
		return _fail("The practice text or controls overlap in the menu's fixed layout.")
	promote.pressed.emit() # Even a direct activation cannot bypass the actual rating gate.
	if _title._training_unit_id != Catalog.HUMAN_INFANTRY or not _button("Promote to Heavy Infantry").disabled:
		return _fail("An ineligible unit was promoted.")
	_joy(JOY_BUTTON_DPAD_DOWN)
	if root.gui_get_focus_owner() != _button("Inspect 3D Model"):
		return _fail("Controller navigation did not skip the locked promotion.")
	_joy(JOY_BUTTON_A)
	if not _studio() or _studio()._unit.scene_file_path != Catalog.TYPES[Catalog.HUMAN_INFANTRY].model.resource_path:
		return _fail("Inspect 3D Model did not open the regular Infantry studio.")
	_joy(JOY_BUTTON_B)
	if root.gui_get_focus_owner() != _button("Inspect 3D Model"):
		return _fail("Returning from the model did not restore inspector focus.")

	for i in range(25):
		if not _press_all(["Award 100 XP"]):
			return false
	for i in range(8):
		if not _press_all(["Melee Power"]):
			return false
	if not _press_all(["Holy"]):
		return false
	promote = _button("Promote to Heavy Infantry")
	if not promote.disabled or not _title._training_promotion_status.text.contains("Melee Power 9 / 10"):
		return _fail("A high level or investment in another rating unlocked the promotion.")
	if not _press_all(["Melee Power"]):
		return false
	if promote.disabled or not _title._training_promotion_status.text.contains("Melee Power 10 / 10"):
		return _fail("Melee Power 10 did not unlock the promotion.")
	var unit: Unit = _title._training_unit
	var health_before := unit.max_hp
	var xp_before := unit.experience
	unit.receive_damage(13.0)
	if unit.level != 12 or xp_before <= 0 or unit.stat_points != 1:
		return _fail("The fixture did not earn the intended level, partial XP, and unspent point.")

	_button("Award 100 XP").grab_focus()
	_key(KEY_TAB)
	if root.gui_get_focus_owner() != promote:
		return _fail("Keyboard focus order skipped the available promotion.")
	_button("Award 100 XP").grab_focus()
	_joy(JOY_BUTTON_DPAD_DOWN)
	if root.gui_get_focus_owner() != promote:
		return _fail("Controller navigation skipped the available promotion.")
	_joy(JOY_BUTTON_A)
	if _title._training_unit_id != Catalog.HUMAN_HEAVY_INFANTRY or _title._training_unit != unit:
		return _fail("The promotion did not equip Heavy Infantry on the existing practice unit.")
	if not is_equal_approx(unit.max_hp, health_before * 1.10) or not is_equal_approx(unit.max_hp - unit.hp, 13.0) \
			or unit.experience != xp_before or unit.level != 12 or unit.stat_points != 1 \
			or unit.rating(Unit.Damage.MELEE) != 10 or unit.rating(Unit.Damage.HOLY) != 2 \
			or _title._training_base_hit != Catalog.TYPES[Catalog.HUMAN_HEAVY_INFANTRY].basic_attack[Unit.Damage.MELEE]:
		return _fail("The promotion lost earned progress, a wound, or the new profile.")
	if not _button("Promote to Heavy Infantry").disabled or root.gui_get_focus_owner() != _button("Inspect 3D Model"):
		return _fail("The promote action did not close or restore focus to the inspector.")
	_joy(JOY_BUTTON_A)
	if not _studio() or _studio()._unit.scene_file_path != Catalog.TYPES[Catalog.HUMAN_HEAVY_INFANTRY].model.resource_path \
			or _studio().animation_player.current_animation != &"Shield-Ready Idle":
		return _fail("The inspector did not load the heavy model and its preview pose.")
	_joy(JOY_BUTTON_B)
	if _title._training_unit != unit or _title._training_unit_id != Catalog.HUMAN_HEAVY_INFANTRY:
		return _fail("Closing the heavy inspector discarded the equipped profile or progress.")
	_joy(JOY_BUTTON_B)
	if root.gui_get_focus_owner() != _button("Unit Progression") or not _press_all(["Unit Progression"]):
		return _fail("Back did not return to the briefing's Unit Progression control.")
	if _title._training_unit_id != Catalog.HUMAN_INFANTRY or _title._training_unit.level != 1 \
			or not _button("Promote to Heavy Infantry").disabled:
		return _fail("Opening a new practice session did not reset the temporary promotion.")
	if before != FileAccess.get_file_as_bytes(_profile_path):
		return _fail("Promotion practice changed the existing campaign save.")

	if not _press_all(["Back", "Back", "Back", "New Game", "sova", "Unit Progression"]):
		return false
	if _button("Promote to Heavy Infantry") or _button("Inspect 3D Model"):
		return _fail("The Infantry branch appeared in an unrelated campaign's practice session.")
	print("Verified the promotion gate, real controller focus/accept/back, retained progression, both model views, and an unchanged campaign save.")
	return true


func _studio() -> Studio:
	return _title.find_child("UnitModelStudio", true, false) as Studio


func _button(node_name: String) -> Button:
	return _title.find_child(node_name, true, false) as Button


func _press_all(names: Array) -> bool:
	for node_name: String in names:
		var button := _button(node_name)
		if not button or button.disabled or not button.is_visible_in_tree():
			return _fail("Missing or unavailable menu control: %s" % node_name)
		button.pressed.emit()
	return true


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release)


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)


func _fail(message: String) -> bool:
	push_error(message)
	return false
