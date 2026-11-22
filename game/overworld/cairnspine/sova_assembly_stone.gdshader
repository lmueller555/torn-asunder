shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
float speck(vec3 t) {
	vec3 p=floor(t), f=smoothstep(vec3(0.0),vec3(1.0),fract(t));
	vec3 d=vec3(13.17,38.19,17.9);
	vec4 lo=fract(sin(vec4(dot(p,d), dot(p+vec3(1,0,0),d),dot(p+vec3(0,1,0),d),dot(p+vec3(1,1,0),d)))*43758.54);
	vec4 hi=fract(sin(vec4(dot(p,d), dot(p+vec3(1,0,0),d),dot(p+vec3(0,1,0),d),dot(p+vec3(1,1,0),d))+d.z)*43758.54);
	vec4 k=mix(lo,hi,f.z);
	return mix(mix(k.x,k.y,f.x),mix(k.z,k.w,f.x),f.y);
}
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
	float fractures=speck(world*vec3(1.1,3.1,1.1));
	float grain=speck(world*14.0);
	float laminate=sin(world.y*10.0+world.x*.09+fractures*2.3)*.055;
	ALBEDO=COLOR.rgb*(.80+.22*fractures+.12*grain+laminate);
	ROUGHNESS=.94;
}
