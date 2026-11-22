shader_type spatial;
varying vec3 _local;
uniform sampler2D route_mask : filter_linear;
uniform vec4 route_domain;
uniform sampler2D connector_mask : filter_linear;
uniform vec4 connector_domain;
uniform sampler2D track_mask : filter_linear;
uniform sampler2D yard_mask : filter_linear;
uniform sampler2D rut_mask : filter_linear;
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
	vec2 cv=(p-connector_domain.xy)/connector_domain.zw;
	mark=max(mark,texture(connector_mask,clamp(cv,0.,1.)).r);
	float broken=clamp(mark*(.77+smooth_noise(p*.28)*.28),0.,1.);
	vec3 trail=mix(vec3(.26,.18,.10),vec3(.54,.37,.19),grain*2.+layers);
	float foot=texture(track_mask,clamp(cv,0.,1.)).r;
	earth=mix(earth,vec3(.255,.220,.162),foot*.67);
	float yard=texture(yard_mask,clamp(cv,0.,1.)).r;
	vec3 grit=mix(vec3(.235,.203,.160),vec3(.403,.371,.296),grain*2.+layers);
	float ruts=texture(rut_mask,clamp(cv,0.,1.)).r;
	ALBEDO=mix(mix(earth,trail*(1.-ruts*.26),broken),grit,yard*.93);
	ROUGHNESS=.97;
}
