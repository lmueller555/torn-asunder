extends SceneTree

const MODEL := preload("res://assets/models/human_heavy_infantry.glb")
const CHEER := &"Sword Cheer"
const READY := &"Shield-Ready Idle"
var _player: AnimationPlayer
var _rig: Skeleton3D
var errs:=0

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var model := MODEL.instantiate()
	root.add_child(model)
	_player = model.find_children("*","AnimationPlayer",true,false)[0]
	_rig = model.find_children("*","Skeleton3D",true,false)[0]
	assert(not _player.has_animation(&"Death Fall"))
	var durations := {CHEER:1.4}
	for a: StringName in durations:
		if not _player.has_animation(a):
			push_error("missing clip " + a)
			quit(1)
			return
		var clip := _player.get_animation(a)
		if absf(clip.length- durations[a])>.0001 or clip.loop_mode != Animation.LOOP_NONE:
			push_error("Wrong duration/loop " + a)
			errs+=1
		var j := _rig.find_bone("Root")
		for i in range(roundi(clip.length*240.0)+1):
			at(a,float(i)/240.0)
			if _rig.get_bone_pose_position(j).length()>.00002:
				push_error("Found duplicate root at " + a)
				errs+=1
				break
	var ready:=sample(READY,0.0)
	compare(sample(CHEER,0.0),ready,"ready to victory raise")
	compare(sample(CHEER,1.4),ready,"victory raise to ready")
	at(READY,0.0)
	var right:=_rig.find_bone("Hand.R")
	var sword_bone:=_rig.find_bone("Sword")
	var bound := _rig.get_bone_global_pose(right).affine_inverse()*_rig.get_bone_global_pose(sword_bone)
	var shield_bone:=_rig.find_bone("Shield")
	var left:=_rig.find_bone("Hand.L")
	var plate_bound := _rig.get_bone_global_pose(left).affine_inverse()*_rig.get_bone_global_pose(shield_bone)
	for a: StringName in durations:
		for i in range(roundi(durations[a]*240.0)+1):
			at(a,float(i)/240.0)
			var sword := _rig.get_bone_global_pose(right).affine_inverse()*_rig.get_bone_global_pose(sword_bone)
			var plate := _rig.get_bone_global_pose(left).affine_inverse()*_rig.get_bone_global_pose(shield_bone)
			if not _same(sword,bound) or not _same(plate,plate_bound):
				push_error("Sword or shield socket drift in " + a)
				errs+=1
				break
	if errs==0:
		print("One-shot 1.40s duration, stationary root, two exact ready joins, and both weapon/shield sockets verified at 240 Hz.")
	quit(errs)

func at(clip:StringName,t:float) -> void:
	if _player.assigned_animation != clip:
		_player.play(clip,0.0)
		_player.advance(0.0)
	_player.seek(t,true)
	_rig.force_update_all_bone_transforms()

func sample(clip:StringName,t:float) -> Array[Transform3D]:
	at(clip,t)
	var out: Array[Transform3D]=[]
	for j in range(_rig.get_bone_count()):
		out.append(_rig.get_bone_global_pose(j))
	return out

func _same(a:Transform3D,b:Transform3D)->bool:
	return a.origin.distance_to(b.origin)<=.00018 and a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())<=.0014

func compare(a:Array[Transform3D],b:Array[Transform3D], label:String) -> void:
	for j in range(a.size()):
		if not _same(a[j],b[j]):
			push_error(label + " mismatch " + _rig.get_bone_name(j))
			errs+=1
			break
