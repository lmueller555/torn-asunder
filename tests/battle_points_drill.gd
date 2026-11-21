extends SceneTree

const TitleScene := preload("res://game/title_screen.tscn")
const Campaigns := preload("res://game/campaigns.gd")
const Points := preload("res://game/combat/battle_points.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Drill := preload("res://game/combat/battle_points_drill.gd")
const Ice := preload("res://game/combat/targeted_ice_cast.gd")

var _title: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_title = TitleScene.instantiate()
	root.add_child(_title)
	# Open an unsaved briefing so the test never writes a player profile.
	_title._active_campaign = Campaigns.ALL[0]
	_title._show_briefing()
	var passed := _check_flow() and await _check_ice_flow()
	_title.queue_free()
	await process_frame
	if passed:
		print("Verified Combat Drills navigation, shared BP, Holy, Ice windup/lane and measured hit, input focus and resets.")
	quit(0 if passed else 1)


func _check_flow() -> bool:
	if not _press("Combat Drills"):
		return false
	var entry := _button("Battle Points Drill")
	var curse := _button("Curse")
	if not entry or not curse or curse.get_node(curse.focus_neighbor_bottom) != entry:
		return _fail("Directional navigation did not reach Battle Points from the drill list.")
	if not _press("Battle Points Drill"):
		return false
	if root.gui_get_focus_owner() != _button("PracticeCharge"):
		return _fail("Opening the drill did not give its first action keyboard/controller focus.")

	var start := Points.STARTING_BALANCE
	var cap := Points.BASE_CAPACITY
	var cost := Battle.FIELD_BENEDICTION_BP_COST
	var initial_hp := _label("WoundedAllyHP")
	if _label("PoolBalance") != "%d / %d BP" % [start, cap] or not "Holy rating too low" in _label("BenedictionStatus"):
		return _fail("A fresh drill did not show the level-1 pool and untrained caster.")
	if not _press("CastBenediction") or not "No BP spent" in _label("DrillFeedback"):
		return _fail("An untrained caster could not visibly demonstrate a rejected cast.")
	if _label("WoundedAllyHP") != initial_hp or _label("PoolBalance") != "%d / %d BP" % [start, cap]:
		return _fail("Failed Holy admission modified HP or the pool.")

	if not _press("PracticeCharge") or _label("PoolBalance") != "%d / %d BP" % [start + Drill.PRACTICE_CHARGE_AWARD, cap]:
		return _fail("The confirmed practice charge did not credit the shared pool.")
	for charge in range(ceili(float(cap - start) / Drill.PRACTICE_CHARGE_AWARD)):
		if not _press("PracticeCharge"):
			return false
	if _label("PoolBalance") != "%d / %d BP" % [cap, cap] or not "already full" in _label("DrillFeedback"):
		return _fail("Repeated practice charges did not stop at the shared cap.")

	if not _press("TrainedCaster") or not "ready" in _label("BenedictionStatus"):
		return _fail("Selecting the trained support caster did not pass both checks.")
	if not _press("CastBenediction") or _label("PoolBalance") != "%d / %d BP" % [cap - cost, cap]:
		return _fail("The support caster did not spend points earned by the lead platoon.")
	if _label("WoundedAllyHP") == initial_hp:
		return _fail("A successful cast did not update displayed ally HP.")

	if not _press("ResetBattlePoints"):
		return false
	if _label("PoolBalance") != "%d / %d BP" % [start, cap] or _label("WoundedAllyHP") != initial_hp:
		return _fail("Reset did not return the drill to its starting battle.")
	if not _press("TrainedCaster"):
		return false
	for cast_index in range(floori(float(start) / cost)):
		if not _press("CastBenediction"):
			return false
	if not "not enough BP" in _label("BenedictionStatus"):
		return _fail("The qualified caster did not show the separate BP failure.")
	var low_pool := _label("PoolBalance")
	var hurt_hp := _label("WoundedAllyHP")
	if not _press("CastBenediction") or not "not enough BP" in _label("DrillFeedback"):
		return _fail("An unaffordable cast did not report the BP reason.")
	if _label("PoolBalance") != low_pool or _label("WoundedAllyHP") != hurt_hp:
		return _fail("Failed BP admission modified HP or the pool.")
	if not _press("PracticeCharge") or not "ready" in _label("BenedictionStatus"):
		return _fail("Earning enough points did not restore casting eligibility.")

	if not _press("Back") or root.gui_get_focus_owner() != _button("Battle Points Drill"):
		return _fail("Back did not return focus to the Battle Points entry in Combat Drills.")
	if not _press("Battle Points Drill") or _label("PoolBalance") != "%d / %d BP" % [start, cap]:
		return _fail("Reentering the drill leaked the previous session's balance.")
	if not _press("Back") or not _press("Back") or not _button("Combat Drills"):
		return _fail("The standard Back path to the briefing broke.")
	return true


func _check_ice_flow() -> bool:
	if not _press("Combat Drills") or not _press("Battle Points Drill"):
		return false
	var start := Points.STARTING_BALANCE
	var cap := Points.BASE_CAPACITY
	if not await _accept_with_input("PracticeSpell") or not "Ice rating too low" in _label("BenedictionStatus"):
		return _fail("Actual Enter did not open the Ice practice with separate rating eligibility.")
	var hp := _label("WoundedAllyHP")
	if not await _accept_with_input("TrainedCaster") or not _press("SimulatedLane"):
		return false
	if not _press("CastBenediction") or not "lane is covered" in _label("DrillFeedback"):
		return _fail("A covered practice lane did not deny cast admission.")
	if _label("PoolBalance") != "%d / %d BP" % [start, cap] or _label("WoundedAllyHP") != hp:
		return _fail("A denied Ice request changed health or the shared pool.")
	if not _press("SimulatedLane") or not await _accept_with_input("CastBenediction"):
		return false
	if not "winding up" in _label("BenedictionStatus") or _label("PoolBalance") != "%d / %d BP" % [start - Ice.COST, cap]:
		return _fail("A valid input did not begin the windup and debit the one shared pool.")
	if not _press("SimulatedLane"):
		return false
	await process_frame
	await process_frame
	if not "interrupted" in _label("DrillFeedback") or _label("WoundedAllyHP") != hp:
		return _fail("Cover during windup did not stop the actual Ice hit.")
	if _label("PoolBalance") != "%d / %d BP" % [start - Ice.COST, cap]:
		return _fail("An interrupted committed cast unexpectedly changed the shared points.")
	if not _press("SimulatedLane") or not _press("CastBenediction"):
		return false
	for count in range(48):
		await process_frame
	if not "Ice hit" in _label("DrillFeedback") or _label("WoundedAllyHP") == hp \
			or _label("PoolBalance") != "%d / %d BP" % [start - 2 * Ice.COST, cap]:
		return _fail("An uninterrupted windup did not deal one visible hit for the agreed cost.")
	if not _press("PracticeSpell") or not "Holy rating" in _label("HolyCheck"):
		return _fail("Returning to Field Benediction lost the original UI.")
	if _label("PoolBalance") != "%d / %d BP" % [start - 2 * Ice.COST, cap]:
		return _fail("Changing spell accidentally switched or reset the team pool.")
	return _press("ResetBattlePoints") and _label("PoolBalance") == "%d / %d BP" % [start, cap]


func _accept_with_input(id: String) -> bool:
	var button := _button(id)
	if not button or not button.is_visible_in_tree():
		return _fail("Missing control: %s" % id)
	button.grab_focus()
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		root.push_input(key, true)
		await process_frame
	return true


func _button(id: String) -> Button:
	return _title.find_child(id, true, false) as Button


func _label(id: String) -> String:
	var label := _title.find_child(id, true, false) as Label
	return label.text if label else ""


func _press(id: String) -> bool:
	var button := _button(id)
	if not button or button.disabled or not button.is_visible_in_tree():
		return _fail("Missing or unavailable drill control: %s" % id)
	button.pressed.emit()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
