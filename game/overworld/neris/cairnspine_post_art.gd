extends RefCounted
## Neutral Cairnspine post. Low stone structures work as windscreens, not a fort.
static func build(v,post:Vector2)->void:
	var site:=post+Vector2(-3.4,-8.5)
	var origin:Vector3=v._at(site)
	var timber:Material=v._paint("#5d4c3e")
	var beam:Material=v._paint("#84705a")
	var colors:Array[Material]=[v._paint("#6e6e5e"),v._paint("#98927b"),v._paint("#7d7968"),v._paint("#9b9985")]
	# Three ashlar courses make the two shelter wings; the roadside front remains open.
	for side:float in [-1.0,1.0]:
		for i in 5:
			var p:=site+Vector2(side*4.86,(i-2)*.91)
			_ashlar(v,p,.95,1.04,2,PI*.50,colors,i)
		var back:=site+Vector2(side*3.75,-2.43)
		for i in range(-1,2):
			_ashlar(v,back+Vector2(i*.93,0),1.00,.96,3,0.,colors,i+2)
		var post_a:Vector3=v._at(site+Vector2(side*4.1,2.68))
		var post_b:Vector3=v._at(site+Vector2(side*4.1,-2.43),.55)
		var front:=origin+Vector3(side*4.02,4.42,2.55)
		var rear:=origin+Vector3(side*4.02,4.42,-2.5)
		v._timber(post_a,front,.28,timber,8)
		v._timber(post_b,rear,.24,timber,8)
		v._timber(front,rear,.21,beam,8)
		v._timber(front-Vector3.UP*.94,front+Vector3(-side*.91,0,0),.122,beam,7)
		v._timber(rear-Vector3.UP*.80,rear+Vector3(-side*.84,0,0),.106,beam,7)
		var brace:=origin+Vector3(0,6.47,side*0.)
		v._timber(front,Vector3(front.x,brace.y,origin.z),.16,timber,7)
		v._timber(rear,Vector3(rear.x,brace.y,origin.z),.16,timber,7)
	v._timber(origin+Vector3(-5.55,6.54,0),origin+Vector3(5.55,6.54,0),.145,beam,8)
	var tile:=_surface(v,Color.WHITE)
	for side:float in [-1.0,1.0]:
		for row in 6:
			for i in 17:
				var x:=lerpf(-5.56,5.56,i/17.0)
				var xx:=lerpf(-5.56,5.56,(i+1.07)/17.0)
				var low:=row*.69
				var high:=(row+1.20)*.69
				var a:=origin+Vector3(x,4.16+low*.57,side*(4.13-low))
				var b:=origin+Vector3(xx,4.16+low*.57,side*(4.13-low))
				var c:=origin+Vector3(xx-.06,4.09+high*.57,side*maxf(0,4.13-high))
				var d:=origin+Vector3(x-.06,4.09+high*.57,side*maxf(0,4.13-high))
				var dye:=Color("#484b48").lerp(Color("#757564"),(.5+.5*sin(i*2.29+row*5.61+side))*.67)
				if side>0 and row<2: dye=dye.lerp(Color("#78795a"),.25)
				v._tri(tile,a,b,c,dye)
				v._tri(tile,a,c,d,dye.darkened(.055))
				v._tri(tile,a-Vector3.UP*.13,a,b,dye.darkened(.26))
				v._tri(tile,a-Vector3.UP*.13,b,b-Vector3.UP*.13,dye.darkened(.28))
	v._positioned(tile.commit(),Vector3.ZERO,null)
	# Shelter sits in front of a curved crosswind wall; the track enters west past the low wall.
	for i in 29:
		var x:=i*.88-14.4
		var p:=site+Vector2(x,-6.02+.025*(x+2.)*(x+2.))
		_ashlar(v,p,.98,1.77,3 if i in range(4,24) else 2,.025*(x+2.),colors,i)
	for i in 9:
		var p:=site+Vector2(6.8+i*.91,-1.6+i*.2)
		_ashlar(v,p,.96,1.26,2,.11,colors,i+4)
	# Weathered unlettered slate at the yard, not a clue or readable gameplay document.
	var notice:=site+Vector2(2.76,3.21)
	var matte:Material=v._paint("#4a5450",.95)
	v._timber(v._at(notice+Vector2(-.63,0)),v._at(notice+Vector2(-.63,0),2.18),.091,timber,6)
	v._timber(v._at(notice+Vector2(.63,0)),v._at(notice+Vector2(.63,0),2.18),.091,timber,6)
	var slate:=BoxMesh.new()
	slate.size=Vector3(1.79,.91,.105)
	v._positioned(slate,v._at(notice,1.73),matte,-.21)
	# Scattered vegetation and stone on the softened south shoulder only.
	for i in 15:
		var theta:=.93*i+.18*sin(i*2.7)
		var p:=post+Vector2(12.+cos(theta)*(7.+i*.81),15.8+absf(sin(theta))*(3.+i*.89))
		if i%3==0:
			v._rock(v._at(p,.14),Vector3(1.2,.52,.91)*(1.+.3*cos(i)),colors[2],theta)
		else:
			var shrub:MeshInstance3D=v._positioned(v._variants[1],v._at(p,-.14),null,theta)
			shrub.scale=Vector3(.19,.12,.23)*(1.+.24*cos(i))
	_regional_outline(v,origin,colors)
	var boundary:=post+Vector2(1.8,-2.4)
	v._rock(v._at(boundary,1.12),Vector3(1.29,2.48,1.04),colors[2],.19)
	v._rock(v._at(boundary,1.48),Vector3(1.16,.19,1.06),colors[1],.19)

static func _regional_outline(v,origin:Vector3,palette:Array[Material])->void:
	# Restrained distant ridge/stone contrast. The nearer mesh remains different
	# materials and full geometry, and does not get duplicate silhouettes.
	var ridge:=BoxMesh.new()
	ridge.size=Vector3(12.3,.35,.80)
	var roof:MeshInstance3D=v._positioned(ridge,origin+Vector3(0.0,6.49,0),v._paint("#615b4a"))
	roof.visibility_range_begin=170.
	roof.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 14:
		var x:=i*1.88-12.38
		var p:=Vector2(origin.x+x,origin.z-6.02+.025*(x+2.)*(x+2.))
		var coping:=BoxMesh.new()
		coping.size=Vector3(1.87,.19,1.31)
		var tile:MeshInstance3D=v._positioned(coping,v._at(p,1.21),palette[1],.025*(x+2.))
		tile.visibility_range_begin=170.
		tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _ashlar(v,p:Vector2,width:float,depth:float,levels:int,angle:float,palette:Array[Material],seed:int)->void:
	for layer in levels:
		var stone:=BoxMesh.new()
		stone.size=Vector3(width*(.92+.11*cos(seed*1.9+layer)),.51-layer*.065,depth*(1.-layer*.1))
		var offset:=Vector2(cos(angle),-sin(angle))*(layer*.13)
		v._positioned(stone,v._at(p+offset,.16+layer*.405+.023*cos(seed*1.8)),palette[posmod(seed+layer*3,4)],angle+.038*sin(seed+layer))
	if levels==3:
		var cap:=BoxMesh.new()
		cap.size=Vector3(width*1.035,.17,depth*.87)
		v._positioned(cap,v._at(p,1.18),palette[1],angle)

static func _surface(v,tint:Color)->SurfaceTool:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m:StandardMaterial3D=v._paint(tint.to_html())
	m.vertex_color_use_as_albedo=true
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	s.set_material(m)
	return s
