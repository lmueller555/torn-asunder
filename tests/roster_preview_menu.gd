extends SceneTree

const Title := preload("res://game/title_screen.gd")
const TitleScene := preload("res://game/title_screen.tscn")
const Profile := preload("res://game/profile_store.gd")
const Unit := preload("res://game/combat/combat_unit.gd")

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
		passed = _open_practice("mara") and not _button("Preview Advancement") \
			and _button("Promote to Heavy Infantry") != null
		if not passed:
			_fail("The provisional preview replaced or altered the Human-only practice promotion.")
	_title.queue_free()
	await process_frame
	for path in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if passed:
		print("Roster preview: actual title flows, all five planning factions, live practice ratings, sample rank isolation, keyboard/controller navigation and unchanged saves passed.")
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
