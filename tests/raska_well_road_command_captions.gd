extends "res://tests/raska_well_road_brace.gd"
## The caption seam must follow the real mounted pass and leave hero, orders and cart captions intact.

func _run() -> void:
	_mission = Scene.instantiate() as Mission
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	var friendly := _mission._brace_banner
	var reserve := _mission._rival._banner
	_check(friendly != null and reserve != null, "Keep the original two world labels.")
	if _failures > 0:
		quit(1)
		return
	var open_origin := _stock(friendly, reserve)
	_march_to_gate()
	_face_and_hold(true)
	_tick(41)
	_check(not _mission._command_captions_active and _stock(friendly,reserve) == open_origin,
		"Arming alone must not change untargeted captions.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0)
	_key(KEY_G)
	_wait(func() -> bool: return _mission._carts[UPPER].waiting_on == "Mounted pass", 700)
	var gate := _marker("Routes/SaltChargeGate")
	# Reuse the actual hero position as command sector focus rather than changing camera range.
	_mission.battle.hero_position = _xz(gate) + Vector2(2.6, 2.8)
	for phase in ["warning", "contact", "regroup"]:
		match phase:
			"warning":
				_check(_mission._pass_stage == Stage.ARMED and _mission._rival.status == Mission.Rival.Status.MARCHING,
					"Inputs produce the real warning phase.")
			"contact":
				_wait(func() -> bool: return _mission._pass_stage == Stage.RUNNING 					and _mission._rival.global_position.distance_to(gate) < 5.8, 2700)
				_check(_mission._pass.result == Pass.Result.NONE, "Actual reserve nears contact without fake impact.")
			"regroup":
				_wait(func() -> bool: return _mission._pass.phase == Pass.Phase.REGROUPING, 500)
				_check(_mission._pass.result == Pass.Result.REPELLED, "Original frontal impact still succeeds.")
		var before := _truth(friendly, reserve)
		_check(not _mission._command_captions_active and _stock(friendly, reserve) == open_origin,
			"Hero view must retain the exact stock captions through all phases.")
		_axis(JOY_AXIS_TRIGGER_LEFT, 1)
		for overview in [false, true]:
			if overview:
				_button(JOY_BUTTON_RIGHT_STICK)
			for alternate in [false, true]:
				_mission._command_yaw = deg_to_rad(115.0) if alternate else 0.0
				_mission._command_pitch = deg_to_rad(73.0) if alternate else deg_to_rad(59.0)
				_mission._update_cameras()
				_mission._sync_view()
				_check(_mission._command_captions_active and friendly.visible and reserve.visible
					and _truth(friendly, reserve) == before and _mission._selection.visible,
					"Keep true identity, the warning/status, selection ring, and original wagon labels.")
				var camera := _mission._command_camera
				var a := _label_rect(friendly, camera)
				var b := _label_rect(reserve, camera)
				var line := _stock_line(camera)
				_check(a.size.y >= 18.0 and b.size.y >= 18.0, "Tactical caption glyph sizes must remain readable at overview too.")
				_check(not a.intersects(line) and not b.intersects(line) and not a.intersects(b),
					"Both captions must clear the original line and each other after orbit/zoom.")
			if overview:
				_button(JOY_BUTTON_RIGHT_STICK)
		_axis(JOY_AXIS_TRIGGER_LEFT, 0)
		_check(root.get_camera_3d() == _mission._hero_camera and _stock(friendly, reserve) == open_origin,
			"Releasing command must restore the exact stock hero anchors immediately.")
	_key(KEY_BACKSPACE)
	_check(not _mission._command_captions_active and _stock(friendly,reserve) == open_origin,
		"Retry cannot leak tactical caption state.")
	if _failures == 0:
		print("Well Road command captions: actual approach, charge and regroup; orbits/overview; unchanged hero, cue, labels, selection and Retry.")
	quit(0 if _failures == 0 else 1)


func _stock(friendly: Label3D, reserve: Label3D) -> Array:
	return [friendly.position, reserve.position, friendly.pixel_size, reserve.pixel_size]


func _truth(friendly: Label3D, reserve: Label3D) -> Array:
	return [friendly.text, reserve.text, _mission._cue.text, _mission._status.text,
		_mission._carts[UPPER].banner.text, _mission._carts[LOWER].banner.text,
		_mission.selected_cart, _mission.selected_index, _mission.battle.formations[0].heading]


func _label_rect(label: Label3D, camera: Camera3D) -> Rect2:
	var font_used := ThemeDB.fallback_font if label.font == null else label.font
	var shape := font_used.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	shape += Vector2.ONE * label.outline_size
	shape *= (label.pixel_size * root.get_visible_rect().size.y / camera.size)
	var center := camera.unproject_position(label.global_position)
	return Rect2(center - shape * 0.5, shape)


func _stock_line(camera: Camera3D) -> Rect2:
	var origin := camera.unproject_position(_mission._formation_models[0].global_position)
	var envelope := Rect2(origin, Vector2.ZERO)
	for anchor in _mission._formation_members[0]:
		for child in anchor.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null:
				continue
			var bound := mesh.get_aabb()
			for i in range(8):
				envelope = envelope.expand(camera.unproject_position(mesh.to_global(bound.get_endpoint(i))))
	return envelope
