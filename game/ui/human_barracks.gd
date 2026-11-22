extends Control
## The caller owns campaign state, purchases, deployment and Escape / Circle.
## Focusing or inspecting a job never equips it.
signal back_requested
signal training_requested
signal melee_allocation_requested
signal heavy_replay_requested

const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Drill := preload("res://game/combat/mara_subordinate_training.gd")
const Infantry := preload("res://game/battlefield/mara_infantry_attack.gd")
const Archers := preload("res://game/battlefield/mara_archer_attack.gd")
const Volley := preload("res://game/combat/human_archer_volley.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Mine := preload("res://game/battlefield/mara_mine_escort.gd")
const DISPLAY := preload("res://assets/fonts/Cinzel.ttf")
const BODY := preload("res://assets/fonts/SourceSans3.ttf")
const GOLD := Color("#d9ad70")
const IVORY := Color("#f4e8d5")
const MUTED := Color("#bcb5a7")
const SILVER := Color("#aec6cc")
const GREEN := Color("#b2d29b")
const FADED := Color("#a89a8b")
const HAIRLINE := Color("#665745")
const PANEL := Color(0.055, 0.062, 0.061, 0.98)
const BOARD := Color(0.064, 0.074, 0.073, 0.98)
const INSET := Color("#151c1c")

const SHIELD := Catalog.HUMAN_INFANTRY
const HEAVY := Catalog.HUMAN_HEAVY_INFANTRY
const BOW := Catalog.HUMAN_ARCHER
const LONGBOW := Catalog.HUMAN_MARCHES_LONGBOWS
const JOBS := [SHIELD, HEAVY, BOW, LONGBOW]
const NAMES := {SHIELD: "Shield Infantry", HEAVY: "Heavy Infantry", BOW: "Archers", LONGBOW: "Marches Longbows"}
const CENTERS := {
	SHIELD: Vector2(969, 357), HEAVY: Vector2(1229, 357),
	BOW: Vector2(969, 566), LONGBOW: Vector2(1229, 566),
}
const RATINGS := {
	Unit.Damage.MELEE: "Melee Power", Unit.Damage.RANGED: "Ranged Power", Unit.Damage.FIRE: "Fire",
	Unit.Damage.LIGHTNING: "Lightning", Unit.Damage.ICE: "Ice", Unit.Damage.NATURE: "Nature",
	Unit.Damage.HOLY: "Holy", Unit.Damage.CURSE: "Curse",
}
const TRAINING := {
	Platoon.Skill.CHARGE_BRACE: "Charge & Brace", Platoon.Skill.FORMATION_DRILL: "Formation Drill",
	Platoon.Skill.MOUNTED_TRAINING: "Mounted Training", Platoon.Skill.SCOUTING: "Scouting",
	Platoon.Skill.SIEGECRAFT: "Siegecraft", Platoon.Skill.BEAST_HANDLING: "Beast Handling",
}
const VIEWS := [&"Ratings", &"Training", &"Job"]

var _snapshot := {}
var _roster := Catalog.faction_roster()
var _slot: StringName = SHIELD
var _inspected: StringName = SHIELD
var _view: StringName = &"Ratings"
var _slots: Dictionary[StringName, Button] = {}
var _nodes: Dictionary[StringName, Button] = {}
var _states: Dictionary[StringName, Label] = {}
var _tabs: Dictionary[StringName, Button] = {}
var _back: Button
var _action: Button
var _active_title: Label
var _active_group: Label
var _progress: Label
var _keys: Array[Label] = []
var _values: Array[Label] = []
var _field_role: Label
var _detail_title: Label
var _detail_state: Label
var _detail_role: Label
var _detail_gate: Label
var _detail_trade: Label
var _detail_scope: Label
var _notice: Label


## Optional shield and archers dictionaries contain ratings and training
## dictionaries keyed by display label. Absent values use only recorded defaults.
func configure(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if is_node_ready():
		_refresh()


func focus_initial() -> void:
	if is_node_ready():
		_slots[SHIELD].grab_focus()


## Reopens the Shield record after confirmation, restoring a safe position if
## the one-time action was used and is no longer available.
func focus_shield_action() -> void:
	if is_node_ready():
		_nodes[SHIELD].grab_focus()
		if _can_allocate() and _action.visible:
			_action.grab_focus()


func focus_heavy_job() -> void:
	if is_node_ready():
		_nodes[HEAVY].grab_focus()


func _ready() -> void:
	name = "Human Barracks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_label("CAMPAIGN  /  HUMANS", Rect2(76, 47, 500, 26), 17, GOLD)
	_label("Barracks", Rect2(73, 75, 870, 77), 58, IVORY, &"BarracksHeading", true)
	_label("Mara’s subordinate platoons  ·  Greyhollow Mine roster", Rect2(77, 153, 850, 36), 24, MUTED)
	_back = _button("Back", Rect2(1192, 92, 172, 50), &"Back")
	_back.pressed.connect(func(): back_requested.emit())
	_build_roster()
	_build_tree()
	_build_detail()
	_refresh()
	focus_initial()


func _build_roster() -> void:
	_label("PLATOONS", Rect2(96, 220, 255, 28), 16, GOLD)
	_slots[SHIELD] = _button("01   Shield Infantry", Rect2(96, 253, 250, 46), &"SelectShieldInfantry")
	_slots[BOW] = _button("02   Archers", Rect2(96, 307, 250, 46), &"SelectArchers")
	for id: StringName in _slots:
		_slots[id].focus_entered.connect(_select_slot.bind(id))
		_slots[id].pressed.connect(_select_slot.bind(id))
	_active_title = _label("", Rect2(96, 368, 250, 28), 20, IVORY, &"SelectedPlatoon", true)
	_active_group = _label("", Rect2(96, 398, 250, 24), 16, MUTED, &"RosterRole")
	_progress = _label("", Rect2(96, 422, 250, 23), 16, SILVER, &"PlatoonProgress")
	for index in range(VIEWS.size()):
		var tab: StringName = VIEWS[index]
		var button := _button(String(tab), Rect2(96 + index * 85, 450, 80, 39), tab, 17)
		button.pressed.connect(_select_view.bind(tab))
		button.focus_entered.connect(_select_view.bind(tab))
		_tabs[tab] = button
	for index in range(8):
		_keys.append(_label("", Rect2(96, 500 + index * 23, 166, 23), 17, MUTED))
		var value := _label("", Rect2(262, 500 + index * 23, 82, 23), 17, IVORY, StringName("StatValue%d" % index))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_values.append(value)
	_field_role = _label("", Rect2(96, 501, 250, 181), 19, IVORY, &"SelectedJobReadout", false, true)


func _build_tree() -> void:
	_label("ADVANCEMENT", Rect2(854, 220, 500, 28), 16, GOLD)
	_label("Separate branches  /  Focus a crest to inspect", Rect2(854, 251, 501, 27), 19, MUTED)
	_label("01 / MELEE", Rect2(856, 293, 235, 27), 16, SILVER)
	_label("02 / RANGED", Rect2(856, 502, 235, 27), 16, SILVER)
	for id: StringName in JOBS:
		var center: Vector2 = CENTERS[id]
		var job_name: String = NAMES[id]
		var identifier := job_name.replace(" ", "")
		var button := _button("", Rect2(center - Vector2(105, 49), Vector2(210, 160)),
			StringName("Job" + identifier))
		for style in [&"normal", &"pressed", &"hover", &"focus", &"disabled", &"hover_pressed"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.tooltip_text = job_name
		button.accessibility_name = job_name
		button.focus_entered.connect(_inspect.bind(id))
		button.focus_exited.connect(queue_redraw)
		button.pressed.connect(_inspect.bind(id))
		_nodes[id] = button
		var caption := _label(job_name, Rect2(center.x - 125, center.y + 53, 250, 32), 20, IVORY, &"", true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge := _label("", Rect2(center.x - 125, center.y + 86, 250, 26), 16, MUTED,
			StringName("State" + identifier))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_states[id] = badge


func _build_detail() -> void:
	_label("JOB RECORD", Rect2(407, 220, 375, 28), 16, GOLD)
	_detail_title = _label("", Rect2(406, 257, 374, 43), 29, IVORY, &"JobDetailName", true)
	_detail_state = _label("", Rect2(407, 309, 371, 27), 17, GOLD, &"JobDetailState")
	_detail_role = _label("", Rect2(407, 351, 371, 60), 20, IVORY, &"JobDetailRole", false, true)
	_label("CURRENT / REQUIRED", Rect2(407, 418, 371, 23), 16, GOLD)
	_detail_gate = _label("", Rect2(407, 446, 371, 64), 18, IVORY, &"JobRequirements", false, true)
	_label("FIELD TRADEOFF", Rect2(407, 518, 371, 23), 16, GOLD)
	_detail_trade = _label("", Rect2(407, 543, 371, 90), 19, IVORY, &"JobTradeoff", false, true)
	_detail_scope = _label("", Rect2(407, 641, 371, 57), 17, MUTED, &"JobScope", false, true)
	_action = _button("", Rect2(407, 642, 371, 50), &"BarracksJobAction", 20)
	_action.pressed.connect(_request_action)
	_notice = _label("", Rect2(76, 707, 1288, 34), 19, Color("#fbb89b"), &"BarracksNotice")


func _select_slot(id: StringName) -> void:
	_slot = id
	_inspected = HEAVY if id == SHIELD and _heavy_selected() else id
	_refresh()


func _inspect(id: StringName) -> void:
	_inspected = id
	_slot = BOW if id in [BOW, LONGBOW] else SHIELD
	_refresh()


func _select_view(tab: StringName) -> void:
	_view = tab
	_refresh()


func _refresh() -> void:
	_update_roster()
	for id: StringName in JOBS:
		var badge := _states[id]
		badge.text = _status(id)
		badge.add_theme_color_override(&"font_color", _ink(id))
		_nodes[id].accessibility_description = badge.text
	_update_detail()
	_wire_focus()
	queue_redraw()


func _update_roster() -> void:
	var current := HEAVY if _slot == SHIELD and _heavy_selected() else _slot
	_active_title.text = NAMES[current]
	_active_group.text = "Ranged platoon" if _slot == BOW else "Frontline platoon"
	var record := _slot_record(_slot)
	var level := int(record.get("level", 1))
	if _slot == BOW and not record.has("total_xp"):
		_progress.text = "Lv %d  ·  No campaign XP tracking" % level
		_progress.tooltip_text = ""
	else:
		var points := int(record.get("remaining_melee_points", 0))
		var total := int(record.get("total_xp", 0))
		_progress.text = "Lv %d  ·  XP %d/%d  ·  %d %s" % [
			level, int(record.get("xp_in_level", 0)), int(record.get("next_level_xp", Unit.FIRST_LEVEL_XP)),
			points, "point" if points == 1 else "points",
		]
		_progress.tooltip_text = "%d total campaign XP" % total
	for id: StringName in _slots:
		_highlight(_slots[id], id == _slot)
	for tab: StringName in _tabs:
		_highlight(_tabs[tab], tab == _view)
	_field_role.visible = _view == &"Job"
	var row := 0
	if _view == &"Job":
		match current:
			SHIELD:
				_field_role.text = "Default Mine formation.\n\n%d starting proxy HP\n%.0f base contact damage\n%.2f m/s march speed" % [
					Infantry.PROTOTYPE_HP, Infantry.BASE_DAMAGE, Battle.FORMATION_SPEED]
			HEAVY:
				_field_role.text = "Chosen for this Mine replay.\n\n%d starting proxy HP\n%.2f base contact damage\n%.2f m/s march speed" % [
					Mine.HEAVY_HP, Mine.HEAVY_CONTACT_BASE, Mine.HEAVY_MOVE_SPEED]
			BOW:
				_field_role.text = "Default Mine formation.\n\n%d starting proxy HP\n%.0f base volley damage\n%.1f–%.0f m firing range" % [
					Archers.PROTOTYPE_HP, Volley.BASIC_ATTACK[Unit.Damage.RANGED], Volley.MIN_RANGE, Volley.MAX_RANGE]
	else:
		var table := RATINGS if _view == &"Ratings" else TRAINING
		for stat in table:
			var value: Variant = _rating(_slot, stat) if _view == &"Ratings" else _training(_slot, stat)
			_keys[row].text = table[stat]
			_values[row].text = _readable(value)
			row += 1
	for index in range(_keys.size()):
		_keys[index].visible = index < row
		_values[index].visible = index < row


func _update_detail() -> void:
	_detail_title.text = NAMES[_inspected]
	_detail_state.text = _status(_inspected)
	_detail_state.add_theme_color_override(&"font_color", _ink(_inspected))
	_notice.text = str(_snapshot.get("notice", ""))
	var action_text := ""
	match _inspected:
		SHIELD:
			_detail_role.text = "Advance into contact and hold the route for the miners."
			_detail_gate.text = "Standard campaign roster.\nNo advancement requirement."
			_detail_trade.text = "%d proxy HP · %.0f base contact damage\n%.2f m/s · Faster and hits harder than Heavy Infantry." % [
				Infantry.PROTOTYPE_HP, Infantry.BASE_DAMAGE, Battle.FORMATION_SPEED]
			_detail_scope.text = "Confirm Deployment fields regular Shield Infantry by default."
			if _can_allocate():
				action_text = "Allocate 1 point to Melee Power"
		HEAVY:
			_detail_role.text = "A sturdier screen for a long hold. Replaces Shield Infantry on one Mine replay."
			_detail_gate.text = "Shield Formation Drill   %d / %d\nPractice / Skirmish: Melee Power %d (separate rule)" % [
				_rank(), Drill.REQUIRED_FORMATION_DRILL,
				Catalog.TYPES[HEAVY].promotion_minimum_ratings[Unit.Damage.MELEE]]
			_detail_trade.text = "%d → %d proxy HP   ·   %.2f → %.2f m/s\n%.0f → %.2f base contact damage\nLasts longer, moves slower, hits for less." % [
				Infantry.PROTOTYPE_HP, Mine.HEAVY_HP, Battle.FORMATION_SPEED, Mine.HEAVY_MOVE_SPEED,
				Infantry.BASE_DAMAGE, Mine.HEAVY_CONTACT_BASE]
			if _heavy_selected():
				_detail_scope.text = "Chosen for this attempt only. Regular Shield Infantry remains the default."
			elif _can_choose():
				action_text = "Choose for this Mine replay"
			elif _eligible():
				_detail_scope.text = "To field this job, choose Replay with Heavy Infantry at Greyhollow’s briefing."
			elif _can_train():
				action_text = "Review Formation Drill"
			elif bool(_snapshot.get("shield_drill_credit", false)):
				_detail_scope.text = "One drill credit available. Spend it under Shield Infantry Drill in Camp Operations."
			else:
				_detail_scope.text = "Clear Get Them Out to earn one drill credit for this platoon."
		BOW:
			_detail_role.text = "Cover an open approach, ridge or retreat from behind the infantry."
			_detail_gate.text = "Standard campaign roster.\nNo advancement requirement."
			_detail_trade.text = "%.1f–%.0f m firing band · %.2f s draw\nHolds its ground when firing. Cover and melee pressure can stop a volley." % [
				Volley.MIN_RANGE, Volley.MAX_RANGE, Volley.WINDUP_SECONDS]
			_detail_scope.text = "Keep a shield screen between this platoon and a close fight."
		LONGBOW:
			var rule := _roster.advancement(BOW, LONGBOW)
			_detail_role.text = "Longer reach for a screened ridge or a long, stable firing lane."
			_detail_gate.text = "Ranged Power   %s / %d\nFormation Drill   %s / %d" % [
				_readable(_rating(BOW, Unit.Damage.RANGED)), rule.ratings[Unit.Damage.RANGED],
				_readable(_training(BOW, Platoon.Skill.FORMATION_DRILL)), rule.training[Platoon.Skill.FORMATION_DRILL]]
			_detail_trade.text = "%.0f → %.0f m maximum range\n%.2f → %.2f s draw after repositioning\nBetter reach, slower to set up." % [
				Volley.MAX_RANGE, Volley.LONGBOW_MAX_RANGE, Volley.WINDUP_SECONDS, Volley.LONGBOW_WINDUP_SECONDS]
			_detail_scope.text = "Preview only. Meeting these requirements does not make this job deployable."
	_detail_scope.visible = action_text.is_empty()
	var restore_focus := _action.has_focus() and action_text.is_empty()
	_action.text = action_text
	_action.visible = not action_text.is_empty()
	if restore_focus:
		_nodes[_inspected].grab_focus()


func _request_action() -> void:
	if _inspected == SHIELD and _can_allocate():
		melee_allocation_requested.emit()
	elif _inspected == HEAVY:
		if _can_choose() and not _heavy_selected():
			heavy_replay_requested.emit()
		elif _can_train():
			training_requested.emit()


func _rank() -> int:
	var base: int = Catalog.TYPES[SHIELD].platoon_training[Platoon.Skill.FORMATION_DRILL]
	return clampi(int(_snapshot.get("shield_drill_rank", base)), base, Drill.REQUIRED_FORMATION_DRILL)


func _qualified() -> bool:
	return _rank() >= Drill.REQUIRED_FORMATION_DRILL


func _eligible() -> bool:
	return _qualified() and bool(_snapshot.get("heavy_replay_eligible", false))


func _can_choose() -> bool:
	return _eligible() and bool(_snapshot.get("mine_replay_context", false))


func _can_allocate() -> bool:
	return bool(_slot_record(SHIELD).get("can_allocate_melee", false))


func _can_train() -> bool:
	return not _qualified() and bool(_snapshot.get("allow_training", false)) and bool(_snapshot.get("shield_drill_credit", false))


func _heavy_selected() -> bool:
	return _can_choose() and bool(_snapshot.get("heavy_selected", false))


func _rating(slot: StringName, stat: Unit.Damage) -> Variant:
	# The Mine's two subordinate CombatUnit proxies use MIN_RATING for all
	# unconfigured ratings; no value is borrowed from the lead or practice unit.
	return _stat_row(slot, "ratings").get(RATINGS[stat], Unit.MIN_RATING)


func _training(slot: StringName, stat: Platoon.Skill) -> Variant:
	if slot == SHIELD and stat == Platoon.Skill.FORMATION_DRILL:
		return _rank()
	var base: Variant = Catalog.TYPES[SHIELD].platoon_training.get(stat) if slot == SHIELD else null
	return _stat_row(slot, "training").get(TRAINING[stat], base)


func _stat_row(slot: StringName, group: String) -> Dictionary:
	return _slot_record(slot).get(group, {})


func _slot_record(slot: StringName) -> Dictionary:
	return _snapshot.get("shield" if slot == SHIELD else "archers", {})


func _readable(value: Variant) -> String:
	return "Not set" if value == null else str(value)


func _status(id: StringName) -> String:
	match id:
		SHIELD:
			return "DEFAULT LOADOUT" if _heavy_selected() else "EQUIPPED · DEFAULT"
		HEAVY:
			if _heavy_selected():
				return "EQUIPPED · THIS REPLAY"
			return "ELIGIBLE · MINE REPLAY" if _eligible() else "LOCKED"
		BOW:
			return "EQUIPPED · DEFAULT"
		LONGBOW:
			return "NOT YET FIELDABLE"
	return ""


func _ink(id: StringName) -> Color:
	match id:
		SHIELD:
			return GOLD if not _heavy_selected() else SILVER
		HEAVY:
			return GOLD if _heavy_selected() else (GREEN if _eligible() else FADED)
		BOW:
			return GOLD
		LONGBOW:
			return SILVER
	return MUTED


func _wire_focus() -> void:
	var left := _slots[_slot]
	var shield_action := _action.visible and _inspected == SHIELD
	_link(_back, _back, _back, _nodes[_inspected], _nodes[_inspected])
	_link(_slots[SHIELD], _slots[SHIELD], _action if shield_action else _nodes[SHIELD], _back, _slots[BOW])
	_link(_slots[BOW], _slots[BOW], _nodes[BOW], _slots[SHIELD], _tabs[_view])
	_link(_tabs[&"Ratings"], _tabs[&"Ratings"], _tabs[&"Training"], left, _tabs[&"Ratings"])
	_link(_tabs[&"Training"], _tabs[&"Ratings"], _tabs[&"Job"], left, _tabs[&"Training"])
	_link(_tabs[&"Job"], _tabs[&"Training"], _nodes[_inspected], left, _tabs[&"Job"])
	_link(_nodes[SHIELD], _action if shield_action else _slots[SHIELD], _nodes[HEAVY], _back, _nodes[BOW])
	_link(_nodes[BOW], _slots[BOW], _nodes[LONGBOW], _nodes[SHIELD], _nodes[BOW])
	_link(_nodes[HEAVY], _nodes[SHIELD], _action if _action.visible else _back, _back, _nodes[LONGBOW])
	_link(_nodes[LONGBOW], _nodes[BOW], _back, _nodes[HEAVY], _nodes[LONGBOW])
	_link(_action, _slots[SHIELD], _nodes[_inspected], _back, _action)
	var order: Array[Button] = [
		_slots[SHIELD], _slots[BOW], _tabs[&"Ratings"], _tabs[&"Training"], _tabs[&"Job"],
		_nodes[SHIELD], _nodes[HEAVY], _nodes[BOW], _nodes[LONGBOW], _back,
	]
	if _action.visible:
		order.insert(order.size() - 1, _action)
	for index in range(order.size()):
		var control := order[index]
		control.focus_next = control.get_path_to(order[(index + 1) % order.size()])
		control.focus_previous = control.get_path_to(order[posmod(index - 1, order.size())])


func _link(control: Control, left: Control, right: Control, up: Control, down: Control) -> void:
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)
	control.focus_neighbor_top = control.get_path_to(up)
	control.focus_neighbor_bottom = control.get_path_to(down)


func _label(body: String, rect: Rect2, pixels: int, ink: Color, node_name: StringName = &"",
		display := false, wrap := false) -> Label:
	var label := Label.new()
	if node_name != &"":
		label.name = node_name
	label.text = body
	label.add_theme_font_override(&"font", DISPLAY if display else BODY)
	label.add_theme_font_size_override(&"font_size", pixels)
	label.add_theme_color_override(&"font_color", ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _button(body: String, rect: Rect2, node_name: StringName, pixels := 22) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = body
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override(&"font", BODY)
	button.add_theme_font_size_override(&"font_size", pixels)
	button.add_theme_color_override(&"font_color", IVORY)
	button.add_theme_color_override(&"font_focus_color", IVORY)
	button.add_theme_color_override(&"font_hover_color", IVORY)
	button.add_theme_stylebox_override(&"normal", _box(INSET, HAIRLINE))
	button.add_theme_stylebox_override(&"hover", _box(Color("#282e2b"), GOLD))
	button.add_theme_stylebox_override(&"pressed", _box(Color("#3a3024"), GOLD))
	button.add_theme_stylebox_override(&"focus", _box(Color.TRANSPARENT, IVORY, 2))
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button


func _box(fill: Color, outline: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(width)
	return style


func _highlight(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override(&"normal", _box(Color("#2f2820") if selected else INSET, GOLD if selected else HAIRLINE))


func _draw() -> void:
	_panel(Rect2(76, 205, 290, 497), PANEL)
	_panel(Rect2(834, 205, 530, 497), BOARD)
	_panel(Rect2(387, 205, 417, 497), PANEL)
	draw_line(Vector2(96, 361), Vector2(346, 361), HAIRLINE)
	draw_line(Vector2(854, 487), Vector2(1344, 487), HAIRLINE)
	draw_line(Vector2(407, 344), Vector2(783, 344), HAIRLINE)
	draw_line(Vector2(407, 514), Vector2(783, 514), HAIRLINE)
	_draw_path(SHIELD, HEAVY, _eligible())
	_draw_path(BOW, LONGBOW, false)
	for id: StringName in JOBS:
		_crest(id)


func _panel(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, HAIRLINE, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(58, 0), GOLD, 2.0)


func _draw_path(source: StringName, target: StringName, eligible: bool) -> void:
	var a: Vector2 = CENTERS[source] + Vector2(47, 0)
	var b: Vector2 = CENTERS[target] - Vector2(47, 0)
	var ink := GREEN if eligible else HAIRLINE
	if eligible:
		draw_line(a, b, ink, 1.5, true)
	else:
		draw_dashed_line(a, b, ink, 1.5, 8.0, true, true)
	draw_colored_polygon(_diamond((a + b) * 0.5, 5.0), ink)
	draw_polyline(PackedVector2Array([b + Vector2(-8, -6), b, b + Vector2(-8, 6)]), ink, 1.5, true)


func _crest(id: StringName) -> void:
	var c: Vector2 = CENTERS[id]
	var ink := _ink(id)
	var focused := _nodes.has(id) and _nodes[id].has_focus()
	var inspected := id == _inspected
	var points := _diamond(c, 45.0)
	draw_colored_polygon(_diamond(c + Vector2(0, 5), 49.0), Color(0.019, 0.024, 0.024, 0.78))
	draw_colored_polygon(points, Color("#302b22") if inspected else INSET)
	draw_polyline(_closed(points), ink, 2.0, true)
	draw_polyline(_closed(_diamond(c, 36.0)), ink.darkened(0.54), 1.0, true)
	if focused:
		draw_polyline(_closed(_diamond(c, 53.0)), IVORY, 2.0, true)
	elif inspected:
		draw_polyline(_closed(_diamond(c, 51.0)), GOLD.darkened(0.32), 1.0, true)
	if id in [SHIELD, HEAVY]:
		var shield := PackedVector2Array([
			c + Vector2(-11, -13), c + Vector2(11, -13), c + Vector2(11, 3),
			c + Vector2(0, 14), c + Vector2(-11, 3),
		])
		draw_polyline(_closed(shield), ink, 2.0, true)
		draw_line(c + Vector2(0, -12), c + Vector2(0, 10), ink, 2.0, true)
		if id == HEAVY:
			draw_line(c + Vector2(-9, -2), c + Vector2(9, -2), ink, 2.0, true)
	else:
		draw_arc(c + Vector2(-8, 0), 15.0, -PI / 3.0, PI / 3.0, 17, ink, 2.0, true)
		draw_line(c + Vector2(-1, -13), c + Vector2(-1, 13), ink, 1.5, true)
		draw_line(c + Vector2(-14, 0), c + Vector2(16, 0), ink, 2.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(11, -4), c + Vector2(16, 0), c + Vector2(11, 4)]), ink, 2.0, true)


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2.UP * radius, center + Vector2.RIGHT * radius,
		center + Vector2.DOWN * radius, center + Vector2.LEFT * radius,
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var copy := points.duplicate()
	copy.append(points[0])
	return copy
