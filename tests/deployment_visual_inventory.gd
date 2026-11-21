extends SceneTree
## Exercise the CLI against registered scenes, not a synthetic list of paths.

const ROOT_SCRIPT := "res://tools/inventory_deployment_visuals.gd"
const SHORE := "res://game/battlefields/moonwash_survey_shore.tscn"
const BEACH_ART := "res://assets/models/environment/ilyra_beach_signal/beach_signal_stand.tscn"
const WHEEL_ART := "res://assets/models/environment/raska_spillway_wheel/spillway_wheel.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var complete := _query()
	var missions := {}
	for row in complete.get("deployments", []):
		if missions.has(row.mission_id) or row.nodes.is_empty():
			quit(1)
			return
		missions[row.mission_id] = row.nodes
	var selected := _query(["ilyra_coast_survey"])
	var matches: Array = selected.get("deployments", [])
	var beach: Array = matches[0].nodes if matches.size() == 1 and matches[0].mission_id == "ilyra_coast_survey" else []
	var stand := _find(beach, "StandVisual", BEACH_ART)
	var discarded := _find(beach, "BeachFlag/Mesh", SHORE)
	var original := _find(missions.get("ilyra_spanwater_evacuation", []), "SpillwayWheelModel",
		"res://game/battlefields/spanwater_lock_campaign.tscn")
	var wheel := _find(missions.get("orc_spanwater_release", []), "SpillwayWheelArt/Near", WHEEL_ART)
	var shadow := _find(missions.get("orc_spanwater_release", []), "SpillwayWheelArt/WheelShadowProxy", WHEEL_ART)
	var infantry := _find(missions.get("mara_mine_escort", []), "Infantry Body", "res://assets/models/human_infantry.glb")
	var valid: bool = (missions.size() == 18 and complete.get("deployment_count", 0) == 18
		and not stand.is_empty() and not stand.scene_owned and stand.visible_in_tree
		and "res://assets/models/environment/ilyra_beach_signal/beach_signal_stand.gdshader" in stand.resource_paths
		and not discarded.is_empty() and discarded.scene_owned and not discarded.visible_in_tree
		and not wheel.is_empty() and not original.is_empty() and original.visible_in_tree
		and not shadow.is_empty() and shadow.shadow_only
		and not infantry.is_empty() and infantry.visible_in_tree)
	var rejected: Array[String] = []
	var unknown := OS.execute(OS.get_executable_path(), ["--headless", "--no-header", "--script",
		ROOT_SCRIPT, "--", "not_a_mission"], rejected, false)
	if valid and unknown == 1 and (rejected.is_empty() or rejected[0].is_empty()):
		print("Opening visual inventory: 18 live deployments, filtered query, hidden originals, active overrides, shadow-only proxy, Infantry reference and unknown mission boundary passed.")
		quit(0)
	else:
		push_error("Opening visual inventory differs from registered Godot placements.")
		quit(1)


func _find(nodes: Array, suffix: String, scene: String) -> Dictionary:
	for node in nodes:
		if node.path.ends_with(suffix) and node.containing_scene == scene:
			return node
	return {}


func _query(selection: PackedStringArray = []) -> Dictionary:
	var output: Array[String] = []
	var args := PackedStringArray(["--headless", "--no-header", "--script", ROOT_SCRIPT])
	if not selection.is_empty():
		args.append("--")
		args.append_array(selection)
	var result := OS.execute(OS.get_executable_path(), args, output, false)
	if result != 0 or output.is_empty():
		return {}
	var payload: Variant = JSON.parse_string(output[0])
	return payload if payload is Dictionary else {}
