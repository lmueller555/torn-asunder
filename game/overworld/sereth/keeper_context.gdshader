shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color;
uniform bool needles = false;
uniform bool distant = false;
varying vec3 p;
varying vec3 normal_w;
float hash(vec3 q){
	q=fract(q*.31831+vec3(.13,.19,.31))*16.;
	return fract(q.x*q.y*q.z*(q.x+q.y+q.z));
}
float grain(vec3 q){
	vec3 a=floor(q);vec3 s=smoothstep(vec3(0),vec3(1),fract(q));
	float low=mix(mix(hash(a),hash(a+vec3(1,0,0)),s.x),mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),s.x),s.y);
	a.z+=1.;
	float high=mix(mix(hash(a),hash(a+vec3(1,0,0)),s.x),mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),s.x),s.y);
	return mix(low,high,s.z);
}
void vertex(){
	p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	normal_w=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	float grain_ = grain(p*(distant?.047:.52));
	float flecks=grain(p*(distant?.091:4.33));
	float slope=smoothstep(.12,.53,1.-abs(normal_w.y));
	vec3 c=tint.rgb*(.63+.34*grain_+.18*flecks);
	if (distant) {
		float stone=grain(vec3(p.x*.042,p.y*.22,p.z*.019));
		c=mix(c,c*vec3(1.08,1.12,1.17),slope*.55)+vec3(.023,.019,.017)*stone;
		c=mix(c,vec3(.27,.34,.38),smoothstep(334.,1150.,length(p.xz))*.81);
	} else if (needles) {
		c*=mix(vec3(.73,.89,.88),vec3(1.15,1.23,1.04),grain_*.87+.10);
	}
	ALBEDO=c*mix(vec3(.80),COLOR.rgb,.76);
	ROUGHNESS=.95;
	SPECULAR=.16;
}
