extends Node3D
signal presentation_camera_changed
const World := preload("res://game/campaign_world.gd")
const Valley := preload("res://game/overworld/sereth/sereth_y5_relief.gd")
const MARK_XZ := Vector2(-158.6,-4.7)
const ARRIVAL := Vector3(-158.6,.471334,-4.7)
const Neutral := preload("res://game/overworld/sereth_neutral_contract.gd")
var relief: Valley
var _zoomed:=false
var bank: MeshInstance3D
@onready var _camera: Camera3D = $Camera

func _ready() -> void:
	relief=Valley.new()
	relief.name="UnoccupiedValley"
	add_child(relief)
	bank=relief.get_node("SurveyRelief") as MeshInstance3D
	if bank:
		bank.create_trimesh_collision()
		for child in bank.get_children():
			if child is StaticBody3D:
				child.collision_layer=2
				child.collision_mask=0
	_place_lens()

func arrival_verified() -> bool:
	if not is_node_ready() or not Neutral.mounted(relief,bank):
		return false
	var hit := bank.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(ARRIVAL+Vector3.UP*7.,ARRIVAL-Vector3.UP*6.,2))
	return not hit.is_empty() and hit.collider.get_parent()==bank and absf(ARRIVAL.y-hit.position.y-.39)<.008

func configure_overworld_art(_world: World,_clears: PackedStringArray,_reduced: bool) -> void:
	pass

func show_party_state(_moving: bool,_selected: String) -> void:
	pass

func toggle_zoom(_target: Vector3) -> void:
	_zoomed=not _zoomed
	_place_lens()

func _place_lens() -> void:
	# Sereth arrives outside the open western mouth. Read the quiet court
	# and approach together, not the downstream custody/forecourt.
	_camera.fov=44. if _zoomed else 52.
	_camera.position=Vector3(-173.,28.,43.) if _zoomed else Vector3(-218.,92.,124.)
	_camera.look_at(Vector3(-143.,1.1,-.2) if _zoomed else Vector3(-166.,2.,-1.))
	presentation_camera_changed.emit()
