extends Node
## Title HUD adapter for the eighteen dedicated deployment scenes. Never install
## on the generic battle view. Underlying authored nodes retain their original
## process, state, connections, and right to handle dedicated non-GUI inputs.

const FEED_NAME := &"AuthoredObjectiveFeed"
const COMMON := "ObjectiveHUD"
const ROW_LAYER := 9
const MAX_OBJECTIVE := 99
const MAX_CONTEXT := 118
# Entries are [layer, primary label, context labels, progress strategy, buttons,
# true default objective]. Only exact known panels are hidden. A source change
# or absent button fails closed: leave that mission's full original panel intact.
const SOURCES := {
	"mara_mine_escort": [COMMON, "Goal", ["Instructions"], "", [], "Reach the miners at the south tunnel"],
	"mara_grain_crossing": [COMMON, "Goal", ["Cue", "Status"], "grain", ["Actions/Select", "Actions/Dispatch", "Actions/Withdraw"], "Deliver at least one load and resolve both carts"],
	"mara_moonwash_quay": ["WithdrawalHUD", "Goal", ["Route", "Levy", "Roster"], "quay", [], "Withdraw the hero and both royal platoons"],
	"orc_mine_witness": [COMMON, "Goal", ["Instructions"], "", [], "Find the witness at the tunnel outlet"],
	"orc_well_road": [COMMON, "Goal", ["Cue", "Instructions", "Status"], "wells", ["Actions/Select", "Actions/Salt", "Actions/Wash"], "Escort both well carts to the Basin exit"],
	"orc_spanwater_release": [COMMON, "Goal", ["Instructions", "Situation"], "", [], "Secure the spillway wheel"],
	"sova_mine_tunnels": [COMMON, "Goal", ["Instructions"], "workgroups", [], "Release both work groups and get them to safety"],
	"sova_public_record": ["HearingHUD", "Goal", ["Detail", "Conditions"], "", [], "Read the public record with the scribe"],
	"sova_vault_return": ["VaultHUD", "Goal", ["Detail", "Reserve"], "", [], "Return the Godbridle to the vault"],
	"ilyra_moonwash_rescue": [COMMON, "Progress", ["Hint", "Pressure"], "rescue", [], "Rig both lines and rescue both crews"],
	"ilyra_coast_survey": [COMMON, "Chart", ["Hint", "Shore"], "chart", [], "Record both readings and signal the cutter"],
	"ilyra_spanwater_evacuation": [COMMON, "Goal", ["Cue", "Status"], "launches", [], "Get both household groups beyond the boat exit"],
	"neris_failing_grove": [COMMON, "Goal", ["Cue", "Status"], "", [], "Help transplant the first tree"],
	"neris_cairnspine_survey": ["SurveyHUD", "Goal", ["Cue", "Evidence"], "", [], "Follow the covered track and find the freight marks"],
	"neris_greyhollow": [COMMON, "Goal", ["Cue", "Status"], "greyhollow", [], "Advance on the mine yard"],
	"sereth_voices_at_the_cut": [COMMON, "Account", ["Hint", "Bundle", "Pressure"], "cut", [], "Hear Iren's account at the cemetery stair"],
	"sereth_pass_writ": [COMMON, "Goal", ["Hint", "Keeper", "Pressure"], "", [], "Carry the writ to the neutral Keeper"],
	"sereth_no_proxy": ["PlaytestHUD", "Goal", ["Hint", "Route", "Pressure"], "", [], "Refuse the court escort before the assembly"],
}

var _host: Node
var _mission_id := ""
var _entry: Array
var _panel: Control
var _panel_was_visible := false
var _primary: Label
var _labels: Dictionary = {}
var _sources: Array[Button] = []
var _mirrors: Array[Button] = []
var _row: HBoxContainer


static func mount(host: Node, mission_id: String) -> Node:
	if not is_instance_valid(host) or not SOURCES.has(mission_id):
		return null
	var script := load("res://game/ui/authored_objective_feed.gd") as GDScript
	var existing := host.get_node_or_null(NodePath(FEED_NAME))
	if existing != null and existing.get_script() == script:
		return existing if existing._mission_id == mission_id else null
	if existing != null:
		return null
	var feed: Node = script.new()
	if not feed._bind_scene(host, mission_id):
		feed.free()
		return null
	feed.name = FEED_NAME
	host.add_child(feed)
	return feed


func _bind_scene(host: Node, mission_id: String) -> bool:
	_host = host
	_mission_id = mission_id
	_entry = SOURCES[mission_id]
	_panel = host.get_node_or_null(NodePath(String(_entry[0]) + "/Panel")) as Control
	if _panel == null:
		return false
	var readout := _panel.get_node_or_null(^"Margin/Readout")
	if readout == null:
		return false
	_primary = readout.get_node_or_null(NodePath(_entry[1])) as Label
	if _primary == null:
		return false
	for label_name: String in _entry[2]:
		var source := readout.get_node_or_null(NodePath(label_name)) as Label
		if source == null:
			return false
		_labels[label_name] = source
	for button_path: String in _entry[4]:
		var source := readout.get_node_or_null(NodePath(button_path)) as Button
		if source == null or source.toggle_mode:
			return false
		_sources.append(source)
	# Refuse to hide an updated panel containing an unregistered new action.
	for button: Node in _panel.find_children("*", "Button", true, false):
		if button.name != &"Restart" and not _sources.has(button):
			return false
	_panel_was_visible = _panel.visible
	return true


func _ready() -> void:
	if not _sources.is_empty():
		_build_row()
	_panel.hide()
	_refresh_row()
	# Only UI visibility follows paused frames; original mission actions do not.
	if _row != null:
		process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(_row != null)


func _exit_tree() -> void:
	if is_instance_valid(_panel) and is_instance_valid(_host) and not _host.is_queued_for_deletion():
		_panel.visible = _panel_was_visible


func _process(_delta: float) -> void:
	_refresh_row()


func action_row() -> Control:
	return _row


func sample() -> Dictionary:
	if not is_instance_valid(_primary):
		return {"objective": "", "context": ""}
	var progress := _source_text(_primary)
	var goal: String = progress if not progress.is_empty() else _entry[5]
	match String(_entry[3]):
		"grain":
			if goal.begins_with("Escort"):
				goal = "Deliver grain · " + _cart_progress(_text("Status"))
		"wells":
			if goal.begins_with("Escort"):
				goal = "Escort both well carts · " + _cart_progress(_text("Status"))
		"quay":
			if not progress.is_empty() and goal.begins_with("Withdraw the"):
				var roster := _text("Roster")
				var safe := roster.count(": Safe") + roster.count(": Extracted")
				goal = "Withdraw to upper quay · %d/3 groups clear" % safe
		"rescue":
			if _text("Pressure").begins_with("Rescue complete"):
				goal = "Rescue complete · Both crews safe"
			elif not progress.is_empty():
				goal = "Rescue both crews · Lines %d/2 · Crews safe %d/2" % [
					progress.count("line: Rigged"), progress.count("crew: Safe")]
			else:
				goal = _entry[5]
		"chart":
			var shore := _text("Shore")
			if shore.begins_with("Both readings acknowledged"):
				goal = "Survey complete · Both readings acknowledged"
			elif shore.begins_with("Survey failed"):
				goal = "Survey failed"
			elif shore.contains("Signaling"):
				goal = shore
			elif not progress.is_empty():
				var readings := progress.count(": recorded")
				goal = "Record both readings · %d/2" % readings if readings < 2 else "Signal both readings to the cutter"
			else:
				goal = _entry[5]
		"launches":
			if goal.begins_with("Bring both"):
				var groups := _text("Status").get_slice(" Launch", 0)
				goal = "Evacuate both households · %d/2 safe" % groups.count(": Safe")
		"workgroups":
			if goal.begins_with("Mouth group:"):
				goal = "Evacuate both groups · " + goal.replace("Mouth group:", "Mouth:").replace("Bend group:", "Bend:")
		"greyhollow":
			var status := _text("Status")
			if status.contains("to withdraw"):
				goal += " · " + status.split(" · ")[-1]
		"cut":
			goal = _cut_goal(progress)
	var context := _proximity_cue()
	if context.is_empty():
		context = _best_authored_cue(goal)
	return {"objective": _shorten(goal, MAX_OBJECTIVE), "context": _shorten(context, MAX_CONTEXT)}


func _cart_progress(raw: String) -> String:
	return raw.replace("Blocked by rival reserve", "Blocked").replace("Upper-well cart:", "Upper:").replace("Lower-well cart:", "Lower:")


func _cut_goal(account: String) -> String:
	var pressure := _text("Pressure")
	var bundle := _text("Bundle")
	if pressure == "Account filed and records secured":
		return "Account filed and records secured"
	if pressure in ["Sereth fell", "Records extracted"]:
		return pressure
	if bundle.contains("Taken by March"):
		return "Intercept the carrier and recover the records"
	if bundle.contains("Dropped and recoverable"):
		return "Recover the dropped records bundle"
	if account.contains("Unheard"):
		return "Hear Iren's account at the cemetery stair"
	if account.contains("Heard:"):
		return "Relay Iren's account to the clerk"
	if bundle.contains("Carried by Sereth"):
		return "Secure the records bundle in the record room"
	if bundle.contains("Exposed"):
		return "Recover the records bundle below the stair"
	return _entry[5]


func _best_authored_cue(goal: String) -> String:
	var fallback := ""
	for name: String in _entry[2]:
		var text := _without_retry(_text(name))
		if text.is_empty() or text == goal:
			continue
		if text.begins_with("Cross / Space:") or text.begins_with("Hold Cross / Space") or text.begins_with("Release L2 / Shift"):
			return text
		if fallback.is_empty():
			fallback = text
	# Physical pressure or a newly closed path is more useful than generic help.
	if _mission_id == "mara_moonwash_quay":
		var route := _text("Route")
		if route.contains("closed") or route.contains("cracking"):
			return route
		var levy := _text("Levy")
		if not levy.is_empty():
			return levy
	elif _mission_id == "orc_well_road":
		var cue := _text("Cue")
		if _text("Status").contains("Awaiting households") and _host.get("selected_cart") == 1:
			return "Take Raska to the lower storehouse. Cross / Space boards the households."
		if cue.begins_with("Salt road is shorter"):
			return "Wash is covered. To brace, aim and Hold Brace Infantry at Salt Charge Gate before riders mobilize."
	elif _mission_id == "ilyra_moonwash_rescue":
		var pressure := _text("Pressure")
		if pressure.contains("contested") or pressure.contains("approaching"):
			return pressure
	elif _mission_id == "sereth_voices_at_the_cut" or _mission_id == "sereth_no_proxy":
		var pressure := _text("Pressure")
		if not pressure.is_empty() and pressure != goal:
			return pressure
	return fallback


# Some authored readouts only mention the key generically. Query the actual
# existing read-only trigger there rather than inventing a new hotspot or key.
func _proximity_cue() -> String:
	if _mission_id not in ["orc_well_road", "sova_public_record", "ilyra_spanwater_evacuation", "neris_cairnspine_survey", "sereth_voices_at_the_cut"]:
		return ""
	if not is_instance_valid(_host) or not _host.is_node_ready() or _host.get("command_view") == true:
		return ""
	if not _host.has_method("hero_world_position"):
		return ""
	var hero: Vector3 = _host.call("hero_world_position")
	match _mission_id:
		"orc_well_road":
			var door: Variant = _host.get("_door")
			if _text("Status").contains("Awaiting households") and door is Vector3 and hero.distance_to(door) <= 2.8:
				return "Cross / Space: board the lower-storehouse households."
		"sova_public_record":
			if _source_text(_primary).begins_with("Choose") and _host.has_method("_nearby_lectern") and int(_host.call("_nearby_lectern", hero)) != 0:
				return "Cross / Space: choose this lectern."
		"ilyra_spanwater_evacuation":
			var cue := _text("Cue")
			if not cue.begins_with("LANDING CLOSED") and _source_text(_primary).begins_with("Bring both") and _host.has_method("_called_group") and int(_host.call("_called_group")) != 0:
				return "Cross / Space: call these households to the landing."
		"neris_cairnspine_survey":
			var stage: Variant = _host.get("stage")
			var beacons: Variant = _host.get("_beacons")
			if stage is int and stage >= 0 and stage < 3 and beacons is Array and stage < beacons.size() and _host.has_method("_watch_has_sight") and not _host.call("_watch_has_sight", hero):
				if hero.distance_to(beacons[stage].global_position) <= 2.45:
					return ["Cross / Space: inspect the wheel marks.", "Cross / Space: inspect the freight slate.", "Cross / Space: report from the eastern turn-off."][stage]
		"sereth_voices_at_the_cut":
			var pressure := _text("Pressure")
			if pressure not in ["Account filed and records secured", "Sereth fell", "Records extracted"] and _host.has_method("_interaction_at"):
				# Actual Cut.Interaction order: NONE, LISTEN, RELAY, PICK UP, SECURE.
				var prompts := ["", "Cross / Space: listen to Iren.", "Cross / Space: relay Iren's account.", "Cross / Space: take the records bundle.", "Cross / Space: secure the records."]
				var action := int(_host.call("_interaction_at", hero))
				if action > 0 and action < prompts.size():
					return prompts[action]
	return ""


func _text(label_name: String) -> String:
	var label := _labels.get(label_name) as Label
	if not is_instance_valid(label) or (label_name == "Levy" and not label.visible):
		return ""
	return _source_text(label)


func _source_text(label: Label) -> String:
	var text := label.text.strip_edges().replace("\n", " · ").replace("\t", " ")
	while text.contains("  "):
		text = text.replace("  ", " ")
	# These are not part of any mapped dynamic goal. Guard against a developer
	# replacing an exported label value with a preview-only sentinel later.
	if text.to_lower().contains("prototype") or text.to_lower().contains("debug"):
		return ""
	return text


func _without_retry(text: String) -> String:
	for suffix in [" Restart", " Use Restart", " Backspace / Options", " Options / Backspace"]:
		var at := text.find(suffix)
		if at >= 0:
			text = text.left(at).strip_edges()
	var lower := text.to_lower()
	if lower.begins_with("restart") or lower.begins_with("use restart") or lower.begins_with("backspace / options"):
		return ""
	return text


func _shorten(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	var shortened := text.left(limit - 1)
	var end := shortened.rfind(" ")
	return shortened.left(end if end > 0 else shortened.length()).rstrip(" .,;·") + "…"


func _build_row() -> void:
	var layer := CanvasLayer.new()
	layer.name = &"MissionObjectiveActions"
	layer.layer = ROW_LAYER
	add_child(layer)
	_row = HBoxContainer.new()
	_row.name = &"Actions"
	_row.anchor_right = 1.0
	_row.anchor_top = 0.726
	_row.anchor_bottom = 0.726
	_row.offset_bottom = 40.0
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 20)
	layer.add_child(_row)
	for source: Button in _sources:
		var proxy := Button.new()
		proxy.name = StringName("Action" + String(source.name))
		proxy.focus_mode = Control.FOCUS_NONE
		proxy.flat = true
		proxy.custom_minimum_size.y = 34.0
		proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		proxy.add_theme_font_size_override("font_size", 20)
		proxy.add_theme_color_override("font_color", Color("#f4dfad"))
		proxy.add_theme_color_override("font_hover_color", Color("#fff3d2"))
		proxy.add_theme_color_override("font_pressed_color", Color("#ffd282"))
		proxy.add_theme_color_override("font_disabled_color", Color("#a79b80"))
		proxy.add_theme_color_override("font_outline_color", Color("#171612"))
		proxy.add_theme_constant_override("outline_size", 4)
		proxy.pressed.connect(_forward.bind(source))
		_row.add_child(proxy)
		_mirrors.append(proxy)


func _source_visible(source: Button) -> bool:
	var current: Node = source
	while current != _panel and current != null:
		if current is CanvasItem and not current.visible:
			return false
		current = current.get_parent()
	if current != _panel:
		return false
	var layer := _panel.get_parent() as CanvasLayer
	return layer == null or layer.visible


func _refresh_row() -> void:
	if _row == null:
		return
	var paused := get_tree() != null and get_tree().paused
	_row.visible = not paused
	for i in range(_mirrors.size()):
		var source := _sources[i]
		var proxy := _mirrors[i]
		if not is_instance_valid(source):
			proxy.hide()
			continue
		proxy.visible = _source_visible(source)
		proxy.disabled = source.disabled or paused
		proxy.text = source.text
		proxy.tooltip_text = source.tooltip_text


func _forward(source: Button) -> void:
	if not is_instance_valid(source) or source.disabled or not _source_visible(source) or get_tree().paused:
		return
	source.pressed.emit()
	_refresh_row()

