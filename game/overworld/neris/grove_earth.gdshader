shader_type spatial;
varying vec3 _local;
uniform sampler2D route_mask : filter_linear;
uniform vec4 route_domain;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float smooth_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);
}
void vertex() { _local=VERTEX; }
void fragment() {
	vec2 p=_local.xz;
	float grain=smooth_noise(p*.41)*.14+smooth_noise(p*1.83)*.046;
	float layers=smooth_noise(p*.044)*.15+smooth_noise(p*.013)*.24;
	float rock=clamp(1.-NORMAL.y,0.,1.);
	vec3 earth=max(vec3(0.01),COLOR.rgb*(.68+grain+layers)+rock*.029);
	vec2 uv=(p-route_domain.xy)/route_domain.zw;
	float mark=texture(route_mask,clamp(uv,0.,1.)).r;
	float broken=clamp(mark*(.77+smooth_noise(p*.28)*.28),0.,1.);
	vec3 trail=mix(vec3(.26,.18,.10),vec3(.54,.37,.19),grain*2.+layers);
	ALBEDO=mix(earth,trail,broken);
	ROUGHNESS=.97;
}
