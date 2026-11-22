shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform int material_kind = 0; // 0 ashlar, 1 canvas, 2 wood
varying vec3 pos;
varying vec3 dye;
varying vec2 uv;
void vertex() {
	pos = (MODEL_MATRIX*vec4(VERTEX, 1.0)).xyz;
	dye = COLOR.rgb;
	uv = UV;
}
float hash(vec2 p) {return fract(sin(dot(p,vec2(15.716,92.162))) * 41758.156);}
float n(vec2 p) {
	vec2 a=floor(p),t=smoothstep(0.0,1.0,fract(p));
	return mix(mix(hash(a),hash(a+vec2(1.,0.)),t.x),mix(hash(a+vec2(0.,1.)),hash(a+vec2(1.)),t.x),t.y);
}
void fragment(){
	float grime=n(pos.xz*vec2(.68,.93)+pos.y*.32)*.53+n(pos.xz*2.27+pos.y*1.15)*.22;
	vec3 ink=dye*(.76+grime*.31);
	if(material_kind==1){
		float thread=n(vec2(pos.x*12.3,pos.z*6.8))*n(vec2(pos.x*7.1,pos.z*12.3));
		float seams = 1.0-smoothstep(.0,.041,min(uv.x,1.-uv.x));
		ink=dye*(.77+.20*grime+.15*thread)-seams*.022;
	}
	if(material_kind==2){
		float grain=n(vec2((pos.x+pos.z)*4.5,pos.y*.91))*.19;
		ink=dye*(.72+grime*.24+grain);
	}
	ALBEDO = ink;
	ROUGHNESS = .93;
}
