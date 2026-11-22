extends "res://game/overworld/neris/cairnspine_opening_view.gd"

func _configure_private_renderer()->bool:
	if not prepared:
		return super._configure_private_renderer()
	var probe:=ExtendedRelief.new()
	var first:=probe.route_contract()
	var road:=probe.boundary_contract()
	var anchors:Dictionary[String,Vector3]={
		"grove_camp":first.get_point_position(0),GROVE:road.get_point_position(0),POST:road.get_point_position(road.point_count-1)}
	var curves:Dictionary[String,Curve3D]={route_key("grove_camp",GROVE):first,route_key(GROVE,POST):road}
	probe.free()
	return _adopt_prepared(anchors,curves)
