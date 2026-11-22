shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 pos;
varying vec3 dye;
void vertex() {
	pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	dye = COLOR.rgb;
}
float hash(vec2 p) {return fract(sin(dot(p,vec2(15.716,92.162))) * 41758.156);}
void fragment(){
	float grit=hash(floor(pos.xz*8.1))*.16+hash(floor(pos.xz*3.2))*.14;
	ALBEDO = dye*(.61+grit);
	ALPHA = smoothstep(.004,.24,UV.x)*.84;
	ROUGHNESS = .95;
}
