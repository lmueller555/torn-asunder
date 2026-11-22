extends RefCounted
## Original landmark shells, scaled for two intended overworld lenses. No collision,
## army/record props, scripted state or transplanted scene resources.
const Weather := preload("res://game/overworld/sereth/cut_landmark_weather.gdshader")
const Yard := preload("res://game/overworld/sereth/cut_yard.gdshader")
const STONE := ["#767b79","#5f6565","#8b8d83","#62696b","#777a72"]
const WOOD := ["#665141","#564437","#887563"]
const CLOTH := ["#887b79","#bbb1a0","#aaa294","#827784"]
var relief
var _builders: Dictionary={}
var _group: Node3D


func build(renderer) -> void:
	relief=renderer
	var camp: Vector2=relief.CAMP+Vector2(-3.0,-9.0)
	_begin_group("CampDetail")
	_work_yard(camp+Vector2(2,0),Vector2(25,12),.11)
	_tent(camp,15.2,9.7,6.8,.055)
	_tent(camp+Vector2(14.7,-5.4),8.4,6.1,4.35,-.46)
	_tent(camp+Vector2(-9.0,-6.8),6.7,5.1,3.38,.32)
	var flag:=camp+Vector2(-8.9,2.0)
	_beam(_at(flag,-.15),_at(flag,8.45),.15,Color("#6d5847"),2)
	_beam(_at(flag,7.83),_at(flag+Vector2(3.3,-.17),7.83),.09,Color("#89745c"),2)
	var p:=_at(flag,7.85)
	_quad(1,p,p+Vector3(3.15,.04,-.17),p+Vector3(3.02,-2.18,.12),
		p+Vector3(.04,-2.32,0),Color("#aba197"))
	for i in 20:
		var a:=.22+float(i)*.15
		var bp:=camp+Vector2(3.,-10.)+Vector2(cos(a)*24.,sin(a)*-8.)
		_block(_at(bp,.16),Vector3(1.4+.58*_noise(i),.66,1.10+.38*_noise(i+5)),a+.19,
			Color(STONE[i%5]),0)
		if i%4==0:
			var lip:=Vector2(cos(a),sin(a))
			_block(_at(bp+lip*.32,.54),Vector3(1.34,.39,1.02),a,
				Color(STONE[(i+2)%5]),0)
	for i in 5:
		var box:=camp+Vector2(9.1+sin(i*2.6)*2.,1.9+float(i)*.83)
		_block(_at(box,.29),Vector3(.92,.65,.76),i*.09,Color(WOOD[i%3]),2)
		_block(_at(box,.62),Vector3(.98,.093,.81),i*.09,Color(WOOD[(i+1)%3]),2)
	_finish_group(0.0,177.0)

	_begin_group("CampRegional")
	_work_yard(camp+Vector2(2.5,0),Vector2(26.4,12.9),.16)
	_tent_shell(camp,15.6,10.1,6.82,.055,false)
	_tent_shell(camp+Vector2(14.7,-5.4),8.75,6.55,4.4,-.46,false)
	_tent_shell(camp+Vector2(-9.0,-6.8),6.95,5.40,3.43,.32,false)
	_beam(_at(flag),_at(flag,8.65),.21,Color("#6d5847"),2)
	p=_at(flag,8.)
	_quad(1,p,p+Vector3(3.65,.03,.05),p+Vector3(3.65,-2.40,.07),
		p+Vector3(.01,-2.40,.03),Color("#b6ad9d"))
	_finish_group(177.0,0.0)

	_begin_group("CutDetail")
	_bank()
	_stair()
	_room(true)
	_graves(true)
	_finish_group(0.0,177.0)

	_begin_group("CutRegional")
	_bank(true)
	_stair(true)
	_room(false)
	_graves(false)
	_finish_group(177.0,0.0)


func _at(p: Vector2, dy:=0.0) -> Vector3:
	return relief.at(p,dy)


func _noise(i: int) -> float:
	return .5+.5*sin(i*2.399 + .7)


func _begin_group(id: String) -> void:
	_builders={}
	_group=Node3D.new()
	_group.name=id
	relief.add_child(_group)


func _finish_group(from: float,to: float) -> void:
	for kind: int in _builders:
		var builder: SurfaceTool=_builders[kind]
		builder.generate_normals()
		var node:=MeshInstance3D.new()
		node.name="WeatheredSurface_%d" % kind
		node.mesh=builder.commit()
		node.visibility_range_begin=from
		node.visibility_range_end=to
		if from>0.0 or kind==3:
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_group.add_child(node)


func _surface(kind: int) -> SurfaceTool:
	if _builders.has(kind):
		return _builders[kind]
	var m:=ShaderMaterial.new()
	m.shader=Yard if kind==3 else Weather
	if kind!=3:
		m.set_shader_parameter("material_kind",kind)
	var face:=SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	face.set_material(m)
	face.set_smooth_group(-1)
	_builders[kind]=face
	return face


func _quad(kind: int, a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color,level:=1.0) -> void:
	var face:=_surface(kind)
	var points=[a,b,c,a,c,d]
	var tex=[Vector2(0,0),Vector2(level,0),Vector2(level,1),Vector2(0,0),Vector2(level,1),Vector2(0,1)]
	for i in 6:
		face.set_color(tint)
		face.set_uv(tex[i])
		face.add_vertex(points[i])


func _prism(a: Vector3,b: Vector3,c: Vector3,d: Vector3,lift: Vector3,tint: Color,kind: int) -> void:
	_quad(kind,a,d,c,b,tint.darkened(.24))
	_quad(kind,a+lift,b+lift,c+lift,d+lift,tint)
	_quad(kind,a,b,b+lift,a+lift,tint.darkened(.07))
	_quad(kind,b,c,c+lift,b+lift,tint.darkened(.14))
	_quad(kind,c,d,d+lift,c+lift,tint.darkened(.10))
	_quad(kind,d,a,a+lift,d+lift,tint.darkened(.06))


func _block(center: Vector3,span: Vector3,yaw: float,tint: Color,kind: int) -> void:
	var base:=center-Vector3.UP*span.y*.50
	var axes:=Basis(Vector3.UP,yaw)
	var u:=axes.x*span.x*.5
	var v:=axes.z*span.z*.5
	_prism(base-u-v,base+u-v,base+u+v,base-u+v,Vector3.UP*span.y,tint,kind)


func _beam(a: Vector3,b: Vector3,thick: float,tint: Color,kind: int) -> void:
	var up:Vector3=b-a
	if up.length_squared()<.00001:
		return
	var normal:=up.normalized()
	var pick:=Vector3.FORWARD if absf(normal.dot(Vector3.UP))>.94 else Vector3.UP
	var u:=normal.cross(pick).normalized()*thick*.5
	var v:=normal.cross(u).normalized()*thick*.5
	_prism(a-u-v,a+u-v,a+u+v,a-u+v,up,tint,kind)


func _work_yard(center: Vector2, span: Vector2, lift: float) -> void:
	var s:=_surface(3)
	var color:=Color("#686052")
	const W:=26
	const H:=16
	var tile:=Vector2(span.x/W,span.y/H)*2.
	# Single mesh, physically conforming at every vertex. Outer irregular gradient
	# avoids painting a hard rectangular pad on the moor.
	for x in W:
		for z in H:
			for n: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var p:=Vector2(x,z)*tile+n*tile-span
				var k:=minf(1.,1.-(p/span).length()+.056*sin(p.x*.32+p.y*.7))
				s.set_uv(Vector2(k,0))
				s.set_color(color)
				s.add_vertex(_at(center+p,lift))


func _tent(center: Vector2, width: float, depth: float, h: float, yaw: float) -> void:
	_tent_shell(center,width,depth,h,yaw,true)


func _tent_shell(center: Vector2, width: float,depth: float,h: float,yaw: float,detailed: bool) -> void:
	var peak:=_at(center,h)
	var cloth_color:=Color(CLOTH[1])
	var strips:=12 if detailed else 4
	for side:float in [-1.,1.]:
		for i in strips:
			var left:float=lerpf(-width*.5,width*.5,float(i)/float(strips))
			var right:float=lerpf(-width*.5,width*.5,float(i+1)/float(strips))
			var a:=_cloth_vertex(peak,left,side,0.,h,depth,yaw)
			var b:=_cloth_vertex(peak,right,side,0.,h,depth,yaw)
			var c:=_cloth_vertex(peak,right,side,1.,h,depth,yaw)
			var d:=_cloth_vertex(peak,left,side,1.,h,depth,yaw)
			cloth_color=Color(CLOTH[3]) if i==0 or i==strips-1 else Color(CLOTH[1+(i%2)])
			_quad(1,a,b,c,d,cloth_color)
			if detailed:
				_beam(a,d,.034,Color("#c4b4a0"),1)
	for end:float in [-1.,1.]:
		var ridge:=peak+Vector3(end*width*.48,0,0).rotated(Vector3.UP,yaw)
		var pos:=Vector2(ridge.x,ridge.z)
		_beam(_at(pos,-.17),ridge,.24,Color(WOOD[0]),2)
		for side:float in [-1.,1.]:
			var edge:=_cloth_vertex(peak,end*width*.47,side,1.,h,depth,yaw)
			var foot:=Vector2(edge.x,edge.z)
			_beam(_at(foot,-.13),edge,.17,Color(WOOD[1]),2)
			if detailed:
				var stake:=center+Vector2(end*width*.63,side*depth*.69).rotated(yaw)
				_beam(_at(stake,-.09),_at(stake,.31),.10,Color(WOOD[2]),2)
				_beam(edge,_at(stake,.18),.037,Color("#b4a585"),1)
			if end<0.:
				_quad(1,ridge,edge,_at(foot,.43),_at(pos,1.3),Color("#716b70"))


func _cloth_vertex(peak: Vector3,x: float,side: float,t: float,h: float,depth: float,yaw: float) -> Vector3:
	return peak+Vector3(x,-h*(.49*t+.032*sin(x*.69)*t),side*depth*.50*t).rotated(Vector3.UP,yaw)


func _bank(far:=false) -> void:
	# Art seated into the actual bank; thin/dipping stone beds break the
	# land color at the naturally eroded arc, not a new cliff collision wall.
	for j in (3 if far else 5):
		for i in (11 if far else 25):
			var gap:=5.9 if far else 2.6
			var x:=87.+float(i)*gap+sin(float(i)*2.3)*.6
			if absf(x-118.)<4.1:
				continue
			var z:=-27.7+3.2*sin(x*.072)+float(j)*1.52+sin(float(i+j)*1.41)*.55
			var p:=Vector2(x,z)
			var at:=_at(p,-.10+float(j)*.08)
			var size:=Vector3(gap*.96,.70+_noise(i+2*j)*.71,1.48+_noise(i+j)*.57)
			var tint:=Color(STONE[(i+2*j)%5]).darkened(.22)
			_block(at,size,.13*sin(i*.8)+.10*sin(j*.4),tint,0)
	for i in (8 if far else 19):
		var x:=145.+float(i)*(4.15 if far else 1.79)
		var p:=Vector2(x,-26.+2.4*sin(x*.06))
		_block(_at(p,.27),Vector3(3.8 if far else 1.72,.90+.35*_noise(i),1.83),.14*sin(i*.23),
			Color(STONE[i%5]),0)


func _stair(far:=false) -> void:
	for i in 22:
		var p:=Vector2(118.,-4.-float(i)*1.73)
		var rise:=maxf(relief.surface_y(p),relief.surface_y(p+Vector2(0,1.2)))
		if far:
			_block(Vector3(p.x,rise+.19,p.y),Vector3(3.9,.52,1.79),0.,Color("#929589"),0)
			continue
		for piece in 3:
			var px:float=(float(piece)-1.)*1.22
			var edge:=.12*sin(float(i*2+piece)*1.14)
			_block(Vector3(p.x+px,rise+.26,p.y+edge),Vector3(1.19,.64,1.78+edge),
				.032*sin(i+piece),Color(STONE[(piece+i)%5]),0)
		for side: float in [-1.,1.]:
			var rim:=p+Vector2(side*2.14,.0)
			_block(_at(rim,.28),Vector3(.76,1.2,1.75),.02*float(i%4),
				Color(STONE[(i+1)%5]).darkened(.19),0)
			_block(_at(rim,.84),Vector3(.94,.24,1.8),.02*float(i%3),Color(STONE[(i+2)%5]),0)


func _room(near: bool) -> void:
	var room:=Vector2(100.,15.)
	var base:=_at(room,.31)
	var slope:=2.46
	var wall_height:=3.82
	var columns:=9 if near else 4
	var floors:=5 if near else 2
	var joint:=14.2/float(columns)
	var shelf:=wall_height/float(floors)
	_work_yard(room+Vector2(-2.,2.4),Vector2(11.6,8.1),.11)
	for side: float in [-1.,1.]:
		for i in columns:
			var foot:=room+Vector2(-7.0+joint*(i+.51),side*4.07)
			var ground:=_at(foot,-.24).y
			var fill:=maxf(.44,base.y+.20-ground)
			_block(Vector3(foot.x,ground+fill*.5,foot.y),Vector3(joint+.06,fill,.73),
				0.,Color(STONE[(i+3)%5]).darkened(.19),0)
			for row in floors:
				var at:=room+Vector2(-7.0+joint*(i+.51),side*4.07)
				_block(Vector3(at.x,base.y+(row+.49)*shelf,at.y),Vector3(joint-.06,shelf-.055,.55),
					.019*sin(i+row),Color(STONE[(i+row)%5]),0)
		for i in 7:
			for row in floors:
				var z:=float(i-3)*1.13
				if side<0.0 and absf(z)<1.47 and row<floors-1:
					continue
				var p:=room+Vector2(side*7.,z)
				_block(Vector3(p.x,base.y+(row+.50)*shelf,p.y),Vector3(.69,shelf-.057,1.1),0.,
					Color(STONE[(i+row)%5]).darkened(.07),0)
		# A continuous slate bed below the staggered tile laps prevents openings
		# between tile columns without erasing the dark narrow seams.
		_quad(0,base+Vector3(-7.86,wall_height+slope-.075,0),
			base+Vector3(7.86,wall_height+slope-.075,0),base+Vector3(7.86,wall_height-.075,side*4.72),
			base+Vector3(-7.86,wall_height-.075,side*4.72),Color("#545d60"))
		var rows:=5 if near else 2
		for y in rows:
			for i in (21 if near else 4):
				var tile:=15.6/(21. if near else 4.)
				var x:=i*tile-7.8+(0.21 if i%2==0 and near else 0.)
				var u:=float(y)/float(rows)
				var v:=float(y+1.065)/float(rows)
				var p:=base+Vector3(x,wall_height+slope*(1.-u),side*4.68*u)
				var q:=base+Vector3(x,wall_height+slope*(1.-v),side*4.68*v)
				_quad(0,p,p+Vector3(tile+.047,0,0),q+Vector3(tile+.047,0,0),q,
					Color("#4b5359").lerp(Color("#777d7d"),_noise(i+3*y)*.72))
		_beam(base+Vector3(-7.91,wall_height-.11,side*4.59),
			base+Vector3(7.93,wall_height-.11,side*4.59),.28,Color("#655444"),2)
		_quad(2,base+Vector3(side*7.1,wall_height,-4.07),base+Vector3(side*7.1,wall_height+slope,0),
			base+Vector3(side*7.1,wall_height+slope,0),base+Vector3(side*7.10,wall_height,4.07),Color("#63564a"))
	_beam(base+Vector3(-7.95,slope+wall_height+.13,0),
		base+Vector3(7.95,slope+wall_height+.13,0),.31,Color("#656e75"),0)
	# Deliberately blank, dark west opening; no bundle/sign/quest marker.
	_block(base+Vector3(-6.61,1.43,0.),Vector3(.18,2.9,2.63),0.,Color("#312e29"),2)
	for side:float in [-1.,1.]:
		_beam(base+Vector3(-7.27,.09,side*1.42),base+Vector3(-7.27,2.97,side*1.42),
			.24,Color("#796553"),2)
	_beam(base+Vector3(-7.24,2.99,-1.48),base+Vector3(-7.24,2.99,1.48),.32,Color("#8d7b67"),2)
	_block(_at(room+Vector2(-7.98,0.),.19),Vector3(1.69,.40,3.18),0.,Color("#85877a"),0)


func _graves(near: bool) -> void:
	for i in 15:
		var p:=Vector2(127.8+float(i%4)*4.4,-46.0-floorf(float(i)/4.)*3.7)
		var a:=.18*sin(i*.94)
		_block(_at(p,.48),Vector3(.82+_noise(i)*.39,1.07+_noise(i+2)*.56,.39),a,
			Color(STONE[i%5]),0)
		if near:
			_block(_at(p+Vector2(0,.82),.105),Vector3(1.43,.30,1.89),a,
				Color(STONE[(i+3)%5]).darkened(.18),0)
