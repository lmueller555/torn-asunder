shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 base_color : source_color;
uniform bool is_path = false;
varying vec3 pos;
varying vec3 face;
float hash3(vec3 p) {
	p = fract(p*.31831 + vec3(.13,.47,.21))*16.0;
	return fract(p.x*p.y*p.z*(p.x+p.y+p.z));
}
float grain(vec3 p) {
	vec3 b = floor(p);
	vec3 d = smoothstep(vec3(0),vec3(1),fract(p));
	vec2 u = vec2(
		mix(hash3(b),hash3(b+vec3(1,0,0)),d.x),
		mix(hash3(b+vec3(0,1,0)),hash3(b+vec3(1,1,0)),d.x));
	vec2 v = vec2(
		mix(hash3(b+vec3(0,0,1)),hash3(b+vec3(1,0,1)),d.x),
		mix(hash3(b+vec3(0,1,1)),hash3(b+vec3(1,1,1)),d.x));
	return mix(mix(u.x,u.y,d.y),mix(v.x,v.y,d.y),d.z);
}
void vertex() {
	pos = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
	face = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	float cloud = grain(pos*.41);
	float sediment = grain(pos*vec3(.52,2.3,.52));
	float fine = grain(pos*8.);
	float height = clamp(abs(face.y),0.,1.);
	vec3 stone = base_color.rgb * (.75 + .33*cloud + .20*sediment + .10*fine);
	// Moisture and mineral staining raised slightly on the shaded north cheek.
	float damp = 1.0 - smoothstep(.65,2.3,pos.y+(cloud-.5)*1.6);
	float moss = smoothstep(.54,.80,grain(pos*.25 + vec3(.1,3.2,.8)))*(.40+.3*height);
	stone = mix(stone,stone*vec3(.45,.53,.53),damp*.7);
	stone = mix(stone,vec3(.112,.122,.080),moss);
	if (is_path) {
		float wear = grain(pos*vec3(.18,2.,.95));
		stone = base_color.rgb*(.60+.48*wear+.23*fine);
		stone = mix(stone,vec3(.17,.145,.111),smoothstep(.65,.88,fine)*.64);
	}
	ALBEDO = stone*mix(vec3(.86),vec3(1),COLOR.r);
	ROUGHNESS = is_path ? .96 : mix(.95,.61,damp);
	SPECULAR = .23;
}
