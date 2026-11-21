extends Node
## This scene-specific visual binding does not own the wheel objective or terrain.

const WHEEL_ART := preload("res://assets/models/environment/raska_spillway_wheel/spillway_wheel.tscn")
const LOCK_PATH := ^"SpanwaterLockCampaign/Geometry/Lock"
const RASKA_FINALE := "res://game/battlefield/raska_spanwater.tscn"
const OLD_PRESENTATION := [
	^"WheelPedestal/Mesh", ^"SpillwayWheelModel", ^"WheelSpoke30", ^"WheelSpoke90", ^"WheelSpoke150",
]


func _ready() -> void:
	var mission := get_parent()
	if not mission or mission.scene_file_path != RASKA_FINALE:
		return
	# The mission creates its battlefield during its own _ready().
	if mission.is_node_ready():
		_bind(mission)
	else:
		mission.ready.connect(_bind.bind(mission), CONNECT_ONE_SHOT)


func _bind(mission: Node) -> void:
	var lock := mission.get_node_or_null(LOCK_PATH)
	if not lock:
		return
	var support := lock.get_node_or_null(^"WheelPedestal") as StaticBody3D
	if not support or support.has_node(^"SpillwayWheelArt"):
		return
	var old_meshes: Array[MeshInstance3D] = []
	for path in OLD_PRESENTATION:
		var mesh := lock.get_node_or_null(path) as MeshInstance3D
		if not mesh:
			return
		old_meshes.append(mesh)
	support.add_child(WHEEL_ART.instantiate())
	for mesh in old_meshes:
		mesh.hide()
