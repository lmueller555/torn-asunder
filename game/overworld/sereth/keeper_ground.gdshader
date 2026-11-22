shader_type spatial;
render_mode diffuse_burley;
varying vec3 p;
varying vec3 n;
float hash(vec2 q){
	q=fract(q*vec2(.11369,.1031));q+=dot(q,q.yx+19.13);
	return fract(q.x*q.y*47.57);
}
float field(vec2 q){
	vec2 a=floor(q);vec2 f=smoothstep(vec2(0),vec2(1),fract(q));
	return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1)),f.x),f.y);
}
void vertex(){
	p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	float slow=field(p.xz*.062)*.65+field(p.xz*.16)*.35;
	float grit=field(p.xz*.83)*.71+field(p.xz*3.1)*.29;
	float rock=smoothstep(.14,.39,1.-n.y+(grit-.42)*.19);
	float grain=field(vec2(p.z*.31+.11*p.x,p.y*1.25));
	vec3 moor=mix(vec3(.133,.148,.102),vec3(.238,.244,.158),slow);
	vec3 slate=mix(vec3(.154,.165,.156),vec3(.281,.270,.236),grain);
	vec3 sand=mix(vec3(.244,.195,.132),vec3(.428,.356,.270),grit);
	float path = max(smoothstep(.05,.88,COLOR.r+(grit-.42)*.17),COLOR.g*.58);
	ALBEDO=mix(mix(moor,slate,rock),sand,path);
	ROUGHNESS=mix(.96,.84,rock);
}
