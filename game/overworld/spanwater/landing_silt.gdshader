shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color;
varying vec2 soil;
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0),vec2(1),fract(p));
	vec4 r = fract(sin(vec4(dot(i,vec2(12.9898,73.13)),dot(i+vec2(1,0),vec2(12.9898,73.13)),
		dot(i+vec2(0,1),vec2(12.9898,73.13)),dot(i+vec2(1),vec2(12.9898,73.13))))*43758.54);
	return mix(mix(r.x,r.y,f.x),mix(r.z,r.w,f.x),f.y);
}
void vertex() {
	soil=(MODEL_MATRIX*vec4(VERTEX,1)).xz;
}
void fragment() {
	float grit=noise2(soil*6.4);
	ALBEDO=tint.rgb*(.57+.35*noise2(soil*.65)+.27*grit);
	ALPHA=clamp(COLOR.a*.84-(1.-grit)*.29,0.,.76);
	ROUGHNESS=.99;
}
