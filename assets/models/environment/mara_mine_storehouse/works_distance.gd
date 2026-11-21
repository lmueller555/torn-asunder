extends MeshInstance3D
## Opt-in only. One actual renderer and one retained shadow caster, not two
## overlapping levels or a fade that turns a blocked wall transparent.

const NEAR_SPAN := 46.0
const FAR_SPAN := 54.0

var _near: ArrayMesh
var _far: ArrayMesh
var using_far := false


func configure(near_mesh: ArrayMesh,far_mesh: ArrayMesh) -> void:
	_near = near_mesh
	_far = far_mesh
	mesh = _near
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _process(_delta: float) -> void:
	if visible:
		update_for_camera(get_viewport().get_camera_3d())


func update_for_camera(camera: Camera3D) -> void:
	if camera == null or _near == null:
		return
	var span := camera.size
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		var depth := -(camera.global_basis.z.dot(to_global(Vector3.UP*2.2)-camera.global_position))
		span = 2.0*maxf(0.0,depth)*tan(deg_to_rad(camera.fov)*.5)
	# Godot measures FOV / size along the fixed aspect axis. Normalize to
	# vertical span before applying thresholds; smaller means visually closer.
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		var screen := camera.get_viewport().get_visible_rect().size
		span *= screen.y / maxf(1.0,screen.x)
	if using_far and span <= NEAR_SPAN:
		using_far = false
		mesh = _near
	elif not using_far and span >= FAR_SPAN:
		using_far = true
		mesh = _far
