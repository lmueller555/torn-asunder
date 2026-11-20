extends SceneTree

const TitleScene := preload("res://game/title_screen.tscn")
const View := preload("res://game/combat/infantry_skirmish_view.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

var title: Control


func _initialize() -> void:
	call_deferred("_check_menu")


func _check_menu() -> void:
	title = TitleScene.instantiate()
	root.add_child(title)
	var passed := _run_flow()
	title.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _run_flow() -> bool:
	if not _press_all(["Unit Test", "AI Skirmish", "BlueCountPlus", "BluePlatoon2", "LevelPlusTen", "LevelPlus"]):
		return false
	if not _press_all(["RatingStep5", "FirePlus", "RatingStepAll", "IcePlus"]):
		return false
	if not _button("MeleePlus").disabled:
		return _fail("Investing all available points left part of the budget unspent.")
	if not _press_all(["IceMinus", "RatingStep1", "MeleePlus", "MeleePlus", "AmberPlatoon1", "LevelPlus", "IcePlus"]):
		return false
	# Amber has spent its only point. Switching back to Blue re-enables purchases.
	if not _button("MeleePlus").disabled:
		return _fail("The editor enabled spending another platoon's points.")
	if not _press_all(["BluePlatoon2", "StartSkirmish"]):
		return false
	var view := title.find_child("InfantrySkirmish", true, false) as View
	if not view:
		return _fail("Start Skirmish did not open the battle view.")
	view.set_physics_process(false)
	var n := Battle.PLATOON_SIZE
	if view.battle.team_size(0) != 2 * n or view.battle.team_size(1) != n or view._models.size() != 3 * n:
		return _fail("The running scene ignored the selected roster sizes.")
	var blue := view.battle.soldiers[n].unit
	var amber := view.battle.soldiers[2 * n].unit
	if blue.level != 12 or blue.rating(Unit.Damage.MELEE) != 3 or blue.rating(Unit.Damage.FIRE) != 6 or blue.stat_points != 4:
		return _fail("The running scene lost Blue platoon 2's build.")
	if amber.level != 2 or amber.rating(Unit.Damage.ICE) != 2 or amber.stat_points != 0 or view.battle.soldiers[0].unit.level != 1:
		return _fail("The menu applied one platoon's edits to another.")
	blue.receive_damage(blue.max_hp)
	if not _press_all(["Pause", "Restart"]):
		return false
	var restarted := view.battle.soldiers[n].unit
	if view.paused or restarted == blue or restarted.hp != restarted.max_hp or restarted.level != 12:
		return _fail("Restart did not restore the configured battle with fresh units.")
	if view.battle.survivors(0) != 2 * n or restarted.rating(Unit.Damage.MELEE) != 3 or restarted.stat_points != 4:
		return _fail("Restart lost platoon membership or allocated points.")
	# Return to Unit Test, open the editor again, and edit the retained Amber build.
	if not _press_all(["Back", "Back", "AI Skirmish", "AmberPlatoon1", "IceMinus", "HolyPlus", "StartSkirmish"]):
		return false
	view = title.find_child("InfantrySkirmish", true, false) as View
	if not view or view.battle.team_size(0) != 2 * n:
		return _fail("Back navigation discarded the configured roster.")
	amber = view.battle.soldiers[2 * n].unit
	if amber.level != 2 or amber.rating(Unit.Damage.ICE) != 1 or amber.rating(Unit.Damage.HOLY) != 2:
		return _fail("Back navigation failed to retain and update the selected build.")
	print("The title-menu setup, unequal rosters, per-platoon builds, restart and Back navigation work end to end.")
	return true


func _button(node_name: String) -> Button:
	return title.find_child(node_name, true, false) as Button


func _press_all(names: Array) -> bool:
	for node_name: String in names:
		var button := _button(node_name)
		if not button or button.disabled or not button.is_visible_in_tree():
			return _fail("Missing or unavailable menu control: %s" % node_name)
		button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
