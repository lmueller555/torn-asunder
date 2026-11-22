extends "res://game/overworld/cairnspine/sova_assembly_map.gd"
## Native expansion of the same approved court; later sites are provisional art.
const VaultRoutes := preload("res://game/overworld/cairnspine/sova_vault_routes.gd")
const VaultSector := preload("res://game/overworld/cairnspine/sova_vault_renderer.tscn")


func marker_styles() -> Dictionary:
	return {VaultRoutes.ASSEMBLY: "STORY MISSION", VaultRoutes.ROAD: "ROAD LINK", VaultRoutes.VAULT: "STORY MISSION"}


func marker_bearing(id: String, width: float) -> Vector2:
	if id == VaultRoutes.ROAD:
		return Vector2(-width-27.0,-47.0)
	if id == VaultRoutes.VAULT:
		return Vector2(15.0,24.0)
	return super.marker_bearing(id,width)


func _anchors_for_sector() -> Dictionary[String,Vector3]:
	var shelf := VaultRoutes.shelf()
	var approach := VaultRoutes.approach()
	return {VaultRoutes.ASSEMBLY:shelf[0],VaultRoutes.ROAD:shelf[-1],VaultRoutes.VAULT:approach[-1]}


func _curves_for_sector() -> Dictionary[String,Curve3D]:
	return {
		route_key(VaultRoutes.ASSEMBLY,VaultRoutes.ROAD):VaultRoutes.curve(VaultRoutes.shelf()),
		route_key(VaultRoutes.ROAD,VaultRoutes.VAULT):VaultRoutes.curve(VaultRoutes.approach()),
	}


func _renderer_scene() -> PackedScene:
	return VaultSector


func _travel_pace() -> float:
	return VaultRoutes.PACE


func _refresh() -> void:
	super._refresh()
	if not _world or not is_instance_valid(_header):
		return
	var here := _world.current_waypoint_id()
	var year := "FIVE" if here == VaultRoutes.VAULT else ("FOUR" if here == VaultRoutes.ROAD else "THREE")
	var heading := _header.get_child(0)
	(heading.get_child(0) as Label).text = "VARETH   /   YEAR " + year
