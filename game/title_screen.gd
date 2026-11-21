extends Control

const Campaigns := preload("res://game/campaigns.gd")
const CampaignMissions := preload("res://game/campaign_missions.gd")
const CampaignDeployments := preload("res://game/campaign_deployments.gd")
const CampaignWorld := preload("res://game/campaign_world.gd")
const CampaignMap := preload("res://game/campaign_map.gd")
const CampaignDialogue := preload("res://game/campaign_dialogue.gd")
const DialogueBeats := preload("res://game/campaign_dialogues.gd")
const MaraMine := preload("res://game/battlefield/mara_mine_escort.gd")
const LeadProgress := preload("res://game/combat/campaign_platoon_progress.gd")
const MaraTraining := preload("res://game/combat/mara_subordinate_training.gd")
const SurveyBattle := preload("res://game/battlefield/ilyra_coast_survey_campaign.gd")
const CAMPAIGN_MAP_SCENE := preload("res://game/campaign_map.tscn")
const CAMPAIGN_DIALOGUE_SCENE := preload("res://game/campaign_dialogue.tscn")
const CAMPAIGN_PLAYTEST_NOTICE := "Development playtest: includes placeholder art."
const WAR_YEARS := ["", "Year One", "Year Two", "Year Three", "Year Four", "Year Five"]
const ProfileStore := preload("res://game/profile_store.gd")
const Embers := preload("res://game/embers.gd")
const Drills := preload("res://game/combat/drills.gd")
const BattlePointsDrill := preload("res://game/combat/battle_points_drill.gd")
const Platoon := preload("res://game/combat/platoon.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const UnitCatalog := preload("res://game/combat/unit_catalog.gd")
const FactionRoster := preload("res://game/combat/faction_roster.gd")
const SkirmishView := preload("res://game/combat/infantry_skirmish_view.gd")
const Skirmish := preload("res://game/combat/infantry_skirmish.gd")
const SkirmishSetup := preload("res://game/combat/skirmish_setup.gd")
const SkirmishSetupMenu := preload("res://game/skirmish_setup_menu.gd")
const SKIRMISH_SCENE := preload("res://game/combat/infantry_skirmish_view.tscn")
const UNIT_STUDIO_SCENE := preload("res://game/combat/unit_model_studio.tscn")
const TITLE_ART := preload("res://assets/art/title.webp")
const VAULT_ART := preload("res://assets/art/vault.webp")
const DISPLAY_FACE := preload("res://assets/fonts/Cinzel.ttf")
const UI_FACE := preload("res://assets/fonts/SourceSans3.ttf")

const GOLD := Color("#d9ad70")
const IVORY := Color("#f4e8d5")
const MUTED := Color("#b5afa2")
const HAIRLINE := Color("#716451")
const DARK := Color("#171a1a")

enum Page {
	TITLE, VAULT, LOAD, SETTINGS, QUIT, BRIEFING, DRILLS, UNIT_PROGRESSION, UNIT_MODEL,
	UNIT_TEST, SKIRMISH_SETUP, SKIRMISH, BATTLE_POINTS_DRILL,
	WORLD_MAP, CAMPAIGN_DIALOGUE, MISSION_BRIEFING, CAMPAIGN_BATTLE, ROSTER_REQUIREMENTS, MARA_SHIELD_DRILL,
	MARA_LEAD_MELEE,
}

const MARA_LEAD_MELEE_ENTRY := "Lead Melee Training"
const RATING_NAMES := {
	Unit.Damage.MELEE: "Melee Power",
	Unit.Damage.RANGED: "Ranged Power",
	Unit.Damage.FIRE: "Fire",
	Unit.Damage.LIGHTNING: "Lightning",
	Unit.Damage.ICE: "Ice",
	Unit.Damage.NATURE: "Nature",
	Unit.Damage.HOLY: "Holy",
	Unit.Damage.CURSE: "Curse",
}

const PRACTICE_ROSTERS := {
	"mara": [FactionRoster.HUMANS, UnitCatalog.HUMAN_ARCHER],
	"raska": [FactionRoster.ORCS, UnitCatalog.ORC_BASIN_REGULARS],
	"ilyra": [FactionRoster.ELVES, UnitCatalog.ELF_SHORE_DETACHMENT],
	"sova": [FactionRoster.DRUIDS, UnitCatalog.DRUID_TUNNEL_GUARD],
	"neris": [FactionRoster.DRYADS, UnitCatalog.DRYAD_LOADING_GUARD],
	"sereth": [FactionRoster.UNDEAD, UnitCatalog.UNDEAD_HOUSEHOLD_GUARD],
}

const TRAINING_NAMES := {
	Platoon.Skill.CHARGE_BRACE: "Charge & Brace",
	Platoon.Skill.MOUNTED_TRAINING: "Mounted Training",
	Platoon.Skill.FORMATION_DRILL: "Formation Drill",
	Platoon.Skill.SCOUTING: "Scouting",
	Platoon.Skill.SIEGECRAFT: "Siegecraft",
	Platoon.Skill.BEAST_HANDLING: "Beast Handling",
}


var _profile := ProfileStore.new()
var _body_face := FontVariation.new()
var _page: Page
var _stage: Control
var _hint: Label
var _notice: Label
var _using_controller := false
var _selected := 0
var _portraits: Array[Button] = []
var _selection_title: Label
var _selection_region: Label
var _selection_summary: Label
var _active_campaign: Dictionary
var _campaign_world: CampaignWorld
var _campaign_warning := ""
var _campaign_battle: Node3D
var _victory_pending := false
var _drill_index := 0
var _drill_rank := Platoon.MAX_RANK
var _drill_buttons: Array[Button] = []
var _drill_title: Label
var _drill_description: Label
var _drill_rank_label: Label
var _drill_baseline_heading: Label
var _drill_rank_heading: Label
var _drill_lower_rank: Button
var _drill_metrics: Array[Label] = []
var _drill_baseline: Array[Label] = []
var _drill_results: Array[Label] = []
var _training_unit: CombatUnit
var _training_unit_id: StringName
var _training_base_hit: float
var _training_level: Label
var _training_stats: Label
var _training_award: Button
var _training_inspect: Button
var _training_planner: Button
var _training_promotion: Button
var _training_promotion_status: Label
var _training_buttons: Dictionary[Unit.Damage, Button] = {}
var _skirmish_setup := SkirmishSetup.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_face.base_font = UI_FACE
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	_body_face.variation_opentype = {weight_axis: 465}
	_map_controller_button("ui_accept", JOY_BUTTON_A)
	_map_controller_button("ui_cancel", JOY_BUTTON_B)
	_apply_fullscreen()
	_show_title()


func _map_controller_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _input(event: InputEvent) -> void:
	if _page == Page.WORLD_MAP or _page == Page.CAMPAIGN_DIALOGUE:
		return # These scenes own navigation, including Back.
	if _page == Page.CAMPAIGN_BATTLE:
		var key_back := event is InputEventKey and event.is_action_pressed("ui_cancel")
		var pad_back: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
		# Circle belongs to the hero's dodge; keyboard Escape and controller Create return.
		if key_back or pad_back:
			get_viewport().set_input_as_handled()
			_return_from_campaign_battle()
		return
	var controller_button := event is InputEventJoypadButton and event.is_pressed()
	var controller_stick: bool = event is InputEventJoypadMotion and absf(event.axis_value) > 0.65
	if controller_button or controller_stick:
		_using_controller = true
		_update_hint()
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_using_controller = false
		_update_hint()

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _page == Page.UNIT_TEST or _page == Page.SKIRMISH_SETUP:
			for option in _stage.find_children("*", "OptionButton", true, false):
				var popup := (option as OptionButton).get_popup()
				if popup.visible:
					popup.hide()
					return
		_go_back()


func _go_back() -> void:
	match _page:
		Page.TITLE:
			_show_quit()
		Page.BRIEFING:
			if _campaign_world:
				_show_world_map()
			else:
				_show_title()
		Page.MISSION_BRIEFING:
			_show_world_map()
		Page.DRILLS:
			_show_briefing()
		Page.UNIT_PROGRESSION:
			_show_briefing()
			_stage.get_node("Unit Progression").grab_focus()
		Page.MARA_SHIELD_DRILL:
			_show_briefing()
			var drill := _stage.get_node_or_null("Shield Infantry Drill") as Button
			if drill:
				drill.grab_focus()
		Page.MARA_LEAD_MELEE:
			_show_briefing()
			var lead := _stage.get_node_or_null(MARA_LEAD_MELEE_ENTRY) as Button
			if lead:
				lead.grab_focus()
		Page.ROSTER_REQUIREMENTS:
			_show_unit_progression(true)
			_training_planner.grab_focus()
		Page.BATTLE_POINTS_DRILL:
			_show_drills()
			_stage.get_node("Battle Points Drill").grab_focus()
		Page.UNIT_MODEL:
			_show_unit_progression(true)
			_training_inspect.grab_focus()
		Page.SKIRMISH:
			_show_skirmish_setup()
		Page.SKIRMISH_SETUP:
			_show_unit_test()
			_stage.get_node("AI Skirmish").grab_focus()
		_:
			_show_title()


func _show_title() -> void:
	_open_page(Page.TITLE)
	_label(_stage, "TORN", Rect2(86, 111, 520, 112), 103, IVORY, DISPLAY_FACE)
	_label(_stage, "ASUNDER", Rect2(89, 204, 540, 96), 75, GOLD, DISPLAY_FACE)
	_rule(Rect2(94, 328, 352, 1), HAIRLINE)
	_color_rect(_stage, Rect2(94, 327, 47, 2), GOLD)

	var saves := _profile.saved_campaigns(Campaigns.ALL)
	var actions: Array[Button] = []
	var new_game := _button("New Game", Rect2(94, 359, 352, 52), _show_vault.bind(0))
	actions.append(new_game)
	var resume := _button("Continue", Rect2(94, 420, 352, 52))
	if saves.is_empty():
		resume.disabled = true
	else:
		resume.pressed.connect(_open_campaign.bind(saves[0]))
		actions.append(resume)
	actions.append(_button("Load", Rect2(94, 481, 352, 52), _show_load))
	actions.append(_button("Settings", Rect2(94, 542, 352, 52), _show_settings))
	actions.append(_button("Unit Test", Rect2(94, 603, 352, 52), _show_unit_test))
	actions.append(_button("Quit", Rect2(94, 664, 352, 52), _show_quit))
	_link_cycle(actions, SIDE_TOP, SIDE_BOTTOM)
	new_game.grab_focus()


func _show_vault(initial_index: int) -> void:
	_open_page(Page.VAULT)
	var back := _heading("Campaign Vault", CAMPAIGN_PLAYTEST_NOTICE + " Choose a leader to begin.")
	_portraits.clear()
	for index in range(Campaigns.ALL.size()):
		var campaign := Campaigns.ALL[index]
		var card := _portrait(campaign, Rect2(76 + index * 217, 224, 203, 292))
		card.focus_entered.connect(_select_portrait.bind(index))
		card.pressed.connect(_open_campaign.bind(campaign))
		_portraits.append(card)

	_rule(Rect2(76, 547, 1288, 1), HAIRLINE)
	_selection_region = _label(_stage, "", Rect2(76, 565, 920, 26), 19, GOLD)
	_selection_title = _label(_stage, "", Rect2(76, 594, 960, 41), 31, IVORY, DISPLAY_FACE)
	_selection_summary = _label(_stage, "", Rect2(76, 642, 900, 69), 22, MUTED)
	_selection_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var begin := _button("Begin Campaign", Rect2(1090, 611, 274, 57), _begin_selected)
	_link_cycle(_portraits, SIDE_LEFT, SIDE_RIGHT)
	for card in _portraits:
		_link_focus(card, SIDE_TOP, back)
		_link_focus(card, SIDE_BOTTOM, begin)
	_link_focus(back, SIDE_BOTTOM, _portraits[initial_index])
	_link_focus(begin, SIDE_TOP, _portraits[initial_index])
	_select_portrait(initial_index)
	_portraits[initial_index].grab_focus()


func _select_portrait(index: int) -> void:
	_selected = index
	for i in range(_portraits.size()):
		var color: Color = GOLD if i == index else HAIRLINE
		_portraits[i].add_theme_stylebox_override("normal", _box(DARK, color))
	var campaign := Campaigns.ALL[index]
	_selection_region.text = "%s  /  %s" % [campaign.faction.to_upper(), campaign.region.to_upper()]
	_selection_region.add_theme_color_override("font_color", campaign.accent)
	_selection_title.text = "%s %s" % [campaign.title, campaign.name]
	_selection_summary.text = campaign.briefing
	for button_name in ["Begin Campaign", "Back"]:
		var button := _stage.get_node_or_null(button_name) as Button
		if button:
			_link_focus(button, SIDE_TOP if button_name == "Begin Campaign" else SIDE_BOTTOM, _portraits[index])


func _begin_selected() -> void:
	_open_campaign(Campaigns.ALL[_selected])


func _open_campaign(campaign: Dictionary) -> void:
	_active_campaign = campaign
	var result := _profile.mark_played(campaign.id)
	_campaign_world = null
	_campaign_warning = "" if result == OK else "The campaign selection could not be saved."
	if not CampaignDeployments.opening_for_campaign(campaign.id).is_empty():
		_campaign_world = _profile.load_campaign_world(campaign.id)
		if not _show_waypoint_intermission():
			_show_world_map()
	else:
		_show_briefing()
		_show_campaign_warning()


func _show_world_map() -> void:
	_replace_stage(Page.WORLD_MAP)
	var map: CampaignMap = CAMPAIGN_MAP_SCENE.instantiate()
	map.configure(_campaign_world, _profile.completed_missions(_active_campaign.id), _profile.setting("reduced_motion"))
	map.return_requested.connect(_show_title)
	map.camp_operations_requested.connect(_show_briefing)
	map.waypoint_arrived.connect(_on_waypoint_arrived)
	map.briefing_requested.connect(_show_campaign_mission_briefing)
	_stage.add_child(map)
	_show_campaign_warning()


func _on_waypoint_arrived(_id: String) -> void:
	if _profile.record_world_waypoint(_campaign_world) != OK:
		_campaign_warning = "The arrived waypoint could not be saved."
	if not _show_waypoint_intermission(false) and _campaign_world.mission_at_current_waypoint().is_empty():
		_show_campaign_warning()


func _show_waypoint_intermission(include_victory_coda := true) -> bool:
	var campaign_id := _campaign_world.campaign_id()
	var beat := CampaignDeployments.intermission_at(campaign_id, _campaign_world.current_waypoint_id())
	if beat == &"" and include_victory_coda:
		var mission_id := _campaign_world.mission_at_current_waypoint()
		if _profile.completed_missions(campaign_id).has(mission_id):
			beat = CampaignDeployments.for_mission(mission_id).get("victory_coda", &"")
	if beat == &"" or _profile.has_seen_intermission(campaign_id, beat):
		return false
	_present_campaign_dialogue(beat, _finish_waypoint_intermission.bind(campaign_id, beat))
	return true


func _finish_waypoint_intermission(campaign_id: String, beat: StringName) -> void:
	if _profile.record_intermission_seen(campaign_id, beat) != OK:
		_campaign_warning = "The intermission could not be marked as read."
	_show_world_map()


func _show_campaign_mission_briefing(mission_id: String) -> void:
	var deployment := CampaignDeployments.for_mission(mission_id)
	var mission := CampaignMissions.mission_for_campaign(_active_campaign.id, mission_id)
	if deployment.is_empty() or mission.is_empty():
		return
	_open_page(Page.MISSION_BRIEFING)
	var back := _heading("Battlefield Briefing", "%s  /  %s" % [mission.title, WAR_YEARS[mission.year]])
	_label(_stage, deployment.get("battlefield_label", "THE MINE · MARCHES BORDER"),
		Rect2(76, 248, 1120, 44), 25, GOLD)
	var orders := _label(_stage, deployment.orders, Rect2(76, 318, 1000, 120), 29, IVORY)
	orders.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var can_replay_heavy := _mine_replay_heavy_available(_active_campaign.id, mission_id, _profile.completed_missions(_active_campaign.id))
	var roster_notice := " Optional replay loadout." if can_replay_heavy else " Fixed test roster."
	_label(_stage, CAMPAIGN_PLAYTEST_NOTICE + roster_notice, Rect2(76, 475, 1080, 32), 21, MUTED)
	var deploy_y := 555.0
	if _active_campaign.id == "mara" and mission_id == "mara_mine_escort":
		# The full orders initially expand the label before wrapping is enabled.
		orders.set_deferred("size", Vector2(1000, 120))
		deploy_y = 578.0
		var lead := LeadProgress.inspect("mara", _profile.completed_missions("mara"))
		var budget := _label(_stage,
			"Mine deployment: %d starting BP · Lead platoon Lv %d · %d BP cap.\n"
			% [lead.next_mission_bp, lead.lead_level, lead.next_mission_capacity]
			+ "Each Mine attempt starts fresh. Confirmed Human chapter clears set the lead level and cap.",
			Rect2(76, 506, 1080, 46), 19, IVORY)
		budget.name = "MineDeploymentBudget"
	var deploy := _button("Confirm Deployment", Rect2(76, deploy_y, 372, 58), _deploy_campaign_mission.bind(mission_id))
	_link_focus(back, SIDE_BOTTOM, deploy)
	_link_focus(deploy, SIDE_TOP, back)
	if can_replay_heavy:
		var heavy := _button("Replay with Heavy Infantry", Rect2(468, deploy_y, 395, 58),
			_deploy_campaign_mission.bind(mission_id, true))
		_link_focus(deploy, SIDE_RIGHT, heavy)
		_link_focus(heavy, SIDE_LEFT, deploy)
		_link_focus(heavy, SIDE_TOP, back)
		var tradeoff := _label(_stage, "Heavy Infantry can withstand more hits, but moves slower and deals less damage. "
			+ "Confirm Deployment uses regular Shield Infantry.",
			Rect2(76, 649, 1150, 46), 20, MUTED)
		tradeoff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tradeoff.name = "MineHeavyReplayTradeoff"
	elif deployment.get("briefing_dispatch", false):
		var dispatch := _button("Read Dispatch", Rect2(468, deploy_y, 268, 58),
			_present_campaign_dialogue.bind(deployment.dispatch, _show_campaign_mission_briefing.bind(mission_id)))
		_link_focus(deploy, SIDE_RIGHT, dispatch)
		_link_focus(dispatch, SIDE_LEFT, deploy)
		_link_focus(dispatch, SIDE_TOP, back)
	back.grab_focus()
	_show_campaign_warning()


func _mine_replay_heavy_available(campaign_id: String, mission_id: String, confirmed_clears: PackedStringArray) -> bool:
	return (campaign_id == MaraTraining.CAMPAIGN_ID and mission_id == MaraTraining.QUALIFYING_CLEAR
		and _has_mara_shield_drill() and confirmed_clears.has(MaraTraining.QUALIFYING_CLEAR)
		and _profile.mara_shield_infantry_training().qualifies_for_branch(
			MaraTraining.SHIELD_INFANTRY_SLOT, MaraTraining.BRANCH_UNIT))


func _deploy_campaign_mission(mission_id: String, use_heavy := false) -> void:
	if _page != Page.MISSION_BRIEFING or not _campaign_world or _campaign_world.mission_at_current_waypoint() != mission_id:
		return
	var campaign_id: String = _active_campaign.id
	var confirmed_clears := _profile.completed_missions(campaign_id)
	if not CampaignMissions.is_unlocked(campaign_id, mission_id, confirmed_clears):
		return
	var deployment := CampaignDeployments.for_mission(mission_id)
	if deployment.is_empty():
		return
	# The briefing's button is not authorization. Recheck against the current
	# campaign record immediately before configuring this one attempt.
	var authorize_heavy := use_heavy and _mine_replay_heavy_available(campaign_id, mission_id, confirmed_clears)
	if use_heavy and not authorize_heavy:
		_show_notice("Heavy Infantry requires a confirmed Mine clear and Shield Infantry Drill Rank 2.")
		return
	var scene: PackedScene = deployment.scene
	var mission: Node3D = scene.instantiate()
	if deployment.has("mission_id"):
		mission.set("mission_id", deployment.mission_id)
		mission.set("campaign_id", campaign_id)
	if use_heavy and (not mission is MaraMine or not mission.configure_replay_heavy_infantry(
			confirmed_clears.has(MaraTraining.QUALIFYING_CLEAR), authorize_heavy)):
		mission.free()
		_show_notice("Heavy Infantry is unavailable. You can still deploy with regular Shield Infantry.")
		return
	_replace_stage(Page.CAMPAIGN_BATTLE)
	_victory_pending = false
	if campaign_id == "mara" and mission_id == "mara_mine_escort" and mission is MaraMine:
		mission.configure_campaign_lead_level(LeadProgress.inspect(campaign_id, confirmed_clears).lead_level)
		mission.configure_campaign_lead_melee(confirmed_clears.has(mission_id) and _profile.mara_lead_melee_invested())
	_campaign_battle = mission
	if deployment.get("result_debrief", false):
		mission.connect(&"mission_cleared", _on_campaign_result.bind(mission, campaign_id, mission_id))
	else:
		mission.connect(&"mission_finished", _on_campaign_battle_finished.bind(mission, campaign_id, mission_id))
	_stage.add_child(mission)
	var back := _button("Return to Campaign Map", Rect2(1079, 735, 330, 48), _return_from_campaign_battle)
	back.name = "ReturnToMap"
	back.focus_mode = Control.FOCUS_NONE
	back.tooltip_text = "Escape or DualSense Create"


func _on_campaign_battle_finished(won: bool, mission: Node3D, campaign_id: String, mission_id: String) -> void:
	if won:
		var deployment := CampaignDeployments.for_mission(mission_id)
		_record_campaign_victory(mission, campaign_id, mission_id, deployment.debrief)


func _on_campaign_result(result: StringName, mission: Node3D, campaign_id: String, mission_id: String) -> void:
	var debrief := &""
	match mission_id:
		"mara_grain_crossing":
			debrief = DialogueBeats.grain_debrief_id(result)
		"ilyra_moonwash_rescue":
			debrief = DialogueBeats.moonwash_debrief_id(result)
		"ilyra_coast_survey":
			var survey := mission as SurveyBattle
			if survey and result == SurveyBattle.CHART_CIRCULATED:
				debrief = DialogueBeats.survey_debrief_id(survey.objective.phase, survey.objective.signal_site)
	if debrief != &"":
		_record_campaign_victory(mission, campaign_id, mission_id, debrief, result)


func _record_campaign_victory(mission: Node3D, campaign_id: String, mission_id: String, debrief: StringName, result := &"") -> void:
	if mission != _campaign_battle or _victory_pending:
		return
	_victory_pending = true
	var saved: Error
	match mission_id:
		"mara_grain_crossing":
			saved = _profile.record_grain_clear(result)
		"ilyra_moonwash_rescue":
			saved = _profile.record_ilyra_moonwash_clear(result)
		_:
			saved = _profile.record_mission_clear(campaign_id, mission_id)
	if saved != OK:
		_campaign_warning = "The mission was completed, but its clear could not be saved."
	elif _profile.record_world_waypoint(_campaign_world) != OK:
		_campaign_warning = "The mission cleared, but the current waypoint could not be saved."
	_finish_campaign_battle.call_deferred(mission, debrief)


func _finish_campaign_battle(mission: Node3D, debrief: StringName) -> void:
	if mission == _campaign_battle:
		_present_campaign_dialogue(debrief, _return_from_campaign_debrief)


func _return_from_campaign_debrief() -> void:
	if not _show_waypoint_intermission():
		_show_world_map()


func _return_from_campaign_battle() -> void:
	if _page == Page.CAMPAIGN_BATTLE and not _victory_pending:
		_show_world_map()


func _present_campaign_dialogue(beat: StringName, then: Callable) -> void:
	_replace_stage(Page.CAMPAIGN_DIALOGUE)
	var dialogue: CampaignDialogue = CAMPAIGN_DIALOGUE_SCENE.instantiate()
	dialogue.completed.connect(func(_id: StringName) -> void: then.call())
	dialogue.cancelled.connect(func(_id: StringName) -> void: then.call())
	_stage.add_child(dialogue)
	if not dialogue.present(beat, DialogueBeats.get_beat(beat), _profile.setting("reduced_motion")):
		then.call()


func _show_campaign_warning() -> void:
	if _campaign_warning.is_empty():
		return
	if _page == Page.WORLD_MAP:
		_label(_stage, _campaign_warning, Rect2(525, 83, 720, 38), 19, Color("#fbb89b"))
	else:
		_show_notice(_campaign_warning)
	_campaign_warning = ""


func _show_briefing() -> void:
	var campaign := _active_campaign
	_open_page(Page.BRIEFING)
	var back := _heading("Camp Operations" if _campaign_world else "Campaign Briefing", campaign.opening)
	_portrait(campaign, Rect2(76, 230, 320, 448), false)
	_label(_stage, campaign.faction.to_upper(), Rect2(442, 255, 736, 32), 20, campaign.accent)
	_label(
		_stage, "%s %s" % [campaign.title, campaign.name],
		Rect2(442, 292, 900, 60), 42, IVORY, DISPLAY_FACE
	)
	_rule(Rect2(442, 369, 675, 1), HAIRLINE)
	var briefing := _label(_stage, "", Rect2(442, 387, 675, 130), 27, IVORY)
	briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	briefing.text = campaign.briefing
	var drills := _button("Combat Drills", Rect2(442, 570, 274, 57), _show_drills)
	var progression := _button("Unit Progression", Rect2(736, 570, 274, 57), _show_unit_progression)
	_link_focus(back, SIDE_BOTTOM, drills)
	_link_focus(drills, SIDE_TOP, back)
	_link_focus(drills, SIDE_RIGHT, progression)
	_link_focus(progression, SIDE_TOP, back)
	_link_focus(progression, SIDE_LEFT, drills)
	var deployment := CampaignDeployments.opening_for_campaign(campaign.id)
	if _campaign_world and not deployment.is_empty():
		var dispatch := _button("Read Dispatch", Rect2(442, 636, 274, 57),
			_present_campaign_dialogue.bind(deployment.dispatch, _show_briefing))
		_link_focus(drills, SIDE_BOTTOM, dispatch)
		_link_focus(progression, SIDE_BOTTOM, dispatch)
		_link_focus(dispatch, SIDE_TOP, drills)
		if _has_mara_shield_drill():
			var shield := _button("Shield Infantry Drill", Rect2(736, 636, 290, 57), _show_mara_shield_drill)
			_link_focus(shield, SIDE_TOP, progression)
			_link_focus(dispatch, SIDE_RIGHT, shield)
			_link_focus(shield, SIDE_LEFT, dispatch)
			if _has_mara_lead_melee():
				var lead := _button(MARA_LEAD_MELEE_ENTRY, Rect2(1046, 636, 318, 57), _show_mara_lead_melee)
				_link_focus(shield, SIDE_RIGHT, lead)
				_link_focus(lead, SIDE_LEFT, shield)
				_link_focus(lead, SIDE_TOP, progression)
	back.grab_focus()


func _has_mara_shield_drill() -> bool:
	return (_campaign_world != null and _active_campaign.get("id") == MaraTraining.CAMPAIGN_ID
		and _campaign_world.campaign_id() == MaraTraining.CAMPAIGN_ID)


func _show_mara_shield_drill() -> void:
	if not _has_mara_shield_drill():
		return
	var plan := _profile.mara_shield_infantry_training()
	var slot := MaraTraining.SHIELD_INFANTRY_SLOT
	var rank := plan.formation_drill_rank(slot)
	var credit := plan.available_drill_credit(slot)
	_open_page(Page.MARA_SHIELD_DRILL)
	var back := _heading("Shield Infantry Drill", "Mara’s development playtest · Training is separate from lead stats and Battle Points.")
	var rank_label := _label(_stage, "Formation Drill: Rank %d" % rank, Rect2(76, 236, 1040, 65), 39, IVORY, DISPLAY_FACE)
	rank_label.name = "ShieldDrillRank"
	var credit_label := _label(_stage, "Available drill credit: %d" % credit, Rect2(76, 314, 1040, 35), 25, GOLD)
	credit_label.name = "ShieldDrillCredit"
	var summary: String
	var qualified := plan.qualifies_for_branch(slot, MaraTraining.BRANCH_UNIT)
	if qualified:
		summary = "Qualified for Heavy Infantry."
	elif credit > 0:
		summary = "Spend 1 drill credit to reach Rank 2 and qualify for Heavy Infantry."
	else:
		summary = "Locked: Clear Get Them Out to earn 1 drill credit."
	var status := _label(_stage, summary, Rect2(76, 381, 1040, 68), 26, IVORY)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.name = "ShieldDrillStatus"
	var loadout_help := "On the Mine replay briefing, choose Replay with Heavy Infantry. Regular Shield Infantry is still the default."
	if not qualified:
		loadout_help = "Rank 2 unlocks the Heavy Infantry option on Mine replays only. Regular Shield Infantry stays the default."
	var availability := _label(_stage, loadout_help, Rect2(76, 459, 1040, 63), 22, MUTED)
	availability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	availability.name = "ShieldDrillAvailability"
	if credit > 0:
		var confirm := _button("Confirm Training (1 drill credit)", Rect2(76, 572, 450, 57), _purchase_mara_shield_drill)
		_link_focus(back, SIDE_BOTTOM, confirm)
		_link_focus(confirm, SIDE_TOP, back)
	back.grab_focus()


func _purchase_mara_shield_drill() -> void:
	if _page != Page.MARA_SHIELD_DRILL or not _has_mara_shield_drill():
		return
	var result := _profile.purchase_mara_shield_infantry_drill()
	if result == OK:
		_show_mara_shield_drill()
	else:
		_show_notice("Training could not be saved. The purchase was not applied.")


func _has_mara_lead_melee() -> bool:
	return (_campaign_world != null and _active_campaign.get("id") == ProfileStore.MARA
		and _campaign_world.campaign_id() == ProfileStore.MARA
		and _campaign_world.current_waypoint_id() == "marches_camp")


func _show_mara_lead_melee() -> void:
	if not _has_mara_lead_melee():
		return
	var state := _profile.mara_lead_melee_status()
	var invested := state == ProfileStore.MaraLeadMeleeStatus.INVESTED
	_open_page(Page.MARA_LEAD_MELEE)
	var back := _heading(MARA_LEAD_MELEE_ENTRY, "Mara’s campaign training · Mine replays only")
	var rating := _label(_stage, "Melee Power: %d" % (2 if invested else 1),
		Rect2(76, 236, 1040, 65), 39, IVORY, DISPLAY_FACE)
	rating.name = "LeadMeleeRating"
	var status := "Locked: Clear Get Them Out."
	match state:
		ProfileStore.MaraLeadMeleeStatus.AVAILABLE:
			status = "Available: Spend 1 earned lead point to raise Melee Power from 1 to 2."
		ProfileStore.MaraLeadMeleeStatus.INVESTED:
			status = "Invested: This one-time training is complete."
		ProfileStore.MaraLeadMeleeStatus.UNAVAILABLE:
			status = "Unavailable: The saved training record could not be read."
	var summary := _label(_stage, status, Rect2(76, 320, 1070, 52), 26, GOLD)
	summary.name = "LeadMeleeStatus"
	var scope := _label(_stage,
		"Only the lead’s Melee Power changes on Mine replays. The lead’s level, HP, Battle Points, and mission rewards stay the same.\n"
		+ "This one-time investment is separate from Shield Infantry Drill and Unit Progression practice.",
		Rect2(76, 398, 1090, 100), 24, IVORY)
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope.name = "LeadMeleeScope"
	if state == ProfileStore.MaraLeadMeleeStatus.AVAILABLE:
		var confirm := _button("Confirm Investment (1 lead point)", Rect2(76, 572, 455, 57), _invest_mara_lead_melee)
		_link_focus(back, SIDE_BOTTOM, confirm)
		_link_focus(confirm, SIDE_TOP, back)
	back.grab_focus()


func _invest_mara_lead_melee() -> void:
	if _page != Page.MARA_LEAD_MELEE or not _has_mara_lead_melee():
		return
	var result := _profile.invest_mara_lead_melee_point()
	_show_mara_lead_melee()
	if result != OK:
		_show_notice("Lead Melee could not be saved. No point was spent.")


func _show_unit_progression(keep_training: bool = false) -> void:
	var starting_id: StringName = _active_campaign.get("starting_unit", &"")
	if not keep_training:
		_training_unit_id = starting_id
		var starting: Dictionary = UnitCatalog.TYPES.get(starting_id, {})
		_training_unit = Unit.new(starting.get("starting_hp", Unit.STARTING_HP), starting.get("ratings", {}))
	var definition: Dictionary = UnitCatalog.TYPES.get(_training_unit_id, {})
	var basic_attack: Dictionary = definition.get("basic_attack", {})
	_training_base_hit = basic_attack.get(Unit.Damage.MELEE, Unit.REFERENCE_HIT)
	var has_promotion := starting_id == UnitCatalog.HUMAN_INFANTRY
	var subtitle := "Practice awarding XP and spending stat points on a training unit."
	if not definition.is_empty():
		var equipment: Dictionary = definition.equipment
		subtitle = "%s · %s · %s and %s" % [
			definition.faction, definition.name, String(equipment.main_hand).capitalize(), equipment.off_hand,
		]
	_open_page(Page.UNIT_PROGRESSION)
	var back := _heading("Unit Progression", subtitle)
	_training_level = _label(_stage, "", Rect2(76, 228, 445, 58), 40, IVORY, DISPLAY_FACE)
	_training_stats = _label(_stage, "", Rect2(76, 294, 445, 164), 24, IVORY)
	_training_stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_training_award = _button("Award 100 XP", Rect2(76, 566 if has_promotion else 573, 345, 45), _award_training_experience)
	_training_inspect = null
	_training_planner = null
	_training_promotion = null
	_training_promotion_status = null
	if has_promotion:
		_training_promotion_status = _label(_stage, "", Rect2(76, 477, 435, 72), 18, GOLD)
		_training_promotion_status.add_theme_constant_override("line_spacing", -4)
		_training_promotion_status.name = "Promotion Status"
		_training_promotion = _button("Promote to Heavy Infantry", Rect2(76, 612, 345, 45), _promote_training_unit)
	if definition.has("model"):
		_training_inspect = _button("Inspect 3D Model", Rect2(76, 658 if has_promotion else 650, 345, 45), _show_unit_model.bind(definition))
	elif PRACTICE_ROSTERS.has(_active_campaign.id):
		_training_planner = _button("Preview Advancement", Rect2(76, 630, 345, 45), _show_roster_requirements)

	_rule(Rect2(523, 229, 841, 1), HAIRLINE)
	_label(_stage, "Combat ratings", Rect2(523, 245, 820, 42), 29, GOLD, DISPLAY_FACE)
	_training_buttons.clear()
	var left: Array[Button] = []
	var right: Array[Button] = []
	for type in Unit.Damage.values():
		var index: int = _training_buttons.size()
		var column := index % 2
		var row := floori(index / 2.0)
		var button := _button(
			RATING_NAMES[type], Rect2(523 + 429 * column, 306 + 80 * row, 412, 60),
			_train_combat_rating.bind(type)
		)
		_training_buttons[type] = button
		var buttons := left if column == 0 else right
		buttons.append(button)

	if has_promotion and PRACTICE_ROSTERS.has(_active_campaign.id):
		_training_planner = _button("Preview Longbows", Rect2(810, 91, 365, 48), _show_roster_requirements)
		_link_focus(back, SIDE_LEFT, _training_planner)
		_link_focus(_training_planner, SIDE_RIGHT, back)
		_link_focus(_training_planner, SIDE_BOTTOM, _training_award)
	_link_cycle(left, SIDE_TOP, SIDE_BOTTOM)
	_link_cycle(right, SIDE_TOP, SIDE_BOTTOM)
	_link_focus(_training_award, SIDE_TOP, back)
	_link_focus(back, SIDE_BOTTOM, _training_award)
	_link_focus(_training_award, SIDE_RIGHT, left[0])
	if _training_promotion:
		_link_focus(_training_promotion, SIDE_RIGHT, left[2])
	if _training_inspect:
		_link_focus(_training_inspect, SIDE_RIGHT, left[3])
	if _training_planner and not has_promotion:
		_link_focus(_training_award, SIDE_BOTTOM, _training_planner)
		_link_focus(_training_planner, SIDE_TOP, _training_award)
		_link_focus(_training_planner, SIDE_RIGHT, left[3])
	for row in range(left.size()):
		_link_focus(left[row], SIDE_LEFT, _training_award)
		_link_focus(left[row], SIDE_RIGHT, right[row])
		_link_focus(right[row], SIDE_LEFT, left[row])
	_update_training()
	_training_award.grab_focus()


func _show_roster_requirements() -> void:
	var source: Array = PRACTICE_ROSTERS.get(_active_campaign.id, [])
	if _page != Page.UNIT_PROGRESSION or source.is_empty():
		return
	var faction: StringName = source[0]
	var unit_id: StringName = source[1]
	var archer_preview := unit_id == UnitCatalog.HUMAN_ARCHER
	var roster := UnitCatalog.faction_roster()
	var unit_name: String = roster.unit(unit_id).display_name
	_open_page(Page.ROSTER_REQUIREMENTS)
	var back := _heading("Advancement Requirements", "%s  /  %s  /  Provisional, not playable" % [_active_campaign.faction, unit_name])
	var explanation := "Uses your practice ratings. Sample rank applies to every platoon skill for this preview only."
	if archer_preview:
		explanation = "Uses your practice Ranged Power. Formation Drill is a sample for this preview only."
	_label(_stage, explanation, Rect2(76, 221, 1235, 42), 23, IVORY)
	var rank_value := _label(_stage, "", Rect2(76, 282, 344, 48), 25, GOLD)
	rank_value.name = "Sample Training Rank"
	var report_labels: Array[Label] = []
	var sample := [0]
	var read_training := func(skill: int) -> Variant:
		return null if archer_preview and skill != Platoon.Skill.FORMATION_DRILL else sample[0]
	var rank_name := "Sample Formation Drill" if archer_preview else "Sample training rank"
	for index in range(roster.inspect_advances(unit_id, faction).size()):
		var x := 76.0 + 655.0 * index
		_rule(Rect2(x, 373, 615, 1), HAIRLINE)
		var report := _label(_stage, "", Rect2(x, 397, 615, 285), 23, IVORY)
		report.name = "Branch Requirements %d" % index
		report.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		report_labels.append(report)
	var redraw := func() -> void:
		rank_value.text = "%s: %d / %d" % [rank_name, sample[0], Platoon.MAX_RANK]
		var rows := roster.inspect_advances(unit_id, faction, _training_unit.rating, read_training)
		for index in range(rows.size()):
			var branch: Dictionary = rows[index]
			var text := "%s\n%s" % [roster.unit(branch.target).display_name,
				"Eligible in this sample · Not playable" if branch.eligible else "Locked · Not playable"]
			text += "\n\nCombat ratings" + _requirement_lines(branch.ratings, RATING_NAMES, "points")
			text += "\n\nPlatoon training" + _requirement_lines(branch.training, TRAINING_NAMES, "ranks")
			report_labels[index].text = text
	var shift_rank := func(delta: int) -> void:
		sample[0] = clampi(sample[0] + delta, 0, Platoon.MAX_RANK)
		redraw.call()
	var lower := _button("Lower Sample Rank", Rect2(429, 282, 263, 48), shift_rank.bind(-1))
	var raise := _button("Raise Sample Rank", Rect2(706, 282, 263, 48), shift_rank.bind(1))
	_link_focus(lower, SIDE_RIGHT, raise)
	_link_focus(raise, SIDE_LEFT, lower)
	_link_focus(lower, SIDE_TOP, back)
	_link_focus(raise, SIDE_TOP, back)
	_link_focus(back, SIDE_BOTTOM, raise)
	_label(_stage, "Viewing these requirements cannot recruit a unit or change a save.", Rect2(76, 711, 1150, 38), 21, MUTED)
	redraw.call()
	raise.grab_focus()


func _requirement_lines(gates: Dictionary, names: Dictionary, units: String) -> String:
	if gates.is_empty():
		return ": None"
	var lines := ""
	for stat: int in gates:
		var gate: Dictionary = gates[stat]
		if gate.missing == null:
			lines += "\n%s: requires %d · current unknown" % [names[stat], gate.minimum]
		elif gate.missing == 0:
			lines += "\n%s: %d / %d · met" % [names[stat], gate.current, gate.minimum]
		else:
			lines += "\n%s: %d / %d · missing %d %s" % [names[stat], gate.current, gate.minimum, gate.missing, units]
	return lines


func _show_unit_model(definition: Dictionary) -> void:
	_open_page(Page.UNIT_MODEL)
	var back := _heading(definition.name, "%s · %s" % [definition.faction, definition.role])
	var studio := _create_unit_studio(Rect2(76, 212, 896, 512))
	studio.set_unit_model(definition.model)
	var pose: StringName = definition.get("preview_clip", &"")
	if studio.animation_player and studio.animation_player.has_animation(pose):
		studio.animation_player.play(pose)
	_label(_stage, "View", Rect2(1012, 248, 352, 48), 30, IVORY, DISPLAY_FACE)
	var views := _unit_view_buttons(studio, Rect2(1012, 319, 352, 55), Vector2(0, 71))
	var navigation: Array[Button] = [back]
	navigation.append_array(views)
	_link_cycle(navigation, SIDE_TOP, SIDE_BOTTOM)
	views[0].grab_focus()


func _create_unit_studio(rect: Rect2) -> UnitModelStudio:
	var viewport := _create_model_viewport(rect)
	viewport.msaa_3d = Viewport.MSAA_2X
	var studio := UNIT_STUDIO_SCENE.instantiate() as UnitModelStudio
	viewport.add_child(studio)
	return studio


func _create_model_viewport(rect: Rect2) -> SubViewport:
	_color_rect(_stage, rect.grow(1), HAIRLINE)
	var frame := SubViewportContainer.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(frame)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	frame.add_child(viewport)
	return viewport


func _unit_view_buttons(studio: UnitModelStudio, rect: Rect2, step: Vector2) -> Array[Button]:
	var front := _button("Front", rect, studio.show_body.bind(25.0))
	rect.position += step
	var side := _button("Side", rect, studio.show_body.bind(-82.0))
	rect.position += step
	var rear := _button("Back view", rect, studio.show_body.bind(153.0))
	rect.position += step
	var face := _button("Face", rect, studio.show_face)
	return [front, side, rear, face]


func _show_unit_test() -> void:
	_open_page(Page.UNIT_TEST)
	var back := _heading("Unit Test", "")
	var units: Array[Dictionary] = []
	for definition in UnitCatalog.TYPES.values():
		if definition.get("model") is PackedScene:
			units.append(definition)
	if units.is_empty():
		_label(_stage, "No unit models available.", Rect2(76, 224, 660, 48), 25, MUTED)
		back.grab_focus()
		return

	var studio := _create_unit_studio(Rect2(76, 212, 896, 460))
	var views := _unit_view_buttons(studio, Rect2(76, 682, 214, 48), Vector2(227, 0))
	_link_cycle(views, SIDE_LEFT, SIDE_RIGHT)
	var details := _label(_stage, "", Rect2(77, 148, 1050, 34), 23, MUTED)
	_label(_stage, "Unit", Rect2(1012, 226, 352, 38), 26, IVORY, DISPLAY_FACE)
	var unit_choice := _option_button("Unit", Rect2(1012, 275, 352, 55))
	for definition in units:
		unit_choice.add_item("%s · %s" % [definition.faction, definition.name])
	_label(_stage, "Animation", Rect2(1012, 369, 352, 38), 26, IVORY, DISPLAY_FACE)
	var animation_choice := _option_button("Animation", Rect2(1012, 418, 352, 55))
	var playback := _button("Pause", Rect2(1012, 492, 352, 52))
	var restart := _button("Restart", Rect2(1012, 554, 352, 52))
	var skirmish := _button("AI Skirmish", Rect2(1012, 616, 352, 52), _show_skirmish_setup)

	var play_animation := func(index: int) -> void:
		var player := studio.animation_player
		var clip: StringName = animation_choice.get_item_metadata(index)
		var definition := units[unit_choice.selected]
		var previews: Dictionary = definition.get("animation_preview", {})
		var preview: Dictionary = previews.get(clip, {})
		studio.set_preview_framing(
			preview.get("headroom", 0.0),
			preview.get("travel", 0.0),
			preview.get("floor_scale", 1.0),
			preview.get("start_offset", 0.0),
			preview.get("side_offset", 0.0)
		)
		player.stop()
		player.speed_scale = preview.get("speed", 1.0)
		player.play(clip)
		player.advance(0.0)
		playback.text = "Pause"
	animation_choice.item_selected.connect(play_animation)
	restart.pressed.connect(func() -> void: play_animation.call(animation_choice.selected))
	playback.pressed.connect(func() -> void:
		var player := studio.animation_player
		if player.is_playing():
			player.pause()
			playback.text = "Play"
		else:
			var clip: StringName = animation_choice.get_selected_metadata()
			player.play(clip)
			playback.text = "Pause"
	)

	var show_unit := func(index: int) -> void:
		var definition := units[index]
		studio.set_unit_model(definition.model)
		studio.show_body(25.0)
		details.text = definition.role
		animation_choice.clear()
		var player := studio.animation_player
		var initial_clip := 0
		var preferred_clip: StringName = definition.get("preview_clip", &"Idle")
		if player:
			for clip in player.get_animation_list():
				if clip != "RESET":
					if clip == preferred_clip:
						initial_clip = animation_choice.item_count
					animation_choice.add_item(clip)
					animation_choice.set_item_metadata(animation_choice.item_count - 1, StringName(clip))
		var can_play := animation_choice.item_count > 0
		animation_choice.disabled = not can_play
		playback.disabled = not can_play
		restart.disabled = not can_play
		var navigation: Array[Button] = [back, unit_choice]
		if can_play:
			navigation.append_array([animation_choice, playback, restart])
			animation_choice.select(initial_clip)
			player.animation_finished.connect(func(_clip: StringName) -> void: playback.text = "Play")
			play_animation.call(initial_clip)
		else:
			animation_choice.add_item("No animations")
			animation_choice.select(0)
			playback.text = "Play"
		navigation.append(skirmish)
		var last := navigation.back() as Button
		navigation.append(views[0])
		_link_cycle(navigation, SIDE_TOP, SIDE_BOTTOM)
		for view in views:
			_link_focus(view, SIDE_TOP, last)
			_link_focus(view, SIDE_BOTTOM, back)
	unit_choice.item_selected.connect(show_unit)
	unit_choice.select(0)
	show_unit.call(0)
	unit_choice.grab_focus()


func _show_skirmish_setup() -> void:
	_open_page(Page.SKIRMISH_SETUP)
	var back := _heading("Skirmish Setup", "Choose the platoons and combat ratings for each army.")
	var menu := SkirmishSetupMenu.new()
	_stage.add_child(menu)
	menu.initialize(_skirmish_setup, back, RATING_NAMES)
	menu.start_requested.connect(_show_skirmish)
	menu.focus_initial()


func _show_skirmish() -> void:
	_open_page(Page.SKIRMISH)
	var total_platoons: int = _skirmish_setup.sides[0].size() + _skirmish_setup.sides[1].size()
	var back := _heading(
		"AI Infantry Skirmish",
		"%d platoons  ·  %d soldiers per platoon" % [total_platoons, Skirmish.PLATOON_SIZE]
	)
	var viewport := _create_model_viewport(Rect2(76, 275, 1288, 392))
	var view := SKIRMISH_SCENE.instantiate() as SkirmishView
	view.configure(_skirmish_setup)
	viewport.add_child(view)
	var team_names := ["Blue", "Amber"]
	var team_labels: Array[Label] = []
	var health_bars: Array[Control] = []
	for team in range(2):
		var x := 76 if team == 0 else 887
		team_labels.append(_label(_stage, "", Rect2(x, 199, 477, 30), 22, SkirmishView.TEAM_COLORS[team]))
		var count: int = _skirmish_setup.sides[team].size()
		var width := (477.0 - 10.0 * (count - 1)) / count
		for slot in range(count):
			var build: SkirmishSetup.PlatoonBuild = _skirmish_setup.sides[team][slot]
			var left := x + slot * (width + 10.0)
			var type_tag := " · Hvy" if build.unit_type == UnitCatalog.HUMAN_HEAVY_INFANTRY else ""
			_label(_stage, "P%d · Lv %d%s" % [slot + 1, build.level, type_tag], Rect2(left, 228, width, 24), 17, IVORY)
			var bar := _color_rect(_stage, Rect2(left, 254, width, 10), Color("#131719"))
			for color in [Color("#63935d"), Color("#a84c47"), Color("#08090a")]:
				_color_rect(bar, Rect2(0, 0, 0, 10), color)
			health_bars.append(bar)
	var status := _label(_stage, "", Rect2(573, 205, 294, 52), 22, IVORY)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var counts := _label(_stage, "", Rect2(76, 682, 885, 45), 22, MUTED)
	var playback := _button("Pause", Rect2(1012, 680, 168, 50))
	var restart := _button("Restart", Rect2(1192, 680, 172, 50))

	var update := func() -> void:
		var battle := view.battle
		for team in range(2):
			team_labels[team].text = "%s   %d / %d alive" % [team_names[team], battle.survivors(team), battle.team_size(team)]
		for index in range(battle.platoons.size()):
			var health: Vector3 = battle.platoons[index].health_fractions()
			var bar := health_bars[index]
			var offset := 0.0
			for segment in range(3):
				var fill := bar.get_child(segment) as ColorRect
				fill.position.x = offset
				fill.size.x = health[segment] * bar.size.x
				offset += fill.size.x
		var seconds := floori(battle.elapsed)
		status.text = "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
		if battle.winner != Skirmish.LIVE:
			status.text = "Mutual defeat" if battle.winner == Skirmish.DRAW else "%s wins" % team_names[battle.winner]
		counts.text = "%d hits   ·   %d blocks   ·   %d waiting for a slot" % [battle.hits, battle.blocks, battle.waiting_count()]
	view.updated.connect(update)
	update.call()
	playback.pressed.connect(func() -> void:
		view.paused = not view.paused
		playback.text = "Resume" if view.paused else "Pause"
	)
	restart.pressed.connect(func() -> void:
		view.restart()
		playback.text = "Pause"
	)
	_link_cycle([back, playback, restart], SIDE_TOP, SIDE_BOTTOM)
	_link_cycle([playback, restart], SIDE_LEFT, SIDE_RIGHT)
	playback.grab_focus()


func _award_training_experience() -> void:
	_notice.hide()
	if _training_unit.level == Unit.MAX_LEVEL:
		_show_notice("This unit has reached level %d." % Unit.MAX_LEVEL)
		return
	_training_unit.award_experience(100)
	_update_training()


func _train_combat_rating(type: Unit.Damage) -> void:
	_notice.hide()
	if _training_unit.spend_stat_point(type):
		_update_training()
	elif _training_unit.rating(type) == Unit.MAX_RATING:
		_show_notice("This rating is already at %d." % Unit.MAX_RATING)
	else:
		_show_notice("Gain a level to earn a stat point.")


func _promote_training_unit() -> void:
	var promoted := UnitCatalog.HUMAN_HEAVY_INFANTRY
	if _page != Page.UNIT_PROGRESSION or not UnitCatalog.can_promote(_training_unit_id, promoted, _training_unit):
		return
	_training_unit.set_starting_hp(UnitCatalog.TYPES[promoted].starting_hp)
	_training_unit_id = promoted
	_show_unit_progression(true)
	_training_inspect.grab_focus()


func _update_training_promotion() -> void:
	var next_button := _training_inspect
	if _training_promotion:
		var regular: Dictionary = UnitCatalog.TYPES[UnitCatalog.HUMAN_INFANTRY]
		var heavy_id := UnitCatalog.HUMAN_HEAVY_INFANTRY
		var heavy: Dictionary = UnitCatalog.TYPES[heavy_id]
		var required_rating: int = heavy.promotion_minimum_ratings[Unit.Damage.MELEE]
		var equipped := _training_unit_id == heavy_id
		var status := "Heavy Infantry equipped" if equipped else "Heavy Infantry · Melee Power %d / %d" % [
			_training_unit.rating(Unit.Damage.MELEE), required_rating,
		]
		_training_promotion_status.text = "%s\n+%d starting HP · %d less base sword damage\nPractice only · Skirmish speed: %d%% of Infantry" % [
			status, heavy.starting_hp - regular.starting_hp,
			regular.basic_attack[Unit.Damage.MELEE] - heavy.basic_attack[Unit.Damage.MELEE],
			roundi(heavy.movement_scale * 100.0),
		]
		_training_promotion.disabled = not UnitCatalog.can_promote(_training_unit_id, heavy_id, _training_unit)
		if not _training_promotion.disabled:
			next_button = _training_promotion
			_link_focus(_training_promotion, SIDE_TOP, _training_award)
			_link_focus(_training_promotion, SIDE_BOTTOM, _training_inspect)
		if equipped:
			_training_promotion.text = "Heavy Infantry equipped"
	if next_button:
		_link_focus(_training_award, SIDE_BOTTOM, next_button)
	if _training_inspect:
		_link_focus(_training_inspect, SIDE_TOP, _training_award if next_button == _training_inspect else next_button)


func _update_training() -> void:
	_training_level.text = "Level %d" % _training_unit.level
	var damage := _training_unit.damage_from(_training_unit, {Unit.Damage.MELEE: _training_base_hit})
	var hits := ceili(_training_unit.max_hp / damage)
	var xp := "XP to next level  %d / %d" % [_training_unit.experience, _training_unit.experience_for_next_level()]
	if _training_unit.level == Unit.MAX_LEVEL:
		xp = "Maximum level reached"
	_training_stats.text = "Maximum HP  %.1f\nMatched melee hit  %.1f damage\n%d hits to defeat\n%s\nUnspent stat points  %d" % [
		_training_unit.max_hp, damage, hits, xp, _training_unit.stat_points,
	]
	for type in _training_buttons:
		_training_buttons[type].text = "%s   %d" % [RATING_NAMES[type], _training_unit.rating(type)]
	_update_training_promotion()


func _show_drills() -> void:
	_open_page(Page.DRILLS)
	var back := _heading("Combat Drills", "Compare outcomes at different skill ranks and damage ratings.")
	_drill_buttons.clear()
	for index in range(Drills.EXERCISES.size()):
		var exercise := Drills.EXERCISES[index]
		var button := _button(exercise.name, Rect2(76, 225 + 67 * index, 345, 55), _select_drill.bind(index))
		button.focus_entered.connect(_select_drill.bind(index))
		_drill_buttons.append(button)
	var points := _button("Battle Points Drill", Rect2(76, 694, 345, 45), _show_battle_points_drill)
	var drill_choices := _drill_buttons.duplicate()
	drill_choices.append(points)
	_link_cycle(drill_choices, SIDE_TOP, SIDE_BOTTOM)
	_link_focus(points, SIDE_RIGHT, back)

	_color_rect(_stage, Rect2(464, 225, 900, 457), Color(0.047, 0.054, 0.055, 0.9))
	_rule(Rect2(464, 225, 900, 1), HAIRLINE)
	_drill_title = _label(_stage, "", Rect2(492, 245, 520, 56), 36, IVORY, DISPLAY_FACE)
	_drill_description = _label(_stage, "", Rect2(492, 317, 823, 66), 23, MUTED)
	_drill_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drill_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_drill_lower_rank = _button("−", Rect2(1038, 251, 51, 43), _change_drill_rank.bind(-1))
	_drill_lower_rank.tooltip_text = "Decrease value"
	_drill_rank_label = _label(_stage, "", Rect2(1092, 251, 180, 43), 21, IVORY)
	_drill_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var raise_rank := _button("+", Rect2(1275, 251, 51, 43), _change_drill_rank.bind(1))
	raise_rank.tooltip_text = "Increase value"
	_link_focus(back, SIDE_BOTTOM, _drill_lower_rank)
	_link_focus(_drill_lower_rank, SIDE_TOP, back)
	_link_focus(raise_rank, SIDE_TOP, back)
	_link_focus(_drill_lower_rank, SIDE_RIGHT, raise_rank)
	_link_focus(raise_rank, SIDE_LEFT, _drill_lower_rank)
	for button in _drill_buttons:
		_link_focus(button, SIDE_RIGHT, _drill_lower_rank)

	_drill_baseline_heading = _label(_stage, "", Rect2(902, 398, 164, 36), 20, MUTED)
	_drill_rank_heading = _label(_stage, "", Rect2(1135, 398, 180, 36), 20, GOLD)
	_drill_metrics.clear()
	_drill_baseline.clear()
	_drill_results.clear()
	for row in range(3):
		var y := 443 + 65 * row
		_rule(Rect2(492, y, 833, 1), HAIRLINE)
		_drill_metrics.append(_label(_stage, "", Rect2(492, y + 9, 402, 46), 24, IVORY))
		_drill_baseline.append(_label(_stage, "", Rect2(902, y + 9, 165, 46), 24, MUTED))
		_drill_results.append(_label(_stage, "", Rect2(1135, y + 9, 180, 46), 24, GOLD))

	_select_drill(_drill_index)
	_drill_buttons[_drill_index].grab_focus()


func _show_battle_points_drill() -> void:
	_open_page(Page.BATTLE_POINTS_DRILL)
	var back := _heading("Battle Points Drill", "Earn points with one platoon and spend from the same pool with another.")
	var drill := BattlePointsDrill.new()
	_stage.add_child(drill)
	drill.initialize(back)


func _select_drill(index: int) -> void:
	_drill_index = index
	_link_focus(_drill_lower_rank, SIDE_LEFT, _drill_buttons[index])
	for i in range(_drill_buttons.size()):
		_drill_buttons[i].add_theme_color_override("font_color", GOLD if i == index else IVORY)
	_update_drill()


func _change_drill_rank(change: int) -> void:
	_drill_rank = clampi(_drill_rank + change, 0, Platoon.MAX_RANK)
	_update_drill()


func _update_drill() -> void:
	var exercise := Drills.EXERCISES[_drill_index]
	var metrics: Array = exercise.metrics
	var uses_rating: bool = exercise.get("damage_rating", false)
	var baseline_level := Unit.MIN_RATING if uses_rating else 0
	var level := _drill_rank
	if uses_rating:
		level = maxi(baseline_level, roundi(float(_drill_rank) / Platoon.MAX_RANK * Unit.MAX_RATING))
	var scale_label := "Rating" if uses_rating else "Rank"
	var baseline := Drills.run(exercise.id, baseline_level)
	var results := Drills.run(exercise.id, level)
	_drill_title.text = exercise.name
	_drill_description.text = exercise.description
	_drill_rank_label.text = "%s %d" % ["Curse rating" if uses_rating else "Training rank", level]
	_drill_baseline_heading.text = "%s %d" % [scale_label, baseline_level]
	_drill_rank_heading.text = "%s %d" % [scale_label, level]
	for row in range(_drill_metrics.size()):
		var has_metric := row < metrics.size()
		_drill_metrics[row].text = metrics[row] if has_metric else ""
		_drill_baseline[row].text = baseline[row] if has_metric else ""
		_drill_results[row].text = results[row] if has_metric else ""


func _show_load() -> void:
	_open_page(Page.LOAD)
	var back := _heading("Load Campaign", "Resume a saved campaign.")
	var saves := _profile.saved_campaigns(Campaigns.ALL)
	if saves.is_empty():
		_label(_stage, "No saved campaigns yet.", Rect2(76, 243, 710, 50), 25, MUTED)
		back.grab_focus()
		return

	var actions: Array[Button] = [back]
	for i in range(saves.size()):
		var campaign := saves[i]
		var text := "%s %s  ·  %s" % [campaign.title, campaign.name, campaign.faction]
		var button := _button(text, Rect2(76, 224 + i * 71, 710, 59), _open_campaign.bind(campaign))
		actions.append(button)
	_link_cycle(actions, SIDE_TOP, SIDE_BOTTOM)
	actions[1].grab_focus()


func _show_settings() -> void:
	_open_page(Page.SETTINGS)
	var back := _heading("Settings", "Adjust display and menu motion.")
	var fullscreen := _setting_button("Fullscreen", "fullscreen", 233)
	var motion := _setting_button("Reduced motion", "reduced_motion", 329)
	var choices: Array[Button] = [back, fullscreen, motion]
	_link_cycle(choices, SIDE_TOP, SIDE_BOTTOM)
	fullscreen.grab_focus()


func _setting_button(title: String, key: String, y: float) -> Button:
	var button := _button(title, Rect2(76, y, 554, 63))
	var status := _label(button, "", Rect2(410, 0, 115, 63), 21, GOLD)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.text = "ON" if _profile.setting(key) else "OFF"
	button.pressed.connect(func() -> void:
		var enabled := not _profile.setting(key)
		if _profile.set_setting(key, enabled) != OK:
			_show_notice("The setting could not be saved.")
			return
		status.text = "ON" if enabled else "OFF"
		_notice.hide()
		if key == "fullscreen":
			_apply_fullscreen()
		else:
			var embers := _stage.get_node("Embers") as Control
			embers.visible = not enabled
			embers.set_process(not enabled)
	)
	return button


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _profile.setting("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _show_quit() -> void:
	_open_page(Page.QUIT)
	var back := _heading("Quit Game", "Close Torn Asunder?")
	var cancel := _button("Keep Playing", Rect2(76, 232, 310, 58), _show_title)
	var quit := _button("Quit Game", Rect2(76, 307, 310, 58), get_tree().quit)
	var choices: Array[Button] = [back, cancel, quit]
	_link_cycle(choices, SIDE_TOP, SIDE_BOTTOM)
	cancel.grab_focus()


func _replace_stage(page: Page) -> void:
	_page = page
	_hint = null
	_notice = null
	_campaign_battle = null
	if is_instance_valid(_stage):
		remove_child(_stage)
		_stage.queue_free()
	_stage = Control.new()
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_page(page: Page) -> void:
	_replace_stage(page)
	var is_title := page == Page.TITLE
	var background := _texture(
		_stage, TITLE_ART if is_title else VAULT_ART, Rect2(0, 0, 1440, 810)
	)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_title:
		_shade(_stage, Rect2(0, 0, 1140, 810), false, Color(0.02, 0.025, 0.024, 0.65))
	else:
		_color_rect(_stage, Rect2(0, 0, 1440, 810), Color(0.025, 0.029, 0.03, 0.49))
	_shade(_stage, Rect2(0, 612, 1440, 198), true, Color(0.016, 0.02, 0.02, 0.92))

	var embers := Embers.new()
	embers.name = "Embers"
	_stage.add_child(embers)
	embers.position = Vector2(500, 0) if is_title else Vector2.ZERO
	embers.size = Vector2(940, 730) if is_title else Vector2(1440, 730)
	embers.visible = not _profile.setting("reduced_motion")
	embers.set_process(embers.visible)

	_rule(Rect2(76, 744, 1288, 1), Color(0.63, 0.55, 0.43, 0.36))
	_hint = _label(_stage, "", Rect2(76, 753, 1200, 38), 17, MUTED)
	_update_hint()
	_notice = _label(_stage, "", Rect2(76, 704, 1140, 32), 21, Color("#fbb89b"))
	_notice.hide()


func _heading(title: String, subtitle: String) -> Button:
	_label(_stage, title, Rect2(76, 67, 1050, 76), 57, IVORY, DISPLAY_FACE)
	if not subtitle.is_empty():
		_label(_stage, subtitle, Rect2(77, 148, 1050, 34), 23, MUTED)
	_rule(Rect2(76, 196, 1288, 1), HAIRLINE)
	return _button("Back", Rect2(1192, 91, 172, 48), _go_back)


func _update_hint() -> void:
	if not is_instance_valid(_hint):
		return
	if _using_controller:
		_hint.text = "D-pad   Navigate       Cross   Select"
		if _page != Page.TITLE:
			_hint.text += "       Circle   Back"
	else:
		_hint.text = "↑ ↓ ← →   Navigate       Enter   Select"
		if _page != Page.TITLE:
			_hint.text += "       Esc   Back"


func _show_notice(message: String) -> void:
	_notice.text = message
	_notice.show()


func _portrait(campaign: Dictionary, rect: Rect2, interactive: bool = true) -> Button:
	var card := Button.new()
	card.name = campaign.id
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stage.add_child(card)
	card.position = rect.position
	card.size = rect.size
	card.add_theme_stylebox_override("normal", _box(DARK, HAIRLINE))
	card.add_theme_stylebox_override("hover", _box(DARK, GOLD))
	card.add_theme_stylebox_override("pressed", _box(DARK, IVORY))
	card.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 2))
	card.tooltip_text = "%s %s" % [campaign.title, campaign.name]
	if not interactive:
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_texture(card, campaign.portrait, Rect2(Vector2(3, 3), rect.size - Vector2(6, 6)))
	if interactive:
		_shade(card, Rect2(3, rect.size.y - 120, rect.size.x - 6, 117), true, Color("#101313"))
		_label(card, campaign.faction.to_upper(), Rect2(14, rect.size.y - 67, rect.size.x - 28, 24), 16, campaign.accent)
		_label(card, campaign.name, Rect2(14, rect.size.y - 44, rect.size.x - 28, 34), 21, IVORY, DISPLAY_FACE)
	return card


func _button(text: String, rect: Rect2, action: Callable = Callable()) -> Button:
	var button := Button.new()
	button.name = text
	button.text = text
	_style_button(button, rect)
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _option_button(name: String, rect: Rect2) -> OptionButton:
	var button := OptionButton.new()
	button.name = name
	button.fit_to_longest_item = false
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_button(button, rect)
	var popup := button.get_popup()
	popup.add_theme_stylebox_override("panel", _box(DARK, HAIRLINE))
	popup.add_theme_stylebox_override("hover", _box(Color("#403123"), GOLD))
	popup.add_theme_font_override("font", _body_face)
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", IVORY)
	return button


func _style_button(button: Button, rect: Rect2) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _body_face)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color("#928b80"))
	button.add_theme_stylebox_override("normal", _box(Color(0.08, 0.09, 0.09, 0.74), HAIRLINE))
	button.add_theme_stylebox_override("hover", _box(Color("#292622"), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color("#403123"), GOLD))
	button.add_theme_stylebox_override("focus", _box(Color(0.64, 0.42, 0.20, 0.16), GOLD, 2))
	button.add_theme_stylebox_override("disabled", _box(Color(0.06, 0.07, 0.07, 0.46), Color("#4a4540")))
	_stage.add_child(button)
	button.position = rect.position
	button.size = rect.size


func _box(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = 19
	box.content_margin_right = 16
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _link_cycle(buttons: Array[Button], previous: Side, next: Side) -> void:
	for index in range(buttons.size()):
		_link_focus(buttons[index], previous, buttons[posmod(index - 1, buttons.size())])
		_link_focus(buttons[index], next, buttons[(index + 1) % buttons.size()])


func _link_focus(from: Button, direction: Side, to: Button) -> void:
	from.set_focus_neighbor(direction, from.get_path_to(to))


func _label(
	parent: Control, text: String, rect: Rect2, font_size: int, color: Color, font: Font = null
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font if font else _body_face)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _texture(parent: Control, art: Texture2D, rect: Rect2) -> TextureRect:
	var texture := TextureRect.new()
	texture.texture = art
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture)
	texture.position = rect.position
	texture.size = rect.size
	return texture


func _color_rect(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	fill.position = rect.position
	fill.size = rect.size
	return fill


func _rule(rect: Rect2, color: Color) -> void:
	_color_rect(_stage, rect, color)


func _shade(parent: Control, rect: Rect2, vertical: bool, color: Color) -> void:
	var gradient := Gradient.new()
	var clear := Color(color, 0.0)
	gradient.colors = PackedColorArray([clear, color] if vertical else [color, clear])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 2 if vertical else 512
	texture.height = 256 if vertical else 2
	texture.fill_to = Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	_texture(parent, texture, rect).stretch_mode = TextureRect.STRETCH_SCALE
