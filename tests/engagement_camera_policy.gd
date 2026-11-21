extends SceneTree

const CameraPolicy := preload("res://game/battlefield/engagement_camera_policy.gd")

var _failures := 0


func _initialize() -> void:
	var camera := CameraPolicy.new(&"hero")
	camera.set_active_platoons([&"hero", &"shield", &"bow"])
	var waypoint := Vector2(64.0, -32.0)
	camera.set_tactical_cursor(waypoint)
	_check(camera.mode() == CameraPolicy.Mode.TACTICAL and camera.follow_platoon().is_empty(),
			"The unengaged selection uses the terrain cursor, not a moving platoon.")
	camera.observe_engaged(&"shield", true)
	camera.observe_engaged(&"bow", true)
	_check(camera.mode() == CameraPolicy.Mode.TACTICAL,
			"Unselected fights do not steal the player's camera.")
	camera.cycle(1)
	_check(camera.selected_id() == &"shield" and camera.mode() == CameraPolicy.Mode.PLATOON_FOLLOW
			and camera.follow_platoon() == &"shield" and camera.accepts_formation_orders()
			and not camera.accepts_direct_hero_input(),
			"Cycling onto a fighting ally follows it without taking away orders.")
	camera.cycle(1)
	_check(camera.follow_platoon() == &"bow", "Cycling retargets to the other engaged platoon.")
	camera.observe_engaged(&"hero", true)
	_check(camera.mode() == CameraPolicy.Mode.PLATOON_FOLLOW, "Hero combat cannot interrupt a different selection.")
	camera.cycle(1)
	_check(camera.mode() == CameraPolicy.Mode.HERO_ACTION and camera.follow_platoon() == &"hero"
			and camera.accepts_direct_hero_input() and not camera.accepts_formation_orders(),
			"Only selecting the engaged hero grants the action camera and direct fighting.")
	camera.cycle(-1)
	_check(camera.mode() == CameraPolicy.Mode.PLATOON_FOLLOW and camera.tactical_cursor() == waypoint,
			"Cycling out during combat preserves the previously placed terrain cursor.")
	camera.observe_engaged(&"bow", false)
	_check(camera.mode() == CameraPolicy.Mode.TACTICAL and camera.tactical_cursor() == waypoint
			and camera.accepts_formation_orders(), "Disengagement returns to the same tactical cursor.")
	_check(not camera.select(&"unknown") and camera.selected_id() == &"bow",
			"Invalid selection does not move the camera.")
	camera.set_active_platoons([&"shield", &"hero", &"shield", &""])
	_check(camera.selected_id() == &"shield" and camera.mode() == CameraPolicy.Mode.PLATOON_FOLLOW,
			"Removing the selected platoon falls back to the first live entry.")
	camera.cycle(1)
	_check(camera.selected_id() == &"hero" and camera.accepts_direct_hero_input(),
			"Selection cycles over unique living platoons only.")
	camera.set_active_platoons([])
	camera.observe_engaged(&"hero", true)
	_check(camera.mode() == CameraPolicy.Mode.TACTICAL and not camera.accepts_formation_orders()
			and not camera.accepts_direct_hero_input(), "An empty roster accepts neither hero action nor orders.")
	camera.set_active_platoons([&"hero"])
	camera.set_tactical_cursor(Vector2.INF)
	_check(camera.mode() == CameraPolicy.Mode.TACTICAL and camera.tactical_cursor() == waypoint,
			"Restored identities do not inherit stale engagement, and invalid cursor motion is ignored.")
	if _failures == 0:
		print("Engagement camera: stable selection, non-hero follow, hero action, tactical return and live roster passed.")
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
