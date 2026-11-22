shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color;
uniform bool underbrush = false;
varying vec3 local_tip;
varying vec3 scene_pos;
float grain(vec3 p) {
	p = fract(p*.31831 + vec3(.13,.47,.21))*16.;
	return fract(p.x*p.y*p.z*(p.x+p.y+p.z));
}
void vertex(){
	local_tip = VERTEX;
	scene_pos = (MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment(){
	float lifted=clamp(local_tip.y*(underbrush ? 1.22 : .13),0.,1.);
	float needle=grain(floor(scene_pos*3.17))*.40 + grain(floor(scene_pos*.74))*.60;
	vec3 cool=tint.rgb*vec3(.64,.78,.74);
	vec3 sprig=tint.rgb*vec3(1.18,1.29,1.05);
	ALBEDO=mix(cool,sprig,lifted*.76+.13)*(0.86+needle*.22)*mix(vec3(.75),COLOR.rgb,.60);
	ROUGHNESS = .96;
	SPECULAR = .10;
}
