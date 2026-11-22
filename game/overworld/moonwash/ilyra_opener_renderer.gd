extends "res://game/overworld/moonwash/coast_renderer.gd"
## Reuses the exact coast; recomposes only Ilyra's regional route, labels and lens.

const ShoreLandmarks := preload("res://game/overworld/moonwash/ilyra_survey_landmarks.gd")
const ScoutCamp := preload("res://game/overworld/moonwash/ilyra_scout_camp.gd")
const HarborRescueDressing := preload("res://game/overworld/moonwash/ilyra_harbor_rescue_dressing.gd")
const Survey := preload("res://game/overworld/moonwash/ilyra_survey_route.gd")
const Opener := preload("res://game/overworld/moonwash/ilyra_opener_route.gd")
var _camp_near: MeshInstance3D
var _camp_regional: MeshInstance3D
var _harbor_rescue_dressing: Node3D
var _survey_landmarks: Array[Array] = []
var _survey_mount_pending := false


func _ready() -> void:
	super._ready()
	_sync_story_art()
	_mount_scout_camp.call_deferred()


func _mount_scout_camp() -> void:
	if not is_inside_tree() or not is_instance_valid(_ground) or not anchors.has(Opener.CAMP):
		return
	var tree := get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_inside_tree():
		return
	_camp_near = ScoutCamp.new().build(_camp_foot)
	_camp_regional = ScoutCamp.new().build(_camp_foot, true)
	if not _camp_near or not _camp_regional:
		if _camp_near:
			_camp_near.free()
		if _camp_regional:
			_camp_regional.free()
		push_warning("Ilyra camp: missing terrain under surveyed foot; provisional art withheld.")
		return
	var pad := ScoutCamp.new().build_pad(_camp_foot)
	for part: MeshInstance3D in [_camp_near, _camp_regional, pad]:
		part.position = anchors[Opener.CAMP]
		add_child(part)
	_set_camp_tier()


func _mount_survey_landmarks() -> void:
	if not is_inside_tree() or not is_instance_valid(_ground) or not _rescue_completed():
		return
	var tree := get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_inside_tree() or not _rescue_completed():
		return
	var layer := Node3D.new()
	layer.name = &"SurveyShoreLandmarks"
	var pairs: Array[Array] = []
	for kind: StringName in ShoreLandmarks.ANCHORS:
		var near := ShoreLandmarks.new().build(kind,_survey_foot,false)
		var regional := ShoreLandmarks.new().build(kind,_survey_foot,true)
		if not near or not regional:
			if near:
				near.free()
			if regional:
				regional.free()
			layer.free()
			push_warning("Survey Shore art withheld: bad native foothold for " + kind)
			return
		layer.add_child(near)
		layer.add_child(regional)
		pairs.append([near,regional])
	add_child(layer)
	_survey_landmarks.assign(pairs)
	_update_survey_tier()


func _survey_foot(world_xz: Vector2) -> Variant:
	var center := Vector3(world_xz.x,12.0,world_xz.y)
	var result := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(center+Vector3.UP*35.0,center-Vector3.UP*30.0))
	if result.is_empty() or result.collider.get_parent() != _ground or result.normal.y < .85 or result.position.y < 2.8:
		return null
	return result.position


func _update_survey_tier() -> void:
	if not camera:
		return
	for pair in _survey_landmarks:
		var near: MeshInstance3D = pair[0]
		var regional: MeshInstance3D = pair[1]
		var limit := 218.0 if near.visible else 191.0
		near.visible = camera.global_position.distance_to(near.global_position) < limit
		regional.visible = not near.visible


func _set_camp_tier() -> void:
	if not is_instance_valid(_camp_near) or not is_instance_valid(_camp_regional) or not camera:
		return
	var threshold := 188.0 if _camp_near.visible else 165.0
	var near := camera.global_position.distance_to(anchors[Opener.CAMP]) < threshold
	_camp_near.visible = near
	_camp_regional.visible = not near


func _process(delta: float) -> void:
	super._process(delta)
	_set_camp_tier()
	_update_survey_tier()


func _aim(target: Vector3, offset: Vector3) -> void:
	super._aim(target, offset)
	_set_camp_tier()
	_update_survey_tier()


func _camp_foot(local_xz: Vector2) -> Variant:
	var center := anchors[Opener.CAMP] + Vector3(local_xz.x, 0.0, local_xz.y)
	var result := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(center + Vector3.UP * 20.0, center - Vector3.UP * 20.0))
	if result.is_empty() or result.collider.get_parent() != _ground or result.normal.y < 0.85:
		return null
	return result.position - anchors[Opener.CAMP]


func package_available() -> bool:
	return super.package_available() and not Opener.points().is_empty() and not Survey.points().is_empty()


func _build_routes() -> void:
	var line := Opener.points()
	var eastern := Survey.points()
	if line.is_empty() or eastern.is_empty():
		return
	anchors[Opener.CAMP] = line[0]
	anchors[Opener.HARBOR] = line[-1]
	anchors[Survey.ID] = eastern[-1]
	anchors["marches_camp"] = line[0] # Base party implant, not a traversable ID.
	_focus = Opener.CAMP
	route_points.assign([line, eastern])
	route_keys.assign([Vector2i(-1, -1), Vector2i(-1, -1)])
	super._build_routes()


func configure_overworld_art(world: World, completed: PackedStringArray, reduced: bool) -> void:
	super.configure_overworld_art(world, completed, reduced)
	_sync_story_art()


func _sync_story_art() -> void:
	if _route_pins.size() == 2:
		_route_pins[1].material_override = _closed_pigment if _link_locked(Opener.HARBOR, Survey.ID) else _open_pigment
	if not _rescue_completed() and not is_instance_valid(_harbor_rescue_dressing) and has_node("MoonwashHarbor"):
		var art := HarborRescueDressing.new().build()
		if not install_harbor_rescue_dressing(art):
			art.free()
	if is_instance_valid(_harbor_rescue_dressing):
		_harbor_rescue_dressing.visible = not _rescue_completed()
	var existing_shore := get_node_or_null(^"SurveyShoreLandmarks") as Node3D
	if existing_shore:
		existing_shore.visible = _rescue_completed()
	elif is_inside_tree() and is_instance_valid(_ground) and _rescue_completed() and not _survey_mount_pending:
		_survey_mount_pending = true
		_mount_survey_landmarks.call_deferred()


## Private Ilyra-only provisional dressing. The Ilyra story gate owns its
## appearance; this prop can never own collision, travel, or objective state.
func install_harbor_rescue_dressing(art: Node3D) -> bool:
	if not art or art.is_inside_tree() or is_instance_valid(_harbor_rescue_dressing) or not terrain:
		return false
	if art is CollisionObject3D or not art.find_children("*", "CollisionObject3D", true, false).is_empty():
		return false
	_harbor_rescue_dressing = art
	art.position = Coast.COAST_OFFSET
	art.visible = not _rescue_completed()
	add_child(art)
	return true


func _rescue_completed() -> bool:
	return Survey.RESCUE_CLEAR in _completed_for_probe


func _set_regional() -> void:
	if _focus == Survey.ID:
		_aim(Vector3(1710, 12, 174), Vector3(27, 245, 347))
	elif _focus == Opener.HARBOR:
		if _rescue_completed():
			_aim(Vector3(1554, 20, 116), Vector3(-26, 288, 439))
		else:
			_aim(Vector3(1370, 20, 62), Vector3(80, 253, 395))
	else:
		_aim(Vector3(1360, 22, 56), Vector3(-36, 236, 313))


func toggle_zoom(point: Vector3) -> void:
	if _focus == Survey.ID:
		if _view_follow or not camera:
			return
		_zoomed = not _zoomed
		if _zoomed:
			_aim(Vector3(1799, 6.5, 183), Vector3(13, 64, 93))
		else:
			_set_regional()
		return
	if _focus == Opener.HARBOR and not _rescue_completed() and is_instance_valid(_harbor_rescue_dressing):
		if _view_follow or not camera:
			return
		_zoomed = not _zoomed
		if _zoomed:
			_aim(Coast.COAST_OFFSET + Vector3(10,4,17), Vector3(32,49,67))
		else:
			_set_regional()
		return
	if _focus != Opener.CAMP:
		super.toggle_zoom(point)
		return
	if _view_follow or not camera:
		return
	_zoomed = not _zoomed
	if not _zoomed:
		_set_regional()
	else:
		_aim(point + Vector3(12, 1, -4), Vector3(-20, 59, 76))
