extends "works_shell.gd"
## Offline far mesh: same atlas, exact unchanged roof, real eave shadow silhouette,
## and full closed body. Retain raised shutter and all principal visible bracing.


func _bar(face: int,a: Vector2,b: Vector2,width: float,d: float,tint: Color,texture: int) -> void:
	var tangent := (b-a).orthogonal().normalized()*width*.468
	var outline := [a+tangent,b+tangent,b-tangent,a-tangent]
	var front: Array[Vector3] = []
	for p in outline:
		front.append(_point(face,p,d))
	var uv := _uv_rect(texture)
	_quad(front,FACE_NORMAL[face],tint,[uv[0],uv[3],uv[2],uv[1]])


func _sill(face: int, half: float) -> void:
	# Keep alternating color broad enough to read at real sector scale; no
	# high-frequency stone facet geometry below one pixel in either direction.
	for row in 2:
		var lo := float(row)*.397 + .025
		var hi := lo + .344
		var seam := half*.34 if row==0 else -half*.24
		var c := Color(.841,.835,.812)
		_rect(face,Vector2(-half+.017,lo),Vector2(seam-.013,hi),.013,STONE,c)
		_rect(face,Vector2(seam+.013,lo+.009),Vector2(half-.018,hi+.012),.013,STONE,
			c.darkened(.018) if row==0 else c.lightened(.012))
