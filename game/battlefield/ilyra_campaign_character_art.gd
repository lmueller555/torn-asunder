extends Node
## Private presentation candidate. Does not grant commands or create combatants.
const ASSET_DIRECTORY := "res://assets/models/campaign/elves/"
const MODELS := {
	&"ilyra": ["ilyra_venn.glb", "IlyraNearBody", "IlyraTacticalBody"],
	&"marine": ["shore_marine.glb", "MarineNearBody", "MarineSectorBody", "MarineNearGear", "MarineSectorGear"],
	&"archer": ["ship_archer.glb", "ShipArcherNearBody", "ShipArcherTacticalBody"],
}
# (role, formation list index, existing member index). -1 is the existing hero.
const SCENES := {
	"res://game/battlefield/ilyra_moonwash_rescue_campaign.tscn":
			[[&"ilyra", -1, -1], [&"marine", 1, 9], [&"archer", 0, 9]],
}
const CLOSE_DISTANCE := 24.0
const NAME := &"IlyraCampaignCharacterArt"
var _roster: Array[Mounted] = []


class Mounted:
	var anchor: Node3D
	var model: Node3D
	var player: AnimationPlayer
	var near: MeshInstance3D
	var far: MeshInstance3D
	var near_gear: MeshInstance3D
	var far_gear: MeshInstance3D
	var origin := Vector3.ZERO
	var gait := &""

	func mount_into_anchor() -> void:
		for child in anchor.get_children():
			if child is MeshInstance3D:
				child.hide()
				child.process_mode = Node.PROCESS_MODE_DISABLED
		model.rotate_y(PI) # glTF +Z to the existing command anchor's -Z.
		near.show()
		far.hide()
		if near_gear != null:
			near_gear.show()
			far_gear.hide()
		anchor.add_child(model)
		origin = anchor.global_position
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in [&"Idle",&"Walk",&"Run"]:
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		var track_source := player.get_animation(&"Run")
		for track in track_source.get_track_count():
			if track_source.track_get_type(track) == Animation.TYPE_POSITION_3D 					and track_source.track_get_path(track).get_concatenated_subnames() == "Root":
				player.root_motion_track = track_source.track_get_path(track)
				break

	func locomotion(delta: float) -> void:
		var at := anchor.global_position
		var step := Vector2(at.x - origin.x, at.z - origin.z).length()
		origin = at
		var speed := step / delta if delta > 0.0 and step < 1.0 else 0.0
		var next := &"Run" if speed >= 2.15 else (&"Walk" if speed >= 0.065 else &"Idle")
		if gait != next:
			gait = next
			player.play(gait, 0.10)
		var reference := 2.7 if gait == &"Run" else 1.02
		player.speed_scale = 1.0 if gait == &"Idle" else clampf(speed / reference, 0.22, 2.15)
		player.advance(delta)

	func update_mesh(camera: Camera3D) -> void:
		if camera == null:
			return
		var detailed := camera.global_position.distance_squared_to(anchor.global_position) < CLOSE_DISTANCE * CLOSE_DISTANCE
		near.visible = detailed
		far.visible = not detailed
		if near_gear != null:
			near_gear.visible = detailed
			far_gear.visible = not detailed


static func attach(host: Node3D) -> void:
	if host.has_node(NodePath(NAME)) or not SCENES.has(host.scene_file_path):
		return
	var spec: Array = SCENES[host.scene_file_path]
	var members: Array = host.get("_formation_members")
	var kit: Array[Mounted] = []
	for row: Array in spec:
		var format: Array = MODELS[row[0]]
		var path := ASSET_DIRECTORY + String(format[0])
		var base := host.get("_hero") as Node3D if int(row[1]) < 0 else null
		if int(row[1]) >= 0 and members.size() > int(row[1]) and members[int(row[1])].size() > int(row[2]):
			base = members[int(row[1])][int(row[2])] as Node3D
		var made := _prepare(base, path, format)
		if made == null:
			for piece in kit:
				piece.model.free()
			return
		kit.append(made)
	var root := new()
	root.name = NAME
	root._roster = kit
	for piece in kit:
		piece.mount_into_anchor()
	host.add_child(root)
	root._physics_process(0.0)
	root._process(0.0)


static func _prepare(anchor: Node3D, path: String, format: Array) -> Mounted:
	if anchor == null or not ResourceLoader.exists(path, "PackedScene"):
		return null
	var resource := load(path) as PackedScene
	if resource == null:
		return null
	var instance := resource.instantiate()
	if not instance is Node3D or not instance.find_children("*", "CollisionObject3D", true, false).is_empty():
		instance.free()
		return null
	var item := Mounted.new()
	item.anchor = anchor
	item.model = instance
	item.near = item.model.find_child(String(format[1]), true, false) as MeshInstance3D
	item.far = item.model.find_child(String(format[2]), true, false) as MeshInstance3D
	item.player = item.model.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if item.near == null or item.far == null or item.player == null 		or not item.player.has_animation(&"Idle") or not item.player.has_animation(&"Walk") 		or not item.player.has_animation(&"Run") or not _matching_pair(item.near, item.far):
		instance.free()
		return null
	if format.size() == 5:
		item.near_gear = item.model.find_child(String(format[3]), true, false) as MeshInstance3D
		item.far_gear = item.model.find_child(String(format[4]), true, false) as MeshInstance3D
		if item.near_gear == null or item.far_gear == null or not _matching_pair(item.near_gear, item.far_gear) 			or item.near_gear.get_node_or_null(item.near_gear.skeleton) != item.near.get_node_or_null(item.near.skeleton):
			instance.free()
			return null
	return item


static func _matching_pair(near: MeshInstance3D, far: MeshInstance3D) -> bool:
	if near.get_parent() != far.get_parent() or not near.transform.is_equal_approx(far.transform):
		return false
	if near.skeleton != far.skeleton or near.skin == null or far.skin == null 				or not near.get_node_or_null(near.skeleton) is Skeleton3D 				or near.skin.get_bind_count() == 0 or near.skin.get_bind_count() != far.skin.get_bind_count():
		return false
	for index in near.skin.get_bind_count():
		if near.skin.get_bind_name(index) != far.skin.get_bind_name(index) 			or near.skin.get_bind_bone(index) != far.skin.get_bind_bone(index) 			or not near.skin.get_bind_pose(index).is_equal_approx(far.skin.get_bind_pose(index)):
			return false
	return true


func _physics_process(delta: float) -> void:
	for piece in _roster:
		if is_instance_valid(piece.anchor):
			piece.locomotion(delta)


func _process(_delta: float) -> void:
	var active := get_viewport().get_camera_3d()
	for piece in _roster:
		if is_instance_valid(piece.anchor):
			piece.update_mesh(active)
