extends SceneTree
## Exercises menu input and read-only state against the real Barracks component,
## without writing a profile. Title and live replay flows have their own tests.

const Barracks := preload("res://game/ui/human_barracks.gd")

var _view: Barracks
var _training_requests := 0
var _heavy_requests := 0
var _melee_requests := 0
var _back_requests := 0
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i(1440, 810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_setup_pad()
	_view = Barracks.new()
	_view.training_requested.connect(func(): _training_requests += 1)
	_view.heavy_replay_requested.connect(func(): _heavy_requests += 1)
	_view.melee_allocation_requested.connect(func(): _melee_requests += 1)
	_view.back_requested.connect(func(): _back_requests += 1)
	_view.configure({})
	root.add_child(_view)
	await process_frame

	_check(_focus(&"SelectShieldInfantry") and _text("SelectedPlatoon") == "Shield Infantry",
		"Fresh view starts on the Shield Infantry slot.")
	_check(_label("StatValue0").visible and _text("StatValue0") == "1" and _text("StatValue7") == "1",
		"Initial ratings come from the Mine subordinate proxy.")
	_tap(KEY_RIGHT)
	_check(_focus(&"JobShieldInfantry") and _text("JobDetailState").contains("EQUIPPED"),
		"Right moves from the roster to its actual equipped job.")
	_tap(KEY_RIGHT)
	_check(_focus(&"JobHeavyInfantry") and _text("JobDetailState") == "LOCKED"
		and _text("JobRequirements").contains("1 / 2") and _text("JobRequirements").contains("Melee Power 10"),
		"Heavy focus shows actual Drill progress independently from the read-only practice requirement.")
	_tap(KEY_ENTER)
	_check(not _action().visible and _training_requests == 0 and _heavy_requests == 0,
		"Selecting a locked job cannot purchase or equip it.")
	_pad(JOY_BUTTON_DPAD_DOWN)
	_check(_focus(&"JobMarchesLongbows") and _text("JobDetailState") == "NOT YET FIELDABLE"
		and _text("SelectedPlatoon") == "Archers" and _text("JobRequirements").contains("1 / 8")
		and _text("PlatoonProgress").contains("No campaign XP tracking")
		and _text("JobRequirements").contains("Not set / 2"),
		"Pad navigation switches to the separate Longbows branch, retaining the real Archer stats.")
	_check(_text("JobTradeoff").contains("52 → 66") and _text("JobTradeoff").contains("0.70 → 1.25"),
		"Longbow tradeoff describes the isolated prototype's extra range and slower draw.")
	_pad(JOY_BUTTON_A)
	_check(_heavy_requests == 0 and not _action().visible,
		"Longbows selection cannot emit a deployment choice.")
	_mouse(&"Training")
	_check(_focus(&"Training") and _text("StatValue1") == "Not set",
		"Mouse can select Training; Archers' unmodeled rank is not fabricated.")
	_tap(KEY_RIGHT)
	_check(_focus(&"Job") and _text("SelectedJobReadout").contains("248 starting proxy HP"),
		"Job tab reports the real Archer formation, not the highlighted future branch.")
	_mouse(&"SelectShieldInfantry")
	_tap(KEY_RIGHT)
	_tap(KEY_RIGHT)
	_view.configure({"shield_drill_rank": 1, "shield_drill_credit": true})
	_check(_focus(&"JobHeavyInfantry") and _text("JobScope").contains("One drill credit available")
		and not _action().visible, "Stationed Barracks leaves purchases to the existing Camp Operations flow.")
	_view.configure({"shield_drill_rank": 2, "heavy_replay_eligible": true})
	_check(_focus(&"JobHeavyInfantry") and _text("JobDetailState") == "ELIGIBLE · MINE REPLAY"
		and _text("JobRequirements").contains("2 / 2")
		and _text("JobScope").contains("Replay with Heavy Infantry")
		and _text("StateShieldInfantry").contains("EQUIPPED") and not _action().visible,
		"Saved eligibility refreshes without changing focus, roster, or fielded loadout.")
	_check(_text("JobTradeoff").contains("310 → 380") and _text("JobTradeoff").contains("3.00 → 2.55")
		and _text("JobTradeoff").contains("42 → 36.32"), "Heavy tradeoff uses the live Mine replay values.")
	_view.configure({
		"shield_drill_rank": 2, "heavy_replay_eligible": true,
		"archers": {"ratings": {"Ranged Power": 8}, "training": {"Formation Drill": 2}},
	})
	_mouse(&"JobMarchesLongbows")
	_check(_text("JobRequirements").contains("8 / 8") and _text("JobRequirements").contains("2 / 2")
		and _text("JobDetailState") == "NOT YET FIELDABLE" and not _action().visible,
		"Meeting Longbow reference requirements does not make it fieldable.")
	_mouse(&"Back")
	_check(_back_requests == 1, "Mouse Back emits exactly one request.")
	_check(_heavy_requests == 0 and _training_requests == 0, "The stationed screen was read-only throughout.")

	root.size = Vector2i(960, 540)
	await process_frame
	_view.configure({
		"shield": {
			"level": 2, "total_xp": 125, "xp_in_level": 25, "next_level_xp": 125,
			"remaining_melee_points": 1, "can_allocate_melee": true, "ratings": {"Melee Power": 1},
		},
	})
	_view.focus_initial()
	_tap(KEY_DOWN)
	_tap(KEY_DOWN)
	_mouse(&"Ratings")
	_mouse(&"SelectShieldInfantry")
	_check(_text("PlatoonProgress") == "Lv 2  ·  XP 25/125  ·  1 point"
		and _label("PlatoonProgress").tooltip_text == "125 total campaign XP"
		and _text("StatValue0") == "1", "Real Shield progress and current rating are shown before allocation.")
	_tap(KEY_RIGHT)
	_check(_focus(&"BarracksJobAction") and _action().text == "Allocate 1 point to Melee Power"
		and _melee_requests == 0, "Right focuses the explicit action without allocating a stat.")
	_pad(JOY_BUTTON_A)
	_check(_melee_requests == 1 and _text("StatValue0") == "1",
		"Confirm input only requests allocation; the view does not mutate the rating.")
	_view.focus_shield_action()
	_check(_focus(&"BarracksJobAction"), "Returning before the point is spent restores action focus.")
	_view.configure({
		"shield": {
			"level": 2, "total_xp": 125, "xp_in_level": 25, "next_level_xp": 125,
			"remaining_melee_points": 0, "can_allocate_melee": false, "ratings": {"Melee Power": 2},
		},
	})
	_view.focus_shield_action()
	_check(_focus(&"JobShieldInfantry") and not _action().visible and _text("StatValue0") == "2"
		and _text("PlatoonProgress").ends_with("0 points"),
		"An updated snapshot reports the spent point and moves focus out of the removed action.")
	_tap(KEY_ENTER)
	_check(_melee_requests == 1, "Reconfirming the crest cannot request a second allocation.")
	_tap(KEY_RIGHT)
	var req := _label("JobRequirements")
	var trade := _label("JobTradeoff")
	var scope := _label("JobScope")
	var graph := _view.get_node("JobHeavyInfantry") as Control
	_check(req.position.x + req.size.x < graph.position.x and req.get_line_count() == req.get_visible_line_count()
		and trade.get_line_count() == trade.get_visible_line_count()
		and scope.get_line_count() == scope.get_visible_line_count()
		and trade.position.y + trade.size.y < scope.position.y
		and root.get_stretch_transform().x.x <= 0.667
		and graph.get_global_rect().end.x <= root.get_visible_rect().size.x,
		"Requirements and tradeoffs fit to the left of the advancement graph at 960 × 540.")

	_view.queue_free()
	await process_frame
	print("Human Barracks: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _setup_pad() -> void:
	for action: StringName in [&"ui_accept", &"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = {
			&"ui_accept": JOY_BUTTON_A, &"ui_left": JOY_BUTTON_DPAD_LEFT, &"ui_right": JOY_BUTTON_DPAD_RIGHT,
			&"ui_up": JOY_BUTTON_DPAD_UP, &"ui_down": JOY_BUTTON_DPAD_DOWN,
		}[action]
		if not InputMap.action_has_event(action, button):
			InputMap.action_add_event(action, button)


func _tap(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event, true)


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)


func _mouse(target: StringName) -> void:
	var widget := _view.get_node(NodePath(target)) as Control
	var point := widget.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)


func _label(node_name: String) -> Label:
	return _view.get_node(node_name) as Label


func _text(node_name: String) -> String:
	return _label(node_name).text


func _focus(node_name: StringName) -> bool:
	var focus := root.gui_get_focus_owner()
	return is_instance_valid(focus) and focus.name == node_name


func _action() -> Button:
	return _view.get_node("BarracksJobAction") as Button


func _check(condition: bool, expectation: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + expectation)
