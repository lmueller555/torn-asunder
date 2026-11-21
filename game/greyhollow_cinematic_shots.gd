extends TextureRect
## Isolated cutscene camera on the unchanged Year One field, never a battle instance.
## No units, custody case, mission state, or interactable props are added here.

const FIELD := "res://game/battlefields/year_one_mine_campaign.tscn"
const SHOTS := {
	&"outlet": [Vector3(-135, 3.4, 111), Vector3(-115, 2.7, 101), 42.0],
	&"shelter_detail": [Vector3(-128, 2.2, 112), Vector3(-119, 1.45, 100), 36.0],
}

var _camera: Camera3D
var _current := &""


static func supports(shot: StringName) -> bool:
	return shot == &"black" or SHOTS.has(shot)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# A fixed wide render matches the letterbox. Never feed the shared campaign viewport back into itself.
	var picture := SubViewport.new()
	picture.name = "GreyhollowSet"
	picture.size = Vector2i(960, 280)
	picture.own_world_3d = true
	picture.gui_disable_input = true
	picture.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(picture)
	var field := load(FIELD) as PackedScene
	picture.add_child(field.instantiate())

	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("#657371")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("#9aabb2")
	atmosphere.ambient_light_energy = 0.52
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("#737f78")
	atmosphere.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.environment = atmosphere
	picture.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-20, -40, 0)
	sun.light_color = Color("#ffe0ac")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	picture.add_child(sun)

	_camera = Camera3D.new()
	_camera.far = 420.0
	_camera.current = true
	picture.add_child(_camera)
	texture = picture.get_texture()


func frame(shot: StringName) -> bool:
	if not _camera or not supports(shot) or _current == shot:
		return false
	_current = shot
	visible = shot != &"black"
	if not visible:
		return true
	var composition: Array = SHOTS[shot]
	_camera.position = composition[0]
	_camera.look_at(composition[1])
	_camera.fov = composition[2]
	return true
