extends SceneTree
const MODEL := preload("res://assets/models/human_heavy_infantry.glb")
const FALL := &"Backward Knockdown"
const UP := &"Get Up"
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
	var durations := {FALL:1.15,UP:94.0/60.0}
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
			sample(a,float(i)/240.0)
			if _rig.get_bone_pose_position(j).length()>.00002:
				push_error("Found duplicate root at " + a)
				errs+=1
				break
	compare(sample(FALL,0.0),sample(READY,0.0),"ready -> fall")
	compare(sample(FALL,1.15),sample(UP,0.0),"held fall -> get up")
	compare(sample(UP,94.0/60.0),sample(READY,0.0),"get up -> ready")
	if errs==0:
		print("Fire-and-hold lengths, static roots at 240Hz and three all-bone endpoints verified.")
	quit(errs)
func sample(clip:StringName,t:float) -> Array[Transform3D]:
	_player.play(clip,0.0)
	_player.advance(0.0)
	_player.seek(t,true)
	_rig.force_update_all_bone_transforms()
	var out: Array[Transform3D]=[]
	for j in range(_rig.get_bone_count()):
		out.append(_rig.get_bone_global_pose(j))
	return out
func compare(a:Array[Transform3D],b:Array[Transform3D], label:String) -> void:
	for j in range(a.size()):
		if a[j].origin.distance_to(b[j].origin)>.00018 or a[j].basis.get_rotation_quaternion().angle_to(b[j].basis.get_rotation_quaternion())>.0014:
			push_error(label + " mismatch " + _rig.get_bone_name(j))
			errs+=1
