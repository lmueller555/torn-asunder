extends SceneTree
## Smoke test for reviewed character mounts; gameplay, art and clocks are unchanged.
const Deployments := preload("res://game/campaign_deployments.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const PlatoonSize := preload("res://game/combat/platoon_size.gd")
const REGULAR_SCENE := "res://assets/models/human_infantry.glb"
const Step := 1.0 / 60.0
const MISSIONS := ["mara_mine_escort", "mara_grain_crossing", "mara_moonwash_quay"]
var checks := 0
var fails := 0
var output := ""
var stats: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var stock := "--stock" in args
	for arg in args:
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	if not stock and not ResourceLoader.exists("res://assets/models/campaign/humans/mara_halden.glb", "PackedScene"):
		printerr("Missing imported campaign character assets; run Godot --headless --import first.")
		quit(2)
		return
	for id in MISSIONS:
		var d := Deployments.for_mission(id)
		var scene: PackedScene = d.scene
		var host = scene.instantiate()
		root.add_child(host)
		host.set_physics_process(false)
		await physics_frame
		await physics_frame
		var art = host.get_node_or_null("MaraCampaignCharacterArt")
		var expected := not stock
		_check((art != null) == expected, "%s registered presentation presence matches complete stock/asset set" % id)
		_check(_valid_lead_roster(host) and host.battle.formations.size() == 2,
			"%s deploys 30 real regular anchors, two separate officers, one hero and two unchanged subordinate platoons" % id)
		var regular_ids := _anchor_ids(host._lead_members)
		var officer_ids := _anchor_ids(host._lead_officers)
		if art != null:
			art.set_process(false)
			art.set_physics_process(false)
			_check(art._hero.visual.get_parent() == host._hero and art._officers[0].visual.get_parent() == host._lead_officers[0]
				and art._officers[1].visual.get_parent() == host._lead_officers[1], "%s mounts both distinct officer assets outside the regular roster" % id)
			for index in 2:
				var anchor: Node3D = host._lead_officers[index]
				var visible_children := 0
				for child: Node3D in anchor.get_children():
					visible_children += int(child.visible)
				_check(visible_children == 1, "%s officer %d has no visible duplicate" % [id, index])
		_step(host, art, 5)
		var spawn: Vector2 = host.battle.hero_position
		var direction: Vector2 = host.battle.hero_heading
		var target := spawn + direction * 3.0
		if id == "mara_mine_escort":
			var road: Marker3D = host.battlefield_marker(^"Markers/Routes/RoadWest")
			target = spawn.move_toward(host._marker_position(road), 10.0)
		if not host._terrain.can_move(spawn, target, false):
			for candidate in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				var alternative: Vector2 = spawn + candidate * 3.0
				if host._terrain.can_move(spawn, alternative, false):
					target = alternative
					break
		_key(KEY_SHIFT, true)
		_key(KEY_Z, true)
		_key(KEY_Z, false)
		var mouse := InputEventMouseMotion.new()
		mouse.position = host._command_camera.unproject_position(host.to_global(host._ground(target)))
		root.push_input(mouse, true)
		var move := InputEventJoypadButton.new()
		move.button_index = JOY_BUTTON_X
		move.pressed = true
		root.push_input(move, true)
		_check(host.selected_index == Battle.LEAD_INDEX and host.battle.lead.order == Battle.Order.MOVE
			and host.battle.lead.destination.distance_to(target) < 0.25,
			"%s accepted native Lead Move" % id)
		_key(KEY_SHIFT, false)
		_step(host, art, 21)
		_check(host.battle.hero_position.distance_to(spawn) > 0.2, "%s moved through real gameplay" % id)
		if art != null:
			_check(art._hero.clip == &"Run" and art._officers[0].clip == &"Run" and art._officers[1].clip == &"Run",
				"%s movement drives three render-only locomotion states" % id)
		await _capture(id + "-hero-march", host)
		if art != null:
			var old_pose: float = art._hero.pose_time
			var old_gait: StringName = art._hero.clip
			art._process(Step * 0.5)
			art._process(Step * 0.5)
			_check(art._hero.pose_time == old_pose and art._hero.clip == old_gait,
				"%s extra render callbacks cannot turn actual physics locomotion into Idle" % id)
		_step(host, art, 24)
		if art != null and id == "mara_mine_escort":
			_check(host.battle.hero_position.distance_to(spawn) > 3.0 and art._hero.clip == &"Run",
				"Longer native Greyhollow route keeps Run beyond the transition")
		_step(host, art, 100)
		if art != null:
			_check(art._hero.clip == &"Idle" and art._officers[0].clip == &"Idle" and art._officers[1].clip == &"Idle",
				"%s native route stops and all rigs return to Idle" % id)
		_key(KEY_SHIFT, true)
		if art != null:
			art._physics_process(Step)
			art._process(Step)
			var correct_tiers: bool = art._hero.sector_body.visible and not art._hero.near_body.visible
			for officer in art._officers:
				correct_tiers = correct_tiers and officer.sector_body.visible and not officer.near_body.visible
			_check(correct_tiers, "%s command camera selects only Sector body for all three rigs" % id)
		await _capture(id + "-tactical", host)
		for transition: int in [-1, 1, 1]:
			_check(host.step_formation(transition), "%s lead spacing changes from command mode" % id)
			host.battle.step(.5, Vector2.ZERO)
			host._sync_lead_platoon()
			_check(_valid_lead_roster(host), "%s all 32 escorts follow the same spacing and ground ownership" % id)
		_key(KEY_SHIFT, false)
		host.restart_mission()
		host._sync_view()
		host.restart_mission()
		host._sync_view()
		_check(_valid_lead_roster(host) and regular_ids == _anchor_ids(host._lead_members)
			and officer_ids == _anchor_ids(host._lead_officers), "%s repeated Retry retains every exact anchor" % id)
		if art != null:
			art._physics_process(Step)
			art._process(Step)
		_check(host.battle.hero_position.is_equal_approx(spawn) and host.get_node_or_null("MaraCampaignCharacterArt") == art,
			"%s retry restores native spawn without duplicating art" % id)
		host.free()
		await process_frame
	if not stock:
		var standalone = load("res://game/battlefield/mara_grain_crossing_playtest.tscn").instantiate()
		root.add_child(standalone)
		_check(not standalone.has_node("MaraCampaignCharacterArt") and standalone._lead_members.size() == 12
			and standalone._lead_officers.is_empty(), "Standalone Grain preserves original non-campaign escort")
		standalone.free()
	if not output.is_empty():
		var report := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
		if report:
			report.store_string(JSON.stringify(stats, "\t"))
	print("Composition checks ", checks - fails, "/", checks, " successful (visual review separate)")
	quit(1 if fails else 0)

func _valid_lead_roster(host) -> bool:
	var lead: Battle.Formation = host.battle.lead
	if host._lead_members.size() != PlatoonSize.REGULAR_MELEE or lead.members.size() != PlatoonSize.REGULAR_MELEE \
			or host._lead_officers.size() != 2 or host._hero.get_parent() == host._lead_model:
		return false
	var seen: Dictionary = {}
	var files: Dictionary = {}
	var ranks: Dictionary = {}
	if lead.leader != null:
		return false
	for slot: Battle.Member in lead.members:
		var regular: Node3D = host._lead_members[slot.index]
		var expected := lead.member_offset(slot)
		var local := Vector2(regular.position.x, regular.position.z)
		if seen.has(expected) or not local.is_equal_approx(expected) or regular.get_child_count() != 1:
			return false
		if regular.get_child(0).scene_file_path != REGULAR_SCENE:
			return false
		seen[expected] = true
		files[slot.offset.x] = true
		ranks[slot.offset.y] = true
	if files.size() != PlatoonSize.REGULAR_MELEE_COLUMNS or ranks.size() != PlatoonSize.REGULAR_MELEE_RANKS:
		return false
	for i in 2:
		var officer: Node3D = host._lead_officers[i]
		var expected: Vector2 = Battle.LEAD_OFFICER_OFFSETS[i] * lead.spread
		if seen.has(expected) or not Vector2(officer.position.x, officer.position.z).is_equal_approx(expected):
			return false
		seen[expected] = true
	return seen.size() == 32


func _anchor_ids(anchors: Array[Node3D]) -> Array[int]:
	var ids: Array[int] = []
	for anchor: Node3D in anchors:
		ids.append(anchor.get_instance_id())
	return ids


func _step(host, art, ticks: int) -> void:
	for i in ticks:
		host._physics_process(Step)
		if art != null:
			art._physics_process(Step)
			art._process(Step)

func _capture(name: String, host) -> void:
	if output.is_empty():
		return
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame != null and not frame.is_empty() and frame.save_png(output.path_join(name + ".png")) == OK, "Captured " + name)
	stats[name] = {"camera": str(root.get_camera_3d().global_transform), "hero": str(host.battle.hero_position),
		"viewport_px": str(frame.get_size()),
		"draws": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"triangles": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
	print(name, " ", stats[name])

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	root.push_input(event, true)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("OK: ", message)
	else:
		fails += 1
		printerr("FAILED: ", message)
