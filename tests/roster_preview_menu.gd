extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")

var _title: Title
var _profile_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile_path = OS.get_temp_dir().path_join("torn-roster-preview-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	var profile := Profile.new(_profile_path)
	var started := profile.set_setting("fullscreen", false) == OK and profile.set_setting("reduced_motion", true) == OK
	_title = TitleScene.instantiate() as Title
	_title._profile = profile
	root.add_child(_title)
	var passed := started and _check_moonwash()
	if passed:
		for fixture: Array in [
			["raska", "Brace Infantry"], ["sova", "Outlet Screen"],
			["neris", "Feeder Reserve"], ["sereth", "Stair Guard"],
		]:
			if not _check_route(fixture[0], fixture[1]):
				passed = false
				break
	if passed:
		passed = _check_marches_longbows()
	_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Roster preview: actual title flows, all six factions, practice ratings, sample rank isolation, keyboard/controller navigation and unchanged saves passed.")
	quit(0 if passed else 1)


func _check_moonwash() -> bool:
	if not _open_practice("ilyra"):
		return false
	var save := FileAccess.get_file_as_bytes(_profile_path)
	if not _press("Award 100 XP") or not _press("Ranged Power"):
		return false
	var unit := _title._training_unit
	_button("Award 100 XP").grab_focus()
	_joy(JOY_BUTTON_DPAD_DOWN)
	if root.gui_get_focus_owner() != _button("Preview Advancement"):
		return _fail("The controller did not reach the preview from the existing practice controls.")
	_key(KEY_ENTER)
	if _title._page != Title.Page.ROSTER_REQUIREMENTS or root.gui_get_focus_owner() != _button("Raise Sample Rank"):
		return _fail("Keyboard confirm did not open the preview and focus its sample rank control.")
	var rank := _label("Sample Training Rank")
	var marines := _label("Branch Requirements 0")
	var archers := _label("Branch Requirements 1")
	if not rank or not marines or not archers or not rank.text.contains("0 / 5") \
			or not marines.text.contains("Locked · Not playable") or not marines.text.contains("Formation Drill: 0 / 2 · missing 2 ranks") \
			or not archers.text.contains("Ranged Power: 2 / 4 · missing 2 points"):
		return _fail("The preview did not report authored options, practice rating investment, and separate exact rank gaps.")
	if marines.get_rect().end.x >= archers.position.x or archers.get_rect().end.x > 1364.0 \
			or marines.get_rect().end.y > 711.0 or archers.get_rect().end.y > 711.0:
		return _fail("The text-only columns overlap or cover the explanatory footer.")
	_key(KEY_ENTER)
	_joy(JOY_BUTTON_A)
	if not rank.text.contains("2 / 5") or not marines.text.contains("Eligible in this sample · Not playable") \
			or not archers.text.contains("Locked · Not playable"):
		return _fail("Only the branch whose requirements are met should show sample eligibility.")
	_key(KEY_LEFT)
	if root.gui_get_focus_owner() != _button("Lower Sample Rank"):
		return _fail("Keyboard focus could not reach the lower sample rank control.")
	_key(KEY_ENTER)
	if not rank.text.contains("1 / 5") or not marines.text.contains("Locked · Not playable"):
		return _fail("Lowering a sample rank did not restore the locked branch.")
	for node in _title._stage.find_children("*", "Button", true, false):
		if node.name not in [&"Back", &"Lower Sample Rank", &"Raise Sample Rank"]:
			return _fail("A planning-only branch exposed a recruitment or purchase action.")
	_joy(JOY_BUTTON_B)
	if _title._page != Title.Page.UNIT_PROGRESSION or root.gui_get_focus_owner() != _button("Preview Advancement") \
			or _title._training_unit != unit or unit.level != 2 or unit.rating(Unit.Damage.RANGED) != 2 \
			or unit.stat_points != 0 or _title._training_unit_id != &"":
		return _fail("Leaving the preview discarded practice progress or equipped a provisional unit.")
	_key(KEY_ENTER)
	var reopened := _label("Sample Training Rank")
	if not reopened or not reopened.text.contains("0 / 5"):
		return _fail("Sample ranks persisted as real investments, or keyboard could not reopen the preview.")
	_key(KEY_ESCAPE)
	if _title._page != Title.Page.UNIT_PROGRESSION or FileAccess.get_file_as_bytes(_profile_path) != save:
		return _fail("The planner did not return to practice or wrote the campaign save.")
	return _return_title()


func _check_route(campaign_id: String, first_branch: String) -> bool:
	if not _open_practice(campaign_id) or not _press("Preview Advancement"):
		return false
	var report := _label("Branch Requirements 0")
	if not report or not report.text.begins_with(first_branch + "\nLocked") or report.get_rect().end.y > 711.0:
		return _fail("Unit Progression showed the wrong or overflowing faction roster for " + campaign_id)
	_joy(JOY_BUTTON_B)
	return _return_title()


func _check_marches_longbows() -> bool:
	if not _open_practice("mara"):
		return false
	if _title._profile.record_mission_clear("mara", "mara_mine_escort") != OK \
			or _title._profile.purchase_mara_shield_infantry_drill() != OK:
		return _fail("Could not seed a nonzero saved Formation Drill before opening the preview.")
	var save := FileAccess.get_file_as_bytes(_profile_path)
	var unit := _title._training_unit
	var preview := _button("Preview Longbows")
	var inspect := _button("Inspect 3D Model")
	var promote := _button("Promote to Heavy Infantry")
	if not preview or not inspect or not promote or not promote.disabled or _button("Preview Advancement") \
			or preview.get_rect().end.x > _button("Back").position.x \
			or _button("Award 100 XP").get_rect().end.y > promote.position.y \
			or promote.get_rect().end.y > inspect.position.y:
		return _fail("The Longbows preview displaced or replaced the existing Human practice controls.")
	_joy(JOY_BUTTON_DPAD_DOWN)
	if root.gui_get_focus_owner() != inspect:
		return _fail("The usual path from XP to the inspector must still skip the locked Heavy promotion.")
	_button("Award 100 XP").grab_focus()
	_joy(JOY_BUTTON_DPAD_UP)
	_joy(JOY_BUTTON_DPAD_LEFT)
	if root.gui_get_focus_owner() != preview:
		return _fail("The controller did not reach Preview Longbows from Back.")
	_joy(JOY_BUTTON_A)
	var report := _label("Branch Requirements 0")
	var rank := _label("Sample Training Rank")
	if _title._page != Title.Page.ROSTER_REQUIREMENTS or not report or not rank \
			or root.gui_get_focus_owner() != _button("Raise Sample Rank") or _label("Branch Requirements 1") \
			or not rank.text.begins_with("Sample Formation Drill: 0 / 5") \
			or not report.text.begins_with("Marches Longbows\nLocked · Not playable") \
			or not report.text.contains("Ranged Power: 1 / 8 · missing 7 points") \
			or not report.text.contains("Formation Drill: 0 / 2 · missing 2 ranks"):
		return _fail("The Human report used the wrong unit, missed a gate, or reused the saved drill rank.")
	_joy(JOY_BUTTON_A)
	_key(KEY_ENTER)
	if not report.text.contains("Formation Drill: 2 / 2 · met") or not report.text.contains("Locked"):
		return _fail("Sample Formation Drill must not substitute for insufficient Ranged Power.")
	_joy(JOY_BUTTON_B)
	if _title._page != Title.Page.UNIT_PROGRESSION or root.gui_get_focus_owner() != _button("Preview Longbows") \
			or _title._training_unit != unit or unit.level != 1 or unit.stat_points != 0:
		return _fail("Leaving the Human preview changed practice state or lost its focus.")

	for i in range(25):
		if not _press("Award 100 XP"):
			return false
	for i in range(7):
		if not _press("Ranged Power"):
			return false
	var unspent := unit.stat_points
	var experience := unit.experience
	if unspent <= 0 or unit.rating(Unit.Damage.RANGED) != 8:
		return _fail("The fixture did not reach Ranged Power 8 with unspent practice points.")
	_key(KEY_ENTER)
	report = _label("Branch Requirements 0")
	rank = _label("Sample Training Rank")
	if not report or not rank or not rank.text.contains("0 / 5") or not report.text.contains("Locked") \
			or not report.text.contains("Ranged Power: 8 / 8 · met"):
		return _fail("Reopening should read the new practice rating but reset sample Formation Drill.")
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	if not report.text.contains("Eligible in this sample · Not playable") or not report.text.contains("Formation Drill: 2 / 2 · met"):
		return _fail("Meeting both gates should show eligibility while keeping Longbows unplayable.")
	for node in _title._stage.find_children("*", "Button", true, false):
		if node.name not in [&"Back", &"Lower Sample Rank", &"Raise Sample Rank"]:
			return _fail("The Longbows planner exposed an action other than adjusting the sample or leaving.")
	_key(KEY_ESCAPE)
	if root.gui_get_focus_owner() != _button("Preview Longbows") or _title._training_unit != unit \
			or _title._training_unit_id != Catalog.HUMAN_INFANTRY or unit.stat_points != unspent \
			or unit.experience != experience or unit.rating(Unit.Damage.RANGED) != 8 \
			or not _button("Promote to Heavy Infantry").disabled or FileAccess.get_file_as_bytes(_profile_path) != save:
		return _fail("Preview eligibility changed the Human practice unit, stats, promotion gate, or campaign save.")
	return true


func _open_practice(campaign_id: String) -> bool:
	return _press("New Game") and _press(campaign_id) and _press("ConfirmTravel") and _press("Unit Progression")


func _return_title() -> bool:
	_key(KEY_ESCAPE) # Practice to Camp Operations.
	_key(KEY_ESCAPE) # Camp to campaign map.
	_joy(JOY_BUTTON_B) # Map to title.
	return _title._page == Title.Page.TITLE or _fail("Back did not return through the existing campaign screens.")


func _button(node_name: String) -> Button:
	return _title.find_child(node_name, true, false) as Button


func _label(node_name: String) -> Label:
	return _title.find_child(node_name, true, false) as Label


func _press(node_name: String) -> bool:
	var button := _button(node_name)
	if not button or button.disabled or not button.is_visible_in_tree():
		return _fail("Missing or unavailable menu control: " + node_name)
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
