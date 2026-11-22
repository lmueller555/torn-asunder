extends Node3D
signal presentation_camera_changed
const Relief := preload("res://game/overworld/spanwater/spanwater_relief.gd")
const World := preload("res://game/campaign_world.gd")
## The existing planked southern landing is at deck height 1.515m.
const LANDING_POINT := Vector3(114.0, 1.52, 25.0)
var _zoomed := false
@onready var _camera: Camera3D = $Camera

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#acbcc5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d9e8")
	env.ambient_light_energy = .35
	env.fog_enabled = true
	env.fog_light_color = Color("#a8bac8")
	env.fog_density = .00051
	$WorldEnvironment.environment = env
	_place_camera()

func configure_overworld_art(_world: World, _clears: PackedStringArray, _reduced: bool) -> void:
	pass

func show_party_state(_moving: bool, _selected: String) -> void:
	pass

func toggle_zoom(_point: Vector3) -> void:
	_zoomed = not _zoomed
	_place_camera()

func _place_camera() -> void:
	_camera.fov = 58 if _zoomed else 52
	_camera.position = Vector3(175,43,66) if _zoomed else Vector3(230,122,119)
	_camera.look_at(Vector3(105,1,23) if _zoomed else Vector3(48,2,-10))
	presentation_camera_changed.emit()

func probe_south_landing() -> bool:
	var south := get_node_or_null("SpanwaterRelief/SurveyAnchors/LowLanding") as Marker3D
	var north := get_node_or_null("SpanwaterRelief/SurveyAnchors/SpillwayWheel") as Marker3D
	var source := get_node_or_null("SpanwaterRelief") as Relief
	var timber := get_node_or_null("SpanwaterRelief/Timber") as MultiMeshInstance3D
	if not south or not north or not source or not timber or not timber.multimesh or position != Vector3.ZERO:
		return false
	if south.position.z <= 0 or north.position.z >= 0 or LANDING_POINT.distance_to(south.position) > 12.0:
		return false
	# Confirm an actual timber tread beneath the anchor rather than a naked float.
	for plank: Transform3D in source._layers.get("Timber", []):
		if absf(plank.origin.x-LANDING_POINT.x) < .1 and absf(plank.origin.z-LANDING_POINT.z) < .3 \
				and absf(plank.origin.y+plank.basis.y.length()*.5-LANDING_POINT.y)<.04:
			return true
	return false
