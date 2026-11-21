extends Node
## Render-only binding for the registered Grain on Credit deployment. The
## shared Marches battlefield retains its original bridge physics and visuals.

const Mission := preload("res://game/battlefield/mara_grain_crossing_playtest.gd")
const FIELD := "res://game/battlefields/marches_crossing.tscn"
const POSITION := Vector3(0.0, 0.0, -65.0)

@export var near_bridge: PackedScene
@export var sector_bridge: PackedScene

var _mission: Mission
var _near: Node3D
var _sector: Node3D
var _near_meshes: Array[MeshInstance3D] = []
var _shadow: MeshInstance3D


func _ready() -> void:
	set_process(false)
	_mission = get_parent() as Mission
	if not _mission:
		return
	if not _mission.is_node_ready():
		await _mission.ready
	_mount()


func _mount() -> void:
	var field := _mission._field
	if not field or field.scene_file_path != FIELD or not near_bridge or not sector_bridge:
		return
	var crossings := field.get_node_or_null(^"Crossings") as Node3D
	if not crossings:
		return
	var stock: Array[MeshInstance3D] = []
	for child in crossings.get_children():
		var name := String(child.name)
		if child is MeshInstance3D and (name.begins_with("BridgePier") or name.begins_with("DeckPlank") \
				or name.begins_with("NorthPost") or name.begins_with("SouthPost")):
			stock.append(child)
	for path in [^"BridgeDeck/Mesh", ^"NorthRail/Mesh", ^"SouthRail/Mesh"]:
		var old := crossings.get_node_or_null(path) as MeshInstance3D
		if old:
			stock.append(old)
	if stock.size() != 49:
		return

	_near = near_bridge.instantiate() as Node3D
	_sector = sector_bridge.instantiate() as Node3D
	if not _near or not _sector or not _configure_meshes():
		if _near:
			_near.free()
		if _sector:
			_sector.free()
		return
	_near.name = &"NorthBridgeNear"
	_sector.name = &"NorthBridgeSector"
	for instance in [_near, _sector]:
		crossings.add_child(instance)
		instance.position = POSITION
	for mesh in stock:
		mesh.hide()
	_sync_camera()
	set_process(true)


func _configure_meshes() -> bool:
	if not _near.find_children("*", "CollisionObject3D", true, false).is_empty() \
			or not _sector.find_children("*", "CollisionObject3D", true, false).is_empty():
		return false
	for child in _near.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.name == &"ShadowProxy":
			_shadow = mesh
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		else:
			_near_meshes.append(mesh)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sector_meshes := _sector.find_children("*", "MeshInstance3D", true, false)
	for child in sector_meshes:
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _shadow != null and _near_meshes.size() == 3 and sector_meshes.size() == 3


func _process(_delta: float) -> void:
	_sync_camera()


func _sync_camera() -> void:
	# Ask the authoritative camera, not one triggering input source. Preserve
	# the same shadow proxy across a mixed Shift/L2 hold and mode handoff.
	var tactical := _mission._command_camera.is_current()
	if _sector.visible == tactical and _near_meshes[0].visible != tactical:
		return
	_sector.visible = tactical
	for mesh in _near_meshes:
		mesh.visible = not tactical
