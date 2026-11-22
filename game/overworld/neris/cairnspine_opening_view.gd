extends "res://game/overworld/neris/grove_opening_view.gd"
const ExtendedRelief := preload("res://game/overworld/neris/cairnspine_relief.gd")
const ExtendedScene := preload("res://game/overworld/neris/cairnspine_relief.tscn")
const GROVE:="isolated_grove_nursery"
const POST:="cairnspine_boundary_post"
var _boundary_lens:=false

func _map_strip_title()->String:
	return "VARETH    /    CAMPAIGN ROAD"

func _configure_private_renderer()->bool:
	var probe:=ExtendedRelief.new()
	var first:=probe.route_contract().duplicate() as Curve3D
	var path:=probe.boundary_contract().duplicate() as Curve3D
	assert(first.get_point_position(first.point_count-1).is_equal_approx(path.get_point_position(0)))
	probe.free()
	var anchors:Dictionary[String,Vector3]={
		"grove_camp":first.get_point_position(0),GROVE:path.get_point_position(0),
		POST:path.get_point_position(path.point_count-1)}
	var curves:Dictionary[String,Curve3D]={
		route_key("grove_camp",GROVE):first,route_key(GROVE,POST):path}
	return configure_renderer(ExtendedScene,^"Camera",^"Party",anchors,curves,34.0)

func _update_party()->void:
	super._update_party()
	_sync_region()

func flip_lens()->void:
	super.flip_lens()
	_sync_region()

func _sync_region()->void:
	if not _navigation or _detail or _navigation.is_travelling():
		return
	var show_boundary:=_world.current_waypoint_id()==POST or _navigation.selected_waypoint_id()==POST
	if show_boundary:
		_renderer.boundary_region()
	elif _boundary_lens:
		_renderer.view_lens(false)
	_boundary_lens=show_boundary
	_overlays.queue_redraw()


func _select_at(point:Vector2)->bool:
	if not _detail and _navigation and not _navigation.is_travelling():
		var points:=_projections()
		if points.has(POST) and point.distance_to(points[POST]+POST_REGIONAL_PIN_OFFSET)<=12.:
			return select_waypoint(POST)
	return super._select_at(point)
