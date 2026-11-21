extends Control

const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Ice := preload("res://game/combat/targeted_ice_cast.gd")
const DISPLAY_FACE := preload("res://assets/fonts/Cinzel.ttf")
const IVORY := Color("#f4e8d5")
const GOLD := Color("#d9ad70")
const MUTED := Color("#b5afa2")
const POSITIVE := Color("#a4c69d")
const WARNING := Color("#fbb89b")
const HAIRLINE := Color("#716451")
const TEAM := 0
const LEAD_PLATOON := 0
const PRACTICE_PLATOON := 2
const UNTRAINED_CASTER := 0
const TRAINED_CASTER := Battle.PLATOON_SIZE
const WOUNDED_ALLY := Battle.PLATOON_SIZE + 1
const ICE_TARGET := Battle.PLATOON_SIZE * PRACTICE_PLATOON
const PRACTICE_RANGE := 10.0
const PRACTICE_CHARGE_AWARD := 100 # Drill only; this is not an encounter award rate.

var _battle: Battle
var _caster_index := UNTRAINED_CASTER
var _balance: Label
var _pool_bar: ProgressBar
var _holy_check: Label
var _bp_check: Label
var _target_hp: Label
var _status: Label
var _feedback: Label
var _untrained: Button
var _trained: Button
var _cast: Button
var _spell_title: Label
var _mode: Button
var _lane: Button
var _ice: Ice
var _ice_mode := false
var _lane_open := true


func initialize(back: Button) -> void:
	name = "BattlePointsDrill"
	position = Vector2(76, 225)
	size = Vector2(1288, 474)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	theme = Theme.new()
	theme.default_font = back.get_theme_font("font", "Button")
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(key, "Button", back.get_theme_stylebox(key, "Button"))
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
		theme.set_color(key, "Button", back.get_theme_color(key, "Button"))

	_panel(Rect2(0, 0, 438, 474))
	_panel(Rect2(464, 0, 824, 474))
	_label("01   EARN", Rect2(28, 18, 382, 28), 18, GOLD)
	_label("Shared Team Pool", Rect2(28, 49, 382, 48), 28, IVORY, DISPLAY_FACE)
	_balance = _label("", Rect2(28, 106, 382, 52), 40, GOLD)
	_balance.name = "PoolBalance"
	_pool_bar = ProgressBar.new()
	_pool_bar.show_percentage = false
	_pool_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool_bar.add_theme_stylebox_override("background", _bar_box(Color("#32312b")))
	_pool_bar.add_theme_stylebox_override("fill", _bar_box(GOLD))
	add_child(_pool_bar)
	_pool_bar.position = Vector2(28, 171)
	_pool_bar.size = Vector2(382, 8)
	_label("Level 1 lead platoon sets the cap.", Rect2(28, 189, 382, 32), 22, MUTED)
	_label("Practice charge: +%d BP (drill only)" % PRACTICE_CHARGE_AWARD,
		Rect2(28, 233, 382, 34), 22, IVORY)
	var earn := _button("PracticeCharge", "Land Practice Charge", Rect2(28, 275, 382, 52), _charge)
	var reset := _button("ResetBattlePoints", "Reset Drill", Rect2(28, 398, 382, 48), _reset)

	_label("02   SPEND", Rect2(492, 18, 768, 28), 18, GOLD)
	_spell_title = _label("Field Benediction", Rect2(492, 49, 480, 48), 28, IVORY, DISPLAY_FACE)
	_mode = _button("PracticeSpell", "Try Ice Cast", Rect2(966, 49, 294, 48), _toggle_spell)
	_untrained = _button("UntrainedCaster", "Untrained Caster", Rect2(492, 112, 376, 46),
		_select_caster.bind(UNTRAINED_CASTER))
	_trained = _button("TrainedCaster", "Trained Caster", Rect2(884, 112, 376, 46),
		_select_caster.bind(TRAINED_CASTER))
	_untrained.toggle_mode = true
	_trained.toggle_mode = true
	_holy_check = _label("", Rect2(492, 179, 376, 42), 23, IVORY)
	_holy_check.name = "HolyCheck"
	_bp_check = _label("", Rect2(884, 179, 376, 42), 23, IVORY)
	_bp_check.name = "BattlePointsCheck"
	_target_hp = _label("", Rect2(492, 229, 768, 40), 23, IVORY)
	_target_hp.name = "WoundedAllyHP"
	_cast = _button("CastBenediction", "Cast Field Benediction", Rect2(492, 275, 376, 52), _cast_current)
	_lane = _button("SimulatedLane", "Lane: Clear", Rect2(884, 275, 376, 52), _toggle_lane)
	_status = _label("", Rect2(492, 335, 768, 34), 22, IVORY)
	_status.name = "BenedictionStatus"
	_feedback = _label("", Rect2(492, 391, 768, 55), 23, GOLD)
	_feedback.name = "DrillFeedback"

	_set_focus(back, earn, reset)
	_reset()
	earn.grab_focus()


func _set_focus(back: Button, earn: Button, reset: Button) -> void:
	_link(back, SIDE_BOTTOM, earn)
	_link(earn, SIDE_TOP, back)
	_link(earn, SIDE_RIGHT, _untrained)
	_link(earn, SIDE_BOTTOM, reset)
	_link(reset, SIDE_TOP, earn)
	_link(reset, SIDE_RIGHT, _cast)
	_link(_untrained, SIDE_LEFT, earn)
	_link(_untrained, SIDE_RIGHT, _trained)
	_link(_trained, SIDE_LEFT, _untrained)
	_link(_trained, SIDE_RIGHT, _mode)
	_link(_mode, SIDE_LEFT, _trained)
	_link(_mode, SIDE_TOP, back)
	_link(_mode, SIDE_BOTTOM, _trained)
	_link(_lane, SIDE_LEFT, _cast)
	_link(_lane, SIDE_TOP, _trained)
	for button in [_untrained, _trained]:
		_link(button, SIDE_TOP, back)
		_link(button, SIDE_BOTTOM, _cast)
	_link(_cast, SIDE_LEFT, reset)
	_link(_cast, SIDE_TOP, _untrained)
	var order: Array[Button] = [back, earn, _untrained, _trained, _mode, _cast, reset]
	for index in range(order.size()):
		var button := order[index]
		button.focus_next = button.get_path_to(order[(index + 1) % order.size()])
		button.focus_previous = button.get_path_to(order[posmod(index - 1, order.size())])


func _reset() -> void:
	var setup := Setup.new()
	setup.set_count(TEAM, 2)
	var support: Setup.PlatoonBuild = setup.sides[TEAM][1]
	var requirement := Battle.FIELD_BENEDICTION_HOLY_RATING
	support.level = requirement + Ice.ICE_RATING - Unit.MIN_RATING
	support.set_points(Unit.Damage.HOLY, requirement - Unit.MIN_RATING)
	support.set_points(Unit.Damage.ICE, Ice.ICE_RATING - Unit.MIN_RATING)
	_battle = Battle.new(8, setup)
	_ice = Ice.new(_battle.battle_points_for_team(TEAM))
	_ice_mode = false
	_lane_open = true
	set_process(false)
	var ally := _battle.soldiers[WOUNDED_ALLY].unit
	ally.receive_damage(ally.max_hp * 0.8)
	_caster_index = UNTRAINED_CASTER
	_feedback.text = "The lead platoon earns BP. The support platoon can spend it."
	_refresh()


func _charge() -> void:
	var pool := _battle.battle_points_for_team(TEAM)
	var before := pool.balance
	var loss := _battle.resolve_platoon_charge(LEAD_PLATOON, PRACTICE_PLATOON, false, PRACTICE_CHARGE_AWARD)
	# The training target reforms between attempts; no free points are awarded on reset.
	_battle.platoons[PRACTICE_PLATOON].reform(60.0)
	if loss <= 0.0:
		_feedback.text = "No confirmed charge. No BP gained."
	elif pool.balance == before:
		_feedback.text = "Charge landed. The team pool is already full."
	else:
		_feedback.text = "Charge landed. The team gained %d BP." % (pool.balance - before)
	_refresh()


func _select_caster(index: int) -> void:
	_caster_index = index
	_feedback.text = "Casting with the lead platoon." if index == UNTRAINED_CASTER else "Casting with the support platoon."
	_refresh()


func _toggle_spell() -> void:
	if _ice.phase == Ice.Phase.WINDUP:
		_ice.advance(0.0, PRACTICE_RANGE, _lane_open, true)
		set_process(false)
		_feedback.text = "Practice cast interrupted. Committed BP were not refunded."
	else:
		_feedback.text = "Both practice spells draw from the same team pool."
	_ice_mode = not _ice_mode
	_refresh()


func _toggle_lane() -> void:
	_lane_open = not _lane_open
	_refresh()


func _cast_current() -> void:
	if not _ice_mode:
		_cast_benediction()
		return
	if _ice.phase == Ice.Phase.WINDUP:
		return
	var status := _ice_status()
	_ice.reset_after_terminal()
	var caster := _battle.soldiers[_caster_index].unit
	var target := _battle.soldiers[ICE_TARGET].unit
	if _ice.begin(caster, target, PRACTICE_RANGE, _lane_open):
		_feedback.text = "Ice cast winding up. Cover the lane to interrupt it."
		set_process(true)
	else:
		_feedback.text = "Cast blocked: %s. No BP spent." % status
	_refresh()


func _process(delta: float) -> void:
	var phase := _ice.advance(delta, PRACTICE_RANGE, _lane_open)
	if phase == Ice.Phase.WINDUP:
		return
	set_process(false)
	if phase == Ice.Phase.RELEASED:
		_feedback.text = "Ice hit for %.1f HP. No BP awarded." % _ice.damage_done
	else:
		_feedback.text = "Practice cast interrupted. Committed BP were not refunded."
	_refresh()


func _ice_status() -> String:
	if _ice.phase == Ice.Phase.WINDUP:
		return "winding up"
	if _battle.soldiers[_caster_index].unit.rating(Unit.Damage.ICE) < Ice.ICE_RATING:
		return "Ice rating too low"
	if not _battle.battle_points_for_team(TEAM).can_afford(Ice.COST):
		return "not enough BP"
	if not _battle.soldiers[ICE_TARGET].unit.is_alive():
		return "target defeated"
	if not _lane_open:
		return "lane is covered"
	return "ready"


func _cast_benediction() -> void:
	var status := _battle.field_benediction_status(TEAM, _caster_index, WOUNDED_ALLY)
	var restored := _battle.cast_field_benediction(TEAM, _caster_index, WOUNDED_ALLY)
	if restored > 0.0:
		_feedback.text = "Restored %.1f HP. The team spent %d BP." % [restored, Battle.FIELD_BENEDICTION_BP_COST]
	else:
		_feedback.text = "Cast blocked: %s. No BP spent." % _status_text(status)
	_refresh()


func _refresh() -> void:
	var pool := _battle.battle_points_for_team(TEAM)
	_balance.text = "%d / %d BP" % [pool.balance, pool.capacity]
	_pool_bar.max_value = pool.capacity
	_pool_bar.value = pool.balance
	var discipline := Unit.Damage.ICE if _ice_mode else Unit.Damage.HOLY
	var rating := _battle.soldiers[_caster_index].unit.rating(discipline)
	var requirement := Ice.ICE_RATING if _ice_mode else Battle.FIELD_BENEDICTION_HOLY_RATING
	var cost := Ice.COST if _ice_mode else Battle.FIELD_BENEDICTION_BP_COST
	var name_of_stat := "Ice" if _ice_mode else "Holy"
	_holy_check.text = "%s rating   %d / %d needed" % [name_of_stat, rating, requirement]
	_holy_check.add_theme_color_override("font_color", POSITIVE if rating >= requirement else WARNING)
	_bp_check.text = "Shared BP   %d / %d needed" % [pool.balance, cost]
	_bp_check.add_theme_color_override("font_color", POSITIVE if pool.can_afford(cost) else WARNING)
	var target := _battle.soldiers[ICE_TARGET if _ice_mode else WOUNDED_ALLY].unit
	_target_hp.text = "%s HP   %.1f / %.1f" % ["Target" if _ice_mode else "Ally", target.hp, target.max_hp]
	_untrained.set_pressed_no_signal(_caster_index == UNTRAINED_CASTER)
	_trained.set_pressed_no_signal(_caster_index == TRAINED_CASTER)
	_link(_cast, SIDE_TOP, _untrained if _caster_index == UNTRAINED_CASTER else _trained)
	_spell_title.text = "Targeted Ice Cast" if _ice_mode else "Field Benediction"
	_mode.text = "Try Benediction" if _ice_mode else "Try Ice Cast"
	_cast.text = "Cast Ice" if _ice_mode else "Cast Field Benediction"
	_lane.visible = _ice_mode
	_lane.text = "Lane: Clear" if _lane_open else "Lane: Covered"
	_cast.focus_neighbor_right = _cast.get_path_to(_lane) if _ice_mode else NodePath()
	var status := _ice_status() if _ice_mode else _status_text(_battle.field_benediction_status(TEAM, _caster_index, WOUNDED_ALLY))
	_status.text = "Cast status: %s" % status
	_status.add_theme_color_override("font_color", POSITIVE if status == "ready" else WARNING)


func _status_text(status: Battle.AbilityStatus) -> String:
	match status:
		Battle.AbilityStatus.READY:
			return "ready"
		Battle.AbilityStatus.STAT_REQUIREMENT:
			return "Holy rating too low"
		Battle.AbilityStatus.INSUFFICIENT_BP:
			return "not enough BP"
		Battle.AbilityStatus.UNHURT_TARGET:
			return "ally is already at full HP"
		_:
			return "order unavailable"


func _button(id: String, caption: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 23)
	button.pressed.connect(action)
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button


func _label(caption: String, rect: Rect2, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _panel(rect: Rect2) -> void:
	for layer in range(2):
		var shape := ColorRect.new()
		shape.color = Color(0.047, 0.054, 0.055, 0.91) if layer == 0 else HAIRLINE
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shape)
		shape.position = rect.position
		shape.size = rect.size if layer == 0 else Vector2(rect.size.x, 1)


func _bar_box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


func _link(from: Button, side: Side, to: Button) -> void:
	from.set_focus_neighbor(side, from.get_path_to(to))
