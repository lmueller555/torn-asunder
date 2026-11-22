extends RefCounted
## Artist-only ground dressing for exact audited Well Road relief.
const PadShader:=preload("res://game/overworld/raska/compound_surface.gdshader")
const StoneShader:=preload("res://game/overworld/raska/compound_stone.gdshader")
const RUST:=Color("#96715a")
const CREAM:=Color("#b79c7d")
const SILT:=Color("#84735f")
const SHALE:=Color("#6c5545")
const DRY:=Color("#958159")
var rng:=RandomNumberGenerator.new()
var rays:=0
var misses:=0
var route_gap:=INF
var grounded_error:=0.
var pads:=SurfaceTool.new()
var rocks:=SurfaceTool.new()
var brush:=SurfaceTool.new()
var space:PhysicsDirectSpaceState3D

func compose(view:Node3D)->Node3D:
	rng.seed=923687
	space=view.get_world_3d().direct_space_state
	pads.begin(Mesh.PRIMITIVE_TRIANGLES)
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	brush.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A paired footprint, not a new building; contrast different soil on the raised
	# stone apron and low compacted silt yard. Both existing silhouettes remain.
	yard(view,view.UPPER,Vector2(13.4,9.0),.26,CREAM)
	yard(view,view.LOWER+Vector2(1.5,.4),Vector2(14.3,9.4),.14,SILT)
	swept(view,[Vector2(-91,-17),Vector2(-101,-12),Vector2(-104,-5),Vector2(-106,-1.5)],2.8,CREAM)
	swept(view,[Vector2(-102,4),Vector2(-101,13),Vector2(-100,21),Vector2(-94,26)],3.6,SILT.lerp(CREAM,.48))
	# Dry wash shoulder, bent real terrain crag and loose strata off both routes.
	for focus:Array in [[Vector2(-64,64),Vector2(18,6),.82,31],[Vector2(-20,34),Vector2(14,6),1.25,23],
		[Vector2(8,87),Vector2(21,8),1.5,27],[Vector2(55,23),Vector2(13,7),.95,24],
		[Vector2(81,69),Vector2(18,8),.98,32],[Vector2(114,-19),Vector2(14,6),.78,22],
		[Vector2(-62,-20),Vector2(12,6),.84,22],[Vector2(-113,10),Vector2(8,4),.73,15]]:
		context(view,focus[0],focus[1],focus[2],focus[3])
	var group:=Node3D.new()
	group.name=&"WellRoadCohesiveContext"
	commit(group,pads,"YardHardscapeAndDust",PadShader,false)
	commit(group,rocks,"DryScarpAndFoundation",StoneShader,true)
	commit(group,brush,"GroupedDryGroundcover",StoneShader,true)
	return group

func foot(view:Node3D,p:Vector2)->Vector3:
	var e:Vector3=view.at(p)
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(e+Vector3.UP*8.,e+Vector3.DOWN*8.))
	if hit.is_empty() or hit.collider.get_parent()!=view.terrain:
		misses+=1
		return e
	grounded_error=maxf(grounded_error,absf(hit.position.y-e.y))
	rays+=1
	return hit.position

func yard(view:Node3D,c:Vector2,r:Vector2,phase:float,color:Color)->void:
	var pos:PackedVector3Array
	var palette:PackedColorArray
	const N:=12
	const D:=52
	for j in range(N+1):
		var u:=j/float(N)
		for i in range(D+1):
			var a:=TAU*i/D+phase
			var radius:=u*(1.0+.067*sin(a*5.2)+.035*sin(a*9.))
			var point:=c+Vector2(cos(a)*r.x,sin(a)*r.y)*radius
			var g:=foot(view,point)
			var dye:=color.lerp(RUST,.21+sin(a*2.4)*.052+rng.randf_range(.02,.14))
			dye.a=(1.0-smoothstep(.69,1.0,u))*.80
			pos.append(g+Vector3.UP*(.084+.05*(1.-u)))
			palette.append(dye.srgb_to_linear())
	for j in range(N):
		for i in range(D):
			var a:=j*(D+1)+i
			var b:=a+D+1
			for k in [a,a+1,b,a+1,b+1,b]:
				pads.set_color(palette[k])
				pads.add_vertex(pos[k])
	# Broad weathered stone from the sunk well/storehouse entrance, no doors added.
	var runlen:=9 if c==view.UPPER else 6
	for j in range(3):
		for i in range(runlen):
			var x:=c.x-5.5+i*1.19+(j%2)*.40
			var z:=c.y+4.8+j*.83
			if c!=view.UPPER:
				x=c.x-7.9+i*1.23+(j%2)*.39
				z=c.y-6.1-j*.90
			if (i+2*j)%13==0: continue
			var q:=Vector2(x,z)
			block(foot(view,q)+Vector3.DOWN*.11,Vector3(rng.randf_range(1.11,1.34),.32,rng.randf_range(.74,1.10)),rng.randf_range(-.19,.14),color.lerp(CREAM,.58))

func swept(view:Node3D,cells:Array,width:float,tint:Color)->void:
	var pos:PackedVector3Array
	var palette:PackedColorArray
	var sections:=0
	for i in range(cells.size()-1):
		var a:Vector2=cells[i]; var b:Vector2=cells[i+1]
		var v:=(b-a).normalized()
		var across:=Vector2(-v.y,v.x)
		for j in range(5 if i<cells.size()-2 else 6):
			var t:=j/5.
			var progress:float=(i+t)/(cells.size()-1)
			var squash:float=(.7+sin(progress*PI)*.3)*width
			var center:=a.lerp(b,t)
			for d:float in [-1.0,-.54,.0,.54,1.0]:
				var q:=center+across*(squash*d+(absf(d)*rng.randf_range(-.24,.24)))
				var a0:=foot(view,q)
				var c:=tint.lerp(RUST,.12+rng.randf_range(.02,.17))
				c.a=(1.0-smoothstep(.47,1.0,absf(d)))*smoothstep(0,.21,progress)*(1.0-smoothstep(.83,1.,progress))*.67
				pos.append(a0+Vector3.UP*.085)
				palette.append(c.srgb_to_linear())
			sections+=1
	for j in range(sections-1):
		for i in range(4):
			var a:=j*5+i
			var b:=a+5
			for k in [a,a+1,b,a+1,b+1,b]:
				pads.set_color(palette[k])
				pads.add_vertex(pos[k])

func context(view:Node3D,c:Vector2,r:Vector2,scale_:float,count:int)->void:
	for i in range(count):
		var q:=c+Vector2(rng.randf_range(-r.x,r.x),rng.randf_range(-r.y,r.y))
		var wash:Vector2=view.profile(q.x,q.y)
		var clearance:=minf(wash.x,absf(q.y))
		if clearance<8.5 or q.distance_to(view.UPPER)<13. or q.distance_to(view.LOWER)<15.: continue
		if q.distance_to(view.WEST)<10. or q.distance_to(view.EAST)<14.: continue
		route_gap=minf(route_gap,clearance)
		var p:=foot(view,q)
		var sz:=rng.randf_range(.37,1.67)*scale_
		if i%5==0:
			# A handful of shallow layered shelves, not new mountains or cover collision.
			for row in range(3):
				block(p+Vector3(.19*row,-.27+row*sz*.17,-.11*row),
					Vector3(sz*(2.43-.35*row),sz*.28,sz*(1.84-.27*row)),rng.randf_range(-.24,.24),SHALE.lerp(RUST,.63-row*.047))
		elif i%3==0:
			add_brush(p,sz)
		else:
			block(p-Vector3.UP*.12,Vector3(sz*1.38,sz*.50,sz*1.09),rng.randf_range(-PI,PI),SHALE.lerp(CREAM,rng.randf_range(.19,.54)))

func add_brush(p:Vector3,h:float)->void:
	for i in range(6):
		var a:=float(i)*2.4
		var d:=Vector3(cos(a),0,sin(a))
		var right:=Vector3(d.z,0,-d.x)*.07*h
		var root:=p+d*.12*h
		var mid:=root+d*.33*h+Vector3.UP*(.29*h)
		var tip:=mid+d*.37*h+Vector3.UP*rng.randf_range(.21,.31)*h
		var pigment:=DRY.lerp(RUST,rng.randf_range(.06,.41)).srgb_to_linear()
		for v:Vector3 in [root-right,root+right,mid+right*.57,root-right,mid+right*.57,mid-right*.57,mid-right*.57,mid+right*.57,tip]:
			brush.set_color(pigment)
			brush.add_vertex(v)

func block(at:Vector3,s:Vector3,yaw:float,tint:Color)->void:
	var rim: Array[Vector2]=[Vector2(-.5,-.28),Vector2(-.31,-.5),Vector2(.33,-.47),Vector2(.49,-.27),
		Vector2(.52,.33),Vector2(.31,.50),Vector2(-.28,.48),Vector2(-.51,.26)]
	var m:=Basis(Vector3.UP,yaw)
	var pts:PackedVector3Array
	for j in range(3):
		for q in rim:
			var d:=.84 if j==2 else 1.
			pts.append(at+m*Vector3(q.x*s.x*d,j*.5*s.y+rng.randf_range(-.04,.04),q.y*s.z*d))
	for j in range(2):
		for i in range(rim.size()):
			var k:=(i+1)%rim.size()
			var a:=j*8
			for t in [a+i,a+k,a+i+8,a+k,a+k+8,a+i+8]:
				rocks.set_color(tint.darkened(.15-j*.07).srgb_to_linear())
				rocks.add_vertex(pts[t])
	for i in range(1,7):
		for t in [16,16+i,17+i]:
			rocks.set_color(tint.srgb_to_linear())
			rocks.add_vertex(pts[t])

func commit(group:Node3D,s:SurfaceTool,key:String,shader:Shader,cast:bool)->void:
	s.generate_normals()
	var instance:=MeshInstance3D.new()
	instance.name=key
	instance.mesh=s.commit()
	var surface:=ShaderMaterial.new()
	surface.shader=shader
	instance.material_override=surface
	if not cast: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(instance)
