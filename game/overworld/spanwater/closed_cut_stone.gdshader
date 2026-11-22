shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 pos;
float hash(vec2 point) {
	point=fract(point*vec2(.11369,.1031));
	point+=dot(point,point.yx+19.13);
	return fract(point.x*point.y*47.57);
}
float ns(vec2 point) {
	vec2 i=floor(point);
	vec2 f=smoothstep(vec2(0),vec2(1),fract(point));
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment() {
	float mottling=ns(pos.xz*.72)*.45+ns(vec2(pos.z*.29,pos.y*1.63))*.55;
	vec3 slate=mix(vec3(.19,.204,.183),vec3(.39,.355,.279),smoothstep(.22,.82,mottling)*.78);
	ALBEDO=slate*(.75+.36*COLOR.r);
	EMISSION=slate*.14;
	ROUGHNESS=.96;
}
