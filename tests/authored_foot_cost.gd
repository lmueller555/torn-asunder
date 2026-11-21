extends SceneTree
const Mine := preload("res://game/battlefield/mara_mine_escort_campaign.tscn")

func _initialize() -> void: _go.call_deferred()
func _go() -> void:
	for heavy: bool in [false,true]:
		var m:=Mine.instantiate()
		if heavy: m.configure_replay_heavy_infantry(true,true)
		root.add_child(m)
		m.set_physics_process(false)
		await process_frame
		var rigs: Array = m._formation_members[0]
		var mesh_count := 0
		var surfaces := 0
		var tris := 0
		for rig: Node3D in rigs:
			for mesh: MeshInstance3D in rig.find_children("*","MeshInstance3D",true,false):
				if not mesh.mesh:
					continue
				mesh_count+=1
				for n in mesh.mesh.get_surface_count():
					var a:=mesh.mesh.surface_get_arrays(n)
					surfaces+=1
					var ids: Variant=a[Mesh.ARRAY_INDEX]
					var vs: Variant=a[Mesh.ARRAY_VERTEX]
					tris+=(ids.size() if ids is PackedInt32Array and not ids.is_empty() else vs.size())/3
		print("Mara ", "Heavy" if heavy else "Infantry",
			" slots=",rigs.size(), " render meshes=",mesh_count," surfaces=",surfaces,
			" source triangles=",tris," animators=",m._infantry_animators.size())
		m.queue_free()
		await process_frame
	print("Not GPU/LOD timing: upper bound for currently instantiated full source rigs.")
	quit()
