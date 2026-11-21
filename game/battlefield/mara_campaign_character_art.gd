extends Node
## Optional character presentation for the three registered Human deployments.
## The hero and both officer models occupy existing renderer anchors only.
const Mine := preload("res://game/battlefield/mara_mine_escort.gd")
const Defense := preload("res://game/combat/hero_defense.gd")
const Attack := preload("res://game/combat/hero_attack_sequence.gd")

const DEPLOYMENTS := [
	"res://game/battlefield/mara_greyhollow_rescue_campaign.tscn",
	"res://game/battlefield/mara_grain_crossing_campaign.tscn",
	"res://game/battlefield/mara_moonwash_playtest.tscn",
]
const ASSETS := [
	"res://assets/models/campaign/humans/mara_halden.glb",
	"res://assets/models/campaign/humans/aldric_thorne.glb",
	"res://assets/models/campaign/humans/longbow_lieutenant.glb",
]
const OFFICER_SLOTS := [0, 6] # Front of each existing lead platoon flank.
const TACTICAL_RANGE := 24.0
const NAME := &"MaraCampaignCharacterArt"
const IDLE := &"Idle"
const WALK := &"Walk"
const RUN := &"Run"
const GUARD := &"Shield Guard"
const RAISE := &"Shield Raise"
const LOWER := &"Shield Lower"
const SLASH := &"Sword Slash"
const FALL := &"Death Fall"

class Rig:
	var visual: Node3D
	var player: AnimationPlayer
	var clip := &""
	var pose_time := 0.0
	var near_body: MeshInstance3D
	var sector_body: MeshInstance3D
	var near_meshes: Array[MeshInstance3D] = []
	var sector_meshes: Array[MeshInstance3D] = []

	static func from_scene(scene: PackedScene, role: int) -> Rig:
		var leader := role == 0
		var node := scene.instantiate()
		var model := node as Node3D
		if model == null:
			node.free()
			return null
		var rig := Rig.new()
		rig.visual = model
		rig.player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if model is CollisionObject3D or not rig._select_tiers(role) \
				or not model.find_children("*", "CollisionObject3D", true, false).is_empty() \
				or rig.player == null or not rig.player.has_animation(IDLE) \
				or not rig.player.has_animation(WALK) or not rig.player.has_animation(RUN):
			model.free()
			return null
		if leader and (not rig.player.has_animation(GUARD) \
				or not rig.player.has_animation(RAISE) or not rig.player.has_animation(LOWER) \
				or not rig.player.has_animation(SLASH) or not rig.player.has_animation(FALL)):
			model.free()
			return null
		rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		# These motion resources belong to the new art imports, not stock soldiers.
		for gait in [IDLE, WALK, RUN, GUARD]:
			if rig.player.has_animation(gait):
				rig.player.get_animation(gait).loop_mode = Animation.LOOP_LINEAR
		# The simulation moves the anchor. Do not duplicate an authored lunge or fall.
		var animation := rig.player.get_animation(SLASH if leader else RUN)
		for track in range(animation.get_track_count()):
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D \
					and animation.track_get_path(track).get_concatenated_subnames() == "Root":
				rig.player.root_motion_track = animation.track_get_path(track)
				break
		model.rotate_y(PI) # glTF +Z forward; command anchors face -Z.
		return rig

	func _select_tiers(role: int) -> bool:
		# Untiered eyes are inexpensive and stay on the shared deform rig. All
		# other render meshes, including any separate gear, must declare a tier.
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			var tag := String(mesh.name)
			if tag.ends_with("NearBody") or (role == 1 and tag == "LOD Near Anatomy"):
				if near_body != null:
					return false
				near_body = mesh
				near_meshes.append(mesh)
			elif tag.ends_with("SectorBody") or (role == 1 and tag == "LOD Tactical Anatomy"):
				if sector_body != null:
					return false
				sector_body = mesh
				sector_meshes.append(mesh)
			elif tag.contains("NearGear") or (role == 1 and tag == "LOD Near Wardrobe"):
				near_meshes.append(mesh)
			elif tag.contains("SectorGear") or (role == 1 and tag == "LOD Tactical Wardrobe"):
				sector_meshes.append(mesh)
			# Aldric’s small rigid sidearm rides the existing bone socket
			# and is intentionally common on the audited combined export.
			elif not "eye" in tag.to_lower() and not (role == 1 and tag == "Common Sidearm"):
				return false
		if near_body == null or sector_body == null or near_body.get_parent() != sector_body.get_parent() \
				or not near_body.transform.is_equal_approx(sector_body.transform):
			return false
		var skin := near_body.get_node_or_null(near_body.skeleton) as Skeleton3D
		if skin == null or skin != sector_body.get_node_or_null(sector_body.skeleton) \
				or not _same_bind_pose(near_body.skin, sector_body.skin):
			return false
		for mesh in near_meshes + sector_meshes:
			if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) != skin:
				return false
		for mesh in near_meshes:
			mesh.visibility_range_end = TACTICAL_RANGE
		for mesh in sector_meshes:
			mesh.visibility_range_begin = TACTICAL_RANGE
			mesh.hide()
		return true

	static func _same_bind_pose(first: Skin, second: Skin) -> bool:
		if first == null or second == null or first.get_bind_count() == 0 \
				or first.get_bind_count() != second.get_bind_count():
			return false
		if first == second:
			return true
		for index in first.get_bind_count():
			if first.get_bind_bone(index) != second.get_bind_bone(index) \
					or first.get_bind_name(index) != second.get_bind_name(index) \
					or not first.get_bind_pose(index).is_equal_approx(second.get_bind_pose(index)):
				return false
		return true

	func tier(camera: Camera3D) -> void:
		if camera == null:
			return
		var near := camera.global_position.distance_squared_to(near_body.global_position) < TACTICAL_RANGE * TACTICAL_RANGE
		for mesh in near_meshes:
			mesh.visible = near
		for mesh in sector_meshes:
			mesh.visible = not near

	func pose(next: StringName, delta: float, rate := 1.0, absolute_time := -1.0, looped := true) -> void:
		if not player.has_animation(next):
			return
		if clip != next:
			clip = next
			pose_time = 0.0
			# A small visual crossfade for locomotion and recovery. The targeted
			# strike preview is unblended so its actual contact pose stays exact.
			player.play(clip, 0.10 if absolute_time < 0.0 else 0.0)
			player.advance(0.0)
		var length := player.get_animation(clip).length
		if absolute_time >= 0.0:
			pose_time = clampf(absolute_time, 0.0, length)
			player.seek(pose_time, true, true)
			return
		if looped:
			pose_time = fposmod(pose_time + delta * rate, maxf(0.001, length))
		else:
			var step := minf(delta * rate, maxf(0.0, length - pose_time))
			player.advance(step)
			pose_time = minf(pose_time + step, length)
			return
		player.advance(delta * rate)

var _host: Node3D
var _hero: Rig
var _officers: Array[Rig] = []
var _last_position := Vector2.INF
var _last_battle: Object
var _last_encounter: Object
var _raising := false
var _lowering := false

static func attach(host: Node3D) -> void:
	if not host.scene_file_path in DEPLOYMENTS or host.has_node(NodePath(NAME)):
		return
	# A checkout without the separately reviewed art keeps all existing visuals.
	var scenes: Array[PackedScene] = []
	for path: String in ASSETS:
		if not ResourceLoader.exists(path, "PackedScene") and not ResourceLoader.has_cached(path):
			return
		var scene := load(path) as PackedScene
		if scene == null or not scene.can_instantiate():
			return
		scenes.append(scene)
	var art := new()
	art._host = host
	if not art._mount(scenes):
		art.free()
		return
	art.name = NAME
	host.add_child(art)
	art._physics_process(0.0)
	art._process(0.0)

func _mount(scenes: Array[PackedScene]) -> bool:
	var hero_anchor := _host.get("_hero") as Node3D
	var members: Array = _host.get("_lead_members")
	if hero_anchor == null or members.size() <= OFFICER_SLOTS[-1]:
		return false
	var rigs: Array[Rig] = []
	for index in scenes.size():
		var rig := Rig.from_scene(scenes[index], index)
		if rig == null:
			for made in rigs:
				made.visual.free()
			return false
		rigs.append(rig)
	_hero = rigs[0]
	_officers.append(rigs[1])
	_officers.append(rigs[2])
	var mine := _host as Mine
	var obsolete_weapon: Node3D = mine._hero_weapon if mine != null else null
	var native_guard: Node3D = mine._hero_guard if mine != null else null
	for child in hero_anchor.get_children():
		if child is MeshInstance3D and child != obsolete_weapon and child != native_guard:
			child.hide()
			child.process_mode = Node.PROCESS_MODE_DISABLED
	hero_anchor.add_child(_hero.visual)
	for index in OFFICER_SLOTS.size():
		var member: Node3D = members[OFFICER_SLOTS[index]]
		for child in member.get_children():
			if child is Node3D:
				child.hide()
				child.process_mode = Node.PROCESS_MODE_DISABLED
		member.add_child(_officers[index].visual)
	return true

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_hero.tier(camera)
	for officer in _officers:
		officer.tier(camera)

func _physics_process(raw_delta: float) -> void:
	var delta := clampf(raw_delta, 0.0, 0.10)
	var battle: Object = _host.get("battle")
	var at: Vector2 = battle.hero_position
	var mine := _host as Mine
	var encounter: Object = mine.encounter if mine != null else null
	if battle != _last_battle or encounter != _last_encounter:
		_last_position = at
		_last_battle = battle
		_last_encounter = encounter
		_raising = false
		_lowering = false
		_hero.clip = &""
		for officer in _officers:
			officer.clip = &""
	var travelled := _last_position.distance_to(at)
	_last_position = at
	var speed := travelled / delta if delta > 0.0001 and travelled < 2.0 else 0.0
	var gait := RUN if speed >= 1.8 else (WALK if speed > 0.06 else IDLE)
	var rate := clampf(speed / (2.7 if gait == RUN else 1.02), 0.55, 2.2) if gait != IDLE else 1.0
	for officer in _officers:
		officer.pose(gait, delta, rate)
	if mine == null or mine.encounter == null:
		_hero.pose(gait, delta, rate)
		return
	# Existing resolver still controls the old in-world block cue at rear camera angles.
	mine._hero_weapon.hide()
	var defense := mine.encounter.defense
	if not mine.encounter.hero.is_alive():
		_hero.pose(FALL, delta, 1.0, -1.0, false)
	elif defense.attack_phase != Attack.Phase.IDLE:
		_raising = false
		_lowering = false
		var slash := _hero.player.get_animation(SLASH)
		var contact := slash.get_marker_time(&"Shield Contact") if slash.has_marker(&"Shield Contact") else 0.70
		contact = clampf(contact, 0.0, slash.length)
		var progress := clampf(defense.attack_progress(), 0.0, 1.0)
		var pose := contact * progress if defense.attack_phase == Attack.Phase.WINDUP \
			else lerpf(contact, slash.length, progress)
		_hero.pose(SLASH, delta, 1.0, pose)
	elif defense.phase == Defense.Phase.GUARD:
		_lowering = false
		if _hero.clip not in [RAISE, GUARD]:
			_raising = true
		if _raising and (_hero.clip != RAISE or _hero.pose_time < _hero.player.get_animation(RAISE).length):
			_hero.pose(RAISE, delta, 1.0, -1.0, false)
		else:
			_raising = false
			_hero.pose(GUARD, delta)
	elif defense.phase in [Defense.Phase.DODGE_STARTUP, Defense.Phase.DODGE_ACTIVE, Defense.Phase.DODGE_RECOVERY]:
		_raising = false
		_lowering = false
		_hero.pose(RUN, delta, 1.4)
	else:
		if _hero.clip in [RAISE, GUARD]:
			_raising = false
			_lowering = true
		if _lowering and (_hero.clip != LOWER or _hero.pose_time < _hero.player.get_animation(LOWER).length):
			_hero.pose(LOWER, delta, 1.0, -1.0, false)
		else:
			_lowering = false
			_hero.pose(gait, delta, rate)
