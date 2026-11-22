shader_type spatial;
render_mode diffuse_burley;
varying vec3 terrain_world;
varying vec4 terrain_zones;
void vertex() {
	terrain_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_zones = COLOR;
}
float rand(vec2 a) {return fract(sin(dot(a, vec2(12.9898,78.233))) * 43758.5453);}
float noise(vec2 p) {
	vec2 q=floor(p);vec2 f=smoothstep(0.0,1.0,fract(p));
	return mix(mix(rand(q),rand(q+vec2(1.0,0.0)),f.x),mix(rand(q+vec2(0.0,1.0)),rand(q+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
	vec2 p=terrain_world.xz; float mottling=noise(p*.105)*.53+noise(p*.47)*.27+noise(p*1.75)*.13;
	vec3 moor=mix(vec3(.10,.13,.111),vec3(.26,.285,.213),mottling);
	vec3 slate=mix(vec3(.12,.129,.153),vec3(.30,.304,.287),noise(p*vec2(.25,.91))*.69+noise(p*.12)*.22);
	vec3 track=mix(vec3(.21,.177,.138),vec3(.38,.325,.247),mottling+noise(p*2.9)*.08);
	ALBEDO=mix(mix(moor,slate,terrain_zones.g),track,terrain_zones.r*.84);
	ROUGHNESS=.94;
}
