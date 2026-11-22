extends SceneTree
## Regression: the exact Greyhollow deployment presents one fighting rank
## without applying damage or changing formation anchors. --compare-stock
## is for running this fixture against a checkout before the presenter.

const Deploy := preload("res://game/campaign_deployments.gd")
const Mission := preload("res://game/battlefield/mara_greyhollow_rescue.gd")
const Mine := preload("res://game/battlefield/mara_mine_escort.gd")
const Size := preload("res://game/combat/platoon_size.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Fight := preload("res://game/battlefield/mara_mine_encounter.gd")
const Infantry := preload("res://game/battlefield/mara_infantry_attack.gd")
const DT := 1.0 / 60.0

var failed := 0
var mission: Mission
var expect_slash := true
var _anchor_roots: Array[Vector3] = []

func _initialize() -> void:
	expect_slash = "--compare-stock" not in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = Deploy.for_mission("mara_mine_escort").scene
	mission = scene.instantiate() as Mission
	root.add_child(mission)
	mission.set_physics_process(false)
	await process_frame
	var fight := mission.encounter
	var group := mission.battle.formations[0]
	var archers := mission.battle.formations[1]
	_check(mission.scene_file_path == "res://game/battlefield/mara_greyhollow_rescue_campaign.tscn", "registered campaign scene")
	_check(group.members.size() == Size.PLATOON_WITH_LEADER and mission._infantry_animators.size() == Size.PLATOON_WITH_LEADER
		and group.leader != null and group.leader.is_leader and group.leader.index == Size.REGULAR_MELEE
		and archers.members.size() == 12, "30 shield rankers, 1 leader and 12 Archer anchors")

	for mode in ["hit", "whiff", "move_cancel", "hold_cancel", "lethal"]:
		mission.restart_mission()
		fight = mission.encounter
		group = mission.battle.formations[0]
		fight.enemy_position = group.position + Vector2(Infantry.STOP_RANGE, 0)
		# Stage the stock Dryad in a clear yard lane, far from Mara and inactive
		# only until the real attack order releases the unchanged pursuit AI.
		mission.battle.hero_position = group.position - Vector2(18, 0.0)
		if mode == "lethal":
			fight.enemy.receive_damage(fight.enemy.hp - 20.0)
		mission._sync_view()
		var previous_tile := group.position
		var prior_hp := fight.enemy.hp
		var prior_bp := fight.points.balance
		_axis(1.0)
		mission.cursor = fight.enemy_position
		_key(KEY_K)
		_check(group.order == Battle.Order.ATTACK, mode + ": actual command accepted")
		var did_hit := false
		_anchor_roots.clear()
		var commit_steps := 0
		var first_tick := -1
		for i in range(64):
			if i == 5:
				if mode == "whiff":
					fight.enemy_position += Vector2(12, 0)
				if mode == "hold_cancel":
					_button(JOY_BUTTON_A)
				if mode == "move_cancel":
					mission.cursor = previous_tile - Vector2(3.0, 0)
					_button(JOY_BUTTON_X)
			if i == 10 and mode in ["hit","lethal"]:
				_axis(0.0)
			var hp := fight.enemy.hp
			var serial: Variant = fight.infantry_attack.get("contact_serial")
			mission._physics_process(DT)
			var observed := fight.enemy.hp < hp
			if expect_slash and fight.infantry_attack.get("contact_serial") != serial:
				commit_steps += 1
				_check_pose("commit", 0.70)
			if observed:
				did_hit = true
				if first_tick < 0:
					first_tick = i
				print("POSE ", mode, " tick=", i, " name=", mission._infantry_animators[0].assigned_animation,
					" time=", mission._infantry_animators[0].current_animation_position)
				if expect_slash:
					_check_pose("damage tick", 0.70)
					_check(root.get_camera_3d() == mission._hero_camera, "camera changed to Mara before contact")
			if expect_slash and i == 0:
				_check_pose("windup entry", 0.0)
			if expect_slash and i == 40 and mode in ["hit", "lethal"]:
				_check_pose("recovery")
				_check(mission._infantry_animators[0].current_animation_position > 0.70,
					"follow-through advances on recovery without another contact")
			if expect_slash and i == 6 and mode in ["move_cancel", "hold_cancel"]:
				_check(mission._infantry_animators[0].assigned_animation != &"Sword Slash", mode + ": slash pose exits")
		_check(did_hit == (mode in ["hit", "lethal"]), mode + ": authoritative damage expectation")
		_check(fight.points.balance - prior_bp == (6 if did_hit else 0),
			mode + ": only the real hit adds the encounter BP reward")
		if expect_slash:
			_check(commit_steps == (0 if mode in ["move_cancel", "hold_cancel"] else 1), mode + ": one authoritative commit or no commit when cancelled")
		print("SIM ", mode, " tick=", first_tick, " enemy=", snappedf(prior_hp - fight.enemy.hp, 0.0001),
			" infantry=", snappedf(fight.infantry_attack.attacker.hp, 0.0001), " bp=", fight.points.balance - prior_bp,
			" order=", group.order, " xy=", group.position, " rescue=", mission.rescue_phase)
		if mode == "lethal":
			for i in range(25):
				mission._physics_process(DT)
			_check(group.order == Battle.Order.HOLD and mission._infantry_animators[0].assigned_animation == &"Idle",
				"completed lethal visual recovery returns to unmodified Hold/Idle")
	_axis(0.0)
	mission.restart_mission()
	_check(mission._infantry_animators[0].assigned_animation == &"Idle", "retry restores original idle")
	if expect_slash:
		_exercise_retry_hold()
	mission.free()

	var heavy := scene.instantiate() as Mine
	_check(heavy.configure_replay_heavy_infantry(true, true), "authorized Heavy variant")
	root.add_child(heavy)
	heavy.set_physics_process(false)
	heavy._after_battle_step(DT)
	_check(heavy._infantry_animators[0].assigned_animation == &"Shield-Ready Idle", "Heavy ready unaffected")
	heavy.free()
	quit(1 if failed else 0)

func _exercise_retry_hold() -> void:
	var previous_battle := mission.battle
	_key(KEY_BACKSPACE) # actual Retry command replaces the battle object
	_check(mission.battle != previous_battle, "actual Retry replaced the battle")
	var order_observer := Callable(mission, "_cancel_shield_slash_on_command")
	_check(not previous_battle.formation_commanded.is_connected(order_observer)
		and mission.battle.formation_commanded.is_connected(order_observer),
		"only the current retry battle sends orders to the regular presenter")
	# Encounter reconfiguration in the same attempt may never double-bind.
	mission._reset_encounter()
	var observer_count := 0
	for item in mission.battle.formation_commanded.get_connections():
		if item.callable == order_observer:
			observer_count += 1
	_check(observer_count == 1, "repeated encounter configuration binds once")
	var group := mission.battle.formations[0]
	var fight := mission.encounter
	fight.enemy_position = group.position + Vector2(Infantry.STOP_RANGE, 0)
	mission.battle.hero_position = group.position - Vector2(18, 0)
	fight.enemy.receive_damage(fight.enemy.hp - 20.0)
	mission._sync_view()
	_axis(1.0)
	mission.cursor = fight.enemy_position
	_key(KEY_K)
	_check(group.order == Battle.Order.ATTACK, "after Retry, actual attack accepted")
	for i in range(60):
		if not fight.enemy.is_alive():
			break
		mission._physics_process(DT)
	_check(not fight.enemy.is_alive() and group.order == Battle.Order.HOLD
		and mission._infantry_animators[0].assigned_animation == &"Sword Slash",
		"real lethal hit leaves gameplay already on HOLD with visual tail active")
	var bp := fight.points.balance
	var contact_number := fight.infantry_attack.contact_serial
	_button(JOY_BUTTON_A) # stationary Hold; no new order state or physics tick
	var immediate_idle := true
	for player in mission._infantry_animators:
		immediate_idle = immediate_idle and player.assigned_animation == &"Idle" and player.root_motion_track.is_empty()
	_check(immediate_idle, "all 31 cancel lethal tail immediately on stationary Hold after Retry")
	_check(fight.points.balance == bp and fight.infantry_attack.contact_serial == contact_number,
		"visual cancellation changes no BP and cannot duplicate committed swings")
	mission._physics_process(DT)
	_check(mission._infantry_animators[0].assigned_animation == &"Idle", "clear tail cannot resume after next physics")
	print("RETRY_HOLD immediate_idle=", immediate_idle, " contact_serial=", contact_number, " bp=", bp)


func _check_pose(stage: String, time := -1.0) -> void:
	var group := mission.battle.formations[0]
	var front := INF
	for member in group.members:
		if not member.is_leader:
			front = minf(front, member.offset.y)
	var active := 0
	for index in range(mission._infantry_animators.size()):
		var player := mission._infantry_animators[index]
		if not group.members[index].is_leader and not is_equal_approx(group.members[index].offset.y, front):
			_check(player.assigned_animation == &"Idle", stage + ": rear rank still uses original ready clip")
			continue
		_check(player.assigned_animation == &"Sword Slash", stage + ": front rank uses exact slash clip")
		active += 1
		if time >= 0:
			_check(is_equal_approx(player.current_animation_position, time), stage + ": exact authored marker")
		_check(not player.root_motion_track.is_empty(), stage + ": authored root translation suppressed")
		var anchor := player.get_parent() as Node3D
		_check(anchor.position.is_zero_approx() and anchor.scale.is_equal_approx(Vector3.ONE), stage + ": untouched model placement")
		var root_track := player.root_motion_track
		if not root_track.is_empty():
			var skeleton := player.get_node(player.root_node).get_node_or_null(NodePath(root_track.get_concatenated_names())) as Skeleton3D
			_check(skeleton != null, stage + ": root track is on real Skeleton3D")
			if skeleton:
				var bone_index := skeleton.find_bone(root_track.get_concatenated_subnames())
				_check(bone_index >= 0, stage + ": real Root bone")
				if bone_index >= 0:
					var root_pose := skeleton.get_bone_pose_position(bone_index)
					if stage == "windup entry":
						_anchor_roots.append(root_pose)
					elif _anchor_roots.size() >= active:
						_check(root_pose.is_equal_approx(_anchor_roots[active - 1]), stage + ": Root bone actually stays put")
	_check(active == Size.REGULAR_MELEE_COLUMNS + 1, stage + ": fighting leader and all five front rankers act")
	_check(group.leader.combatant == mission.encounter.infantry_attack.attacker, stage + ": the fighting leader owns the existing aggregate damage actor")

func _check(passed: bool, detail: String) -> void:
	if not passed:
		failed += 1
		push_error(detail)

func _axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = value
	root.push_input(event, true)

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)

func _button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
