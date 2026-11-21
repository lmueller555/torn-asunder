shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D old_vista_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D crossing_albedo : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 vp;
void vertex() {
	vp=VERTEX;
}
void fragment() {
	float x=vp.x-420.0;
	float d=vp.z-300.0;
	float w=smoothstep(0.0,38.0,x)*(1.0-smoothstep(10.0,70.0,d))
		*(1.0-smoothstep(297.0,327.0,x))*step(0.0,d);
	// Carry the actual boundary pigment across the rim before dissolving into original V3 scenery.
	float grain=(0.41*sin(x*.12+d*.24)+0.24*sin(d*.81+x*.18))*smoothstep(0.0,18.0,d);
	vec2 join_uv=vec2(clamp((x+grain)/540.0,.0001,.9999),
		clamp((max(d,0.0)*.57+grain)/600.0,.0001,.9999));
	ALBEDO=mix(texture(old_vista_albedo,UV).rgb,texture(crossing_albedo,join_uv).rgb,w);
	METALLIC=0.0;
	ROUGHNESS=0.95;
	SPECULAR=0.5;
}
