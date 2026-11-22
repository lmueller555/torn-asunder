extends "res://game/overworld/cairnspine/sova_assembly_relief.gd"
## Same neutral geometry; the only painted way is the approach to the court.
## No custody/vault branches, year props or cross-campaign state mounted.
func _paint_track(p: Vector2) -> float:
	if p.x < -251 or p.x > -106 or p.y < -29 or p.y > 21:
		return 0.
	var dist := INF
	var way: PackedVector2Array = _travel["ValleyApproach"]
	for i in range(0,way.size()-1,2):
		var j := mini(i+2,way.size()-1)
		dist=minf(dist,p.distance_to(Geometry2D.get_closest_point_to_segment(p,way[i],way[j])))
	return (1.0-smoothstep(2.0,5.2,dist))*(1.-smoothstep(-128.,-106.,p.x))
