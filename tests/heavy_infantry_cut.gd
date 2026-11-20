extends SceneTree

const MODEL := preload("res://assets/models/human_heavy_infantry.glb")
const CUT := &"Advancing Diagonal Cut"
const READY := &"Shield-Ready Idle"
const SHEATHED: Array[StringName] = [&"Shield Fit Test", &"Travel Run"]
const SAMPLE_RATE := 240.0

var _skeleton: Skeleton3D
var _player: AnimationPlayer


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model := MODEL.instantiate()
	root.add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	var hand := _skeleton.find_bone("Hand.R")
	var sword := _skeleton.find_bone("Sword")
	var scabbard := _skeleton.find_bone("Scabbard")
	if _skeleton.get_bone_parent(sword) != hand:
		_fail("Drawn sword must inherit the hand transform between keys.")
		return

	_pose(READY, 0.0)
	var grip := _relative_pose(hand, sword)
	var fingers: Dictionary[int, Quaternion] = {}
	for finger: String in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		for segment in range(1, 4):
			var bone := _skeleton.find_bone("%s %d.R" % [finger, segment])
			fingers[bone] = _skeleton.get_bone_pose_rotation(bone)

	_pose(SHEATHED[0], 0.0)
	var sheath := _relative_pose(scabbard, sword)
	for clip in SHEATHED:
		if not _check_equipment(clip, scabbard, sword, sheath, {}):
			return
	for clip: StringName in _player.get_animation_list():
		if clip not in SHEATHED and clip != &"RESET":
			if not _check_equipment(clip, hand, sword, grip, fingers):
				return

	var upper := _skeleton.find_bone("Upper Arm.R")
	var forearm := _skeleton.find_bone("Forearm.R")
	var chest := _skeleton.find_bone("Chest")
	_pose(CUT, 0.0)
	var hinge := _elbow_plane(upper, upper, forearm)
	var previous := _elbow_plane(chest, upper, forearm)
	for sample in range(1, roundi(_player.get_animation(CUT).length * SAMPLE_RATE) + 1):
		var seconds := sample / SAMPLE_RATE
		_pose(CUT, seconds)
		var actual_hinge := _elbow_plane(upper, upper, forearm)
		var plane := _elbow_plane(chest, upper, forearm)
		if actual_hinge.angle_to(hinge) > deg_to_rad(0.4):
			_fail("The right elbow changed its local hinge at %.3f s." % seconds)
			return
		if plane.angle_to(previous) > deg_to_rad(4.0):
			_fail("The right elbow swiveled abruptly at %.3f s." % seconds)
			return
		previous = plane

	print("Verified the Heavy Infantry elbow hinge, sword socket, fingers and sheathed clips.")
	quit()


func _check_equipment(
	clip: StringName,
	socket: int,
	sword: int,
	reference: Transform3D,
	fingers: Dictionary[int, Quaternion]
) -> bool:
	var translation_tolerance := 0.001 if fingers.is_empty() else 0.00005
	var rotation_tolerance := 0.005 if fingers.is_empty() else 0.001
	var animation := _player.get_animation(clip)
	for sample in range(roundi(animation.length * SAMPLE_RATE) + 1):
		var seconds := sample / SAMPLE_RATE
		_pose(clip, seconds)
		var pose := _relative_pose(socket, sword)
		var rotation := pose.basis.get_rotation_quaternion()
		if pose.origin.distance_to(reference.origin) > translation_tolerance or rotation.angle_to(reference.basis.get_rotation_quaternion()) > rotation_tolerance:
			_fail("The sword moved in its socket during %s at %.3f s." % [clip, seconds])
			return false
		for joint in fingers:
			if _skeleton.get_bone_pose_rotation(joint).angle_to(fingers[joint]) > 0.001:
				_fail("A finger changed its drawn grip during %s at %.3f s." % [clip, seconds])
				return false
	return true


func _elbow_plane(space: int, upper: int, forearm: int) -> Vector3:
	var axes := _skeleton.get_bone_global_pose(upper).basis.y.cross(_skeleton.get_bone_global_pose(forearm).basis.y)
	return (_skeleton.get_bone_global_pose(space).basis.inverse() * axes).normalized()


func _relative_pose(parent: int, child: int) -> Transform3D:
	return _skeleton.get_bone_global_pose(parent).affine_inverse() * _skeleton.get_bone_global_pose(child)


func _pose(clip: StringName, seconds: float) -> void:
	if _player.assigned_animation != clip:
		_player.play(clip)
		_player.advance(0.0)
	_player.seek(seconds, true)
	_skeleton.force_update_all_bone_transforms()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
