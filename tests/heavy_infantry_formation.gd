extends Node3D

const REGULAR := "res://assets/models/human_infantry.glb"
const HEAVY := "res://assets/models/human_heavy_infantry.glb"
const FIT_CLIP := &"Shield Fit Test"

const WARMUP_FRAMES := 20
const SAMPLE_FRAMES := 60


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var tree := get_tree()
	var window := tree.root
	var args := OS.get_cmdline_user_args()
	var unit := "heavy" if args.is_empty() else args[0]
	if unit not in ["heavy", "heavy-animated", "regular"] or args.size() > 2:
		push_error("Expected heavy, heavy-animated, or regular, followed by an optional PNG output path.")
		tree.quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Run the render comparison with a display and a 3D renderer.")
		tree.quit(1)
		return
	var model := load(REGULAR if unit == "regular" else HEAVY) as PackedScene
	if model == null:
		tree.quit(1)
		return

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = Vector2i(1024, 640)
	window.mesh_lod_threshold = 0.0
	_set_studio()
	var geometry: Dictionary
	var soldier_count := 0
	for side in [-1, 1]:
		for rank in range(4):
			for file in range(8):
				var soldier := model.instantiate() as Node3D
				var facing := -float(side) * PI / 2.0
				soldier.rotation.y = facing
				soldier.position = Vector3(
					float(side) * (1.8 + 1.38 * rank), 0.0, (file - 3.5) * 1.12
				)
				add_child(soldier)
				if unit == "heavy-animated":
					var players := soldier.find_children("*", "AnimationPlayer", true, false)
					if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(FIT_CLIP):
						push_error("The Heavy Infantry model is missing the shield fit clip.")
						tree.quit(1)
						return
					var player := players[0] as AnimationPlayer
					var clip := player.get_animation(FIT_CLIP)
					clip.loop_mode = Animation.LOOP_LINEAR
					player.play(FIT_CLIP)
					player.seek(clip.length * soldier_count / 64.0, true)
				soldier_count += 1
				if geometry.is_empty():
					geometry = _model_geometry(soldier)

	for frame in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	var samples := PackedFloat64Array()
	var draws := PackedInt32Array()
	var previous := Time.get_ticks_usec()
	for frame in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		draws.append(int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	samples.sort()
	draws.sort()
	var result := {
		"unit": unit, "instances": soldier_count, "per_model": geometry,
		"viewport": str(window.get_visible_rect().size), "warmup": WARMUP_FRAMES,
		"samples": SAMPLE_FRAMES, "frame_ms_median": (samples[(SAMPLE_FRAMES - 1) / 2] + samples[SAMPLE_FRAMES / 2]) / 2.0,
		"frame_ms_p95": samples[ceili(0.95 * SAMPLE_FRAMES) - 1],
		"scene_draw_calls_median": draws[SAMPLE_FRAMES / 2],
		"backend": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().get("string"),
	}
	print("FORMATION ", JSON.stringify(result))
	if args.size() == 2:
		var error := window.get_texture().get_image().save_png(args[1])
		if error != OK:
			push_error("Could not save formation image. " + error_string(error))
			tree.quit(1)
			return
	# Running the scene with F6 leaves the formation open for inspection.
	if not args.is_empty():
		tree.quit()


func _model_geometry(model: Node3D) -> Dictionary:
	var triangles := 0
	var vertices := 0
	var surfaces := 0
	var materials := {}
	var instances := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		instances.append(model)
	for item in instances:
		var instance := item as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh == null or not instance.is_visible_in_tree():
			continue
		for index in mesh.get_surface_count():
			surfaces += 1
			vertices += mesh.surface_get_array_len(index)
			var indices := mesh.surface_get_array_index_len(index)
			triangles += (indices if indices > 0 else mesh.surface_get_array_len(index)) / 3
			materials[instance.get_active_material(index)] = true
	return {"triangles": triangles, "vertices": vertices, "surfaces": surfaces,
		"materials": materials.size()}


func _set_studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.21, 0.23)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.76, 0.81, 0.85)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.30, 0.33, 0.33)
	clay.roughness = 1.0
	plane.material = clay
	ground.mesh = plane
	add_child(ground)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -34, 0)
	key.light_color = Color(1.0, 0.96, 0.89)
	key.light_energy = 1.15
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 45
	add_child(key)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	add_child(camera)
	camera.position = Vector3(11.0, 10.0, 16.0)
	camera.look_at(Vector3(0, 0.65, 0))
	camera.current = true
