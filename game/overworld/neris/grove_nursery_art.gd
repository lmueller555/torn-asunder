extends RefCounted
## Original native overworld landmark art. The wet receiver and town well are separate
## from the failed spring; neither geometry nor materials assert any gameplay outcome.

static func build(view, anchor:Vector2)->void:
	var soil:PackedColorArray=PackedColorArray([Color("#424835"),Color("#4d4e38"),Color("#54533e")])
	var wood:Material=view._paint("#65513b")
	var sapwood:Material=view._paint("#876b48")
	var reed:Material=view._paint("#6c7850")
	var pale:Material=view._paint("#9e9971")
	var stone:Material=view._paint("#777768")
	for lane in 3:
		var center:=anchor+Vector2(8,-10-lane*7)
		_field(view,center,Vector2(12.6,2.65),soil[lane])
		for end in [-1.0,1.0]:
			var run:float=float(end)
			var rail:Vector2=center+Vector2(run*12.25,0.0)
			view._timber(view._at(rail+Vector2(0,-2.45),.31),view._at(rail+Vector2(0,2.45),.31),.15,wood,7)
		for i in 6:
			var p:=anchor+Vector2(-3+i*4.15,-10-lane*7+i*.27)
			var tree:MeshInstance3D=view._positioned(view._variants[(lane+i)%4],view._at(p),null,i*1.83)
			tree.scale=Vector3.ONE*(.24+.07*float((i+lane)%4))
			var stake:=p+Vector2(.45,-.48)
			view._timber(view._at(stake),view._at(stake,1.53),.055,sapwood,5)
		# Woven low retaining edge, raised stone endcaps preserve the three-row field silhouette.
		for i in 14:
			var edge:=center+Vector2((i-6.5)*1.85,2.48)
			view._rock(view._at(edge,.18),Vector3(1.82,.41,.69),pale if i%3 else stone,i*.12)
		var beam_a:Vector2=center+Vector2(-12.35,-2.47)
		var beam_b:Vector2=center+Vector2(12.35,-2.47)
		view._timber(view._at(beam_a,.31),view._at(beam_b,.31),.10,reed,7)
	var well:=anchor+Vector2(-11,-6)
	_well(view,well,wood,sapwood,stone,pale)
	# A small covered working area reads as horticulture rather than a second settlement.
	_lath(view,anchor+Vector2(14,-32),wood,sapwood)
	_regional_read(view,anchor,well)

static func _surface(view,tint:Color)->SurfaceTool:
	var surf:=SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat:StandardMaterial3D=view._paint(tint.to_html())
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	surf.set_material(mat)
	return surf

static func _field(view,center:Vector2,half:Vector2,tint:Color)->void:
	var mesh:=_surface(view,Color.WHITE)
	for i in 19:
		for j in 4:
			var a:=center+Vector2(lerpf(-half.x,half.x,i/19.0),lerpf(-half.y,half.y,j/4.0))
			var c:=center+Vector2(lerpf(-half.x,half.x,(i+1)/19.0),lerpf(-half.y,half.y,(j+1)/4.0))
			var tone:=tint.lightened((.5+.5*sin(i*2.23+j*4.61))*.15)
			var b:=Vector2(c.x,a.y)
			var d:=Vector2(a.x,c.y)
			view._tri(mesh,view._at(a,.035),view._at(c,.035),view._at(b,.035),tone)
			view._tri(mesh,view._at(a,.035),view._at(d,.035),view._at(c,.035),tone.darkened(.04))
	view._positioned(mesh.commit(),Vector3.ZERO,null)

static func _well(view,spot:Vector2,timber:Material,edge:Material,stone:Material,pale:Material)->void:
	var center:Vector3=view._at(spot)
	for layer in 3:
		for i in 14:
			var a:float=(i+layer*.42)*TAU/14.0
			var at:=Vector3(cos(a),0,sin(a))*(2.73+.10*int(layer==2))
			var brick:=BoxMesh.new()
			brick.size=Vector3(1.31,.46 if layer<2 else .31,.87 if layer<2 else 1.04)
			view._positioned(brick,center+at+Vector3.UP*(.14+layer*.40+.025*sin(i*3.2)),pale if layer==2 or i%5==0 else stone,-a+PI*.5)
	var pool:=CylinderMesh.new()
	pool.height=.08
	pool.radial_segments=22
	pool.top_radius=2.32
	pool.bottom_radius=2.32
	view._positioned(pool,center+Vector3.UP*.17,view._paint("#334640",.53))
	for side:float in [-1.0,1.0]:
		var upright:=Vector2(side*2.91,0)
		var post:Vector3=view._at(spot+upright)
		var head:=center+Vector3(side*2.70,5.05,0)
		view._timber(post,head,.23,timber,8)
		view._timber(head-Vector3.UP*1.2,head+Vector3(-side*.85,.03,.06),.11,edge,7)
	var axle:=center+Vector3(0,3.39,0)
	view._timber(axle-Vector3(3.10,0,0),axle+Vector3(3.25,0,0),.15,timber,8)
	var iron:Material=view._paint("#454238",.7)
	for i in 8:
		var a:=float(i)*TAU/8.0
		var w:=Vector3(3.18,cos(a)*.8,sin(a)*.8)
		var v:=Vector3(3.18,cos(a+TAU/8.0)*.8,sin(a+TAU/8.0)*.8)
		view._timber(axle+w,axle+v,.06,iron,6)
		if i%2==0:
			view._timber(axle+Vector3(3.18,0,0),axle+w,.045,edge,5)
	view._timber(axle+Vector3(0,0,.21),center+Vector3(0,.64,.21),.037,edge,5)
	var roof:=_surface(view,Color.WHITE)
	for s:float in [-1.0,1.0]:
		for i in 12:
			for j in 4:
				var x:=lerpf(-4.30,4.30,i/12.0)
				var dx:=lerpf(-4.30,4.30,(i+1)/12.0)
				var z:=j*.59
				var dz:=(j+1.12)*.59
				var a:=center+Vector3(x,6.42-z*.51-.086*absf(x),z*s)
				var b:=center+Vector3(dx,6.42-z*.51-.086*absf(dx),z*s)
				var c:=center+Vector3(dx,6.36-dz*.51-.086*absf(dx),dz*s)
				var d:=center+Vector3(x,6.36-dz*.51-.086*absf(x),dz*s)
				var tint:=Color("#6d6547").lerp(Color("#a29361"),(.5+.5*sin(i*3.25+j*5.1))*.70)
				view._tri(roof,a,c,b,tint)
				view._tri(roof,a,d,c,tint.darkened(.06))
	view._positioned(roof.commit(),Vector3.ZERO,null)
	for i in 5:
		var p:=spot+Vector2(-.2-i*.41,3.15+i*.81)
		view._rock(view._at(p,.09),Vector3(1.20,.22,.92),pale,i*.62)

static func _lath(view,p:Vector2,timber:Material,edge:Material)->void:
	for side:float in [-1.0,1.0]:
		var end:=p+Vector2(side*7.4,0)
		var a:=view._at(end+Vector2(0,-2.05),3.41) as Vector3
		var b:=view._at(end+Vector2(0,2.05),2.79) as Vector3
		view._timber(view._at(end+Vector2(0,-2.05)),a,.15,timber,7)
		view._timber(view._at(end+Vector2(0,2.05)),b,.15,timber,7)
		view._timber(a,b,.13,timber,7)
	for i in 17:
		var t:=p+Vector2((i-8)*.96,0)
		view._timber(view._at(t+Vector2(0,-2.05),3.45),view._at(t+Vector2(0,2.05),2.83),.098,edge,6)

static func _regional_read(view,anchor:Vector2,well:Vector2)->void:
	# Far-only contrast geometry kept away from the independently approved close lens.
	var dark:=_surface(view,Color.WHITE)
	var rim:=_surface(view,Color.WHITE)
	for lane in 3:
		var center:=anchor+Vector2(8,-10-lane*7)
		for i in 42:
			for j in 9:
				var p:=center+Vector2((i-21)*.67,(j-4.5)*.58)
				var east:=Vector2(.67,0)
				var south:=Vector2(0,.58)
				var a:Vector3=view._at(p,.13)
				var b:Vector3=view._at(p+east,.13)
				var c:Vector3=view._at(p+east+south,.13)
				var d:Vector3=view._at(p+south,.13)
				var dye:=Color("#322e24").lerp(Color("#44392a"),(.5+.5*sin(i*.44+lane*2.2))*.7)
				view._tri(dark,a,c,b,dye)
				view._tri(dark,a,d,c,dye)
		var endcap:=Color("#c4bb8c") if lane==0 else Color("#9f9b71")
		for i in range(-14,14):
			var p:=center+Vector2(i,2.61)
			var a:Vector3=view._at(p,.43)
			var b:Vector3=view._at(p+Vector2(1,0),.43)
			var c:Vector3=view._at(p+Vector2(1,1.10),.43)
			var d:Vector3=view._at(p+Vector2(0,1.10),.43)
			view._tri(rim,a,c,b,endcap)
			view._tri(rim,a,d,c,endcap)
	var center:Vector3=view._at(well,1.24)
	for i in 20:
		var a:=Vector3(cos(i*TAU/20.),0,sin(i*TAU/20.))
		var b:=Vector3(cos((i+1)*TAU/20.),0,sin((i+1)*TAU/20.))
		var dye:=Color("#dbc58d")
		view._tri(rim,center+a*3.62,center+a*2.12,center+b*3.62,dye)
		view._tri(rim,center+b*3.62,center+a*2.12,center+b*2.12,dye)
	for patch:SurfaceTool in [dark,rim]:
		# Group around local bounds; Godot evaluates visibility range at the mesh center.
		var instance:MeshInstance3D=view._positioned(patch.commit(),Vector3.ZERO,null)
		instance.visibility_range_begin=170.
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
