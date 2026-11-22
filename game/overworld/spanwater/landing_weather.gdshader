shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color;
uniform bool timber = false;
varying vec3 p;
float hash(vec3 q) {
	q = fract(q*.31831 + vec3(.13,.47,.21))*16.0;
	return fract(q.x*q.y*q.z*(q.x+q.y+q.z));
}
float ns(vec3 q) {
	vec3 b = floor(q);
	vec3 t = smoothstep(vec3(0),vec3(1),fract(q));
	float a = mix(mix(hash(b),hash(b+vec3(1,0,0)),t.x),
		mix(hash(b+vec3(0,1,0)),hash(b+vec3(1,1,0)),t.x),t.y);
	b.z += 1.0;
	float d = mix(mix(hash(b),hash(b+vec3(1,0,0)),t.x),
		mix(hash(b+vec3(0,1,0)),hash(b+vec3(1,1,0)),t.x),t.y);
	return mix(a,d,t.z);
}
void vertex() {
	p = (MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment() {
	float gr = ns(p*vec3(4.0,1.9,4.0));
	float large = ns(p*.48);
	float grain = ns(p*vec3(12.5,.19,9.7));
	float worn = timber ? .71+.34*grain+.15*large : .60+.31*gr+.37*large;
	float damp = 1.-smoothstep(.40,1.2,p.y + .35*(large-.5));
	ALBEDO = tint.rgb*worn*mix(.74,1.,COLOR.r)*mix(1.,.59,damp);
	ROUGHNESS = timber ? .89 : .95;
}
