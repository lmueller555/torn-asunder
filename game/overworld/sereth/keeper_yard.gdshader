shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 p;
float hash(vec2 q){
	q=fract(q*vec2(.11369,.1031));q+=dot(q,q.yx+19.13);
	return fract(q.x*q.y*47.57);
}
float grain(vec2 q){
	vec2 k=floor(q);vec2 d=smoothstep(vec2(0),vec2(1),fract(q));
	return mix(mix(hash(k),hash(k+vec2(1,0)),d.x),mix(hash(k+vec2(0,1)),hash(k+vec2(1)),d.x),d.y);
}
void vertex(){
	p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment(){
	float packed=grain(p.xz*.51)*.64+grain(p.xz*3.62)*.36;
	ALBEDO=mix(vec3(.19,.170,.118),vec3(.325,.284,.210),packed);
	ALPHA=clamp(COLOR.a*(.70+.36*packed),0.,.94);
	ROUGHNESS=.99;
}
