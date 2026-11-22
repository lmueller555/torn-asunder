extends "res://game/overworld/cairnspine/sova_assembly_relief.gd"
## Permanent neutral geography. Exact validated relief/spur curves unchanged.
const Threshold:=preload("res://game/overworld/cairnspine/sova_vault_threshold.gd")

func _forecourt() -> void:
	add_child(Threshold.mount(_mesh_foot))


func _mesh_foot(xz: Vector2) -> Vector3:
	# Match the accepted relief's triangle layout exactly. Art placement does
	# not resample a smooth theoretical slope or modify the native collision.
	var stride := (HI-LO)/Vector2(158,150)
	var grid := (xz-LO)/stride
	var i:=Vector2(floorf(grid.x),floorf(grid.y))
	var f:=grid-i
	var base:=LO+i*stride
	var p01:=ground(base+Vector2(0,stride.y))
	var p10:=ground(base+Vector2(stride.x,0))
	var height:float
	if f.x+f.y<=1:
		height=ground(base)*(1.0-f.x-f.y) + p10*f.x + p01*f.y
	else:
		height=ground(base+stride)*(f.x+f.y-1.0) + p10*(1.0-f.y) + p01*(1.0-f.x)
	return Vector3(xz.x,height,xz.y)
