shader_type spatial;
render_mode cull_disabled, blend_mix;
varying vec3 p;
float h(vec2 q){return fract(sin(dot(q,vec2(141.4,63.83)))*28741.768);}
float n(vec2 a){vec2 i=floor(a),f=fract(a);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	float crust=n(p.xz*.29)*.49+n(p.xz*1.9)*.29+n(p.xz*4.47)*.22;
	float pore=n(p.xz*8.3+p.y*.41);
	ALBEDO=COLOR.rgb*(.73+crust*.49+pore*.10);
	ALPHA=COLOR.a;
	ROUGHNESS=.91;
}
