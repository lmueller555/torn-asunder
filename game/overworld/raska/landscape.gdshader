shader_type spatial;
render_mode cull_disabled;
varying vec3 place;
varying vec3 incline;
varying vec2 map_point;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(143.47,73.13))) * 4856.352);
}
float noise2(vec2 p) {
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	vec2 cell = floor(p);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void vertex() { map_point=VERTEX.xz; place=(MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; incline=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
	float stone = noise2(place.xz*.58) * .60 + noise2(place.xz*2.53) * .21 + noise2(place.xz*.079)*.19;
	float fold = noise2(place.xz*.16)*1.6 + place.x*.042 + place.z*.037;
	float strata = sin(place.y*.83 + fold)+.64*sin(place.y*2.28+fold*.95);
	float face = 1.0-smoothstep(.35,.83,abs(incline.y));
	float breakage=noise2(vec2(place.x*.66+place.z*.7,place.y*1.02));
	float rut_center = sin(map_point.x*.049)*.66 + sin(map_point.x*.113+1.3)*.24;
	float rut_distance = abs(abs(map_point.y-rut_center)-1.46);
	float wear = (1.0-smoothstep(.25,1.12,rut_distance)) * (1.0-smoothstep(88.0,136.0,abs(map_point.x)));
	wear *= noise2(map_point*.34)*.44+.36;
	ALBEDO=COLOR.rgb*(.82+stone*.30 + face*(strata*.079 + breakage*.103) - wear*.19);
	ROUGHNESS=.94;
}
