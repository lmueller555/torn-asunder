extends Node
## Mount only Ilyra's beach relay skin; the scene keeps its original two solids.

const STAND := preload("res://assets/models/environment/ilyra_beach_signal/beach_signal_stand.tscn")
const ILYRA_SURVEY := "res://game/battlefield/ilyra_coast_survey_campaign.tscn"
const SHORE := "res://game/battlefields/moonwash_survey_shore.tscn"


func _ready() -> void:
	var mission := get_parent()
	if not mission or mission.scene_file_path != ILYRA_SURVEY:
		return
	# The harness instantiates the field in the parent mission's _ready().
	if mission.is_node_ready():
		_bind(mission)
	else:
		mission.ready.connect(_bind.bind(mission), CONNECT_ONE_SHOT)


func _bind(mission: Node) -> void:
	var field := mission.get_node_or_null(^"MoonwashSurveyShore")
	if not field or field.scene_file_path != SHORE:
		return
	var pole := field.get_node_or_null(^"Geometry/Beach/BeachSignalStand") as StaticBody3D
	var flag_mesh := field.get_node_or_null(^"Geometry/Beach/BeachFlag/Mesh") as MeshInstance3D
	if not pole or not flag_mesh or pole.has_node(^"BeachSignalStandArt"):
		return
	var pole_mesh := pole.get_node_or_null(^"Mesh") as MeshInstance3D
	if not pole_mesh:
		return
	var art := STAND.instantiate()
	pole.add_child(art)
	if not art.has_node(^"StandVisual"):
		art.queue_free()
		return
	pole_mesh.hide()
	flag_mesh.hide()
