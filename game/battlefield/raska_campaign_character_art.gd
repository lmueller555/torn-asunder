extends Node
## Private render-only Orc campaign art candidate.
const ASSETS := "res://assets/models/campaign/orcs/"
const CHARACTER_ART := &"RaskaCampaignCharacterArt"
const DISTANCE_SQUARED := 576.0
const RASKA_NEAR := ["RaskaNear_Anatomy","RaskaNear_Textiles","RaskaNear_Ironwork"]
const RASKA_FAR := ["RaskaSector_Anatomy","RaskaSector_Textiles","RaskaSector_Ironwork"]
const ROLES := {
	&"raska": ["raska_vennor.glb",RASKA_NEAR,RASKA_FAR,"Raska_",1.42,5.50],
	&"durga": ["durga_ashtusk.glb",["DurgaNearBody"],["DurgaSectorBody"],"Durga_",1.43,4.15],
	&"vasha": ["vasha_grem.glb",["LOD Near Vasha"],["LOD Tactical Vasha"],"",1.45,4.0],
}
const SLOTS := {
	"res://game/battlefield/raska_spanwater.tscn": [[&"raska",-1,-1],[&"durga",0,9],[&"vasha",1,9]],
}
var _figures: Array[Figure] = []


class Figure:
	var anchor: Node3D
	var model: Node3D
	var rig: Skeleton3D
	var player: AnimationPlayer
	var near: Array[MeshInstance3D] = []
	var sector: Array[MeshInstance3D] = []
	var origin := Vector3.ZERO
	var gait := &""
	var clips := {}
	var pace := Vector2.ONE

	func mount_visual() -> void:
		origin = anchor.global_position
		for child in anchor.get_children():
			if child is MeshInstance3D:
				child.hide()
				child.process_mode = Node.PROCESS_MODE_DISABLED
		model.rotate_y(PI)
		anchor.add_child(model)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		# Scoped visual policy: these three in-place locomotion clips always loop.
		for clip: StringName in clips.values():
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.play(clips[&"Idle"])
		player.advance(0.0)

	func step_pose(delta: float) -> void:
		var pos := anchor.global_position
		var step := Vector2(pos.x-origin.x,pos.z-origin.z).length()
		origin = pos
		if not anchor.is_visible_in_tree():
			return
		var speed := step / delta if step < 1.5 and delta > 0.0 else 0.0
		var mode := &"Run" if speed >= 2.15 else (&"Walk" if speed > 0.06 else &"Idle")
		if gait != mode:
			gait = mode
			player.play(clips[gait],0.10)
		player.speed_scale = 1.0 if gait == &"Idle" else clampf(speed / (pace.y if gait == &"Run" else pace.x),0.20,1.90)
		player.advance(delta)

	func tier(camera: Camera3D) -> void:
		if camera == null:
			return
		var use_near := camera.global_position.distance_squared_to(anchor.global_position) < DISTANCE_SQUARED
		for mesh in near:
			mesh.visible = use_near
		for mesh in sector:
			mesh.visible = not use_near


static func attach(host: Node3D) -> void:
	if not SLOTS.has(host.scene_file_path) or host.has_node(NodePath(CHARACTER_ART)):
		return
	var formation_slots: Array = host.get("_formation_members")
	var kit: Array[Figure] = []
	for row: Array in SLOTS[host.scene_file_path]:
		var slot := int(row[1])
		var anchor := host.get("_hero") as Node3D if slot < 0 else null
		if slot >= 0 and slot < formation_slots.size() and int(row[2]) < formation_slots[slot].size():
			anchor = formation_slots[slot][int(row[2])] as Node3D
		var piece := _figure(anchor,ROLES[row[0]])
		if piece == null:
			for previous in kit:
				previous.model.free()
			return
		kit.append(piece)
	var adapter := new()
	adapter.name = CHARACTER_ART
	adapter._figures = kit
	for item in kit:
		item.mount_visual()
	host.add_child(adapter)
	adapter._process(0.0)


static func _figure(anchor: Node3D, spec: Array) -> Figure:
	var path := ASSETS + String(spec[0])
	if anchor == null or not ResourceLoader.exists(path,"PackedScene"):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var n := packed.instantiate()
	var player := n.find_children("*","AnimationPlayer",true,false)
	var skeletons := n.find_children("*","Skeleton3D",true,false)
	if not n is Node3D or not n.find_children("*","CollisionObject3D",true,false).is_empty() 			or player.size() != 1 or skeletons.size() != 1:
		n.free()
		return null
	var item := Figure.new()
	item.anchor = anchor
	item.model = n as Node3D
	item.rig = skeletons[0] as Skeleton3D
	item.player = player[0] as AnimationPlayer
	item.pace = Vector2(float(spec[4]),float(spec[5]))
	for i in spec[1].size():
		var near := n.find_child(String(spec[1][i]),true,false) as MeshInstance3D
		var far := n.find_child(String(spec[2][i]),true,false) as MeshInstance3D
		if not _matched(near,far,item.rig):
			n.free()
			return null
		item.near.append(near)
		item.sector.append(far)
	for gait in [&"Idle",&"Walk",&"Run"]:
		var authored := StringName(String(spec[3])+String(gait))
		if not item.player.has_animation(authored):
			authored = StringName(String(authored)+"-loop")
		if not item.player.has_animation(authored):
			n.free()
			return null
		item.clips[gait] = authored
	return item


static func _matched(near: MeshInstance3D, far: MeshInstance3D, rig: Skeleton3D) -> bool:
	if near == null or far == null or near.get_parent() != far.get_parent() 			or not near.transform.is_equal_approx(far.transform) or near.skin == null or far.skin == null 			or near.get_node_or_null(near.skeleton) != rig or far.get_node_or_null(far.skeleton) != rig 			or near.skin.get_bind_count() != far.skin.get_bind_count():
		return false
	for i in near.skin.get_bind_count():
		if near.skin.get_bind_name(i) != far.skin.get_bind_name(i) 			or near.skin.get_bind_bone(i) != far.skin.get_bind_bone(i) 			or not near.skin.get_bind_pose(i).is_equal_approx(far.skin.get_bind_pose(i)):
			return false
	return true


func _physics_process(delta: float) -> void:
	for item in _figures:
		if is_instance_valid(item.anchor):
			item.step_pose(delta)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for item in _figures:
		if is_instance_valid(item.anchor):
			item.tier(camera)
