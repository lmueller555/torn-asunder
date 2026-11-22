shader_type spatial;
render_mode cull_disabled;
varying vec3 p;
float h(vec2 q){return fract(sin(dot(q,vec2(141.4,63.83)))*28741.768);}
float n(vec2 a){vec2 i=floor(a),f=fract(a);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	float grain=n(p.xz*1.6+p.y*.37)*.36+n(p.xz*4.9+p.y*2.7)*.22+n(p.xz*.36)*.42;
	float strata=sin(p.y*13.0+n(p.xz*.55)*2.1)*.06;
	ALBEDO=COLOR.rgb*(.67+grain*.55+strata);
	ROUGHNESS=.92;
}
