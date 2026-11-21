shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D original_water : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tributary_water : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 crossing_local;
void vertex() {
	crossing_local=VERTEX;
}
void fragment() {
	// Only the duplicate motif on the west branch. Keep the true ford, west seam and V3 material intact.
	float tributary=(1.0-smoothstep(225.0,265.0,crossing_local.x))*smoothstep(135.0,151.0,crossing_local.z);
	float painted=(1.0-smoothstep(0.021,0.032,abs(UV.x-0.69275)))*tributary;
	ALBEDO=mix(texture(original_water,UV).rgb,texture(tributary_water,UV).rgb,painted);
	METALLIC=0.0;
	ROUGHNESS=0.81;
	SPECULAR=0.5;
}
