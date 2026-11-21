extends Node3D
## Builds a mission battlefield from map data: ground, roads, cliffs, water, props,
## objective markers and lighting. Every mesh is generated, so maps need no art files.

const THEMES := {
	"mountain": {"ground": Color("#4a4e3f"), "accent": Color("#6b6650"), "rock": Color("#77746a"), "sky": Color("#9fb2bd"), "fog": Color("#a9b6b8"), "sun": Color("#ffe6c4")},
	"plains": {"ground": Color("#5d6d3d"), "accent": Color("#71784a"), "rock": Color("#827c6a"), "sky": Color("#a9c3d6"), "fog": Color("#bccbd0"), "sun": Color("#fff0d0")},
	"highland": {"ground": Color("#57624a"), "accent": Color("#6f6a52"), "rock": Color("#7c7b74"), "sky": Color("#8e9ea8"), "fog": Color("#98a4a6"), "sun": Color("#f2e3c8")},
	"coast": {"ground": Color("#8a8266"), "accent": Color("#8a8a6a"), "rock": Color("#8d8a80"), "sky": Color("#b6cfdc"), "fog": Color("#c4d3d8"), "sun": Color("#fff2da")},
	"fen": {"ground": Color("#454c3a"), "accent": Color("#3c4536"), "rock": Color("#5e5f58"), "sky": Color("#6f7a7c"), "fog": Color("#6f7d7a"), "sun": Color("#c9d2d6")},
	"forest": {"ground": Color("#4c5e35"), "accent": Color("#5d6a3c"), "rock": Color("#6e6c62"), "sky": Color("#9fb7bf"), "fog": Color("#a4b3ad"), "sun": Color("#fbe9c9")},
	"salt": {"ground": Color("#b3a68a"), "accent": Color("#9e8f72"), "rock": Color("#8d7a62"), "sky": Color("#c9b9a0"), "fog": Color("#cdbda4"), "sun": Color("#fff0d6")},
	"river": {"ground": Color("#56633f"), "accent": Color("#6a6b48"), "rock": Color("#7a776c"), "sky": Color("#a3b8c2"), "fog": Color("#aebcbf"), "sun": Color("#fbeccd")},
	"vault": {"ground": Color("#5a5a50"), "accent": Color("#6a645a"), "rock": Color("#6d6c68"), "sky": Color("#8a95a3"), "fog": Color("#8f98a2"), "sun": Color("#ffe1bb")},
}

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec4 tint : source_color = vec4(1.0);
uniform float thickness = 0.06;
uniform float pulse = 0.0;
varying vec2 local;
void vertex() { local = VERTEX.xz; }
void fragment() {
	float r = length(local) * 2.0;
	float ring = smoothstep(1.0 - thickness, 1.0 - thickness * 0.5, r) * (1.0 - smoothstep(0.985, 1.0, r));
	float fill = (1.0 - smoothstep(0.0, 1.0, r)) * 0.10;
	float wave = 0.65 + 0.35 * sin(TIME * 2.6 + pulse);
	ALBEDO = tint.rgb;
	ALPHA = clamp((ring + fill) * tint.a * wave, 0.0, 1.0);
}
"""

const BURST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec4 tint : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform vec2 cone_dir = vec2(0.0);
uniform float cone_cos = -2.0;
varying vec2 local;
void vertex() { local = VERTEX.xz; }
void fragment() {
	float r = length(local) * 2.0;
	float front = progress;
	float band = smoothstep(front - 0.18, front, r) * (1.0 - smoothstep(front, front + 0.03, r));
	float inside = (1.0 - smoothstep(0.0, front, r)) * 0.18;
	float cone = 1.0;
	if (cone_cos > -1.5) {
		vec2 dir = normalize(local + vec2(0.0001));
		cone = smoothstep(cone_cos - 0.05, cone_cos + 0.05, dot(dir, cone_dir));
	}
	ALBEDO = tint.rgb;
	ALPHA = clamp((band + inside) * cone * (1.0 - progress * 0.8), 0.0, 1.0);
}
"""

const GROUND_SHADER := """
shader_type spatial;
uniform vec3 base : source_color;
uniform vec3 accent : source_color;
uniform vec2 bounds = vec2(50.0);
varying vec2 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	float n = noise(world * 0.08) * 0.6 + noise(world * 0.35) * 0.3 + noise(world * 1.7) * 0.1;
	vec3 col = mix(base, accent, smoothstep(0.35, 0.75, n));
	vec2 edge = abs(world) - bounds;
	float outside = smoothstep(-2.0, 6.0, max(edge.x, edge.y));
	col *= 0.9 + n * 0.2;
	col = mix(col, col * 0.55, outside);
	ALBEDO = col;
	ROUGHNESS = 0.96;
}
"""

const ROCK_SHADER := """
shader_type spatial;
uniform vec3 rock : source_color;
varying vec3 world;
varying vec3 normal_world;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float n = noise(world * 0.35) * 0.55 + noise(world * 1.4) * 0.3 + noise(world * 5.0) * 0.15;
	float strata = 0.5 + 0.5 * sin(world.y * 2.3 + n * 4.0);
	vec3 col = rock * (0.72 + n * 0.45) * (0.9 + strata * 0.12);
	float top = smoothstep(0.55, 0.9, normal_world.y);
	col = mix(col, rock * vec3(0.78, 0.86, 0.66), top * 0.55);
	col *= mix(0.75, 1.0, smoothstep(0.0, 3.0, world.y));
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep : source_color = vec3(0.10, 0.22, 0.28);
uniform vec3 shallow : source_color = vec3(0.24, 0.42, 0.45);
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	float w = sin(world.x * 0.7 + TIME * 1.1) * sin(world.y * 0.6 - TIME * 0.8);
	ALBEDO = mix(deep, shallow, 0.5 + 0.25 * w);
	ROUGHNESS = 0.18;
	METALLIC = 0.1;
	ALPHA = 0.92;
}
"""

var theme: Dictionary
var _materials: Dictionary = {}
var _ring_shader := Shader.new()
var _burst_shader := Shader.new()
var _zone_markers: Dictionary = {}
var _interact_markers: Array[Node3D] = []
var _dynamic: Dictionary = {}
var _random := RandomNumberGenerator.new()


func build(map: Dictionary, interactables: Array) -> void:
	_random.seed = hash(map.get("name", ""))
	_ring_shader.code = RING_SHADER
	_burst_shader.code = BURST_SHADER
	theme = THEMES.get(map.get("theme", "plains"), THEMES.plains)
	var size: Vector2 = map.get("size", Vector2(100, 100))
	_environment(size)
	_ground(size)
	_border(size)
	for road: Dictionary in map.get("roads", []):
		_road(road)
	for obstacle: Dictionary in map.get("obstacles", []):
		_obstacle(obstacle, self)
	for item: Dictionary in map.get("decor", []):
		_prop(item.kind, item.pos, deg_to_rad(item.get("rot", 0.0)), item.get("scale", 1.0), item.get("color", Color.WHITE))
	for id in map.get("zones", {}):
		var zone: Dictionary = map.zones[id]
		var marker := _ring(zone.radius, Color(0.98, 0.84, 0.55, 0.55), 0.04)
		marker.position = Vector3(zone.pos.x, 0.06, zone.pos.y)
		marker.visible = false
		_zone_markers[id] = marker
	for item: Dictionary in interactables:
		var marker := Node3D.new()
		add_child(marker)
		marker.position = Vector3(item.pos.x, 0, item.pos.y)
		var ring := _ring(3.2, Color(0.75, 0.95, 1.0, 0.8), 0.08)
		remove_child(ring)
		marker.add_child(ring)
		ring.position.y = 0.07
		var beam := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.35
		cylinder.bottom_radius = 0.55
		cylinder.height = 7.0
		beam.mesh = cylinder
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color(0.6, 0.85, 1.0, 0.22)
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = glow
		beam.position.y = 3.5
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(beam)
		_interact_markers.append(marker)
	for id in map.get("dynamic_obstacles", {}):
		var holder := Node3D.new()
		add_child(holder)
		holder.visible = false
		_obstacle(map.dynamic_obstacles[id], holder)
		_dynamic[id] = holder


func show_zone(id: String, visible_now: bool) -> void:
	if _zone_markers.has(id):
		_zone_markers[id].visible = visible_now


func show_interactable(index: int, visible_now: bool, at: Vector2 = Vector2.INF) -> void:
	if index < _interact_markers.size():
		_interact_markers[index].visible = visible_now
		if at != Vector2.INF:
			_interact_markers[index].position = Vector3(at.x, 0, at.y)


func raise_obstacle(id: String) -> void:
	if _dynamic.has(id):
		var holder: Node3D = _dynamic[id]
		holder.visible = true
		holder.scale = Vector3(1, 0.05, 1)
		var tween := create_tween()
		tween.tween_property(holder, "scale", Vector3.ONE, 2.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func burst(radius: float, color: Color, facing: Vector2) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mesh.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = _burst_shader
	material.set_shader_parameter("tint", color)
	if facing != Vector2.ZERO:
		material.set_shader_parameter("cone_dir", facing.normalized())
		material.set_shader_parameter("cone_cos", 0.55)
	mesh.material_override = material
	mesh.scale = Vector3(radius * 2.0, 1, radius * 2.0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func ring_marker(radius: float, color: Color) -> MeshInstance3D:
	return _ring(radius, color, 0.12)


# ---------------------------------------------------------------- building blocks


func _environment(size: Vector2) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = theme.sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.background_color = theme.sky.darkened(0.15)
	environment.ambient_light_color = theme.sky
	environment.ambient_light_energy = 0.38
	environment.fog_enabled = true
	environment.fog_light_color = theme.fog.darkened(0.2)
	environment.fog_density = 0.0022
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = theme.sun
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = theme.sky
	fill.light_energy = 0.3
	add_child(fill)


func _ground(size: Vector2) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size + Vector2(160, 160)
	ground.mesh = plane
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	material.shader = shader
	material.set_shader_parameter("base", theme.ground)
	material.set_shader_parameter("accent", theme.accent)
	material.set_shader_parameter("bounds", size * 0.5)
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _border(size: Vector2) -> void:
	# Ridges just outside the playable bounds frame the field from every camera angle.
	var half := size * 0.5
	var step := 9.0
	var x := -half.x - 6.0
	while x <= half.x + 6.0:
		for side in [-1.0, 1.0]:
			_rock_lump(Vector2(x + _random.randf_range(-2, 2), side * (half.y + 5.0 + _random.randf_range(0, 3))), _random.randf_range(5.0, 8.0), _random.randf_range(5.0, 12.0))
		x += step
	var y := -half.y
	while y <= half.y:
		for side in [-1.0, 1.0]:
			_rock_lump(Vector2(side * (half.x + 5.0 + _random.randf_range(0, 3)), y + _random.randf_range(-2, 2)), _random.randf_range(5.0, 8.0), _random.randf_range(5.0, 12.0))
		y += step


func _rock_lump(at: Vector2, radius: float, height: float) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.material_override = _rock_material()
	mesh.scale = Vector3(radius, height, radius * _random.randf_range(0.8, 1.2))
	mesh.position = Vector3(at.x, height * 0.15, at.y)
	mesh.rotation.y = _random.randf() * TAU
	add_child(mesh)


func _road(road: Dictionary) -> void:
	var points: Array = road.points
	var width: float = road.get("width", 5.0)
	var color: Color = theme.ground.lerp(Color("#8a7a5c"), 0.45)
	match road.get("kind", ""):
		"riverbed":
			color = theme.ground.lerp(Color("#c2ad8a"), 0.6)
		"sand":
			color = Color("#c9b892")
		"boardwalk":
			color = Color("#6b5640")
	var material := _material(color)
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(width, a.distance_to(b) + width * 0.5)
		segment.mesh = plane
		segment.material_override = material
		var mid := (a + b) * 0.5
		segment.position = Vector3(mid.x, 0.02 + i * 0.001, mid.y)
		segment.rotation.y = atan2(b.x - a.x, b.y - a.y)
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(segment)


func _obstacle(obstacle: Dictionary, parent: Node3D) -> void:
	var kind: String = obstacle.get("kind", "rock")
	if obstacle.has("rect"):
		var rect: Rect2 = obstacle.rect
		var center := rect.get_center()
		match kind:
			"water":
				_water(rect.size, Vector3(center.x, 0.0, center.y), parent)
			"chasm":
				var pit := _box(Vector3(rect.size.x, 0.2, rect.size.y), Color("#0d0f12"), parent)
				pit.position = Vector3(center.x, 0.01, center.y)
				var lip := _box(Vector3(rect.size.x + 0.6, 0.5, 0.6), theme.rock.darkened(0.3), parent)
				lip.position = Vector3(center.x, 0.25, rect.position.y)
				var lip2 := _box(Vector3(rect.size.x + 0.6, 0.5, 0.6), theme.rock.darkened(0.3), parent)
				lip2.position = Vector3(center.x, 0.25, rect.end.y)
			"cliff":
				var height := 7.0 + _random.randf_range(0.0, 3.0)
				var block := _box(Vector3(rect.size.x, height, rect.size.y), theme.rock, parent)
				block.material_override = _rock_material()
				block.position = Vector3(center.x, height * 0.5, center.y)
				# Broken boulders soften the silhouette along the cliff edges.
				var perimeter := 2.0 * (rect.size.x + rect.size.y)
				for i in range(int(perimeter / 6.0)):
					var t := _random.randf()
					var along := t * perimeter
					var p := rect.position
					if along < rect.size.x:
						p += Vector2(along, 0)
					elif along < rect.size.x + rect.size.y:
						p += Vector2(rect.size.x, along - rect.size.x)
					elif along < 2.0 * rect.size.x + rect.size.y:
						p += Vector2(rect.size.x - (along - rect.size.x - rect.size.y), rect.size.y)
					else:
						p += Vector2(0, rect.size.y - (along - 2.0 * rect.size.x - rect.size.y))
					var lump := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radial_segments = 8
					sphere.rings = 5
					lump.mesh = sphere
					lump.material_override = _rock_material()
					var r := _random.randf_range(1.2, 2.4)
					lump.scale = Vector3(r, r * _random.randf_range(1.0, 2.6), r)
					lump.position = Vector3(p.x, r * 0.6, p.y)
					parent.add_child(lump)
			"wall":
				var wall := _box(Vector3(rect.size.x, 3.2, rect.size.y), Color("#8e877a"), parent)
				wall.position = Vector3(center.x, 1.6, center.y)
			"ruin":
				var ruin := _box(Vector3(rect.size.x, 1.8, rect.size.y), Color("#9aa39b"), parent)
				ruin.position = Vector3(center.x, 0.9, center.y)
			"house":
				_house(rect, parent)
			"thornwall":
				for i in range(int(rect.size.x / 1.6)):
					var bush := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radial_segments = 8
					sphere.rings = 5
					bush.mesh = sphere
					bush.material_override = _material(Color("#3d5a2a").darkened(_random.randf_range(0.0, 0.3)))
					var r := _random.randf_range(1.6, 2.4)
					bush.scale = Vector3(r, r * 2.6, r)
					bush.position = Vector3(rect.position.x + 0.8 + i * 1.6, r * 1.6, center.y + _random.randf_range(-0.6, 0.6))
					parent.add_child(bush)
			_:
				var block := _box(Vector3(rect.size.x, 3.0, rect.size.y), theme.rock, parent)
				block.position = Vector3(center.x, 1.5, center.y)
	elif obstacle.has("circle"):
		var circle: Vector3 = obstacle.circle
		var at := Vector2(circle.x, circle.y)
		match kind:
			"water":
				var pool := MeshInstance3D.new()
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = circle.z
				cylinder.bottom_radius = circle.z
				cylinder.height = 0.05
				pool.mesh = cylinder
				pool.material_override = _water_material()
				pool.position = Vector3(at.x, 0.03, at.y)
				parent.add_child(pool)
			"trees":
				for i in range(int(circle.z * 1.6)):
					var offset := Vector2.from_angle(_random.randf() * TAU) * _random.randf() * circle.z * 0.85
					_tree(at + offset, _random.randf_range(0.8, 1.25), parent)
			"stone":
				pass
			_:
				var rock := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radial_segments = 10
				sphere.rings = 6
				rock.mesh = sphere
				rock.material_override = _rock_material()
				rock.scale = Vector3(circle.z, circle.z * 1.1, circle.z)
				rock.position = Vector3(at.x, circle.z * 0.35, at.y)
				rock.rotation.y = _random.randf() * TAU
				parent.add_child(rock)


func _water(size: Vector2, at: Vector3, parent: Node3D) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	water.mesh = plane
	water.material_override = _water_material()
	water.position = at + Vector3(0, 0.04, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water)


func _rock_material() -> ShaderMaterial:
	if not _materials.has("rock"):
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = ROCK_SHADER
		material.shader = shader
		material.set_shader_parameter("rock", theme.rock)
		_materials["rock"] = material
	return _materials.rock


func _water_material() -> ShaderMaterial:
	if not _materials.has("water"):
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = WATER_SHADER
		material.shader = shader
		_materials["water"] = material
	return _materials.water


func _house(rect: Rect2, parent: Node3D) -> void:
	var center := rect.get_center()
	var body := _box(Vector3(rect.size.x, 3.0, rect.size.y), Color("#b4a58a"), parent)
	body.position = Vector3(center.x, 1.5, center.y)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(rect.size.x + 0.6, 2.2, rect.size.y + 0.6)
	roof.mesh = prism
	roof.material_override = _material(Color("#6e4a37"))
	roof.position = Vector3(center.x, 4.1, center.y)
	parent.add_child(roof)


func _tree(at: Vector2, size: float, parent: Node3D) -> void:
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18 * size
	cylinder.bottom_radius = 0.3 * size
	cylinder.height = 2.4 * size
	trunk.mesh = cylinder
	trunk.material_override = _material(Color("#5a4632"))
	trunk.position = Vector3(at.x, 1.2 * size, at.y)
	parent.add_child(trunk)
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 6
	crown.mesh = sphere
	crown.material_override = _material(Color("#4a6a32").darkened(_random.randf_range(0.0, 0.25)))
	crown.scale = Vector3(1.9, 1.7, 1.9) * size
	crown.position = Vector3(at.x, 3.2 * size, at.y)
	parent.add_child(crown)


func _pine(at: Vector2, size: float) -> void:
	var trunk := _box(Vector3(0.35, 1.4, 0.35) * size, Color("#4c3a2a"), self)
	trunk.position = Vector3(at.x, 0.7 * size, at.y)
	for i in range(3):
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = (1.8 - i * 0.45) * size
		mesh.height = 2.2 * size
		mesh.radial_segments = 8
		cone.mesh = mesh
		cone.material_override = _material(Color("#33502f"))
		cone.position = Vector3(at.x, (1.8 + i * 1.2) * size, at.y)
		add_child(cone)


func _prop(kind: String, at: Vector2, rot: float, size: float, color: Color) -> void:
	match kind:
		"tree":
			_tree(at, size, self)
		"pine":
			_pine(at, size * _random.randf_range(0.9, 1.3))
		"dead_tree":
			var trunk := _box(Vector3(0.4, 4.0, 0.4), Color("#4a4238"), self)
			trunk.position = Vector3(at.x, 2.0, at.y)
			trunk.rotation = Vector3(0.08, rot, 0.05)
			var branch := _box(Vector3(2.2, 0.22, 0.22), Color("#4a4238"), self)
			branch.position = Vector3(at.x, 3.2, at.y)
			branch.rotation = Vector3(0, rot + 0.6, 0.5)
		"tent":
			var tent := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(3.2, 2.2, 3.6) * size
			tent.mesh = prism
			tent.material_override = _material(Color("#c8b897"))
			tent.position = Vector3(at.x, 1.1 * size, at.y)
			tent.rotation.y = rot
			add_child(tent)
		"pavilion":
			_pavilion(at, color, self)
		"crates":
			for i in range(3):
				var crate := _box(Vector3(0.9, 0.9, 0.9), Color("#7a5a3a"), self)
				crate.position = Vector3(at.x + (i % 2) * 1.0, 0.45 + (i / 2) * 0.9, at.y + (i % 2) * 0.3)
		"mine":
			var frame := _box(Vector3(6.0, 5.0, 2.0), Color("#3a3a36"), self)
			frame.position = Vector3(at.x, 2.5, at.y)
			var opening := _box(Vector3(3.4, 3.6, 0.3), Color("#0b0b0b"), self)
			opening.position = Vector3(at.x, 1.8, at.y + 1.05)
			for side in [-1.0, 1.0]:
				var beam := _box(Vector3(0.4, 4.0, 0.4), Color("#6b5137"), self)
				beam.position = Vector3(at.x + side * 1.9, 2.0, at.y + 1.2)
			var lintel := _box(Vector3(4.4, 0.4, 0.5), Color("#6b5137"), self)
			lintel.position = Vector3(at.x, 4.0, at.y + 1.2)
		"tunnel":
			var tunnel := _box(Vector3(4.0, 3.6, 0.4), Color("#0b0b0b"), self)
			tunnel.position = Vector3(at.x, 1.8, at.y)
			tunnel.rotation.y = rot
		"standing_stone":
			var stone := _box(Vector3(1.0, 3.6, 0.7), Color("#8a8c88"), self)
			stone.position = Vector3(at.x, 1.8, at.y)
			stone.rotation = Vector3(_random.randf_range(-0.06, 0.06), _random.randf() * TAU, _random.randf_range(-0.06, 0.06))
		"well":
			var ring := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.6
			cylinder.bottom_radius = 1.7
			cylinder.height = 1.0
			ring.mesh = cylinder
			ring.material_override = _material(Color("#9a9384"))
			ring.position = Vector3(at.x, 0.5, at.y)
			add_child(ring)
			var water := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 1.3
			disc.bottom_radius = 1.3
			disc.height = 0.05
			water.mesh = disc
			water.material_override = _water_material()
			water.position = Vector3(at.x, 0.95, at.y)
			add_child(water)
		"banner":
			var pole := _box(Vector3(0.12, 4.2, 0.12), Color("#5b4a38"), self)
			pole.position = Vector3(at.x, 2.1, at.y)
			var flag := _box(Vector3(1.1, 1.6, 0.05), color, self)
			flag.position = Vector3(at.x + 0.6, 3.3, at.y)
		"bridge":
			var deck := _box(Vector3(10.0, 0.3, 7.0), Color("#6b5137"), self)
			deck.position = Vector3(at.x, 0.12, at.y)
		"arch":
			for side in [-1.0, 1.0]:
				var post := _box(Vector3(1.0, 5.0, 1.0), Color("#a6aea6"), self)
				post.position = Vector3(at.x + side * 2.2, 2.5, at.y)
			var top := _box(Vector3(5.4, 0.9, 1.1), Color("#a6aea6"), self)
			top.position = Vector3(at.x, 5.2, at.y)
		"statue":
			var plinth := _box(Vector3(1.6, 1.0, 1.6), Color("#8f988f"), self)
			plinth.position = Vector3(at.x, 0.5, at.y)
			var figure := _box(Vector3(0.7, 2.4, 0.5), Color("#9fb0aa"), self)
			figure.position = Vector3(at.x, 2.2, at.y)
		"boat":
			var hull := _box(Vector3(2.2, 1.0, 6.0), Color("#6a4c32"), self)
			hull.position = Vector3(at.x, 0.3, at.y)
			hull.rotation.y = rot
		"dock":
			var deck := _box(Vector3(3.0, 0.3, 10.0), Color("#7a6045"), self)
			deck.position = Vector3(at.x, 0.2, at.y)
			deck.rotation.y = rot
		"rocks":
			for i in range(4):
				_rock_lump(at + Vector2(_random.randf_range(-2, 2), _random.randf_range(-2, 2)), _random.randf_range(0.6, 1.3), _random.randf_range(0.6, 1.4))
		"cairn":
			for i in range(4):
				var stone := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radial_segments = 8
				sphere.rings = 5
				stone.mesh = sphere
				stone.material_override = _material(Color("#7d7f78"))
				var r := 0.9 - i * 0.18
				stone.scale = Vector3(r, r * 0.7, r)
				stone.position = Vector3(at.x, 0.3 + i * 0.55, at.y)
				add_child(stone)
		"fire":
			var logs := _box(Vector3(1.2, 0.3, 1.2), Color("#3c2a1c"), self)
			logs.position = Vector3(at.x, 0.15, at.y)
			var light := OmniLight3D.new()
			light.light_color = Color("#ffb066")
			light.light_energy = 1.4
			light.omni_range = 9.0
			light.position = Vector3(at.x, 1.2, at.y)
			add_child(light)
			var flame := _glow_box(Vector3(0.6, 1.0, 0.6), Color(1.0, 0.55, 0.2, 0.7))
			flame.position = Vector3(at.x, 0.7, at.y)
		"wagon":
			add_child(_wagon_node(at, rot))
		"vault_door":
			var door := _box(Vector3(9.0, 9.0, 1.2), Color("#4d4a45"), self)
			door.position = Vector3(at.x, 4.5, at.y)
			var seam := _glow_box(Vector3(0.25, 8.0, 0.1), Color(0.8, 0.9, 1.0, 0.6))
			seam.position = Vector3(at.x, 4.2, at.y + 0.65)
		"root_bridge":
			for i in range(5):
				var root := MeshInstance3D.new()
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.45
				cylinder.bottom_radius = 0.6
				cylinder.height = 16.0
				root.mesh = cylinder
				root.material_override = _material(Color("#5b4630"))
				root.rotation = Vector3(PI * 0.5, 0, 0)
				root.position = Vector3(at.x - 3.0 + i * 1.5, 0.3 + absf(i - 2) * 0.1, at.y)
				add_child(root)


func _pavilion(at: Vector2, color: Color, parent: Node3D) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = Vector3(at.x, 0, at.y)
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.4
	cylinder.bottom_radius = 2.4
	cylinder.height = 2.6
	cylinder.radial_segments = 12
	base.mesh = cylinder
	base.material_override = _material(Color("#d8c9a8"))
	base.position.y = 1.3
	holder.add_child(base)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.9
	cone.height = 2.2
	cone.radial_segments = 12
	roof.mesh = cone
	roof.material_override = _material(color)
	roof.position.y = 3.7
	holder.add_child(roof)
	return holder


func _wagon_node(at: Vector2, rot: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(at.x, 0, at.y)
	holder.rotation.y = rot
	var bed := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.9, 3.4)
	bed.mesh = box
	bed.material_override = _material(Color("#6b4d33"))
	bed.position.y = 1.0
	holder.add_child(bed)
	for x in [-1.0, 1.0]:
		for z in [-1.1, 1.1]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.55
			cylinder.bottom_radius = 0.55
			cylinder.height = 0.18
			wheel.mesh = cylinder
			wheel.material_override = _material(Color("#3d2e22"))
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(x * 1.0, 0.55, z)
			holder.add_child(wheel)
	var chest := MeshInstance3D.new()
	var lid := BoxMesh.new()
	lid.size = Vector3(1.1, 0.6, 1.1)
	chest.mesh = lid
	chest.material_override = _material(Color("#8a6a3a"))
	chest.position.y = 1.75
	holder.add_child(chest)
	var glow := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.25
	orb.height = 0.5
	glow.mesh = orb
	var light_material := StandardMaterial3D.new()
	light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_material.albedo_color = Color("#bfe6ff")
	glow.material_override = light_material
	glow.position.y = 2.25
	holder.add_child(glow)
	return holder


## Returns a node that represents a structure. MissionView moves it and tints it as it takes damage.
func structure_node(kind: StringName, at: Vector2, facing: Vector2) -> Node3D:
	var node: Node3D
	match kind:
		&"wagon":
			node = _wagon_node(at, atan2(facing.x, facing.y))
			add_child(node)
		&"pavilion":
			node = _pavilion(at, Color("#8e3a2c"), self)
		&"stone":
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			var stone := _box(Vector3(1.4, 4.4, 1.0), Color("#9a9c96"), node)
			stone.position = Vector3(0, 2.2, 0)
			var rune := _glow_box(Vector3(0.5, 0.5, 0.05), Color(0.6, 0.95, 0.8, 0.8))
			remove_child(rune)
			node.add_child(rune)
			rune.position = Vector3(0, 2.8, 0.53)
		&"ship":
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			var hull := _box(Vector3(3.6, 2.4, 11.0), Color("#5e432c"), node)
			hull.position = Vector3(0, 1.0, 0)
			hull.rotation.z = 0.12
			var mast := _box(Vector3(0.3, 9.0, 0.3), Color("#4a3624"), node)
			mast.position = Vector3(0, 6.0, 0)
			var sail := _box(Vector3(0.1, 4.0, 5.0), Color("#d9d2c0"), node)
			sail.position = Vector3(0.2, 6.5, 0)
		&"heart_tree":
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			_tree(Vector2.ZERO, 1.9, node)
		&"signal_fire":
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			var brazier := _box(Vector3(1.6, 1.4, 1.6), Color("#4a4440"), node)
			brazier.position.y = 0.7
			var flame := _glow_box(Vector3(1.0, 1.6, 1.0), Color(1.0, 0.5, 0.15, 0.8))
			remove_child(flame)
			node.add_child(flame)
			flame.position.y = 2.1
			var light := OmniLight3D.new()
			light.light_color = Color("#ff9c4a")
			light.light_energy = 2.0
			light.omni_range = 12.0
			light.position.y = 2.6
			node.add_child(light)
		&"root_bridge":
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			var root := _box(Vector3(3.2, 2.6, 2.6), Color("#5b4630"), node)
			root.position.y = 1.3
			var crown := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			crown.mesh = sphere
			crown.material_override = _material(Color("#4f6b33"))
			crown.scale = Vector3(2.2, 1.4, 2.2)
			crown.position.y = 3.2
			node.add_child(crown)
		&"gate":
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			var door := _box(Vector3(7.0, 7.5, 1.4), Color("#5a5650"), node)
			door.position.y = 3.75
		_:
			node = Node3D.new()
			add_child(node)
			node.position = Vector3(at.x, 0, at.y)
			_box(Vector3(2, 2, 2), Color.GRAY, node).position.y = 1.0
	return node


func _box(size: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _glow_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _ring(radius: float, color: Color, thickness: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mesh.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = _ring_shader
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("thickness", thickness)
	material.set_shader_parameter("pulse", _random.randf() * TAU)
	mesh.material_override = material
	mesh.scale = Vector3(radius * 2.0, 1, radius * 2.0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.92
		_materials[key] = material
	return _materials[key]
