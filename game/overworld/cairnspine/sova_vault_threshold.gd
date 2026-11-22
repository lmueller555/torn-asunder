extends "res://game/overworld/cairnspine/sova_assembly_court.gd"
## Civil threshold, fully shut. Stone and erosion only: no signal, symbols,
## active mechanism, actors or quest data. West-facing threshold and apron.

const PaleStone := preload("res://game/overworld/cairnspine/sova_vault_stone.gdshader")
const SILT := preload("res://game/overworld/cairnspine/sova_vault_apron.gdshader")
const SLATE := Color("#615d52")
const STRATUM := Color("#897d6a")
const TOP := Color("#ab9780")
const SEALED := Color("#a89980")
var apron_surface := SurfaceTool.new()
var finery := {}


static func mount(read: Callable) -> Node3D:
	var maker := new()
	maker.soil=read
	maker.surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	maker.apron_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	maker._portal()
	maker._apron()
	var art:=Node3D.new()
	art.name="CairnspineVaultThreshold"
	maker._commit(art)
	return art


func _portal() -> void:
	var middle := _ground(Vector2(160,-16))
	# Weathered wedge stones form a low segmental crown over a recessed
	# monolithic leaf; the arch is structural, not freestanding scenery.
	var lintel_spring := middle.y+2.81
	for side: float in [-1,1]:
		var buttress := _ground(Vector2(159.1,-16.0+side*4.08))
		_block(buttress,Vector3(6.4,1.16,3.3),side*.055,side+6.7,SLATE)
		for step in range(4):
			var tier := float(step)
			_block(buttress+Vector3(.38*tier,.85+tier*.96,-side*.19*tier),
				Vector3(5.94-tier*.68,1.05,3.01-tier*.34),side*.038,23.19*tier+side,STRATUM.lerp(TOP,tier*.075))
		for step in range(3):
			var tier := float(step)
			var foot := _ground(Vector2(157.8+tier*1.32,-16+side*(5.38+tier*1.63)))
			_block(foot,Vector3(5.16+tier*.54,1.18-tier*.14,2.41+tier*.42),side*.21,
				tier*13.3+side,SLATE.lerp(STRATUM,tier*.15))
			_block(foot+Vector3(.33,.68,side*.11),Vector3(4.65+tier*.35,.50,1.93+tier*.42),side*.24,
				tier*5.9+side,STRATUM.darkened(.09))
		# Narrow carved rebated jamb, using stepped shoulders and small sunk
		# channels, without invented script or symbology.
		var jamb:=_ground(Vector2(157.38,-16+side*2.68))
		for i in range(4):
			var tier:=float(i)
			_block(jamb+Vector3(tier*.09,tier*.72,-side*tier*.025),
				Vector3(1.85,.82,.72),side*.009,tier*8+side,TOP if i%2==0 else STRATUM)
		_block(jamb+Vector3(-.51,.10,-side*.42),Vector3(.49,.35,.49),.0,side+4.67,SLATE)
	for i in range(11):
		var a:=lerpf(PI,0.0,i/11.0)
		var b:=lerpf(PI,0.0,(i+1)/11.0)
		var tint:=STRATUM.lerp(TOP,.37+.16*cos(i*1.8))
		_wedge(lintel_spring,a-.013,b+.013,tint, i)
		# Closed face fills the arch; shallow chased grooves do not expose
		# any opening between the leaf and the stone.
		var d:=middle+Vector3(-1.64,2.81+sin(a)*1.64,cos(a)*2.18)
		var e:=middle+Vector3(-1.64,2.81+sin(b)*1.64,cos(b)*2.18)
		_triangle(d,e,middle+Vector3(-1.64,2.75,0),SEALED)
	_block(middle+Vector3(-1.61,.005,0),Vector3(.48,3.05,4.46),.0,12.45,SEALED)
	_block(_ground(Vector2(157.91,-16)),Vector3(1.33,.22,4.65),.0,3.11,STRATUM.lightened(.12))
	for side: float in [-1,1]:
		for i in range(3):
			var offset:=.43+float(i)*.46
			var line:=Vector3(158.12,middle.y+.44,-16+side*offset)
			_rectangle(line,line+Vector3(0,1.93,0),.035,SLATE.darkened(.2))
	# Settle the outer shoulders under irregular split caps into real terrain.
	for i in range(7):
		var p:=_ground(Vector2(162.9+sin(i*2.1)*.94,-21.7+i*1.89))
		_block(p+Vector3.UP*(2.85+sin(i*1.64)*.49),Vector3(5.04,.87,2.31),
			sin(i*.9)*.17,i*9.41,STRATUM.darkened(.10))


func _wedge(spring: float,a: float,b: float,tone: Color,i: int) -> void:
	var points:=PackedVector3Array()
	for x in [157.26 + sin(float(i)*7.8)*.055,159.94]:
		for radius in [1.0,1.27+cos(i*3.77)*.027]:
			for angle in [a,b]:
				points.append(Vector3(x,spring+sin(angle)*1.66*radius,-16+cos(angle)*2.16*radius))
	for q in [[0,1,3,2],[4,6,7,5],[0,2,6,4],[1,5,7,3],[0,4,5,1],[2,3,7,6]]:
		_triangle(points[q[0]],points[q[1]],points[q[2]],tone)
		_triangle(points[q[0]],points[q[2]],points[q[3]],tone)


func _rectangle(a: Vector3,b: Vector3,half: float,tone: Color) -> void:
	var left:=Vector3(0,0,half)
	_triangle(a-left,b-left,b+left,tone)
	_triangle(a-left,b+left,a+left,tone)


func _apron() -> void:
	var old:=PackedVector3Array()
	for row in range(19):
		var x:=lerpf(123.0,159.1,row/18.0)
		var layer:=PackedVector3Array()
		for col in range(13):
			var w:=(col-6)/6.0
			var span:=lerpf(2.15,4.65,pow(row/18.0,1.4))
			var p:=Vector2(x+cos(row*2.6+col*.61)*.21,-16.0+w*span+sin(row*.77+col)*.25)
			var hit:=_ground(p)
			var stone:=hit+Vector3.UP*.050
			var end_fade:=smoothstep(0.0,.28,row/18.0)
			finery[stone]=end_fade*(1.0-smoothstep(.56,1.0,absf(w)))
			layer.append(stone)
		if old.size()>0:
			for col in range(12):
				_skirt(old[col],layer[col],layer[col+1])
				_skirt(old[col],layer[col+1],old[col+1])
		old=layer
	for side:float in [-1,1]:
		for i in range(15):
			if i in [2,8,13]:
				continue
			var x:=132.3+i*1.46
			var p:=_ground(Vector2(x,-16+side*(3.58+sin(i*1.18)*.44+(x-132)*.021)))
			_block(p,Vector3(1.28+cos(i)*.26,.32+absf(cos(i*2.11))*.40,1.51+sin(i*.35)*.27),
				side*(.12+sin(i*.8)*.47),i*3.98+side,STRATUM.darkened(i%3*.11))
		for i in range(6):
			var pad:=_ground(Vector2(151.8+i*.87,-16+side*(1.88+i*.19)))
			_block(pad-Vector3.UP*.024,Vector3(1.01+cos(i)*.11,.11,1.25),side*sin(i*.9)*.32,
				i*.98+side,TOP.darkened(.19+absf(cos(i))*.15))




func _skirt(a: Vector3,b: Vector3,c: Vector3) -> void:
	for v in [a,b,c]:
		apron_surface.set_color(Color(1,1,1,finery[v]))
		apron_surface.add_vertex(v)


func _commit(root:Node3D) -> void:
	for label: String in ["CarvedThreshold","TerracedSlateApron"]:
		var is_stone:=label=="CarvedThreshold"
		var batch:=surface if is_stone else apron_surface
		batch.generate_normals()
		var pigment:=ShaderMaterial.new()
		pigment.shader=PaleStone if is_stone else SILT
		batch.set_material(pigment)
		var piece:=MeshInstance3D.new()
		piece.name=label
		piece.mesh=batch.commit()
		if not is_stone:
			piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(piece)
	root.set_meta(&"vault_support",contacts)
