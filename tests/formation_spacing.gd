extends SceneTree
## Closed, Normal and Open formations for melee platoons: pace (0.5x / 1x / 1.5x),
## soldiers gathering in or fanning out, the controls, and the control settings rows.

const Battle := preload("res://game/battlefield/command_battle.gd")
const HarnessScene := preload("res://game/battlefield/command_harness.tscn")
const InfantryAttack := preload("res://game/battlefield/mara_infantry_attack.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Bindings := preload("res://game/settings/control_bindings.gd")
const DT := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_simulation()
	_check_meter_grid()
	_check_attack_release()
	await _check_harness()
	await _check_tactical_retreat()
	_check_settings_rows()
	if _failures == 0:
		print("Formation spacing: exact file/rank meters, stable indexed combat return/retreat, pace and controls passed.")
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
	_check(infantry.spread > 1.0 and infantry.spread < infantry.target_spread(), "Soldiers fan out over time.")
	for i in range(120):
		battle.step(DT, Vector2.ZERO)
	_check(is_equal_approx(infantry.spread, infantry.target_spread()), "Soldiers settle at the Open spacing.")
	# The leader's own platoon marches at its formation's pace too.
	var lead_trial := Battle.new()
	lead_trial.step_spacing(Battle.LEAD_INDEX, -1)
	var lead_start := lead_trial.hero_position
	lead_trial.order_move(Battle.LEAD_INDEX, lead_start + Vector2(0.0, -10.0))
	lead_trial.step(0.5, Vector2.ZERO)
	_check(is_equal_approx(lead_trial.hero_position.distance_to(lead_start), Battle.LEAD_SPEED * 0.5 * 0.5),
		"The Lead Platoon in Closed formation marches at half pace.")


func _check_meter_grid() -> void:
	var battle := Battle.new()
	var regular := battle.formations[0]
	regular.configure_role(Battle.FormationRole.REGULAR_MELEE, 0.23)
	battle.lead.configure_lead(true)
	for group: Battle.Formation in [regular, battle.lead]:
		var seats := group.members.duplicate()
		for mode: Battle.Spacing in [Battle.Spacing.CLOSED, Battle.Spacing.NORMAL, Battle.Spacing.OPEN]:
			group.spacing = mode
			group.settle_spread(1.0)
			# Measured from world feet, not metadata or ratios: both axes in meters
			# even with a non-cardinal facing, under the scene's trailing bias.
			group.heading = Vector2(3.0, -4.0).normalized()
			var start := group.member_position(seats[0])
			var same_file := group.member_position(seats[1])
			var next_file := group.member_position(seats[6])
			var metres := float(mode + 1)
			_check(is_equal_approx(start.distance_to(same_file), metres)
				and is_equal_approx(start.distance_to(next_file), metres)
				and is_zero_approx((same_file - start).dot(next_file - start)),
				"%s %s is exactly %.0f m in both axes." % [group.title, group.spacing_name(), metres])
			_check(group.members == seats, "Changing mode never replaces or compacts the indexed roster.")
	var ranged := battle.formations[1]
	var ranged_entry := ranged.member_position(ranged.members[0])
	_check(not ranged.step_spacing(-1) and ranged.member_position(ranged.members[0]) == ranged_entry,
		"Fixed-layout archers keep their original positions.")


func _check_attack_release() -> void:
	var battle := Battle.new()
	var group := battle.formations[0]
	group.configure_role(Battle.FormationRole.REGULAR_MELEE)
	var actor := group.members[0]
	var at_home := group.member_position(actor)
	var attack := InfantryAttack.new()
	var enemy := Unit.new(1.0)
	var target := group.position + Vector2.UP * 2.0
	var clear := func(_a: Vector2, _b: Vector2) -> bool: return true
	var passable := func(_a: Vector2, _b: Vector2, _platoon: bool) -> bool: return true
	_check(attack.issue(group, enemy, target), "Use the authored infantry attack order.")
	for i in 8:
		battle.step(DT, Vector2.ZERO)
		attack.advance(DT, battle, enemy, target, clear, passable)
	_check(group.order == Battle.Order.ATTACK and group.member_position(actor) != at_home
		and group.member_position(actor) != group.slot_position(actor),
		"The authored attack owns moving feet outside their marching slots.")
	_check(enemy.is_alive() and group.leader.combatant == attack.attacker,
		"The existing aggregate combatant and strike timing own damage.")
	for i in 60:
		battle.step(DT, Vector2.ZERO)
		attack.advance(DT, battle, enemy, target, clear, passable)
		if group.order == Battle.Order.HOLD:
			break
	_check(not enemy.is_alive() and attack.contact_serial == 1 and group.order == Battle.Order.HOLD
		and group.has_detached_members(), "One lethal contact releases the platoon without snapping its feet.")

	# Keep an inactive index in the roster. No live fighter gets its slot.
	var casualty := group.members[1]
	casualty.combatant = Unit.new(1.0)
	casualty.combatant.receive_damage(1.0e3)
	var fallen_at := group.member_position(casualty)
	var from := group.member_position(actor)
	battle.step_spacing(0, 1)
	battle.order_move(0, group.position + Vector2(10.0, -3.0))
	battle.step(DT, Vector2.ZERO)
	_check(group.member_position(actor).distance_to(from) <= Battle.REGROUP_SPEED * DT + 0.001,
		"Movement, a turn, and widening on release do not teleport a returning soldier.")
	for i in 350:
		battle.step(DT, Vector2.ZERO)
	_check(group.members[0] == actor and group.members[1] == casualty
		and group.member_position(actor).is_equal_approx(group.slot_position(actor))
		and group.member_position(casualty) == fallen_at and not group.has_detached_members(),
		"Survivors reform at their original indices in the moving/turned Open layout; the casualty stays down.")


func _check_tactical_retreat() -> void:
	var script := GDScript.new()
	script.source_code = 'extends "res://game/battlefield/command_harness.gd"\nvar hostiles := PackedVector2Array()\nfunc _hostile_positions() -> PackedVector2Array:\n\treturn hostiles\n'
	_check(script.reload() == OK, "Compile an input fixture with a live contact source.")
	var harness = HarnessScene.instantiate()
	harness.set_script(script)
	root.add_child(harness)
	harness.set_physics_process(false)
	await physics_frame
	var battle: Battle = harness.battle
	var lead := battle.lead
	var actor := lead.members[0]
	var anchor: Node3D = harness._lead_members[actor.index]
	harness.hostiles = PackedVector2Array([battle.hero_position + Vector2.RIGHT * 3.0])
	for i in 20:
		harness._physics_process(DT)
	var before := lead.member_position(actor)
	_check(battle.lead_engaged and not before.is_equal_approx(lead.slot_position(actor)),
		"Real proximity engagement moves Lead Platoon feet away from their numbered seats.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key(KEY_O)
	var retreat := battle.hero_position + Vector2(-11.0, -6.0)
	harness.cursor = retreat
	_button(JOY_BUTTON_X)
	_check(lead.order == Battle.Order.MOVE and battle.lead_withdrawing and not battle.lead_engaged
		and lead.spacing == Battle.Spacing.OPEN and lead.member_position(actor) == before,
		"Command Move selects withdrawal even while a hostile stays in reach, with no positional snap.")
	var previous := before
	var bounded := true
	for i in 250:
		harness._physics_process(DT)
		var now := lead.member_position(actor)
		bounded = bounded and (i > 45 or now.distance_to(previous) <= Battle.REGROUP_SPEED * DT + 0.001)
		previous = now
	var rendered := harness.to_local(anchor.global_position) as Vector3
	_check(bounded and lead.members[actor.index] == actor and battle.hero_position.is_equal_approx(retreat)
		and lead.heading.is_equal_approx(Vector2(-11.0, -6.0).normalized())
		and lead.member_position(actor).is_equal_approx(lead.slot_position(actor))
		and Vector2(rendered.x, rendered.z).is_equal_approx(lead.member_position(actor)),
		"Retreat re-forms the same visible actor in its live Open seat relative to the new position and heading.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	harness.free()
	await process_frame


func _check_harness() -> void:
	var harness = HarnessScene.instantiate()
	root.add_child(harness)
	await physics_frame
	var battle: Battle = harness.battle
	var infantry := battle.formations[0]
	var members: Array = harness._formation_members[0]
	await _frames(2)
	var normal_width := _width(members)
	_check(harness.march_mode() and harness.selected_index == Battle.LEAD_INDEX, "The harness starts with the lead platoon selected.")
	_button(JOY_BUTTON_DPAD_RIGHT)
	_check(harness.selected_index == 0, "D-pad right selects the supporting infantry.")
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
