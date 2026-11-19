@tool
extends EditorScenePostImport

const LOOPING_CLIPS: Array[StringName] = [&"Idle", &"Walk", &"Run"]


func _post_import(scene: Node) -> Object:
	var player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player:
		for clip in LOOPING_CLIPS:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return scene
