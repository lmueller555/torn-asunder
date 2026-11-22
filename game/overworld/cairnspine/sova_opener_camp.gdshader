shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.50,0.42,0.31,1.0);
uniform bool fabric = false;
varying vec3 world;
float hash31(vec3 p) {
	return fract(sin(dot(p,vec3(11.31,47.18,27.31)))*43758.5453);
}
float noise3(vec3 p) {
	vec3 c=floor(p), q=smoothstep(vec3(0.0),vec3(1.0),fract(p));
	float k=mix(mix(hash31(c),hash31(c+vec3(1,0,0)),q.x),
		mix(hash31(c+vec3(0,1,0)),hash31(c+vec3(1,1,0)),q.x),q.y);
	c.z+=1.0;
	float j=mix(mix(hash31(c),hash31(c+vec3(1,0,0)),q.x),
		mix(hash31(c+vec3(0,1,0)),hash31(c+vec3(1,1,0)),q.x),q.y);
	return mix(k,j,q.z);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float stain=noise3(world*1.72);
	float grain=noise3(world*(fabric ? vec3(80,14,87) : vec3(7,24,12)));
	ALBEDO=tint.rgb*mix(0.63,1.23,stain*0.7+grain*0.3);
	ROUGHNESS=0.89;
}
