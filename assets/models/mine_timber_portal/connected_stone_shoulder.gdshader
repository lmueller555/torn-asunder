shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D wall_surface : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;

void fragment() {
	vec4 baked = texture(wall_surface, UV);
	ALBEDO = baked.rgb;
	ROUGHNESS = baked.a;
	NORMAL_MAP = texture(wall_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.77;
	SPECULAR = 0.24;
}
