shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform bool water = false;
varying vec3 loc;
varying vec3 norm;
varying vec3 masks;
float hash(vec2 p) {
	p = fract(p * vec2(0.11369, 0.1031));
	p += dot(p, p.yx + 19.13);
	return fract(p.x * p.y * 47.57);
}
float n2(vec2 p) {
	vec2 a = floor(p);
	vec2 f = smoothstep(vec2(0.), vec2(1.), fract(p));
	return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1)),f.x),f.y);
}
void vertex() {
	loc = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	norm = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	masks = COLOR.rgb;
}
void fragment() {
	vec2 p = loc.xz;
	float broad = n2(p*.033)*.62 + n2(p*.097)*.38;
	float grit = n2(p*.41)*.58+n2(p*1.73)*.42;
	if (water) {
		float currents = n2(p*vec2(.10,.59))*.25 + n2(p*vec2(.18,1.57))*.30
			+ n2(p*vec2(.035,.40))*.25 + .20*sin(p.y*.45+2.9*sin(p.x*.08));
		vec3 deep = mix(vec3(.042,.127,.142),vec3(.108,.217,.231), broad);
		vec3 bank = mix(vec3(.233,.299,.220),vec3(.278,.390,.345),broad);
		vec3 surf = mix(deep,bank,smoothstep(.47,.99,masks.r));
		ALBEDO = surf + smoothstep(.55,.81,currents)*vec3(.10,.15,.13);
		ROUGHNESS = .46 + .26*grit;
		SPECULAR = .29;
	} else {
		float steep = smoothstep(.13,.48,1.-norm.y+.12*grit);
		vec3 turf = mix(vec3(.12,.15,.063),vec3(.195,.224,.113),broad);
		vec3 shale = mix(vec3(.193,.189,.141),vec3(.260,.241,.176),grit);
		vec3 sediment = mix(vec3(.171,.161,.100),vec3(.302,.244,.161),broad);
		vec3 dirt = mix(vec3(.22,.174,.105),vec3(.37,.296,.203),grit);
		ALBEDO = mix(mix(mix(turf,shale,steep),sediment,masks.g),dirt,
			smoothstep(.06,.90,masks.r+(grit-.5)*.26));
		ROUGHNESS = 0.96;
	}
}
