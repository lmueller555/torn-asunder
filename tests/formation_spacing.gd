extends SceneTree
## Closed, Normal and Open formations for melee platoons: pace (0.5x / 1x / 1.5x),
## soldiers gathering in or fanning out, the controls, and the control settings rows.

const Battle := preload("res://game/battlefield/command_battle.gd")
const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const Bindings := preload("res://game/settings/control_bindings.gd")
const DT := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_simulation()
	await _check_harness()
	_check_settings_rows()
	if _failures == 0:
		print("Formation spacing: Closed/Normal/Open pace, spreading and gathering, controls and settings rows passed.")
	quit(0 if _failures == 0 else 1)


func _check_simulation() -> void:
	var battle := Battle.new()
	var infantry := battle.formations[0]
	var archers := battle.formations[1]
	_check(infantry.spacing == Battle.Spacing.NORMAL and infantry.speed_factor() == 1.0 and infantry.spread == 1.0,
		"Platoons start in Normal formation at their usual pace.")
	for spacing in [Battle.Spacing.CLOSED, Battle.Spacing.NORMAL, Battle.Spacing.OPEN]:
		var trial := Battle.new()
		var group := trial.formations[0]
		group.spacing = spacing
		var start := group.position
		trial.order_move(0, start + Vector2(20.0, 0.0))
		trial.step(1.0, Vector2.ZERO)
		var expected: float = Battle.FORMATION_SPEED * [0.5, 1.0, 1.5][spacing]
		_check(is_equal_approx(group.position.distance_to(start), expected),
			"%s formation moves at %.1f m/s." % [group.spacing_name(), expected])
	_check(battle.step_spacing(0, -1) and infantry.spacing == Battle.Spacing.CLOSED, "Tightening steps Normal to Closed.")
	_check(not battle.step_spacing(0, -1) and infantry.spacing == Battle.Spacing.CLOSED, "Closed is the tightest formation.")
	_check(battle.step_spacing(0, 1) and battle.step_spacing(0, 1) and infantry.spacing == Battle.Spacing.OPEN
		and not battle.step_spacing(0, 1), "Widening steps through Normal to Open, the widest.")
	_check(not battle.step_spacing(1, -1) and archers.spacing == Battle.Spacing.NORMAL and archers.speed_factor() == 1.0,
		"Archers keep a single formation.")
	for title in ["Refugees", "Witnesses", "Escort Archers", "Basin Archers"]:
		archers.title = title
		_check(not archers.uses_formations(), "%s keep a single formation." % title)
	for title in ["Shield Infantry", "Heavy Infantry", "Household Guard", "Landing Marines", "Lead Platoon"]:
		archers.title = title
		_check(archers.uses_formations(), "%s change formation." % title)
	# The soldiers ease out to the wider spacing rather than jumping.
	infantry.spread = 1.0
	battle.step(DT, Vector2.ZERO)
	_check(infantry.spread > 1.0 and infantry.spread < Battle.SPACING_SPREAD[Battle.Spacing.OPEN], "Soldiers fan out over time.")
	for i in range(120):
		battle.step(DT, Vector2.ZERO)
	_check(is_equal_approx(infantry.spread, Battle.SPACING_SPREAD[Battle.Spacing.OPEN]), "Soldiers settle at the Open spacing.")
	# The leader's own platoon marches at its formation's pace too.
	var lead_trial := Battle.new()
	lead_trial.step_spacing(Battle.LEAD_INDEX, -1)
	var lead_start := lead_trial.hero_position
	lead_trial.order_move(Battle.LEAD_INDEX, lead_start + Vector2(0.0, -10.0))
	lead_trial.step(0.5, Vector2.ZERO)
	_check(is_equal_approx(lead_trial.hero_position.distance_to(lead_start), Battle.LEAD_SPEED * 0.5 * 0.5),
		"The Lead Platoon in Closed formation marches at half pace.")


func _check_harness() -> void:
	var harness = HarnessScene.instantiate()
	root.add_child(harness)
	await physics_frame
	var battle: Battle = harness.battle
	var infantry := battle.formations[0]
	var members: Array = harness._formation_members[0]
	await _frames(2)
	var normal_width := _width(members)
	_check(harness.march_mode() and harness.selected_index == 0, "The harness starts marching with the infantry selected.")
	_check(harness._controls_label.text.contains("L1 / I: tighter formation") and harness._controls_label.text.contains("R2 / O: wider formation"),
		"The marching controls list the formation buttons.")
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_check(infantry.spacing == Battle.Spacing.CLOSED and harness._formation_label.text.contains("Closed formation"),
		"L1 tightens the selected platoon to Closed and the HUD says so.")
	await _frames(60)
	_check(_width(members) < normal_width * 0.75, "The soldiers gather in when the platoon closes up.")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_check(infantry.spacing == Battle.Spacing.OPEN, "Each R2 squeeze widens the formation one step, to Open.")
	await _frames(90)
	_check(_width(members) > normal_width * 1.4, "The soldiers fan out when the platoon opens up.")
	_key(KEY_I)
	_check(infantry.spacing == Battle.Spacing.NORMAL, "I tightens on the keyboard.")
	_key(KEY_O)
	_check(infantry.spacing == Battle.Spacing.OPEN, "O widens on the keyboard.")
	# Command view changes the selected platoon's formation too.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_check(harness.command_view and infantry.spacing == Battle.Spacing.NORMAL, "L1 tightens the selected platoon in command view.")
	_check(harness._controls_label.text.contains("L1 / I: tighter formation"), "The command view controls list the formation buttons.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_DPAD_RIGHT)
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_check(battle.formations[1].spacing == Battle.Spacing.NORMAL and harness._controls_label.text.contains("keep a single formation"),
		"Archers say they keep a single formation.")
	# Lead platoon soldiers spread with it as well.
	_button(JOY_BUTTON_DPAD_RIGHT)
	_check(harness.selected_index == Battle.LEAD_INDEX, "D-pad reaches the Lead Platoon.")
	var lead_width := _width(harness._lead_members)
	_button(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(60)
	_check(battle.lead.spacing == Battle.Spacing.CLOSED and _width(harness._lead_members) < lead_width * 0.75,
		"The leader's own soldiers close up around them.")
	# In combat the fight owns L1 and R2 for the leader.
	battle.lead_engaged = true
	harness._calm_seconds = -1.0e6
	_button(JOY_BUTTON_LEFT_SHOULDER)
	_check(battle.lead.spacing == Battle.Spacing.CLOSED, "While fighting as the leader, L1 does not change formation.")
	harness.queue_free()
	await process_frame


func _check_settings_rows() -> void:
	_check(Bindings.ROWS[&"button"][JOY_BUTTON_LEFT_SHOULDER].contains("tighter formation")
		and Bindings.ROWS[&"trigger"][JOY_AXIS_TRIGGER_RIGHT].contains("wider formation")
		and Bindings.ROWS[&"key"][KEY_I] == "Tighter formation" and Bindings.ROWS[&"key"][KEY_O] == "Wider formation",
		"The control settings list the formation controls.")
	_check(Bindings.ROWS[&"button"][JOY_BUTTON_RIGHT_SHOULDER].contains("set waypoint")
		and Bindings.ROWS[&"button"][JOY_BUTTON_X].contains("add waypoint to route"),
		"The control settings list the waypoint controls.")


static func _width(members: Array) -> float:
	var low := INF
	var high := -INF
	for member: Node3D in members:
		low = minf(low, member.position.x)
		high = maxf(high, member.position.x)
	return high - low


func _axis(code: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = amount
	root.push_input(event, true)


func _button(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		root.push_input(event, true)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
