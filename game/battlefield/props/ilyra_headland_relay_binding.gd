extends Node
## Mount only Ilyra's Headland Relay skin; keep both original solids.

const STAND := preload("res://assets/models/environment/ilyra_headland_relay/headland_relay.glb")
const ILYRA_SURVEY := "res://game/battlefield/ilyra_coast_survey_campaign.tscn"
const SHORE := "res://game/battlefields/moonwash_survey_shore.tscn"


func _ready() -> void:
	var mission := get_parent()
	if not mission or mission.scene_file_path != ILYRA_SURVEY:
		return
	if mission.is_node_ready():
		_bind(mission)
	else:
		mission.ready.connect(_bind.bind(mission), CONNECT_ONE_SHOT)


func _bind(mission: Node) -> void:
	var field := mission.get_node_or_null(^"MoonwashSurveyShore")
	if not field or field.scene_file_path != SHORE:
		return
	var pole := field.get_node_or_null(^"Geometry/Headlands/HighSignalStand") as StaticBody3D
	var flag := field.get_node_or_null(^"Geometry/Headlands/HighFlag") as StaticBody3D
	if not pole or not flag or pole.has_node(^"HeadlandRelayArt"):
		return
	var pole_mesh := pole.get_node_or_null(^"Mesh") as MeshInstance3D
	var flag_mesh := flag.get_node_or_null(^"Mesh") as MeshInstance3D
	if not pole_mesh or not flag_mesh:
		return
	var art := STAND.instantiate() as Node3D
	if not art:
		return
	var mesh := art.get_node_or_null(^"HeadlandRelayVisual") as MeshInstance3D
	if not mesh or not mesh.mesh or mesh.mesh.get_surface_count() != 1:
		art.free()
		return
	art.name = &"HeadlandRelayArt"
	pole.add_child(art)
	pole_mesh.hide()
	flag_mesh.hide()
