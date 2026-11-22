extends RefCounted
## Detached preflight against actual identity-transformed native ground triangles.
static func foot(mesh:Mesh,xz:Vector2)->Vector3:
	if not mesh: return Vector3.INF
	var src:=Vector3(xz.x,270,xz.y)
	var tgt:=Vector3(xz.x,-60,xz.y)
	var face:=mesh.get_faces()
	var best:=Vector3.INF
	for i in range(0,face.size(),3):
		var hit:Variant=Geometry3D.segment_intersects_triangle(src,tgt,face[i],face[i+1],face[i+2])
		if hit is Vector3 and (not best.is_finite() or hit.y>best.y):
			best=hit
	return best
