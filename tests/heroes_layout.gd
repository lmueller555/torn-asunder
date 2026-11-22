extends SceneTree
## The Kingdom Under Fire: Heroes controller layout: physical buttons in Tactics
## (marching), Action (fighting as the leader) and Command (mini-map) modes, the
## combos (LT + RT + A, Y + B), Back as the mini-map toggle, prompts and settings.

const Bindings := preload("res://game/settings/control_bindings.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const MineScene := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const DT := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Bindings.layout() == Bindings.Layout.CLASSIC, "Scripted runs default to the classic slot layout.")
	Bindings.set_layout(Bindings.Layout.HEROES, "")
	await _check_tactics_and_command()
	await _check_action()
	_check_prompts_and_settings()
	Bindings.set_layout(Bindings.Layout.CLASSIC, "")
	if _failures == 0:
		print("Heroes layout: Tactics, Action and Command buttons, combos, the Back mini-map toggle, prompts and settings passed.")
	quit(0 if _failures == 0 else 1)


func _check_tactics_and_command() -> void:
	var harness = HarnessScene.instantiate()
	root.add_child(harness)
	await _frames(2)
	var battle: Battle = harness.battle
	var infantry := battle.formations[0]
	_check(Bindings.heroes_active() and harness.march_mode(), "A battlefield turns the Heroes layout on, starting in Tactics mode.")
	# LT / RT change the selected troop.
	_trigger(JOY_AXIS_TRIGGER_RIGHT, true)
	_trigger(JOY_AXIS_TRIGGER_RIGHT, false)
	_check(harness.selected_index == 1, "RT selects the next troop.")
	_trigger(JOY_AXIS_TRIGGER_LEFT, true)
	_trigger(JOY_AXIS_TRIGGER_LEFT, false)
	_check(harness.selected_index == 0, "LT selects the previous troop.")
	# A sends the troop to the marker, replacing its route; LT + RT + A adds to it.
	_nudge(Vector2(0.0, -1.0), 20)
	_button(JOY_BUTTON_A)
	var first: Vector2 = harness.march_marker
	_check(harness.march_waypoints(0).size() == 1 and infantry.order == Battle.Order.MOVE and infantry.destination.is_equal_approx(first),
		"A sets a waypoint and the troop moves to it.")
	_nudge(Vector2(1.0, 0.0), 12)
	_trigger(JOY_AXIS_TRIGGER_LEFT, true)
	_trigger(JOY_AXIS_TRIGGER_RIGHT, true)
	_button(JOY_BUTTON_A)
	_trigger(JOY_AXIS_TRIGGER_RIGHT, false)
	_trigger(JOY_AXIS_TRIGGER_LEFT, false)
	_check(harness.selected_index == 0 and harness.march_waypoints(0).size() == 2 and infantry.destination.is_equal_approx(first),
		"LT + RT + A appends a waypoint to the same troop's route.")
	_nudge(Vector2(0.0, 1.0), 8)
	_button(JOY_BUTTON_A)
	_check(harness.march_waypoints(0).size() == 1, "A on its own replaces the route again.")
	_button(JOY_BUTTON_B)
	_check(infantry.order == Battle.Order.HOLD and harness.march_waypoints(0).is_empty(), "B stops the troop and clears its route.")
	# Formations on the shoulder buttons (White = wider, Black = tighter).
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_check(infantry.spacing == Battle.Spacing.OPEN, "LB (White) sets a wider formation.")
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_check(infantry.spacing == Battle.Spacing.CLOSED, "RB (Black) sets a tighter formation.")
	# Y moves every troop at once.
	_nudge(Vector2(0.0, -1.0), 10)
	_button(JOY_BUTTON_Y)
	_check(infantry.order == Battle.Order.MOVE and battle.formations[1].order == Battle.Order.MOVE and battle.lead.order == Battle.Order.MOVE,
		"Y moves all troops at once.")
	# R3 changes the camera view.
	_button(JOY_BUTTON_RIGHT_STICK)
	_check(harness._camera_view == 1, "R3 changes the camera view.")
	# Back toggles the mini-map / command view; it stays on without holding anything.
	_button(JOY_BUTTON_BACK)
	await _frames(2)
	_check(harness.command_view, "Back opens the mini-map and command view, and it stays open.")
	harness.cursor = infantry.position + Vector2(3.0, 0.0)
	_button(JOY_BUTTON_A)
	_check(infantry.order == Battle.Order.MOVE and infantry.destination == harness.cursor, "In command view A moves the troop to the cursor.")
	_button(JOY_BUTTON_B)
	_check(infantry.order == Battle.Order.HOLD, "In command view B stops the troop.")
	_trigger(JOY_AXIS_TRIGGER_RIGHT, true)
	_trigger(JOY_AXIS_TRIGGER_RIGHT, false)
	_check(harness.selected_index == 1, "In command view RT selects the next troop.")
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_check(battle.formations[1].spacing == Battle.Spacing.NORMAL, "Archers keep one formation in command view too.")
	_button(JOY_BUTTON_Y)
	_check(infantry.order == Battle.Order.MOVE and battle.formations[1].order == Battle.Order.MOVE, "In command view Y moves all troops to the cursor.")
	_button(JOY_BUTTON_BACK)
	await _frames(2)
	_check(not harness.command_view and Bindings.axis(0, JOY_AXIS_TRIGGER_LEFT) == 0.0, "Back again closes the mini-map.")
	harness.queue_free()
	await process_frame
	_check(not Bindings.heroes_active(), "Leaving the battlefield turns the Heroes layout off for menus.")


func _check_action() -> void:
	var mission = MineScene.instantiate()
	root.add_child(mission)
	mission.set_physics_process(false)
	await _frames(2)
	var fight = mission.encounter
	mission.battle.lead_engaged = true
	mission._calm_seconds = -1.0e6
	_tick(mission)
	_check(mission.hero_combat_active() and int(Bindings._mode_provider.call().mode) == Bindings.Mode.ACTION,
		"Contact switches to Action mode with the leader selected.")
	_button(JOY_BUTTON_A)
	_check(fight.defense.attack_kind == Attack.Attack.LIGHT and fight.defense.attack_phase == Attack.Phase.WINDUP, "A is the normal attack.")
	_tick(mission, 90)
	_button_event(JOY_BUTTON_Y, true)
	_check(fight.defense.attack_phase == Attack.Phase.IDLE, "Holding Y waits for B before attacking.")
	_button_event(JOY_BUTTON_Y, false)
	_check(fight.defense.attack_kind == Attack.Attack.HEAVY, "Tapping Y is the heavy attack.")
	_tick(mission, 120)
	var points: int = fight.points.balance
	_button_event(JOY_BUTTON_Y, true)
	_button_event(JOY_BUTTON_B, true)
	_button_event(JOY_BUTTON_B, false)
	_button_event(JOY_BUTTON_Y, false)
	_check(fight.defense.attack_kind == Attack.Attack.SUNDERING_STRIKE and fight.points.balance < points, "Y + B is the special attack (Sundering Strike).")
	_tick(mission, 150)
	_button(JOY_BUTTON_B)
	_check(fight.defense.phase in [Defense.Phase.DODGE_STARTUP, Defense.Phase.DODGE_ACTIVE], "B on its own is the special move (dodge).")
	_tick(mission, 60)
	_button_event(JOY_BUTTON_RIGHT_SHOULDER, true)
	_tick(mission)
	_check(fight.defense.phase == Defense.Phase.GUARD, "With no officers yet, a shoulder button guards.")
	_button_event(JOY_BUTTON_RIGHT_SHOULDER, false)
	_tick(mission)
	var hud = mission.get_node_or_null("MinimapHUD/Panel")
	var focused_before: bool = hud._lead_action.focused if hud else false
	_button(JOY_BUTTON_RIGHT_STICK)
	_check(hud != null and hud._lead_action.focused != focused_before, "R3 changes the camera view (Mara's focus) in her missions.")
	_trigger(JOY_AXIS_TRIGGER_RIGHT, true)
	_trigger(JOY_AXIS_TRIGGER_RIGHT, false)
	_tick(mission)
	_check(mission.selected_index == 0 and not mission.hero_combat_active(), "RT switches to another troop mid-fight.")
	# Back opens the mini-map; D-pad Up aims on it, and A confirms the aimed Move.
	_button(JOY_BUTTON_BACK)
	_tick(mission)
	_button(JOY_BUTTON_DPAD_UP)
	_tick(mission)
	_check(mission.command_view and hud.is_drafting(), "Back, then D-pad Up, aims on the mini-map.")
	_axis(JOY_AXIS_LEFT_X, 0.6)
	_tick(mission, 10)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_A)
	_tick(mission)
	_check(not hud.is_drafting() and mission.battle.formations[0].order == Battle.Order.MOVE, "A confirms the aimed mini-map Move.")
	_button(JOY_BUTTON_BACK)
	_tick(mission)
	_check(not mission.command_view, "Back closes the mini-map.")
	mission.queue_free()
	await process_frame


func _check_prompts_and_settings() -> void:
	_check(TranslationServer.translate("Cross / Space: inspect the wheel marks.") == "Square / Space: inspect the wheel marks.",
		"Battle prompts name Square for interact in the Heroes layout.")
	_check(TranslationServer.translate("Release L2 / Shift to return to Sova.").begins_with("Press Back"),
		"Battle prompts name Back for the mini-map in the Heroes layout.")
	var rows: Dictionary = Bindings.rows()
	_check(rows[&"button"][JOY_BUTTON_Y].contains("Move all troops") and rows[&"button"][JOY_BUTTON_BACK].contains("Mini-map")
		and rows[&"trigger"][JOY_AXIS_TRIGGER_LEFT].contains("Previous troop"), "The settings list the Heroes layout's controls.")
	Bindings.set_layout(Bindings.Layout.CLASSIC, "")
	_check(TranslationServer.translate("Cross / Space: inspect the wheel marks.") == "Cross / Space: inspect the wheel marks."
		and Bindings.rows() == Bindings.ROWS, "The classic layout keeps its own prompts and settings rows.")


func _nudge(direction: Vector2, frames: int) -> void:
	_axis(JOY_AXIS_LEFT_X, direction.x)
	_axis(JOY_AXIS_LEFT_Y, direction.y)
	for i in range(frames):
		root.get_child(root.get_child_count() - 1)._physics_process(DT)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)


func _tick(mission: Node, count := 1) -> void:
	for i in range(count):
		mission._physics_process(DT)


func _trigger(code: JoyAxis, held: bool) -> void:
	_axis(code, 1.0 if held else 0.0)


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	_button_event(code, true)
	_button_event(code, false)


func _button_event(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	root.push_input(event, true)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
