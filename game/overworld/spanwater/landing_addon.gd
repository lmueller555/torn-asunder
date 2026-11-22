extends Node3D
## Static south bank staging only. No collision, route, households or release state.
const Relief := preload("res://game/overworld/spanwater/spanwater_relief.gd")
const SILT := preload("res://game/overworld/spanwater/landing_silt.gdshader")
const WEATHER := preload("res://game/overworld/spanwater/landing_weather.gdshader")
var _relief: Relief
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _footings: Array[Vector3] = []

func _ready() -> void:
	_relief = get_parent().get_node("SpanwaterRelief") as Relief
	_rng.seed = 9707
	_shelter()
	_berth()
	_approach()
	_shore()
	for id: String in _batches:
		_emit(id,_batches[id])

# Match the exact source mesh grid and its diagonal, rather than using
# analytical heights for thin material patches draped over triangle ground.
static func _grid(i: int, n: int, base: float, extension: float) -> float:
	var p := 2.0*float(i)/n-1.0
	return p*base + p*pow(absf(p),8)*extension

static func _lower(v: float, n: int, base: float, extension: float) -> int:
	var left := 0
	var right := n-1
	while left < right:
		@warning_ignore("integer_division")
		var mid := (left+right+1)/2
		if _grid(mid,n,base,extension) > v:
			right = mid-1
		else:
			left = mid
	return left

func _ground(x: float, z: float) -> float:
	var i := _lower(x,255,300,590)
	var j := _lower(z,205,228,510)
	var ax := _grid(i,255,300,590)
	var bx := _grid(i+1,255,300,590)
	var az := _grid(j,205,228,510)
	var bz := _grid(j+1,205,228,510)
	var u := inverse_lerp(ax,bx,x)
	var v := inverse_lerp(az,bz,z)
	var h10 := _relief.ground(Vector2(bx,az))
	var h01 := _relief.ground(Vector2(ax,bz))
	if u+v <= 1.0:
		return _relief.ground(Vector2(ax,az))*(1-u-v)+h10*u+h01*v
	return _relief.ground(Vector2(bx,bz))*(u+v-1)+h10*(1-v)+h01*(1-u)

func _box(id: String, pos: Vector3, scale_: Vector3, angles := Vector3.ZERO) -> void:
	if not _batches.has(id):
		_batches[id] = []
	_batches[id].append(Transform3D(Basis.from_euler(angles).scaled_local(scale_),pos))

func _beam(id: String, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	if not _batches.has(id):
		_batches[id] = []
	var axis := b-a
	_batches[id].append(Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled_local(
		Vector3(width,axis.length(),depth)),(a+b)*.5))

func _post(x: float, z: float, top: float, width: float) -> void:
	var base := _ground(x,z)
	_footings.append(Vector3(x,base,z))
	_box("Stone",Vector3(x,base+.06,z),Vector3(width*1.7,.48,width*1.54),Vector3(0,.19,0))
	_beam("Wood",Vector3(x,base-.27,z),Vector3(x,top,z),width,width*.91)

func _shelter() -> void:
	# Open outward-facing bay, clear ingress from the dry approaches, timber
	# shade for staging (not evidence that either household is already there).
	const X := 127.5
	const Z := 40.6
	var grade := _ground(X,Z)
	var eaves := grade+4.9
	var crest := eaves+2.10
	for side: float in [-1.0,1.0]:
		for offset: float in [-5.0,0.0,5.0]:
			var p := Vector3(X+offset,eaves,Z+side*2.85)
			_post(p.x,p.z,p.y,.37)
			var nudge := -1.40 if offset>0 else 1.4
			_beam("Wood",p-Vector3.UP*1.20,p+Vector3(nudge,-.12,0),.19,.25)
			_beam("Rafter",p,Vector3(p.x,crest,Z),.23,.26)
		_beam("Wood",Vector3(X-5.55,eaves-.20,Z+side*2.85),
			Vector3(X+5.55,eaves-.20,Z+side*2.85),.30,.38)
		# Individually laid, staggered cleft shingles with exposed fascia.
		var rise := atan2(2.1,3.5)
		for course in 7:
			var run := .32+course*.56
			var y := crest-run*.60
			for panel in 15:
				var jitter := _rng.randf_range(-.041,.041)
				var x: float = X-5.9+panel*.825+(.17 if course%2 else 0)+jitter
				_box("Shingle",Vector3(x,y+jitter,Z+run*side),
					Vector3(.843+_rng.randf_range(-.07,.09),.11,.83),Vector3(side*rise,0,jitter))
	for i in 15:
		_box("Rafter",Vector3(X-5.62+i*.814,crest+.045,Z),Vector3(.850,.24,.64),Vector3(.01,0,.03*sin(i)))
	# Interrupted slat windbreak, deliberately away from the entry-facing side.
	for i in 14:
		if i == 6 or i == 7:
			continue
		var x := X-4.8+i*.37
		var z := Z+2.78
		var floor := _ground(x,z)
		var y := floor+.88+_rng.randf_range(-.02,.14)
		_box("Wood",Vector3(x,y,z),Vector3(.26,1.94,.135),Vector3(0,.02*sin(i),.018*cos(i)))
	for offset: float in [-3.8,3.8]:
		var x := X+offset
		var z := Z+1.45
		var y := _ground(x,z)
		_box("Wood",Vector3(x,y+.34,z),Vector3(1.45,.49,.67))
		for a in [-.53,.53]:
			_box("Rafter",Vector3(x+a,y+.12,z),Vector3(.22,.31,.49))

func _berth() -> void:
	# The original landing stays intact. Outboard mooring posts frame the
	# single usable dock face; no extra branch or boat is drawn.
	for p in [Vector2(110.3,14.1),Vector2(117.4,14.3),Vector2(117.65,20.7),Vector2(117.65,26.52)]:
		_post(p.x,p.y,2.50,.53)
		_box("Rafter",Vector3(p.x,2.53,p.y),Vector3(.50,.16,.50),Vector3(0,.27,0))
	for i in 13:
		var z := 13.0+i*1.14
		_box("Wood",Vector3(117.78,1.35,z),Vector3(.20,.61,1.02),Vector3(0,.02*sin(i),.023*cos(i)))
	for s in [110.54,117.43]:
		for z in [25.7,29.7]:
			_post(s,z,2.27,.25)
		_beam("Rafter",Vector3(s,2.09,25.7),Vector3(s,2.09,29.7),.19,.18)

func _approach() -> void:
	# Four irregular dry pad lobes overlap without touching the original timber
	# walk or painting a path into the river. The existing south walking line
	# remains visible; stones are shoulders, not collision.
	for pair in [Vector3(114,52,5.3),Vector3(116.5,46.8,4.3),Vector3(121.2,44.5,3.5),Vector3(127.2,40.6,5.0)]:
		_ground_wear(Vector2(pair.x,pair.y),Vector2(pair.z,pair.z*.72))
	for side: float in [-1.0,1.0]:
		for i in range(12):
			if i in [4,5,9]:
				continue
			var z := 48.4+i*.92
			var x := 114.4+4.15*side+.27*sin(i*1.5)
			var y := _ground(x,z)
			_box("Stone",Vector3(x,y+.10,z),Vector3(1.05,.44,.92),Vector3(.07,.31*sin(i),.12*cos(i)))

func _ground_wear(c: Vector2, radii: Vector2) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var per := 6
	for j in range(per+1):
		for i in range(n):
			var a := TAU*float(i)/n
			var r := float(j)/per
			var p := c + Vector2(cos(a),sin(a))*r*radii*(.92+.07*sin(a*5+.20)+.04*cos(a*9))
			tool.set_normal(Vector3.UP)
			tool.set_color(Color(1.0,1.0,1.0,1-r*r*r))
			tool.add_vertex(Vector3(p.x,_ground(p.x,p.y)+.037,p.y))
	for j in range(per):
		for i in range(n):
			var a := j*n+i
			var b := j*n+(i+1)%n
			for index in [a,a+n,b,b,a+n,b+n]:
				tool.add_index(index)
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = _material("Silt")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _shore() -> void:
	# Small breaks of rounded rubble and reed stems only outside the usable berth.
	for center: Vector2 in [Vector2(97.8,24),Vector2(103.2,23.8),Vector2(121.9,21.4),Vector2(130,22.4),Vector2(137.7,25.1)]:
		for i in range(17):
			var p := center+Vector2(_rng.randf_range(-2.8,2.8),_rng.randf_range(-3.1,3.1))
			var y := _ground(p.x,p.y)
			if y < .30 or y>3.1:
				continue
			var s := _rng.randf_range(.16,1.28)
			_box("Stone",Vector3(p.x,y-.137*s,p.y),Vector3(s*.75,s*.67,s*1.25),
				Vector3(_rng.randf_range(-.6,.6),_rng.randf_range(-PI,PI),_rng.randf_range(-.6,.6)))
			if i%3 == 0:
				for j in 7:
					var a := Vector3(p.x,y,p.y)+Vector3(_rng.randf_range(-.47,.47),-.08,_rng.randf_range(-.47,.47))
					var b := a+Vector3(_rng.randf_range(-.31,.30),_rng.randf_range(.67,1.64),_rng.randf_range(-.4,.4))
					_beam("Reed",a,b,.043,.054)
					_beam("ReedHead",b-Vector3.UP*.17,b+Vector3.UP*.16,.068,.072)

func _material(id: String) -> ShaderMaterial:
	var colors := {"Wood":"#75503a","Rafter":"#4d3528","Shingle":"#555044",
		"Stone":"#8d8573","Reed":"#6f7946","ReedHead":"#79694c","Silt":"#89745a"}
	var shader := ShaderMaterial.new()
	shader.shader = SILT if id == "Silt" else WEATHER
	shader.set_shader_parameter("tint",Color(colors[id]))
	if id != "Silt":
		shader.set_shader_parameter("timber",id in ["Wood","Shingle","Rafter"])
	return shader

func _emit(id: String, items: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	if id == "Stone":
		var stone := SphereMesh.new()
		stone.radial_segments = 6
		stone.rings = 4
		multi.mesh = stone
	else:
		multi.mesh = BoxMesh.new()
	multi.instance_count = items.size()
	for i in items.size():
		multi.set_instance_transform(i,items[i])
		var tint := _rng.randf_range(.71,1.0)
		multi.set_instance_color(i,Color(tint,tint*.97,tint*.9))
	var node := MultiMeshInstance3D.new()
	node.name = id
	node.multimesh = multi
	node.material_override = _material(id)
	add_child(node)
