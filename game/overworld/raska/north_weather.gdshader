shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
float h(vec2 p){return fract(sin(dot(p,vec2(137.8,61.83)))*39568.52);}
float n(vec2 p){vec2 o=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(o),h(o+vec2(1,0)),f.x),mix(h(o+vec2(0,1)),h(o+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	float mottle=n(world.xz*.63+world.y*.28)*.43+n(world.xz*3.47+world.y*.39)*.14+n(world.xz*.091)*.43;
	vec3 base=COLOR.rgb*(.79+mottle*.36);
	ALBEDO=base;
	ROUGHNESS=.91;
}
