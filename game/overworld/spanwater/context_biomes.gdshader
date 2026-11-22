shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
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
		float steep = smoothstep(.13,.48,1.-norm.y+.12*grit);
		vec3 turf = mix(vec3(.12,.15,.063),vec3(.195,.224,.113),broad);
		vec3 shale = mix(vec3(.193,.189,.141),vec3(.260,.241,.176),grit);
		vec3 sediment = mix(vec3(.171,.161,.100),vec3(.302,.244,.161),broad);
		vec3 dirt = mix(vec3(.22,.174,.105),vec3(.37,.296,.203),grit);
		ALBEDO = mix(mix(mix(turf,shale,steep),sediment,masks.g),dirt,
			smoothstep(.06,.90,masks.r+(grit-.5)*.26));
		ROUGHNESS = 0.96;
	vec3 base = ALBEDO;
	float channel = min(
		min(length(p - (vec2(-49,14)+clamp(dot(p-vec2(-49,14),vec2(13,24))/745.0,0.,1.)*vec2(13,24))),
		length(p - (vec2(-36,38)+clamp(dot(p-vec2(-36,38),vec2(22,19))/845.0,0.,1.)*vec2(22,19)))),
		min(length(p - (vec2(-14,57)+clamp(dot(p-vec2(-14,57),vec2(18,46))/2440.0,0.,1.)*vec2(18,46))),
		length(p - (vec2(4,103)+clamp(dot(p-vec2(4,103),vec2(14,117))/13885.0,0.,1.)*vec2(14,117)))));
	float grass = smoothstep(.23,.73,n2(p*.073)*.55+n2(p*.037+vec2(43,27))*.45);
	float wet = smoothstep(.12,.91,masks.g) * .87;
	wet = max(wet,(1.-smoothstep(5.,17.,channel))*.81);
	float shelf = smoothstep(.06,.40,1.-norm.y + (n2(p*.118)-.50)*.22);
	float striae = n2(vec2(p.x*.13+p.y*.04,loc.y*.91));
	vec3 dry = mix(vec3(.108,.153,.077),vec3(.244,.226,.127),grass*.76);
	dry += (grit-.46)*vec3(.058,.071,.058);
	vec3 rock = mix(vec3(.194,.190,.172),vec3(.317,.291,.242),striae*.83);
	vec3 wet_silt = mix(vec3(.125,.158,.123),vec3(.295,.261,.178),n2(p*.31)*.61+grit*.39);
	vec3 changed = mix(mix(dry,rock,shelf*.85),wet_silt,wet);
	changed = mix(changed,base,smoothstep(.13,.81,masks.r)*.91);
	float landmark = min(smoothstep(25.,49.,length(p-vec2(118,31))),smoothstep(39.,70.,length(p-vec2(-52,-29))));
	ALBEDO = mix(base,changed,landmark*.84);
	// A double-sided silt cut at the old dry branch remains topologically exact.
	// Lift just its shadowed shale strata for regional legibility.
	float bend = (1.-smoothstep(10.,22.,channel))*smoothstep(79.,108.,p.y);
	float seams = .50 + .5*striae;
	EMISSION = mix(vec3(.075,.085,.079),vec3(.160,.155,.119),seams)*bend*landmark;
	ROUGHNESS = mix(.96,.82,wet*landmark*.56);
}
