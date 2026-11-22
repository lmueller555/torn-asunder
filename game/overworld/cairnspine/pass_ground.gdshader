shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 wp;
varying vec3 wn;
varying float track;

float hash(vec3 p) {
	p = fract(p * vec3(.1031, .1099, .11369));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 a = floor(p);
	vec3 f = fract(p);
	f = smoothstep(vec3(0.), vec3(1.), f);
	return mix(mix(mix(hash(a), hash(a + vec3(1,0,0)), f.x),
		mix(hash(a + vec3(0,0,1)), hash(a + vec3(1,0,1)), f.x), f.z),
		mix(mix(hash(a + vec3(0,1,0)), hash(a + vec3(1,1,0)), f.x),
		mix(hash(a + vec3(0,1,1)), hash(a + vec3(1,1,1)), f.x), f.z), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	track = COLOR.r;
}

void fragment() {
	float fields = noise3(wp * .063) * .65 + noise3(wp * .18) * .35;
	float fine = noise3(wp * 1.10) * .7 + noise3(wp * 3.4) * .3;
	float weather = noise3(vec3(wp.x*.14, wp.y*.61, wp.z*.14) + vec3(.03*wp.z, .03*wp.x, 0));
	float beds = noise3(vec3(wp.x*.043+wp.z*.028, wp.y*.4+wp.x*.025, wp.z*.05));
	float strata = smoothstep(.33, .73, weather*.48 + beds*.52);
	float rock = smoothstep(.12, .47, 1.0 - wn.y + .15 * fields);
	float high = smoothstep(30.0, 92.0, wp.y);
	vec3 turf = mix(vec3(.081,.122,.067), vec3(.198,.223,.123), smoothstep(.23,.80, fields));
	turf += (fine - .5) * .09;
	vec3 shale = mix(vec3(.146,.166,.169), vec3(.318,.323,.288), strata * .67 + .22 * fine);
	float exposed = max(rock, high * smoothstep(.38, .79, fields) * .90);
	vec3 packed = mix(vec3(.228,.174,.105),vec3(.400,.312,.201), fine*.68+fields*.32);
	float edge = smoothstep(.10,.84,track + (fine-.5)*.30 + (fields-.5)*.12);
	ALBEDO = mix(mix(turf, shale, exposed), packed, edge*.94);
	ROUGHNESS = .95;
}
