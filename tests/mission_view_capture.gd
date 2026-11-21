extends SceneTree
## Renders a campaign mission and saves screenshots. Needs a display (or xvfb-run).
## godot --script tests/mission_view_capture.gd -- <mission_id> <seconds> <output.png> [command]

const View := preload("res://game/mission/mission_view.tscn")
const Autopilot := preload("res://tests/mission_autopilot.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mission_id: String = args[0] if args.size() > 0 else "mara_mine_escort"
	var seconds := float(args[1]) if args.size() > 1 else 6.0
	var output: String = args[2] if args.size() > 2 else "user://mission.png"
	var command := args.size() > 3 and args[3] == "command"
	root.size = Vector2i(1440, 810)
	var view = View.instantiate()
	view.mission_id = mission_id
	root.add_child(view)
	var pilot := Autopilot.new(view.battle)
	var frames := int(seconds * 60.0)
	for i in range(frames):
		pilot.drive()
		view.paused = true
		view.battle.step(1.0 / 60.0)
		view.paused = false
		await physics_frame
	if command:
		view.command_mode = true
		view.cursor = view.battle.hero.position + Vector2(0, -20)
		for i in range(40):
			await process_frame
	for i in range(3):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(output)
	print("saved ", output)
	quit()
