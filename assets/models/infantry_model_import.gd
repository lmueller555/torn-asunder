@tool
extends EditorScenePostImport

const LOOPING_CLIPS: Array[StringName] = [&"Idle", &"Walk", &"Run", &"Shield Guard"]
const SHIELD_CONTACT_TIMES: Dictionary[StringName, float] = {
	&"Sword Slash": 0.70,
	&"Sword Recoil": 0.0,
	&"Blocked Hit Stagger": 0.0,
}


func _post_import(scene: Node) -> Object:
	var player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player:
		for clip in LOOPING_CLIPS:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		# glTF carries the pose tracks but does not export Blender action markers.
		for clip in SHIELD_CONTACT_TIMES:
			if player.has_animation(clip):
				player.get_animation(clip).add_marker(&"Shield Contact", SHIELD_CONTACT_TIMES[clip])
	return scene
