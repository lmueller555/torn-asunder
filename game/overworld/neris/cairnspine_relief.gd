extends "res://game/overworld/neris/grove_relief.gd"
## Private, continuous same-terrain extension. No canonical world distance asserted.
const POST:=Vector2(419,-131)
const GUIDES:=[NURSERY, Vector2(174,-40), Vector2(207,-47), Vector2(236,-60), Vector2(277,-72),
	Vector2(312,-80), Vector2(343,-95), Vector2(373,-112), Vector2(393,-116), POST]
const TRACK:=[Vector2(310,-80),Vector2(325,-104),Vector2(345,-121),Vector2(365,-126),
	Vector2(387,-140),Vector2(402,-142),Vector2(417,-136)]
var _extension:Curve3D
const EARTH:=preload("res://game/overworld/neris/cairnspine_earth.gdshader")

func _after_terrain()->void:
	super._after_terrain()
	_post_landmark()

func height(x:float,z:float)->float:
	var native:=super.height(x,z)
	if x<=163.0 or x>=482.0 or z < -179.0 or z > -10.0:
		return native
	var bed:=_freight_ground(x,z,native)
	if x<315.0 or x>415.0:
		return bed
	var track_z:=_track_z(x)
	var offset:=z-track_z
	var envelope:=smoothstep(321.,342.,x)*(1.0-smoothstep(391.,413.,x))
	var depth:=3.8*envelope
	# The shelf is screened north and south, then blends back toward the open yard.
	var notch:=bed-depth*(1.0-smoothstep(2.,11.,absf(offset)))
	if offset>=0.0 or offset<=-19.0:
		return notch
	var floor:=_freight_ground(x,track_z,super.height(x,track_z))-depth
	var screen:=smoothstep(0.0,7.0,-offset)*(1.0-smoothstep(10.,19.,-offset))*envelope
	return lerpf(notch,maxf(notch,floor+2.20),screen)

func _freight_ground(x:float,z:float,native:float)->float:
	var xs:=minf(x,POST.x)
	var ix:=1
	while ix<GUIDES.size()-2 and xs>GUIDES[ix+1].x:
		ix+=1
	var a:Vector2=GUIDES[ix]
	var b:Vector2=GUIDES[ix+1]
	var blend:=clampf(inverse_lerp(a.x,b.x,xs),0,1)
	var cross:=absf(z-lerpf(a.y,b.y,blend))
	# Below the wind-sheltered saddle, the gentle engineered road grades into the existing hillside.
	var center_height:=19.29+.0815*(xs-174.)+1.65*sin((xs-174.0)*.026)
	var shoulder_span:=30.0+15.0*smoothstep(340.,425.,x)
	if z>lerpf(a.y,b.y,blend):
		shoulder_span+=28.0*smoothstep(388.0,428.0,x)*(1.0-smoothstep(462.0,482.0,x))
	var shoulder:=1.0-smoothstep(7.0,shoulder_span,cross)
	shoulder*=smoothstep(163.,182.,x)*(1.0-smoothstep(428.,482.,x))
	return lerpf(native,center_height,shoulder)

func _track_z(x:float)->float:
	for i in range(TRACK.size()-1):
		var a:Vector2=TRACK[i]
		var b:Vector2=TRACK[i+1]
		if x<=b.x:
			return lerpf(a.y,b.y,clampf(inverse_lerp(a.x,b.x,x),0,1))
	return TRACK[-1].y

func boundary_contract()->Curve3D:
	if _extension:
		return _extension
	_extension=Curve3D.new()
	_extension.bake_interval=.23
	for i in range(GUIDES.size()-1):
		var a:Vector2=GUIDES[maxi(i-1,0)]
		var b:Vector2=GUIDES[i]
		var c:Vector2=GUIDES[i+1]
		var d:Vector2=GUIDES[mini(i+2,GUIDES.size()-1)]
		for k in maxi(2,ceili(b.distance_to(c)/.55)):
			var t:=float(k)/maxi(2,ceili(b.distance_to(c)/.55))
			_extension.add_point(_at(b.cubic_interpolate(c,a,d,t),.38))
	_extension.add_point(_at(POST,.38))
	return _extension

func _build_route()->void:
	_ground_material.shader=EARTH
	super._build_route()
	var line:=boundary_contract()
	var ink:=Rect2(134,-155,307,135)
	var mask:=Image.create(896,480,false,Image.FORMAT_L8)
	for i in ceili(line.get_baked_length()*3.0):
		var v:=line.sample_baked(i/3.0)
		var uv:=(Vector2(v.x,v.z)-ink.position)/ink.size
		var point:=Vector2i(uv*Vector2(mask.get_size()))
		for dy in range(-17,18):
			for dx in range(-16,17):
				var radius:=Vector2(dx*ink.size.x/896.0,dy*ink.size.y/480.0).length()
				var shade:=1.0-smoothstep(2.34,4.75,radius)
				var px:=point.x+dx
				var py:=point.y+dy
				if shade>.006 and mask.get_pixel(px,py).r<shade:
					mask.set_pixel(px,py,Color(shade,shade,shade))
	var track:=Image.create(896,480,false,Image.FORMAT_L8)
	for i in 430:
		var x:=lerpf(TRACK[0].x,TRACK[-1].x,i/429.)
		var z:=_track_z(x)
		var point:=Vector2i(((Vector2(x,z)-ink.position)/ink.size)*Vector2(track.get_size()))
		for dy in range(-8,9):
			for dx in range(-7,8):
				var center_dist:=Vector2(dx*ink.size.x/896.,dy*ink.size.y/480.).length()
				var shade:float=1.0-smoothstep(1.,2.25,center_dist)
				var px:=point.x+dx
				var py:=point.y+dy
				if track.get_pixel(px,py).r<shade:
					track.set_pixel(px,py,Color(shade,shade,shade))
	var yard:=Image.create(896,480,false,Image.FORMAT_L8)
	var yard_center:=POST+Vector2(-3.4,-4.2)
	for y in range(42,133):
		for x in range(785,893):
			var world:=ink.position+(Vector2(x,y)/Vector2(896,480))*ink.size
			var r:=((world-yard_center)/Vector2(11.6,6.6)).length()
			var coverage:=1.0-smoothstep(.66,1.0,r+.046*sin(x*.64+y*.77))
			if coverage>.009:
				yard.set_pixel(x,y,Color(coverage,coverage,coverage))
	# Two subtle wheel wear tracks just before the yard, not another selectable way.
	var ruts:=Image.create(896,480,false,Image.FORMAT_L8)
	var finish:=line.get_baked_length()
	for step in 140:
		var station:=finish-61.0+step*.40
		var pos:=line.sample_baked(station)
		var tangent:=line.sample_baked(station+.65)-line.sample_baked(station-.65)
		var lateral:=Vector2(-tangent.z,tangent.x).normalized()
		var wear:=smoothstep(0.0,10.0,step)*(1.0-smoothstep(122.0,139.0,step))*(.80+.15*sin(step*.531))
		for side:float in [-1.0,1.0]:
			var world:=Vector2(pos.x,pos.z)+lateral*side*(1.32+.12*sin(step*.09))
			var point:=Vector2i(((world-ink.position)/ink.size)*Vector2(ruts.get_size()))
			for dy in range(-2,3):
				for dx in range(-2,3):
					var shade:=wear*(1.0-smoothstep(.07,.55,Vector2(dx*ink.size.x/896.0,dy*ink.size.y/480.0).length()))
					var x:=point.x+dx
					var y:=point.y+dy
					if ruts.get_pixel(x,y).r<shade:
						ruts.set_pixel(x,y,Color(shade,shade,shade))
	_ground_material.set_shader_parameter("rut_mask",ImageTexture.create_from_image(ruts))
	_ground_material.set_shader_parameter("yard_mask",ImageTexture.create_from_image(yard))
	_ground_material.set_shader_parameter("track_mask",ImageTexture.create_from_image(track))
	_ground_material.set_shader_parameter("connector_mask",ImageTexture.create_from_image(mask))
	_ground_material.set_shader_parameter("connector_domain",Vector4(ink.position.x,ink.position.y,ink.size.x,ink.size.y))

func _filter_tree(p:Vector2)->bool:
	if p.x<165.0 or p.x>451.0:
		return false
	if p.distance_to(POST+Vector2(-3,-6))<23.0:
		return true
	if p.x>314.0 and p.x<421. and absf(p.y-_track_z(p.x))<4.5:
		return true
	for i in range(GUIDES.size()-1):
		var a:Vector2=GUIDES[i]
		var b:Vector2=GUIDES[i+1]
		if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<8.3:
			return true
	return false

func _post_landmark()->void:
	preload("res://game/overworld/neris/cairnspine_post_art.gd").build(self,POST)

func boundary_region()->void:
	var look:=_at(Vector2(281,-83),8.)
	$Camera.position=look+Vector3(40,290,372)
	$Camera.look_at(look)
