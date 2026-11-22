shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 world;
varying vec3 slope;
float h(vec2 p){p=fract(p*vec2(.01369,.0731));p+=dot(p,p.yx+17.7);return fract(p.x*p.y*31.28);}
float noise2(vec2 p){vec2 a=floor(p),w=smoothstep(vec2(0.0),vec2(1.0),fract(p));return mix(mix(h(a),h(a+vec2(1.,0.)),w.x),mix(h(a+vec2(0.,1.)),h(a+vec2(1.)),w.x),w.y);}
void vertex(){
	world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	slope=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	float mottle=noise2(world.xz*.043)*.57+noise2(world.xz*.13)*.43;
	float uplift=smoothstep(.09,.67,1.0-slope.y);
	vec3 tint=mix(vec3(.092,.125,.092),vec3(.139,.174,.127),mottle);
	tint=mix(tint,vec3(.179,.184,.143),uplift*.55);
	float far_fade=smoothstep(420.,1690.,length(world.xz));
	ALBEDO=mix(tint,vec3(.137,.181,.168),far_fade*.68);
	ROUGHNESS=.98;
}
