shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55,0.49,0.41,1.0);
uniform bool slate = false;
varying vec3 world;
float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(37.18,25.31)))*43758.5453);
}
float fleck(vec2 p) {
	vec2 b=floor(p), f=smoothstep(vec2(0.0),vec2(1.0),fract(p));
	return mix(mix(hash21(b),hash21(b+vec2(1,0)),f.x),
		mix(hash21(b+vec2(0,1)),hash21(b+vec2(1,1)),f.x),f.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float fine=fleck(world.xz*(slate ? 9.3 : 5.4));
	float fragments=fleck(world.xz*(slate ? 3.1 : 2.1));
	ALBEDO=tint.rgb*mix(0.71,1.19,fine*0.6+fragments*0.4);
	ALPHA=clamp(COLOR.a-(1.0-COLOR.a)*fragments*0.18,0.0,0.91);
	ROUGHNESS=0.95;
}
