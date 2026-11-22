shader_type spatial;
render_mode cull_disabled, shadows_disabled;
varying vec3 world;
float grain(vec2 p) { return fract(sin(dot(p,vec2(30.18,17.73)))*43758.54); }
float coarse(vec2 p) {
	vec2 cell=floor(p), q=smoothstep(vec2(0),vec2(1),fract(p));
	return mix(mix(grain(cell),grain(cell+vec2(1,0)),q.x),
		mix(grain(cell+vec2(0,1)),grain(cell+vec2(1,1)),q.x),q.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float deposit=coarse(world.xz*1.7);
	float gravel=coarse(world.xz*11.7);
	ALBEDO=mix(vec3(.24,.19,.13),vec3(.42,.34,.26),deposit*.62+gravel*.38);
	ALPHA=clamp(COLOR.a*.83 - (1.0-COLOR.a)*deposit*.24,0.0,.85);
	ROUGHNESS=.96;
}
