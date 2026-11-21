shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D baked_surface : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D baked_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 gunmetal : source_color = vec4(0.340, 0.347, 0.343, 1.0);
uniform vec4 oxide : source_color = vec4(0.382, 0.289, 0.205, 1.0);
uniform float polished : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 coords = UV * vec2(2.6, 1.7);
	vec3 forged = texture(baked_surface, coords).rgb;
	float worn = 1.0 - smoothstep(0.17, 0.43, forged.g);
	float scuff = polished * (0.49 + worn * 0.33);
	vec3 scale = mix(gunmetal.rgb, oxide.rgb, forged.b * (0.53 - polished * 0.19));
	vec3 bare = gunmetal.rgb * 1.28;
	ALBEDO = mix(scale, bare, scuff) * (0.72 + 0.32 * forged.r);
	METALLIC = mix(0.30, 0.57, scuff) * (1.0 - forged.b * 0.24);
	ROUGHNESS = clamp(forged.g + (1.0 - polished) * 0.095 - polished * 0.23, 0.26, 0.84);
	SPECULAR = 0.63;
	NORMAL_MAP = texture(baked_normal, coords).rgb;
	NORMAL_MAP_DEPTH = 0.57;
}
