shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color;
uniform bool timber = false;
varying vec3 p;
float hash(vec3 q){
	q=fract(q*.31831+vec3(.13,.19,.31))*16.;
	return fract(q.x*q.y*q.z*(q.x+q.y+q.z));
}
float grain(vec3 q){
	vec3 a=floor(q);vec3 s=smoothstep(vec3(0),vec3(1),fract(q));
	float low=mix(mix(hash(a),hash(a+vec3(1,0,0)),s.x),
		mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),s.x),s.y);
	a.z+=1.0;
	float high=mix(mix(hash(a),hash(a+vec3(1,0,0)),s.x),
		mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),s.x),s.y);
	return mix(low,high,s.z);
}
void vertex(){
	p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment(){
	float slow=grain(p*.91);
	float spot=grain(p*5.30);
	float band=grain(p*vec3(.38,2.9,.94));
	float fiber=grain(p*vec3(.52,3.9,4.7));
	vec3 c=tint.rgb*(.66+.21*slow+.21*spot+.17*(timber?fiber:band));
	c=mix(c,c*vec3(.75,.83,.70),smoothstep(.55,.81,slow)*.69);
	ALBEDO=c*mix(vec3(.76),COLOR.rgb,.61);
	ROUGHNESS=timber?.91:.95;
	SPECULAR=.20;
}
