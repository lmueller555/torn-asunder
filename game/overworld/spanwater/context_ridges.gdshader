shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_p;
varying vec3 nrm;
float h(vec2 p) {
	p = fract(p*vec2(.11369,.1031));
	p += dot(p,p.yx+19.13);
	return fract(p.x*p.y*47.57);
}
float ns(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0),vec2(1),fract(p));
	return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	world_p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	nrm=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	float scree = smoothstep(.10,.49,1.-nrm.y+(ns(world_p.xz*.035)-.5)*.20);
	vec3 foothills = mix(vec3(.083,.126,.086),vec3(.202,.223,.142),ns(world_p.xz*.016));
	vec3 shale = mix(vec3(.177,.191,.179),vec3(.274,.292,.269),ns(vec2(world_p.x*.033+world_p.z*.022,world_p.y*.061)));
	vec3 ridge = mix(foothills,shale,scree*.84+COLOR.g*.14);
	ALBEDO = mix(ridge,vec3(.214,.248,.255),COLOR.r*.69);
	ROUGHNESS=.98;
}
